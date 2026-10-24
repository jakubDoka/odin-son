package typecheck

import "core:odin/ast"
import "core:strconv"

Gpu_Op_Kind :: enum {A, B, Constant, Add, Sub, Neg, Mul, Div, Eq, Ne, Lt, Le, Gt, Ge, And, Or, Not, Select, Return}
Gpu_Value_Type :: enum {F32, Bool}
Gpu_Op :: struct {
	kind: Gpu_Op_Kind,
	bits: u32,
	inputs: [3]int,
	type: Gpu_Value_Type,
}
Gpu_Local :: struct {name: string, value: int, mutable: bool}
Gpu_Lower :: struct {
	ctx: ^Gen_Ctx,
	ops: [dynamic]Gpu_Op,
	locals: [dynamic]Gpu_Local,
	failed: bool,
	returned: bool,
	divisions: int,
}

lower_gpu_scalar :: proc(ctx: ^Gen_Ctx, prc: ^ast.Proc_Lit) -> []Gpu_Op {
	state := Gpu_Lower{ctx = ctx}
	state.ops = make([dynamic]Gpu_Op, ctx.types.allocator)
	state.locals = make([dynamic]Gpu_Local, ctx.types.allocator)
	defer delete(state.locals)
	param_index := 0
	for param in prc.type.params.list {
		for node in param.names {
			name, ok := node.derived.(^ast.Ident)
			if !ok {gpu_fail(&state, node, "native GPU requires named parameters"); break}
			value := gpu_value(&state, {kind = param_index == 0 ? .A : .B})
			append(&state.locals, Gpu_Local{name.name, value, false})
			param_index += 1
		}
	}
	gpu_block(&state, prc.body, true)
	if !state.returned do gpu_fail(&state, prc, "native GPU procedure requires a final f32 return")
	if state.failed {delete(state.ops); return nil}
	return state.ops[:]
}

gpu_fail :: proc(state: ^Gpu_Lower, node: ^ast.Node, message: string) {
	if !state.failed do error(state.ctx, node, message)
	state.failed = true
}

gpu_value :: proc(state: ^Gpu_Lower, op: Gpu_Op) -> int {
	if len(state.ops) >= 4096 {
		gpu_fail(state, state.ctx.file.decls[0], "native GPU procedure exceeds 4096 lowered values")
		return 0
	}
	append(&state.ops, op)
	return len(state.ops)-1
}

gpu_local :: proc(state: ^Gpu_Lower, name: string) -> int {
	for i := len(state.locals)-1; i >= 0; i -= 1 do if state.locals[i].name == name do return i
	return -1
}

gpu_expression :: proc(state: ^Gpu_Lower, node: ^ast.Node, depth := 0) -> int {
	if state.failed do return 0
	if depth > 64 {gpu_fail(state, node, "native GPU expression is too deeply nested"); return 0}
	#partial switch d in node.derived {
	case ^ast.Paren_Expr: return gpu_expression(state, d.expr, depth+1)
	case ^ast.Ident:
		if d.name == "true" || d.name == "false" do return gpu_value(state, {kind = .Constant, type = .Bool, bits = d.name == "true" ? 1 : 0})
		local := gpu_local(state, d.name)
		if local >= 0 do return state.locals[local].value
	case ^ast.Basic_Lit:
		value, valid := strconv.parse_f64(src_of(state.ctx.file^, node))
		if valid do return gpu_value(state, {kind = .Constant, bits = transmute(u32)f32(value)})
	case ^ast.Unary_Expr:
		value := gpu_expression(state, d.expr, depth+1)
		if state.failed do return 0
		if d.op.kind == .Not && state.ops[value].type == .Bool do return gpu_value(state, {kind = .Not, type = .Bool, inputs = {value, 0, 0}})
		if state.ops[value].type == .F32 {
			if d.op.kind == .Add do return value
			if d.op.kind == .Sub do return gpu_value(state, {kind = .Neg, inputs = {value, 0, 0}})
		}
	case ^ast.Binary_Expr:
		lhs := gpu_expression(state, d.left, depth+1)
		rhs := gpu_expression(state, d.right, depth+1)
		if state.failed do return 0
		kind: Gpu_Op_Kind
		result_type: Gpu_Value_Type
		#partial switch d.op.kind {
		case .Add: kind = .Add
		case .Sub: kind = .Sub
		case .Mul: kind = .Mul
		case .Quo:
			kind = .Div
			state.divisions += 1
			if state.divisions > 2 {gpu_fail(state, node, "native GPU procedure supports at most two divisions"); return 0}
		case .Cmp_Eq: kind = .Eq; result_type = .Bool
		case .Not_Eq: kind = .Ne; result_type = .Bool
		case .Lt: kind = .Lt; result_type = .Bool
		case .Lt_Eq: kind = .Le; result_type = .Bool
		case .Gt: kind = .Gt; result_type = .Bool
		case .Gt_Eq: kind = .Ge; result_type = .Bool
		case .Cmp_And: kind = .And; result_type = .Bool
		case .Cmp_Or: kind = .Or; result_type = .Bool
		case: gpu_fail(state, node, "unsupported native GPU binary operation"); return 0
		}
		left_type, right_type := state.ops[lhs].type, state.ops[rhs].type
		valid := left_type == right_type
		if kind == .And || kind == .Or {valid &= left_type == .Bool} else if kind != .Eq && kind != .Ne {valid &= left_type == .F32}
		if !valid {gpu_fail(state, node, "incompatible native GPU operands"); return 0}
		return gpu_value(state, {kind = kind, type = result_type, inputs = {lhs, rhs, 0}})
	case ^ast.Ternary_If_Expr:
		condition := gpu_expression(state, d.cond, depth+1)
		lhs := gpu_expression(state, d.x, depth+1)
		rhs := gpu_expression(state, d.y, depth+1)
		if state.failed do return 0
		if state.ops[condition].type != .Bool || state.ops[lhs].type != state.ops[rhs].type {
			gpu_fail(state, node, "native GPU select requires a bool condition and matching values"); return 0
		}
		return gpu_value(state, {kind = .Select, type = state.ops[lhs].type, inputs = {condition, lhs, rhs}})
	}
	gpu_fail(state, node, "unsupported native GPU expression")
	return 0
}

gpu_block :: proc(state: ^Gpu_Lower, node: ^ast.Node, allow_return: bool) {
	block, ok := node.derived.(^ast.Block_Stmt)
	if !ok {gpu_fail(state, node, "native GPU requires a block"); return}
	previous := len(state.locals)
	defer resize(&state.locals, previous)
	for stmt in block.stmts {
		if state.failed do return
		if state.returned {gpu_fail(state, stmt, "native GPU does not accept statements after return"); return}
		#partial switch d in stmt.derived {
		case ^ast.Value_Decl:
			if len(d.names) != 1 || len(d.values) != 1 {gpu_fail(state, stmt, "native GPU locals require one initializer"); return}
			name, named := d.names[0].derived.(^ast.Ident)
			if !named {gpu_fail(state, stmt, "native GPU local requires a name"); return}
			for local in state.locals[previous:] {
				if local.name == name.name {gpu_fail(state, stmt, "duplicate native GPU local"); return}
			}
			value := gpu_expression(state, d.values[0])
			if state.failed do return
			if d.type != nil {
				type_name, typed := d.type.derived.(^ast.Ident)
				if !typed || (type_name.name != "f32" && type_name.name != "bool") || (type_name.name == "bool") != (state.ops[value].type == .Bool) {
					gpu_fail(state, stmt, "native GPU locals support matching f32 or bool types"); return
				}
			}
			append(&state.locals, Gpu_Local{name.name, value, d.is_mutable})
		case ^ast.Assign_Stmt:
			if len(d.lhs) != 1 || len(d.rhs) != 1 {gpu_fail(state, stmt, "native GPU assignment requires one local"); return}
			name, named := d.lhs[0].derived.(^ast.Ident)
			if !named {gpu_fail(state, stmt, "native GPU assignment requires a local name"); return}
			index := gpu_local(state, name.name)
			if index < 0 || !state.locals[index].mutable {gpu_fail(state, stmt, "native GPU assignment requires a mutable local"); return}
			value := gpu_expression(state, d.rhs[0])
			if state.failed do return
			previous_value := state.locals[index].value
			if state.ops[previous_value].type != state.ops[value].type {gpu_fail(state, stmt, "native GPU assignment changes local type"); return}
			if d.op.kind != .Eq {
				kind: Gpu_Op_Kind
				#partial switch d.op.kind {
				case .Add_Eq: kind = .Add
				case .Sub_Eq: kind = .Sub
				case .Mul_Eq: kind = .Mul
				case: gpu_fail(state, stmt, "unsupported native GPU assignment operation"); return
				}
				if state.ops[value].type != .F32 {gpu_fail(state, stmt, "native GPU compound assignment requires f32"); return}
				value = gpu_value(state, {kind = kind, inputs = {previous_value, value, 0}})
			}
			state.locals[index].value = value
		case ^ast.For_Stmt: gpu_unroll(state, d)
		case ^ast.Block_Stmt: gpu_block(state, stmt, false)
		case ^ast.Return_Stmt:
			if !allow_return || len(d.results) != 1 {gpu_fail(state, stmt, "native GPU requires one final f32 return outside loops"); return}
			value := gpu_expression(state, d.results[0])
			if state.failed do return
			if state.ops[value].type != .F32 {gpu_fail(state, stmt, "native GPU return must be f32"); return}
			gpu_value(state, {kind = .Return, inputs = {value, 0, 0}})
			state.returned = true
		case: gpu_fail(state, stmt, "native GPU supports locals, assignments, bounded for loops and return")
		}
	}
}

gpu_unroll :: proc(state: ^Gpu_Lower, loop: ^ast.For_Stmt) {
	message :: "native GPU loop requires for i := 0; i < N; i += 1 with constant N in 1..64"
	if loop.init == nil || loop.cond == nil || loop.post == nil || loop.label != nil {gpu_fail(state, loop, message); return}
	init, initialized := loop.init.derived.(^ast.Value_Decl)
	condition, compared := loop.cond.derived.(^ast.Binary_Expr)
	post, assigned := loop.post.derived.(^ast.Assign_Stmt)
	if !initialized || !compared || !assigned {gpu_fail(state, loop, message); return}
	if len(init.names) != 1 || len(init.values) != 1 || condition.op.kind != .Lt || post.op.kind != .Add_Eq || len(post.lhs) != 1 || len(post.rhs) != 1 {gpu_fail(state, loop, message); return}
	name, named := init.names[0].derived.(^ast.Ident)
	left, left_named := condition.left.derived.(^ast.Ident)
	updated, update_named := post.lhs[0].derived.(^ast.Ident)
	start, start_constant := const_eval_int(init.values[0])
	bound, bounded := const_eval_int(condition.right)
	step, stepped := const_eval_int(post.rhs[0])
	if !named || !left_named || !update_named || name.name != left.name || name.name != updated.name || !start_constant || start != 0 || !bounded || bound < 1 || bound > 64 || !stepped || step != 1 {gpu_fail(state, loop, message); return}
	previous := len(state.locals)
	defer resize(&state.locals, previous)
	append(&state.locals, Gpu_Local{name = name.name})
	for i := i64(0); i < bound && !state.failed; i += 1 {
		state.locals[previous].value = gpu_value(state, {kind = .Constant, bits = transmute(u32)f32(i)})
		gpu_block(state, loop.body, false)
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
