
package bac_lib

import "base:runtime"
import bac "../.."
import bac_ssa "../../ssa"
import bac_arm "../../arm"
import bac_x64 "../../x64"
import bac_wasm "../../wasm"
import bac_regalloc "../../regalloc/"
import arna "../../../utils/arna/"

_ :: bac
_ :: bac_ssa
_ :: bac_arm
_ :: bac_x64
_ :: bac_wasm
_ :: bac_regalloc
_ :: arna
@(export)
bac_add_bin_op :: proc "c" (
	graph: ^bac.Proc,
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
	return bac.add_bin_op(graph, name, type, dt, lhs, rhs, lane)
}

@(export)
bac_add_c_int :: proc "c" (
	graph: ^bac.Proc,
	name: string,
	dt: bac.Node_Datatype,
	value: i64,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac.add_c_int(graph, name, dt, value)
}

@(export)
bac_add_call :: proc "c" (
	graph: ^bac.Proc,
	name: string,
	inputs: []bac.Node_ID,
	extra: bac.Call,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac.add_call(graph, name, inputs, extra)
}

@(export)
bac_add_call_end :: proc "c" (
	graph: ^bac.Proc,
	name: string,
	call: bac.Node_ID,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac.add_call_end(graph, name, call)
}

@(export)
bac_add_copy :: proc "c" (
	graph: ^bac.Proc,
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
	return bac.add_copy(graph, name, ctrl, mem, dst, src, size)
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
bac_add_global :: proc "c" (
	graph: ^bac.Proc,
	name: string,
	idx: u32,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac.add_global(graph, name, idx)
}

@(export)
bac_add_global_addr :: proc "c" (
	graph: ^bac.Proc,
	name: string,
	global: bac.Node_ID,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac.add_global_addr(graph, name, global)
}

@(export)
bac_add_local :: proc "c" (
	graph: ^bac.Proc,
	name: string,
	mem: bac.Node_ID,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac.add_local(graph, name, mem)
}

@(export)
bac_add_local_addr :: proc "c" (
	graph: ^bac.Proc,
	name: string,
	local: bac.Node_ID,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac.add_local_addr(graph, name, local)
}

@(export)
bac_add_mem :: proc "c" (
	graph: ^bac.Proc,
	name: string,
	ctrl: bac.Node_ID,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac.add_mem(graph, name, ctrl)
}

@(export)
bac_add_proc_addr :: proc "c" (
	graph: ^bac.Proc,
	name: string,
	idx: u32,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac.add_proc_addr(graph, name, idx)
}

@(export)
bac_add_ret :: proc "c" (
	graph: ^bac.Proc,
	name: string,
	dt: bac.Node_Datatype,
	call_end: bac.Node_ID,
	idx: u32,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac.add_ret(graph, name, dt, call_end, idx)
}

@(export)
bac_add_set :: proc "c" (
	graph: ^bac.Proc,
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
	return bac.add_set(graph, name, ctrl, mem, dst, value, size)
}

@(export)
bac_add_trap :: proc "c" (
	graph: ^bac.Proc,
	name: string,
	inputs: []bac.Node_ID,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac.add_trap(graph, name, inputs)
}

@(export)
bac_add_un_op :: proc "c" (
	graph: ^bac.Proc,
	name: string,
	type: bac.Un_Op,
	dt: bac.Node_Datatype,
	oprnd: bac.Node_ID,
	lane: bac.Lane_Type,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac.add_un_op(graph, name, type, dt, oprnd, lane)
}

@(export)
bac_apply_peep :: proc "c" (
	graph: ^bac.Proc,
	id: bac.Node_ID,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac.apply_peep(graph, id)
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
bac_compact :: proc "c" (
	graph: ^bac.Proc,
) {
	context = {}
	bac.compact(graph)
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
bac_connect :: proc "c" (
	graph: ^bac.Proc,
	use: bac.Node_ID,
	def: bac.Node_ID,
) -> (
	int,
) {
	context = {}
	return bac.connect(graph, use, def)
}

@(export)
bac_delete_node_node :: proc "c" (
	graph: ^bac.Proc,
	node: ^bac.Node,
) {
	context = {}
	bac.delete_node_node(graph, node)
}

@(export)
bac_delete_node_node_id :: proc "c" (
	graph: ^bac.Proc,
	id: bac.Node_ID,
) {
	context = {}
	bac.delete_node_node_id(graph, id)
}

@(export)
bac_emit_function :: proc "c" (
	ctx: bac.Codegen_Emit_Ctx,
) -> (
	bac.Codegen_Output,
) {
	context = {}
	return bac.emit_function(ctx)
}

@(export)
bac_expand_node :: proc "c" (
	graph: ^bac.Proc,
	id: bac.Node_ID,
) -> (
	bac.Expanded_Node,
) {
	context = {}
	return bac.expand_node(graph, id)
}

@(export)
bac_find_node :: proc "c" (
	graph: ^bac.Proc,
	kind: bac.Node_Type,
	on: bac.Node_ID,
) -> (
	bac.Node_ID,
	bool,
) {
	context = {}
	return bac.find_node(graph, kind, on)
}

@(export)
bac_find_or_create_node :: proc "c" (
	graph: ^bac.Proc,
	kind: bac.Node_Type,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac.find_or_create_node(graph, kind)
}

@(export)
bac_get_inputs_node :: proc "c" (
	graph: ^bac.Proc,
	node: ^bac.Node,
) -> (
	[]bac.Node_ID,
) {
	context = {}
	return bac.get_inputs_node(graph, node)
}

@(export)
bac_get_inputs_node_id :: proc "c" (
	graph: ^bac.Proc,
	id: bac.Node_ID,
) -> (
	[]bac.Node_ID,
) {
	context = {}
	return bac.get_inputs_node_id(graph, id)
}

@(export)
bac_get_node :: proc "c" (
	graph: ^bac.Proc,
	id: bac.Node_ID,
) -> (
	^bac.Node,
) {
	context = {}
	return bac.get_node(graph, id)
}

@(export)
bac_get_stencil :: proc "c" (
	graph: ^bac.Proc,
) -> (
	bac.Stencil,
) {
	context = {}
	return bac.get_stencil(graph)
}

@(export)
bac_get_sym_count :: proc "c" (
	graph: ^bac.Proc,
) -> (
	bac.Node_ID,
	int,
) {
	context = {}
	return bac.get_sym_count(graph)
}

@(export)
bac_init_custom_fmt :: proc "c" (
) {
	context = {}
	bac.init_custom_fmt()
}

@(export)
bac_lane_from_dt :: proc "c" (
	ty: bac.Node_Datatype,
) -> (
	bac.Lane_Type,
	bool,
) {
	context = {}
	return bac.lane_from_dt(ty)
}

@(export)
bac_mount_stencil :: proc "c" (
	graph: ^bac.Proc,
	stencil: bac.Stencil,
) {
	context = {}
	bac.mount_stencil(graph, stencil)
}

@(export)
bac_pin :: proc "c" (
	graph: ^bac.Proc,
	id: bac.Node_ID,
) {
	context = {}
	bac.pin(graph, id)
}

@(export)
bac_schedule_graph :: proc "c" (
	graph: ^bac.Proc,
	gs: ^bac.Schedule,
	purpose: enum int {for_regalloc, for_loopopt},
	scratch: runtime.Allocator,
) {
	context = {}
	bac.schedule_graph(graph, gs, purpose, scratch)
}

@(export)
bac_schedule_peeps :: proc "c" (
	graph: ^bac.Proc,
	schedule: ^bac.Schedule,
) {
	context = {}
	bac.schedule_peeps(graph, schedule)
}

@(export)
bac_set_input :: proc "c" (
	graph: ^bac.Proc,
	id: bac.Node_ID,
	idx: int,
	value: bac.Node_ID,
	subsume_on_intern: bool,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac.set_input(graph, id, idx, value, subsume_on_intern)
}

@(export)
bac_set_local_size :: proc "c" (
	graph: ^bac.Proc,
	loc: bac.Node_ID,
	size: i32,
) {
	context = {}
	bac.set_local_size(graph, loc, size)
}

@(export)
bac_sloc_scope :: proc "c" (
	graph: ^bac.Proc,
	sloc: bac.Sloc,
) -> (
	^bac.Proc,
	bac.Sloc,
) {
	context = {}
	return bac.sloc_scope(graph, sloc)
}

@(export)
bac_sym_iter_next :: proc "c" (
	graph: ^bac.Proc,
	sym: bac.Node_ID,
	iter: ^int,
) -> (
	bac.Sym_Ref,
	bool,
) {
	context = {}
	return bac.sym_iter_next(graph, sym, iter)
}

@(export)
bac_take_dbg_data :: proc "c" (
	graph: ^bac.Proc,
	sched: ^bac.Schedule,
	data: ^bac.Dbg_Data,
	scratch: runtime.Allocator,
) {
	context = {}
	bac.take_dbg_data(graph, sched, data, scratch)
}

@(export)
bac_unpin :: proc "c" (
	graph: ^bac.Proc,
	id: bac.Node_ID,
	no_delete: bool,
) {
	context = {}
	bac.unpin(graph, id, no_delete)
}

@(export)
bac_regalloc_regalloc :: proc "c" (
	ra: ^bac.Regalloc,
	graph: ^bac.Proc,
	sched: ^bac.Schedule,
	mode: bac_regalloc.Mode,
	scratch: runtime.Allocator,
) -> (
	bac.Regalloc_Output,
) {
	context = {}
	return bac_regalloc.regalloc(ra, graph, sched, mode, scratch)
}

@(export)
bac_ssa_add_arbitrary_load :: proc "c" (
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
bac_ssa_add_arbitrary_store :: proc "c" (
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
bac_ssa_add_call :: proc "c" (
	graph: ^bac.Proc,
	args: []bac.Node_ID,
	extra: bac.Call,
) -> (
	bac.Node_ID,
	bac.Node_ID,
) {
	context = {}
	return bac_ssa.add_call(graph, args, extra)
}

@(export)
bac_ssa_add_field_load :: proc "c" (
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
bac_ssa_add_field_offset :: proc "c" (
	graph: ^bac.Proc,
	base: bac.Node_ID,
	offset: int,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac_ssa.add_field_offset(graph, base, offset)
}

@(export)
bac_ssa_add_field_store :: proc "c" (
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
bac_ssa_add_scope :: proc "c" (
	graph: ^bac.Proc,
	name: string,
	cfg: bac.Node_ID,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac_ssa.add_scope(graph, name, cfg)
}

@(export)
bac_ssa_arg_gen_finalize :: proc "c" (
	ctx: ^bac.Proc,
	gen: ^bac_ssa.Param_Gen,
) -> (
	[]bac.Param_Spec,
) {
	context = {}
	return bac_ssa.arg_gen_finalize(ctx, gen)
}

@(export)
bac_ssa_arg_gen_next :: proc "c" (
	ctx: ^bac.Proc,
	mem: bac.Node_ID,
	gen: ^bac_ssa.Param_Gen,
	name: string,
	apa: ^bac_ssa.Abi_Param,
) -> (
	bac.Node_ID,
	bac.Node_ID,
) {
	context = {}
	return bac_ssa.arg_gen_next(ctx, mem, gen, name, apa)
}

@(export)
bac_ssa_break_block :: proc "c" (
	graph: ^bac.Proc,
	scope: ^bac.Node_ID,
	state: ^bac_ssa.Block_State,
) {
	context = {}
	bac_ssa.break_block(graph, scope, state)
}

@(export)
bac_ssa_compute_index_offset :: proc "c" (
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
bac_ssa_decl_local :: proc "c" (
	graph: ^bac.Proc,
	loc: bac.Node_ID,
	name: string,
	type: u64,
) {
	context = {}
	bac_ssa.decl_local(graph, loc, name, type)
}

@(export)
bac_ssa_delete_scope :: proc "c" (
	graph: ^bac.Proc,
	scope: bac.Node_ID,
) {
	context = {}
	bac_ssa.delete_scope(graph, scope)
}

@(export)
bac_ssa_end_block :: proc "c" (
	graph: ^bac.Proc,
	scope: ^bac.Node_ID,
	state: ^bac_ssa.Block_State,
) {
	context = {}
	bac_ssa.end_block(graph, scope, state)
}

@(export)
bac_ssa_end_else :: proc "c" (
	graph: ^bac.Proc,
	else_scope: ^bac.Node_ID,
	state: ^bac_ssa.If_State,
) {
	context = {}
	bac_ssa.end_else(graph, else_scope, state)
}

@(export)
bac_ssa_end_if :: proc "c" (
	graph: ^bac.Proc,
	then_scope: ^bac.Node_ID,
	state: ^bac_ssa.If_State,
) {
	context = {}
	bac_ssa.end_if(graph, then_scope, state)
}

@(export)
bac_ssa_end_loop :: proc "c" (
	graph: ^bac.Proc,
	node_scope: ^bac.Node_ID,
	state: ^bac_ssa.Loop_State,
) {
	context = {}
	bac_ssa.end_loop(graph, node_scope, state)
}

@(export)
bac_ssa_get_scope_value :: proc "c" (
	graph: ^bac.Proc,
	scope: bac.Node_ID,
	idx: int,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac_ssa.get_scope_value(graph, scope, idx)
}

@(export)
bac_ssa_inline_graph :: proc "c" (
	graph: ^bac.Proc,
	call: bac.Node_ID,
	from: ^bac.Proc,
) {
	context = {}
	bac_ssa.inline_graph(graph, call, from)
}

@(export)
bac_ssa_inline_stencil :: proc "c" (
	graph: ^bac.Proc,
	call: bac.Node_ID,
	from: bac.Stencil,
) {
	context = {}
	bac_ssa.inline_stencil(graph, call, from)
}

@(export)
bac_ssa_loop_control :: proc "c" (
	variant: bac_ssa.Loop_Control,
	ctx: ^bac.Proc,
	scope: bac.Node_ID,
	loop: ^bac_ssa.Loop_State,
) {
	context = {}
	bac_ssa.loop_control(variant, ctx, scope, loop)
}

@(export)
bac_ssa_loopopt :: proc "c" (
	graph: ^bac.Proc,
) -> (
	bool,
) {
	context = {}
	return bac_ssa.loopopt(graph)
}

@(export)
bac_ssa_memopt :: proc "c" (
	graph: ^bac.Proc,
) -> (
	bool,
) {
	context = {}
	return bac_ssa.memopt(graph)
}

@(export)
bac_ssa_merge_returns :: proc "c" (
	graph: ^bac.Proc,
	args: []bac.Node_ID,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac_ssa.merge_returns(graph, args)
}

@(export)
bac_ssa_push_scope_value :: proc "c" (
	graph: ^bac.Proc,
	scope: bac.Node_ID,
	value: bac.Node_ID,
	name: string,
	type: u64,
) -> (
	int,
) {
	context = {}
	return bac_ssa.push_scope_value(graph, scope, value, name, type)
}

@(export)
bac_ssa_set_scope_value :: proc "c" (
	graph: ^bac.Proc,
	scope: bac.Node_ID,
	idx: int,
	value: bac.Node_ID,
) {
	context = {}
	bac_ssa.set_scope_value(graph, scope, idx, value)
}

@(export)
bac_ssa_start_block :: proc "c" (
	state: ^bac_ssa.Block_State,
) {
	context = {}
	bac_ssa.start_block(state)
}

@(export)
bac_ssa_start_else :: proc "c" (
	graph: ^bac.Proc,
	then_scope: ^bac.Node_ID,
	state: ^bac_ssa.If_State,
) {
	context = {}
	bac_ssa.start_else(graph, then_scope, state)
}

@(export)
bac_ssa_start_if :: proc "c" (
	graph: ^bac.Proc,
	scope: bac.Node_ID,
	state: ^bac_ssa.If_State,
	cond: bac.Node_ID,
) {
	context = {}
	bac_ssa.start_if(graph, scope, state, cond)
}

@(export)
bac_ssa_start_loop :: proc "c" (
	graph: ^bac.Proc,
	scope: bac.Node_ID,
	state: ^bac_ssa.Loop_State,
) {
	context = {}
	bac_ssa.start_loop(graph, scope, state)
}

@(export)
bac_ssa_start_loop_increment :: proc "c" (
	graph: ^bac.Proc,
	node_scope: ^bac.Node_ID,
	state: ^bac_ssa.Loop_State,
) {
	context = {}
	bac_ssa.start_loop_increment(graph, node_scope, state)
}

@(export)
bac_ssa_start_proc :: proc "c" (
	graph: ^bac.Proc,
	mem: ^arna.Allocator,
) -> (
	bac.Node_ID,
) {
	context = {}
	return bac_ssa.start_proc(graph, mem)
}

@(export)
bac_ssa_truncate_scope :: proc "c" (
	graph: ^bac.Proc,
	scope: bac.Node_ID,
	to_len: int,
) {
	context = {}
	bac_ssa.truncate_scope(graph, scope, to_len)
}

