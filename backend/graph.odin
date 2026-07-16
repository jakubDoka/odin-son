package backend

import "../vendored/gam/util/arna"
import "base:intrinsics"
import "base:runtime"
import "core:container/queue"
import "core:fmt"
import "core:math"
import "core:mem"
import "core:reflect"
import "core:simd"
import "core:slice"

when NODE_NAMES {
	PREFIX_SIZE :: size_of(string)
} else {
	PREFIX_SIZE :: 0
}

DEAD_LOCAL: i32 : -1
PRECISION :: size_of(u32)
NODE_NAMES :: #config(NODE_NAMES, ODIN_DEBUG)

Stats :: struct {
	efficiency: [Efficiency_Stat_Kind]Efficiency_Stat,
}

Efficiency_Stat_Kind :: enum int {
	graph_waste,
	late_schedule_rounds,
	ifg_rounds,
	peephole_rounds,
}

Efficiency_Stat :: struct {
	total: int,
	ideal: int,
}

add_efficiency_stat :: proc(
	stats: ^Stats,
	kind: Efficiency_Stat_Kind,
	#any_int total: int,
	#any_int ideal: int,
) {
	if stats == nil do return

	stats.efficiency[kind].total += total
	stats.efficiency[kind].ideal += ideal
}

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

DEAD_NODE_KIND :: ~u16(0)

Ideal_Node_Type :: enum u16 {
	Start,
	Entry,
	Poison,
	Arg,
	CInt,
	Add,
	Sub,
	And,
	Or,
	Xor,
	Eq,
	Ne,
	Le,
	Lt,
	Gt,
	Ge,
	U_Lt,
	U_Gt,
	U_Le,
	U_Ge,
	F_Add,
	F_Sub,
	F_Mul,
	F_Div,
	F_Eq,
	F_Ne,
	F_Lt,
	F_Le,
	F_Gt,
	F_Ge,
	Shl,
	Shr,
	U_Shr,
	Mul,
	Div,
	U_Div,
	Rem,
	U_Rem,
	And_Not,
	Split,
	Phi,
	Mem,
	Local,
	Local_Addr,
	Global,
	Global_Addr,
	Proc_Addr,
	Copy,
	Set,
	Store,
	Load,
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
	Neg,
	Not,
	Sext,
	Uext,
	Cast,
	F_To_I,
	F_From_I,
	F_Ext,
	F_Demote,
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

Scope :: struct #align (4) {
	done: bool,
}

CInt :: struct #raw_union #align (4) {
	value:  i64,
	fvalue: f64,
}

Call :: struct {
	using _: Cfg,
	using _: bit_field u32 {
		ccid:     u32  | 30,
		imported: bool | 1,
		indirect: bool | 1,
	},
	cid:     u32,
}

Tup :: struct {
	using fields: struct #raw_union {
		idx:     u32,
		using _: bit_field u32 {
			size:      int  | 16,
			align:     int  | 15,
			is_inline: bool | 1,
		},
	},
	end:          [0]u8,
}

Local :: struct {
	using props: struct #raw_union {
		size:       i32,
		offset:     i32,
		rename_idx: i32,
	},
}

No_Extra :: struct {}

Node_Datatype :: enum u8 {
	Void,
	I8,
	I16,
	I32,
	I64,
	F32,
	F64,
}

DT_SIZE := [Node_Datatype]int {
	.Void = 0,
	.I8   = 1,
	.I16  = 2,
	.I32  = 4,
	.I64  = 8,
	.F32  = 4,
	.F64  = 8,
}

FLOAT_DTS :: bit_set[Node_Datatype]{.F64, .F32}

int_for_size :: proc(size: int) -> Node_Datatype {
	assert(math.is_power_of_two(size))
	assert(size <= 8)
	return Node_Datatype(
		u8(Node_Datatype.I8) + u8(intrinsics.count_trailing_zeros(size)),
	)
}

Node_ID :: distinct u32

Node_Output :: bit_field u32 {
	id:  Node_ID | 22,
	idx: int     | 10,
}

Node :: struct {
	using spec:   struct #align (4) {
		using _: struct #raw_union {
			itype: Ideal_Node_Type,
			btype: Builder_Node_Type,
			xtype: X64_Node_Type,
			rtype: u16,
		},
		using _: bit_field u16 {
			dt:                    Node_Datatype | 4,
			in_worklist:           bool          | 1,
			is_store:              bool          | 1,
			is_load:               bool          | 1,
			in_place_slot_offset:  i8            | 2,
			additional_data_start: u8            | 2,
			mem_alignment_pow:     u32           | 3,
			extra_dwords:          u32           | 2,
		},
	},
	gvn:          u32,
	input_idx:    u32,
	input_count:  u16,
	input_cap:    u16,
	output_idx:   u32,
	output_count: u16,
	output_cap:   u16,
	extra:        [0]u32,
}

#assert(size_of(Node) == 24)

Node_Intern_Entry :: struct {
	hash: u8,
	id:   Node_ID,
}

Interner :: struct {
	hash_idx: uintptr,
	node_idx: uintptr,
	len:      int,
	cap:      int,
}

Graph :: struct {
	using node_spec: ^Node_Spec,
	using stats:     ^Stats,
	worklist:        ^queue.Queue(Node_ID),
	triggers:        ^[dynamic][dynamic; 4]Node_ID,
	mem:             ^arna.Allocator,
	using meta:      Graph_Meta,
	dont_intern:     bool,
	dont_delete:     bool,
	peeped:          bool,
	opt_flags:       Graph_Opt_Flags,
}

Graph_Meta :: struct {
	interner: Interner,
	weight:   int,
	gvn:      u32,
	start:    Node_ID,
	entry:    Node_ID,
	end:      Node_ID,
	waste:    int,
}

Stencil :: struct {
	mem:        []u8,
	using meta: Graph_Meta,
}

Graph_Opt_Flags :: bit_set[Graph_Opt_Flag]

Graph_Opt_Flag :: enum int {
	Iter_Peeps,
	Local_Peeps,
	Mem_Opt,
}

Peep_Ctx :: struct {
	using graph: ^Graph,
}

peep_ctx_graph_is_complete :: proc(ctx: Peep_Ctx) -> bool {
	return ctx.worklist != nil
}

peep_ctx_add_trigger :: proc(ctx: Peep_Ctx, triggerer: Node_ID, tar: Node_ID) {
	if triggerer == 0 do return
	if ctx.triggers == nil do return

	gvn := graph_get(ctx, triggerer).gvn
	if len(ctx.triggers) <= int(gvn) {
		resize(ctx.triggers, gvn + 1)
	}
	if !slice.contains(ctx.triggers[gvn][:], tar) {
		append(&ctx.triggers[gvn], tar)
	}
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

Block_State :: struct {
	end_scope: Node_ID,
}

graph_start_block :: proc(state: ^Block_State) {
	state^ = {}
}

graph_break_block :: proc(
	graph: ^Graph,
	scope: ^Node_ID,
	state: ^Block_State,
) {
	state.end_scope = graph_merge_scopes(graph, state.end_scope, scope^)
	scope^ = 0
}

graph_end_block :: proc(graph: ^Graph, scope: ^Node_ID, state: ^Block_State) {
	state.end_scope = graph_merge_scopes(graph, state.end_scope, scope^)
	scope^ = state.end_scope
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
	if worklist == nil do return

	node := graph_get(graph, id)
	if node.rtype == DEAD_NODE_KIND do return
	if node.in_worklist {
		if false {
			for elem in worklist.data {
				if elem == id do return
			}
			fmt.panicf("wuta: %v", node)
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
	for {
		id := queue.pop_front_safe(worklist) or_return
		nd := graph_get(graph, id)
		if nd.rtype == DEAD_NODE_KIND do continue
		nd.in_worklist = false
		return id, true
	}
}

graph_pin :: proc(graph: ^Graph, id: Node_ID) {
	if id == 0 do return
	graph_add_output(graph, id, 0, 0)
}

graph_unpin :: proc(graph: ^Graph, id: Node_ID, no_delete := false) {
	if id == 0 do return
	graph_remove_output(graph, id, {}, no_delete)
}

graph_peep :: proc(graph: ^Graph, id: Node_ID) -> Node_ID {
	if .Local_Peeps not_in graph.opt_flags do return id
	if id == 0 do return id

	node := graph_expand(graph, id)
	if len(node.outs) > 0 do return id

	prev_hash := graph_node_hash(graph, node)
	res := graph.peep({graph}, node)
	if res == 0 do return id

	if res == id {
		graph_unintern(graph, id, prev_hash)
		res = graph_intern(graph, id)
		if res == id do return id
	}

	graph_pin(graph, res)
	graph_delete(graph, node)
	graph_unpin(graph, res, no_delete = true)

	return res
}

graph_schedule_peeps :: proc(graph: ^Graph, schedule: ^Graph_Schedule) {
	for &bb in schedule.bbs {
		for &instr, i in bb.instrs[:len(bb.instrs) - 1] {
			node := graph_expand(graph, instr)
			new_node := graph.post_schedule_peep({graph, bb.instrs[:i]}, node)
			if new_node == 0 do continue
			if new_node == instr do continue
			graph_subsume(graph, new_node, instr)
			instr = new_node
		}
	}

	for &bb in schedule.bbs {
		keep := 0
		for instr in bb.instrs {
			if graph_get(graph, instr).rtype != DEAD_NODE_KIND {
				bb.instrs[keep] = instr
				keep += 1
			}
		}
		resize(&bb.instrs, keep)
	}

	for &bb in schedule.bbs {
		phi_shift: #reverse for instr, i in bb.instrs {
			inode := graph_expand(graph, instr)
			if inode.output_count == 1 &&
			   graph_get(graph, inode.outs[0].id).itype == .Phi &&
			   graph_get(graph, inode.outs[0].id).dt != .Void &&
			   (0 == len(inode.inps) ||
					   (graph_get(graph, inode.inps[0]).itype == .Phi &&
							   inode.inps[0] == inode.outs[0].id &&
							   graph_get(graph, inode.inps[0]).output_count >
								   1)) {

				for inp in inode.inps[min(1, len(inode.inps)):] {
					if graph_get(graph, inp).itype == .Phi {
						continue phi_shift
					}
				}

				slice.rotate_left(bb.instrs[i:len(bb.instrs) - 1], 1)
			}
		}
	}

	add_efficiency_stat(
		graph,
		.graph_waste,
		graph.mem.pos,
		int(graph.mem.pos) - graph.waste,
	)
}

graph_find_node :: proc(
	graph: ^Graph,
	kind: Ideal_Node_Type,
	on: Node_ID = 0,
) -> (
	Node_ID,
	bool,
) {
	for eout in graph_outs(graph, on if on != 0 else graph.entry) {
		enode := graph_expand(graph, eout.id)
		if enode.itype == kind {
			return eout.id, true
		}
	}
	return 0, false
}

graph_inline :: proc(graph: ^Graph, call: Node_ID, from: ^Graph) {
	assert(graph.node_spec == &SPECS[.Builder])

	context.allocator, _ = arna.scrath()

	Ctx :: struct {
		graph:      ^Graph,
		from:       ^Graph,
		projection: []Node_ID,
	}

	ctx: Ctx
	ctx.graph = graph
	ctx.from = from
	ctx.projection = make([]Node_ID, from.gvn)

	call := graph_expand(graph, call)

	entry := graph_expand(from, ctx.from.entry)
	mem_id := graph_find_node(from, .Mem) or_else panic("")
	mem := graph_get(from, mem_id)
	ctx.projection[entry.gvn] = call.inps[0]
	ctx.projection[mem.gvn] = call.inps[1]

	Arg_Entry :: bit_field u64 {
		id:  Node_ID | 32,
		gvn: u32     | 32,
	}
	starter: Node_ID
	params: [dynamic]Arg_Entry
	for o in entry.outs {
		onode := graph_expand(from, o.id)
		is_local_arg := onode.itype == .Local
		if is_local_arg {
			for lo in onode.outs {
				if graph_get(from, lo.id).itype == .Call {
					is_local_arg = false
					break
				}
			}
		}

		if onode.itype == .Arg || is_local_arg {
			append(&params, Arg_Entry{id = o.id, gvn = onode.gvn})
		}

		if is_cfg(from, o.id) {
			assert(starter == 0)
			starter = o.id
		}
	}

	assert(len(params) == int(call.input_cap))
	for i in 0 ..< len(params) {
		param := params[i]
		arg := raw_data(call.inps)[i]
		ctx.projection[param.gvn] = arg
	}

	clone_along_cfg(&ctx, starter)

	cend := graph_expand(graph, call.outs[0].id)
	ret := graph_expand(from, from.end)

	for o in cend.outs {
		onode := graph_expand(ctx.graph, o.id)
		if onode.itype == .Mem {
			sub := graph_get(from, ret.inps[1])
			graph_subsume(graph, ctx.projection[sub.gvn], o.id)
		}
		if onode.itype == .Ret {
			RET_PREFIX :: 2
			idx := graph_extra(graph, onode, Tup).idx
			sub := graph_get(from, ret.inps[RET_PREFIX + idx])
			graph_subsume(graph, ctx.projection[sub.gvn], o.id)
		}
	}

	end_ctrl := graph_get(from, ret.inps[0])
	graph_subsume(graph, ctx.projection[end_ctrl.gvn], call.outs[0].id)

	clone_along_cfg :: proc(ctx: ^Ctx, root: Node_ID) {
		node := graph_expand(ctx.from, root)
		if ctx.projection[node.gvn] != 0 do return

		if node.itype == .Region {
			for i in node.inps {
				inode := graph_expand(ctx.from, i)
				if ctx.projection[node.gvn] == 0 {
					return
				}
			}

			for out in node.outs {
				onode := graph_expand(ctx.from, out.id)
				if onode.itype == .Phi {
					for inp in onode.inps[1:] {
						clone_node(ctx, inp)
					}
				}
			}
		}

		if node.itype == .Loop {
			for out in node.outs {
				onode := graph_expand(ctx.from, out.id)
				if onode.itype == .Phi {
					clone_node(ctx, onode.inps[1])
				}
			}
		}

		clone_node(ctx, root)
		nid := ctx.projection[node.gvn]

		for out in node.outs {
			if !is_cfg(ctx.from, out.id) do continue

			onode := graph_expand(ctx.from, out.id)

			if onode.itype == .Loop && out.idx == 1 {
				proj := ctx.projection[onode.gvn]
				graph_add_input(ctx.graph, proj, nid)

				for lout in onode.outs {
					lonode := graph_expand(ctx.graph, lout.id)
					if lonode.btype == .Phi {
						lproj := ctx.projection[lonode.gvn]
						lpnode := graph_get(ctx.graph, lproj)
						backedge := graph_get(ctx.from, lonode.inps[2])
						bproj := ctx.projection[backedge.gvn]
						lpnode.itype = .Phi
						graph_add_input(ctx.graph, lproj, bproj)
						id := graph_intern(ctx.graph, lout.id)
						if id != lout.id {
							graph_subsume(ctx.graph, id, lout.id)
							ctx.projection[lonode.gvn] = id
						}
					}
				}

				continue
			}

			clone_along_cfg(ctx, out.id)
		}
	}

	clone_node :: proc(ctx: ^Ctx, root: Node_ID) {
		graph := ctx.graph

		node := graph_expand(ctx.from, root)
		if ctx.projection[node.gvn] != 0 do return

		assert(!is_cfg(ctx.from, root))

		input_cap := node.input_cap
		rtype := node.rtype
		if node.itype not_in KEEP_CAPACITY {
			input_cap = node.input_count
		}

		if node.itype == .Loop {
			input_cap = 1
		}

		if node.itype == .Phi &&
		   graph_get(ctx.from, node.inps[0]).itype == .Loop {
			rtype = u16(Builder_Node_Type.Lazy_Phi)
			input_cap = 2
		}

		inps := make([]Node_ID, input_cap)
		for inp, i in raw_data(node.inps)[:input_cap] {
			clone_node(ctx, inp)
			inps[i] = ctx.projection[graph_get(ctx.from, inp).gvn]
		}

		if node.itype == .Return do return

		prev := graph.mem.pos

		size :=
			size_of(Node) +
			int(graph.node_extra_sizes[node.rtype]) * PRECISION +
			int(node.extra_dwords) * PRECISION
		push_node_name(graph, graph_get_node_name(ctx.from, root))
		slot := arna.alloc(graph.mem, uint(size), PRECISION)

		mem.copy_non_overlapping(raw_data(slot), node.node, len(slot))

		new_node := (^Node)(raw_data(slot))
		new_node.gvn = graph.gvn
		graph.gvn += 1

		new_node.input_idx = u32(graph.mem.pos / PRECISION)
		_ = arna.clone(graph.mem, raw_data(node.inps)[:node.input_cap])

		new_node.output_idx = u32(graph.mem.pos / PRECISION)
		_ = arna.alloc(graph.mem, uint(node.output_cap * PRECISION), PRECISION)
		new_node.output_count = 0
		new_node.output_cap = node.output_cap

		id := graph_id(graph, new_node)
		interned := graph_intern(graph, id)
		if interned != id {
			graph.mem.pos = prev
			id = interned
		}

		ctx.projection[node.gvn] = id
	}
}

KEEP_CAPACITY :: bit_set[Ideal_Node_Type]{.Call}

graph_compute_weight :: proc(graph: ^Graph, all: []Node_ID) {
	@(static, rodata)
	WEIGHTS := #partial [Ideal_Node_Type]u8 {
		.Loop = 5,
		.Call = 10,
		.Add ..= .And_Not      = 1,
	}

	graph.weight = 1

	for n in all {
		graph.weight += int(WEIGHTS[graph_get(graph, n).itype])
	}
}

// mem is borrowed
graph_stencil :: proc(graph: ^Graph) -> (s: Stencil) {
	s.mem = graph.mem.ptr[:graph.mem.pos]
	s.meta = graph.meta
	return
}

graph_compact :: proc(graph: ^Graph) {
	context.allocator, _ = arna.scrath()

	worklist: queue.Queue(Node_ID)
	queue.init(&worklist, int(graph.gvn * 3 / 5 + 20))

	collect_nodes(graph, &worklist)

	prev_mem := graph.mem^
	prev := graph^
	prev.mem = &prev_mem

	graph.mem.ptr = graph.mem.ptr[graph.mem.pos:]
	graph.mem.pos = PRECISION
	graph.gvn = 0

	interned_count := 0

	for &n in worklist.data[:worklist.len] {
		node := graph_expand(&prev, n)

		interned_count += int(graph_has_flag(&prev, node, .Interned))
		if node.itype not_in KEEP_CAPACITY {
			node.input_cap = node.input_count
		}
		node.output_cap = node.output_count

		size :=
			size_of(Node) +
			int(graph.node_extra_sizes[node.rtype]) * PRECISION +
			int(node.extra_dwords) * PRECISION
		push_node_name(graph, graph_get_node_name(&prev, n))
		slot := arna.alloc(graph.mem, uint(size), PRECISION)

		mem.copy_non_overlapping(raw_data(slot), node.node, len(slot))

		new_node := (^Node)(raw_data(slot))
		new_node.gvn = graph.gvn
		graph.gvn += 1

		new_node.input_idx = u32(graph.mem.pos / PRECISION)
		_ = arna.clone(graph.mem, raw_data(node.inps)[:node.input_cap])

		new_node.output_idx = u32(graph.mem.pos / PRECISION)
		_ = arna.clone(graph.mem, node.outs)

		n = graph_id(graph, new_node)
	}

	graph.interner.len = 0
	graph.interner.cap = 0
	graph_interner_grow(
		graph,
		mem.align_forward_int(interned_count, align_of(Intern_Vec)),
	)

	iview := graph_interner_zip(graph)

	for n in worklist.data[:worklist.len] {
		node := graph_expand(graph, n)
		node.in_worklist = false

		for &inp in raw_data(node.inps)[:node.input_cap] {
			if inp == 0 do continue
			inp = project(&prev, worklist, inp)
		}

		for &out in node.outs {
			out.id = project(&prev, worklist, out.id)
		}

		if graph_has_flag(graph, node, .Interned) {
			hash := graph_node_hash(graph, node)
			iview[graph.interner.len] = {hash, n}
			graph.interner.len += 1
		}
	}

	assert(graph.interner.len == interned_count)

	graph.start = project(&prev, worklist, graph.start)
	graph.entry = project(&prev, worklist, graph.entry)
	graph.end = project(&prev, worklist, graph.end)

	project :: proc(
		prev: ^Graph,
		wl: queue.Queue(Node_ID),
		node: Node_ID,
	) -> Node_ID {
		return wl.data[:wl.len][graph_get(prev, node).gvn]
	}

	mem.copy(prev.mem.ptr, graph.mem.ptr, int(graph.mem.pos))
	graph.mem.ptr = prev.mem.ptr
	graph.waste = 0
}

graph_iter_peeps :: proc(graph: ^Graph) -> (optimized: bool) {
	is_builder := graph.node_spec == &SPECS[.Builder]

	if graph.peeped && is_builder do return
	graph.peeped = true

	if .Iter_Peeps not_in graph.opt_flags && is_builder do return

	graph.dont_intern = !is_builder
	defer graph.dont_intern = false

	context.allocator, _ = arna.scrath()

	worklist: queue.Queue(Node_ID)
	queue.init(&worklist, int(graph.gvn))

	triggers: [dynamic][dynamic; 4]Node_ID

	graph.worklist = &worklist
	graph.triggers = &triggers

	collect_nodes(graph, &worklist)

	rounds := 0
	for n in worklist_next(graph, &worklist) {
		rounds += 1

		node := graph_expand(graph, n)

		prev_hash := graph_node_hash(graph, node)
		new_node := graph.peep({graph}, node)
		if node.rtype == DEAD_NODE_KIND do continue
		if new_node == 0 && node.output_count != 0 do continue

		optimized = true

		for out in node.outs {
			worklist_add(graph, &worklist, out.id)
		}

		if int(node.gvn) < len(triggers) {
			for trig in triggers[node.gvn] {
				worklist_add(graph, &worklist, trig)
			}
			triggers[node.gvn] = {}
		}

		if new_node == n {
			graph_unintern(graph, n, prev_hash)
			new_node = graph_intern(graph, n)
			if new_node == n do continue
		}

		node = graph_expand(graph, n)

		for inp in node.inps {
			worklist_add(graph, &worklist, inp)
		}

		if new_node != 0 {
			graph_subsume(graph, new_node, n, &worklist)
		} else {
			graph_delete(graph, n, indirect = true)
		}
	}

	add_efficiency_stat(graph, .peephole_rounds, rounds, graph.gvn)

	if ODIN_DEBUG {
		collect_nodes(graph, &worklist)

		for n in worklist_next(graph, &worklist) {
			node := graph_expand(graph, n)
			for out in node.outs {
				onode := graph_get(graph, out.id)
				if onode.itype != .Call {
					assert(out.idx < int(onode.input_count))
				}
			}
			assert(
				node.itype != .Local ||
				graph_extra(graph, node, Local).size != DEAD_LOCAL,
			)
			new_node := graph.peep({graph}, node)
			if new_node != 0 {
				//log.info(graph)

				fmt.assertf(
					new_node == 0,
					"\nnew: %v\nold: %v",
					graph_get(graph, new_node),
					node.node,
				)
			}
		}
	}

	graph.worklist = nil
	graph.triggers = nil

	return
}

collect_nodes :: proc(graph: ^Graph, worklist: ^queue.Queue(Node_ID)) {
	i := 0
	worklist.offset = 0
	worklist_add(graph, worklist, graph.start)
	for i < int(worklist.len) {
		node := graph_expand(graph, worklist.data[i])
		node.gvn = u32(i)

		for inp in node.inps {
			if inp == 0 do continue
			worklist_add(graph, worklist, inp)
		}

		for out in node.outs {
			worklist_add(graph, worklist, out.id)
		}

		i += 1
	}
	graph.gvn = u32(worklist.len)

	return
}

is_noalias :: proc {
	is_noalias_ptrs,
	is_noalias_ops,
}

is_noalias_ops :: proc(graph: ^Graph, a, b: Node_ID) -> bool {
	sizes: [2]int
	nodes := [?]Node_ID{a, b}

	for &n, i in nodes {
		node := graph_expand(graph, n)
		sizes[i] = mem_op_size(graph, n) or_return
		n = node.inps[2]
	}

	return is_noalias(graph, nodes[0], nodes[1], sizes[0], sizes[1])
}

mem_op_size :: proc(
	graph: ^Graph,
	n: Node_ID,
) -> (
	size: int,
	ok: bool = true,
) {
	node := graph_expand(graph, n)
	#partial switch node.itype {
	case .Store:
		size = DT_SIZE[graph_get(graph, node.inps[3]).dt]
	case .Load, .Load_S:
		size = DT_SIZE[node.dt]
	case .Set, .Copy:
		size_cnst := graph_extra(graph, node.inps[4], CInt)
		if size_cnst == nil {
			size = 1 << 30
		} else {
			size = int(size_cnst.value)
		}
	case:
		return 0, false
	}
	return
}

is_noalias_ptrs :: proc(graph: ^Graph, a, b: Node_ID, as, bs: int) -> bool {
	abase, aoffset := base_and_offset(graph, a)
	bbase, boffset := base_and_offset(graph, b)

	anode := graph_get(graph, abase)
	bnode := graph_get(graph, bbase)

	if anode == bnode {
		aend, bend := aoffset + as, boffset + bs
		return aoffset >= bend || boffset >= aend
	}

	return false
}

base_and_offset :: proc(
	graph: ^Graph,
	node: Node_ID,
) -> (
	base: Node_ID,
	off: int,
) {
	base = node
	for {
		bnode := graph_expand(graph, base)
		if bnode.itype == .Add {
			lhs_const := graph_extra(graph, bnode.inps[1], CInt)
			if lhs_const == nil do return
			base = bnode.inps[0]
			off += int(lhs_const.value)
			continue
		}

		if bnode.xtype == .X64_Add {
			base = bnode.inps[0]
			off += int(graph_extra(graph, bnode, X64_Mem_Op).imm)
			continue
		}

		return
	}
}

Offset_Iter :: struct {
	curr:    Node_ID,
	offset:  int,
	out_idx: int,
}

offset_iter_next :: proc(
	ctx: ^Graph,
	iter: ^Offset_Iter,
) -> (
	Node_Output,
	bool,
) {
	for {
		curr := graph_expand(ctx, iter.curr)
		if iter.out_idx == len(curr.outs) {
			if curr.itype == .Add {
				parent := graph_expand(ctx, curr.inps[0])
				off := graph_extra(ctx, curr.inps[1], CInt)
				iter.offset -= int(off.value)
				iter.out_idx =
					slice.linear_search(
						parent.outs,
						Node_Output{id = iter.curr, idx = 0},
					) or_else panic("")
				iter.out_idx += 1
				iter.curr = curr.inps[0]
				continue
			} else {
				return {}, false
			}
		}

		next := curr.outs[iter.out_idx]
		next_node := graph_expand(ctx, next.id)
		recurse: if next_node.itype == .Add {
			off := graph_extra(ctx, next_node.inps[1], CInt)
			if off == nil do break recurse
			iter.offset += int(off.value)
			iter.curr = next.id
			iter.out_idx = 0
			continue
		}

		iter.out_idx += 1
		return next, true
	}
}

graph_start_loop :: proc(graph: ^Graph, scope: Node_ID, state: ^Loop_State) {
	snode := graph_expand(graph, scope)
	loop := graph_add_loop(graph, "loop", snode.inps[0])
	graph_set_input(graph, scope, 0, loop)
	state.scope = graph_clone(graph, scope)

	graph_add_output(graph, state.scope, 0, 0)

	snode = graph_expand(graph, scope)
	for i in 1 ..< snode.input_count {
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
		assert(init.input_count == backedge.input_count)
		for i in 1 ..< init.input_count {
			init := init.inps[i]
			inode := graph_expand(graph, init)
			bnode := graph_expand(graph, backedge.inps[i])
			if inode.btype != .Lazy_Phi || inode.inps[0] != loop do continue

			for {
				scp := graph_extra(graph, bnode, Scope)
				if scp == nil || !scp.done || bnode.inps[0] == loop do break
				bnode = graph_expand(graph, bnode.inps[i])
			}

			if bnode.btype == .Scope || inode.node == bnode.node {
				graph_subsume(graph, inode.inps[1], init)
			} else {
				graph_connect(graph, init, graph_id(graph, bnode))
				inode.itype = .Phi
				id := graph_intern(graph, init)
				if id != init do graph_subsume(graph, id, init)
			}
		}

		assert(graph_get(graph, init.inps[0]).itype == .Loop)
		graph_connect(graph, init.inps[0], backedge.inps[0])
	}

	node_scope^ = state.scopes[.Break]

	if node_scope^ != 0 {
		exit := graph_expand(graph, node_scope^)
		for i in 1 ..< exit.input_count {
			enode := graph_expand(graph, exit.inps[i])
			if enode.btype == .Scope && enode.inps[0] == loop {
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
	base_size := graph_get(ctx, loop.scope).input_count
	graph_truncate_scope(ctx, scope, base_size)
	loop.scopes[variant] = graph_merge_scopes(ctx, scope, loop.scopes[variant])
}

graph_merge_returns :: proc(graph: ^Graph, args: []Node_ID) -> Node_ID {
	if graph.end == 0 {
		args[0] = graph_add_region(graph, "rret", {args[0], graph.start})
		for &a in args[1:] {
			push_node_name(graph, "rphi")
			a = graph_add_raw(
				graph,
				u16(Ideal_Node_Type.Phi),
				graph_get(graph, a).dt,
				{args[0], a},
			)
		}

		graph.end = graph_add_return(graph, "ret", args)
	} else {
		end := graph_expand(graph, graph.end)

		reg := graph_expand(graph, end.inps[0])

		prev_cached := reg.inps[len(reg.inps) - 1]
		reg.input_count -= 1
		graph_remove_output(
			graph,
			prev_cached,
			{idx = len(reg.inps) - 1, id = end.inps[0]},
			no_delete = true,
		)

		graph_connect(graph, end.inps[0], args[0])

		for i in 1 ..< len(end.inps) {
			new := i < len(args) ? args[i] : graph_add_poison(graph, "rpsn")
			graph_connect(graph, end.inps[i], new)
		}

		graph_connect(graph, end.inps[0], prev_cached)
	}

	return graph.end
}

graph_interner_zip :: proc(graph: ^Graph) -> (r: #soa[]Node_Intern_Entry) {
	r.hash = graph.mem.ptr[graph.interner.hash_idx * PRECISION:]
	r.id = ([^]Node_ID)(graph.mem.ptr)[graph.interner.node_idx:]
	runtime.raw_soa_footer(&r).len = graph.interner.cap
	return
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
	iview := graph_interner_zip(graph)
	assert(mem.is_aligned(iview.hash, align_of(Intern_Vec)))
	assert(id != 0)

	needle := precomputed_hash
	if needle == 0 {
		needle = graph_node_hash(graph, id)
	}
	assert(needle != 0)

	for mask, i in mem.slice_data_cast([]Intern_Vec, iview.hash[:len(iview)]) {
		eqs := simd.lanes_eq(mask, Intern_Vec(needle))
		bits := transmute(u16)simd.extract_lsbs(eqs)
		for bits != 0 {
			idx :=
				i * size_of(Intern_Vec) + int(simd.count_trailing_zeros(bits))
			bits &= bits - 1

			if graph_node_eq(graph, iview.id[idx], id) {
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

	iview := graph_interner_zip(graph)

	idx, hash, _ := graph_interner_find(graph, id, 0)
	if idx >= 0 do return iview.id[idx]

	if len(iview) == graph.interner.len {
		new_cap := len(iview) * 2 + size_of(Intern_Vec)
		graph_interner_grow(graph, new_cap)
		iview = graph_interner_zip(graph)
	}

	iview[graph.interner.len] = {hash, id}
	graph.interner.len += 1

	return id
}

graph_interner_grow :: proc(graph: ^Graph, new_cap: int) {
	assert(mem.is_aligned(rawptr(uintptr(new_cap)), align_of(Intern_Vec)))

	iview := graph_interner_zip(graph)

	hashes := arna.alloc(
		graph.mem,
		uint(new_cap),
		align_of(Intern_Vec),
		zeroed = true,
	)
	nodes := arna.smake(graph.mem, []Node_ID, new_cap)

	mem.copy_non_overlapping(raw_data(hashes), iview.hash, len(iview))
	mem.copy_non_overlapping(
		raw_data(nodes),
		iview.id,
		len(iview) * size_of(Node_ID),
	)

	graph.interner.hash_idx =
		(uintptr(raw_data(hashes)) - uintptr(graph.mem.ptr)) / PRECISION
	graph.interner.node_idx =
		(uintptr(raw_data(nodes)) - uintptr(graph.mem.ptr)) / PRECISION
	graph.interner.cap = new_cap
}

graph_unintern :: proc(graph: ^Graph, id: Node_ID, precomputed_hash: u8 = 0) {
	if !graph_has_flag(graph, id, .Interned) || graph.dont_intern do return

	idx, _, _ := graph_interner_find(graph, id, precomputed_hash)
	if idx < 0 do return

	iview := graph_interner_zip(graph)

	graph.interner.len -= 1
	iview[idx] = iview[graph.interner.len]

	// NOTE: there is probably a bug in the odin compiler that requires us
	// to not set the value with a leteral
	tmp: Node_Intern_Entry
	iview[graph.interner.len] = tmp
}

node_approx_size :: proc(graph: ^Graph, node: ^Node) -> uint {
	return(
		size_of(Node) +
		uint(graph.node_extra_sizes[node.rtype]) * PRECISION +
		uint(node.input_cap * size_of(Node_ID)) \
	)
}

graph_subsume :: proc(
	graph: ^Graph,
	with: Node_ID,
	target: Node_ID,
	worklist: ^queue.Queue(Node_ID) = nil,
	dont_delete: bool = false,
) {
	assert(with != graph.start)
	assert(target != graph.entry)

	wnode := graph_expand(graph, with)
	tnode := graph_expand(graph, target)

	assert(with != target)

	graph_ensure_available_output_cap(graph, wnode, tnode.output_count)

	wnode.output_count += tnode.output_count
	tnode.output_count = 0

	wnode = graph_expand(graph, with)

	copy(wnode.outs[len(wnode.outs) - len(tnode.outs):], tnode.outs)

	for out in tnode.outs {
		if out == {} do continue
		graph_unintern(graph, out.id)
		graph_inps(graph, out.id)[out.idx] = with
	}

	graph_pin(graph, with)

	if !dont_delete do graph_delete(graph, tnode)

	wnode = graph_expand(graph, with)

	keep := 0
	for out in tnode.outs {
		if out == {} do continue
		for oout in wnode.outs {
			if oout == {} do continue
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

	graph_unpin(graph, with)
}

graph_node_eq :: proc(graph: ^Graph, a, b: Node_ID) -> bool {
	if a == b do return true

	an, bn := graph_get(graph, a), graph_get(graph, b)
	if an.spec != bn.spec do return false

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
	return graph_connect(graph, scope, value)
}

graph_truncate_scope :: proc(
	graph: ^Graph,
	scope: Node_ID,
	#any_int to_len: int,
) {
	if scope == 0 do return

	snode := graph_expand(graph, scope)
	assert(snode.btype == .Scope)
	assert(to_len <= int(snode.input_count))

	for &inp, i in snode.inps[to_len:] {
		graph_remove_output(graph, inp, {idx = to_len + i, id = scope})
		inp = 0
	}

	snode.input_count = u16(to_len)
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

	assert(lnode.input_count == rnode.input_count)

	region := graph_add_region(
		graph,
		"reg",
		{lnode.inps[0], rnode.inps[0], graph.start},
	)

	for i in 1 ..< lnode.input_count {
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

	assert(idx < len(node.inps))
	if node.inps[idx] == value do return id

	assert(node.inps[idx] != 0)

	graph_add_output(graph, value, id, idx)
	graph_remove_output(graph, node.inps[idx], {idx = idx, id = id})

	graph_unintern(graph, id)
	node.inps[idx] = value
	return graph_intern(graph, id)
}

graph_clone :: proc(graph: ^Graph, id: Node_ID) -> Node_ID {
	node := graph_expand(graph, id)
	assert(node.itype != .Call)
	graph.dont_intern = true
	push_node_name(graph, graph_get_node_name(graph, id))
	idx := graph_get_next_extra_slot(graph, node.rtype)
	extra := graph_extra_dwords(graph, node)
	copy(idx[:len(extra)], extra)
	new := graph_add_raw(graph, node.rtype, node.dt, node.inps)
	graph_get(graph, new).input_count = node.input_count
	graph.dont_intern = false
	return new
}

@(tag = "node_proc")
graph_remove_output_node :: proc(
	graph: ^Graph,
	node: ^Node,
	out: Node_Output,
	no_delete := false,
) {
	outs := graph_outs(graph, node)
	out_idx := slice.linear_search(outs, out) or_else fmt.panicf("%v", node)
	outs[out_idx] = outs[len(outs) - 1]
	node.output_count -= 1
	if !no_delete {
		graph_delete(graph, node, indirect = true)
	}
}

@(tag = "node_proc")
graph_node_hash_node :: proc(graph: ^Graph, node: ^Node) -> u8 {
	if !graph_has_flag(graph, node, .Interned) do return 0

	hash: u32

	spec := transmute(u32)(node.spec)
	extra_dwords := graph_extra_dwords(graph, node)
	inps := graph_inps(graph, node)

	hash += spec
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
	if graph.dont_delete do return

	if graph.triggers != nil && int(node.gvn) < len(graph.triggers) {
		for trig in graph.triggers[node.gvn] {
			worklist_add(graph, graph.worklist, trig)
		}
		graph.triggers[node.gvn] = {}
	}

	for inp, i in graph_inps(graph, node) {
		if inp == 0 do continue
		if graph.worklist != nil && len(graph_outs(graph, inp)) > 1 {
			worklist_add(graph, graph.worklist, inp)
		}
		graph_remove_output(graph, inp, {idx = i, id = id})
	}

	graph_unintern(graph, graph_id(graph, node))

	size := node_approx_size(graph, node)

	graph.waste += int(node.input_cap * size_of(Node_ID))
	graph.waste += int(node.output_count * size_of(Node_Output))
	graph.waste += size_of(Node)
	graph.waste += int(graph.node_extra_sizes[node.rtype] * PRECISION)

	node^ = {
		rtype = DEAD_NODE_KIND,
	}
}

@(tag = "node_proc")
graph_extra_dwords_node :: proc(graph: ^Graph, node: ^Node) -> []u32 {
	return mem.slice_data_cast(
		[]u32,
		raw_data(&node.extra)[:graph.node_extra_sizes[node.rtype]],
	)
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
	assert(node.rtype != DEAD_NODE_KIND)
	in_place := graph.inplace_slot_idxs[node.rtype]
	in_place += i8(node.additional_data_start)
	in_place += node.in_place_slot_offset
	return {
		node,
		graph_inps(graph, node),
		graph_outs(graph, node),
		int(graph.first_input_idxs[node.rtype] + node.additional_data_start),
		int(in_place),
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
	assert(node != 0)
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
		rtype       = type,
		dt          = dt,
		gvn         = graph.gvn,
		is_store    = .Store in graph.node_flags[type],
		is_load     = .Load in graph.node_flags[type],
		input_idx   = u32(graph.mem.pos / PRECISION),
		input_count = u16(len(inps)),
		input_cap   = u16(len(inps) + extra_capacity),
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

graph_connect :: proc(graph: ^Graph, use: Node_ID, def: Node_ID) -> int {
	idx := graph_add_input(graph, use, def)
	graph_add_output(graph, def, use, idx)
	return idx
}

@(tag = "node_proc")
graph_add_input_node :: proc(graph: ^Graph, node: ^Node, inp: Node_ID) -> int {
	free_idx := int(node.input_count)
	grow: if node.input_count == node.input_cap {
		graph.waste += int(node.input_cap * size_of(Node_ID))
		base := u32(graph.mem.pos / PRECISION)
		new_cap := node.input_cap * 2 + 2
		slot := arna.alloc(
			graph.mem,
			uint(new_cap * PRECISION),
			PRECISION,
			zeroed = true,
		)
		copy(mem.slice_data_cast([]Node_ID, slot), graph_inps(graph, node))
		node.input_cap = new_cap
		node.input_idx = base
	}

	raw_data(graph_inps(graph, node))[free_idx] = inp
	node.input_count += 1

	return free_idx
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
	assert(node.rtype != DEAD_NODE_KIND)
	graph_ensure_available_output_cap(graph, node, 1)

	node.output_count += 1
	assert(i < 256)
	graph_outs(graph, node)[node.output_count - 1] = {
		id  = out,
		idx = i,
	}
}

graph_extra :: proc {
	graph_get_static_extra_node,
	graph_get_static_extra_node_id,
}

graph_extra_dyn :: proc {
	graph_get_any_extra_node,
	graph_get_any_extra_node_id,
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
