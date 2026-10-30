package bac

import "../utils/arna"
import "../utils/bit_arr"
import "../utils/fmt"
import "base:intrinsics"
import "base:runtime"
import "core:container/queue"
import "core:math"
import "core:mem"
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

@(tag = "api")
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
	node_kind:         typeid,
	using regalloc:    Regalloc_Spec,
	using codegen:     Codegen_Spec,
}

DEAD_NODE_KIND :: ~u16(0)

Sloc :: bit_field [2]u32 {
	file:  u32 | 20,
	line:  u32 | 20,
	col:   u32 | 16,
	range: u32 | 8,
}

SPEC_NOT_PRESENT :: (#load("node_specs.odin", string) or_else "") == ""

when SPEC_NOT_PRESENT {
	Node_Type :: enum u16 {
		// unreachable
		Nil,
		Entry,
		Then,
		Else,
		Region,
		Loop,
		Call_End,
		End,
		// Dbg
		Dbg_Sym_Decl,
		Dbg_Sym_Update,
		Dbg_Scope,
		// block tails
		If,
		Jump,
		Trap,
		Call,
		Always,
		Return,
		// virtual
		Poison,
		Mem,
		Split_Mem,
		Merge_Mem,
		Sym,
		Local,
		Global,
		// abi
		Param,
		Ret,
		// Phi
		Phi,
		// CInt
		CInt,
		// binary ops
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
		Shl,
		Shr,
		U_Shr,
		Mul,
		Div,
		U_Div,
		Rem,
		U_Rem,
		And_Not,
		// Split
		Split,
		// memory ops
		Local_Addr,
		Global_Addr,
		Proc_Addr,
		Copy,
		Set,
		Store,
		Load,
		// unary Ops
		Neg,
		Not,
		Cast,
		Conv,
		U_Conv,
		Splat,
		Ctz,
		Simd_Extract_Lsbs,
		Simd_Extract_Msbs,
		Simd_Reduce_Add_Bisect,
		Select,
		Thread_Id,
		Lane_Id,
		Uniform_Addr,
	}

	inherit_idx_of :: proc($T: typeid) -> u8 {return 0}

	add_return :: proc(
		prc: ^Proc,
		name: string,
		inputs: []Node_ID,
	) -> Node_ID {return 0}
	add_merge_mem :: add_return

	add_region :: proc(
		prc: ^Proc,
		name: string,
		ctrls: []Node_ID,
	) -> Node_ID {return 0}
	add_always :: add_region

	add_jump :: proc(
		prc: ^Proc,
		name: string,
		ctrl: Node_ID,
	) -> Node_ID {return 0}
	add_then :: add_jump
	add_else :: add_jump
	add_mem :: add_jump
	add_split_mem :: add_jump
	add_poison :: proc(prc: ^Proc, name: string) -> Node_ID {return 0}
	add_select :: proc(
		prc: ^Proc,
		name: string,
		dt: Node_Datatype,
		on_true, on_false, condition: Node_ID,
	) -> Node_ID {return 0}
}

Dbg_Sym :: struct {
	name: string,
	type: u64,
}

Class_Flags :: bit_set[Class_Flag;u8]

Class_Flag :: enum {
	Is_Basic_Block_Start,
	Interned,
	Comutes,
	Store,
	Load,
	Clonable,
}

Cfg :: struct {
	idepth: u32,
}

CInt :: struct #raw_union #align (4) {
	value:  i64,
	fvalue: f64,
}

Call :: struct {
	using _:     Cfg,
	using flags: bit_field u32 {
		ccid:      u32  | 26,
		ret_count: int  | 4,
		imported:  bool | 1,
	},
	cid:         u32,
	rets:        [4]Node_Datatype,
}

is_indirect_call :: proc(node: Expanded_Node) -> bool {
	return node.itype == .Call && node.inps[2] == 0
}

Tup :: struct {
	idx: u32,
}

Local :: struct {
	using props: struct #raw_union {
		size:   i32,
		offset: i32,
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

@(tag = "api")
lane_from_dt :: proc(ty: Node_Datatype) -> (Lane_Type, bool) {
	return Lane_Type(u8(ty) - (u8(Node_Datatype.I8) - u8(Lane_Type.I8))),
		.I8 <= ty && ty <= .F64
}

Node_Datatype :: enum u8 {
	Void,
	Mem,
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

@(rodata)
LANE_SIZE := [Lane_Type]int {
	.I8  = 1,
	.I16 = 2,
	.I32 = 4,
	.I64 = 8,
	.F32 = 4,
	.F64 = 8,
}

@(rodata)
LANE_TO_DT := [Lane_Type]Node_Datatype {
	.I8  = .I8,
	.I16 = .I16,
	.I32 = .I32,
	.I64 = .I64,
	.F32 = .F32,
	.F64 = .F64,
}

@(rodata)
DT_SIZE := [Node_Datatype]int {
	.Void = 0,
	.Mem  = 0,
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
INT_DTS :: bit_set[Node_Datatype]{.I8, .I16, .I32, .I64}
VECTOR_DTS :: bit_set[Node_Datatype]{.V128, .V256, .V512}

operation_datatype :: proc(prc: ^Proc, node: Expanded_Node) -> Node_Datatype {
	dt := node.dt
	#partial switch node.itype {
	case .Eq ..= .U_Ge:
		dt = get_node(prc, node.inps[0]).dt
	}
	if dt in VECTOR_DTS do return LANE_TO_DT[node.lane]
	return dt
}

int_for_size :: proc(size: int) -> Node_Datatype {
	assert(math.is_power_of_two(size))
	assert(size <= 8)
	return Node_Datatype(
		u8(Node_Datatype.I8) + u8(intrinsics.count_trailing_zeros(size)),
	)
}

Node_ID :: distinct u32

when #config(COMPACT_NODE_OUTPUTS, true) {
	Node_Output :: bit_field u32 {
		id:  Node_ID | 22,
		idx: int     | 10,
	}
} else {
	Node_Output :: struct {
		id:      Node_ID,
		using _: bit_field u32 {
			idx: int | 32,
		},
	}
}

Node :: struct {
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
		extra_dwords: int  | 4,
		must_spill:   bool | 1,
	},
	input_idx:       u32,
	input_count:     u16,
	input_cap:       u16,
	output_idx:      u32,
	output_count:    u16,
	output_cap:      u16,
	using tag:       Tag,
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

Worklist :: struct {
	using queue: queue.Queue(Node_ID),
	in_queue:    bit_arr.Bit_Set,
}

Proc :: struct {
	using node_spec: ^Node_Spec,
	using preserved: struct {
		using stats: ^Stats,
	},
	worklist:        ^Worklist,
	triggers:        ^[dynamic][dynamic]Node_ID,
	mem:             ^arna.Allocator,
	temps:           ^arna.Temps,
	curret_sloc:     Sloc,
	nil_sloc_slot:   Sloc,
	using meta:      Proc_Meta,
	dont_intern:     bool,
	dont_delete:     bool,
	computed_passes: bit_set[Pass],
	lattices:        []Lattice,
}

Proc_Meta :: struct {
	last_pass_spec: ^Node_Spec,
	interner:       Interner,
	weight:         int,
	waste:          int,
	gvn:            u32,
	gdn:            u32,
	stable_id:      u32,
	min_idepth:     u32,
	max_idepth:     u32,
	using config:   struct {
		has_dbg:   bool,
		opt_flags: Opt_Flags,
	},
	using pinned:   struct {
		entry: Node_ID,
		end:   Node_ID,
	},
	using cached:   struct {
		cmem: Node_ID,
	},
}

Stencil :: struct {
	mem:        []u8,
	using meta: Proc_Meta,
}

Pass :: enum int {
	Peep,
	Sccp,
	Mem,
	Loop,
}

Opt_Flags :: bit_set[Opt_Flag]

Opt_Flag :: enum int {
	Sccp,
	Local_Peeps,
	Mem_Opt,
	Loop_Opt,
	Inline,
}

Peep_Ctx :: struct {
	using prc:       ^Proc,
	using opt_hints: Opt_Hints,
}

ensure_spec_pass_match :: #force_inline proc(ctx: ^Proc) {
	if ctx.node_spec != ctx.last_pass_spec {
		ctx.computed_passes = {}
		ctx.last_pass_spec = ctx.node_spec
	}
}

@(deferred_in_out = pass_quard_end)
pass_quard :: #force_inline proc(
	ctx: ^Proc,
	pass: Pass,
	opted: ^bool,
) -> (
	Pass_Snapshot,
	bool,
) {
	ensure_spec_pass_match(ctx)
	if pass in ctx.computed_passes do return {}, false
	ctx.computed_passes |= {pass}
	return pass_snapshot(ctx), true
}

@(tag = "api")
set_local_size :: proc(prc: ^Proc, loc: Node_ID, size: i32) {
	get_extra(prc, loc, Local).size = size
}

pass_quard_end :: #force_inline proc(
	ctx: ^Proc,
	pass: Pass,
	opted: ^bool,
	snap: Pass_Snapshot,
	ok: bool,
) {
	if ok do opted^ |= snap != pass_snapshot(ctx)
	defer if opted^ do ctx.computed_passes = {pass}
}

invalidate_idepth :: proc(prc: ^Proc) {
	prc.min_idepth = prc.max_idepth
}

peep_ctx_graph_is_complete :: proc(ctx: ^Proc) -> bool {
	return ctx.worklist != nil
}

peep_ctx_flush_triggers :: proc(ctx: ^Proc, node: ^Node) {
	if ctx.triggers == nil do return
	assert(ctx.worklist != nil)

	if int(node.gvn) < len(ctx.triggers) {
		for trig in ctx.triggers[node.gvn] {
			worklist_add(ctx, ctx.worklist, trig)
		}
		clear(&ctx.triggers[node.gvn])
	}
}

peep_ctx_add_trigger :: proc(ctx: ^Proc, triggerer: Node_ID, tar: Node_ID) {
	if triggerer == 0 do return
	if ctx.triggers == nil do return

	gvn := get_node(ctx, triggerer).gvn
	if len(ctx.triggers) <= int(gvn) {
		// Exact growth retains quadratic amounts of storage in the scratch arena.
		resize(ctx.triggers, max(int(gvn) + 1, len(ctx.triggers) * 2))
	}
	if !slice.contains(ctx.triggers[gvn][:], tar) {
		cnt := append(&ctx.triggers[gvn], tar)
		assert(cnt == 1)
	}
}

worklist_add :: proc(prc: ^Proc, worklist: ^Worklist, id: Node_ID) {
	if worklist == nil do return

	node := get_node(prc, id)
	if node.rtype == DEAD_NODE_KIND do return

	if worklist.in_queue.bit_length <= int(node.gvn) {
		context.allocator = worklist.data.allocator
		bit_arr.resize(&worklist.in_queue, (node.gvn + 1) * 2)
	}

	if !bit_arr.set(worklist.in_queue, node.gvn) {
		if !ODIN_DISABLE_ASSERT && false {
			for elem in worklist.data {
				if elem == id do return
			}
			fmt.panicf("no")
		} else {
			return
		}
	}
	queue.push_back(&worklist.queue, id)
}

worklist_next :: proc(
	prc: ^Proc,
	worklist: ^Worklist,
) -> (
	n: Node_ID,
	ok: bool,
) {
	for {
		id := queue.pop_front_safe(&worklist.queue) or_return
		nd := get_node(prc, id)
		if nd.rtype == DEAD_NODE_KIND do continue
		bit_arr.set(worklist.in_queue, nd.gvn, value = false)
		return id, true
	}
}

@(tag = "api")
pin :: proc(prc: ^Proc, id: Node_ID) {
	add_output(prc, id, 0, 0)
}

@(tag = "api")
unpin :: proc(prc: ^Proc, id: Node_ID, no_delete := false) {
	remove_output(prc, id, {}, no_delete)
}

@(tag = "api")
find_node :: proc(
	prc: ^Proc,
	kind: Node_Type,
	on: Node_ID = 0,
) -> (
	Node_ID,
	bool,
) #optional_ok {
	for eout in get_outputs(prc, on != 0 ? on : prc.entry) {
		enode := expand_node(prc, eout.id)
		if enode.itype == kind {
			return eout.id, true
		}
	}
	return 0, false
}

@(tag = "api")
find_or_create_node :: proc(prc: ^Proc, kind: Node_Type) -> (sym: Node_ID) {
	sym = find_node(prc, kind)
	if sym == 0 {
		sym = add_raw(prc, "goc", u16(kind), .Void, {prc.entry})
		outs := get_outputs(prc, prc.entry)
		// NOTE: to bring it closer so the search for this is fast
		// (mem is as 0)
		outs[1], outs[len(outs) - 1] = outs[len(outs) - 1], outs[1]
	}
	return
}

@(tag = "api")
get_sym_count :: proc(prc: ^Proc) -> (sym: Node_ID, count: int) {
	sym = find_node(prc, .Sym)
	count = len(get_outputs(prc, sym))
	return
}

@(tag = "api")
sym_iter_next :: proc(
	prc: ^Proc,
	sym: Node_ID,
	iter: ^int,
) -> (
	res: Sym_Ref,
	ok: bool,
) {
	arr := get_outputs(prc, sym)
	if iter^ <= 0 do return
	iter^ -= 1
	ok = true
	elem := get_node(prc, arr[iter^].id)
	#partial switch elem.itype {
	case .Call:
		res.id = get_extra(prc, elem, Call).cid
	case:
		fmt.panicf("TODO: %v", elem)
	}
	res.type = Sym_Ref_Type(elem.itype)
	res.node = get_node_id(prc, elem)
	return
}

assemble_args :: proc(
	ctx: ^Proc,
	param_count: int,
) -> (
	res: []Node_ID,
	starter: Node_ID,
) {
	when !fmt.NO_FMT {
		prev := current_prc
		current_prc = ctx
		defer current_prc = prev
	}

	params := make([]Node_ID, param_count)
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

compute_weight :: proc(prc: ^Proc, all: []Node_ID) {
	@(static, rodata)
	WEIGHTS := #partial [Node_Type]u8 {
		.Loop   = 5,
		.Call   = 10,
		.CInt   = 1,
		.Select = 1,
		.Neg ..= .U_Conv        = 1,
		.Add ..= .And_Not        = 1,
	}

	prc.weight = 1

	for n in all {
		ty := get_node(prc, n).itype
		if ty <= max(Node_Type) {
			prc.weight += int(WEIGHTS[ty])
		} else {
			prc.weight += 1
		}
	}
}

/// Extract the stencil from the function. The resulting stencil does not own
/// the .mem, you need to clone it if you want to save the stencil for later.
/// Stencil represents a compressed state of a graph, you can recover the
/// function with mount_stencil. You usually want to store the stencils when
/// collecting functions for inlining.
///
/// Note that stencil can be stored on disk and loaded just fine, it does not
/// contain any global pointers that break the integrity.
@(tag = "api,priority=95")
get_stencil :: proc(prc: ^Proc) -> (s: Stencil) {
	s.mem = prc.mem.ptr[:prc.mem.pos]
	s.meta = prc.meta
	return
}

/// Reverse of get_stencil, if the proc has empty arena, the proc will borrow the
/// .mem field and the prc should not be modifyed, but its safe to use it for
/// inlining or other ops that just read the graph.
@(tag = "api,priority=95")
mount_stencil :: proc(prc: ^Proc, stencil: Stencil) {
	if prc.mem.ptr == nil {
		prc.mem^ = arna.init_from_buffer(stencil.mem)
		prc.mem.pos = prc.mem.reserved
	} else {
		prc.mem.pos = 0
		arna.clone(prc.mem, stencil.mem)
	}
	prc.meta = stencil.meta
	prc.curret_sloc = {}
	prc.computed_passes = {}
}

worklist_init :: proc(w: ^Worklist, #any_int cap: int = 0) {
	queue.init(&w.queue, cap)
	w.in_queue = bit_arr.init(cap)
}

/// The graph can accumulate wasted space of dead nodes during optimizations.
/// Function will garbige collect the nodes into the smallest possible
/// allocation. This is particularly usefull before `get_stencil`, as it
/// reduces the memory usage of cold functions.
@(tag = "api,priority=95")
compact :: proc(prc: ^Proc) {
	context.allocator, _ = arna.scrath(prc.temps)

	assert_live_pins(prc)

	worklist: Worklist
	worklist_init(&worklist, int(prc.gvn * 3 / 5 + 20))

	collect_nodes(prc, &worklist)
	compute_weight(prc, worklist.data[:worklist.len])

	prev_mem := prc.mem^
	prev := prc^
	prev.mem = &prev_mem

	prc.mem.ptr = prc.mem.ptr[prc.mem.pos:]
	prc.mem.pos = PRECISION
	prc.gvn = 1
	prc.gdn = 1
	prc.cached = {}
	prc.computed_passes &~= {.Sccp}
	prc.lattices = {}

	interned_count := 0

	for &n in worklist.data[1:worklist.len] {
		node := expand_node(&prev, n)

		interned_count += int(has_flag(&prev, node, .Interned))
		node.input_cap = node.input_count
		node.output_cap = node.output_count

		new_node, id := shallow_clone(prc, node)
		new_node.gvn = prc.gvn
		prc.gvn += 1

		assert(node.gvn == new_node.gvn)

		new_node.input_idx = u32(prc.mem.pos / PRECISION)
		_ = arna.clone(prc.mem, node.inps)

		new_node.output_idx = u32(prc.mem.pos / PRECISION)
		_ = arna.clone(prc.mem, node.outs)

		n = id
	}

	prc.interner.len = 0
	prc.interner.cap = 0
	interner_grow(
		prc,
		mem.align_forward_int(interned_count, align_of(Intern_Vec)),
	)

	iview := interner_zip(prc)

	for n in worklist.data[1:worklist.len] {
		node := expand_node(prc, n)

		for &inp in node.inps {
			pnode := expand_node(&prev, inp)
			inp = project(&prev, worklist, inp)
			cnode := expand_node(prc, inp)
			fmt.assertf(pnode.itype == cnode.itype, "%v", cnode)
		}

		for &out in node.outs {
			out = {
				id  = project(&prev, worklist, out.id),
				idx = out.idx,
			}
		}

		if has_flag(prc, node, .Interned) {
			hash := node_hash(prc, node)
			iview[prc.interner.len] = {hash, n}
			prc.interner.len += 1
		}

		on_node_creation(prc, node)
	}

	assert(prc.interner.len == interned_count)

	for &n in mem.slice_data_cast([]Node_ID, mem.ptr_to_bytes(&prc.pinned)) {
		n = project(&prev, worklist, n)
	}

	project :: proc(
		prev: ^Proc,
		wl: queue.Queue(Node_ID),
		node: Node_ID,
	) -> Node_ID {
		fmt.assertf(
			get_node(prev, node).gvn < u32(wl.len),
			"%v < %v",
			get_node(prev, node).gvn,
			u32(wl.len),
		)
		return wl.data[:wl.len][get_node(prev, node).gvn]
	}

	mem.copy(prev.mem.ptr, prc.mem.ptr, int(prc.mem.pos))
	prc.mem.ptr = prev.mem.ptr
	prc.waste = 0

	assert_live_pins(prc)

	verify(prc)
}

shallow_clone :: proc(prc: ^Proc, node: ^Node) -> (^Node, Node_ID) {
	assert(node != &NIL_NODE)
	size := compute_node_size(prc, node.rtype, node.extra_dwords)
	slot := arna.alloc(prc.mem, uint(size), PRECISION)
	mem.copy_non_overlapping(raw_data(slot), node, len(slot))
	return (^Node)(raw_data(slot)), get_node_id(prc, (^Node)(raw_data(slot)))
}

init_counts :: proc(prc: ^Proc, new_node: ^Node) {
	new_node.gvn = prc.gvn
	prc.gvn += 1
	if NODE_NAMES {
		prc.stable_id += 1
		new_node.stable_id = prc.stable_id
	}
}

@(tag = "api")
apply_peep :: proc(prc: ^Proc, id: Node_ID) -> (r: Node_ID) {
	defer add_efficiency_stat(prc, .redundant_peep, 1, int(id != r))

	if .Local_Peeps not_in prc.opt_flags do return id

	node := expand_node(prc, id)
	if len(node.outs) > 0 do return id

	prev_hash := node_hash(prc, node)
	mount_peep_node(prc, node)
	res, ok := prc.peep({prc = prc}, node).?
	unmount_peep_node(prc)
	if !ok do return id

	if res == id {
		unintern(prc, id, prev_hash)
		res = intern(prc, id)
		if res == id do return id
	}

	pin(prc, res)
	delete_node(prc, node)
	unpin(prc, res, no_delete = true)

	return res
}

@(disabled = ODIN_DISABLE_ASSERT)
verify :: proc(prc: ^Proc) {
	CHECK_INTERN_INTEGRITY :: true

	if !prc.dont_intern && CHECK_INTERN_INTEGRITY {
		for entry in interner_zip(prc) {
			if entry.hash == 0 {
				assert(entry.id == 0)
			} else {
				node := expand_node(prc, entry.id)
				fmt.assertf(has_flag(prc, node, .Interned), "%v", node)

				fmt.assertf(
					entry.hash == node_hash(prc, node),
					"%v %v %v %v",
					node,
					int(entry.id),
					entry.hash,
					node,
				)
			}
		}
	}

	seen_intern_slots := bit_arr.init(prc.interner.len)
	wl: Worklist
	worklist_init(&wl)
	collect_nodes(prc, &wl)
	for n in worklist_next(prc, &wl) {
		node := expand_node(prc, n)
		if len(node.outs) == 0 && node.itype != .Nil {
			fmt.panicf("%v", node)
		}
		if node.itype == .Phi {
			fmt.assertf(
				get_node(prc, node.inps[0]).itype == .Region ||
				get_node(prc, node.inps[0]).itype == .Loop,
				"%v",
				node,
			)
		}
		if has_flag(prc, n, .Interned) &&
		   !prc.dont_intern &&
		   CHECK_INTERN_INTEGRITY {
			idx, _ :=
				interner_find(prc, n, 0) or_else fmt.panicf(
					"%v %v %v %#v",
					node,
					int(n),
					node_hash(prc, n),
					interner_zip(prc),
				)
			fmt.assertf(
				bit_arr.set(seen_intern_slots, idx),
				"%v %v %v",
				node,
				int(n),
				get_node(prc, interner_zip(prc)[idx].id),
			)
		}
	}

	if !prc.dont_intern && CHECK_INTERN_INTEGRITY {
		for it := bit_arr.iter(
			seen_intern_slots,
			inverted = true,
		); idx in bit_arr.iter_next(&it) {
			if idx < seen_intern_slots.bit_length {
				arr := interner_zip(prc)
				grub := get_node(prc, arr[idx].id)
				// TODO: this is insufficient, we need to adress this in the
				// dont_delete sections
				if grub.output_count + grub.input_count == 0 {
					bit_arr.set(seen_intern_slots, idx)
				} else {
					when !ODIN_DISABLE_ASSERT {
						fmt.eprintln(idx, u32(arr[idx].id), grub, prc.interner.len)
					}
				}
			}
		}
		assert(bit_arr.pop_count(seen_intern_slots) == prc.interner.len)
	}
}

// NOTE: for debugging purposes to trace where a node was created
@(disabled = ODIN_DISABLE_ASSERT)
on_node_creation :: proc(prc: ^Proc, node: ^Node) {
	//id := get_node_id(prc, node)
}

unmount_peep_node :: proc(prc: ^Proc) {
	prc.curret_sloc = {}
}

mount_peep_node :: proc(prc: ^Proc, node: ^Node) {
	prc.curret_sloc = get_sloc(prc, node)^
}

get_or_add_const_mem :: proc(prc: ^Proc) -> (cmem: Node_ID) {
	if prc.cmem == 0 || get_node(prc, prc.cmem).rtype == DEAD_NODE_KIND {
		rmem := find_node(prc, .Mem)

		split := add_split_mem(prc, "cptspl", rmem)
		prc.cmem = add_mem(prc, "cslcm", split)
		split_mem := add_mem(prc, "cmscm", split)
		for out in get_outputs(prc, rmem) {
			if out.id != split && get_node(prc, out.id).itype != .Local {
				set_input(prc, out.id, out.idx, split_mem)
			}
		}

		for einp in get_inputs(prc, prc.end) {
			if is_end_ctrl(prc, einp) {
				node := expand_node(prc, einp)
				connect_to := einp
				if node.itype == .Return {
					connect_to = add_merge_mem(prc, "cmmrg", {node.inps[1]})
					set_input(prc, einp, 1, connect_to)
				}
				connect(prc, connect_to, split_mem)
			}
		}
	}

	return prc.cmem
}

@(tag = "api")
schedule_peeps :: proc(prc: ^Proc, schedule: ^Schedule) {
	for &bb in schedule.bbs {
		for &instr, i in bb.instrs {
			node := expand_node(prc, instr)
			mount_peep_node(prc, node)
			new_node := prc.post_schedule_peep({prc, bb.instrs[:i]}, node)
			unmount_peep_node(prc)
			if new_node == 0 do continue
			if new_node == instr do continue
			subsume(prc, new_node, instr)
			instr = new_node
		}
	}

	for &bb in schedule.bbs {
		keep := 0
		for instr in bb.instrs {
			if get_node(prc, instr).rtype != DEAD_NODE_KIND {
				bb.instrs[keep] = instr
				keep += 1
			}
		}
		resize(&bb.instrs, keep)
	}

	for &bb in schedule.bbs {
		until := len(bb.instrs)
		for ; until > 0 && get_node(prc, bb.instrs[until - 1]).dt == .Void;
		    until -= 1 {
		}

		#reverse for instr, i in bb.instrs[:until] {
			inode := expand_node(prc, instr)
			if inode.output_count == 1 &&
			   get_node(prc, inode.outs[0].id).itype == .Phi &&
			   get_node(prc, inode.outs[0].id).dt > .Mem &&
			   (0 == len(inode.inps) ||
					   (get_node(prc, inode.inps[0]).itype == .Phi &&
							   inode.inps[0] == inode.outs[0].id &&
							   get_node(prc, inode.inps[0]).output_count > 1)) {

				has_phy_inp := false
				for inp in inode.inps[min(1, len(inode.inps)):] {
					if get_node(prc, inp).itype == .Phi {
						has_phy_inp = true
						break
					}
				}
				if has_phy_inp do continue

				end := until - 1
				for other, j in bb.instrs[i:end] {
					if get_node(prc, other).dt == .Void {
						// Flag producers must remain adjacent to their consumers.
						end = i + j
						break
					}
				}
				slice.rotate_left(bb.instrs[i:end], 1)
			}
		}
	}

	add_efficiency_stat(
		prc,
		.graph_waste,
		prc.mem.pos,
		int(prc.mem.pos) - prc.waste,
	)
}

peep_subsume :: proc(prc: ^Proc, with: Node_ID, target: Node_ID) {
	node := expand_node(prc, target)

	for out in node.outs {
		worklist_add(prc, prc.worklist, out.id)
	}

	peep_ctx_flush_triggers(prc, node)

	for inp in node.inps {
		worklist_add(prc, prc.worklist, inp)
	}

	subsume(prc, with, target)
}

Pass_Snapshot :: struct {
	prev_pos: u32,
	waste:    u32,
}

pass_snapshot :: proc(ctx: ^Proc) -> Pass_Snapshot {
	// TODO: this is not perfect, wee need some kind of node mod counter
	return {u32(ctx.mem.pos), u32(ctx.waste)}
}

/// Apply peephole optimizations until fixpoint, the peephole strategy is picked
/// from the ctx.prc.node_spec.peep. If you use `compute_latices` before this
/// pass, the latices will be used to improve optimizations.
@(tag = "api,priority=95")
apply_peeps :: proc(ctx: Peep_Ctx) -> (optimized: bool) {
	prc := ctx.prc

	ensure_spec_pass_match(ctx)

	if .Peep in prc.computed_passes do return
	prc.computed_passes |= {.Peep}
	snap := pass_snapshot(ctx)

	context.allocator, _ = arna.scrath(prc.temps)

	worklist: Worklist
	worklist_init(&worklist, int(prc.gvn))

	triggers: [dynamic][dynamic]Node_ID

	prc.worklist = &worklist
	prc.triggers = &triggers

	collect_nodes(prc, &worklist)

	if .Sccp in prc.computed_passes {
		assert(len(prc.lattices) == int(prc.gvn))
	}

	rounds := 0
	triggered := 0
	for n in worklist_next(prc, &worklist) {
		rounds += 1

		node := expand_node(prc, n)

		mount_peep_node(prc, node)
		prev_hash := node_hash(prc, node)
		new_node, ok := prc.peep(ctx, node).?
		unmount_peep_node(prc)
		if node.rtype == DEAD_NODE_KIND do continue
		if !ok && node.output_count != 0 {
			assert(prev_hash == node_hash(prc, node))
			continue
		}

		optimized |= ok

		for out in node.outs {
			worklist_add(prc, &worklist, out.id)
		}

		peep_ctx_flush_triggers(prc, node)

		if new_node == n {
			unintern(prc, n, prev_hash)
			new_node = intern(prc, n)
			if new_node == n do continue
		}

		node = expand_node(prc, n)

		for inp in node.inps {
			worklist_add(prc, &worklist, inp)
		}

		if ok {
			subsume(prc, new_node, n)
		} else {
			delete_node(prc, n)
		}

		triggered += 1
	}

	optimized |= snap != pass_snapshot(ctx)
	if optimized do prc.computed_passes = {.Peep}

	add_efficiency_stat(prc, .redundant_peep, rounds, triggered)
	add_efficiency_stat(prc, .peephole_rounds, rounds, prc.gvn)

	if !ODIN_DISABLE_ASSERT {
		gvn := prc.gvn
		collect_nodes(prc, &worklist)
		assert(optimized || gvn == prc.gvn)

		for n in worklist_next(prc, &worklist) {
			node := expand_node(prc, n)
			for out in node.outs {
				onode := get_node(prc, out.id)
				if onode.itype != .Call {
					fmt.assertf(
						out.idx < int(onode.input_count) || node.itype == .End,
						"%v %v",
						node.itype,
						onode.itype,
					)
				}
			}
			fmt.assertf(
				node.itype != .Local || get_extra(prc, node, Local).size != DEAD_LOCAL,
				"%v",
				node,
			)
			new_node := prc.peep(ctx, node).? or_continue
			fmt.assertf(
				new_node == 0,
				"\nnew: %v\nold: %v",
				get_node(prc, new_node),
				node.node,
			)
		}
	}

	verify(prc)

	prc.worklist = nil
	prc.triggers = nil

	return
}

collect_nodes :: proc(prc: ^Proc, worklist: ^Worklist, renumber := true) {
	gvn := 1
	assert(worklist.len == 0)
	worklist.offset = 0
	worklist_add(prc, worklist, 0)
	worklist_add(prc, worklist, prc.entry)
	worklist_add(prc, worklist, prc.end)
	assert(worklist.len != 0)
	for gvn < int(worklist.len) {
		node := expand_node(prc, worklist.data[gvn])

		for inp in node.inps {
			worklist_add(prc, worklist, inp)
		}

		for out in node.outs {
			worklist_add(prc, worklist, out.id)
		}

		gvn += 1
	}

	if renumber {
		prc.gvn = u32(worklist.len)
		bit_arr.set_all(worklist.in_queue, false)
		bit_arr.set_range(worklist.in_queue, 0, prc.gvn, true)

		assert(worklist.data[0] == 0)

		for n, i in worklist.data[1:worklist.len] {
			get_node(prc, n).gvn = u32(1 + i)
		}

		when !ODIN_DISABLE_ASSERT {
			for n in worklist.data[1:worklist.len] {
				assert(bit_arr.contains(worklist.in_queue, get_node(prc, n).gvn))
			}
		}
	}

	when !ODIN_DISABLE_ASSERT {
		context.allocator, _ = arna.scrath(prc.temps)
		seen := bit_arr.init(prc.gvn)
		for n in worklist.data[:worklist.len] {
			node := get_node(prc, n)
			fmt.assertf(bit_arr.set(seen, node.gvn), "%v", node)
		}
	}

	assert_live_pins(prc)

	return
}

@(disabled = ODIN_DISABLE_ASSERT)
assert_live_pins :: proc(prc: ^Proc) {
	when !fmt.NO_FMT {
		prev := current_prc
		current_prc = prc
		defer current_prc = prev
	}
	expected := [?]Node_Type{.Entry, .End}
	for &n, i in mem.slice_data_cast([]Node_ID, mem.ptr_to_bytes(&prc.pinned)) {
		if expected[i] == .Return && n == 0 do continue
		fmt.assertf(get_node(prc, n).rtype != DEAD_NODE_KIND, "%v", expected[i])
		fmt.assertf(
			get_node(prc, n).itype == expected[i],
			"%v %v",
			expected[i],
			get_node(prc, n),
		)
	}
}

is_noalias :: proc {
	is_noalias_ptrs,
	is_noalias_ops,
}

is_noalias_ops :: proc(prc: ^Proc, a, b: Node_ID) -> bool {
	a, b := a, b
	if get_node(prc, a).itype == .Copy do a, b = b, a

	sizes: [2]int
	nodes := [?]Node_ID{a, b}

	for &n, i in nodes {
		node := expand_node(prc, n)
		sizes[i] = mem_op_size(prc, n) or_return
		n = node.inps[2]
	}

	bn := expand_node(prc, b)

	if bn.itype == .Copy &&
	   !is_noalias(prc, nodes[0], bn.inps[3], sizes[0], sizes[1]) {
		return false
	}

	return is_noalias(prc, nodes[0], nodes[1], sizes[0], sizes[1])
}

mem_op_dt :: proc(
	prc: ^Proc,
	n: Node_ID,
) -> (
	dt: Node_Datatype,
	ok: bool = true,
) {
	node := expand_node(prc, n)
	#partial switch node.itype {
	case .Store:
		dt = get_node(prc, node.inps[3]).dt
	case .Load:
		dt = node.dt
	}
	return
}

mem_op_size :: proc(prc: ^Proc, n: Node_ID) -> (size: int, ok: bool = true) {
	node := expand_node(prc, n)
	#partial switch node.itype {
	case .Store:
		size = DT_SIZE[get_node(prc, node.inps[3]).dt]
	case .Load:
		size = DT_SIZE[node.dt]
	case .Set, .Copy:
		size_cnst := get_extra(prc, node.inps[4], CInt)
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

is_noalias_ptrs :: proc(prc: ^Proc, a, b: Node_ID, as, bs: int) -> bool {
	abase, aoffset := base_and_offset(prc, a)
	bbase, boffset := base_and_offset(prc, b)

	anode := get_node(prc, abase)
	bnode := get_node(prc, bbase)

	if anode == bnode {
		aend, bend := aoffset + as, boffset + bs
		return aoffset >= bend || boffset >= aend
	}

	return false
}

is_always_valid_ptr :: proc(prc: ^Proc, ptr: Node_ID) -> bool {
	// NOTE: it appears that this is only valid with constant offsets
	bptr, _ := base_and_offset(prc, ptr)
	node := expand_node(prc, bptr)
	#partial switch node.itype {
	case .Global_Addr, .Local_Addr:
		return true
	case:
		return false
	}
}

base_and_offset :: proc {
	base_and_offset_proc,
	base_and_offset_default,
}

base_and_offset_default :: proc(
	prc: ^Proc,
	node: Node_ID,
) -> (
	base: Node_ID,
	off: int,
) {
	root_addr_add_offset :: proc(
		prc: ^Proc,
		node: Expanded_Node,
	) -> (
		base: Node_ID,
		off: int,
		ok: bool,
	) {
		return
	}

	return base_and_offset_proc(prc, node, root_addr_add_offset)
}

base_and_offset_proc :: proc(
	prc: ^Proc,
	node: Node_ID,
	$offn: proc(
		prc: ^Proc,
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
		bnode := expand_node(prc, base)
		if bnode.itype == .Add && bnode.dt in INT_DTS {
			lhs_const := get_extra(prc, bnode.inps[1], CInt)
			if lhs_const == nil do return
			base = bnode.inps[0]
			off += int(lhs_const.value)
			continue
		}

		if hbase, hoff, ok := offn(prc, bnode); ok {
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
			if curr.itype == .Add && curr.dt in INT_DTS {
				parent := expand_node(ctx, curr.inps[0])
				off := get_extra(ctx, curr.inps[1], CInt)
				if off == nil do return {}, false
				iter.offset -= int(off.value)
				iter.out_idx =
					slice.linear_search(
						parent.outs,
						Node_Output{id = iter.curr, idx = 0},
					) or_else fmt.panicf("")
				iter.out_idx += 1
				iter.curr = curr.inps[0]
				continue
			} else {
				return {}, false
			}
		}

		next := curr.outs[iter.out_idx]
		next_node := expand_node(ctx, next.id)
		recurse: if next_node.itype == .Add && next_node.dt in INT_DTS {
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

interner_zip :: proc(prc: ^Proc) -> (r: #soa[]SS_Entry(Node_ID)) {
	r.hash = prc.mem.ptr[prc.interner.hash_idx * PRECISION:]
	r.id = ([^]Node_ID)(prc.mem.ptr)[prc.interner.node_idx:]
	runtime.raw_soa_footer(&r).len = prc.interner.cap
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
	fmt.assertf(
		mem.is_aligned(raw_data(haystack), align_of(Intern_Vec)),
		"%v",
		raw_data(haystack),
	)
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
			mask := simd.lanes_eq(siter.haystack[siter.i], Intern_Vec(siter.needle))
			siter.mask = transmute(u16)simd.extract_lsbs(mask)
			siter.i += 1
		} else {
			return -1, false
		}
	}
}

interner_find :: proc(
	prc: ^Proc,
	id: Node_ID,
	precomputed_hash: u8,
	identity_only := false,
) -> (
	int,
	u8,
	bool,
) {
	iview := interner_zip(prc)
	assert(id != 0)

	needle := precomputed_hash
	if needle == 0 {
		needle = node_hash(prc, id)
	}
	assert(needle != 0)

	siter := simd_iter_from(iview.hash[:len(iview)], needle)
	for idx in simd_iter_next(&siter) {
		if iview.id[idx] == id || (!identity_only && node_eq(prc, iview.id[idx], id)) {
			return idx, needle, true
		}
	}

	return -1, needle, false
}

@(require_results)
intern :: proc(prc: ^Proc, id: Node_ID) -> Node_ID {
	if !has_flag(prc, id, .Interned) || prc.dont_intern {
		return id
	}

	iview := interner_zip(prc)

	idx, hash, _ := interner_find(prc, id, 0)
	if idx >= 0 do return iview.id[idx]

	if len(iview) == prc.interner.len {
		new_cap := len(iview) * 2 + size_of(Intern_Vec)
		interner_grow(prc, new_cap)
		iview = interner_zip(prc)
	}

	iview[prc.interner.len] = {hash, id}
	prc.interner.len += 1

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

interner_grow :: proc(prc: ^Proc, new_cap: int) {
	if new_cap == 0 do return

	iview := interner_zip(prc)
	grow_search_space(&iview, new_cap, arna.allocator(prc.mem))

	prc.interner.hash_idx =
		(uintptr(iview.hash) - uintptr(prc.mem.ptr)) / PRECISION
	prc.interner.node_idx =
		(uintptr(iview.id) - uintptr(prc.mem.ptr)) / PRECISION
	prc.interner.cap = new_cap
}

unintern :: proc(prc: ^Proc, id: Node_ID, precomputed_hash: u8 = 0) {
	if !has_flag(prc, id, .Interned) || prc.dont_intern do return

	// A rewritten node may now equal an earlier entry in the same hash bucket.
	// Removal must select identity or this node can remain interned after deletion.
	idx, _, _ := interner_find(prc, id, precomputed_hash, identity_only = true)
	if idx < 0 do return

	iview := interner_zip(prc)

	if iview[idx].id != id do return

	prc.interner.len -= 1
	iview[idx] = iview[prc.interner.len]

	// NOTE: there is probably a bug in the odin compiler that requires us
	// to not set the value with a leteral
	tmp: SS_Entry(Node_ID)
	iview[prc.interner.len] = tmp
}

node_approx_size :: proc(prc: ^Proc, node: ^Node) -> uint {
	return(
		uint(compute_node_size(prc, node.rtype, node.extra_dwords)) +
		uint(node.input_cap * size_of(Node_ID)) \
	)
}

subsume :: proc(prc: ^Proc, with: Node_ID, target: Node_ID) {
	assert(target != 0)

	wnode := expand_node(prc, with)
	tnode := expand_node(prc, target)

	if with == 0 {
		for out in tnode.outs {
			unintern(prc, out.id)
			get_inputs(prc, out.id)[out.idx] = 0
		}

		for {
			changed := false
			for &out in tnode.outs {

				id := intern(prc, out.id)
				if id != out.id {
					subsume(prc, id, out.id)
					out.id = id
					changed = true
				}
			}
			if !changed do break
		}

		tnode.output_count = 0
		delete_node(prc, target)

		return
	}

	wnode.stable_id = tnode.stable_id

	assert(with != target)

	ensure_available_output_cap(prc, wnode, tnode.output_count)

	when !ODIN_DISABLE_ASSERT {
		for out in tnode.outs {
			fmt.assertf(
				get_node(prc, out.id).itype != .Region || is_cfg(prc, with),
				"%v %v %v",
				wnode,
				tnode,
				get_node(prc, out.id),
			)

			fmt.assertf(
				!is_cfg(prc, with) ||
				get_node(prc, out.id).itype != .Phi ||
				out.idx == 0,
				"%v %v",
				wnode,
				tnode,
			)
		}
	}

	wnode.output_count += tnode.output_count
	tnode.output_count = 0

	wnode = expand_node(prc, with)

	copy(wnode.outs[len(wnode.outs) - len(tnode.outs):], tnode.outs)

	for out in tnode.outs {
		if out == {} do continue
		unintern(prc, out.id)
		get_inputs(prc, out.id)[out.idx] = with
	}

	pin(prc, with)

	delete_node(prc, target)

	wnode = expand_node(prc, with)

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
		if get_node(prc, out.id).rtype == DEAD_NODE_KIND do continue
		id := intern(prc, out.id)
		if id != out.id do subsume(prc, id, out.id)
	}

	unpin(prc, with)
}

node_eq :: proc(prc: ^Proc, a, b: Node_ID) -> bool {
	if a == b do return true

	an, bn := get_node(prc, a), get_node(prc, b)
	if an.spec != bn.spec do return false

	if !slice.equal(get_inputs(prc, an), get_inputs(prc, bn)) {
		return false
	}

	ad := get_extra_dwords(prc, an)
	bd := get_extra_dwords(prc, bn)
	if !slice.equal(ad, bd) do return false

	return true
}

@(tag = "api")
set_input :: proc(
	prc: ^Proc,
	id: Node_ID,
	#any_int idx: int,
	value: Node_ID,
	subsume_on_intern := false,
) -> Node_ID {
	node := expand_node(prc, id)

	assert(idx < len(node.inps))
	if node.inps[idx] == value do return id

	prev := node.inps[idx]

	add_output(prc, value, id, idx)
	node.inps[idx] = value
	remove_output(prc, prev, {idx = idx, id = id})
	node.inps[idx] = prev

	if node.rtype != DEAD_NODE_KIND {
		unintern(prc, id)
		node.inps[idx] = value
		nid := intern(prc, id)
		if subsume_on_intern {
			if nid != id do subsume(prc, nid, id)
		} else {
			assert(nid == id)
		}
		return nid
	}

	return id
}

clone :: proc(prc: ^Proc, id: Node_ID) -> Node_ID {
	node := expand_node(prc, id)
	fmt.assertf(!has_flag(prc, node, .Interned) || prc.dont_intern, "%v", node)
	assert(node.itype != .Call)
	idx := get_next_extra_slot(prc, node.rtype, node.extra_dwords)
	extra := get_extra_dwords(prc, node, consider_dbg = true)
	copy(idx[:len(extra)], extra)
	new := add_raw(prc, node.name, node.rtype, node.dt, node.inps)
	return new
}

@(tag = "node_proc")
remove_output_node :: proc(
	prc: ^Proc,
	node: ^Node,
	out: Node_Output,
	no_delete := false,
) {
	if node == &NIL_NODE do return

	outs := get_outputs(prc, node)
	out_idx, ok := slice.linear_search(outs, out)
	if !ok {
		fmt.panicf("%v %v", node, out)
	}
	outs[out_idx] = outs[len(outs) - 1]
	node.output_count -= 1

	if !no_delete {
		delete_node(prc, node)
	}
}

@(tag = "node_proc")
node_hash_node :: proc(prc: ^Proc, node: ^Node) -> u8 {
	if !has_flag(prc, node, .Interned) do return 0

	assert(node.rtype != DEAD_NODE_KIND)

	hash: u32

	spec := transmute(u32)(node.spec)
	extra_dwords := get_extra_dwords(prc, node)
	inps := get_inputs(prc, node)

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

get_node_id :: #force_inline proc(prc: ^Proc, node: ^Node) -> Node_ID {
	id := Node_ID((uintptr(node) - uintptr(prc.mem.ptr)) / PRECISION)
	return node == &NIL_NODE ? 0 : id
}

@(tag = "node_proc,api")
delete_node_node :: proc(prc: ^Proc, node: ^Node) {
	id := get_node_id(prc, node)

	if (node.output_count != 0) |
	   (id == 0) |
	   prc.dont_delete |
	   (node.rtype == DEAD_NODE_KIND) {return}

	assert(node.itype != .End)

	if prc.triggers != nil {
		peep_ctx_flush_triggers(prc, node)
	}

	for inp, i in get_inputs(prc, node) {
		if prc.worklist != nil && len(get_outputs(prc, inp)) > 1 {
			worklist_add(prc, prc.worklist, inp)
		}
		remove_output(prc, inp, {idx = i, id = id})
	}

	unintern(prc, id)

	prc.waste += int(node.input_cap * size_of(Node_ID))
	prc.waste += int(node.output_cap * size_of(Node_Output))
	prc.waste += compute_node_size(prc, node.rtype, node.extra_dwords)

	size := node_approx_size(prc, node)

	if size == prc.mem.pos - uint(id * PRECISION) {
		add_efficiency_stat(prc, .immediate_deletes, 1)
	}

	node^ = {
		rtype = DEAD_NODE_KIND,
	}

	//lines, err := trace.resolve(
	//	trace.capture(skip = 1),
	//	context.temp_allocator,
	//	context.temp_allocator,
	//)
	//runtime.print_string("[back trace]\n")
	//trace.print(lines)

	add_efficiency_stat(prc, .deleted_nodes, 1)

}

@(tag = "node_proc")
get_extra_dwords_node :: proc(
	prc: ^Proc,
	node: ^Node,
	consider_dbg := false,
) -> []u32 {
	total :=
		prc.node_extra_sizes[node.rtype] +
		u8(node.extra_dwords) +
		u8(prc.has_dbg & consider_dbg) * size_of(Sloc) / PRECISION
	return raw_data(&node.extra)[:total]
}

Nil_Node :: struct {
	using base: Node,
	cfg:        Cfg,
}

@(tag = "api", rodata, export, link_name = "bac_NIL_NODE")
NIL_NODE: Nil_Node

@(tag = "api")
get_node :: #force_inline proc(prc: ^Proc, id: Node_ID) -> ^Node {
	node := (^Node)(&([^]u32)(prc.mem.ptr)[id])
	return id == 0 ? &NIL_NODE : node
}

Expanded_Node :: struct {
	using node: ^Node,
	inps:       []Node_ID,
	outs:       []Node_Output,
}

@(tag = "api")
expand_node :: proc(prc: ^Proc, id: Node_ID) -> Expanded_Node {
	node := get_node(prc, id)

	assert(node.rtype != DEAD_NODE_KIND)
	return {node, get_inputs(prc, node), get_outputs(prc, node)}
}

@(tag = "node_proc,api")
get_inputs_node :: #force_inline proc(prc: ^Proc, node: ^Node) -> []Node_ID {
	return ([^]Node_ID)(prc.mem.ptr)[node.input_idx:][:node.input_count]
}

@(tag = "node_proc")
get_outputs_node :: #force_inline proc(
	prc: ^Proc,
	node: ^Node,
) -> []Node_Output {
	return(
		([^]Node_Output)(
			([^]u32)(prc.mem.ptr)[node.output_idx:],
		)[:node.output_count] \
	)
}

compute_node_size :: proc(prc: ^Proc, type: u16, extra_dwords: int) -> int {
	assert(prc.node_spec != nil, "call bac_ssa.start_proc first")
	total := (int(prc.node_extra_sizes[type]) + extra_dwords) * PRECISION
	return size_of(Node) + total + int(prc.has_dbg) * size_of(Sloc)
}

get_next_extra_slot :: proc(
	prc: ^Proc,
	type: u16,
	extra_dwords: int,
) -> [^]u32 {
	size := compute_node_size(prc, type, extra_dwords)
	slot := arna.alloc(prc.mem, uint(size), PRECISION)
	prc.mem.pos -= uint(len(slot))

	return ([^]u32)(raw_data(slot)[size_of(Node):])
}

get_tag :: proc(prc: ^Proc, node: Node_ID) -> ^Tag {
	when NODE_NAMES {
		return &get_node(prc, node).tag
	} else {
		return nil
	}
}

@(tag = "node_proc")
get_sloc_node :: proc(prc: ^Proc, node: ^Node) -> ^Sloc {
	assert(int(node.rtype) < len(prc.node_extra_sizes))
	pos := prc.node_extra_sizes[node.rtype] + u8(node.extra_dwords)
	ptr := &([^]u32)(&node.extra)[pos]
	return prc.has_dbg ? (^Sloc)(ptr) : &prc.nil_sloc_slot
}

Add_Raw_Meta :: bit_field u64 {
	lane:           Lane_Type | 3,
	extra_capacity: int       | 2,
	extra_dwords:   int       | 4,
}

add_raw :: proc(
	prc: ^Proc,
	name: Tag_Name,
	type: u16,
	dt: Node_Datatype,
	inps: []Node_ID = {},
	meta: Add_Raw_Meta = {},
) -> (
	id: Node_ID,
) {
	assert(prc.node_spec != nil, "call bac_ssa.start_proc first")

	id = Node_ID(prc.mem.pos / PRECISION)

	size := compute_node_size(prc, type, meta.extra_dwords)
	slot := arna.alloc(prc.mem, uint(size), PRECISION)

	node := (^Node)(raw_data(slot))
	node^ = {
		name         = name,
		rtype        = type,
		dt           = dt,
		lane         = meta.lane,
		extra_dwords = meta.extra_dwords,
		is_store     = .Store in prc.node_flags[type],
		is_load      = .Load in prc.node_flags[type],
		input_idx    = u32(prc.mem.pos / PRECISION),
		input_count  = u16(len(inps)),
		input_cap    = u16(len(inps) + meta.extra_capacity),
	}

	new_inps := arna.alloc(
		prc.mem,
		uint(int(len(inps) + meta.extra_capacity) * PRECISION),
		PRECISION,
	)
	copy(mem.slice_data_cast([]Node_ID, new_inps), inps)

	inode := intern(prc, id)
	if inode != id {
		prc.mem.pos = uint(id) * PRECISION
		return inode
	}

	for inp, i in inps {
		add_output(prc, inp, id, i)
	}

	init_counts(prc, node)

	get_sloc(prc, node)^ = prc.curret_sloc

	on_node_creation(prc, node)

	return
}

@(deferred_out = pop_sloc)
@(tag = "api")
sloc_scope :: proc(prc: ^Proc, sloc: Sloc) -> (out_prc: ^Proc, prev: Sloc) {
	out_prc = prc
	prev = push_sloc(prc, sloc)
	return
}

push_sloc :: proc(prc: ^Proc, dnd: Sloc) -> (prev: Sloc) {
	prev = prc.curret_sloc
	prc.curret_sloc = dnd
	return
}

pop_sloc :: proc(prc: ^Proc, prev: Sloc) {
	prc.curret_sloc = prev
}

swap_inputs :: proc(prc: ^Proc, node: Expanded_Node, i, j: int) {
	id := get_node_id(prc, node)
	ind := expand_node(prc, node.inps[i])
	jnd := expand_node(prc, node.inps[j])

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

	unintern(prc, id)
	node.inps[j], node.inps[i] = node.inps[i], node.inps[j]
	nid := intern(prc, id)
	assert(nid == id)
}

@(tag = "api")
connect :: proc(prc: ^Proc, use: Node_ID, def: Node_ID) -> int {
	idx := add_input(prc, use, def)
	add_output(prc, def, use, idx)
	return idx
}

@(tag = "node_proc")
add_input_node :: proc(prc: ^Proc, node: ^Node, inp: Node_ID) -> int {
	if node == &NIL_NODE do return 0

	free_idx := int(node.input_count)
	grow: if node.input_count == node.input_cap {
		prc.waste += int(node.input_cap * size_of(Node_ID))
		base := u32(prc.mem.pos / PRECISION)
		new_cap := node.input_cap * 2 + 2
		slot := arna.alloc(
			prc.mem,
			uint(new_cap * PRECISION),
			PRECISION,
			zeroed = true,
		)
		copy(mem.slice_data_cast([]Node_ID, slot), get_inputs(prc, node))
		node.input_cap = new_cap
		node.input_idx = base
	}

	id := get_node_id(prc, node)

	unintern(prc, id)
	raw_data(get_inputs(prc, node))[free_idx] = inp
	node.input_count += 1
	nid := intern(prc, id)
	assert(nid == id)

	return free_idx
}

ensure_available_output_cap :: proc(prc: ^Proc, node: ^Node, available: u16) {
	if node.output_cap - node.output_count < available {
		prc.waste += int(node.output_cap * size_of(Node_ID))
		base := u32(prc.mem.pos / PRECISION)
		new_cap := max(node.output_cap * 2 + 2, node.output_cap + available)
		slot := arna.alloc(
			prc.mem,
			uint(new_cap * size_of(Node_Output)),
			PRECISION,
		)
		copy(mem.slice_data_cast([]Node_Output, slot), get_outputs(prc, node))
		node.output_cap = new_cap
		node.output_idx = base
	}
}

@(tag = "node_proc")
add_output_node :: proc(
	prc: ^Proc,
	node: ^Node,
	out: Node_ID,
	#any_int i: int,
) {
	if node == &NIL_NODE do return

	assert(node.rtype != DEAD_NODE_KIND)
	ensure_available_output_cap(prc, node, 1)

	fmt.assertf(
		get_extra(prc, node, Cfg) == nil ||
		get_node(prc, out).itype != .Phi ||
		i == 0,
		"%v %v",
		node,
		out,
	)

	node.output_count += 1
	assert(i < 256)
	get_outputs(prc, node)[node.output_count - 1] = {
		id  = out,
		idx = i,
	}
}

get_extra :: proc {
	get_static_extra_node,
	get_static_extra_node_id,
}

@(tag = "node_proc")
get_static_extra_node :: #force_inline proc(
	prc: ^Proc,
	node: ^Node,
	$T: typeid,
) -> ^T {
	fmt.assertf(
		int(node.rtype) < len(prc.inheritance_table),
		"node: %v %v",
		get_node_id(prc, node),
		get_outputs(prc, node),
	)
	if prc.inheritance_table[node.rtype] & (1 << inherit_idx_of(T)) ==
	   0 {return nil}
	return (^T)(&node.extra)
}

@(tag = "node_proc")
has_flag_node :: #force_inline proc(
	prc: ^Proc,
	node: ^Node,
	flag: Class_Flag,
) -> bool {
	fmt.assertf(int(node.rtype) < len(prc.node_flags), "%v", node.rtype)
	return flag in prc.node_flags[node.rtype]
}

is_end_ctrl :: proc(prc: ^Proc, node: Node_ID) -> bool {
	return get_node(prc, node).itype not_in bit_set[Node_Type]{.Dbg_Scope, .Nil}
}

truncate_inputs :: proc(prc: ^Proc, scope: Node_ID, #any_int to_len: int) {
	if scope == 0 do return

	snode := expand_node(prc, scope)
	assert(to_len <= int(snode.input_count))

	for &inp, i in snode.inps[to_len:] {
		remove_output(prc, inp, {idx = to_len + i, id = scope})
		inp = 0
	}

	snode.input_count = u16(to_len)
}

ensure_init :: proc() {
	when ODIN_BUILD_MODE != .Executable {
		@(static) inited: bool
		if !intrinsics.atomic_exchange(&inited, true) {
			runtime._startup_runtime()
		}
	}
}
