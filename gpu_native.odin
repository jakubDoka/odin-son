package main

import "bac"
import eu "bac/intel_xelp"
import "bac/ssa"
import "core:slice"
import "typecheck"
import "utils/arna"

compile_gpu_scalar :: proc(ctx: ^Gen_Ctx, prc: ^typecheck.Proc) -> []u8 {
	context.allocator, _ = arna.scrath()
	p: bac.Proc
	memory: arna.Allocator
	if err := arna.init(&memory, 8 * 1024 * 1024); err != nil do panic("GPU graph allocation failed")
	defer arna.destroy(&memory)
	rmem := ssa.start_proc(&p, &memory, &arna.scratch)
	p.node_spec = &eu.SPEC
	previous := bac.current_prc
	bac.current_prc = &p
	defer bac.current_prc = previous
	a := bac.add_param(&p, "a", .F32, p.entry, 0)
	b := bac.add_param(&p, "b", .F32, p.entry, 1)
	stack: [dynamic]Node_ID
	for op in prc.gpu_ops {
		switch op.kind {
		case .A: append(&stack, a)
		case .B: append(&stack, b)
		case .Constant: append(&stack, bac.add_c_int(&p, "literal", .F32, i64(op.bits)))
		case .Add, .Mul, .Div:
			rhs, lhs := pop(&stack), pop(&stack)
			k: bac.Bin_Op = .Add
			if op.kind == .Mul do k = .Mul
			if op.kind == .Div do k = .Div
			append(&stack, bac.add_bin_op(&p, "expression", k, .F32, lhs, rhs))
		}
	}
	assert(len(stack) == 1)
	ssa.merge_returns(&p, {p.entry, rmem, stack[0]})
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
