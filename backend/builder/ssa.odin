package builder

import backend ".."
import "../../vendored/gam/util/arna"
import "core:fmt"
import "core:mem"
import "core:sort"

Node_ID :: backend.Node_ID
Graph :: backend.Graph

btype :: #force_inline proc(node: backend.Expanded_Node) -> Builder_Node_Type {
	return Builder_Node_Type(node.rtype)
}

// mirrors backend.graph_extra, but resolved against this package's own
// (generated) inherit_idx_of, since that generic proc's body is bound to
// whichever package declares it and backend's copy knows nothing about
// Builder-only extra-data types such as Scope
builder_extra :: proc {
	builder_extra_node,
	builder_extra_node_id,
}

builder_extra_node :: #force_inline proc(
	graph: ^backend.Graph,
	node: ^backend.Node,
	$T: typeid,
) -> ^T {
	if graph.inheritance_table[node.rtype] & (1 << inherit_idx_of(T)) == 0 {
		return nil
	}
	return (^T)(&node.extra)
}

builder_extra_node_id :: #force_inline proc(
	graph: ^backend.Graph,
	id: backend.Node_ID,
	$T: typeid,
) -> ^T {
	return builder_extra_node(graph, backend.graph_get(graph, id), T)
}

If_State :: struct {
	if_:     backend.Node_ID,
	using _: struct #raw_union {
		else_scope: backend.Node_ID,
		then_scope: backend.Node_ID,
	},
}

graph_start_if :: proc(
	graph: ^backend.Graph,
	scope: backend.Node_ID,
	state: ^If_State,
	cond: backend.Node_ID,
) {
	snode := backend.graph_expand(graph, scope)
	state.if_ = backend.graph_add_if(graph, "if", snode.inps[0], cond)
	state.else_scope = backend.graph_clone(graph, scope)

	then := backend.graph_add_then(graph, "then", state.if_)
	backend.graph_set_input(graph, scope, 0, then)
}

graph_start_else :: proc(
	graph: ^backend.Graph,
	then_scope: ^backend.Node_ID,
	state: ^If_State,
) {
	else_ := backend.graph_add_else(graph, "else", state.if_)
	backend.graph_set_input(graph, state.else_scope, 0, else_)
	then_scope^, state.then_scope = state.else_scope, then_scope^
}

graph_end_else :: proc(
	graph: ^backend.Graph,
	else_scope: ^backend.Node_ID,
	state: ^If_State,
) {
	else_scope^ = graph_merge_scopes(graph, state.then_scope, else_scope^)
}

Block_State :: struct {
	end_scope: backend.Node_ID,
}

graph_start_block :: proc(state: ^Block_State) {
	state^ = {}
}

graph_break_block :: proc(
	graph: ^backend.Graph,
	scope: ^backend.Node_ID,
	state: ^Block_State,
) {
	state.end_scope = graph_merge_scopes(graph, state.end_scope, scope^)
	scope^ = 0
}

graph_end_block :: proc(
	graph: ^backend.Graph,
	scope: ^backend.Node_ID,
	state: ^Block_State,
) {
	state.end_scope = graph_merge_scopes(graph, state.end_scope, scope^)
	scope^ = state.end_scope
}

Loop_Control :: enum int {
	Break,
	Continue,
}

Loop_State :: struct {
	scope:  backend.Node_ID,
	scopes: [Loop_Control]backend.Node_ID,
}

graph_start_loop :: proc(
	graph: ^backend.Graph,
	scope: backend.Node_ID,
	state: ^Loop_State,
) {
	snode := backend.graph_expand(graph, scope)
	loop := backend.graph_add_loop(graph, "loop", snode.inps[0])
	backend.graph_set_input(graph, scope, 0, loop)
	state.scope = backend.graph_clone(graph, scope)

	backend.graph_add_output(graph, state.scope, 0, 0)

	snode = backend.graph_expand(graph, scope)
	for i in 1 ..< snode.input_count {
		backend.graph_set_input(graph, scope, i, state.scope)
	}
}

graph_end_loop :: proc(
	graph: ^backend.Graph,
	node_scope: ^backend.Node_ID,
	state: ^Loop_State,
) {
	node_scope^ = graph_merge_scopes(
		graph,
		node_scope^,
		state.scopes[.Continue],
	)

	init := backend.graph_expand(graph, state.scope)
	loop := init.inps[0]
	assert(backend.graph_get(graph, loop).itype == .Loop)

	bscope := node_scope^
	if bscope != 0 {
		backedge := backend.graph_expand(graph, bscope)
		assert(init.input_count == backedge.input_count)
		for i in 1 ..< init.input_count {
			init := init.inps[i]
			inode := backend.graph_expand(graph, init)
			bnode := backend.graph_expand(graph, backedge.inps[i])
			if btype(inode) != .Lazy_Phi || inode.inps[0] != loop do continue

			for {
				scp := builder_extra(graph, bnode, Scope)
				if scp == nil || !scp.done || bnode.inps[0] == loop do break
				bnode = backend.graph_expand(graph, bnode.inps[i])
			}

			if btype(bnode) == .Scope || inode.node == bnode.node {
				backend.graph_subsume(graph, inode.inps[1], init)
			} else {
				backend.graph_connect(
					graph,
					init,
					backend.graph_id(graph, bnode),
				)
				inode.itype = .Phi
				id := backend.graph_intern(graph, init)
				if id != init do backend.graph_subsume(graph, id, init)
			}
		}

		assert(backend.graph_get(graph, init.inps[0]).itype == .Loop)
		backend.graph_connect(graph, init.inps[0], backedge.inps[0])
	}

	node_scope^ = state.scopes[.Break]

	if node_scope^ != 0 {
		exit := backend.graph_expand(graph, node_scope^)
		for i in 1 ..< exit.input_count {
			enode := backend.graph_expand(graph, exit.inps[i])
			if btype(enode) == .Scope && enode.inps[0] == loop {
				backend.graph_set_input(graph, node_scope^, i, init.inps[i])
			}
		}
	}

	builder_extra(graph, state.scope, Scope).done = true
	backend.graph_remove_output(graph, state.scope, {id = 0, idx = 0})

	if bscope != 0 {
		backend.graph_delete(graph, bscope)
	} else {
		for out in backend.graph_outs(graph, loop) {
			onode := backend.graph_expand(graph, out.id)
			if btype(onode) == .Lazy_Phi {
				backend.graph_subsume(graph, onode.inps[1], out.id)
			}
		}

		backend.graph_subsume(graph, backend.graph_inps(graph, loop)[0], loop)
	}

	return
}

graph_loop_control :: proc(
	variant: Loop_Control,
	ctx: ^backend.Graph,
	scope: backend.Node_ID,
	loop: ^Loop_State,
) {
	base_size := backend.graph_get(ctx, loop.scope).input_count
	graph_truncate_scope(ctx, scope, base_size)
	loop.scopes[variant] = graph_merge_scopes(ctx, scope, loop.scopes[variant])
}

graph_get_scope_value :: proc(
	graph: ^backend.Graph,
	scope: backend.Node_ID,
	#any_int idx: int,
) -> backend.Node_ID {
	snode := backend.graph_get(graph, scope)
	assert(Builder_Node_Type(snode.rtype) == .Scope)

	val := backend.graph_inps(graph, snode)[idx]
	vnode := backend.graph_expand(graph, val)
	loop_scope := builder_extra(graph, vnode, Scope)
	if loop_scope != nil {
		pval := val
		val = graph_get_scope_value(graph, val, idx)
		cvnode := backend.graph_expand(graph, val)
		if (btype(cvnode) != .Lazy_Phi || vnode.inps[0] != cvnode.inps[0]) &&
		   !loop_scope.done {
			assert(backend.graph_get(graph, vnode.inps[0]).itype == .Loop)
			val = graph_add_lazy_phi(
				graph,
				"lphi",
				backend.graph_get(graph, val).dt,
				vnode.inps[0],
				val,
			)
			backend.graph_set_input(graph, pval, idx, val)
		}
		backend.graph_set_input(graph, scope, idx, val)
	}

	return val
}

graph_push_scope_value :: proc(
	graph: ^backend.Graph,
	scope: backend.Node_ID,
	value: backend.Node_ID,
) -> int {
	scope_node := backend.graph_get(graph, scope)
	assert(Builder_Node_Type(scope_node.rtype) == .Scope)
	return backend.graph_connect(graph, scope, value)
}

graph_truncate_scope :: proc(
	graph: ^backend.Graph,
	scope: backend.Node_ID,
	#any_int to_len: int,
) {
	if scope == 0 do return

	snode := backend.graph_expand(graph, scope)
	assert(btype(snode) == .Scope)
	assert(to_len <= int(snode.input_count))

	for &inp, i in snode.inps[to_len:] {
		backend.graph_remove_output(graph, inp, {idx = to_len + i, id = scope})
		inp = 0
	}

	snode.input_count = u16(to_len)
}

graph_merge_scopes :: proc(
	graph: ^backend.Graph,
	lctrl: backend.Node_ID,
	rctrl: backend.Node_ID,
) -> backend.Node_ID {
	if lctrl == 0 do return rctrl
	if rctrl == 0 do return lctrl

	lnode := backend.graph_expand(graph, lctrl)
	assert(btype(lnode) == .Scope)
	rnode := backend.graph_expand(graph, rctrl)
	assert(btype(rnode) == .Scope)

	assert(lnode.input_count == rnode.input_count)

	region := backend.graph_add_region(
		graph,
		"reg",
		{lnode.inps[0], rnode.inps[0], graph.start},
	)

	for i in 1 ..< lnode.input_count {
		if lnode.inps[i] == rnode.inps[i] do continue
		lvalue := graph_get_scope_value(graph, lctrl, i)
		rvalue := graph_get_scope_value(graph, rctrl, i)
		if lvalue == rvalue do continue
		phi := backend.graph_add_phi(
			graph,
			"phi",
			backend.graph_get(graph, lvalue).dt,
			region,
			lvalue,
			rvalue,
		)
		backend.graph_set_input(graph, lctrl, i, phi)
	}

	backend.graph_set_input(graph, lctrl, 0, region)
	backend.graph_delete(graph, rnode)

	return lctrl
}

graph_inline :: proc {
	graph_inline_graph,
	graph_inline_stencil,
}

graph_inline_stencil :: proc(
	graph: ^backend.Graph,
	call: backend.Node_ID,
	from: backend.Stencil,
) {
	slot: arna.Allocator
	fromg: backend.Graph
	fromg.node_spec = &SPEC
	fromg.mem = &slot
	backend.graph_mount_stencil(&fromg, from)
	graph_inline_graph(graph, call, &fromg)
}

graph_inline_graph :: proc(
	graph: ^backend.Graph,
	call: backend.Node_ID,
	from: ^backend.Graph,
) {
	assert(graph.node_spec == &SPEC)

	backend.add_efficiency_stat(graph, .inlines, 1)
	backend.add_efficiency_stat(graph, .duplicated_nodes, from.gvn)

	context.allocator, _ = arna.scrath()

	graph.peeped = false

	Ctx :: struct {
		graph:       ^backend.Graph,
		from:        ^backend.Graph,
		projection:  []backend.Node_ID,
		dprojection: []backend.D_Node_ID,
	}

	proj_of :: proc(ctx: ^Ctx, id: backend.Node_ID) -> ^backend.Node_ID {
		return &ctx.projection[backend.graph_get(ctx.from, id).gvn]
	}

	ctx: Ctx
	ctx.graph = graph
	ctx.from = from
	ctx.projection = make([]backend.Node_ID, from.gvn)
	ctx.dprojection = make([]backend.D_Node_ID, from.gdn)

	call := backend.graph_expand(graph, call)
	assert(call.itype == .Call)
	proj_of(&ctx, from.entry)^ = call.inps[0]
	proj_of(&ctx, from.root_mem)^ = call.inps[1]
	proj_of(&ctx, from.sym)^ = call.inps[2]

	entry := backend.graph_expand(from, from.entry)
	Param_Entry :: bit_field u64 {
		id:           backend.Node_ID | 32,
		is_local_arg: bool            | 1,
		gvn:          u32             | 31,
	}
	starter: backend.Node_ID
	params: [dynamic]Param_Entry
	for o in entry.outs {
		onode := backend.graph_expand(from, o.id)
		is_local_arg := onode.itype == .Local
		is_local_arg &&=
			backend.graph_extra(from, onode, backend.Local).is_param

		if onode.itype == .Param || is_local_arg {
			append(
				&params,
				Param_Entry {
					id = o.id,
					gvn = onode.gvn,
					is_local_arg = is_local_arg,
				},
			)
		}

		if backend.is_cfg(from, o.id) {
			assert(starter == 0)
			starter = o.id
		}
	}

	sort.quick_sort(params[:])

	for i in 0 ..< len(params) {
		param := params[i]
		pnode := backend.graph_expand(from, param.id)
		arg_idx: int
		if param.is_local_arg {
			arg_idx = int(backend.graph_extra(graph, pnode, backend.Local).idx)
		} else {
			arg_idx = int(backend.graph_extra(from, pnode, backend.Tup).idx)
		}
		arg_idx += backend.CALL_PREFIX
		arg := raw_data(call.inps)[arg_idx]
		node := backend.graph_expand(graph, arg)
		if arg_idx < int(call.input_count) {
			assert(node.itype != .Local)
			assert(pnode.itype != .Local)
		} else {
			assert(node.inps[0] == graph.entry)
			backend.graph_set_input(graph, arg, 0, graph.root_mem)
			if !param.is_local_arg {
				// reach out for the store value
				arg = node.outs[0].id
				arg = backend.graph_outs(graph, arg)[0].id
				arg = backend.graph_inps(graph, arg)[3]
			} else {
				// project the addr too or we get dups
				ctx.projection[backend.graph_get(from, pnode.outs[0].id).gvn] =
					node.outs[0].id
			}
		}
		ctx.projection[param.gvn] = arg
	}

	clone_along_cfg(&ctx, starter)

	cend := backend.graph_expand(graph, call.outs[0].id)
	ret := backend.graph_expand(from, from.end)

	for o in cend.outs {
		onode := backend.graph_expand(ctx.graph, o.id)
		if onode.itype == .Mem {
			sub := backend.graph_get(from, ret.inps[1])
			backend.graph_subsume(graph, ctx.projection[sub.gvn], o.id)
		}
		if onode.itype == .Ret {
			idx := backend.graph_extra(graph, onode, backend.Tup).idx
			sub := backend.graph_get(from, ret.inps[backend.RET_PREFIX + idx])
			backend.graph_subsume(graph, ctx.projection[sub.gvn], o.id)
		}
	}

	end_ctrl := backend.graph_get(from, ret.inps[0])
	backend.graph_subsume(graph, ctx.projection[end_ctrl.gvn], call.outs[0].id)

	for out in backend.graph_outs(graph, graph.start) {
		assert(backend.graph_get(graph, out.id).itype != .Local)
	}

	clone_along_cfg :: proc(ctx: ^Ctx, root: backend.Node_ID) {
		node := backend.graph_expand(ctx.from, root)
		if ctx.projection[node.gvn] != 0 do return

		if node.itype == .Region {
			for i in node.inps[:len(node.inps) - 1] {
				inode := backend.graph_expand(ctx.from, i)
				if ctx.projection[inode.gvn] == 0 {
					return
				}
			}

			for out in node.outs {
				onode := backend.graph_expand(ctx.from, out.id)
				if onode.itype == .Phi {
					for inp in onode.inps[1:] {
						clone_node(ctx, inp)
					}
				}
			}
		}

		if node.itype == .Loop {
			for out in node.outs {
				onode := backend.graph_expand(ctx.from, out.id)
				if onode.itype == .Phi {
					clone_node(ctx, onode.inps[1])
				}
			}
		}

		clone_node(ctx, root)
		nid := ctx.projection[node.gvn]

		for out in node.outs {
			if !backend.is_cfg(ctx.from, out.id) do continue

			onode := backend.graph_expand(ctx.from, out.id)

			if onode.itype == .Loop && out.idx == 1 {
				proj := ctx.projection[onode.gvn]
				backend.graph_connect(ctx.graph, proj, nid)

				for lout in onode.outs {
					lonode := backend.graph_expand(ctx.from, lout.id)
					if lonode.itype == .Phi {
						clone_node(ctx, lonode.inps[2])
						lproj := ctx.projection[lonode.gvn]
						lpnode := backend.graph_get(ctx.graph, lproj)
						backedge := backend.graph_get(ctx.from, lonode.inps[2])
						bproj := ctx.projection[backedge.gvn]
						assert(Builder_Node_Type(lpnode.rtype) == .Lazy_Phi)
						lpnode.itype = .Phi
						backend.graph_connect(ctx.graph, lproj, bproj)
						id := backend.graph_intern(ctx.graph, lproj)
						if id != lproj {
							backend.graph_subsume(ctx.graph, id, lproj)
							ctx.projection[lonode.gvn] = id
						}
					}
				}

				continue
			}

			clone_along_cfg(ctx, out.id)
		}
	}

	clone_node :: proc(ctx: ^Ctx, root: backend.Node_ID) {
		graph := ctx.graph

		node := backend.graph_expand(ctx.from, root)
		if ctx.projection[node.gvn] != 0 do return

		input_cap := node.input_cap
		rtype := node.rtype
		if node.itype not_in backend.KEEP_CAPACITY {
			input_cap = node.input_count
		}

		if node.itype == .Loop {
			input_cap = 1
		}

		if node.itype == .Phi &&
		   backend.graph_get(ctx.from, node.inps[0]).itype == .Loop {
			rtype = u16(Builder_Node_Type.Lazy_Phi)
			input_cap = 2
		}

		inps := make([]backend.Node_ID, input_cap)
		for inp, i in raw_data(node.inps)[:input_cap] {
			clone_node(ctx, inp)
			inps[i] = ctx.projection[backend.graph_get(ctx.from, inp).gvn]
		}

		if node.itype == .Local {
			if node.inps[0] == ctx.from.root_mem {
				inps[0] = graph.root_mem
			}

			if node.inps[0] == ctx.from.entry {
				inps[0] = graph.entry
			}
		}

		if node.itype == .Return do return

		prev := graph.mem.pos

		size :=
			backend.graph_size(graph, node.rtype) +
			int(node.extra_dwords) * backend.PRECISION
		backend.push_node_name(
			graph,
			backend.graph_get_node_name(ctx.from, root),
		)
		slot := arna.alloc(graph.mem, uint(size), backend.PRECISION)

		mem.copy_non_overlapping(raw_data(slot), node.node, len(slot))

		new_node := (^backend.Node)(raw_data(slot))
		new_node.rtype = rtype
		new_node.gvn = graph.gvn
		graph.gvn += 1

		new_node.input_idx = u32(graph.mem.pos / backend.PRECISION)
		_ = arna.clone(graph.mem, inps)
		new_node.input_cap = input_cap
		new_node.input_count = min(new_node.input_count, input_cap)

		new_node.output_idx = u32(graph.mem.pos / backend.PRECISION)
		_ = arna.alloc(
			graph.mem,
			uint(node.output_cap * backend.PRECISION),
			backend.PRECISION,
		)
		new_node.output_count = 0
		new_node.output_cap = node.output_cap

		id := backend.graph_id(graph, new_node)
		interned := backend.graph_intern(graph, id)
		if interned != id {
			graph.mem.pos = prev
			id = interned
		} else {
			for inp, i in inps {
				backend.graph_add_output(graph, inp, id, i)
			}
		}

		dn := backend.graph_dbg_slot(ctx.from, node)^
		did: backend.D_Node_ID

		if dn != 0 &&
		   ctx.dprojection[backend.graph_getd(ctx.from, dn).gdn] == 0 {
			did := backend.D_Node_ID(graph.mem.pos / backend.PRECISION)
			size := size_of(backend.D_Node)
			bytes := arna.alloc(graph.mem, uint(size), backend.PRECISION)
			mem.copy_non_overlapping(raw_data(bytes), node.node, len(bytes))
			ctx.dprojection[backend.graph_getd(ctx.from, dn).gdn] = did
		}

		backend.graph_dbg_slot(graph, new_node)^ = did
		ctx.projection[node.gvn] = id
	}
}

graph_add_field_offset :: proc(
	graph: ^Graph,
	base: Node_ID,
	offset: int,
) -> Node_ID {
	if offset == 0 do return base
	off := backend.graph_add_c_int(graph, "foff", .I64, i64(offset))
	return backend.graph_add_bin_op(graph, "fld", .Add, .I64, base, off)
}

graph_add_field_store :: proc(
	ctx: ^Graph,
	name: string,
	cfg: Node_ID,
	mem: Node_ID,
	base: Node_ID,
	offset: int,
	value: Node_ID,
) -> Node_ID {
	return backend.graph_add_store(
		ctx,
		name,
		cfg,
		mem,
		graph_add_field_offset(ctx, base, offset),
		value,
	)
}

graph_add_arbitrary_store :: proc(
	ctx: ^Graph,
	cfg: Node_ID,
	mem: Node_ID,
	addr: Node_ID,
	value: Node_ID,
	size: int,
	extra_offset := 0,
	unit: backend.Node_Datatype = .I64,
) -> (
	omem: Node_ID,
) {
	omem = mem

	store_unit := unit
	size := min(size - extra_offset, backend.DT_SIZE[unit])
	offset: int

	if store_unit in backend.FLOAT_DTS {
		omem = graph_add_field_store(
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
		for backend.DT_SIZE[store_unit] + offset > size {
			store_unit = backend.Node_Datatype(u8(store_unit) - 1)
			assert(store_unit != .Void)
		}

		value := backend.graph_add_un_op(
			ctx,
			"rvl",
			.Cast,
			store_unit,
			backend.graph_add_bin_op(
				ctx,
				"stsh",
				.U_Shr,
				.I64,
				value,
				backend.graph_add_c_int(ctx, "stshoff", .I64, i64(offset * 8)),
			),
		)

		omem = graph_add_field_store(
			ctx,
			"asst",
			cfg,
			omem,
			addr,
			offset + extra_offset,
			value,
		)

		offset += backend.DT_SIZE[store_unit]
	}

	return
}

graph_add_field_load :: proc(
	ctx: ^Graph,
	name: string,
	dt: backend.Node_Datatype,
	cfg: Node_ID,
	mem: Node_ID,
	base: Node_ID,
	offset: int = 0,
) -> Node_ID {
	return backend.graph_add_load(
		ctx,
		name,
		dt,
		cfg,
		mem,
		graph_add_field_offset(ctx, base, offset),
	)
}

graph_add_arbitrary_load :: proc(
	ctx: ^Graph,
	cfg: Node_ID,
	mem: Node_ID,
	addr: Node_ID,
	size: int,
	extra_offset := 0,
	unit: backend.Node_Datatype = .I64,
) -> Node_ID {
	load_unit := unit
	size := min(size - extra_offset, backend.DT_SIZE[unit])
	offset: int
	value: Node_ID

	if load_unit in backend.FLOAT_DTS {
		return graph_add_field_load(
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
		for backend.DT_SIZE[load_unit] + offset > size {
			assert(load_unit not_in backend.FLOAT_DTS)
			load_unit = backend.Node_Datatype(u8(load_unit) - 1)
			assert(load_unit != .Void)
		}

		load := graph_add_field_load(
			ctx,
			"asld",
			load_unit,
			cfg,
			mem,
			addr,
			offset + extra_offset,
		)

		if value == 0 {
			value = load
			assert(offset == 0)
		} else {
			value = backend.graph_add_bin_op(
				ctx,
				"aor",
				.Or,
				.I64,
				value,
				backend.graph_add_bin_op(
					ctx,
					"ash",
					.Shl,
					.I64,
					load,
					backend.graph_add_c_int(
						ctx,
						"ssham",
						.I64,
						i64(offset * 8),
					),
				),
			)
		}

		offset += backend.DT_SIZE[load_unit]
	}

	return value
}

Param_Gen :: struct {
	vls:         [dynamic]Node_ID,
	spill_start: int,
}

Abi_Param :: struct {
	dt:        [dynamic; 2]backend.Node_Datatype,
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
		value = backend.graph_add_param(
			ctx,
			name,
			dt,
			ctx.entry,
			u32(apa.spilled),
		)
		append(&gen.vls, value)
	} else {
		nd := apa.copied ? ctx.root_mem : ctx.entry
		alloca := backend.graph_add_local(ctx, name, nd)
		backend.graph_extra(ctx, alloca, backend.Local).size = i32(
			apa.real_size,
		)
		backend.graph_extra(ctx, alloca, backend.Local).is_param = !apa.copied
		value = backend.graph_add_local_addr(ctx, name, alloca)

		if !apa.copied {
			append(&gen.vls, alloca)
		}
	}

	for dt, j in apa.dt[:(apa.size + 7) / 8] {
		vl := backend.graph_add_param(ctx, name, dt, ctx.entry, 0)
		gen.spill_start += int(j == 1)
		append(&gen.vls, vl)
		omem = graph_add_arbitrary_store(
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

arg_gen_finalize :: proc(
	ctx: ^Graph,
	gen: ^Param_Gen,
) -> []backend.Param_Spec {
	arg_tys := make([]backend.Param_Spec, len(gen.vls))

	j, ri: u32
	for arg in gen.vls {
		anode := backend.graph_get(ctx, arg)
		if arga := backend.graph_extra(ctx, arg, backend.Tup); arga != nil {
			size: i32
			if arga.idx == 0 {
				arga.idx = j
				j += 1
			} else {
				arga.idx = u32(gen.spill_start) + ri
				size = 8
				ri += 1
			}
			arg_tys[arga.idx] = backend.Param_Spec{anode.dt, size}
		}

		if loca := backend.graph_extra(ctx, arg, backend.Local); loca != nil {
			loca.size = i32(mem.align_forward_int(int(loca.size), 8))
			loca.idx = u32(gen.spill_start) + ri
			arg_tys[loca.idx] = backend.Param_Spec{.Void, loca.size}
			loca.is_param = true
			ri += 1
		}
	}
	fmt.assertf(int(j) == gen.spill_start, "%v %v", j, gen.spill_start)
	return arg_tys
}
