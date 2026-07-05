package backend

import "../vendored/gam/util/arna"
import "base:intrinsics"
import "base:runtime"
import "core:container/queue"
import "core:fmt"
import "core:io"
import "core:log"
import "core:math"
import "core:mem"
import "core:reflect"
import "core:simd"
import "core:slice"
import "core:sort"
import "core:terminal/ansi"

when NODE_NAMES {
	PREFIX_SIZE :: size_of(string)
} else {
	PREFIX_SIZE :: 0
}

DEAD_LOCAL: i32 : -1
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
		size:   i32,
		offset: i32,
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

Graph :: struct {
	using node_spec: ^Node_Spec,
	worklist:        ^queue.Queue(Node_ID),
	triggers:        ^[dynamic][dynamic; 4]Node_ID,
	interner:        #soa[]Node_Intern_Entry,
	interner_len:    int,
	mem:             ^arna.Allocator,
	gvn:             u32,
	end:             Node_ID,
	waste:           int,
	dont_intern:     bool,
	opt_flags:       Graph_Opt_Flags,
}

Graph_Opt_Flags :: bit_set[Graph_Opt_Flag]

Graph_Opt_Flag :: enum int {
	Schedule_Peeps,
	Iter_Peeps,
	Local_Peeps,
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
	graph_add_output(graph, id, 0, 0)
}

graph_unpin :: proc(graph: ^Graph, id: Node_ID, no_delete := false) {
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
	if .Schedule_Peeps not_in graph.opt_flags do return

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

}

graph_iter_peeps :: proc(graph: ^Graph) {
	if .Iter_Peeps not_in graph.opt_flags &&
	   graph.node_spec == &SPECS[.Builder] {return}

	context.allocator, _ = arna.scrath()

	worklist: queue.Queue(Node_ID)
	queue.init(&worklist, int(graph.gvn))

	triggers: [dynamic][dynamic; 4]Node_ID

	graph.worklist = &worklist
	graph.triggers = &triggers

	collect_nodes(graph, &worklist)

	for n in worklist_next(graph, &worklist) {
		node := graph_expand(graph, n)

		prev_hash := graph_node_hash(graph, node)
		new_node := graph.peep({graph}, node)
		if new_node == 0 do continue

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

		graph_subsume(graph, new_node, n, &worklist)
	}

	if ODIN_DEBUG {
		collect_nodes(graph, &worklist)

		for n in worklist_next(graph, &worklist) {
			node := graph_expand(graph, n)
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

	collect_nodes :: proc(graph: ^Graph, worklist: ^queue.Queue(Node_ID)) {
		i := 0
		worklist.offset = 0
		worklist_add(graph, worklist, NODE_START)
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
	fold_un_op :: proc(
		op: Un_Op,
		oper: i64,
		src_ty: Node_Datatype,
	) -> (
		value: i64,
	) {
		bit_size := uint(DT_SIZE[src_ty] * 8)
		mask: i64 = -1 << bit_size

		switch op {
		case .Not:
			value = ~oper
		case .Neg:
			value = -oper
		case .Uext:
			value = oper &~ mask
		case .Sext:
			if oper & (1 << (bit_size - 1)) == 0 {
				value = oper &~ mask
			} else {
				value = oper | mask
			}
		case .Cast:
			value = oper
		}
		return
	}

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
		node := node
		id := graph_id(ctx, node)
		is_complete := peep_ctx_graph_is_complete(ctx)

		DEAD_EXCEPTIONS := bit_set[Ideal_Node_Type]{.Region, .Start}

		if is_cfg(ctx, id) && node.itype not_in DEAD_EXCEPTIONS {
			idom := graph_expand(ctx, node.inps[0])
			if idom.btype == .Dead {
				return node.inps[0]
			}
		}

		ordered_remove :: proc(ctx: Peep_Ctx, node: ^Expanded_Node, i: int) {
			par := graph_id(ctx, node)
			for inp, j in node.inps[i + 1:] {
				graph_add_output(ctx, inp, par, j + i)
				graph_remove_output(ctx, inp, {idx = j + i + 1, id = par})
			}
			inp := node.inps[i]
			slice.rotate_left(node.inps[i:], 1)
			node.inps = node.inps[:len(node.inps) - 1]
			node.input_count -= 1
			graph_remove_output(ctx, inp, {idx = i, id = par})
		}

		STORES := bit_set[Ideal_Node_Type]{.Store, .Set, .Copy}

		emilinate_dead_local: if node.itype in STORES {
			base, _ := base_and_offset(ctx, node.inps[2])
			bnode := graph_expand(ctx, base)
			if bnode.itype != .Local_Addr do break emilinate_dead_local
			if graph_extra(ctx, bnode.inps[0], Local).size == DEAD_LOCAL {
				return node.inps[1]
			}
		}

		#partial match: switch node.itype {
		case .Local_Addr:
			if !is_complete do break match

			slot := graph_expand(ctx, node.inps[0])
			root := graph_expand(ctx, slot.inps[0])
			mark_dead: {
				if root.itype != .Mem do break mark_dead

				slot_local := graph_extra(ctx, slot, Local)
				if slot_local.size == DEAD_LOCAL do break match

				iter: Offset_Iter
				iter.curr = id
				for user in offset_iter_next(ctx, &iter) {
					unode := graph_expand(ctx, user.id)
					if unode.itype in STORES && user.idx == 2 {
						continue
					}

					peep_ctx_add_trigger(ctx, user.id, id)
					break mark_dead
				}

				slot_local.size = DEAD_LOCAL

				iter = {}
				iter.curr = id
				for user in offset_iter_next(ctx, &iter) {
					worklist_add(ctx, ctx.worklist, user.id)
				}

				break match
			}

			forward: {
				if root.itype != .Mem do break forward

				forward_candidate: Node_ID
				op_count := 0

				iter: Offset_Iter
				iter.curr = id
				for user in offset_iter_next(ctx, &iter) {
					unode := graph_expand(ctx, user.id)
					op_count += 1
					if unode.itype in STORES && user.idx == 2 {
						continue
					}

					if unode.itype == .Copy &&
					   user.idx == 3 &&
					   forward_candidate == 0 {
						forward_candidate = user.id
						continue
					}

					peep_ctx_add_trigger(ctx, user.id, id)
					break forward
				}

				assert(forward_candidate != 0)

				fnode := graph_expand(ctx, forward_candidate)

				cursor := fnode.inps[1]
				op_count -= 1
				for op_count > 0 {
					cnode := graph_expand(ctx, cursor)
					if cnode.itype not_in STORES do break forward
					base, _ := base_and_offset(ctx, cnode.inps[2])
					if base != id do break forward
					cursor = cnode.inps[1]
					op_count -= 1
				}

				return fnode.inps[2]
			}
		case .Region:
			#reverse for inp, i in node.inps {
				inode := graph_expand(ctx, inp)
				if inode.btype != .Dead do continue
				ordered_remove(ctx, &node, i)

				for out in node.outs {
					onode := graph_expand(ctx, out.id)
					if onode.itype == .Phi && len(onode.inps) > 2 {
						ordered_remove(ctx, &onode, i + 1)
					}
				}

				if node.input_count == 1 {
					break
				}
			}

			elim: if len(node.inps) == 1 {
				for out in node.outs {
					if graph_get(ctx, out.id).itype == .Return {
						break elim
					}
				}
				return node.inps[0]
			}

			phi_count := 0
			for out in node.outs {
				onode := graph_expand(ctx, out.id)
				phi_count += int(onode.itype == .Phi)
			}

			changed := true

			for changed {
				changed = false

				node = graph_expand(ctx, id)

				merge: #reverse for inp, i in node.inps {
					inode := graph_expand(ctx, inp)
					if inode.itype != .Region do continue

					not_covered_count := phi_count
					for out in inode.outs {
						onode := graph_expand(ctx, out.id)
						if onode.itype == .Region do continue

						if onode.itype != .Phi do continue merge
						if len(onode.outs) != 1 do continue merge
						if graph_inps(ctx, onode.outs[0].id)[0] != id {
							continue merge
						}

						not_covered_count -= 1
					}

					if not_covered_count != 0 {
						continue
					}

					for inp in inode.inps[1:] {
						idx := graph_add_input(ctx, node, inp)
						graph_add_output(ctx, inp, id, idx)
					}

					for out in node.outs {
						onode := graph_expand(ctx, out.id)
						if onode.itype != .Phi do continue

						to_merge := graph_expand(ctx, onode.inps[1 + i])
						assert(to_merge.itype == .Phi)

						for inp in to_merge.inps[2:] {
							idx := graph_add_input(ctx, onode, inp)
							graph_add_output(ctx, inp, out.id, idx)
						}

						graph_set_input(ctx, out.id, 1 + i, to_merge.inps[1])
					}

					graph_set_input(ctx, id, i, inode.inps[0])

					changed = true
				}
			}

			return 0
		case .Phi:
			if graph_get(ctx, node.inps[0]).btype == .Dead &&
			   2 < len(node.inps) {
				ordered_remove(ctx, &node, 2)

				if node.rtype == DEAD_NODE_KIND do break match
			}

			elimn: if len(node.inps) == 2 {
				for out in graph_outs(ctx, node.inps[0]) {
					if graph_get(ctx, out.id).itype == .Return {
						break elimn
					}
				}
				return node.inps[1]
			}

			if 2 < len(node.inps) && node.inps[2] == id {
				return node.inps[1]
			}
		case .Then, .Else:
			if_ := graph_expand(ctx, node.inps[0])
			cond_const := graph_extra(ctx, if_.inps[1], CInt)
			if cond_const != nil {
				if (cond_const.value == 0) ~ (node.itype == .Else) {
					return graph_add_dead(ctx, "dead")
				} else {
					return if_.inps[0]
				}
			} else {
				peep_ctx_add_trigger(ctx, if_.inps[1], id)
			}
		case .Neg ..= .Cast:
			op := Un_Op(node.itype)
			oper := graph_expand(ctx.graph, node.inps[0])
			coper := graph_extra(ctx.graph, oper, CInt)

			if coper != nil {
				value := fold_un_op(op, coper.value, oper.dt)
				return graph_add_c_int(ctx.graph, "fld", node.dt, value)
			}

			if (op == .Sext || op == .Uext) &&
			   DT_SIZE[oper.dt] >= DT_SIZE[node.dt] {
				return node.inps[0]
			}

			if op == .Cast && oper.dt == node.dt {
				return node.inps[0]
			}
		case .Add ..= .And_Not:
			lhs := graph_expand(ctx.graph, node.inps[0])
			rhs := graph_expand(ctx.graph, node.inps[1])

			clhs := graph_extra(ctx.graph, lhs, CInt)
			crhs := graph_extra(ctx.graph, rhs, CInt)
			op := Bin_Op(node.itype)

			if clhs != nil && crhs != nil {
				value := fold_bin_op(clhs.value, op, crhs.value)
				return graph_add_c_int(ctx.graph, "fld", lhs.dt, value)
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
				for clhs_rhs != nil && clhs_lhs == nil {
					res := graph_add_bin_op(
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
					worklist_add(ctx, ctx.worklist, res)
					return res
				}

				if clhs_rhs == nil && clhs_lhs == nil {
					peep_ctx_add_trigger(ctx, lhs.inps[1], id)
				}
			}

			COMUTATIVE_OR_SWAPPABLE :: bit_set[Bin_Op] {
				.Add,
				.Mul,
				.Ne,
				.Eq,
				.Or,
				.And,
				.Xor,
				.Ge,
				.Lt,
				.Gt,
				.Le,
				.U_Ge,
				.U_Lt,
				.U_Gt,
				.U_Le,
			}

			@(static, rodata)
			SWAPPABLE := #partial [Bin_Op]Bin_Op {
				.Ge   = .Lt,
				.Lt   = .Ge,
				.Gt   = .Le,
				.Le   = .Gt,
				.U_Ge = .U_Lt,
				.U_Lt = .U_Ge,
				.U_Gt = .U_Le,
				.U_Le = .U_Gt,
			}

			@(static, rodata)
			COMUTE_PRIORITY_TABLE := #partial [Ideal_Node_Type]u8 {
				.CInt = 1,
			}

			lhs_priority, rhs_priority: u8
			if int(lhs.itype) < len(COMUTE_PRIORITY_TABLE) {
				lhs_priority = COMUTE_PRIORITY_TABLE[lhs.itype]
			}
			if int(rhs.itype) < len(COMUTE_PRIORITY_TABLE) {
				rhs_priority = COMUTE_PRIORITY_TABLE[rhs.itype]
			}

			if op in COMUTATIVE_OR_SWAPPABLE && lhs_priority > rhs_priority {
				if SWAPPABLE[op] != {} {
					node.rtype = u16(SWAPPABLE[op])
				}

				for inp, i in node.inps {
					graph_add_output(ctx, inp, id, 1 - i)
					graph_remove_output(ctx, inp, {idx = i, id = id})
				}
				node.inps[0], node.inps[1] = node.inps[1], node.inps[0]
				worklist_add(ctx, ctx.worklist, id)
				return id
			}
		case .Load, .Load_S:
			florward_loads: {
				cursor := node.inps[1]
				for {
					cnode := graph_expand(ctx, cursor)
					if cnode.itype != .Store do break
					if cnode.inps[0] != node.inps[0] do break
					if !is_noalias(
						ctx,
						cnode.inps[2],
						node.inps[2],
						node.dt,
						graph_get(ctx, cnode.inps[3]).dt,
					) {
						break
					}
					cursor = cnode.inps[1]
				}

				fnode := graph_expand(ctx, cursor)
				if fnode.itype == .Store &&
				   fnode.inps[0] == node.inps[0] &&
				   fnode.inps[2] == node.inps[2] &&
				   graph_get(ctx, fnode.inps[3]).dt == node.dt {

					return fnode.inps[3]
				} else {
					peep_ctx_add_trigger(ctx, cursor, id)
					if fnode.itype == .Store {
						peep_ctx_add_trigger(ctx, fnode.inps[2], id)
					}
				}
			}
		case .Store:
			coalesce_stores: {
				SIZE_LIMIT :: 8
				fuel := SIZE_LIMIT
				imm: i64
				size: int
				common_ctrl := node.inps[0]
				common_base, prev_offset := base_and_offset(ctx, node.inps[2])
				prev_offset += DT_SIZE[graph_get(ctx, node.inps[3]).dt]
				cursor := id
				last_valid: Node_ID
				last_valid_imm: i64
				last_valid_size: int
				for fuel > 0 {
					cnode := graph_expand(ctx, cursor)
					if cnode.itype != .Store do break
					if size != 0 && len(cnode.outs) != 1 do break
					if cnode.inps[0] != common_ctrl do break
					val := graph_get(ctx, cnode.inps[3])
					val_const := graph_extra(ctx, val, CInt)
					if val_const == nil do break
					base, offset := base_and_offset(ctx, cnode.inps[2])
					if base != common_base do break
					if prev_offset - offset != DT_SIZE[val.dt] do break
					if size + DT_SIZE[val.dt] > SIZE_LIMIT do break

					size += DT_SIZE[val.dt]
					imm <<= uint(DT_SIZE[val.dt] * 8)
					imm |= val_const.value

					prev_offset = offset
					if math.is_power_of_two(size) {
						last_valid = cursor
						last_valid_imm = imm
						last_valid_size = size
					}
					cursor = cnode.inps[1]
					fuel -= 1

				}

				if last_valid != id && last_valid != 0 {
					final := graph_expand(ctx, last_valid)
					return graph_add_store(
						ctx,
						"cost",
						final.inps[0],
						final.inps[1],
						final.inps[2],
						graph_add_c_int(
							ctx,
							"cocnst",
							int_for_size(last_valid_size),
							last_valid_imm,
						),
					)
				}
			}

		case .Set:
			if !is_complete do break

			ctrl := node.inps[0]
			mem := node.inps[1]
			dst := graph_expand(ctx, node.inps[2])
			val := graph_expand(ctx, node.inps[3])
			val_const := graph_extra(ctx, val, CInt)
			sze := graph_expand(ctx, node.inps[4])
			sze_const := graph_extra(ctx, sze, CInt)

			if dst.itype != .Local_Addr do break
			if sze_const == nil do break

			if len(node.outs) == 1 {
				out := graph_expand(ctx, node.outs[0].id)
				if out.itype == .Copy &&
				   out.inps[0] == ctrl &&
				   out.inps[2] == node.inps[2] &&
				   out.inps[4] == node.inps[4] {
					return mem
				}
			}

			if val_const == nil do break
			if val_const.value != 0 do break

			dst_slot := graph_expand(ctx, dst.inps[0])

			Slot :: bit_field int {
				size:   int | 8,
				state:  enum uint {
					Uninit,
					Needs_Init,
					Inited,
				}    | 2,
				offset: int | 54,
			}

			Slots :: [dynamic; 8]Slot

			slots: Slots
			dst_size := int(graph_extra(ctx, dst_slot, Local).size)

			Member :: struct {
				id:       Node_ID,
				slot_idx: int,
			}

			members: [dynamic; 16]Member

			iter: Offset_Iter
			iter.curr = node.inps[2]
			corrupt := false
			scan: for out in offset_iter_next(ctx, &iter) {
				onode := graph_expand(ctx, out.id)

				size: int
				#partial switch onode.itype {
				case .Load:
					size = DT_SIZE[onode.dt]
				case .Store:
					if out.idx != 2 {
						continue
					}
					size = DT_SIZE[graph_get(ctx, onode.inps[3]).dt]
				case .Copy, .Set:
					if out.idx != 2 {
						continue
					}

					copy_size := graph_extra(ctx, onode.inps[4], CInt)
					if copy_size == nil {
						continue
					}

					size = int(copy_size.value)
					continue // TODO: worth a try
				case:
					continue
				}

				end := iter.offset + size

				if end > dst_size {
					log.error(ctx.graph)
					log.error(onode.node, iter.offset, size, dst_size)
					break match
				}

				#reverse for &slot, i in slots {
					send := slot.offset + slot.size
					if end <= slot.offset || send <= iter.offset {
						continue
					}

					if slot.offset != iter.offset || slot.size != size {
						corrupt = true
					}

					if onode.itype != .Load {
						corrupt |= append(&members, Member{out.id, i}) == 0
					}
					continue scan
				}

				if onode.itype != .Load {
					corrupt |=
						append(&members, Member{out.id, len(slots)}) == 0
				}

				slot := Slot {
					offset = iter.offset,
					size   = size,
				}
				corrupt |= append(&slots, slot) == 0
			}

			if corrupt {
				for m in members {
					peep_ctx_add_trigger(ctx, m.id, id)
				}
				break match
			}

			blocker: Node_ID
			cursor := id
			traverse: for {
				cnode := graph_expand(ctx, cursor)
				prev_len := len(slots)

				cursor = 0
				cur_slot: ^Slot

				for out in cnode.outs {
					onode := graph_expand(ctx, out.id)

					slot: ^Slot
					for memb in members {
						if memb.id == out.id {
							slot = &slots[memb.slot_idx]
						}
					}

					if slot == nil {
						if onode.itype == .Load {
							base, off := base_and_offset(ctx, onode.inps[2])
							if base == node.inps[2] {
								for &slt in slots {
									if slt.offset == off {
										slot = &slt
										break
									}
								}
							}
						}
					}

					if slot == nil {
						blocker = out.id
						break traverse
					}

					#partial switch onode.itype {
					case .Store:
						// give up on branches and backtrack
						if cursor != 0 {
							break traverse
						}
						cur_slot = slot
						cursor = out.id
					case .Load:
						if slot.state == .Uninit {
							slot.state = .Needs_Init
						}
					case:
						panic("")
					}
				}

				if cursor == 0 do break
				if cur_slot.state == .Uninit {
					cur_slot.state = .Inited
				}
			}

			sort.quick_sort(slots[:])

			align_of :: proc(offset: int) -> int {
				if offset == 0 do return MAX_STORE_UNIT
				return 1 << uint(intrinsics.count_trailing_zeros(offset))
			}

			MAX_STORE_UNIT :: 8

			align := min(align_of(dst_size), MAX_STORE_UNIT)
			assert(align != 0)

			offset := dst_size
			prev_len := len(slots)
			for i in 0 ..= prev_len {
				slot := i == prev_len ? Slot{} : slots[prev_len - i - 1]

				fmt.assertf(offset >= slot.offset, "%v, %v", offset, slot)
				rev_offset := slot.offset + slot.size
				inserts := 0
				for rev_offset < offset {
					fill := Slot {
						size = offset - rev_offset,
					}
					current_align := min(align, align_of(rev_offset))
					assert(current_align != 0)
					fill.size = min(current_align, fill.size)
					assert(fill.size != 0)
					fill.offset = rev_offset
					rev_offset += fill.size
					if prev_len - i + inserts >= cap(slots) {
						break match
					}
					inject_at(&slots, prev_len - i + inserts, fill)
					inserts += 1
				}
				offset = slot.offset
			}

			keep := 0
			for slot in slots {
				if slot.state != .Inited {
					slots[keep] = slot
					keep += 1
				}
			}
			resize(&slots, keep)

			if len(slots) >= 5 {
				peep_ctx_add_trigger(ctx, blocker, id)
				break match
			}

			mem_thread := mem
			for slot in slots {
				idx := intrinsics.count_trailing_zeros(slot.size)
				table := [4]Node_Datatype{.I8, .I16, .I32, .I64}
				dt := table[idx]
				vl := graph_add_c_int(ctx, "zrsp", dt, 0)
				off := graph_add_c_int(ctx, "zroffv", .I64, i64(slot.offset))
				dst := graph_add_bin_op(
					ctx,
					"zroff",
					.Add,
					.I64,
					node.inps[2],
					off,
				)
				worklist_add(ctx, ctx.worklist, dst)
				mem_thread = graph_add_store(
					ctx,
					"zrst",
					ctrl,
					mem_thread,
					dst,
					vl,
				)
				worklist_add(ctx, ctx.worklist, mem_thread)
			}

			return mem_thread
		case .Copy:
			if node.inps[2] == node.inps[3] {
				return node.inps[1]
			}
		}

		return 0
	}

	builder_post_schedule_peep :: proc(
		ctx: PS_Peep_Ctx,
		node: Expanded_Node,
	) -> Node_ID {
		return 0
	}
}

is_noalias :: proc(
	graph: ^Graph,
	a, b: Node_ID,
	ad, bd: Node_Datatype,
) -> bool {
	abase, aoffset := base_and_offset(graph, a)
	bbase, boffset := base_and_offset(graph, b)

	anode := graph_get(graph, abase)
	bnode := graph_get(graph, bbase)

	if anode == bnode {
		aend, bend := aoffset + DT_SIZE[ad], boffset + DT_SIZE[bd]
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
	ctx: Peep_Ctx,
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
		for i in 1 ..< exit.input_count {
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
	base_size := graph_get(ctx, loop.scope).input_count
	graph_truncate_scope(ctx, scope, base_size)
	loop.scopes[variant] = graph_merge_scopes(ctx, scope, loop.scopes[variant])
}

graph_merge_returns :: proc(graph: ^Graph, args: []Node_ID) -> Node_ID {
	if graph.end == 0 {
		args[0] = graph_add_region(graph, "rret", {args[0]})
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
		idx := graph_add_input(graph, end.inps[0], args[0])
		graph_add_output(graph, args[0], end.inps[0], idx)

		for i in 1 ..< len(end.inps) {
			new := i < len(args) ? args[i] : graph_add_poison(graph, "rpsn")
			idx = graph_add_input(graph, end.inps[i], new)
			graph_add_output(graph, new, end.inps[i], idx)
		}
	}

	return graph.end
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
) {
	wnode := graph_expand(graph, with)
	tnode := graph_expand(graph, target)

	assert(with != target)

	try_recycle: if 0 == 0 {
		if wnode.in_worklist {
			last := queue.pop_back(worklist)
			queue.push_back(worklist, last)
			if last != with {
				break try_recycle
			}
		}

		wtotal_size := node_approx_size(graph, wnode)

		if int(graph.mem.pos - wtotal_size) / PRECISION != int(with) {
			break try_recycle
		}

		assert(wnode.gvn == graph.gvn - 1)
		assert(wnode.output_cap == 0)
		assert(wnode.input_cap == wnode.input_count)
		assert(
			wnode.input_idx ==
			(u32(graph.mem.pos) - u32(wnode.input_cap) * size_of(Node_ID)) /
				PRECISION,
		)

		ttotal_size := node_approx_size(graph, tnode)

		if wtotal_size > ttotal_size do break try_recycle

		if wnode.in_worklist {
			queue.pop_back(worklist)
		}

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
		wnode.in_worklist = tnode.in_worklist
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

	idx := graph_add_input(graph, scope_node, value)
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
	assert(to_len <= int(snode.input_count))

	for &inp, i in snode.inps[to_len:snode.input_count] {
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

	region := graph_add_region(graph, "reg", {lnode.inps[0], rnode.inps[0]})

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
	out_idx := slice.linear_search(outs, out) or_else panic("")
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

	if int(graph.mem.pos - size) / PRECISION != int(id) {
		graph.waste += int(node.input_cap * size_of(Node_ID))
		graph.waste += int(node.output_count * size_of(Node_Output))
		graph.waste += size_of(Node)
		graph.waste += int(graph.node_extra_sizes[node.rtype] * PRECISION)
	} else {
		graph.mem.pos = uint(id) * PRECISION - PREFIX_SIZE
		graph.gvn -= 1
	}

	node.rtype = DEAD_NODE_KIND

	node^ = {
		rtype = DEAD_NODE_KIND,
	}
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
	assert(node.rtype != DEAD_NODE_KIND)
	in_place := graph.inplace_slot_idxs[node.rtype]
	if in_place >= 0 {
		in_place += i8(node.additional_data_start)
	}
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
		input_cap   = u16(len(inps)),
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
	max_growth: u16 = 1024,
) -> int {
	free_idx := int(node.input_count)
	grow: if node.input_count == node.input_cap {
		graph.waste += int(node.input_cap * size_of(Node_ID))
		base := u32(graph.mem.pos / PRECISION)
		max_growth := node.input_cap + max_growth
		new_cap := min(node.input_cap * 2 + 2, max_growth)
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

@(tag = "node_proc")
graph_add_extra_input_node :: proc(graph: ^Graph, node: ^Node, inp: Node_ID) {
	// TODO: remove this
	node.input_cap += 1
	node.input_count += 1
	graph_inps(graph, node)[node.input_cap - 1] = inp
	graph_add_output(graph, inp, graph_id(graph, node), node.input_cap - 1)
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
	context.allocator, _ = arna.scrath()

	ctx := ctx
	our_ctx: Graph_Schedule

	if ctx == nil {
		graph_schedule(graph, &our_ctx, context.allocator)
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
	if node.mem_alignment_pow != 0 {
		written_one = true
		fmt.wprintf(w, "align: %v", 1 << node.mem_alignment_pow)
	}

	graph_display_extra(w, extra, "", &written_one)

	for inp, i in node.inps {
		if written_one {
			if i == int(node.input_count) {
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

	if !mem.check_zero(reflect.as_bytes(extra)) {
		if written_one^ do fmt.wprint(w, ", ")
		written_one^ = true
		if name != "" {
			fmt.wprintf(w, "%v: ", name)
		}
		fmt.wprint(w, extra)
	}
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
