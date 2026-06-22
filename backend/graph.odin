package backend

import "../vendored/gam/util/arna"
import "base:runtime"
import "core:container/queue"
import "core:fmt"
import "core:io"
import "core:mem"
import "core:reflect"
import "core:simd"
import "core:slice"
import "core:terminal/ansi"

when NODE_NAMES {
	PREFIX_SIZE :: size_of(string)
} else {
	PREFIX_SIZE :: 0
}

PRECISION :: size_of(u32)
NODE_START :: Node_ID(4 + PREFIX_SIZE) / 4
NODE_ENTRY ::
	Node_ID(4 + PREFIX_SIZE + size_of(Node) + size_of(Cfg) + PREFIX_SIZE) / 4
NODE_NAMES :: #config(NODE_NAMES, ODIN_DEBUG)

Node_Spec_Name :: enum {
	Builder,
	X64,
}

Node_Spec :: struct {
	node_extra_sizes:  []u8,
	inheritance_table: []Inherit_Table_Elem,
	node_flags:        []Class_Flags,
	node_extra_types:  []typeid,
	node_kind_name:    []string,
	using regalloc:    Regalloc_Spec,
	using codegen:     Codegen_Spec,
}

Ideal_Node_Type :: enum u16 {
	Start,
	Entry,
	Poison,
	Arg,
	CInt,
	Add,
	Sub,
	Mul,
	Eq,
	Ne,
	Le,
	Lt,
	Gt,
	Ge,
	Div,
	Rem,
	And,
	Or,
	Xor,
	And_Not,
	Shl,
	Shr,
	U_Lt,
	U_Gt,
	U_Le,
	U_Ge,
	U_Div,
	U_Rem,
	U_Shr,
	Split,
	Phi,
	Mem,
	Local,
	Local_Addr,
	Copy,
	Set,
	Store,
	Load,
	// like Load, but sign extends the loaded value into the full register
	// since we always do arithmetic in the biggest register size
	Load_S,
	If,
	Then,
	Else,
	Jump,
	Region,
	Loop,
	Always,
	Call,
	Call_End,
	Ret,
	Return,
}

Class_Flags :: bit_set[Class_Flag;u8]

Class_Flag :: enum {
	Is_Basic_Block_Start,
	Interned,
	Comutes,
	Immortal,
	Store,
	Load,
	Clonable,
}

Cfg :: struct {
	using props: struct #raw_union {
		idepth: u32,
	},
}

Region :: struct {
	using _: Cfg,
}

Scope :: struct #align (4) {
	done: bool,
}

CInt :: struct #align (4) {
	value: i64,
}

Call :: struct {
	using _: Cfg,
	cid:     u32,
}

Tup :: struct {
	idx: u32,
}

Local :: struct {
	using props: struct #raw_union {
		size:   u32,
		offset: u32,
	},
}

Mem_Op :: struct {}

No_Extra :: struct {}

Node_Datatype :: enum u8 {
	Void,
	I8,
	I16,
	I32,
	I64,
}

DT_SIZE := [Node_Datatype]int {
	.Void = 0,
	.I8   = 1,
	.I16  = 2,
	.I32  = 4,
	.I64  = 8,
}

Node_ID :: distinct u32

Node_Output :: bit_field u32 {
	id:  Node_ID | 22,
	idx: int     | 10,
}

Node :: struct {
	using _:             struct #raw_union {
		itype: Ideal_Node_Type,
		btype: Builder_Node_Type,
		xtype: X64_Node_Type,
		rtype: u16,
	},
	using _:             bit_field u8 {
		dt: Node_Datatype | 8,
	},
	using _:             bit_field u8 {
		in_worklist:           bool | 1,
		additional_data_start: u8   | 2,
	},
	gvn:                 u32,
	input_idx:           u32,
	ordered_input_count: u16,
	input_count:         u16,
	output_idx:          u32,
	output_count:        u16,
	output_cap:          u16,
	extra:               [0]u32,
}

#assert(size_of(Node) == 24)

Node_Intern_Entry :: struct {
	hash: u8,
	id:   Node_ID,
}

Graph :: struct {
	using node_spec: ^Node_Spec,
	interner:        #soa[]Node_Intern_Entry,
	interner_len:    int,
	mem:             ^arna.Allocator,
	gvn:             u32,
	end:             Node_ID,
	waste:           int,
	dont_intern:     bool,
}

Peep_Ctx :: struct {
	using graph: ^Graph,
	worklist:    ^queue.Queue(Node_ID),
}

Intern_Vec :: #simd[16]u8

If_State :: struct {
	if_:     Node_ID,
	using _: struct #raw_union {
		else_scope: Node_ID,
		then_scope: Node_ID,
	},
}

graph_start_if :: proc(
	graph: ^Graph,
	scope: Node_ID,
	state: ^If_State,
	cond: Node_ID,
) {
	snode := graph_expand(graph, scope)
	state.if_ = graph_add_if(graph, "if", snode.inps[0], cond)
	state.else_scope = graph_clone(graph, scope)

	then := graph_add_then(graph, "then", state.if_)
	graph_set_input(graph, scope, 0, then)
}

graph_start_else :: proc(
	graph: ^Graph,
	then_scope: ^Node_ID,
	state: ^If_State,
) {
	else_ := graph_add_else(graph, "else", state.if_)
	graph_set_input(graph, state.else_scope, 0, else_)
	then_scope^, state.then_scope = state.else_scope, then_scope^
}

graph_end_else :: proc(graph: ^Graph, else_scope: ^Node_ID, state: ^If_State) {
	else_scope^ = graph_merge_scopes(graph, state.then_scope, else_scope^)
}

Loop_Control :: enum int {
	Break,
	Continue,
}

Loop_State :: struct {
	scope:  Node_ID,
	scopes: [Loop_Control]Node_ID,
}

worklist_add :: proc(
	graph: ^Graph,
	worklist: ^queue.Queue(Node_ID),
	id: Node_ID,
) {
	if id == 0 do return
	node := graph_expand(graph, id)
	if node.in_worklist {
		if false {
			for elem in worklist.data {
				if elem == id do return
			}
			fmt.panicf("wuta: %v", node.node)
		} else {
			return
		}
	}
	node.in_worklist = true
	queue.push_back(worklist, id)
}

worklist_next :: proc(
	graph: ^Graph,
	worklist: ^queue.Queue(Node_ID),
) -> (
	n: Node_ID,
	ok: bool,
) {
	id := queue.pop_front_safe(worklist) or_return
	graph_expand(graph, id).in_worklist = false
	return id, true
}

graph_iter_peeps :: proc(graph: ^Graph) {
	worklist: queue.Queue(Node_ID)
	queue.init(&worklist, int(graph.gvn))
	worklist_add(graph, &worklist, NODE_START)

	collect_nodes(graph, &worklist)

	for n in worklist_next(graph, &worklist) {
		node := graph_expand(graph, n)

		prev_hash := graph_node_hash(graph, n)
		node.in_worklist = true
		new_node := graph.peep({graph, &worklist}, node)
		node.in_worklist = false
		if new_node == 0 do continue

		for out in node.outs {
			worklist_add(graph, &worklist, out.id)
		}

		assert_eq_hash := true

		if new_node == n {
			graph_unintern(graph, n, prev_hash)
			new_node = graph_intern(graph, n)
			if new_node == n do continue
			assert_eq_hash = false
		}

		for inp in node.inps {
			worklist_add(graph, &worklist, inp)
		}

		if assert_eq_hash {
			assert(graph_node_hash(graph, node) == prev_hash)
		}

		graph_subsume(graph, new_node, n)
	}

	if ODIN_DEBUG {
		collect_nodes(graph, &worklist)

		for n in worklist_next(graph, &worklist) {
			node := graph_expand(graph, n)
			new_node := graph.peep({graph, &worklist}, node)
			assert(new_node == 0)
		}
	}

	collect_nodes :: proc(graph: ^Graph, worklist: ^queue.Queue(Node_ID)) {
		i := 0
		for i < queue.len(worklist^) {
			node := graph_expand(graph, worklist.data[i])

			for inp in node.inps {
				if inp == 0 do continue
				worklist_add(graph, worklist, inp)
			}

			for out in node.outs {
				worklist_add(graph, worklist, out.id)
			}

			i += 1
		}
	}
}

when !GEN_SPEC {
	fold_bin_op :: proc(lhs: i64, op: Bin_Op, rhs: i64) -> (value: i64) {
		switch op {
		case .Add:
			value = lhs + rhs
		case .Sub:
			value = lhs - rhs
		case .Mul:
			value = lhs * rhs
		case .Div:
			value = lhs / rhs
		case .Rem:
			value = lhs % rhs
		case .And:
			value = lhs & rhs
		case .Or:
			value = lhs | rhs
		case .Xor:
			value = lhs ~ rhs
		case .And_Not:
			value = lhs &~ rhs
		case .Shl:
			value = lhs << u64(rhs)
		case .Shr:
			value = lhs >> u64(rhs)
		case .Eq:
			value = i64(lhs == rhs)
		case .Ne:
			value = i64(lhs != rhs)
		case .Le:
			value = i64(lhs <= rhs)
		case .Lt:
			value = i64(lhs < rhs)
		case .Gt:
			value = i64(lhs > rhs)
		case .Ge:
			value = i64(lhs >= rhs)
		case .U_Lt:
			value = i64(u64(lhs) < u64(rhs))
		case .U_Gt:
			value = i64(u64(lhs) > u64(rhs))
		case .U_Le:
			value = i64(u64(lhs) <= u64(rhs))
		case .U_Ge:
			value = i64(u64(lhs) >= u64(rhs))
		case .U_Div:
			value = i64(u64(lhs) / u64(rhs))
		case .U_Rem:
			value = i64(u64(lhs) % u64(rhs))
		case .U_Shr:
			value = i64(u64(lhs) >> u64(rhs))
		case:
			panic("wuwut")
		}
		return
	}

	builder_peep :: proc(ctx: Peep_Ctx, node: Expanded_Node) -> Node_ID {
		id := graph_id(ctx, node)

		#partial switch node.itype {
		case .Add ..= .U_Shr:
			lhs := graph_expand(ctx.graph, node.inps[0])
			rhs := graph_expand(ctx.graph, node.inps[1])

			clhs := graph_extra(ctx.graph, lhs, CInt)
			crhs := graph_extra(ctx.graph, rhs, CInt)
			op := Bin_Op(node.itype)

			if clhs != nil && crhs != nil {
				value := fold_bin_op(clhs.value, op, crhs.value)
				return graph_add_c_int(ctx.graph, "fld", .I64, value)
			}

			if crhs != nil {
				ZERO_IS_NEUTRAL := bit_set[Bin_Op] {
					.Add,
					.Sub,
					.Or,
					.Shr,
					.U_Shr,
					.Shl,
					.Xor,
					.And_Not,
				}
				if op in ZERO_IS_NEUTRAL && crhs.value == 0 {
					return node.inps[0]
				}

				ONE_IS_NEUTRAL := bit_set[Bin_Op]{.Mul, .Div}
				if op in ONE_IS_NEUTRAL && crhs.value == 1 {
					return node.inps[0]
				}
			}

			if lhs.node == rhs.node {
				SYMETRI_IS_ZERO := bit_set[Bin_Op] {
					.Sub,
					.Xor,
					.And_Not,
					.Ne,
					.Lt,
					.Gt,
					.U_Lt,
					.U_Gt,
				}
				if op in SYMETRI_IS_ZERO {
					return graph_add_c_int(ctx.graph, "sim0", .I64, 0)
				}

				SYMETRI_IS_ONE := bit_set[Bin_Op]{.Eq, .Le, .Ge, .U_Le, .U_Ge}
				if op in SYMETRI_IS_ONE {
					return graph_add_c_int(ctx.graph, "sim1", .I64, 1)
				}
			}

			ASOCIATIVE := bit_set[Bin_Op]{.Add, .Mul, .And, .Or, .Xor, .And}

			if Bin_Op(lhs.itype) == op && op in ASOCIATIVE && crhs != nil {
				clhs_lhs := graph_extra(ctx, lhs.inps[0], CInt)
				clhs_rhs := graph_extra(ctx, lhs.inps[1], CInt)
				if clhs_rhs != nil && clhs_lhs == nil {
					return graph_add_bin_op(
						ctx.graph,
						"rsoc",
						op,
						node.dt,
						lhs.inps[0],
						graph_add_c_int(
							ctx.graph,
							"rfld",
							node.dt,
							fold_bin_op(clhs_rhs.value, op, crhs.value),
						),
					)
				}
			}

			COMUTATIVE :: bit_set[Bin_Op] {
				.Add,
				.Mul,
				.Ge,
				.Gt,
				.Ne,
				.Eq,
				.Or,
				.And,
				.Xor,
			}

			@(static, rodata)
			COMUTE_PRIORITY_TABLE := #partial [Ideal_Node_Type]u8 {
				.CInt = 1,
			}

			if op in COMUTATIVE &&
			   COMUTE_PRIORITY_TABLE[lhs.itype] >
				   COMUTE_PRIORITY_TABLE[rhs.itype] {
				for inp, i in node.inps {
					graph_add_output(ctx, inp, id, 1 - i)
					graph_remove_output(ctx, inp, {idx = i, id = id})
				}
				node.inps[0], node.inps[1] = node.inps[1], node.inps[0]
				return id
			}
		}

		return 0
	}
}

graph_start_loop :: proc(graph: ^Graph, scope: Node_ID, state: ^Loop_State) {
	snode := graph_expand(graph, scope)
	loop := graph_add_loop(graph, "loop", snode.inps[0])
	graph_set_input(graph, scope, 0, loop)
	state.scope = graph_clone(graph, scope)

	graph_add_output(graph, state.scope, 0, 0)

	snode = graph_expand(graph, scope)
	for i in 1 ..< snode.ordered_input_count {
		graph_set_input(graph, scope, i, state.scope)
	}
}

graph_end_loop :: proc(
	graph: ^Graph,
	node_scope: ^Node_ID,
	state: ^Loop_State,
) {
	node_scope^ = graph_merge_scopes(
		graph,
		node_scope^,
		state.scopes[.Continue],
	)

	init := graph_expand(graph, state.scope)
	loop := init.inps[0]
	assert(graph_get(graph, loop).itype == .Loop)

	bscope := node_scope^
	if bscope != 0 {
		backedge := graph_expand(graph, bscope)
		assert(init.ordered_input_count == backedge.ordered_input_count)
		for i in 1 ..< init.ordered_input_count {
			init := init.inps[i]
			inode := graph_expand(graph, init)
			bnode := graph_expand(graph, backedge.inps[i])
			if inode.btype != .Lazy_Phi do continue

			for {
				scp := graph_extra(graph, bnode, Scope)
				if scp == nil || !scp.done || bnode.inps[0] == loop do break
				bnode = graph_expand(graph, bnode.inps[i])
			}

			if bnode.btype == .Scope || inode.node == bnode.node {
				graph_subsume(graph, inode.inps[1], init)
			} else {
				graph_add_extra_input(graph, inode, graph_id(graph, bnode))
				inode.itype = .Phi
				graph_intern(graph, init)
			}
		}

		assert(graph_get(graph, init.inps[0]).itype == .Loop)
		graph_add_extra_input(graph, init.inps[0], backedge.inps[0])
	}

	node_scope^ = state.scopes[.Break]

	if node_scope^ != 0 {
		exit := graph_expand(graph, node_scope^)
		for i in 1 ..< exit.ordered_input_count {
			enode := graph_get(graph, exit.inps[i])
			if enode.btype == .Scope {
				graph_set_input(graph, node_scope^, i, init.inps[i])
			}
		}
	}

	graph_extra(graph, state.scope, Scope).done = true
	graph_remove_output(graph, state.scope, {id = 0, idx = 0})

	if bscope != 0 {
		graph_delete(graph, bscope)
	} else {
		for out in graph_outs(graph, loop) {
			onode := graph_expand(graph, out.id)
			if onode.btype == .Lazy_Phi {
				graph_subsume(graph, onode.inps[1], out.id)
			}
		}

		graph_subsume(graph, graph_inps(graph, loop)[0], loop)
	}

	return
}

graph_loop_control :: proc(
	variant: Loop_Control,
	ctx: ^Graph,
	scope: Node_ID,
	loop: ^Loop_State,
) {
	base_size := graph_get(ctx, loop.scope).ordered_input_count
	graph_truncate_scope(ctx, scope, base_size)
	loop.scopes[variant] = graph_merge_scopes(ctx, scope, loop.scopes[variant])
}

graph_merge_returns :: proc(graph: ^Graph, args: []Node_ID) -> Node_ID {
	if graph.end == 0 {
		graph.end = graph_add_return(graph, "ret", args)
		return graph.end
	}

	end := graph_expand(graph, graph.end)

	reg := graph_add_region(graph, "rreg", args[0], end.inps[0])
	graph_set_input(graph, graph.end, 0, reg)

	for i in 1 ..< len(end.inps) {
		rhs := end.inps[i]
		ty := graph_get(graph, rhs).dt
		lhs := i < len(args) ? args[i] : graph_add_poison(graph, "rpsn")
		if rhs == lhs do continue
		phi := graph_add_phi(graph, "rphi", ty, reg, lhs, rhs)
		graph_set_input(graph, graph.end, i, phi)
	}

	return reg
}

graph_interner_find :: proc(
	graph: ^Graph,
	id: Node_ID,
	precomputed_hash: u8,
) -> (
	int,
	u8,
	bool,
) {
	assert(mem.is_aligned(graph.interner.hash, align_of(Intern_Vec)))
	assert(id != 0)

	needle := precomputed_hash
	if needle == 0 {
		needle = graph_node_hash(graph, id)
	}
	assert(needle != 0)

	for mask, i in mem.slice_data_cast(
		[]Intern_Vec,
		graph.interner.hash[:len(graph.interner)],
	) {
		eqs := simd.lanes_eq(mask, Intern_Vec(needle))
		bits := transmute(u16)simd.extract_lsbs(eqs)
		for bits != 0 {
			idx :=
				i * size_of(Intern_Vec) + int(simd.count_trailing_zeros(bits))
			bits &= bits - 1

			if graph_node_eq(graph, graph.interner.id[idx], id) {
				return idx, needle, true
			}
		}
	}

	return -1, needle, false
}

graph_intern :: proc(graph: ^Graph, id: Node_ID) -> Node_ID {
	if !graph_has_flag(graph, id, .Interned) || graph.dont_intern {
		return id
	}

	idx, hash, _ := graph_interner_find(graph, id, 0)
	if idx >= 0 {
		//assert(len(graph_outs(graph, id)) == 0)
		return graph.interner.id[idx]
	}

	if len(graph.interner) == graph.interner_len {
		new_cap := len(graph.interner) * 2 + size_of(Intern_Vec)
		hashes := arna.alloc(
			graph.mem,
			uint(new_cap),
			align_of(Intern_Vec),
			zeroed = true,
		)
		nodes := arna.smake(graph.mem, []Node_ID, new_cap)

		mem.copy_non_overlapping(
			raw_data(hashes),
			graph.interner.hash,
			graph.interner_len,
		)
		mem.copy_non_overlapping(
			raw_data(nodes),
			graph.interner.id,
			graph.interner_len * size_of(Node_ID),
		)

		graph.interner.hash = raw_data(hashes)
		graph.interner.id = raw_data(nodes)

		raw_soa_footer_slice(&graph.interner).len = new_cap
	}

	graph.interner[graph.interner_len] = {
		hash = hash,
		id   = id,
	}
	graph.interner_len += 1

	return id
}

graph_unintern :: proc(graph: ^Graph, id: Node_ID, precomputed_hash: u8 = 0) {
	if graph_has_flag(graph, id, .Interned) && !graph.dont_intern {
		idx, _, _ := graph_interner_find(graph, id, precomputed_hash)
		if idx < 0 do return

		graph.interner_len -= 1
		graph.interner[idx] = graph.interner[graph.interner_len]

		// NOTE: there is probably a bug in the odin compiler that requires us
		// to not set the value with a leteral
		tmp: Node_Intern_Entry
		graph.interner[graph.interner_len] = tmp
	}
}

graph_subsume :: proc(graph: ^Graph, with: Node_ID, target: Node_ID) {
	wnode := graph_expand(graph, with)
	tnode := graph_expand(graph, target)

	assert(with != target)

	try_recycle: if 0 == 0 {
		wtotal_size :=
			size_of(Node) +
			uint(graph.node_extra_sizes[wnode.rtype]) * PRECISION +
			uint(wnode.input_count * size_of(Node_ID))

		if int(graph.mem.pos - wtotal_size) / PRECISION != int(with) {
			break try_recycle
		}

		assert(wnode.gvn == graph.gvn - 1)
		assert(wnode.output_cap == 0)
		assert(wnode.input_count == wnode.ordered_input_count)
		assert(
			wnode.input_idx ==
			(u32(graph.mem.pos) - u32(wnode.input_count) * size_of(Node_ID)) /
				PRECISION,
		)

		ttotal_size :=
			size_of(Node) +
			uint(graph.node_extra_sizes[tnode.rtype]) * PRECISION +
			size_of(Node_ID) * uint(tnode.ordered_input_count)

		if wtotal_size > ttotal_size do break try_recycle

		for inp, i in wnode.inps {
			graph_remove_output(graph, inp, {idx = i, id = with})
			graph_add_output(graph, inp, target, i)
		}

		for inp, i in tnode.inps {
			if inp == 0 do continue
			assert(inp != with)
			graph_remove_output(graph, inp, {idx = i, id = target})
		}

		graph_unintern(graph, with)
		graph_unintern(graph, target)

		graph.waste += int(ttotal_size - wtotal_size)

		wnode.gvn = tnode.gvn
		wnode.input_idx -= u32(with - target)
		wnode.output_count = tnode.output_count
		wnode.output_cap = tnode.output_cap
		wnode.output_idx = tnode.output_idx

		nnode_slice := ([^]u8)(wnode.node)[-PREFIX_SIZE:][:wtotal_size +
		PREFIX_SIZE]
		node_slice := ([^]u8)(tnode.node)[-PREFIX_SIZE:][:ttotal_size +
		PREFIX_SIZE]
		copy(node_slice, nnode_slice)
		graph.mem.pos = uint(with) * PRECISION - PREFIX_SIZE
		graph.gvn -= 1

		graph_intern(graph, target)

		return
	}

	graph_ensure_available_output_cap(graph, wnode, tnode.output_count)

	wnode.output_count += tnode.output_count
	tnode.output_count = 0

	wnode = graph_expand(graph, with)

	copy(wnode.outs[len(wnode.outs) - len(tnode.outs):], tnode.outs)

	for out in tnode.outs {
		graph_unintern(graph, out.id)
		graph_inps(graph, out.id)[out.idx] = with
	}
	graph_delete(graph, tnode)

	wnode = graph_expand(graph, with)

	keep := 0
	for out in tnode.outs {
		for oout in wnode.outs {
			if out == oout {
				tnode.outs[keep] = out
				keep += 1
			}
		}
	}
	tnode.outs = tnode.outs[:keep]

	for out in tnode.outs {
		graph_intern(graph, out.id)
	}

}

graph_node_eq :: proc(graph: ^Graph, a, b: Node_ID) -> bool {
	if a == b do return true

	an, bn := graph_get(graph, a), graph_get(graph, b)
	if an.rtype != bn.rtype do return false
	if an.dt != bn.dt do return false

	if !slice.equal(graph_inps(graph, an), graph_inps(graph, bn)) {
		return false
	}

	ad := graph_extra_dwords(graph, an)
	bd := graph_extra_dwords(graph, bn)
	if !slice.equal(ad, bd) do return false

	return true
}

graph_get_scope_value :: proc(
	graph: ^Graph,
	scope: Node_ID,
	#any_int idx: int,
) -> Node_ID {
	snode := graph_get(graph, scope)
	assert(snode.btype == .Scope)

	val := graph_inps(graph, snode)[idx]
	vnode := graph_expand(graph, val)
	loop_scope := graph_extra(graph, vnode, Scope)
	if loop_scope != nil {
		pval := val
		val = graph_get_scope_value(graph, val, idx)
		cvnode := graph_expand(graph, val)
		if (cvnode.btype != .Lazy_Phi || vnode.inps[0] != cvnode.inps[0]) &&
		   !loop_scope.done {
			assert(graph_get(graph, vnode.inps[0]).itype == .Loop)
			val = graph_add_lazy_phi(
				graph,
				"lphi",
				graph_get(graph, val).dt,
				vnode.inps[0],
				val,
			)
			graph_set_input(graph, pval, idx, val)
		}
		graph_set_input(graph, scope, idx, val)
	}

	return val
}

graph_push_scope_value :: proc(
	graph: ^Graph,
	scope: Node_ID,
	value: Node_ID,
) -> int {
	scope_node := graph_get(graph, scope)
	assert(scope_node.btype == .Scope)

	idx := graph_add_input(graph, scope_node, value, is_scope = true)
	graph_add_output(graph, value, scope, idx)
	return idx
}

graph_truncate_scope :: proc(
	graph: ^Graph,
	scope: Node_ID,
	#any_int to_len: int,
) {
	if scope == 0 do return

	snode := graph_expand(graph, scope)
	assert(snode.btype == .Scope)
	assert(to_len <= int(snode.ordered_input_count))

	for &inp, i in snode.inps[to_len:snode.ordered_input_count] {
		graph_remove_output(graph, inp, {idx = to_len + i, id = scope})
		inp = 0
	}

	snode.ordered_input_count = u16(to_len)
}

graph_merge_scopes :: proc(
	graph: ^Graph,
	lctrl: Node_ID,
	rctrl: Node_ID,
) -> Node_ID {
	if lctrl == 0 do return rctrl
	if rctrl == 0 do return lctrl

	lnode := graph_expand(graph, lctrl)
	assert(lnode.btype == .Scope)
	rnode := graph_expand(graph, rctrl)
	assert(rnode.btype == .Scope)

	assert(lnode.ordered_input_count == rnode.ordered_input_count)

	region := graph_add_region(graph, "reg", lnode.inps[0], rnode.inps[0])

	for i in 1 ..< lnode.ordered_input_count {
		if lnode.inps[i] == rnode.inps[i] do continue
		lvalue := graph_get_scope_value(graph, lctrl, i)
		rvalue := graph_get_scope_value(graph, rctrl, i)
		if lvalue == rvalue do continue
		phi := graph_add_phi(
			graph,
			"phi",
			graph_get(graph, lvalue).dt,
			region,
			lvalue,
			rvalue,
		)
		graph_set_input(graph, lctrl, i, phi)
	}

	graph_set_input(graph, lctrl, 0, region)
	graph_delete(graph, rnode)

	return lctrl
}

graph_set_input :: proc(
	graph: ^Graph,
	id: Node_ID,
	#any_int idx: int,
	value: Node_ID,
) -> Node_ID {
	node := graph_expand(graph, id)

	if node.inps[idx] == value do return id

	assert(node.inps[idx] != 0)

	graph_remove_output(graph, node.inps[idx], {idx = idx, id = id})

	graph_add_output(graph, value, id, idx)

	graph_unintern(graph, id)
	node.inps[idx] = value
	return graph_intern(graph, id)
}

graph_clone :: proc(graph: ^Graph, id: Node_ID) -> Node_ID {
	node := graph_expand(graph, id)
	graph.dont_intern = true
	push_node_name(graph, graph_get_node_name(graph, id))
	idx := graph_get_next_extra_slot(graph, node.rtype)
	extra := graph_extra_dwords(graph, node)
	copy(idx[:len(extra)], extra)
	new := graph_add_raw(graph, node.rtype, node.dt, node.inps)
	graph_get(graph, new).ordered_input_count = node.ordered_input_count
	graph.dont_intern = false
	return new
}

@(tag = "node_proc")
graph_remove_output_node :: proc(
	graph: ^Graph,
	node: ^Node,
	out: Node_Output,
) {
	outs := graph_outs(graph, node)
	out_idx := slice.linear_search(outs, out) or_else panic("")
	outs[out_idx] = outs[len(outs) - 1]
	node.output_count -= 1
	graph_delete(graph, node, indirect = true)
}

@(tag = "node_proc")
graph_node_hash_node :: proc(graph: ^Graph, node: ^Node) -> u8 {
	if !graph_has_flag(graph, node, .Interned) do return 0

	hash: u32

	type := u32(node.rtype)
	dt := u32(node.dt)
	extra_dwords := graph_extra_dwords(graph, node)
	inps := graph_inps(graph, node)

	hash += type + dt
	for n in extra_dwords do hash += n
	for n in inps do hash += u32(n)

	hash_u32 :: proc(x: u32) -> u32 {
		h := x

		h ~= h >> 16
		h *= 0x85eb_ca6b
		h ~= h >> 13
		h *= 0xc2b2_ae35
		h ~= h >> 16

		return h
	}

	hash = hash_u32(hash)

	res := u8(hash)
	res += u8(res == 0)
	return res
}

graph_id :: #force_inline proc(graph: ^Graph, node: ^Node) -> Node_ID {
	return Node_ID((uintptr(node) - uintptr(graph.mem.ptr)) / PRECISION)
}

@(tag = "node_proc")
graph_delete_node :: proc(graph: ^Graph, node: ^Node, indirect := false) {
	id := graph_id(graph, node)
	if node.output_count != 0 do return
	if graph_has_flag(graph, node, .Immortal) && indirect do return

	for inp, i in graph_inps(graph, node) {
		if inp == 0 do continue
		graph_remove_output(graph, inp, {idx = i, id = id})
	}

	graph_unintern(graph, graph_id(graph, node))
	graph.waste += int(node.input_count * size_of(Node_ID))
	graph.waste += int(node.output_count * size_of(Node_Output))
	graph.waste += size_of(Node)
	graph.waste += int(graph.node_extra_sizes[node.rtype] * PRECISION)
	node^ = {}
}

@(tag = "node_proc")
graph_extra_dwords_node :: proc(graph: ^Graph, node: ^Node) -> []u32 {
	extra := graph_extra(graph, node)
	return mem.slice_data_cast([]u32, reflect.as_bytes(extra))
}

graph_get :: #force_inline proc(graph: ^Graph, id: Node_ID) -> ^Node {
	assert(id != 0)
	return (^Node)(&([^]u32)(graph.mem.ptr)[id])
}

Expanded_Node :: struct {
	using node:   ^Node,
	inps:         []Node_ID,
	outs:         []Node_Output,
	data_start:   int,
	inplace_slot: int,
}

graph_expand :: #force_no_inline proc(
	graph: ^Graph,
	id: Node_ID,
) -> Expanded_Node {
	node := graph_get(graph, id)
	return {
		node,
		graph_inps(graph, node),
		graph_outs(graph, node),
		int(graph.first_input_idxs[node.rtype] + node.additional_data_start),
		int(graph.inplace_slot_idxs[node.rtype]),
	}
}

@(tag = "node_proc")
graph_inps_node :: #force_inline proc(
	graph: ^Graph,
	node: ^Node,
) -> []Node_ID {
	return ([^]Node_ID)(graph.mem.ptr)[node.input_idx:][:node.input_count]
}

@(tag = "node_proc")
graph_outs_node :: #force_inline proc(
	graph: ^Graph,
	node: ^Node,
) -> []Node_Output {
	return(
		([^]Node_Output)(graph.mem.ptr)[node.output_idx:][:node.output_count] \
	)
}

graph_get_next_extra_slot :: proc(graph: ^Graph, type: u16) -> [^]u32 {
	size := size_of(Node) + int(graph.node_extra_sizes[type]) * PRECISION
	slot := arna.alloc(graph.mem, uint(size), PRECISION)
	graph.mem.pos -= uint(len(slot))

	return ([^]u32)(raw_data(slot)[size_of(Node):])
}

@(disabled = !NODE_NAMES)
push_node_name :: proc(graph: ^Graph, name: string) {
	slot := arna.alloc(graph.mem, size_of(string), 4)
	copy(slot, reflect.as_bytes(name))
}

@(disabled = !NODE_NAMES)
graph_set_name :: proc(graph: ^Graph, node: Node_ID, name: string) {
	copy(
		graph.mem.ptr[int(node) * PRECISION - PREFIX_SIZE:][:PREFIX_SIZE],
		reflect.as_bytes(name),
	)
}

graph_add_raw :: proc(
	graph: ^Graph,
	type: u16,
	dt: Node_Datatype,
	inps: []Node_ID,
	extra_capacity: int = 0,
) -> (
	id: Node_ID,
) {
	id = Node_ID(graph.mem.pos / PRECISION)

	size := size_of(Node) + int(graph.node_extra_sizes[type]) * PRECISION
	slot := arna.alloc(graph.mem, uint(size), PRECISION)

	node := (^Node)(raw_data(slot))
	node^ = {
		rtype               = type,
		dt                  = dt,
		gvn                 = graph.gvn,
		input_idx           = u32(graph.mem.pos / PRECISION),
		ordered_input_count = u16(len(inps)),
		input_count         = u16(len(inps)),
	}

	new_inps := arna.alloc(
		graph.mem,
		uint(int(len(inps) + extra_capacity) * PRECISION),
		PRECISION,
		zeroed = ODIN_DEBUG,
	)
	copy(mem.slice_data_cast([]Node_ID, new_inps), inps)

	inode := graph_intern(graph, id)
	if inode != id {
		graph.mem.pos = uint(id) * PRECISION
		return inode
	}

	for inp, i in inps {
		if inp == 0 do continue
		graph_add_output(graph, inp, id, i)
	}

	graph.gvn += 1

	return
}

@(tag = "node_proc")
graph_add_input_node :: proc(
	graph: ^Graph,
	node: ^Node,
	inp: Node_ID,
	is_scope := false,
) -> int {
	assert(is_scope, "TODO")

	free_idx := int(node.ordered_input_count)
	grow: if node.ordered_input_count == node.input_count || !is_scope {
		if !is_scope {
			free_idx, _ = slice.linear_search_reverse(
				graph_inps(graph, node),
				0,
			)
			if free_idx >= 0 do break grow
			free_idx = int(node.input_count)
		}

		graph.waste += int(node.input_count * size_of(Node_ID))
		base := u32(graph.mem.pos / PRECISION)
		new_cap := node.input_count * 2 + 2
		slot := arna.alloc(
			graph.mem,
			uint(new_cap * PRECISION),
			PRECISION,
			zeroed = true,
		)
		copy(mem.slice_data_cast([]Node_ID, slot), graph_inps(graph, node))
		node.input_count = new_cap
		node.input_idx = base
	}

	graph_inps(graph, node)[free_idx] = inp
	node.ordered_input_count += u16(is_scope)

	return free_idx
}

@(tag = "node_proc")
graph_add_extra_input_node :: proc(graph: ^Graph, node: ^Node, inp: Node_ID) {
	node.input_count += 1
	node.ordered_input_count += 1
	graph_inps(graph, node)[node.input_count - 1] = inp
	graph_add_output(graph, inp, graph_id(graph, node), node.input_count - 1)
}

graph_ensure_available_output_cap :: proc(
	graph: ^Graph,
	node: ^Node,
	available: u16,
) {
	if node.output_cap - node.output_count < available {
		graph.waste += int(node.output_cap * size_of(Node_ID))
		base := u32(graph.mem.pos / PRECISION)
		new_cap := max(node.output_cap * 2 + 2, node.output_cap + available)
		slot := arna.alloc(graph.mem, uint(new_cap * PRECISION), PRECISION)
		copy(mem.slice_data_cast([]Node_Output, slot), graph_outs(graph, node))
		node.output_cap = new_cap
		node.output_idx = base
	}
}

@(tag = "node_proc")
graph_add_output_node :: proc(
	graph: ^Graph,
	node: ^Node,
	out: Node_ID,
	#any_int i: int,
) {
	graph_ensure_available_output_cap(graph, node, 1)

	node.output_count += 1
	assert(i < 256)
	graph_outs(graph, node)[node.output_count - 1] = {
		id  = out,
		idx = i,
	}
}

graph_extra :: proc {
	graph_get_any_extra_node,
	graph_get_any_extra_node_id,
	graph_get_static_extra_node,
	graph_get_static_extra_node_id,
}

@(tag = "node_proc")
graph_get_static_extra_node :: #force_inline proc(
	graph: ^Graph,
	node: ^Node,
	$T: typeid,
) -> ^T {
	fmt.assertf(
		int(node.rtype) < len(graph.inheritance_table),
		"node: %v %v",
		graph_id(graph, node),
		graph_outs(graph, node),
	)
	if graph.inheritance_table[node.rtype] & (1 << inherit_idx_of(T)) ==
	   0 {return nil}
	return (^T)(&node.extra)
}

@(tag = "node_proc")
graph_get_any_extra_node :: #force_inline proc(
	graph: ^Graph,
	node: ^Node,
) -> any {
	return {&node.extra, graph.node_extra_types[node.rtype]}
}

@(tag = "node_proc")
graph_has_flag_node :: #force_inline proc(
	graph: ^Graph,
	node: ^Node,
	flag: Class_Flag,
) -> bool {
	return flag in graph.node_flags[node.rtype]
}

graph_display :: proc(
	w: io.Writer,
	graph: ^Graph,
	ctx: ^Graph_Schedule = nil,
	prefix: proc(_: io.Writer, _: ^Node, _: Graph_Basic_Block) = nil,
	regs: []Reg = {},
) {
	ctx := ctx
	our_ctx: Graph_Schedule

	if ctx == nil {
		graph_schedule(graph, &our_ctx)
		ctx = &our_ctx
	}

	seen_loop_trees: map[^Loop_Tree]int

	for bb in ctx.bbs {
		if bb.loop_tree != nil {
			if bb.loop_tree not_in seen_loop_trees {
				seen_loop_trees[bb.loop_tree] = len(seen_loop_trees)
			}
			if bb.loop_tree.parent not_in seen_loop_trees {
				seen_loop_trees[bb.loop_tree.parent] = len(seen_loop_trees)
			}

			fmt.wprintf(
				w,
				"%02i:%02i:%02i ",
				bb.loop_tree.depth,
				seen_loop_trees[bb.loop_tree],
				seen_loop_trees[bb.loop_tree.parent],
			)
		}

		graph_display_node(w, graph, bb.head, scheduled = true)

		fmt.wprint(w, " {\n")

		for instr in bb.instrs {
			inode := graph_get(graph, instr)
			if inode.itype == .Phi {
				continue
			}

			fmt.wprint(w, "  ")
			if len(regs) != 0 {
				if inode.dt != .Void {
					reg := regs[inode.gvn]
					fmt.wprintf(
						w,
						"%v%03i",
						reg_kind_char(reg.kind),
						reg.index,
					)
				} else {
					fmt.wprint(w, "    ")
				}
			} else if prefix != nil {
				prefix(w, inode, bb)
			}
			graph_display_node(w, graph, instr, scheduled = true)
			fmt.wprint(w, "\n")
		}

		fmt.wprint(w, "}\n")
	}
}

graph_display_node :: proc(
	w: io.Writer,
	graph: ^Graph,
	id: Node_ID,
	scheduled := false,
) {
	node := graph_expand(graph, id)

	extra := graph_extra(graph, node)

	graph_display_node_gvn(w, graph, id)
	if node.dt != .Void {
		fmt.wprintf(w, ":%v", node.dt)
	}
	fmt.wprintf(w, ":%v(", graph.node_kind_name[node.rtype])

	written_one: bool
	graph_display_extra(w, extra, "", &written_one)

	for inp, i in node.inps {
		if written_one {
			if i == int(node.ordered_input_count) {
				fmt.wprintf(w, "; ")
			} else {
				fmt.wprintf(w, ", ")
			}
		}
		written_one = true
		graph_display_node_gvn(w, graph, inp)
	}

	if node.itype == .Jump && scheduled {
		reg := node.outs[0]
		rnode := graph_expand(graph, reg.id)
		for out in rnode.outs {
			onode := graph_expand(graph, out.id)
			if onode.itype == .Phi {
				if written_one do fmt.wprintf(w, ", ")
				written_one = true
				graph_display_node_gvn(w, graph, onode.inps[1 + reg.idx])
			}
		}
	}

	if (node.itype == .Region || node.itype == .Loop) && scheduled {
		for out in node.outs {
			onode := graph_get(graph, out.id)
			if onode.itype == .Phi {
				if written_one do fmt.wprintf(w, ", ")
				written_one = true
				graph_display_node_gvn(w, graph, out.id)
			}
		}
	}

	fmt.wprint(w, ") [")
	written_one = false
	for out in node.outs {
		if out.id != 0 {
			onode := graph_expand(graph, out.id)
			if onode.itype == .Phi && scheduled {
				if out.idx != 0 {
					reg := onode.inps[0]
					rnode := graph_expand(graph, reg)
					idx := 0
					for ro in rnode.outs {
						if ro.id == out.id do break
						idx += int(graph_get(graph, ro.id).itype == .Phi)
					}
					if written_one do fmt.wprintf(w, ", ")
					written_one = true
					graph_display_node_gvn(w, graph, rnode.inps[out.idx - 1])
					fmt.wprintf(w, ":%v", 1 + idx)
				}
				continue
			}
		}
		if written_one do fmt.wprintf(w, ", ")
		written_one = true
		graph_display_node_gvn(w, graph, out.id)
		fmt.wprintf(w, ":%v", out.idx)
	}
	fmt.wprint(w, "]")
}

graph_display_extra :: proc(
	w: io.Writer,
	extra: any,
	name: string,
	written_one: ^bool,
) {
	#partial switch info in
		type_info_of(reflect.typeid_base(extra.id)).variant {
	case runtime.Type_Info_Struct:
		for field in reflect.struct_fields_zipped(extra.id) {
			extra_field := reflect.struct_field_value(extra, field)
			graph_display_extra(w, extra_field, field.name, written_one)
			if .raw_union in info.flags do break
		}
		return
	}

	if written_one^ do fmt.wprint(w, ", ")
	written_one^ = true
	if name != "" {
		fmt.wprintf(w, "%v: ", name)
	}
	fmt.wprint(w, extra)
}

ansi_start :: proc(w: io.Writer, #any_int gvn: int) {
	if .Terminal_Color in context.logger.options {
		Combo :: struct {
			fg: string,
			bg: string,
		}

		colors := [?]Combo {
			{fg = ansi.FG_BRIGHT_BLACK},
			{fg = ansi.FG_BRIGHT_RED},
			{fg = ansi.FG_BRIGHT_GREEN},
			{fg = ansi.FG_BRIGHT_YELLOW},
			{fg = ansi.FG_BRIGHT_BLUE},
			{fg = ansi.FG_BRIGHT_MAGENTA},
			{fg = ansi.FG_BRIGHT_CYAN},
			{fg = ansi.FG_RED},
			{fg = ansi.FG_GREEN},
			{fg = ansi.FG_YELLOW},
			{fg = ansi.FG_BLUE},
			{fg = ansi.FG_MAGENTA},
			{fg = ansi.FG_CYAN},
			{fg = ansi.FG_BLACK, bg = ansi.BG_WHITE},
			{fg = ansi.FG_BLACK, bg = ansi.BG_RED},
			{fg = ansi.FG_BLACK, bg = ansi.BG_GREEN},
			{fg = ansi.FG_BLACK, bg = ansi.BG_YELLOW},
			{fg = ansi.FG_WHITE, bg = ansi.BG_BLUE},
			{fg = ansi.FG_WHITE, bg = ansi.BG_BRIGHT_BLACK},
			{fg = ansi.FG_BLACK, bg = ansi.BG_MAGENTA},
			{fg = ansi.FG_BLACK, bg = ansi.BG_CYAN},
			{fg = ansi.FG_BLACK, bg = ansi.BG_WHITE},
		}

		pick := colors[gvn % len(colors)]

		if pick.fg != "" {
			fmt.wprintf(w, ansi.CSI + "%v" + ansi.SGR, pick.fg)
		}

		if pick.bg != "" {
			fmt.wprintf(w, ansi.CSI + "%v" + ansi.SGR, pick.bg)
		}
	}
}

ansi_end :: proc(w: io.Writer) {
	if .Terminal_Color in context.logger.options {
		fmt.wprint(w, ansi.CSI + ansi.RESET + ansi.SGR)
	}
}

graph_get_node_name :: proc(graph: ^Graph, id: Node_ID) -> (name: string) {
	when NODE_NAMES {
		copy(
			reflect.as_bytes(name),
			graph.mem.ptr[int(id) * PRECISION - PREFIX_SIZE:][:PREFIX_SIZE],
		)
	}
	return
}

graph_display_node_gvn :: proc(w: io.Writer, graph: ^Graph, id: Node_ID) {
	if id == 0 {
		fmt.wprint(w, "nl")
		return
	}
	n := graph_get(graph, id)

	ansi_start(w, n.gvn)

	fmt.wprintf(w, "#%v%v", n.gvn, graph_get_node_name(graph, id))

	ansi_end(w)
}
