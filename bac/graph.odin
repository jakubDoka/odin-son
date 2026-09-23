package bac

import "../vendored/gam/util/arna"
import "../vendored/gam/util/bit_arr"
import "base:intrinsics"
import "base:runtime"
import "core:container/queue"
import "core:fmt"
import "core:math"
import "core:mem"
import "core:mem/virtual"
import "core:simd"
import "core:slice"

Tag :: struct #align (4) {
	name:      Tag_Name,
	stable_id: Stable_Id,
}
Stable_Id :: [int(NODE_NAMES)]u32
Tag_Name :: [int(NODE_NAMES)]string

CALL_PREFIX :: 3
RET_PREFIX :: 2
DEAD_LOCAL: i32 : -1
PRECISION :: size_of(u32)
NODE_NAMES :: #config(NODE_NAMES, true)

Sym_Ref_Type :: enum u32 {
	Func = u32(Node_Type.Call),
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
	regalloc_rounds,
	regalloc_memory_overhead,
	regalloc_wasted_lrgs,
	peephole_rounds,
	splits_inserted,
	pressure_splits_inserted,
	fail_count_ratio,
	kill_splits_inserted,
	conflict_splits_inserted,
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

aggregate_effeciency_stats :: proc(dest: ^Stats, src: ^Stats) {
	for i in 0 ..< len(dest.efficiency) {
		i := Efficiency_Stat_Kind(i)
		dest.efficiency[i].total += src.efficiency[i].total
		dest.efficiency[i].ideal += src.efficiency[i].ideal
	}
	src^ = {}
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

Inherit_Table_Elem :: u16

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

D_Node_ID :: distinct u32

Sloc :: bit_field u64 {
	file:  u32 | 20,
	line:  u32 | 20,
	col:   u32 | 16,
	range: u32 | 8,
}

D_Node :: struct #align (4) {
	using sloc: Sloc,
	using _:    bit_field u32 {
		gdn:        u32  | 31,
		// if this is equal to graph.dbgn_flip it means the info is unvisited
		visit_mark: bool | 1,
	},
	binding:    [0]D_Binding,
}

D_Binding :: struct #align (4) {
	name: string,
	type: D_Type,
}

D_Type :: enum u64 {}

SPEC_NOT_PRESENT :: (#load("node_specs.odin", string) or_else "") == ""

when SPEC_NOT_PRESENT {
	Node_Type :: enum u16 {
		Start,
		Entry,
		Poison,
		Param,
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
		Root_Mem,
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
		If,
		Then,
		Else,
		Jump,
		Dead,
		Region,
		Loop,
		Always,
		Trap,
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
		U_F_From_I,
		F_Ext,
		F_Demote,
		Splat,
		Ctz,
		Simd_Extract_Lsbs,
		Simd_Reduce_Add_Bisect,
		CV128,
	}

	inherit_idx_of :: proc($T: typeid) -> u8 {return 0}

	add_return :: proc(
		graph: ^Proc,
		name: string,
		inputs: []Node_ID,
	) -> Node_ID {return 0}

	add_region :: proc(
		graph: ^Proc,
		name: string,
		ctrls: []Node_ID,
	) -> Node_ID {return 0}

	add_jump :: proc(
		graph: ^Proc,
		name: string,
		ctrl: Node_ID,
	) -> Node_ID {return 0}
	add_always :: add_jump
	add_then :: add_jump
	add_else :: add_jump
	add_poison :: proc(graph: ^Proc, name: string) -> Node_ID {return 0}
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

CV128 :: struct #align (4) {
	lo: u64,
	hi: u64,
}

Call :: struct {
	using _: Cfg,
	using _: bit_field u32 {
		ccid:      u32  | 26,
		ret_count: int  | 4,
		imported:  bool | 1,
		indirect:  bool | 1,
	},
	using _: struct #raw_union {
		cid:  u32,
		rets: [4]Node_Datatype,
	},
}

Tup :: struct {
	using fields: struct #raw_union {
		idx: u32,
	},
}

Local :: struct {
	using props: struct #raw_union {
		size:       i32,
		offset:     i32,
		rename_idx: i32,
	},
	using __:    bit_field u32 {
		idx:      u32  | 31,
		is_param: bool | 1,
	},
}

No_Extra :: struct {}

Lane_Type :: enum u8 {
	I8,
	I16,
	I32,
	I64,
	F32,
	F64,
}

lane_from_dt :: proc(ty: Node_Datatype) -> (Lane_Type, bool) {
	return Lane_Type(u8(ty) - (u8(Node_Datatype.I8) - u8(Lane_Type.I8))),
		.I8 <= ty && ty <= .F64
}

Node_Datatype :: enum u8 {
	Void,
	I8,
	I16,
	I32,
	I64,
	F32,
	F64,
	V128,
	V256,
	V512,
}

LANE_SIZE := [Lane_Type]int {
	.I8  = 1,
	.I16 = 2,
	.I32 = 4,
	.I64 = 8,
	.F32 = 4,
	.F64 = 8,
}

DT_SIZE := [Node_Datatype]int {
	.Void = 0,
	.I8   = 1,
	.I16  = 2,
	.I32  = 4,
	.I64  = 8,
	.F32  = 4,
	.F64  = 8,
	.V128 = 16,
	.V256 = 32,
	.V512 = 64,
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
	using tag:       Tag,
	using spec:      struct #align (4) {
		using type: struct #raw_union {
			itype: Node_Type,
			rtype: u16,
		},
		using meta: bit_field u16 {
			dt:                Node_Datatype | 4,
			is_store:          bool          | 1,
			is_load:           bool          | 1,
			mem_alignment_pow: u32           | 3,
			lane:              Lane_Type     | 3,
		},
	},
	using gvn_group: bit_field u32 {
		gvn:          u32  | 26,
		in_worklist:  bool | 1,
		scan_split:   bool | 1,
		extra_dwords: int  | 4,
	},
	input_idx:       u32,
	input_count:     u16,
	input_cap:       u16,
	output_idx:      u32,
	output_count:    u16,
	output_cap:      u16,
	extra:           [0]u32,
}

#assert(size_of(Node) - size_of(Tag) == 24)

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

Dbg_Ctx :: struct {}

Proc :: struct {
	using node_spec: ^Node_Spec,
	using stats:     ^Stats,
	worklist:        ^queue.Queue(Node_ID),
	triggers:        ^[dynamic][dynamic]Node_ID,
	mem:             ^arna.Allocator,
	current_dnode:   D_Node_ID,
	using meta:      Proc_Meta,
	dont_intern:     bool,
	dont_delete:     bool,
	peeped:          bool,
	opt_flags:       Opt_Flags,
}

Proc_Meta :: struct {
	interner:     Interner,
	weight:       int,
	waste:        int,
	gvn:          u32,
	gdn:          u32,
	stable_id:    u32,
	min_idepth:   u32,
	max_idepth:   u32,
	has_dbg:      bool,
	dbgn_flip:    bool,
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
	using meta: Proc_Meta,
}

Opt_Flags :: bit_set[Opt_Flag]

Opt_Flag :: enum int {
	Iter_Peeps,
	Local_Peeps,
	Mem_Opt,
	Loop_Opt,
	Inline,
}

Peep_Ctx :: struct {
	using graph: ^Proc,
}

invalidate_idepth :: proc(graph: ^Proc) {
	graph.min_idepth = graph.max_idepth
}

peep_ctx_graph_is_complete :: proc(ctx: Peep_Ctx) -> bool {
	return ctx.worklist != nil
}

peep_ctx_add_trigger :: proc(ctx: Peep_Ctx, triggerer: Node_ID, tar: Node_ID) {
	if triggerer == 0 do return
	if ctx.triggers == nil do return

	gvn := get_node(ctx, triggerer).gvn
	if len(ctx.triggers) <= int(gvn) {
		resize(ctx.triggers, gvn + 1)
	}
	if !slice.contains(ctx.triggers[gvn][:], tar) {
		cnt := append(&ctx.triggers[gvn], tar)
		assert(cnt == 1)
	}
}

worklist_add :: proc(
	graph: ^Proc,
	worklist: ^queue.Queue(Node_ID),
	id: Node_ID,
) {
	if id == 0 do return
	if worklist == nil do return

	node := get_node(graph, id)
	if node.rtype == DEAD_NODE_KIND do return
	if node.in_worklist {
		if !ODIN_DISABLE_ASSERT && false {
			for elem in worklist.data {
				if elem == id do return
			}
			fmt.panicf("wuta")
		} else {
			return
		}
	}
	node.in_worklist = true
	queue.push_back(worklist, id)
}

worklist_next :: proc(
	graph: ^Proc,
	worklist: ^queue.Queue(Node_ID),
) -> (
	n: Node_ID,
	ok: bool,
) {
	for {
		id := queue.pop_front_safe(worklist) or_return
		nd := get_node(graph, id)
		if nd.rtype == DEAD_NODE_KIND do continue
		nd.in_worklist = false
		return id, true
	}
}

pin :: proc(graph: ^Proc, id: Node_ID) {
	if id == 0 do return
	add_output(graph, id, 0, 0)
}

unpin :: proc(graph: ^Proc, id: Node_ID, no_delete := false) {
	if id == 0 do return
	remove_output(graph, id, {}, no_delete)
}

find_node :: proc(
	graph: ^Proc,
	kind: Node_Type,
	on: Node_ID = 0,
) -> (
	Node_ID,
	bool,
) {
	for eout in get_outputs(graph, on if on != 0 else graph.entry) {
		enode := expand_node(graph, eout.id)
		if enode.itype == kind {
			return eout.id, true
		}
	}
	return 0, false
}

get_sym_count :: proc(graph: ^Proc) -> int {
	return len(get_outputs(graph, graph.sym))
}

sym_iter_next :: proc(graph: ^Proc, iter: ^int) -> (res: Sym_Ref, ok: bool) {
	arr := get_outputs(graph, graph.sym)
	if iter^ <= 0 do return
	iter^ -= 1
	ok = true
	elem := get_node(graph, arr[iter^].id)
	#partial switch elem.itype {
	case .Call:
		res.id = get_extra(graph, elem, Call).cid
	case:
		fmt.panicf("TODO: %v", elem)
	}
	res.type = Sym_Ref_Type(elem.itype)
	res.node = get_node_id(graph, elem)
	return
}

assemble_args :: proc(
	ctx: ^Proc,
	param_count: int,
) -> (
	res: []Node_ID,
	starter: Node_ID,
) {
	prev := current_graph
	current_graph = ctx
	defer current_graph = prev

	params := make([]Node_ID, param_count)
	slice.fill(params, ctx.start)
	find_args: for eout in get_outputs(ctx, ctx.entry) {
		enode := expand_node(ctx, eout.id)

		if is_cfg(ctx, eout.id) do starter = eout.id

		if enode.itype != .Param && enode.itype != .Local do continue

		idx: u32
		if param := get_extra(ctx, eout.id, Tup); param != nil {
			idx = param.idx
		}

		if locp := get_extra(ctx, eout.id, Local); locp != nil {
			if !locp.is_param do continue
			idx = locp.idx
		}

		fmt.assertf(int(idx) < len(params), "%v %v", param_count, enode)
		params[idx] = eout.id
	}
	return params, starter
}

compute_weight :: proc(graph: ^Proc, all: []Node_ID) {
	if !graph.node_spec.intern do return

	@(static, rodata)
	WEIGHTS := #partial [Node_Type]u8 {
		.Loop = 5,
		.Call = 10,
		.CInt = 1,
		.Neg ..= .F_Demote      = 1,
		.Add ..= .And_Not      = 1,
	}

	graph.weight = 1

	for n in all {
		graph.weight += int(WEIGHTS[get_node(graph, n).itype])
	}
}

// mem is borrowed
get_stencil :: proc(graph: ^Proc) -> (s: Stencil) {
	s.mem = graph.mem.ptr[:graph.mem.pos]
	s.meta = graph.meta
	return
}

mount_stencil :: proc(graph: ^Proc, stencil: Stencil) {
	if graph.mem.ptr == nil {
		if false {
			arna.init(
				graph.mem,
				mem.align_forward_int(len(stencil.mem), mem.PAGE_SIZE),
			)
			arna.clone(graph.mem, stencil.mem)
			virtual.protect(graph.mem.ptr, graph.mem.reserved, {.Read})
		} else {
			graph.mem^ = arna.init_from_buffer(stencil.mem)
			graph.mem.pos = graph.mem.reserved
		}
	} else {
		graph.mem.pos = 0
		arna.clone(graph.mem, stencil.mem)
	}
	graph.meta = stencil.meta
	graph.current_dnode = 0
}

clone_dnode :: proc(
	graph: ^Proc,
	prev: ^Proc,
	dn: D_Node_ID,
	dnodes: []D_Node_ID,
) -> D_Node_ID {
	if dn == 0 do return 0

	mapped := dnodes[get_dnode(prev, dn).gdn]
	if mapped == 0 {
		mapped = D_Node_ID(graph.mem.pos / PRECISION)
		size := size_of(D_Node)
		bytes := arna.alloc(graph.mem, uint(size), PRECISION)
		mem.copy_non_overlapping(
			raw_data(bytes),
			get_dnode(prev, dn),
			len(bytes),
		)
		(^D_Node)(raw_data(bytes)).visit_mark = graph.dbgn_flip
		dnodes[get_dnode(prev, dn).gdn] = mapped
	}
	return mapped
}

compact :: proc(graph: ^Proc) {
	context.allocator, _ = arna.scrath()

	assert_live_pins(graph)

	worklist: queue.Queue(Node_ID)
	queue.init(&worklist, int(graph.gvn * 3 / 5 + 20))

	collect_nodes(graph, &worklist)
	compute_weight(graph, worklist.data[:worklist.len])

	dnodes := make([]D_Node_ID, graph.gdn)

	prev_mem := graph.mem^
	prev := graph^
	prev.mem = &prev_mem

	graph.mem.ptr = graph.mem.ptr[graph.mem.pos:]
	graph.mem.pos = PRECISION
	(^D_Node_ID)(graph.mem.ptr)^ = 0
	graph.gvn = 0

	interned_count := 0

	for &n in worklist.data[:worklist.len] {
		node := expand_node(&prev, n)

		dn := get_dbg_slot(&prev, node)^

		did := clone_dnode(graph, &prev, dn, dnodes)

		interned_count += int(has_flag(&prev, node, .Interned))
		node.input_cap = node.input_count
		node.output_cap = node.output_count

		new_node, id := shallow_clone(graph, node)
		init_counts(graph, new_node)

		new_node.input_idx = u32(graph.mem.pos / PRECISION)
		_ = arna.clone(graph.mem, node.inps)

		new_node.output_idx = u32(graph.mem.pos / PRECISION)
		_ = arna.clone(graph.mem, node.outs)

		get_dbg_slot(graph, new_node)^ = did

		n = id
	}

	graph.interner.len = 0
	graph.interner.cap = 0
	interner_grow(
		graph,
		mem.align_forward_int(interned_count, align_of(Intern_Vec)),
	)

	iview := interner_zip(graph)

	for n in worklist.data[:worklist.len] {
		node := expand_node(graph, n)
		node.in_worklist = false

		for &inp in node.inps {
			if inp == 0 do continue
			inp = project(&prev, worklist, inp)
		}

		for &out in node.outs {
			out = {
				id  = project(&prev, worklist, out.id),
				idx = out.idx,
			}
		}

		if has_flag(graph, node, .Interned) {
			hash := node_hash(graph, node)
			iview[graph.interner.len] = {hash, n}
			graph.interner.len += 1
		}

		on_node_creation(graph, node)
	}

	assert(graph.interner.len == interned_count)

	assert(graph.start != graph.root_mem)

	for &n in mem.slice_data_cast([]Node_ID, mem.ptr_to_bytes(&graph.pinned)) {
		if n == 0 do continue
		n = project(&prev, worklist, n)
	}

	project :: proc(
		prev: ^Proc,
		wl: queue.Queue(Node_ID),
		node: Node_ID,
	) -> Node_ID {
		return wl.data[:wl.len][get_node(prev, node).gvn]
	}

	mem.copy(prev.mem.ptr, graph.mem.ptr, int(graph.mem.pos))
	graph.mem.ptr = prev.mem.ptr
	graph.waste = 0

	fmt.assertf(
		graph.start != graph.root_mem,
		"%v %v %v",
		worklist.data[:worklist.len],
	)

	assert_live_pins(graph)
}

shallow_clone :: proc(graph: ^Proc, node: ^Node) -> (^Node, Node_ID) {
	size := compute_node_size(graph, node.rtype, node.extra_dwords)
	slot := arna.alloc(graph.mem, uint(size), PRECISION)
	mem.copy_non_overlapping(raw_data(slot), node, len(slot))
	return (^Node)(raw_data(slot)), get_node_id(graph, (^Node)(raw_data(slot)))
}

init_counts :: proc(graph: ^Proc, new_node: ^Node) {
	new_node.gvn = graph.gvn
	graph.gvn += 1
	if NODE_NAMES {
		graph.stable_id += 1
		new_node.stable_id = graph.stable_id
	}
}

apply_peep :: proc(graph: ^Proc, id: Node_ID) -> (r: Node_ID) {
	defer add_efficiency_stat(graph, .redundant_peep, 1, int(id != r))

	if .Local_Peeps not_in graph.opt_flags do return id
	if id == 0 do return id

	node := expand_node(graph, id)
	if len(node.outs) > 0 do return id

	prev_hash := node_hash(graph, node)
	mount_peep_node(graph, node)
	res := graph.peep({graph = graph}, node)
	if res == 0 do return id

	if res == id {
		unintern(graph, id, prev_hash)
		res = intern(graph, id)
		if res == id do return id
	}

	pin(graph, res)
	delete_node(graph, node)
	unpin(graph, res, no_delete = true)

	return res
}

@(disabled = ODIN_DISABLE_ASSERT)
verify :: proc(graph: ^Proc) {
	CHECK_INTERN_INTEGRITY :: true

	if !graph.dont_intern && CHECK_INTERN_INTEGRITY {
		for entry in interner_zip(graph) {
			if entry.hash == 0 {
				assert(entry.id == 0)
			} else {
				fmt.assertf(
					entry.hash == node_hash(graph, entry.id),
					"%v %v %v %v",
					get_node(graph, entry.id),
					int(entry.id),
					entry.hash,
					node_hash(graph, entry.id),
				)
			}
		}
	}

	seen_intern_slots := bit_arr.init(graph.interner.len)
	wl: queue.Queue(Node_ID)
	queue.init(&wl)
	collect_nodes(graph, &wl)
	for n in worklist_next(graph, &wl) {
		if len(get_outputs(graph, n)) == 0 && !has_flag(graph, n, .Immortal) {
			fmt.panicf("%v", get_node(graph, n))
		}
		if has_flag(graph, n, .Interned) &&
		   !graph.dont_intern &&
		   CHECK_INTERN_INTEGRITY {
			idx, _ :=
				interner_find(graph, n, 0) or_else fmt.panicf(
					"%v %v %v %#v",
					get_node(graph, n),
					int(n),
					node_hash(graph, n),
					interner_zip(graph),
				)
			fmt.assertf(
				bit_arr.set(seen_intern_slots, idx),
				"%v %v",
				get_node(graph, n),
				int(n),
			)
		}
	}

	if !graph.dont_intern && CHECK_INTERN_INTEGRITY {
		for it := bit_arr.iter(
			seen_intern_slots,
			inverted = true,
		); idx in bit_arr.iter_next(&it) {
			if idx < seen_intern_slots.bit_length {
				arr := interner_zip(graph)
				grub := get_node(graph, arr[idx].id)
				// TODO: this is insufficient, we need to adress this in the
				// dont_delete sections
				if grub.output_count + grub.input_count == 0 {
					bit_arr.set(seen_intern_slots, idx)
				} else {
					when !ODIN_DISABLE_ASSERT {
						fmt.eprintln(
							idx,
							u32(arr[idx].id),
							grub,
							graph.interner.len,
						)
					}
				}
			}
		}
		assert(bit_arr.pop_count(seen_intern_slots) == graph.interner.len)
	}
}

// NOTE: for debugging purposes to trace where a node was created
@(disabled = ODIN_DISABLE_ASSERT)
on_node_creation :: proc(graph: ^Proc, node: ^Node) {
	id := get_node_id(graph, node)
}

mount_peep_node :: proc(graph: ^Proc, node: ^Node) {
	graph.current_dnode = get_dbg_slot(graph, node)^
}

schedule_peeps :: proc(graph: ^Proc, schedule: ^Schedule) {
	for &bb in schedule.bbs {
		for &instr, i in bb.instrs[:len(bb.instrs) - 1] {
			node := expand_node(graph, instr)
			mount_peep_node(graph, node)
			new_node := graph.post_schedule_peep({graph, bb.instrs[:i]}, node)
			if new_node == 0 do continue
			if new_node == instr do continue
			subsume(graph, new_node, instr)
			instr = new_node
		}
	}

	for &bb in schedule.bbs {
		keep := 0
		for instr in bb.instrs {
			if get_node(graph, instr).rtype != DEAD_NODE_KIND {
				bb.instrs[keep] = instr
				keep += 1
			}
		}
		resize(&bb.instrs, keep)
	}

	for &bb in schedule.bbs {
		until := len(bb.instrs)
		for ; until > 0 && get_node(graph, bb.instrs[until - 1]).dt == .Void;
		    until -= 1 {
		}

		#reverse for instr, i in bb.instrs[:until] {
			inode := expand_node(graph, instr)
			if inode.output_count == 1 &&
			   get_node(graph, inode.outs[0].id).itype == .Phi &&
			   get_node(graph, inode.outs[0].id).dt != .Void &&
			   (0 == len(inode.inps) ||
					   (get_node(graph, inode.inps[0]).itype == .Phi &&
							   inode.inps[0] == inode.outs[0].id &&
							   get_node(graph, inode.inps[0]).output_count >
								   1)) {

				has_phy_inp := false
				for inp in inode.inps[min(1, len(inode.inps)):] {
					if get_node(graph, inp).itype == .Phi {
						has_phy_inp = true
						break
					}
				}
				if has_phy_inp do continue

				slice.rotate_left(bb.instrs[i:until - 1], 1)
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

has_unreachable_return :: proc(graph: ^Proc) -> bool {
	inp := get_inputs(graph, graph.end)[0]
	cfg := expand_node(graph, inp)

	if cfg.itype == .Trap do return true
	if cfg.itype != .Region do return false

	for inp in cfg.inps {
		if get_node(graph, inp).itype != .Trap {
			peep_ctx_add_trigger({graph}, inp, graph.end)
			return false
		}
	}

	return true
}

peep_subsume :: proc(graph: Peep_Ctx, with: Node_ID, target: Node_ID) {
	node := expand_node(graph, target)

	for out in node.outs {
		worklist_add(graph, graph.worklist, out.id)
	}

	if int(node.gvn) < len(graph.triggers) {
		for trig in graph.triggers[node.gvn] {
			worklist_add(graph, graph.worklist, trig)
		}
		graph.triggers[node.gvn] = {}
	}

	for inp in node.inps {
		worklist_add(graph, graph.worklist, inp)
	}

	subsume(graph, with, target)
}

apply_peeps :: proc(ctx: Peep_Ctx) -> (optimized: bool) {
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

	triggers: [dynamic][dynamic]Node_ID

	graph.worklist = &worklist
	graph.triggers = &triggers

	collect_nodes(graph, &worklist)

	rounds := 0
	triggered := 0
	for n in worklist_next(graph, &worklist) {
		rounds += 1

		node := expand_node(graph, n)

		mount_peep_node(graph, node)
		prev_hash := node_hash(graph, node)
		new_node := graph.peep(ctx, node)
		if node.rtype == DEAD_NODE_KIND do continue
		if new_node == 0 &&
		   (node.output_count != 0 || has_flag(graph, node, .Immortal)) {
			assert(prev_hash == node_hash(graph, node))
			continue
		}

		optimized = true

		for out in node.outs {
			worklist_add(graph, &worklist, out.id)
		}

		if int(node.gvn) < len(triggers) {
			for trig in triggers[node.gvn] {
				worklist_add(graph, &worklist, trig)
			}
			clear(&triggers[node.gvn])
		}

		if new_node == n {
			unintern(graph, n, prev_hash)
			new_node = intern(graph, n)
			if new_node == n do continue
		}

		node = expand_node(graph, n)

		for inp in node.inps {
			worklist_add(graph, &worklist, inp)
		}

		if new_node != 0 {
			subsume(graph, new_node, n)
		} else {
			delete_node(graph, n, indirect = true)
		}

		triggered += 1
	}

	add_efficiency_stat(graph, .redundant_peep, rounds, triggered)
	add_efficiency_stat(graph, .peephole_rounds, rounds, graph.gvn)

	if !ODIN_DISABLE_ASSERT {
		collect_nodes(graph, &worklist)

		for n in worklist_next(graph, &worklist) {
			node := expand_node(graph, n)
			for out in node.outs {
				onode := get_node(graph, out.id)
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
				get_extra(graph, node, Local).size != DEAD_LOCAL,
				"%v",
				node,
			)
			new_node := graph.peep(ctx, node)
			if new_node != 0 {
				fmt.assertf(
					new_node == 0,
					"\nnew: %v\nold: %v",
					get_node(graph, new_node),
					node.node,
				)
			}
		}
	}

	verify(graph)

	graph.worklist = nil
	graph.triggers = nil

	return
}

collect_nodes :: proc(graph: ^Proc, worklist: ^queue.Queue(Node_ID)) {
	gvn := 0
	gdn := 0
	assert(worklist.len == 0)
	worklist.offset = 0
	worklist_add(graph, worklist, graph.start)
	assert(worklist.len != 0)
	for gvn < int(worklist.len) {
		node := expand_node(graph, worklist.data[gvn])
		node.gvn = u32(gvn)

		dbg := get_dbg_slot(graph, node)^
		if dbg != 0 {
			dbgn := get_dnode(graph, dbg)
			if dbgn.visit_mark == graph.dbgn_flip {
				dbgn.gdn = u32(gdn)
				dbgn.visit_mark ~= true
				gdn += 1
			}
		}

		for inp in node.inps {
			if inp == 0 do continue
			worklist_add(graph, worklist, inp)
		}

		for out in node.outs {
			worklist_add(graph, worklist, out.id)
		}

		gvn += 1
	}
	graph.gvn = u32(gvn)
	graph.gdn = u32(gdn)
	graph.dbgn_flip ~= true

	when !ODIN_DISABLE_ASSERT {
		context.allocator, _ = arna.scrath()
		seen := bit_arr.init(graph.gvn)
		for n in worklist.data[:worklist.len] {
			node := get_node(graph, n)
			assert(bit_arr.set(seen, node.gvn))
		}
	}

	assert_live_pins(graph)

	return
}

@(disabled = ODIN_DISABLE_ASSERT)
assert_live_pins :: proc(graph: ^Proc) {
	prev := current_graph
	current_graph = graph
	defer current_graph = prev
	expected := [?]Node_Type{.Start, .Entry, .Root_Mem, .Sym, .Return}
	for &n, i in mem.slice_data_cast(
		[]Node_ID,
		mem.ptr_to_bytes(&graph.pinned),
	) {
		if expected[i] == .Return && n == 0 do continue
		fmt.assertf(
			get_node(graph, n).rtype != DEAD_NODE_KIND,
			"%v",
			expected[i],
		)
		fmt.assertf(
			get_node(graph, n).itype == expected[i],
			"%v %v",
			expected[i],
			get_node(graph, n),
		)
	}
}

is_noalias :: proc {
	is_noalias_ptrs,
	is_noalias_ops,
}

is_noalias_ops :: proc(graph: ^Proc, a, b: Node_ID) -> bool {
	a, b := a, b
	if get_node(graph, a).itype == .Copy do a, b = b, a

	sizes: [2]int
	nodes := [?]Node_ID{a, b}

	for &n, i in nodes {
		node := expand_node(graph, n)
		sizes[i] = mem_op_size(graph, n) or_return
		n = node.inps[2]
	}

	bn := expand_node(graph, b)

	if bn.itype == .Copy &&
	   !is_noalias(graph, nodes[0], bn.inps[3], sizes[0], sizes[1]) {
		return false
	}

	return is_noalias(graph, nodes[0], nodes[1], sizes[0], sizes[1])
}

mem_op_dt :: proc(
	graph: ^Proc,
	n: Node_ID,
) -> (
	dt: Node_Datatype,
	ok: bool = true,
) {
	node := expand_node(graph, n)
	#partial switch node.itype {
	case .Store:
		dt = get_node(graph, node.inps[3]).dt
	case .Load:
		dt = node.dt
	}
	return
}

mem_op_size :: proc(graph: ^Proc, n: Node_ID) -> (size: int, ok: bool = true) {
	node := expand_node(graph, n)
	#partial switch node.itype {
	case .Store:
		size = DT_SIZE[get_node(graph, node.inps[3]).dt]
	case .Load:
		size = DT_SIZE[node.dt]
	case .Set, .Copy:
		size_cnst := get_extra(graph, node.inps[4], CInt)
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

is_noalias_ptrs :: proc(graph: ^Proc, a, b: Node_ID, as, bs: int) -> bool {
	abase, aoffset := base_and_offset(graph, a)
	bbase, boffset := base_and_offset(graph, b)

	anode := get_node(graph, abase)
	bnode := get_node(graph, bbase)

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
	graph: ^Proc,
	node: Node_ID,
) -> (
	base: Node_ID,
	off: int,
) {
	return base_and_offset_proc(graph, node, root_addr_add_offset)
}

base_and_offset_proc :: proc(
	graph: ^Proc,
	node: Node_ID,
	$offn: proc(
		graph: ^Proc,
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
		bnode := expand_node(graph, base)
		if bnode.itype == .Add {
			lhs_const := get_extra(graph, bnode.inps[1], CInt)
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
	ctx: ^Proc,
	iter: ^Offset_Iter,
) -> (
	Node_Output,
	bool,
) {
	for {
		curr := expand_node(ctx, iter.curr)
		if iter.out_idx == len(curr.outs) {
			if curr.itype == .Add {
				parent := expand_node(ctx, curr.inps[0])
				off := get_extra(ctx, curr.inps[1], CInt)
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
		next_node := expand_node(ctx, next.id)
		recurse: if next_node.itype == .Add {
			off := get_extra(ctx, next_node.inps[1], CInt)
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

interner_zip :: proc(graph: ^Proc) -> (r: #soa[]SS_Entry(Node_ID)) {
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

simd_iter_next_rev :: proc(siter: ^Simd_Iter) -> (int, bool) {
	for {
		if siter.mask != 0 {
			leading := simd.count_leading_zeros(siter.mask)
			idx :=
				(len(siter.haystack) - siter.i + 1) * size_of(Intern_Vec) -
				int(leading) -
				1

			siter.mask &= max(u16) >> (leading + 1)

			return idx, true
		}

		if siter.i < len(siter.haystack) {
			mask := simd.lanes_eq(
				siter.haystack[len(siter.haystack) - siter.i - 1],
				Intern_Vec(siter.needle),
			)
			siter.mask = transmute(u16)simd.extract_lsbs(mask)
			siter.i += 1
		} else {
			return -1, false
		}
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

interner_find :: proc(
	graph: ^Proc,
	id: Node_ID,
	precomputed_hash: u8,
) -> (
	int,
	u8,
	bool,
) {
	iview := interner_zip(graph)
	assert(id != 0)

	needle := precomputed_hash
	if needle == 0 {
		needle = node_hash(graph, id)
	}
	assert(needle != 0)

	siter := simd_iter_from(iview.hash[:len(iview)], needle)
	for idx in simd_iter_next(&siter) {
		if node_eq(graph, iview.id[idx], id) {
			return idx, needle, true
		}
	}

	return -1, needle, false
}

@(require_results)
intern :: proc(graph: ^Proc, id: Node_ID) -> Node_ID {
	if !has_flag(graph, id, .Interned) || graph.dont_intern {
		return id
	}

	iview := interner_zip(graph)

	idx, hash, _ := interner_find(graph, id, 0)
	if idx >= 0 do return iview.id[idx]

	if len(iview) == graph.interner.len {
		new_cap := len(iview) * 2 + size_of(Intern_Vec)
		interner_grow(graph, new_cap)
		iview = interner_zip(graph)
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
	allocator: runtime.Allocator,
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

interner_grow :: proc(graph: ^Proc, new_cap: int) {
	iview := interner_zip(graph)
	grow_search_space(&iview, new_cap, arna.allocator(graph.mem))

	graph.interner.hash_idx =
		(uintptr(iview.hash) - uintptr(graph.mem.ptr)) / PRECISION
	graph.interner.node_idx =
		(uintptr(iview.id) - uintptr(graph.mem.ptr)) / PRECISION
	graph.interner.cap = new_cap
}

unintern :: proc(graph: ^Proc, id: Node_ID, precomputed_hash: u8 = 0) {
	if !has_flag(graph, id, .Interned) || graph.dont_intern do return

	idx, hash, _ := interner_find(graph, id, precomputed_hash)
	if idx < 0 do return

	iview := interner_zip(graph)

	if iview[idx].id != id do return

	graph.interner.len -= 1
	iview[idx] = iview[graph.interner.len]

	// NOTE: there is probably a bug in the odin compiler that requires us
	// to not set the value with a leteral
	tmp: SS_Entry(Node_ID)
	iview[graph.interner.len] = tmp
}

node_approx_size :: proc(graph: ^Proc, node: ^Node) -> uint {
	return(
		uint(compute_node_size(graph, node.rtype, node.extra_dwords)) +
		uint(node.input_cap * size_of(Node_ID)) \
	)
}

subsume :: proc(
	graph: ^Proc,
	with: Node_ID,
	target: Node_ID,
	dont_delete: bool = false,
) {
	//assert(with != graph.start)
	//assert(target != graph.entry)

	wnode := expand_node(graph, with)
	tnode := expand_node(graph, target)

	assert(with != target)

	ensure_available_output_cap(graph, wnode, tnode.output_count)

	when !ODIN_DISABLE_ASSERT {
		for out in tnode.outs {
			fmt.assertf(
				get_node(graph, out.id).itype != .Region ||
				is_cfg(graph, with) ||
				get_node(graph, with).itype == .Dead,
				"%v %v %v",
				wnode,
				tnode,
				get_node(graph, out.id),
			)

			fmt.assertf(
				!is_cfg(graph, with) ||
				get_node(graph, out.id).itype != .Phi ||
				out.idx == 0,
				"%v %v",
				wnode,
				tnode,
			)
		}
	}

	wnode.output_count += tnode.output_count
	tnode.output_count = 0

	wnode = expand_node(graph, with)

	copy(wnode.outs[len(wnode.outs) - len(tnode.outs):], tnode.outs)

	for out in tnode.outs {
		if out == {} do continue
		unintern(graph, out.id)
		get_inputs(graph, out.id)[out.idx] = with
	}

	pin(graph, with)

	if !dont_delete do delete_node(graph, tnode)

	wnode = expand_node(graph, with)

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

	#reverse for out in tnode.outs {
		if get_node(graph, out.id).rtype == DEAD_NODE_KIND do continue
		id := intern(graph, out.id)
		if id != out.id do subsume(graph, id, out.id)
	}

	unpin(graph, with)
}

node_eq :: proc(graph: ^Proc, a, b: Node_ID) -> bool {
	if a == b do return true

	an, bn := get_node(graph, a), get_node(graph, b)
	if an.spec != bn.spec do return false

	if !slice.equal(get_inputs(graph, an), get_inputs(graph, bn)) {
		return false
	}

	ad := get_extra_dwords(graph, an)
	bd := get_extra_dwords(graph, bn)
	if !slice.equal(ad, bd) do return false

	return true
}

set_input :: proc(
	graph: ^Proc,
	id: Node_ID,
	#any_int idx: int,
	value: Node_ID,
) -> Node_ID {
	node := expand_node(graph, id)

	assert(value != 0)

	assert(idx < len(node.inps))
	if node.inps[idx] == value do return id

	assert(node.inps[idx] != 0)

	add_output(graph, value, id, idx)
	remove_output(graph, node.inps[idx], {idx = idx, id = id})

	unintern(graph, id)
	node.inps[idx] = value
	nid := intern(graph, id)
	assert(nid == id)
	return nid
}

clone :: proc(graph: ^Proc, id: Node_ID) -> Node_ID {
	node := expand_node(graph, id)
	fmt.assertf(
		!has_flag(graph, node, .Interned) || graph.dont_intern,
		"%v",
		node,
	)
	assert(node.itype != .Call)
	idx := get_next_extra_slot(graph, node.rtype, node.extra_dwords)
	extra := get_extra_dwords(graph, node, consider_dbg = true)
	copy(idx[:len(extra)], extra)
	new := add_raw(graph, node.name, node.rtype, node.dt, node.inps)
	return new
}

@(tag = "node_proc")
remove_output_node :: proc(
	graph: ^Proc,
	node: ^Node,
	out: Node_Output,
	no_delete := false,
) {
	outs := get_outputs(graph, node)
	out_idx :=
		slice.linear_search(outs, out) or_else fmt.panicf("%v %v", node, out)
	outs[out_idx] = outs[len(outs) - 1]
	node.output_count -= 1

	if !no_delete {
		delete_node(graph, node, indirect = true)
	}
}

@(tag = "node_proc")
node_hash_node :: proc(graph: ^Proc, node: ^Node) -> u8 {
	if !has_flag(graph, node, .Interned) do return 0

	hash: u32

	spec := transmute(u32)(node.spec)
	extra_dwords := get_extra_dwords(graph, node)
	inps := get_inputs(graph, node)

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

get_node_id :: #force_inline proc(graph: ^Proc, node: ^Node) -> Node_ID {
	return Node_ID((uintptr(node) - uintptr(graph.mem.ptr)) / PRECISION)
}

@(tag = "node_proc")
delete_node_node :: proc(graph: ^Proc, node: ^Node, indirect := false) {
	id := get_node_id(graph, node)

	if node.output_count != 0 do return
	if has_flag(graph, node, .Immortal) && indirect do return
	if graph.dont_delete do return

	assert(node.itype != .Sym)

	if graph.triggers != nil && int(node.gvn) < len(graph.triggers) {
		for trig in graph.triggers[node.gvn] {
			worklist_add(graph, graph.worklist, trig)
		}
		clear(&graph.triggers[node.gvn])
	}

	for inp, i in get_inputs(graph, node) {
		if inp == 0 do continue
		if graph.worklist != nil && len(get_outputs(graph, inp)) > 1 {
			worklist_add(graph, graph.worklist, inp)
		}
		remove_output(graph, inp, {idx = i, id = id})
	}

	unintern(graph, id)

	size := node_approx_size(graph, node)

	if size == graph.mem.pos - uint(id * PRECISION) {
		add_efficiency_stat(graph, .immediate_deletes, 1)
	}

	//if get_tag(graph, id).stable_id == 174 && node.itype == .Then {
	//	panic("")
	//}

	graph.waste += int(node.input_cap * size_of(Node_ID))
	graph.waste += int(node.output_cap * size_of(Node_Output))
	graph.waste += compute_node_size(graph, node.rtype, node.extra_dwords)

	node^ = {
		rtype = DEAD_NODE_KIND,
	}

	add_efficiency_stat(graph, .deleted_nodes, 1)
}

@(tag = "node_proc")
get_extra_dwords_node :: proc(
	graph: ^Proc,
	node: ^Node,
	consider_dbg := false,
) -> []u32 {
	total :=
		graph.node_extra_sizes[node.rtype] +
		u8(node.extra_dwords) +
		u8(graph.has_dbg & consider_dbg)
	return raw_data(&node.extra)[:total]
}

get_dnode :: #force_inline proc(graph: ^Proc, id: D_Node_ID) -> ^D_Node {
	assert(id != 0)
	return (^D_Node)(&([^]u32)(graph.mem.ptr)[id])
}

get_node :: #force_inline proc(graph: ^Proc, id: Node_ID) -> ^Node {
	assert(id != 0)
	return (^Node)(&([^]u32)(graph.mem.ptr)[id])
}

Expanded_Node :: struct {
	using node: ^Node,
	inps:       []Node_ID,
	outs:       []Node_Output,
}

expand_node :: proc(graph: ^Proc, id: Node_ID) -> Expanded_Node {
	node := get_node(graph, id)

	assert(node.rtype != DEAD_NODE_KIND)
	return {node, get_inputs(graph, node), get_outputs(graph, node)}
}

@(tag = "node_proc")
get_inputs_node :: #force_inline proc(graph: ^Proc, node: ^Node) -> []Node_ID {

	return ([^]Node_ID)(graph.mem.ptr)[node.input_idx:][:node.input_count]
}

@(tag = "node_proc")
get_outputs_node :: #force_inline proc(
	graph: ^Proc,
	node: ^Node,
) -> []Node_Output {
	return(
		([^]Node_Output)(graph.mem.ptr)[node.output_idx:][:node.output_count] \
	)
}

compute_node_size :: proc(graph: ^Proc, type: u16, extra_dwords: int) -> int {
	total :=
		int(graph.node_extra_sizes[type]) + extra_dwords + int(graph.has_dbg)
	return size_of(Node) + total * PRECISION
}

get_next_extra_slot :: proc(
	graph: ^Proc,
	type: u16,
	extra_dwords: int,
) -> [^]u32 {
	size := compute_node_size(graph, type, extra_dwords)
	slot := arna.alloc(graph.mem, uint(size), PRECISION)
	graph.mem.pos -= uint(len(slot))

	return ([^]u32)(raw_data(slot)[size_of(Node):])
}

get_tag :: proc(graph: ^Proc, node: Node_ID) -> ^Tag {
	when NODE_NAMES {
		return &get_node(graph, node).tag
	} else {
		return nil
	}
}

get_dbg_slot :: proc(graph: ^Proc, node: ^Node) -> ^D_Node_ID {
	assert(int(node.rtype) < len(graph.node_extra_sizes))
	pos := graph.node_extra_sizes[node.rtype] + u8(node.extra_dwords)
	ptr := &([^]D_Node_ID)(&node.extra)[pos]
	nl := (^D_Node_ID)(graph.mem.ptr)
	if graph.has_dbg do return ptr
	return nl
}

add_debug_node :: proc(graph: ^Proc, sloc: Sloc) -> D_Node_ID {
	id := D_Node_ID(graph.mem.pos / PRECISION)

	size := size_of(D_Node)
	slot := arna.alloc(graph.mem, uint(size), PRECISION)

	dnode := (^D_Node)(raw_data(slot))
	dnode.sloc = sloc
	dnode.gdn = graph.gdn

	graph.gdn += 1

	return id
}

Add_Raw_Meta :: bit_field u64 {
	lane:           Lane_Type | 3,
	extra_capacity: int       | 2,
	extra_dwords:   int       | 3,
}

add_raw :: proc(
	graph: ^Proc,
	name: Tag_Name,
	type: u16,
	dt: Node_Datatype,
	inps: []Node_ID = {},
	meta: Add_Raw_Meta = {},
) -> (
	id: Node_ID,
) {
	id = Node_ID(graph.mem.pos / PRECISION)

	size := compute_node_size(graph, type, meta.extra_dwords)
	slot := arna.alloc(graph.mem, uint(size), PRECISION)

	node := (^Node)(raw_data(slot))
	node^ = {
		name         = name,
		stable_id    = graph.stable_id,
		rtype        = type,
		dt           = dt,
		gvn          = graph.gvn,
		lane         = meta.lane,
		extra_dwords = meta.extra_dwords,
		is_store     = .Store in graph.node_flags[type],
		is_load      = .Load in graph.node_flags[type],
		input_idx    = u32(graph.mem.pos / PRECISION),
		input_count  = u16(len(inps)),
		input_cap    = u16(len(inps) + meta.extra_capacity),
	}

	new_inps := arna.alloc(
		graph.mem,
		uint(int(len(inps) + meta.extra_capacity) * PRECISION),
		PRECISION,
	)
	copy(mem.slice_data_cast([]Node_ID, new_inps), inps)

	inode := intern(graph, id)
	if inode != id {
		graph.mem.pos = uint(id) * PRECISION
		return inode
	}

	for inp, i in inps {
		if inp == 0 do continue
		add_output(graph, inp, id, i)
	}

	graph.gvn += 1
	graph.stable_id += 1

	get_dbg_slot(graph, node)^ = graph.current_dnode

	on_node_creation(graph, node)

	return
}

@(deferred_out = pop_sloc)
get_sloc_scope :: proc(
	graph: ^Proc,
	sloc: D_Node_ID,
) -> (
	agraph: ^Proc,
	prev: D_Node_ID,
) {
	agraph = graph
	prev = push_sloc(graph, sloc)
	return
}

push_sloc :: proc(graph: ^Proc, dnd: D_Node_ID) -> (prev: D_Node_ID) {
	if !graph.has_dbg do return
	prev = graph.current_dnode
	graph.current_dnode = dnd
	return
}

pop_sloc :: proc(graph: ^Proc, prev: D_Node_ID) {
	graph.current_dnode = prev
}

merge_returns :: proc(graph: ^Proc, args: []Node_ID) -> Node_ID {
	if graph.end == 0 {
		args[0] = add_region(graph, "rret", {args[0], graph.start})
		for &a in args[1:] {
			a = add_raw(
				graph,
				"rphi",
				u16(Node_Type.Phi),
				get_node(graph, a).dt,
				{args[0], a},
			)
		}

		graph.end = add_return(graph, "ret", args)
	} else {
		end := expand_node(graph, graph.end)

		reg := expand_node(graph, end.inps[0])

		prev_cached := reg.inps[len(reg.inps) - 1]
		reg.input_count -= 1
		remove_output(
			graph,
			prev_cached,
			{idx = len(reg.inps) - 1, id = end.inps[0]},
			no_delete = true,
		)

		connect(graph, end.inps[0], args[0])

		for i in 1 ..< len(end.inps) {
			fmt.assertf(
				int(get_node(graph, end.inps[i]).input_count) == len(reg.inps),
				"%v %v",
				reg,
				get_node(graph, end.inps[i]),
			)
		}

		for i in 1 ..< len(end.inps) {
			new := i < len(args) ? args[i] : add_poison(graph, "rpsn")
			connect(graph, end.inps[i], new)
		}

		connect(graph, end.inps[0], prev_cached)
	}

	return graph.end
}

swap_inputs :: proc(graph: ^Proc, node: Expanded_Node, i, j: int) {
	id := get_node_id(graph, node)
	ind := expand_node(graph, node.inps[i])
	jnd := expand_node(graph, node.inps[j])

	for &out in ind.outs {
		if out.id == id && out.idx == i {
			out.idx = j
			break
		}
	}

	for &out in jnd.outs {
		if out.id == id && out.idx == j {
			out.idx = i
			break
		}
	}

	unintern(graph, id)
	node.inps[j], node.inps[i] = node.inps[i], node.inps[j]
	nid := intern(graph, id)
	assert(nid == id)
}

connect :: proc(graph: ^Proc, use: Node_ID, def: Node_ID) -> int {
	idx := add_input(graph, use, def)
	add_output(graph, def, use, idx)
	return idx
}

@(tag = "node_proc")
add_input_node :: proc(graph: ^Proc, node: ^Node, inp: Node_ID) -> int {
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
		copy(mem.slice_data_cast([]Node_ID, slot), get_inputs(graph, node))
		node.input_cap = new_cap
		node.input_idx = base
	}

	id := get_node_id(graph, node)

	unintern(graph, id)
	raw_data(get_inputs(graph, node))[free_idx] = inp
	node.input_count += 1
	nid := intern(graph, id)
	assert(nid == id)

	return free_idx
}

ensure_available_output_cap :: proc(
	graph: ^Proc,
	node: ^Node,
	available: u16,
) {
	if node.output_cap - node.output_count < available {
		graph.waste += int(node.output_cap * size_of(Node_ID))
		base := u32(graph.mem.pos / PRECISION)
		new_cap := max(node.output_cap * 2 + 2, node.output_cap + available)
		slot := arna.alloc(graph.mem, uint(new_cap * PRECISION), PRECISION)
		copy(
			mem.slice_data_cast([]Node_Output, slot),
			get_outputs(graph, node),
		)
		node.output_cap = new_cap
		node.output_idx = base
	}
}

@(tag = "node_proc")
add_output_node :: proc(
	graph: ^Proc,
	node: ^Node,
	out: Node_ID,
	#any_int i: int,
) {
	assert(node.rtype != DEAD_NODE_KIND)
	ensure_available_output_cap(graph, node, 1)

	if out != 0 {
		fmt.assertf(
			get_extra(graph, node, Cfg) == nil ||
			get_node(graph, out).itype != .Phi ||
			i == 0,
			"%v %v",
			node,
			out,
		)
	}

	node.output_count += 1
	assert(i < 256)
	get_outputs(graph, node)[node.output_count - 1] = {
		id  = out,
		idx = i,
	}
}

get_extra :: proc {
	get_static_extra_node,
	get_static_extra_node_id,
}

get_extra_dyn :: proc {
	get_any_extra_node,
	get_any_extra_node_id,
}

@(tag = "node_proc")
get_static_extra_node :: #force_inline proc(
	graph: ^Proc,
	node: ^Node,
	$T: typeid,
) -> ^T {
	fmt.assertf(
		int(node.rtype) < len(graph.inheritance_table),
		"node: %v %v",
		get_node_id(graph, node),
		get_outputs(graph, node),
	)
	if graph.inheritance_table[node.rtype] & (1 << inherit_idx_of(T)) ==
	   0 {return nil}
	return (^T)(&node.extra)
}

@(tag = "node_proc")
get_any_extra_node :: #force_inline proc(graph: ^Proc, node: ^Node) -> any {
	assert(int(node.rtype) < len(graph.node_extra_types))
	return {&node.extra, graph.node_extra_types[node.rtype]}
}

@(tag = "node_proc")
has_flag_node :: #force_inline proc(
	graph: ^Proc,
	node: ^Node,
	flag: Class_Flag,
) -> bool {
	fmt.assertf(int(node.rtype) < len(graph.node_flags), "%v", node.rtype)
	return flag in graph.node_flags[node.rtype]
}

root_addr_add_offset :: proc(
	graph: ^Proc,
	node: Expanded_Node,
) -> (
	base: Node_ID,
	off: int,
	ok: bool,
) {
	return
}
