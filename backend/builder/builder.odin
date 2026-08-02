package builder

import backend ".."
import "base:intrinsics"
import "base:runtime"
import "core:container/queue"
import "core:fmt"
import "core:math"
import "core:slice"
import "core:sort"

CInt :: backend.CInt
Un_Op :: backend.Un_Op
Bin_Op :: backend.Bin_Op

sext :: proc(oper: i64, ty: backend.Node_Datatype) -> (value: i64) {
	bit_size := uint(backend.DT_SIZE[ty] * 8)
	mask: i64 = -1 << bit_size

	if oper & (1 << (bit_size - 1)) == 0 {
		value = oper &~ mask
	} else {
		value = oper | mask
	}

	return
}

fold_un_op :: proc(
	op: Un_Op,
	oper: i64,
	dst_ty: backend.Node_Datatype,
	src_ty: backend.Node_Datatype,
) -> (
	value: i64,
) {
	bit_size := uint(backend.DT_SIZE[src_ty] * 8)
	mask: i64 = -1 << bit_size

	#partial switch op {
	case .Not:
		value = ~oper
	case .Neg:
		value = -oper
	case .Uext:
		value = oper &~ mask
	case .Cast:
		value = oper &~ (-1 << uint(backend.DT_SIZE[dst_ty] * 8))
	case .Sext:
		value = sext(oper, src_ty)
	case .F_Ext, .F_Demote:
		value = oper
	case .F_From_I:
		value = transmute(i64)(f64(oper))
	case .F_To_I:
		value = i64(transmute(f64)oper)
	}
	return
}

fold_bin_op :: proc(
	lhs: i64,
	op: Bin_Op,
	rhs: i64,
	ty: backend.Node_Datatype,
) -> (
	value: i64,
) {
	lhs := lhs
	rhs := rhs
	#partial switch op {
	case .Div, .Rem, .Shr, .Shl, .Le ..= .Ge:
		lhs = sext(lhs, ty)
	}

	#partial switch op {
	case .Div, .Rem, .Le ..= .Ge:
		rhs = sext(rhs, ty)
	}

	switch op {
	case .Add:
		value = lhs + rhs
	case .Sub:
		value = lhs - rhs
	case .Mul:
		value = lhs * rhs
	case .Div:
		if rhs == 0 do return 0
		value = lhs / rhs
	case .Rem:
		if rhs == 0 do return 0
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
		value = sext(lhs << u64(rhs), ty)
	case .Shr:
		value = sext(lhs, ty) >> u64(rhs)
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
		// TODO: actually report this, maybe emit a special node
		if rhs == 0 do return 0
		value = i64(u64(lhs) / u64(rhs))
	case .U_Rem:
		if rhs == 0 do return 0
		value = i64(u64(lhs) % u64(rhs))
	case .U_Shr:
		value = i64(u64(lhs) >> u64(rhs))
	case .F_Ne:
		value = i64(tf(lhs) != tf(rhs))
	case .F_Eq:
		value = i64(tf(lhs) == tf(rhs))
	case .F_Le:
		value = i64(tf(lhs) <= tf(rhs))
	case .F_Lt:
		value = i64(tf(lhs) < tf(rhs))
	case .F_Gt:
		value = i64(tf(lhs) > tf(rhs))
	case .F_Ge:
		value = i64(tf(lhs) >= tf(rhs))
	case .F_Add:
		value = ti(tf(lhs) + tf(rhs))
	case .F_Sub:
		value = ti(tf(lhs) - tf(rhs))
	case .F_Mul:
		value = ti(tf(lhs) * tf(rhs))
	case .F_Div:
		value = ti(tf(lhs) / tf(rhs))
	}
	return

	tf :: proc(i: i64) -> f64 {return transmute(f64)i}
	ti :: proc(i: f64) -> i64 {return transmute(i64)i}
}

builder_peep :: proc(
	ctx: backend.Peep_Ctx,
	node: backend.Expanded_Node,
	_: $T,
) -> Node_ID {
	node := node
	id := backend.graph_id(ctx, node)
	is_complete := backend.peep_ctx_graph_is_complete(ctx)

	DEAD_EXCEPTIONS := bit_set[backend.Ideal_Node_Type]{.Region, .Start}

	if backend.is_cfg(ctx, id) && node.itype not_in DEAD_EXCEPTIONS {
		idom := graph_expand(ctx, node.inps[0])
		if btype(idom) == .Dead {
			return node.inps[0]
		}
	}

	STORES := bit_set[backend.Ideal_Node_Type]{.Store, .Set, .Copy}

	emilinate_dead_local: if node.itype in STORES {
		base, _ := backend.base_and_offset(ctx, node.inps[2])
		bnode := graph_expand(ctx, base)
		if bnode.itype != .Local_Addr do break emilinate_dead_local
		if backend.graph_extra(ctx, bnode.inps[0], Local).size ==
		   backend.DEAD_LOCAL {
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

			slot_local := backend.graph_extra(ctx, slot, Local)
			if slot_local.size == backend.DEAD_LOCAL do break match

			iter: backend.Offset_Iter
			iter.curr = id
			for user in backend.offset_iter_next(ctx, &iter) {
				unode := graph_expand(ctx, user.id)
				if unode.itype in STORES && user.idx == 2 {
					continue
				}

				backend.peep_ctx_add_trigger(ctx, user.id, id)
				break mark_dead
			}

			slot_local.size = backend.DEAD_LOCAL

			iter = {}
			iter.curr = id
			for user in backend.offset_iter_next(ctx, &iter) {
				backend.worklist_add(ctx, ctx.worklist, user.id)
			}

			break match
		}

		forward: {
			if root.itype != .Mem do break forward

			forward_candidate: Node_ID
			rev_forward_candidate: Node_ID
			load_base: Node_ID
			op_count := 0

			iter: backend.Offset_Iter
			iter.curr = id
			for user in backend.offset_iter_next(ctx, &iter) {
				unode := graph_expand(ctx, user.id)
				op_count += 1

				if unode.itype == .Copy &&
				   user.idx == 2 &&
				   rev_forward_candidate == 0 {
					rev_forward_candidate = user.id
					continue
				}

				if unode.itype in STORES && user.idx == 2 {
					continue
				}

				if unode.itype == .Copy &&
				   user.idx == 3 &&
				   forward_candidate == 0 {
					forward_candidate = user.id
					continue
				}

				if unode.itype == .Load && load_base == 0 {
					load_base = unode.inps[1]
					continue
				}

				backend.peep_ctx_add_trigger(ctx, user.id, id)
				break forward
			}

			if load_base != 0 &&
			   (((load_base != rev_forward_candidate) &&
						   forward_candidate == 0) ||
					   forward_candidate != 0) {
				break forward
			}

			if forward_candidate != 0 {
				fnode := graph_expand(ctx, forward_candidate)

				bse, _ := backend.base_and_offset(ctx, fnode.inps[2])
				subs := graph_get(ctx, bse)

				VALID :: bit_set[backend.Ideal_Node_Type] {
					.Local_Addr,
					.Param,
					.Global_Addr,
				}
				if subs.itype not_in VALID {break forward}

				cursor := fnode.inps[1]
				op_count -= 1
				for op_count > 0 {
					cnode := graph_expand(ctx, cursor)
					if cnode.itype not_in STORES do break forward
					base, _ := backend.base_and_offset(ctx, cnode.inps[2])
					if base != id &&
					   !backend.is_noalias(ctx, cursor, forward_candidate) {
						backend.peep_ctx_add_trigger(ctx, cursor, id)
						break forward
					}
					cursor = cnode.inps[1]
					op_count -= int(base == id)
				}

				return fnode.inps[2]
			}

			fnode := graph_expand(ctx, rev_forward_candidate)
			if op_count == 2 {
				return fnode.inps[3]
			}
		}
	case .Loop:
		bedge := graph_expand(ctx, node.inps[1])
		if btype(bedge) == .Dead {
			#reverse for out in node.outs {
				onode := graph_expand(ctx, out.id)
				if onode.itype == .Phi {
					backend.graph_subsume(ctx, onode.inps[1], out.id)
				}
			}
			return node.inps[0]
		}
	case .Region:
		#reverse for inp, i in node.inps {
			inode := graph_expand(ctx, inp)
			if btype(inode) != .Dead do continue
			ordered_remove(ctx, &node, i)

			for out in node.outs {
				onode := graph_expand(ctx, out.id)
				if onode.itype == .Phi && len(onode.inps) > 2 {
					ordered_remove(ctx, &onode, i + 1)
				}
			}

			if node.input_count == 2 {
				break
			}
		}

		elim: if len(node.inps) == 2 {
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

			merge: #reverse for inp, i in slice.clone(node.inps) {
				inode := graph_expand(ctx, inp)
				if inode.itype != .Region do continue

				not_covered_count := phi_count
				for out in inode.outs {

					onode := graph_expand(ctx, out.id)
					if onode.itype == .Region do continue

					if onode.itype != .Phi {
						backend.peep_ctx_add_trigger(ctx, out.id, id)
						continue merge
					}
					if len(onode.outs) != 1 {
						for o in onode.outs {
							if o.id != id {
								backend.peep_ctx_add_trigger(ctx, o.id, id)
							}
						}
						continue merge
					}
					if backend.graph_inps(ctx, onode.outs[0].id)[0] != id {
						continue merge
					}

					not_covered_count -= 1
				}

				if not_covered_count != 0 {
					continue
				}

				prev_cached := node.inps[len(node.inps) - 1]
				node.input_count -= 1
				backend.graph_remove_output(
					ctx,
					prev_cached,
					{idx = len(node.inps) - 1, id = id},
					no_delete = true,
				)

				for iinp in inode.inps[1:len(inode.inps) - 1] {
					backend.graph_connect(ctx, id, iinp)
				}

				for out in node.outs {
					onode := graph_expand(ctx, out.id)
					if onode.itype != .Phi do continue

					to_merge := graph_expand(ctx, onode.inps[1 + i])
					assert(to_merge.itype == .Phi)

					for iinp in to_merge.inps[2:] {
						backend.graph_connect(ctx, out.id, iinp)
					}

					backend.graph_set_input(
						ctx,
						out.id,
						1 + i,
						to_merge.inps[1],
					)
				}

				backend.graph_connect(ctx, id, prev_cached)
				backend.graph_set_input(ctx, id, i, inode.inps[0])

				node = graph_expand(ctx, id)
				changed = true
			}
		}

		return 0
	case .Phi:
		ctrl := graph_expand(ctx, node.inps[0])

		if Builder_Node_Type(ctrl.rtype) == .Dead && 2 < len(node.inps) {
			ordered_remove(ctx, &node, 2)

			if node.rtype == backend.DEAD_NODE_KIND do break match
		}

		elimn: if len(node.inps) == 2 {
			for out in backend.graph_outs(ctx, node.inps[0]) {
				if graph_get(ctx, out.id).itype == .Return {
					break elimn
				}
			}
			return node.inps[1]
		}

		if 2 < len(node.inps) && node.inps[2] == id {
			return node.inps[1]
		}

		memcpify: if node.dt == .Void && ctrl.itype == .Loop {
			if len(ctrl.outs) != 3 do break memcpify

			els := graph_expand(ctx, ctrl.inps[1])
			if els.itype != .Else do break memcpify
			if len(els.outs) != 3 do break memcpify
			ifo := graph_expand(ctx, els.inps[0])
			if ifo.itype != .If do break memcpify

			cnd := graph_expand(ctx, ifo.inps[1])
			if cnd.itype != .Ge do break memcpify
			idx := graph_expand(ctx, cnd.inps[0])
			if idx.itype != .Phi do break memcpify
			if idx.inps[0] != node.inps[0] do break memcpify
			init := backend.graph_extra(ctx, idx.inps[1], CInt)
			if init == nil || init.value != 0 do break memcpify
			if len(idx.outs) > 4 do break memcpify

			add := graph_expand(ctx, idx.inps[2])
			if add.itype != .Add do break memcpify
			if add.inps[0] != cnd.inps[0] do break memcpify
			inc := graph_expand(ctx, add.inps[1])
			if inc.itype != .CInt do break memcpify
			if backend.graph_extra(ctx, inc, CInt).value != 1 {
				break memcpify
			}

			cnt := graph_expand(ctx, cnd.inps[1])

			store := graph_expand(ctx, node.inps[2])
			if store.itype != .Store do break memcpify
			if store.inps[1] != id do break memcpify

			load := graph_expand(ctx, store.inps[3])
			if load.itype != .Load do break memcpify
			if load.inps[1] != id do break memcpify

			factor: Node_ID

			src_cur := graph_expand(ctx, load.inps[2])
			if src_cur.itype != .Add do break memcpify
			src_cur_idx := graph_expand(ctx, src_cur.inps[1])
			if src_cur_idx.itype == .Mul {
				factor = src_cur_idx.inps[1]
				if src_cur_idx.inps[0] != cnd.inps[0] do break memcpify
			} else {
				if src_cur.inps[1] != cnd.inps[0] do break memcpify
			}

			dst_cur := graph_expand(ctx, store.inps[2])
			if dst_cur.itype != .Add do break memcpify
			dst_cur_idx := graph_expand(ctx, dst_cur.inps[1])
			if dst_cur_idx.itype == .Mul {
				if dst_cur_idx.inps[1] != factor do break memcpify
				if dst_cur_idx.inps[0] != cnd.inps[0] do break memcpify
			} else {
				if dst_cur.inps[1] != cnd.inps[0] do break memcpify
			}

			if factor != 0 {
				const := backend.graph_extra(ctx, factor, CInt)
				if const == nil ||
				   int(const.value) != backend.DT_SIZE[load.dt] {
					break memcpify
				}
			}

			src := src_cur.inps[0]
			dst := dst_cur.inps[0]
			count := cnd.inps[1]

			for out in node.outs {
				// NOTE: For now, free floating ops cancel this opt, and this
				// needs to be deferred to the loop elimination pass
				onode := graph_expand(ctx, out.id)
				if onode.inps[0] == 0 do break memcpify
			}

			pcount := 0
			for out in ctrl.outs {
				pcount += int(graph_get(ctx, out.id).itype == .Phi)
			}
			if pcount != 2 do break memcpify

			backend.worklist_add(ctx, ctx.worklist, els.inps[0])
			backend.graph_subsume(ctx, ctrl.inps[0], node.inps[0])
			backend.graph_subsume(ctx, ctrl.inps[0], ifo.outs[0].id)
			backend.graph_subsume(ctx, idx.inps[0], cnd.inps[0])

			if factor != 0 {
				count = backend.graph_add_bin_op(
					ctx,
					"cfc",
					.Mul,
					.I64,
					count,
					factor,
				)
				backend.worklist_add(ctx, ctx.worklist, count)
			}

			return backend.graph_add_copy(
				ctx,
				"lcpi",
				ctrl.inps[0],
				node.inps[1],
				dst,
				src,
				count,
			)
		}
	case .Then, .Else:
		if_ := graph_expand(ctx, node.inps[0])
		cond_const := backend.graph_extra(ctx, if_.inps[1], CInt)
		if cond_const != nil {
			if (cond_const.value == 0) ~ (node.itype == .Else) {
				return graph_add_dead(ctx, "dead")
			} else {
				return if_.inps[0]
			}
		} else {
			backend.peep_ctx_add_trigger(ctx, if_.inps[1], id)
		}
	case .Neg ..= .F_Demote:
		op := Un_Op(node.itype)
		oper := graph_expand(ctx.graph, node.inps[0])
		coper := backend.graph_extra(ctx.graph, oper, CInt)

		if coper != nil {
			value := fold_un_op(op, coper.value, node.dt, oper.dt)
			return backend.graph_add_c_int(ctx.graph, "fld", node.dt, value)
		}

		if (op == .Sext || op == .Uext) &&
		   backend.DT_SIZE[oper.dt] >= backend.DT_SIZE[node.dt] {
			return node.inps[0]
		}

		if op == .Cast && oper.dt == node.dt {
			return node.inps[0]
		}
	case .Add ..= .And_Not:
		lhs := graph_expand(ctx.graph, node.inps[0])
		rhs := graph_expand(ctx.graph, node.inps[1])

		clhs := backend.graph_extra(ctx.graph, lhs, CInt)
		crhs := backend.graph_extra(ctx.graph, rhs, CInt)
		op := Bin_Op(node.itype)

		if clhs != nil && crhs != nil {
			value := fold_bin_op(clhs.value, op, crhs.value, node.dt)
			return backend.graph_add_c_int(ctx.graph, "fld", node.dt, value)
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
				return backend.graph_add_c_int(ctx.graph, "sim0", .I64, 0)
			}

			SYMETRI_IS_ONE := bit_set[Bin_Op]{.Eq, .Le, .Ge, .U_Le, .U_Ge}
			if op in SYMETRI_IS_ONE {
				return backend.graph_add_c_int(ctx.graph, "sim1", .I64, 1)
			}
		}

		ASOCIATIVE := bit_set[Bin_Op]{.Add, .Mul, .And, .Or, .Xor, .And}

		if Bin_Op(lhs.itype) == op && op in ASOCIATIVE && crhs != nil {
			clhs_lhs := backend.graph_extra(ctx, lhs.inps[0], CInt)
			clhs_rhs := backend.graph_extra(ctx, lhs.inps[1], CInt)
			for clhs_rhs != nil && clhs_lhs == nil {
				res := backend.graph_add_bin_op(
					ctx.graph,
					"rsoc",
					backend.Bin_Op(op),
					node.dt,
					lhs.inps[0],
					backend.graph_add_c_int(
						ctx.graph,
						"rfld",
						node.dt,
						fold_bin_op(clhs_rhs.value, op, crhs.value, node.dt),
					),
				)
				backend.worklist_add(ctx, ctx.worklist, res)
				return res
			}

			if clhs_rhs == nil && clhs_lhs == nil {
				backend.peep_ctx_add_trigger(ctx, lhs.inps[1], id)
			}
		}

		COMUTATIVE_OR_SWAPPABLE :: bit_set[Bin_Op] {
			.Add,
			.Mul,
			.F_Add,
			.F_Mul,
			.Ne,
			.F_Ne,
			.Eq,
			.F_Eq,
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
			.F_Ge,
			.F_Lt,
			.F_Gt,
			.F_Le,
		}

		@(static, rodata)
		SWAPPABLE := #partial [Bin_Op]Bin_Op {
			.Ge   = .Le,
			.Lt   = .Gt,
			.Gt   = .Lt,
			.Le   = .Ge,
			.U_Ge = .U_Le,
			.U_Lt = .U_Gt,
			.U_Gt = .U_Lt,
			.U_Le = .U_Ge,
			.F_Ge = .F_Le,
			.F_Lt = .F_Gt,
			.F_Gt = .F_Lt,
			.F_Le = .F_Ge,
		}

		@(static, rodata)
		COMUTE_PRIORITY_TABLE := #partial [backend.Ideal_Node_Type]u8 {
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
				backend.graph_add_output(ctx, inp, id, 1 - i)
				backend.graph_remove_output(ctx, inp, {idx = i, id = id})
			}
			node.inps[0], node.inps[1] = node.inps[1], node.inps[0]
			backend.worklist_add(ctx, ctx.worklist, id)
			return id
		}
	case .Load:
		florward_loads: {
			cursor := node.inps[1]
			for {
				cnode := graph_expand(ctx, cursor)
				if cnode.itype != .Store do break
				if cnode.inps[0] != node.inps[0] do break
				if !backend.is_noalias(
					ctx,
					cnode.inps[2],
					node.inps[2],
					backend.DT_SIZE[graph_get(ctx, cnode.inps[3]).dt],
					backend.DT_SIZE[node.dt],
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
				backend.peep_ctx_add_trigger(ctx, cursor, id)
				if fnode.itype == .Store {
					backend.peep_ctx_add_trigger(ctx, fnode.inps[2], id)
					base, _ := backend.base_and_offset(ctx, fnode.inps[2])
					bnode := graph_expand(ctx, base)
					if bnode.itype == .Add {
						backend.peep_ctx_add_trigger(ctx, bnode.inps[1], id)
					}
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
			common_base, prev_offset := backend.base_and_offset(
				ctx,
				node.inps[2],
			)
			prev_offset += backend.DT_SIZE[graph_get(ctx, node.inps[3]).dt]
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
				if val.dt in backend.FLOAT_DTS do break
				val_const := backend.graph_extra(ctx, val, CInt)
				if val_const == nil do break
				base, offset := backend.base_and_offset(ctx, cnode.inps[2])
				if base != common_base do break
				if prev_offset - offset != backend.DT_SIZE[val.dt] do break
				if size + backend.DT_SIZE[val.dt] > SIZE_LIMIT do break

				size += backend.DT_SIZE[val.dt]
				bits := uint(backend.DT_SIZE[val.dt] * 8)
				vmask: i64 = i64(~uint(0) >> (64 - bits))
				imm <<= bits
				imm |= val_const.value & vmask

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
				return backend.graph_add_store(
					ctx,
					"cost",
					final.inps[0],
					final.inps[1],
					final.inps[2],
					backend.graph_add_c_int(
						ctx,
						"cocnst",
						backend.int_for_size(last_valid_size),
						last_valid_imm,
					),
				)
			}
		}

		eliminate: {
			fuel := 4

			cursor := id
			size := backend.mem_op_size(ctx, id) or_else panic("")
			base, off := backend.base_and_offset(ctx, node.inps[2])
			for {
				cnode := graph_expand(ctx, cursor)
				cursor = 0
				for out in cnode.outs {
					onode := graph_expand(ctx, out.id)
					if !onode.is_store ||
					   (onode.itype == .Copy &&
							   onode.inps[2] == onode.inps[3]) {
						backend.peep_ctx_add_trigger(ctx, out.id, id)
						break eliminate
					}
				}
				for out in cnode.outs {
					clobbered := true
					defer if clobbered {
						backend.peep_ctx_add_trigger(ctx, out.id, id)
					}

					onode := graph_expand(ctx, out.id)
					if backend.is_noalias(ctx, id, out.id) {
						if cursor != 0 do break eliminate
						cursor = out.id
						continue
					}
					if onode.itype == .Copy &&
					   backend.is_noalias(ctx, node.inps[2], onode.inps[3]) {}
					osize := backend.mem_op_size(
						ctx,
						out.id,
					) or_break eliminate
					obase, ooff := backend.base_and_offset(ctx, onode.inps[2])
					if base != obase {
						break eliminate
					}

					if ooff <= off && off + size <= ooff + osize {
						clobbered = false
						return node.inps[1]
					}

					break eliminate
				}

				if cursor == 0 do break
			}
		}
	case .Set:
		if !is_complete do break

		ctrl := node.inps[0]
		mm := node.inps[1]
		dst := graph_expand(ctx, node.inps[2])
		val := graph_expand(ctx, node.inps[3])
		val_const := backend.graph_extra(ctx, val, CInt)
		sze := graph_expand(ctx, node.inps[4])
		sze_const := backend.graph_extra(ctx, sze, CInt)

		if dst.itype != .Local_Addr do break
		if sze_const == nil do break

		if len(node.outs) == 1 {
			out := graph_expand(ctx, node.outs[0].id)
			if out.itype == .Copy &&
			   out.inps[0] == ctrl &&
			   out.inps[2] == node.inps[2] &&
			   out.inps[4] == node.inps[4] {
				return mm
			}
		}

		if val_const == nil do break
		if val_const.value != 0 do break

		dst_slot := graph_expand(ctx, dst.inps[0])

		Slot :: bit_field u64 {
			size:   int | 30,
			state:  enum uint {
				Uninit,
				Needs_Init,
				Inited,
			}    | 2,
			offset: int | 32,
		}

		Slots :: [dynamic; 16]Slot

		slots: Slots
		dst_size := int(backend.graph_extra(ctx, dst_slot, Local).size)

		members: [dynamic; 32]Node_ID

		iter: backend.Offset_Iter
		iter.curr = node.inps[2]
		corrupt := false
		scan: for out in backend.offset_iter_next(ctx, &iter) {
			onode := graph_expand(ctx, out.id)

			if out.id == id do continue
			if out.idx != 2 do continue

			size := backend.mem_op_size(ctx, out.id) or_continue
			assert(size != 0)

			if size > dst_size {
				break match
			}

			end := iter.offset + size
			offset := iter.offset

			if end > dst_size {
				break match
			}

			AUX :: bit_set[backend.Ideal_Node_Type]{.Load}

			#reverse for &slot, i in slots {
				send := slot.offset + slot.size
				if end <= slot.offset || send <= offset {
					continue
				}

				iter_is_inside := slot.offset <= offset && end <= send
				slot_is_inside := offset <= slot.offset && send <= end
				start_matches := offset == slot.offset
				end_matches := send == end

				corrupt |= !iter_is_inside && !slot_is_inside
				corrupt |= !start_matches && !end_matches

				if onode.itype not_in AUX {
					corrupt |= append(&members, out.id) == 0
				}

				if iter_is_inside && slot_is_inside {
				} else if slot_is_inside {
					if start_matches do offset = send
					size -= slot.size
					continue
				} else if iter_is_inside {
					if start_matches do slot.offset = end
					slot.size -= size
					continue
				}

				continue scan
			}

			if onode.itype not_in AUX {
				corrupt |= append(&members, out.id) == 0
			}

			slot := Slot {
				offset = offset,
				size   = size,
			}
			corrupt |= append(&slots, slot) == 0
		}

		if corrupt {
			for m in members {
				backend.peep_ctx_add_trigger(ctx, m, id)
			}
			break match
		}

		blocker: Node_ID
		cursor := id
		traverse: for {
			cnode := graph_expand(ctx, cursor)

			cursor = 0
			offset: int

			for out in cnode.outs {
				onode := graph_expand(ctx, out.id)

				ALLOWED := bit_set[backend.Ideal_Node_Type] {
					.Store,
					.Load,
					.Set,
					.Copy,
				}

				blocker = out.id

				if onode.itype not_in ALLOWED do break traverse

				base, off := backend.base_and_offset(ctx, onode.inps[2])
				if base != node.inps[2] do break traverse

				#partial switch onode.itype {
				case .Store, .Set, .Copy:
					if cursor != 0 do break traverse
					cursor = out.id
					offset = off
				case .Load:
					for &slot in slots {
						if slot.offset == off {
							assert(slot.size == backend.DT_SIZE[onode.dt])
							if slot.state == .Uninit {
								slot.state = .Needs_Init
							}
							break
						}
					}
				case:
					fmt.panicf("%v", onode.itype)
				}

				blocker = 0
			}

			if cursor == 0 do break
			size := backend.mem_op_size(ctx, cursor) or_else panic("")
			end := offset + size
			for &slot in slots {
				send := slot.offset + slot.size
				if offset <= slot.offset && send <= end {
					if slot.state == .Uninit {
						slot.state = .Inited
					}
				}
			}
		}

		sort.quick_sort(slots[:])

		align_of :: proc(offset: int) -> int {
			if offset == 0 do return MAX_STORE_UNIT
			return 1 << uint(intrinsics.count_trailing_zeros(offset))
		}

		MAX_STORE_UNIT :: 16

		align := min(align_of(dst_size), MAX_STORE_UNIT)
		assert(align != 0)

		offset := dst_size
		prev_len := len(slots)
		for i in 0 ..= prev_len {
			slot := i == prev_len ? Slot{} : slots[prev_len - i - 1]

			fmt.assertf(
				offset >= slot.offset,
				"%v, %v, %#v",
				offset,
				slot,
				slots,
			)
			rev_offset := slot.offset + slot.size
			inserts := 0
			for rev_offset < offset {
				gap := offset - rev_offset
				current_align := min(align, align_of(rev_offset))
				assert(current_align != 0)
				fill := Slot {
					size   = min(current_align, gap),
					offset = rev_offset,
				}
				assert(math.is_power_of_two(fill.size))
				rev_offset += fill.size
				if len(slots) >= cap(slots) {
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

		if len(slots) > 0 {
			keep = 0
			for &slot in slots[1:] {
				curr := &slots[keep]

				if slot.offset == curr.offset + curr.size &&
				   math.is_power_of_two(curr.size + slot.size) {
					curr.size += slot.size
				} else {
					keep += 1
					slots[keep] = slot
				}
			}
			resize(&slots, keep + 1)

			for i in 0 ..< len(slots) {
				for {
					curr := &slots[i]
					if curr.size <= MAX_STORE_UNIT do break
					new_slot := Slot {
						size   = curr.size - MAX_STORE_UNIT,
						state  = .Needs_Init,
						offset = curr.offset + MAX_STORE_UNIT,
					}
					assert(math.is_power_of_two(new_slot.size))
					curr.size = MAX_STORE_UNIT
					if !inject_at(&slots, i, new_slot) {
						break match
					}
				}
			}

			for i := 0; i < len(slots); i += 1 {
				slot := &slots[i]
				for !math.is_power_of_two(slot.size) {
					chip := min(align_of(slot.offset), slot.size)
					inject_at(
						&slots,
						i + 1,
						Slot {
							offset = slot.offset + chip,
							size = slot.size - chip,
						},
					)
					slot.size = chip
				}
			}
		}

		if len(slots) >= 5 {
			backend.peep_ctx_add_trigger(ctx, blocker, id)
			break match
		}

		mem_thread := mm
		for slot in slots {
			fmt.assertf(
				math.is_power_of_two(slot.size),
				"%v %#v",
				slot.size,
				slots,
			)
			idx := intrinsics.count_trailing_zeros(slot.size)
			table := [?]backend.Node_Datatype{.I8, .I16, .I32, .I64, .V128}
			dt := table[idx]
			vl := backend.graph_add_c_int(ctx, "zrsp", dt, 0)
			off := backend.graph_add_c_int(
				ctx,
				"zroffv",
				.I64,
				i64(slot.offset),
			)
			dst := backend.graph_add_bin_op(
				ctx,
				"zroff",
				.Add,
				.I64,
				node.inps[2],
				off,
			)
			backend.worklist_add(ctx, ctx.worklist, dst)
			mem_thread = backend.graph_add_store(
				ctx,
				"zrst",
				ctrl,
				mem_thread,
				dst,
				vl,
			)
			backend.worklist_add(ctx, ctx.worklist, mem_thread)
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
	ctx: backend.PS_Peep_Ctx,
	node: backend.Expanded_Node,
	_: $T,
) -> Node_ID {
	return 0
}

builder_emit_function :: proc(
	ectx: backend.Codegen_Emit_Ctx,
) -> backend.Codegen_Output {

	return {}
}
