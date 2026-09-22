package builder

import bac ".."
import "../../vendored/gam/util/arna"
import "core:fmt"
import "core:mem"
import "core:slice"

Graph :: bac.Graph
get_node :: bac.get_node

btype :: #force_inline proc(node: bac.Expanded_Node) -> Node_Type {
	return Node_Type(node.rtype)
}

builder_extra :: proc {
	builder_extra_node,
	builder_extra_node_id,
}

builder_extra_node :: #force_inline proc(
	graph: ^bac.Graph,
	node: ^bac.Node,
	$T: typeid,
) -> ^T {
	if graph.inheritance_table[node.rtype] & (1 << inherit_idx_of(T)) == 0 {
		return nil
	}
	return (^T)(&node.extra)
}

builder_extra_node_id :: #force_inline proc(
	graph: ^bac.Graph,
	id: bac.Node_ID,
	$T: typeid,
) -> ^T {
	return builder_extra_node(graph, get_node(graph, id), T)
}

If_State :: struct {
	if_:     bac.Node_ID,
	using _: struct #raw_union {
		else_scope: bac.Node_ID,
		then_scope: bac.Node_ID,
	},
}

start_if :: proc(
	graph: ^bac.Graph,
	scope: bac.Node_ID,
	state: ^If_State,
	cond: bac.Node_ID,
) {
	snode := expand_node(graph, scope)
	state.if_ = bac.add_if(graph, "if", snode.inps[0], cond)
	state.else_scope = bac.clone(graph, scope)

	then := bac.add_then(graph, "then", state.if_)
	bac.set_input(graph, scope, 0, then)
}

end_if :: proc(graph: ^bac.Graph, then_scope: ^bac.Node_ID, state: ^If_State) {
	start_else(graph, then_scope, state)
	end_else(graph, then_scope, state)
}

start_else :: proc(
	graph: ^bac.Graph,
	then_scope: ^bac.Node_ID,
	state: ^If_State,
) {
	else_ := bac.add_else(graph, "else", state.if_)
	bac.set_input(graph, state.else_scope, 0, else_)
	then_scope^, state.then_scope = state.else_scope, then_scope^
}

end_else :: proc(
	graph: ^bac.Graph,
	else_scope: ^bac.Node_ID,
	state: ^If_State,
) {
	else_scope^ = merge_scopes(graph, state.then_scope, else_scope^)
}

Block_State :: struct {
	end_scope: bac.Node_ID,
}

start_block :: proc(state: ^Block_State) {
	state^ = {}
}

break_block :: proc(
	graph: ^bac.Graph,
	scope: ^bac.Node_ID,
	state: ^Block_State,
) {
	state.end_scope = merge_scopes(graph, state.end_scope, scope^)
	scope^ = 0
}

end_block :: proc(
	graph: ^bac.Graph,
	scope: ^bac.Node_ID,
	state: ^Block_State,
) {
	state.end_scope = merge_scopes(graph, state.end_scope, scope^)
	scope^ = state.end_scope
}

Loop_Control :: enum int {
	Break,
	Continue,
}

Loop_State :: struct {
	scope:  bac.Node_ID,
	scopes: [Loop_Control]bac.Node_ID,
}

start_loop :: proc(graph: ^bac.Graph, scope: bac.Node_ID, state: ^Loop_State) {
	snode := expand_node(graph, scope)
	loop := bac.add_loop(graph, "loop", snode.inps[0])
	bac.set_input(graph, scope, 0, loop)
	state.scope = bac.clone(graph, scope)

	bac.add_output(graph, state.scope, 0, 0)

	snode = expand_node(graph, scope)
	for i in 1 ..< snode.input_count {
		bac.set_input(graph, scope, i, state.scope)
	}
}

start_loop_increment :: proc(
	graph: ^bac.Graph,
	node_scope: ^bac.Node_ID,
	state: ^Loop_State,
) {
	node_scope^ = merge_scopes(graph, node_scope^, state.scopes[.Continue])
	state.scopes[.Continue] = 0
}

end_loop :: proc(
	graph: ^bac.Graph,
	node_scope: ^bac.Node_ID,
	state: ^Loop_State,
) {
	start_loop_increment(graph, node_scope, state)

	init := expand_node(graph, state.scope)
	loop := init.inps[0]
	assert(get_node(graph, loop).itype == .Loop)

	bscope := node_scope^
	if bscope != 0 {
		backedge := expand_node(graph, bscope)
		assert(init.input_count == backedge.input_count)
		for i in 1 ..< init.input_count {
			init := init.inps[i]
			inode := expand_node(graph, init)
			bnode := expand_node(graph, backedge.inps[i])
			if btype(inode) != .Lazy_Phi || inode.inps[0] != loop do continue

			for {
				scp := builder_extra(graph, bnode, Scope)
				if scp == nil || !scp.done || bnode.inps[0] == loop do break
				bnode = expand_node(graph, bnode.inps[i])
			}

			if btype(bnode) == .Scope || inode.node == bnode.node {
				bac.subsume(graph, inode.inps[1], init)
			} else {
				bac.connect(graph, init, bac.get_node_id(graph, bnode))
				inode.itype = .Phi
				id := bac.intern(graph, init)
				if id != init {
					bac.subsume(graph, id, init)
				}
			}
		}

		assert(get_node(graph, init.inps[0]).itype == .Loop)
		bac.connect(graph, init.inps[0], backedge.inps[0])
	}

	node_scope^ = state.scopes[.Break]

	if node_scope^ != 0 {
		exit := expand_node(graph, node_scope^)
		for i in 1 ..< exit.input_count {
			enode := expand_node(graph, exit.inps[i])
			if btype(enode) == .Scope && enode.inps[0] == loop {
				bac.set_input(graph, node_scope^, i, init.inps[i])
			}
		}
	}

	builder_extra(graph, state.scope, Scope).done = true
	bac.remove_output(graph, state.scope, {id = 0, idx = 0})

	if bscope != 0 {
		bac.delete_node(graph, bscope)
	} else {
		for out in bac.get_outputs(graph, loop) {
			onode := expand_node(graph, out.id)
			if btype(onode) == .Lazy_Phi {
				bac.subsume(graph, onode.inps[1], out.id)
			}
		}

		bac.subsume(graph, bac.get_inputs(graph, loop)[0], loop)
	}

	return
}

loop_control :: proc(
	variant: Loop_Control,
	ctx: ^bac.Graph,
	scope: bac.Node_ID,
	loop: ^Loop_State,
) {
	base_size := get_node(ctx, loop.scope).input_count
	truncate_scope(ctx, scope, base_size)
	loop.scopes[variant] = merge_scopes(ctx, scope, loop.scopes[variant])
}

set_scope_value :: proc(
	graph: ^bac.Graph,
	scope: bac.Node_ID,
	#any_int idx: int,
	value: bac.Node_ID,
) {
	get_scope_value(graph, scope, idx)
	bac.set_input(graph, scope, idx, value)
}

get_scope_value :: proc(
	graph: ^bac.Graph,
	scope: bac.Node_ID,
	#any_int idx: int,
) -> bac.Node_ID {
	snode := get_node(graph, scope)
	assert(Node_Type(snode.rtype) == .Scope)

	val := bac.get_inputs(graph, snode)[idx]
	vnode := expand_node(graph, val)
	loop_scope := builder_extra(graph, vnode, Scope)
	if loop_scope != nil {
		pval := val
		val = get_scope_value(graph, val, idx)
		cvnode := expand_node(graph, val)
		if (btype(cvnode) != .Lazy_Phi || vnode.inps[0] != cvnode.inps[0]) &&
		   !loop_scope.done {
			assert(get_node(graph, vnode.inps[0]).itype == .Loop)
			val = add_lazy_phi(
				graph,
				"lphi",
				get_node(graph, val).dt,
				vnode.inps[0],
				val,
			)
			bac.set_input(graph, pval, idx, val)
		}
		bac.set_input(graph, scope, idx, val)
	}

	return val
}

push_scope_value :: proc(
	graph: ^bac.Graph,
	scope: bac.Node_ID,
	value: bac.Node_ID,
) -> int {
	scope_node := get_node(graph, scope)
	assert(Node_Type(scope_node.rtype) == .Scope)
	return bac.connect(graph, scope, value)
}

truncate_scope :: proc(
	graph: ^bac.Graph,
	scope: bac.Node_ID,
	#any_int to_len: int,
) {
	if scope == 0 do return

	snode := expand_node(graph, scope)
	assert(btype(snode) == .Scope)
	assert(to_len <= int(snode.input_count))

	for &inp, i in snode.inps[to_len:] {
		bac.remove_output(graph, inp, {idx = to_len + i, id = scope})
		inp = 0
	}

	snode.input_count = u16(to_len)
}

merge_scopes :: proc(
	graph: ^bac.Graph,
	lctrl: bac.Node_ID,
	rctrl: bac.Node_ID,
) -> bac.Node_ID {
	if lctrl == 0 do return rctrl
	if rctrl == 0 do return lctrl

	lnode := expand_node(graph, lctrl)
	assert(btype(lnode) == .Scope)
	rnode := expand_node(graph, rctrl)
	assert(btype(rnode) == .Scope)

	assert(lnode.input_count == rnode.input_count)

	region := bac.add_region(
		graph,
		"reg",
		{lnode.inps[0], rnode.inps[0], graph.start},
	)

	for i in 1 ..< lnode.input_count {
		if lnode.inps[i] == rnode.inps[i] do continue
		lvalue := get_scope_value(graph, lctrl, i)
		rvalue := get_scope_value(graph, rctrl, i)
		if lvalue == rvalue do continue
		phi := bac.add_phi(
			graph,
			"phi",
			get_node(graph, lvalue).dt,
			region,
			lvalue,
			rvalue,
		)
		bac.set_input(graph, lctrl, i, phi)
	}

	bac.set_input(graph, lctrl, 0, region)
	bac.delete_node(graph, rnode)

	return lctrl
}

inline_call :: proc {
	inline_graph,
	inline_stencil,
}

inline_stencil :: proc(
	graph: ^bac.Graph,
	call: bac.Node_ID,
	from: bac.Stencil,
) {
	slot: arna.Allocator
	fromg: bac.Graph
	fromg.node_spec = &SPEC
	fromg.mem = &slot
	bac.mount_stencil(&fromg, from)
	inline_graph(graph, call, &fromg)
}

inline_graph :: proc(graph: ^bac.Graph, call: bac.Node_ID, from: ^bac.Graph) {
	assert(graph.node_spec == &SPEC)

	bac.add_efficiency_stat(graph, .inlines, 1)
	bac.add_efficiency_stat(graph, .duplicated_nodes, from.gvn)

	context.allocator, _ = arna.scrath()

	bac.verify(graph)

	graph.peeped = false
	graph.max_idepth = max(graph.max_idepth, from.max_idepth)
	bac.invalidate_idepth(graph)

	Ctx :: struct {
		graph:          ^bac.Graph,
		from:           ^bac.Graph,
		projection:     []bac.Node_ID,
		dprojection:    []bac.D_Node_ID,
		reached_return: bool,
	}

	proj_of :: proc(ctx: ^Ctx, id: bac.Node_ID) -> ^bac.Node_ID {
		return &ctx.projection[get_node(ctx.from, id).gvn]
	}

	ctx: Ctx
	ctx.graph = graph
	ctx.graph.current_dnode = 0
	ctx.from = from
	ctx.projection = make([]bac.Node_ID, from.gvn)
	ctx.dprojection = make([]bac.D_Node_ID, from.gdn)

	assert(from.start != from.root_mem)

	call := expand_node(graph, call)
	assert(call.itype == .Call)
	proj_of(&ctx, from.start)^ = graph.start
	proj_of(&ctx, from.entry)^ = call.inps[0]
	proj_of(&ctx, from.root_mem)^ = call.inps[1]
	proj_of(&ctx, from.sym)^ = call.inps[2]

	bac.assert_live_pins(from)

	entry := expand_node(from, from.entry)
	params, starter := bac.assemble_args(
		from,
		int(call.input_cap) - bac.CALL_PREFIX,
	)

	assert(proj_of(&ctx, starter)^ == 0)

	for param, arg_idx in params {
		pnode := expand_node(from, param)
		arg_idx := arg_idx + bac.CALL_PREFIX
		arg := raw_data(call.inps)[arg_idx]
		arg_node := expand_node(graph, arg)
		if pnode.itype == .Start do continue
		if arg_node.itype != .Local {
			assert(pnode.itype != .Local)
		} else {
			assert(arg_node.inps[0] == graph.entry)
			bac.set_input(graph, arg, 0, graph.root_mem)
			if pnode.itype == .Local {
				// project the addr too or we get dups
				assert(ctx.projection[pnode.gvn] == 0)
				ctx.projection[get_node(from, pnode.outs[0].id).gvn] =
					arg_node.outs[0].id
			} else {
				// reach out for the store value
				arg = arg_node.outs[0].id
				arg = bac.get_outputs(graph, arg)[0].id
				arg = bac.get_inputs(graph, arg)[3]
			}
		}
		assert(ctx.projection[pnode.gvn] == 0)
		ctx.projection[pnode.gvn] = arg
	}

	assert(get_node(graph, proj_of(&ctx, from.start)^).itype == .Start)
	assert(proj_of(&ctx, starter)^ == 0)

	clone_along_cfg(&ctx, starter)

	call_end := expand_node(graph, call.outs[0].id)

	if ctx.reached_return {
		from_ret := expand_node(from, from.end)

		for co in call_end.outs {
			coonode := expand_node(ctx.graph, co.id)
			if coonode.itype == .Mem {
				sub := get_node(from, from_ret.inps[1])
				bac.subsume(graph, ctx.projection[sub.gvn], co.id)
			}
			if coonode.itype == .Ret {
				idx := bac.get_extra(graph, coonode, bac.Tup).idx
				ret_idx := bac.RET_PREFIX + idx
				if int(ret_idx) < len(from_ret.inps) {
					sub := get_node(from, from_ret.inps[ret_idx])
					bac.subsume(graph, ctx.projection[sub.gvn], co.id)
				} else {
					psn := bac.add_poison(graph, "irps")
					bac.subsume(graph, psn, co.id)
				}
			}
		}

		bac.pin(graph, proj_of(&ctx, from_ret.inps[0])^)

		for ri in from_ret.inps {
			rinode := get_node(from, ri)
			nd := ctx.projection[rinode.gvn]
			if nd != 0 {
				bac.delete_node(graph, nd)
			}
		}

		bac.unpin(graph, proj_of(&ctx, from_ret.inps[0])^, no_delete = true)

		from_end_ctrl := get_node(from, from_ret.inps[0])

		if graph.end != 0 {
			end_inps := bac.get_inputs(graph, graph.end)
			end_reg := end_inps[0]

			from_ret_reg := expand_node(
				graph,
				ctx.projection[from_end_ctrl.gvn],
			)

			prev_ent_reg_len := get_node(graph, end_reg).input_count

			bac.assert_live_pins(graph)

			#reverse for ri, i in from_ret_reg.inps[:len(from_ret_reg.inps) - 1] {
				rinode := expand_node(graph, ri)
				if rinode.itype == .Trap {
					bac.connect(graph, end_reg, ri)

					#reverse for ei, j in end_inps[1:] {
						if 1 + j < len(from_ret.inps) {
							frnode := get_node(from, from_ret.inps[1 + j])
							assert(frnode.itype == .Phi)
							rnode := expand_node(
								graph,
								ctx.projection[frnode.gvn],
							)
							assert(rnode.itype == .Phi)
							rinp := rnode.inps[1 + i]
							assert(!bac.is_cfg(graph, rinp))
							bac.connect(graph, ei, rinp)
							ordered_remove(graph, &rnode, 1 + i)
						} else {
							inp := bac.add_poison(graph, "trps")
							bac.connect(graph, ei, inp)
						}
					}

					ordered_remove(graph, &from_ret_reg, i)
				}
			}

			bac.assert_live_pins(graph)

			ernode := expand_node(graph, end_reg)
			if int(prev_ent_reg_len) < len(ernode.inps) {
				bac.swap_inputs(
					graph,
					ernode,
					int(prev_ent_reg_len) - 1,
					len(ernode.inps) - 1,
				)
			}

			for inp in ernode.inps {
				fmt.assertf(
					bac.is_cfg(graph, inp) ||
					expand_node(graph, inp).itype == .Dead,
					"%v",
					get_node(graph, inp),
				)
			}

			if len(from_ret_reg.inps) == 1 {
				ctx.projection[from_end_ctrl.gvn] = bac.add_dead(
					graph,
					"rdead",
				)
			}
		}

		bac.subsume(graph, ctx.projection[from_end_ctrl.gvn], call.outs[0].id)
	} else {
		dead := bac.add_dead(graph, "inlnd")
		bac.subsume(graph, dead, call.outs[0].id)
	}

	for out in bac.get_outputs(graph, graph.start) {
		assert(get_node(graph, out.id).itype != .Local)
	}

	bac.assert_live_pins(graph)

	bac.verify(graph)

	clone_along_cfg :: proc(ctx: ^Ctx, root: bac.Node_ID) {
		rnode := expand_node(ctx.from, root)
		if ctx.projection[rnode.gvn] != 0 do return

		if rnode.itype == .Region {
			for i in rnode.inps[:len(rnode.inps) - 1] {
				inode := expand_node(ctx.from, i)
				if ctx.projection[inode.gvn] == 0 {
					return
				}
			}

			for out in rnode.outs {
				onode := expand_node(ctx.from, out.id)
				if onode.itype == .Phi {
					for inp in onode.inps[1:] {
						clone_node(ctx, inp)
					}
				}
			}
		}

		if rnode.itype == .Loop {
			for out in rnode.outs {
				onode := expand_node(ctx.from, out.id)
				if onode.itype == .Phi {
					clone_node(ctx, onode.inps[1])
				}
			}
		}

		clone_node(ctx, root)
		nid := ctx.projection[rnode.gvn]

		for out in rnode.outs {
			if !bac.is_cfg(ctx.from, out.id) do continue

			onode := expand_node(ctx.from, out.id)

			if onode.itype == .Loop && out.idx == 1 {
				proj := ctx.projection[onode.gvn]
				bac.connect(ctx.graph, proj, nid)

				for lout in onode.outs {
					lonode := expand_node(ctx.from, lout.id)
					if lonode.itype == .Phi {
						clone_node(ctx, lonode.inps[2])
						lproj := ctx.projection[lonode.gvn]
						lpnode := get_node(ctx.graph, lproj)
						backedge := get_node(ctx.from, lonode.inps[2])
						bproj := ctx.projection[backedge.gvn]
						assert(Node_Type(lpnode.rtype) == .Lazy_Phi)
						lpnode.itype = .Phi
						bac.connect(ctx.graph, lproj, bproj)
						id := bac.intern(ctx.graph, lproj)
						if id != lproj {
							bac.subsume(ctx.graph, id, lproj)
							assert(ctx.projection[lonode.gvn] == 0)
							ctx.projection[lonode.gvn] = id
						}
					}
				}

				continue
			}

			clone_along_cfg(ctx, out.id)
		}
	}

	clone_node :: proc(ctx: ^Ctx, root: bac.Node_ID) {
		graph := ctx.graph

		node := expand_node(ctx.from, root)
		if ctx.projection[node.gvn] != 0 do return

		input_cap := node.input_cap
		rtype := node.rtype
		input_cap = node.input_count

		if node.itype == .Loop {
			input_cap = 1
		}

		if node.itype == .Phi &&
		   get_node(ctx.from, node.inps[0]).itype == .Loop {
			rtype = u16(Node_Type.Lazy_Phi)
			input_cap = 2
		}

		inps := make([]bac.Node_ID, input_cap)
		for inp, i in node.inps[:input_cap] {
			clone_node(ctx, inp)

			if get_node(ctx.from, inp).itype == .Start {
				bac.current_graph = ctx.from
				fmt.assertf(
					get_node(graph, proj_of(ctx, inp)^).itype == .Start,
					"%v %v",
					inp,
					node,
				)
				bac.current_graph = graph
			}
			inps[i] = proj_of(ctx, inp)^
		}

		if node.itype == .Local {
			if node.inps[0] == ctx.from.root_mem {
				inps[0] = graph.root_mem
			}

			if node.inps[0] == ctx.from.entry {
				inps[0] = graph.entry
			}
		}

		if node.itype == .Return {
			ctx.reached_return = true
			return
		}

		prev := graph.mem.pos

		new_node, id := bac.shallow_clone(graph, node)
		new_node.rtype = rtype
		bac.init_counts(graph, new_node)

		new_node.input_idx = u32(graph.mem.pos / bac.PRECISION)
		_ = arna.clone(graph.mem, inps)
		new_node.input_cap = input_cap
		new_node.input_count = min(new_node.input_count, input_cap)

		new_node.output_idx = u32(graph.mem.pos / bac.PRECISION)
		_ = arna.alloc(
			graph.mem,
			uint(node.output_cap * bac.PRECISION),
			bac.PRECISION,
		)
		new_node.output_count = 0
		new_node.output_cap = node.output_cap

		interned := bac.intern(graph, id)
		if interned != id {
			graph.mem.pos = prev
			id = interned
		} else {
			for inp, i in inps {
				bac.add_output(graph, inp, id, i)
			}

			dn := bac.get_dbg_slot(ctx.from, node)^
			did := bac.clone_dnode(graph, ctx.from, dn, ctx.dprojection)
			bac.get_dbg_slot(graph, new_node)^ = did
			assert(ctx.projection[node.gvn] == 0)

			bac.on_node_creation(graph, new_node)
		}

		ctx.projection[node.gvn] = id
	}
}

ordered_remove :: proc(ctx: ^bac.Graph, node: ^bac.Expanded_Node, i: int) {
	par := bac.get_node_id(ctx, node)
	for inp, j in node.inps[i + 1:] {
		bac.add_output(ctx, inp, par, j + i)
		bac.remove_output(ctx, inp, {idx = j + i + 1, id = par})
	}
	inp := node.inps[i]
	bac.unintern(ctx, par)
	slice.rotate_left(node.inps[i:], 1)
	node.inps = node.inps[:len(node.inps) - 1]
	node.input_count -= 1
	nid := bac.intern(ctx, par)
	assert(par == nid)
	bac.remove_output(ctx, inp, {idx = i, id = par})
}

compute_index_offset :: proc(
	ctx: ^bac.Graph,
	base: Node_ID,
	index: Node_ID,
	#any_int stride: i64,
) -> Node_ID {
	if stride == 0 do return base

	index := index
	if stride > 1 {
		index = bac.add_bin_op(
			ctx,
			"snoff",
			.Mul,
			.I64,
			index,
			bac.add_c_int(ctx, "sst", .I64, stride),
		)
		index = bac.apply_peep(ctx, index)
	}

	return bac.add_bin_op(ctx, "snd", .Add, .I64, base, index)
}

add_field_offset :: proc(
	graph: ^Graph,
	base: Node_ID,
	offset: int,
) -> Node_ID {
	if offset == 0 do return base
	off := bac.add_c_int(graph, "foff", .I64, i64(offset))
	return bac.add_bin_op(graph, "fld", .Add, .I64, base, off)
}

add_field_store :: proc(
	ctx: ^Graph,
	name: string,
	cfg: Node_ID,
	mem: Node_ID,
	base: Node_ID,
	offset: int,
	value: Node_ID,
) -> Node_ID {
	return bac.add_store(
		ctx,
		name,
		cfg,
		mem,
		add_field_offset(ctx, base, offset),
		value,
	)
}

add_arbitrary_store :: proc(
	ctx: ^Graph,
	cfg: Node_ID,
	mem: Node_ID,
	addr: Node_ID,
	value: Node_ID,
	size: int,
	extra_offset := 0,
	unit: bac.Node_Datatype = .I64,
) -> (
	omem: Node_ID,
) {
	omem = mem

	store_unit := unit
	size := min(size - extra_offset, bac.DT_SIZE[unit])
	offset: int

	if bac.DT_SIZE[store_unit] == size {
		omem = add_field_store(
			ctx,
			"asst",
			cfg,
			omem,
			addr,
			offset + extra_offset,
			value,
		)
		return
	}

	for offset < size {
		for bac.DT_SIZE[store_unit] + offset > size {
			store_unit = bac.Node_Datatype(u8(store_unit) - 1)
			assert(store_unit != .Void)
		}

		value := bac.add_un_op(
			ctx,
			"rvl",
			.Cast,
			store_unit,
			bac.add_bin_op(
				ctx,
				"stsh",
				.U_Shr,
				.I64,
				value,
				bac.add_c_int(ctx, "stshoff", .I64, i64(offset * 8)),
			),
		)

		omem = add_field_store(
			ctx,
			"asst",
			cfg,
			omem,
			addr,
			offset + extra_offset,
			value,
		)

		offset += bac.DT_SIZE[store_unit]
	}

	return
}

add_field_load :: proc(
	ctx: ^Graph,
	name: string,
	dt: bac.Node_Datatype,
	cfg: Node_ID,
	mem: Node_ID,
	base: Node_ID,
	offset: int = 0,
) -> Node_ID {
	return bac.add_load(
		ctx,
		name,
		dt,
		cfg,
		mem,
		add_field_offset(ctx, base, offset),
	)
}

add_arbitrary_load :: proc(
	ctx: ^Graph,
	cfg: Node_ID,
	mem: Node_ID,
	addr: Node_ID,
	size: int,
	extra_offset := 0,
	unit: bac.Node_Datatype = .I64,
) -> Node_ID {
	load_unit := unit
	size := min(size - extra_offset, bac.DT_SIZE[unit])
	offset: int
	value: Node_ID

	if load_unit in bac.FLOAT_DTS {
		return add_field_load(
			ctx,
			"asld",
			load_unit,
			cfg,
			mem,
			addr,
			offset + extra_offset,
		)
	}

	for offset < size {
		for bac.DT_SIZE[load_unit] + offset > size {
			assert(load_unit not_in bac.FLOAT_DTS)
			load_unit = bac.Node_Datatype(u8(load_unit) - 1)
			assert(load_unit != .Void)
		}

		load := add_field_load(
			ctx,
			"asld",
			load_unit,
			cfg,
			mem,
			addr,
			offset + extra_offset,
		)

		if load_unit != unit {
			load = bac.add_un_op(ctx, "asxt", .Uext, unit, load)
		}

		if value == 0 {
			value = load
			assert(offset == 0)
		} else {
			value = bac.add_bin_op(
				ctx,
				"aor",
				.Or,
				.I64,
				value,
				bac.add_bin_op(
					ctx,
					"ash",
					.Shl,
					.I64,
					load,
					bac.add_c_int(ctx, "ssham", .I64, i64(offset * 8)),
				),
			)
		}

		offset += bac.DT_SIZE[load_unit]
	}

	return value
}

Param_Gen :: struct {
	vls:         [dynamic]Node_ID,
	spill_start: int,
}

Abi_Param :: struct {
	dt:        [dynamic; 2]bac.Node_Datatype,
	size:      int,
	real_size: int,
	spilled:   bool,
	scalar:    bool,
	copied:    bool,
}

arg_gen_next :: proc(
	ctx: ^Graph,
	mem: Node_ID,
	gen: ^Param_Gen,
	name: string,
	apa: ^Abi_Param,
) -> (
	omem: Node_ID,
	value: Node_ID,
) {
	omem = mem
	gen.spill_start += int(!apa.spilled)

	if apa.scalar {
		dt := apa.dt[0]
		value = bac.add_param(ctx, name, dt, ctx.entry, u32(apa.spilled))
		append(&gen.vls, value)
	} else {
		nd := apa.copied ? ctx.root_mem : ctx.entry
		alloca := bac.add_local(ctx, name, nd)
		bac.get_extra(ctx, alloca, bac.Local).size = i32(apa.real_size)
		bac.get_extra(ctx, alloca, bac.Local).is_param = !apa.copied
		value = bac.add_local_addr(ctx, name, alloca)

		if !apa.copied {
			append(&gen.vls, alloca)
		}
	}

	for dt, j in apa.dt[:(apa.size + 7) / 8] {
		vl := bac.add_param(ctx, name, dt, ctx.entry, 0)
		gen.spill_start += int(j == 1)
		append(&gen.vls, vl)
		omem = add_arbitrary_store(
			ctx,
			ctx.entry,
			omem,
			value,
			vl,
			apa.size,
			j * 8,
			dt,
		)
	}

	return
}

arg_gen_finalize :: proc(ctx: ^Graph, gen: ^Param_Gen) -> []bac.Param_Spec {
	arg_tys := make([]bac.Param_Spec, len(gen.vls))

	j, ri: u32
	for arg in gen.vls {
		anode := get_node(ctx, arg)
		if arga := bac.get_extra(ctx, arg, bac.Tup); arga != nil {
			size: i32
			if arga.idx == 0 {
				arga.idx = j
				j += 1
			} else {
				arga.idx = u32(gen.spill_start) + ri
				size = 8
				ri += 1
			}
			arg_tys[arga.idx] = bac.Param_Spec{anode.dt, size}
		}

		if loca := bac.get_extra(ctx, arg, bac.Local); loca != nil {
			loca.size = i32(mem.align_forward_int(int(loca.size), 8))
			loca.idx = u32(gen.spill_start) + ri
			arg_tys[loca.idx] = bac.Param_Spec{.Void, loca.size}
			loca.is_param = true
			ri += 1
		}
	}
	fmt.assertf(int(j) == gen.spill_start, "%v %v", j, gen.spill_start)
	return arg_tys
}

Builtin_Proc :: enum {
	memcpy,
	memset,
}

init_graph :: proc(graph: ^Graph) {
	graph.start = bac.add_start(graph, "start")
	graph.entry = bac.add_entry(graph, "entry", graph.start)
	graph.root_mem = bac.add_root_mem(graph, "emem", graph.entry)
	graph.sym = bac.add_sym(graph, "sym", graph.entry)
}

make_builtin_proc :: proc(graph: ^Graph, name: Builtin_Proc) {
	init_graph(graph)

	scope := add_scope(graph, "scp", graph.entry)

	memv := push_scope_value(graph, scope, graph.root_mem)

	dst := bac.add_param(graph, "dst", .I64, graph.entry, 0)
	dstv := push_scope_value(graph, scope, dst)

	val, src: Node_ID
	srcv: int
	switch name {
	case .memcpy:
		src = bac.add_param(graph, "src", .I64, graph.entry, 1)
		srcv = push_scope_value(graph, scope, src)
	case .memset:
		val = bac.add_param(graph, "val", .I8, graph.entry, 1)
	}

	len := bac.add_param(graph, "len", .I64, graph.entry, 2)
	lenv := push_scope_value(graph, scope, len)

	loop: Loop_State
	start_loop(graph, scope, &loop)

	if_: If_State
	cond := get_scope_value(graph, scope, lenv)
	start_if(graph, scope, &if_, cond)

	ctrl := bac.get_inputs(graph, scope)[0]
	one := bac.add_c_int(graph, "one", .I64, 1)

	mem := get_scope_value(graph, scope, memv)
	dst = get_scope_value(graph, scope, dstv)
	if src != 0 {
		src = get_scope_value(graph, scope, srcv)
		val = bac.add_load(graph, "ld", .I8, ctrl, mem, src)
	}

	mem = bac.add_store(graph, "st", ctrl, mem, dst, val)
	set_scope_value(graph, scope, memv, mem)

	add := bac.add_bin_op(graph, "add_dst", .Add, .I64, dst, one)
	set_scope_value(graph, scope, dstv, add)

	if src != 0 {
		ads := bac.add_bin_op(graph, "add_src", .Add, .I64, src, one)
		set_scope_value(graph, scope, srcv, ads)
	}

	sub := bac.add_bin_op(graph, "sub_len", .Sub, .I64, cond, one)
	set_scope_value(graph, scope, lenv, sub)

	start_else(graph, &scope, &if_)
	loop_control(.Break, graph, scope, &loop)
	scope = 0
	end_else(graph, &scope, &if_)

	end_loop(graph, &scope, &loop)

	ctrl = bac.get_inputs(graph, scope)[0]
	bac.merge_returns(graph, {ctrl})

	bac.delete_node(graph, scope)
}
