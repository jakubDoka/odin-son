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
	TAG_SIZE :: size_of(string)
} else {
	TAG_SIZE :: 0
}

CALL_PREFIX :: 3
RET_PREFIX :: 2
DEAD_LOCAL: i32 : -1
PRECISION :: size_of(u32)
NODE_NAMES :: #config(NODE_NAMES, ODIN_DEBUG)

Sym_Ref_Type :: enum u32 {
	Func = u32(Ideal_Node_Type.Call),
}

Sym_Ref :: struct {
	type: Sym_Ref_Type,
	id:   u32,
	node: Node_ID,
}

Stats :: struct {
	efficiency: [Efficiency_Stat_Kind]Efficiency_Stat,
}

Efficiency_Stat_Kind :: enum int {
	graph_waste,
	late_schedule_rounds,
	ifg_rounds,
	peephole_rounds,
	splits_inserted,
	clones,
	inlines,
	duplicated_nodes,
	deleted_nodes,
	immediate_deletes,
	redundant_peep,
	sroad_locals,
	sroa_slot_mismatch,
}

Efficiency_Stat :: struct {
	total: int,
	ideal: int,
}

add_efficiency_stat :: proc(
	stats: ^Stats,
	kind: Efficiency_Stat_Kind,
	#any_int total: int,
	#any_int ideal: int = 0,
) {
	if stats == nil do return

	stats.efficiency[kind].total += total
	stats.efficiency[kind].ideal += ideal
}

Node_Spec :: struct {
	node_extra_sizes:  []u8,
	inheritance_table: []Inherit_Table_Elem,
	node_flags:        []Class_Flags,
	node_extra_types:  []typeid,
	node_kind_name:    []string,
	// only true for the pre-lowering/builder spec; every codegen-target
	// spec leaves this false so generic drivers stay spec-agnostic
	intern:            bool,
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
	Sym,
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
	using _:     bit_field u32 {
		idx:      u32  | 31,
		is_param: bool | 1,
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
	interner:     Interner,
	weight:       int,
	waste:        int,
	gvn:          u32,
	using pinned: struct {
		start:    Node_ID,
		entry:    Node_ID,
		root_mem: Node_ID,
		sym:      Node_ID,
		end:      Node_ID,
	},
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
	Inline,
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

graph_peep :: proc(graph: ^Graph, id: Node_ID) -> (r: Node_ID) {
	defer add_efficiency_stat(graph, .redundant_peep, 1, int(id != r))

	if .Local_Peeps not_in graph.opt_flags do return id
	if id == 0 do return id

	node := graph_expand(graph, id)
	if len(node.outs) > 0 do return id

	prev_hash := graph_node_hash(graph, node)
	res := graph.peep({graph = graph}, node)
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

graph_sym_count :: proc(graph: ^Graph) -> int {
	return len(graph_outs(graph, graph.sym))
}

graph_sym_iter_next :: proc(
	graph: ^Graph,
	iter: ^int,
) -> (
	res: Sym_Ref,
	ok: bool,
) {
	arr := graph_outs(graph, graph.sym)
	if iter^ <= 0 do return
	iter^ -= 1
	ok = true
	elem := graph_get(graph, arr[iter^].id)
	#partial switch elem.itype {
	case .Call:
		res.id = graph_extra(graph, elem, Call).cid
	case:
		fmt.panicf("TODO: %v", elem)
	}
	res.type = Sym_Ref_Type(elem.itype)
	res.node = graph_id(graph, elem)
	return
}

KEEP_CAPACITY :: bit_set[Ideal_Node_Type]{.Call}

graph_compute_weight :: proc(graph: ^Graph, all: []Node_ID) {
	if !graph.node_spec.intern do return

	@(static, rodata)
	WEIGHTS := #partial [Ideal_Node_Type]u8 {
		.Loop = 5,
		.Call = 10,
		.CInt = 1,
		.Neg ..= .F_Demote      = 1,
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

graph_mount_stencil :: proc(graph: ^Graph, stencil: Stencil) {
	if graph.mem.ptr == nil {
		graph.mem^ = arna.init_from_buffer(stencil.mem)
	} else {
		graph.mem.pos = 0
		arna.clone(graph.mem, stencil.mem)
	}
	graph.meta = stencil.meta
}

graph_compact :: proc(graph: ^Graph) {
	context.allocator, _ = arna.scrath()

	worklist: queue.Queue(Node_ID)
	queue.init(&worklist, int(graph.gvn * 3 / 5 + 20))

	collect_nodes(graph, &worklist)
	graph_compute_weight(graph, worklist.data[:worklist.len])

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
			out = {
				id  = project(&prev, worklist, out.id),
				idx = out.idx,
			}
		}

		if graph_has_flag(graph, node, .Interned) {
			hash := graph_node_hash(graph, node)
			iview[graph.interner.len] = {hash, n}
			graph.interner.len += 1
		}
	}

	assert(graph.interner.len == interned_count)

	for &n in mem.slice_data_cast([]Node_ID, mem.ptr_to_bytes(&graph.pinned)) {
		n = project(&prev, worklist, n)
	}

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

graph_iter_peeps :: proc(ctx: Peep_Ctx) -> (optimized: bool) {
	graph := ctx.graph

	is_builder := graph.node_spec.intern

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
	triggered := 0
	for n in worklist_next(graph, &worklist) {
		rounds += 1

		node := graph_expand(graph, n)

		prev_hash := graph_node_hash(graph, node)
		new_node := graph.peep(ctx, node)
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

		triggered += 1
	}

	add_efficiency_stat(graph, .redundant_peep, rounds, triggered)
	add_efficiency_stat(graph, .peephole_rounds, rounds, graph.gvn)

	if !ODIN_DISABLE_ASSERT {
		collect_nodes(graph, &worklist)

		for n in worklist_next(graph, &worklist) {
			node := graph_expand(graph, n)
			for out in node.outs {
				onode := graph_get(graph, out.id)
				if onode.itype != .Call {
					fmt.assertf(
						out.idx < int(onode.input_count),
						"%v %v",
						node.itype,
						onode.itype,
					)
				}
			}
			fmt.assertf(
				node.itype != .Local ||
				graph_extra(graph, node, Local).size != DEAD_LOCAL,
				"%v",
				node,
			)
			new_node := graph.peep(ctx, node)
			if new_node != 0 {
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

base_and_offset :: proc {
	base_and_offset_proc,
	base_and_offset_default,
}

base_and_offset_default :: proc(
	graph: ^Graph,
	node: Node_ID,
) -> (
	base: Node_ID,
	off: int,
) {
	return base_and_offset_proc(graph, node, root_addr_add_offset)
}

base_and_offset_proc :: proc(
	graph: ^Graph,
	node: Node_ID,
	$offn: proc(
		graph: ^Graph,
		node: Expanded_Node,
	) -> (
		base: Node_ID,
		off: int,
		ok: bool,
	),
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

		if hbase, hoff, ok := offn(graph, bnode); ok {
			base = hbase
			off += hoff
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

graph_interner_zip :: proc(graph: ^Graph) -> (r: #soa[]SS_Entry(Node_ID)) {
	r.hash = graph.mem.ptr[graph.interner.hash_idx * PRECISION:]
	r.id = ([^]Node_ID)(graph.mem.ptr)[graph.interner.node_idx:]
	runtime.raw_soa_footer(&r).len = graph.interner.cap
	return
}

Intern_Vec :: #simd[16]u8

Simd_Iter :: struct {
	haystack: []Intern_Vec,
	i:        int,
	mask:     u16,
	needle:   u8,
}

simd_iter_from :: #force_no_inline proc(
	haystack: []u8,
	needle: u8,
) -> Simd_Iter {
	assert(mem.is_aligned(raw_data(haystack), align_of(Intern_Vec)))
	assert(len(haystack) % size_of(Intern_Vec) == 0)
	return Simd_Iter {
		haystack = mem.slice_data_cast([]Intern_Vec, haystack),
		needle = needle,
	}
}

simd_iter_next :: proc(siter: ^Simd_Iter) -> (int, bool) {
	for {
		if siter.mask != 0 {
			idx :=
				(siter.i - 1) * size_of(Intern_Vec) +
				int(simd.count_trailing_zeros(siter.mask))
			siter.mask &= siter.mask - 1

			return idx, true
		}

		if siter.i < len(siter.haystack) {
			mask := simd.lanes_eq(
				siter.haystack[siter.i],
				Intern_Vec(siter.needle),
			)
			siter.mask = transmute(u16)simd.extract_lsbs(mask)
			siter.i += 1
		} else {
			return -1, false
		}
	}
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
	assert(id != 0)

	needle := precomputed_hash
	if needle == 0 {
		needle = graph_node_hash(graph, id)
	}
	assert(needle != 0)

	siter := simd_iter_from(iview.hash[:len(iview)], needle)
	for idx in simd_iter_next(&siter) {
		if graph_node_eq(graph, iview.id[idx], id) {
			return idx, needle, true
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

SS_Entry :: struct($V: typeid) {
	hash: u8,
	id:   V,
}

grow_search_space :: proc(
	ss: ^#soa[]SS_Entry($V),
	new_cap: int,
	allocator := context.temp_allocator,
) {
	context.allocator = allocator
	assert(mem.is_aligned(rawptr(uintptr(new_cap)), align_of(Intern_Vec)))

	hashes, _ := mem.alloc_bytes(new_cap, align_of(Intern_Vec))
	nodes, _ := mem.alloc_bytes(new_cap * size_of(V), align_of(V))

	mem.copy_non_overlapping(raw_data(hashes), ss.hash, len(ss))
	mem.zero_slice(hashes[len(ss):new_cap])
	mem.copy_non_overlapping(raw_data(nodes), ss.id, len(ss) * size_of(V))

	ss.hash = raw_data(hashes)
	ss.id = ([^]V)(raw_data(nodes))
	runtime.raw_soa_footer(ss).len = new_cap
}

graph_interner_grow :: proc(graph: ^Graph, new_cap: int) {
	iview := graph_interner_zip(graph)
	grow_search_space(&iview, new_cap, arna.allocator(graph.mem))

	graph.interner.hash_idx =
		(uintptr(iview.hash) - uintptr(graph.mem.ptr)) / PRECISION
	graph.interner.node_idx =
		(uintptr(iview.id) - uintptr(graph.mem.ptr)) / PRECISION
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
	tmp: SS_Entry(Node_ID)
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
	res = max(res, 1)
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

	if node.itype in KEEP_CAPACITY {
		node.input_count = node.input_cap
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

	if size == graph.mem.pos - uint(id * PRECISION) {
		add_efficiency_stat(graph, .immediate_deletes, 1)
	}

	graph.waste += int(node.input_cap * size_of(Node_ID))
	graph.waste += int(node.output_count * size_of(Node_Output))
	graph.waste += size_of(Node)
	graph.waste += int(graph.node_extra_sizes[node.rtype] * PRECISION)

	node^ = {
		rtype = DEAD_NODE_KIND,
	}

	add_efficiency_stat(graph, .deleted_nodes, 1)
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

graph_expand :: proc(graph: ^Graph, id: Node_ID) -> Expanded_Node {
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
		graph.mem.ptr[int(node) * PRECISION - TAG_SIZE:][:TAG_SIZE],
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

graph_add_field_offset :: proc(
	graph: ^Graph,
	base: Node_ID,
	offset: int,
) -> Node_ID {
	if offset == 0 do return base
	off := graph_add_c_int(graph, "foff", .I64, i64(offset))
	return graph_add_bin_op(graph, "fld", .Add, .I64, base, off)
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
	return graph_add_store(
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
	unit: Node_Datatype = .I64,
) -> (
	omem: Node_ID,
) {
	omem = mem

	store_unit := unit
	size := min(size - extra_offset, DT_SIZE[unit])
	offset: int

	if store_unit in FLOAT_DTS {
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
		for DT_SIZE[store_unit] + offset > size {
			store_unit = Node_Datatype(u8(store_unit) - 1)
			assert(store_unit != .Void)
		}

		value := graph_add_un_op(
			ctx,
			"rvl",
			.Cast,
			store_unit,
			graph_add_bin_op(
				ctx,
				"stsh",
				.U_Shr,
				.I64,
				value,
				graph_add_c_int(ctx, "stshoff", .I64, i64(offset * 8)),
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

		offset += DT_SIZE[store_unit]
	}

	return
}

graph_add_field_load :: proc(
	ctx: ^Graph,
	name: string,
	dt: Node_Datatype,
	cfg: Node_ID,
	mem: Node_ID,
	base: Node_ID,
	offset: int = 0,
) -> Node_ID {
	return graph_add_load(
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
	unit: Node_Datatype = .I64,
) -> Node_ID {
	load_unit := unit
	size := min(size - extra_offset, DT_SIZE[unit])
	offset: int
	value: Node_ID

	if load_unit in FLOAT_DTS {
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
		for DT_SIZE[load_unit] + offset > size {
			assert(load_unit not_in FLOAT_DTS)
			load_unit = Node_Datatype(u8(load_unit) - 1)
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
			value = graph_add_bin_op(
				ctx,
				"aor",
				.Or,
				.I64,
				value,
				graph_add_bin_op(
					ctx,
					"ash",
					.Shl,
					.I64,
					load,
					graph_add_c_int(ctx, "ssham", .I64, i64(offset * 8)),
				),
			)
		}

		offset += DT_SIZE[load_unit]
	}

	return value
}

Param_Gen :: struct {
	vls:         [dynamic]Node_ID,
	spill_start: int,
}

Abi_Param :: struct {
	dt:        [dynamic; 2]Node_Datatype,
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
		value = graph_add_arg(ctx, name, dt, ctx.entry, u32(apa.spilled))
		append(&gen.vls, value)
	} else {
		nd := apa.copied ? ctx.root_mem : ctx.entry
		alloca := graph_add_local(ctx, name, nd)
		graph_extra(ctx, alloca, Local).size = i32(apa.real_size)
		graph_extra(ctx, alloca, Local).is_param = !apa.copied
		value = graph_add_local_addr(ctx, name, alloca)

		if !apa.copied {
			append(&gen.vls, alloca)
		}
	}

	for dt, j in apa.dt[:(apa.size + 7) / 8] {
		vl := graph_add_arg(ctx, name, dt, ctx.entry, 0)
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

arg_gen_finalize :: proc(ctx: ^Graph, gen: ^Param_Gen) -> []Param_Spec {
	arg_tys := make([]Param_Spec, len(gen.vls))

	j, ri: u32
	for arg in gen.vls {
		anode := graph_get(ctx, arg)
		if arga := graph_extra(ctx, arg, Tup); arga != nil {
			size: i32
			if arga.idx == 0 {
				arga.idx = j
				j += 1
			} else {
				arga.idx = u32(gen.spill_start) + ri
				size = 8
				ri += 1
			}
			arg_tys[arga.idx] = Param_Spec{anode.dt, size}
		}

		if loca := graph_extra(ctx, arg, Local); loca != nil {
			loca.size = i32(mem.align_forward_int(int(loca.size), 8))
			loca.idx = u32(gen.spill_start) + ri
			arg_tys[loca.idx] = Param_Spec{.Void, loca.size}
			loca.is_param = true
			ri += 1
		}
	}
	fmt.assertf(int(j) == gen.spill_start, "%v %v", j, gen.spill_start)
	return arg_tys
}
