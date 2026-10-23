package main

import "bac"
import eu "bac/intel_xelp"
import "bac/ssa"
import "core:slice"
import "typecheck"
import "utils/arna"

compile_gpu_scalar :: proc(ctx: ^Gen_Ctx, prc: ^typecheck.Proc) -> []u8 {
	return compile_gpu_scalar_code(ctx, prc, false)
}

compile_gpu_scalar_body :: proc(ctx: ^Gen_Ctx, prc: ^typecheck.Proc) -> []u8 {
	return compile_gpu_scalar_code(ctx, prc, true)
}

compile_gpu_scalar_code :: proc(ctx: ^Gen_Ctx, prc: ^typecheck.Proc, body_only: bool) -> []u8 {
	context.allocator, _ = arna.scrath()
	p: bac.Proc
	memory: arna.Allocator
	if err := arna.init(&memory, 8 * 1024 * 1024); err != nil do panic("GPU graph allocation failed")
	defer arna.destroy(&memory)
	rmem := ssa.start_proc(&p, &memory, &arna.scratch)
	spec := eu.SPEC
	if body_only do spec.emit_function = eu.emit_body
	p.node_spec = &spec
	previous := bac.current_prc
	bac.current_prc = &p
	defer bac.current_prc = previous
	a := bac.add_param(&p, "a", .F32, p.entry, 0)
	b := bac.add_param(&p, "b", .F32, p.entry, 1)
	values := make([]Node_ID, len(prc.gpu_ops))
	result: Node_ID
	for op, i in prc.gpu_ops {
		lhs, rhs := values[op.inputs[0]], values[op.inputs[1]]
		dt: bac.Node_Datatype = op.type == .Bool ? .I32 : .F32
		switch op.kind {
		case .A: values[i] = a
		case .B: values[i] = b
		case .Constant: values[i] = bac.add_c_int(&p, "literal", dt, i64(op.bits))
		case .Add, .Mul, .Div:
			k: bac.Bin_Op = .Add
			if op.kind == .Mul do k = .Mul
			if op.kind == .Div do k = .Div
			values[i] = bac.add_bin_op(&p, "expression", k, .F32, lhs, rhs)
		case .Sub, .Neg:
			value := op.kind == .Sub ? rhs : lhs
			bits := bac.add_un_op(&p, "neg-bits", .Cast, .I32, value)
			neg := bac.add_un_op(&p, "neg-value", .Cast, .F32, eu.iop(&p, .Xor, bits, eu.icon(&p, 0x8000_0000)))
			values[i] = op.kind == .Sub ? bac.add_bin_op(&p, "subtract", .Add, .F32, lhs, neg) : neg
		case .Eq, .Ne, .Lt, .Le, .Gt, .Ge:
			@(static, rodata) OPS := #partial [typecheck.Gpu_Op_Kind]bac.Bin_Op{.Eq = .Eq, .Ne = .Ne, .Lt = .Lt, .Le = .Le, .Gt = .Gt, .Ge = .Ge}
			values[i] = bac.add_bin_op(&p, "comparison", OPS[op.kind], .I32, lhs, rhs)
		case .And, .Or:
			values[i] = eu.iop(&p, op.kind == .And ? .And : .Or, lhs, rhs)
		case .Not: values[i] = eu.iop(&p, .Xor, lhs, eu.icon(&p, 1))
		case .Select:
			mask := eu.ineg(&p, lhs)
			left, right := rhs, values[op.inputs[2]]
			if dt == .F32 {
				left = bac.add_un_op(&p, "select-left", .Cast, .I32, left)
				right = bac.add_un_op(&p, "select-right", .Cast, .I32, right)
			}
			selected := eu.iselect(&p, mask, left, right)
			values[i] = dt == .F32 ? bac.add_un_op(&p, "select-value", .Cast, .F32, selected) : selected
		case .Return: result = lhs
		}
	}
	assert(result != 0)
	ssa.merge_returns(&p, {p.entry, rmem, result})
	code: arna.Allocator
	if err := arna.init(&code, 1024 * 1024); err != nil do panic("GPU code allocation failed")
	defer arna.destroy(&code)
	constants, relocs, slocs, cfi, dbg: arna.Allocator
	constants.reserved = 4096
	relocs.reserved = 4096
	slocs.reserved = 4096
	cfi.reserved = 4096
	dbg.reserved = 4096
	if err := arna.bulk_init(&constants, &relocs, &slocs, &cfi, &dbg); err != nil do panic("GPU metadata allocation failed")
	defer arna.bulk_destroy(&constants, &relocs, &slocs, &cfi, &dbg)
	out := ssa.compile({prc = &p, abi = &eu.CC_TABLE[0], param_specs = {{dt = .F32}, {dt = .F32}}, buf = {&code, &constants, &relocs, &slocs, &cfi, &dbg}})
	return slice.clone(out.code, ctx.types.allocator)
}

emit_gpu_scalar_stub :: proc(ctx: ^Gen_Ctx, prc: ^typecheck.Proc, params: [2]Node_ID) {
	if prc.gpu_kernel == nil do prc.gpu_kernel = compile_gpu_scalar(ctx, prc)
	idx := typecheck.add_global(ctx, prc.gpu_kernel, 64)
	ctx.globals[idx].gpu = true
	g := bac.add_global(ctx, "gpu-kernel", idx)
	ptr := bac.add_global_addr(ctx, "gpu-kernel", g)
	size := bac.add_c_int(ctx, "gpu-size", .I64, i64(len(prc.gpu_kernel)))
	output := alloca(ctx, "gpu-result", .F32, zeroed = false)
	args := [?]Node_ID{ctx_ctrl(ctx), ctx_mem(ctx), bac.find_or_create_node(ctx, .Sym), ptr, size, params[0], params[1], output}
	control, memory := ssa.make_call(ctx, args[:], {cid = u32(prc.gpu_dispatch)})
	status := ssa.add_call_ret(ctx, control, .I32)
	ctx_set_mem(ctx, memory)
	bac.set_input(ctx, ctx.node_scope, 0, control)
	failed := bac.add_bin_op(ctx, "gpu-failed", .Ne, .I8, status, bac.add_c_int(ctx, "zero", .I32, 0))
	branch: ssa.If_State
	ssa.start_if(ctx, ctx.node_scope, &branch, failed)
	trap := bac.add_trap(ctx, "gpu-dispatch-failed", {ctx_ctrl(ctx), ctx_mem(ctx)})
	bac.connect(ctx, ctx.end, trap)
	ssa.delete_scope(ctx, ctx.node_scope)
	ctx.node_scope = 0
	ssa.start_else(ctx, &ctx.node_scope, &branch)
	value := ssa.add_field_load(ctx, "gpu-result", .F32, ctx_ctrl(ctx), ctx_mem(ctx), output)
	ssa.merge_returns(ctx, {ctx_ctrl(ctx), ctx_mem(ctx), value})
	ssa.delete_scope(ctx, ctx.node_scope)
	ctx.node_scope = 0
}
