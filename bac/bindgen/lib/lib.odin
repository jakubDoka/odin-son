
package bac_lib

import "base:runtime"

Proc :: bac.Proc
Node_ID :: bac.Node_ID
import bac "../.."
import bac_ssa "../../ssa"
import bac_arm "../../arm"
import bac_amd64 "../../amd64"
import bac_wasm "../../wasm"
import bac_regalloc "../../regalloc/"
import arna "../../../utils/arna/"

_ :: bac
_ :: bac_ssa
_ :: bac_arm
_ :: bac_amd64
_ :: bac_wasm
_ :: bac_regalloc
_ :: arna
@(export)
arna_init_from_buffer :: proc "c" (
	buf: []u8,
) -> (
	arna.Allocator,
) {
	context = {}
	return arna.init_from_buffer(buf)
}

@(export)
bac_start_proc :: proc "c" (
	prc: ^bac.Proc,
	mem: ^arna.Allocator,
	temps: ^arna.Temps,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac_ssa.start_proc(prc, mem, temps)
}

@(export)
bac_set_scope_value :: proc "c" (
	prc: ^bac.Proc,
	scope: bac.Node_ID,
	idx: int,
	value: bac.Node_ID,
) {
	context = {}
	bac_ssa.set_scope_value(prc, scope, idx, value)
}

@(export)
bac_delete_scope :: proc "c" (
	prc: ^bac.Proc,
	scope: bac.Node_ID,
) {
	context = {}
	bac_ssa.delete_scope(prc, scope)
}

@(export)
bac_push_scope_value :: proc "c" (
	prc: ^bac.Proc,
	scope: bac.Node_ID,
	value: bac.Node_ID,
	name: string,
	type: u64,
) -> (
	int,
) {
	context = {}
	return bac_ssa.push_scope_value(prc, scope, value, name, type)
}

@(export)
bac_merge_return :: proc "c" (
	prc: ^bac.Proc,
	args: []bac.Node_ID,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac_ssa.merge_return(prc, args)
}

@(export)
bac_truncate_scope :: proc "c" (
	prc: ^bac.Proc,
	scope: bac.Node_ID,
	to_len: int,
) {
	context = {}
	bac_ssa.truncate_scope(prc, scope, to_len)
}

@(export)
bac_compile :: proc "c" (
	ctx: bac.Codegen_Emit_Ctx,
) -> (
	bac.Codegen_Output,
) {
	context = {}
	return bac_ssa.compile(ctx)
}

@(export)
bac_opt :: proc "c" (
	ctx: bac.Peep_Ctx,
) {
	context = {}
	bac_ssa.opt(ctx)
}

@(export)
bac_memopt :: proc "c" (
	prc: ^bac.Proc,
) -> (
	bool,
) {
	context = {}
	return bac_ssa.memopt(prc)
}

@(export)
bac_inline_graph :: proc "c" (
	prc: ^bac.Proc,
	call: bac.Node_ID,
	from: ^bac.Proc,
) {
	context = {}
	bac_ssa.inline_graph(prc, call, from)
}

@(export)
bac_mount_stencil :: proc "c" (
	prc: ^bac.Proc,
	stencil: bac.Stencil,
) {
	context = {}
	bac.mount_stencil(prc, stencil)
}

@(export)
bac_apply_peeps :: proc "c" (
	ctx: bac.Peep_Ctx,
) -> (
	bool,
) {
	context = {}
	return bac.apply_peeps(ctx)
}

@(export)
bac_get_stencil :: proc "c" (
	prc: ^bac.Proc,
) -> (
	bac.Stencil,
) {
	context = {}
	return bac.get_stencil(prc)
}

@(export)
bac_loopopt :: proc "c" (
	prc: ^bac.Proc,
) -> (
	bool,
) {
	context = {}
	return bac_ssa.loopopt(prc)
}

@(export)
bac_inline_stencil :: proc "c" (
	prc: ^bac.Proc,
	call: bac.Node_ID,
	from: bac.Stencil,
) {
	context = {}
	bac_ssa.inline_stencil(prc, call, from)
}

@(export)
bac_compact :: proc "c" (
	prc: ^bac.Proc,
) {
	context = {}
	bac.compact(prc)
}

@(export)
bac_compute_latices :: proc "c" (
	ctx: ^bac.Proc,
	scratch: runtime.Allocator,
) -> (
	bool,
) {
	context = {}
	return bac.compute_latices(ctx, scratch)
}

@(export)
bac_schedule_graph :: proc "c" (
	prc: ^bac.Proc,
	gs: ^bac.Schedule,
	purpose: bac.Schedule_Mode,
	scratch: runtime.Allocator,
) {
	context = {}
	bac.schedule_graph(prc, gs, purpose, scratch)
}

@(export)
bac_take_dbg_data :: proc "c" (
	prc: ^bac.Proc,
	sched: ^bac.Schedule,
	data: ^bac.Dbg_Data,
	scratch: runtime.Allocator,
) {
	context = {}
	bac.take_dbg_data(prc, sched, data, scratch)
}

@(export)
bac_regalloc :: proc "c" (
	ra: ^bac.Regalloc,
	prc: ^bac.Proc,
	sched: ^bac.Schedule,
	mode: bac.Regalloc_Mode,
	scratch: runtime.Allocator,
) -> (
	bac.Regalloc_Output,
) {
	context = {}
	return bac_regalloc.regalloc(ra, prc, sched, mode, scratch)
}

@(export)
bac_add_local_addr :: proc "c" (
	prc: ^bac.Proc,
	name: string,
	local: bac.Node_ID,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac.add_local_addr(prc, name, local)
}

@(export)
bac_add_local :: proc "c" (
	prc: ^bac.Proc,
	name: string,
	mem: bac.Node_ID,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac.add_local(prc, name, mem)
}

@(export)
bac_add_loop :: proc "c" (
	prc: ^bac.Proc,
	name: string,
	ctrl: bac.Node_ID,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac.add_loop(prc, name, ctrl)
}

@(export)
bac_add_jump :: proc "c" (
	prc: ^bac.Proc,
	name: string,
	ctrl: bac.Node_ID,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac.add_jump(prc, name, ctrl)
}

@(export)
bac_add_param :: proc "c" (
	prc: ^bac.Proc,
	name: string,
	dt: bac.Node_Datatype,
	entry: bac.Node_ID,
	idx: u32,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac.add_param(prc, name, dt, entry, idx)
}

@(export)
bac_add_phi :: proc "c" (
	prc: ^bac.Proc,
	name: string,
	dt: bac.Node_Datatype,
	reg: bac.Node_ID,
	lhs: bac.Node_ID,
	rhs: bac.Node_ID,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac.add_phi(prc, name, dt, reg, lhs, rhs)
}

@(export)
bac_add_poison :: proc "c" (
	prc: ^bac.Proc,
	name: string,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac.add_poison(prc, name)
}

@(export)
bac_add_proc_addr :: proc "c" (
	prc: ^bac.Proc,
	name: string,
	idx: u32,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac.add_proc_addr(prc, name, idx)
}

@(export)
bac_add_region :: proc "c" (
	prc: ^bac.Proc,
	name: string,
	inputs: []bac.Node_ID,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac.add_region(prc, name, inputs)
}

@(export)
bac_add_ret :: proc "c" (
	prc: ^bac.Proc,
	name: string,
	dt: bac.Node_Datatype,
	call_end: bac.Node_ID,
	idx: u32,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac.add_ret(prc, name, dt, call_end, idx)
}

@(export)
bac_add_return :: proc "c" (
	prc: ^bac.Proc,
	name: string,
	inputs: []bac.Node_ID,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac.add_return(prc, name, inputs)
}

@(export)
bac_add_select :: proc "c" (
	prc: ^bac.Proc,
	name: string,
	dt: bac.Node_Datatype,
	on_true: bac.Node_ID,
	on_false: bac.Node_ID,
	condition: bac.Node_ID,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac.add_select(prc, name, dt, on_true, on_false, condition)
}

@(export)
bac_add_set :: proc "c" (
	prc: ^bac.Proc,
	name: string,
	ctrl: bac.Node_ID,
	mem: bac.Node_ID,
	dst: bac.Node_ID,
	value: bac.Node_ID,
	size: bac.Node_ID,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac.add_set(prc, name, ctrl, mem, dst, value, size)
}

@(export)
bac_add_split :: proc "c" (
	prc: ^bac.Proc,
	name: string,
	dt: bac.Node_Datatype,
	dest: bac.Node_ID,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac.add_split(prc, name, dt, dest)
}

@(export)
bac_add_split_mem :: proc "c" (
	prc: ^bac.Proc,
	name: string,
	mem: bac.Node_ID,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac.add_split_mem(prc, name, mem)
}

@(export)
bac_add_store :: proc "c" (
	prc: ^bac.Proc,
	name: string,
	ctrl: bac.Node_ID,
	mem: bac.Node_ID,
	addr: bac.Node_ID,
	value: bac.Node_ID,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac.add_store(prc, name, ctrl, mem, addr, value)
}

@(export)
bac_add_sym :: proc "c" (
	prc: ^bac.Proc,
	name: string,
	entry: bac.Node_ID,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac.add_sym(prc, name, entry)
}

@(export)
bac_add_then :: proc "c" (
	prc: ^bac.Proc,
	name: string,
	ctrl: bac.Node_ID,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac.add_then(prc, name, ctrl)
}

@(export)
bac_add_if :: proc "c" (
	prc: ^bac.Proc,
	name: string,
	ctrl: bac.Node_ID,
	cond: bac.Node_ID,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac.add_if(prc, name, ctrl, cond)
}

@(export)
bac_add_global_addr :: proc "c" (
	prc: ^bac.Proc,
	name: string,
	global: bac.Node_ID,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac.add_global_addr(prc, name, global)
}

@(export)
bac_add_load :: proc "c" (
	prc: ^bac.Proc,
	name: string,
	dt: bac.Node_Datatype,
	ctrl: bac.Node_ID,
	mem: bac.Node_ID,
	addr: bac.Node_ID,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac.add_load(prc, name, dt, ctrl, mem, addr)
}

@(export)
bac_add_mem :: proc "c" (
	prc: ^bac.Proc,
	name: string,
	ctrl: bac.Node_ID,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac.add_mem(prc, name, ctrl)
}

@(export)
bac_buf_checkpoint :: proc "c" (
	buf: ^bac.Codegen_Emit_Buf,
) -> (
	bac.Codegen_Emit_Buf_Checkpoint,
) {
	context = {}
	return bac.buf_checkpoint(buf)
}

@(export)
bac_apply_peep :: proc "c" (
	prc: ^bac.Proc,
	id: bac.Node_ID,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac.apply_peep(prc, id)
}

@(export)
bac_add_un_op :: proc "c" (
	prc: ^bac.Proc,
	name: string,
	type: bac.Un_Op,
	dt: bac.Node_Datatype,
	oprnd: bac.Node_ID,
	lane: bac.Lane_Type,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac.add_un_op(prc, name, type, dt, oprnd, lane)
}

@(export)
bac_connect :: proc "c" (
	prc: ^bac.Proc,
	use: bac.Node_ID,
	def: bac.Node_ID,
) -> (
	int,
) {
	context = {}
	return bac.connect(prc, use, def)
}

@(export)
bac_buf_output :: proc "c" (
	buf: bac.Codegen_Emit_Buf,
	check: bac.Codegen_Emit_Buf_Checkpoint,
) -> (
	bac.Codegen_Output,
) {
	context = {}
	return bac.buf_output(buf, check)
}

@(export)
bac_delete_node_node_id :: proc "c" (
	prc: ^bac.Proc,
	id: bac.Node_ID,
) {
	context = {}
	bac.delete_node_node_id(prc, id)
}

@(export)
bac_expand_node :: proc "c" (
	prc: ^bac.Proc,
	id: bac.Node_ID,
) -> (
	bac.Expanded_Node,
) {
	context = {}
	return bac.expand_node(prc, id)
}

@(export)
bac_find_node :: proc "c" (
	prc: ^bac.Proc,
	kind: bac.Node_Type,
	on: bac.Node_ID,
	binding_out_0: ^bac.Node_ID,
) -> (
	bool,
) {
	context = {}
	binding_result_0, binding_result_1 := bac.find_node(prc, kind, on)
	binding_out_0^ = binding_result_0
	return binding_result_1
}

@(export)
bac_find_or_create_node :: proc "c" (
	prc: ^bac.Proc,
	kind: bac.Node_Type,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac.find_or_create_node(prc, kind)
}

@(export)
bac_delete_node_node :: proc "c" (
	prc: ^bac.Proc,
	node: ^bac.Node,
) {
	context = {}
	bac.delete_node_node(prc, node)
}

@(export)
bac_get_inputs_node :: proc "c" (
	prc: ^bac.Proc,
	node: ^bac.Node,
) -> (
	[]bac.Node_ID,
) {
	context = {}
	return bac.get_inputs_node(prc, node)
}

@(export)
bac_get_node :: proc "c" (
	prc: ^bac.Proc,
	id: bac.Node_ID,
) -> (
	^bac.Node,
) {
	context = {}
	return bac.get_node(prc, id)
}

@(export)
bac_get_inputs_node_id :: proc "c" (
	prc: ^bac.Proc,
	id: bac.Node_ID,
) -> (
	[]bac.Node_ID,
) {
	context = {}
	return bac.get_inputs_node_id(prc, id)
}

@(export)
bac_get_sym_count :: proc "c" (
	prc: ^bac.Proc,
	binding_out_0: ^bac.Node_ID,
) -> (
	int,
) {
	context = {}
	binding_result_0, binding_result_1 := bac.get_sym_count(prc)
	binding_out_0^ = binding_result_0
	return binding_result_1
}

@(export)
bac_add_end :: proc "c" (
	prc: ^bac.Proc,
	name: string,
	inputs: []bac.Node_ID,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac.add_end(prc, name, inputs)
}

@(export)
bac_add_efficiency_stat :: proc "c" (
	stats: ^bac.Stats,
	kind: bac.Efficiency_Stat_Kind,
	total: int,
	ideal: int,
) {
	context = {}
	bac.add_efficiency_stat(stats, kind, total, ideal)
}

@(export)
bac_add_dbg_sym_update :: proc "c" (
	prc: ^bac.Proc,
	name: string,
	new_value: bac.Node_ID,
	prev_update: bac.Node_ID,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac.add_dbg_sym_update(prc, name, new_value, prev_update)
}

@(export)
bac_add_else :: proc "c" (
	prc: ^bac.Proc,
	name: string,
	ctrl: bac.Node_ID,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac.add_else(prc, name, ctrl)
}

@(export)
bac_add_entry :: proc "c" (
	prc: ^bac.Proc,
	name: string,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac.add_entry(prc, name)
}

@(export)
bac_add_copy :: proc "c" (
	prc: ^bac.Proc,
	name: string,
	ctrl: bac.Node_ID,
	mem: bac.Node_ID,
	dst: bac.Node_ID,
	src: bac.Node_ID,
	size: bac.Node_ID,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac.add_copy(prc, name, ctrl, mem, dst, src, size)
}

@(export)
bac_add_call_end :: proc "c" (
	prc: ^bac.Proc,
	name: string,
	call: bac.Node_ID,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac.add_call_end(prc, name, call)
}

@(export)
bac_schedule_peeps :: proc "c" (
	prc: ^bac.Proc,
	schedule: ^bac.Schedule,
) {
	context = {}
	bac.schedule_peeps(prc, schedule)
}

@(export)
bac_set_input :: proc "c" (
	prc: ^bac.Proc,
	id: bac.Node_ID,
	idx: int,
	value: bac.Node_ID,
	subsume_on_intern: bool,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac.set_input(prc, id, idx, value, subsume_on_intern)
}

@(export)
bac_pin :: proc "c" (
	prc: ^bac.Proc,
	id: bac.Node_ID,
) {
	context = {}
	bac.pin(prc, id)
}

@(export)
bac_lane_from_dt :: proc "c" (
	ty: bac.Node_Datatype,
	binding_out_0: ^bac.Lane_Type,
) -> (
	bool,
) {
	context = {}
	binding_result_0, binding_result_1 := bac.lane_from_dt(ty)
	binding_out_0^ = binding_result_0
	return binding_result_1
}

@(export)
bac_sym_iter_next :: proc "c" (
	prc: ^bac.Proc,
	sym: bac.Node_ID,
	iter: ^int,
	binding_out_0: ^bac.Sym_Ref,
) -> (
	bool,
) {
	context = {}
	binding_result_0, binding_result_1 := bac.sym_iter_next(prc, sym, iter)
	binding_out_0^ = binding_result_0
	return binding_result_1
}

@(export)
bac_sloc_scope :: proc "c" (
	prc: ^bac.Proc,
	sloc: bac.Sloc,
	binding_out_0: ^^bac.Proc,
) -> (
	bac.Sloc,
) {
	context = {}
	binding_result_0, binding_result_1 := bac.sloc_scope(prc, sloc)
	binding_out_0^ = binding_result_0
	return binding_result_1
}

@(export)
bac_unpin :: proc "c" (
	prc: ^bac.Proc,
	id: bac.Node_ID,
	no_delete: bool,
) {
	context = {}
	bac.unpin(prc, id, no_delete)
}

@(export)
bac_set_local_size :: proc "c" (
	prc: ^bac.Proc,
	loc: bac.Node_ID,
	size: i32,
) {
	context = {}
	bac.set_local_size(prc, loc, size)
}

@(export)
bac_add_arbitrary_store :: proc "c" (
	ctx: ^bac.Proc,
	cfg: bac.Node_ID,
	mem: bac.Node_ID,
	addr: bac.Node_ID,
	rvalue: bac.Node_ID,
	rsize: int,
	extra_offset: int,
	unit: bac.Node_Datatype,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac_ssa.add_arbitrary_store(ctx, cfg, mem, addr, rvalue, rsize, extra_offset, unit)
}

@(export)
bac_add_field_offset :: proc "c" (
	prc: ^bac.Proc,
	base: bac.Node_ID,
	offset: int,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac_ssa.add_field_offset(prc, base, offset)
}

@(export)
bac_add_arbitrary_load :: proc "c" (
	ctx: ^bac.Proc,
	cfg: bac.Node_ID,
	mem: bac.Node_ID,
	addr: bac.Node_ID,
	rsize: int,
	extra_offset: int,
	unit: bac.Node_Datatype,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac_ssa.add_arbitrary_load(ctx, cfg, mem, addr, rsize, extra_offset, unit)
}

@(export)
bac_add_lazy_phi :: proc "c" (
	prc: ^bac.Proc,
	name: string,
	dt: bac.Node_Datatype,
	reg: bac.Node_ID,
	lhs: bac.Node_ID,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac_ssa.add_lazy_phi(prc, name, dt, reg, lhs)
}

@(export)
bac_add_scope :: proc "c" (
	prc: ^bac.Proc,
	name: string,
	cfg: bac.Node_ID,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac_ssa.add_scope(prc, name, cfg)
}

@(export)
bac_arg_gen_finalize :: proc "c" (
	ctx: ^bac.Proc,
	gen: ^bac_ssa.Param_Gen,
) -> (
	[]bac.Param_Spec,
) {
	context = {}
	context.allocator = arna.allocator(ctx.mem)
	return bac_ssa.arg_gen_finalize(ctx, gen)
}

@(export)
bac_add_field_load :: proc "c" (
	ctx: ^bac.Proc,
	name: string,
	dt: bac.Node_Datatype,
	cfg: bac.Node_ID,
	mem: bac.Node_ID,
	base: bac.Node_ID,
	offset: int,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac_ssa.add_field_load(ctx, name, dt, cfg, mem, base, offset)
}

@(export)
bac_add_field_store :: proc "c" (
	ctx: ^bac.Proc,
	name: string,
	cfg: bac.Node_ID,
	mem: bac.Node_ID,
	base: bac.Node_ID,
	offset: int,
	value: bac.Node_ID,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac_ssa.add_field_store(ctx, name, cfg, mem, base, offset, value)
}

@(export)
bac_arg_gen_next :: proc "c" (
	ctx: ^bac.Proc,
	mem: bac.Node_ID,
	gen: ^bac_ssa.Param_Gen,
	name: string,
	apa: bac_ssa.Abi_Param,
	binding_out_0: ^bac.Node_ID,
) -> (
	bac.Node_ID,
) {
	context = {}
	binding_result_0, binding_result_1 := bac_ssa.arg_gen_next(ctx, mem, gen, name, apa)
	binding_out_0^ = binding_result_0
	return binding_result_1
}

@(export)
bac_break_block :: proc "c" (
	prc: ^bac.Proc,
	scope: ^bac.Node_ID,
	state: ^bac_ssa.Block_State,
) {
	context = {}
	bac_ssa.break_block(prc, scope, state)
}

@(export)
bac_decl_local :: proc "c" (
	prc: ^bac.Proc,
	loc: bac.Node_ID,
	name: string,
	type: u64,
) {
	context = {}
	bac_ssa.decl_local(prc, loc, name, type)
}

@(export)
bac_compute_index_offset :: proc "c" (
	ctx: ^bac.Proc,
	base: bac.Node_ID,
	index: bac.Node_ID,
	stride: i64,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac_ssa.compute_index_offset(ctx, base, index, stride)
}

@(export)
bac_end_block :: proc "c" (
	prc: ^bac.Proc,
	scope: ^bac.Node_ID,
	state: ^bac_ssa.Block_State,
) {
	context = {}
	bac_ssa.end_block(prc, scope, state)
}

@(export)
bac_end_else :: proc "c" (
	prc: ^bac.Proc,
	else_scope: ^bac.Node_ID,
	state: ^bac_ssa.If_State,
) {
	context = {}
	bac_ssa.end_else(prc, else_scope, state)
}

@(export)
bac_add_dbg_scope :: proc "c" (
	prc: ^bac.Proc,
	name: string,
	inputs: []bac.Node_ID,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac.add_dbg_scope(prc, name, inputs)
}

@(export)
bac_add_c_int :: proc "c" (
	prc: ^bac.Proc,
	name: string,
	dt: bac.Node_Datatype,
	value: i64,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac.add_c_int(prc, name, dt, value)
}

@(export)
bac_add_always :: proc "c" (
	prc: ^bac.Proc,
	name: string,
	inputs: []bac.Node_ID,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac.add_always(prc, name, inputs)
}

@(export)
bac_add_bin_op :: proc "c" (
	prc: ^bac.Proc,
	name: string,
	type: bac.Bin_Op,
	dt: bac.Node_Datatype,
	lhs: bac.Node_ID,
	rhs: bac.Node_ID,
	lane: bac.Lane_Type,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac.add_bin_op(prc, name, type, dt, lhs, rhs, lane)
}

@(export)
bac_add_call :: proc "c" (
	prc: ^bac.Proc,
	name: string,
	inputs: []bac.Node_ID,
	extra: bac.Call,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac.add_call(prc, name, inputs, extra)
}

@(export)
bac_add_dbg_sym_decl :: proc "c" (
	prc: ^bac.Proc,
	name: string,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac.add_dbg_sym_decl(prc, name)
}

@(export)
bac_add_global :: proc "c" (
	prc: ^bac.Proc,
	name: string,
	idx: u32,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac.add_global(prc, name, idx)
}

@(export)
bac_add_merge_mem :: proc "c" (
	prc: ^bac.Proc,
	name: string,
	inputs: []bac.Node_ID,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac.add_merge_mem(prc, name, inputs)
}

@(export)
bac_add_trap :: proc "c" (
	prc: ^bac.Proc,
	name: string,
	inputs: []bac.Node_ID,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac.add_trap(prc, name, inputs)
}

@(export)
bac_init_custom_fmt :: proc "c" (
) {
	context = {}
	bac.init_custom_fmt()
}

@(export)
bac_end_if :: proc "c" (
	prc: ^bac.Proc,
	then_scope: ^bac.Node_ID,
	state: ^bac_ssa.If_State,
) {
	context = {}
	bac_ssa.end_if(prc, then_scope, state)
}

@(export)
bac_make_call :: proc "c" (
	prc: ^bac.Proc,
	args: []bac.Node_ID,
	extra: bac.Call,
	binding_out_0: ^bac.Node_ID,
) -> (
	bac.Node_ID,
) {
	context = {}
	binding_result_0, binding_result_1 := bac_ssa.make_call(prc, args, extra)
	binding_out_0^ = binding_result_0
	return binding_result_1
}

@(export)
bac_start_block :: proc "c" (
	state: ^bac_ssa.Block_State,
) {
	context = {}
	bac_ssa.start_block(state)
}

@(export)
bac_start_else :: proc "c" (
	prc: ^bac.Proc,
	then_scope: ^bac.Node_ID,
	state: ^bac_ssa.If_State,
) {
	context = {}
	bac_ssa.start_else(prc, then_scope, state)
}

@(export)
bac_get_scope_value :: proc "c" (
	prc: ^bac.Proc,
	scope: bac.Node_ID,
	idx: int,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac_ssa.get_scope_value(prc, scope, idx)
}

@(export)
bac_end_loop :: proc "c" (
	prc: ^bac.Proc,
	node_scope: ^bac.Node_ID,
	state: ^bac_ssa.Loop_State,
) {
	context = {}
	bac_ssa.end_loop(prc, node_scope, state)
}

@(export)
bac_loop_control :: proc "c" (
	variant: bac_ssa.Loop_Control,
	ctx: ^bac.Proc,
	scope: bac.Node_ID,
	loop: ^bac_ssa.Loop_State,
) {
	context = {}
	bac_ssa.loop_control(variant, ctx, scope, loop)
}

@(export)
bac_start_if :: proc "c" (
	prc: ^bac.Proc,
	scope: bac.Node_ID,
	state: ^bac_ssa.If_State,
	cond: bac.Node_ID,
) {
	context = {}
	bac_ssa.start_if(prc, scope, state, cond)
}

@(export)
bac_start_loop_increment :: proc "c" (
	prc: ^bac.Proc,
	node_scope: ^bac.Node_ID,
	state: ^bac_ssa.Loop_State,
) {
	context = {}
	bac_ssa.start_loop_increment(prc, node_scope, state)
}

@(export)
bac_start_loop :: proc "c" (
	prc: ^bac.Proc,
	scope: bac.Node_ID,
	state: ^bac_ssa.Loop_State,
) {
	context = {}
	bac_ssa.start_loop(prc, scope, state)
}

