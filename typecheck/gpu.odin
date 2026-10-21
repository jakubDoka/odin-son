package typecheck

import "core:math"
import "core:odin/ast"
import "core:strconv"

lower_gpu_program :: proc(ctx: ^Gen_Ctx, prc: ^ast.Proc_Lit) -> []u32 {
	block := prc.body.derived.(^ast.Block_Stmt) or_else panic("GPU kernel must be a block")
	words := make([dynamic]u32, ctx.types.allocator)
	returned := false
	for stmt in block.stmts {
		if returned {
			error(ctx, stmt, "GPU backend does not accept statements after return")
			continue
		}
		if ret, ok := stmt.derived.(^ast.Return_Stmt); ok {
			if len(ret.results) != 1 {
				error(ctx, ret, "GPU kernel must end with return 0")
				continue
			}
			value, constant := const_eval_int(ret.results[0])
			if !constant || value != 0 do error(ctx, ret, "GPU kernel must end with return 0")
			returned = true
			continue
		}
		expr, is_expr := stmt.derived.(^ast.Expr_Stmt)
		if !is_expr {
			error(ctx, stmt, "GPU backend supports gpu_add_scaled(dst, src, scale) and return 0")
			continue
		}
		call, is_call := expr.expr.derived.(^ast.Call_Expr)
		if !is_call {
			error(ctx, stmt, "GPU backend requires a gpu_add_scaled call")
			continue
		}
		name, is_ident := call.expr.derived.(^ast.Ident)
		if !is_ident || name.name != "gpu_add_scaled" || len(call.args) != 3 {
			error(ctx, call, "GPU backend supports only gpu_add_scaled(dst, src, scale)")
			continue
		}
		dst, dst_ok := const_eval_int(call.args[0])
		src, src_ok := const_eval_int(call.args[1])
		if !dst_ok || !src_ok || dst < 0 || dst > 3 || src < 0 || src > 3 {
			error(ctx, call, "GPU register indices must be constants in 0..3 (x, y, vx, vy)")
			continue
		}
		scale_text := src_of(ctx.file^, call.args[2])
		scale, scale_ok := strconv.parse_f64(scale_text)
		imm := f32(scale)
		if !scale_ok || math.is_nan(imm) || math.is_inf(imm) {
			error(ctx, call.args[2], "GPU scale must be a finite f32 literal")
			continue
		}
		if len(words) >= 16 * 4 {
			error(ctx, call, "GPU backend supports at most 16 instructions")
			continue
		}
		append(&words, 1, u32(dst), u32(src), transmute(u32)imm)
	}
	if !returned do error(ctx, prc, "GPU kernel must end with return 0")
	if len(words) == 0 do error(ctx, prc, "GPU kernel must contain at least one instruction")
	return words[:]
}

gpu_dispatch_proc :: proc(ctx: ^Gen_Ctx) -> Proc_ID {
	decl, found := find_module_decl(ctx, ctx.module, "phy_gpu_dispatch")
	if !found {
		error(ctx, ctx.file.decls[0], "GPU backend requires the local phy_gpu_dispatch runtime adapter")
		return 0
	}
	meta := get_node_meta(decl.value)
	if !is_of(meta.type, ^Proc_Type) || !meta.known || meta.lit.procid == 0 {
		error(ctx, decl.value, "phy_gpu_dispatch must be a local runtime procedure")
		return 0
	}
	prc := &ctx.procs[meta.lit.procid]
	valid := prc.lit.body != nil && len(prc.params) == 4 && len(prc.rets) == 1
	if valid {
		ptr, is_ptr := unpack_type(prc.params[2]).(Multi_Pointer)
		valid = prc.params[0] == .U64 && prc.params[1] == .U64 &&
		        is_ptr && ptr^ == .U32 && prc.params[3] == .Uintptr && prc.rets[0] == .I32
	}
	if !valid {
		error(ctx, decl.value, "phy_gpu_dispatch requires a local proc(handle: u64, frame: u64, words: [^]u32, word_count: uintptr) -> i32")
		return 0
	}
	return meta.lit.procid
}
