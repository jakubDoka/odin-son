package typecheck

import "core:odin/ast"
import "core:strconv"

Gpu_Op_Kind :: enum {A, B, Constant, Add, Mul, Div}
Gpu_Op :: struct {kind: Gpu_Op_Kind, bits: u32}

lower_gpu_scalar :: proc(ctx: ^Gen_Ctx, prc: ^ast.Proc_Lit) -> []Gpu_Op {
	block, is_block := prc.body.derived.(^ast.Block_Stmt)
	if !is_block {error(ctx, prc, "native GPU procedure requires a block"); return nil}
	if len(block.stmts) != 1 {error(ctx, prc, "native GPU procedure requires one return expression"); return nil}
	ret, ok := block.stmts[0].derived.(^ast.Return_Stmt)
	if !ok || len(ret.results) != 1 {error(ctx, prc, "native GPU procedure requires one f32 return expression"); return nil}
	ops := make([dynamic]Gpu_Op, ctx.types.allocator)
	if !expression(ctx, prc, ret.results[0], &ops) {delete(ops); return nil}
	if len(ops) > 64 {error(ctx, prc, "native GPU expression exceeds 64 source operations"); delete(ops); return nil}
	divisions := 0
	for op in ops do if op.kind == .Div do divisions += 1
	if divisions > 2 {error(ctx, prc, "native GPU expression supports at most two divisions"); delete(ops); return nil}
	return ops[:]

	expression :: proc(ctx: ^Gen_Ctx, prc: ^ast.Proc_Lit, node: ^ast.Node, ops: ^[dynamic]Gpu_Op, depth := 0) -> bool {
		if depth > 64 {error(ctx, node, "native GPU expression is too deeply nested"); return false}
		#partial switch d in node.derived {
		case ^ast.Paren_Expr: return expression(ctx, prc, d.expr, ops, depth+1)
		case ^ast.Ident:
			for param, i in prc.type.params.list {
				name := param.names[0].derived.(^ast.Ident) or_continue
				if name.name == d.name {append(ops, Gpu_Op{kind = i == 0 ? .A : .B}); return true}
			}
		case ^ast.Basic_Lit:
			value, valid := strconv.parse_f64(src_of(ctx.file^, node))
			if valid {append(ops, Gpu_Op{kind = .Constant, bits = transmute(u32)f32(value)}); return true}
		case ^ast.Binary_Expr:
			kind: Gpu_Op_Kind
			#partial switch d.op.kind {
			case .Add: kind = .Add
			case .Mul: kind = .Mul
			case .Quo: kind = .Div
			case: error(ctx, node, "native GPU supports f32 +, * and /"); return false
			}
			if !expression(ctx, prc, d.left, ops, depth+1) || !expression(ctx, prc, d.right, ops, depth+1) do return false
			append(ops, Gpu_Op{kind = kind})
			return true
		}
		error(ctx, node, "unsupported native GPU expression")
		return false
	}
}

gpu_scalar_runtime :: proc(ctx: ^Gen_Ctx) -> Proc_ID {
	params := [5]Type{.Rawptr, .Uintptr, .F32, .F32, .Rawptr}
	for prc, i in ctx.procs {
		if prc.name != "trueos_cabi_vgpu_call_f32_v1" do continue
		valid := prc.lit.body == nil && len(prc.params) == len(params) && len(prc.rets) == 1
		if valid {
			valid = prc.rets[0] == .I32
			for param, j in params do valid &= prc.params[j] == param
		}
		if !valid {error(ctx, ctx.file.decls[0], "incompatible declaration of the native GPU runtime symbol"); return 0}
		return Proc_ID(i)
	}
	sig := new(Proc_Type, ctx.types.allocator)
	sig.params = intern_type_slice(ctx, params[:])
	sig.rets = intern_type_slice(ctx, {.I32})
	lit := new(ast.Proc_Lit, ctx.types.allocator)
	lit.type = new(ast.Proc_Type, ctx.types.allocator)
	lit.type.params = new(ast.Field_List, ctx.types.allocator)
	append(&ctx.procs, Proc{name = "trueos_cabi_vgpu_call_f32_v1", sig = sig, lit = lit})
	return Proc_ID(len(ctx.procs)-1)
}
