package backend

import "base:intrinsics"
import "base:runtime"
import "core:container/queue"
import "core:fmt"
import "core:log"
import "core:math"
import "core:slice"
import "core:sort"

when !GEN_SPEC {
	sext :: proc(oper: i64, ty: Node_Datatype) -> (value: i64) {
		bit_size := uint(DT_SIZE[ty] * 8)
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
		dst_ty: Node_Datatype,
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
		case .Cast:
			value = oper &~ (-1 << uint(DT_SIZE[dst_ty] * 8))
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
		ty: Node_Datatype,
	) -> (
		value: i64,
	) {
		switch op {
		case .Add:
			value = lhs + rhs
		case .Sub:
			value = lhs - rhs
		case .Mul:
			value = lhs * rhs
		case .Div:
			value = sext(lhs, ty) / sext(rhs, ty)
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
			value = sext(lhs << u64(rhs), ty)
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

}

builder_peep :: proc(ctx: Peep_Ctx, node: Expanded_Node, _: $T) -> Node_ID {
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
				if base != id && !is_noalias(ctx, cursor, forward_candidate) {
					peep_ctx_add_trigger(ctx, cursor, id)
					break forward
				}
				cursor = cnode.inps[1]
				op_count -= int(base == id)
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

				prev_cached := node.inps[len(node.inps) - 1]
				node.input_count -= 1
				graph_remove_output(
					ctx,
					prev_cached,
					{idx = len(node.inps) - 1, id = id},
					no_delete = true,
				)

				for iinp in inode.inps[1:len(inode.inps) - 1] {
					graph_connect(ctx, id, iinp)
				}

				for out in node.outs {
					onode := graph_expand(ctx, out.id)
					if onode.itype != .Phi do continue

					to_merge := graph_expand(ctx, onode.inps[1 + i])
					assert(to_merge.itype == .Phi)

					for iinp in to_merge.inps[2:] {
						graph_connect(ctx, out.id, iinp)
					}

					graph_set_input(ctx, out.id, 1 + i, to_merge.inps[1])
				}

				graph_connect(ctx, id, prev_cached)
				graph_set_input(ctx, id, i, inode.inps[0])

				node = graph_expand(ctx, id)
				changed = true
			}
		}

		return 0
	case .Phi:
		if graph_get(ctx, node.inps[0]).btype == .Dead && 2 < len(node.inps) {
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
	case .Neg ..= .F_Demote:
		op := Un_Op(node.itype)
		oper := graph_expand(ctx.graph, node.inps[0])
		coper := graph_extra(ctx.graph, oper, CInt)

		if coper != nil {
			value := fold_un_op(op, coper.value, node.dt, oper.dt)
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
			value := fold_bin_op(clhs.value, op, crhs.value, node.dt)
			return graph_add_c_int(ctx.graph, "fld", node.dt, value)
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
				.Ne,
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
						fold_bin_op(clhs_rhs.value, op, crhs.value, node.dt),
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
			.Lt   = .Lt,
			.Gt   = .Gt,
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
					DT_SIZE[node.dt],
					DT_SIZE[graph_get(ctx, cnode.inps[3]).dt],
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
				if val.dt in FLOAT_DTS do break
				val_const := graph_extra(ctx, val, CInt)
				if val_const == nil do break
				base, offset := base_and_offset(ctx, cnode.inps[2])
				if base != common_base do break
				if prev_offset - offset != DT_SIZE[val.dt] do break
				if size + DT_SIZE[val.dt] > SIZE_LIMIT do break

				size += DT_SIZE[val.dt]
				bits := uint(DT_SIZE[val.dt] * 8)
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
		mm := node.inps[1]
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
		dst_size := int(graph_extra(ctx, dst_slot, Local).size)

		members: [dynamic; 32]Node_ID

		iter: Offset_Iter
		iter.curr = node.inps[2]
		corrupt := false
		scan: for out in offset_iter_next(ctx, &iter) {
			onode := graph_expand(ctx, out.id)

			if out.id == id do continue
			if out.idx != 2 do continue

			size := mem_op_size(ctx, out.id) or_continue
			assert(size != 0)

			if size > dst_size {
				break match
			}

			end := iter.offset + size
			offset := iter.offset

			if end > dst_size {
				break match
			}

			AUX :: bit_set[Ideal_Node_Type]{.Load_S, .Load}

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
				peep_ctx_add_trigger(ctx, m, id)
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

				ALLOWED := bit_set[Ideal_Node_Type] {
					.Store,
					.Load,
					.Load_S,
					.Set,
					.Copy,
				}

				blocker = out.id

				if onode.itype not_in ALLOWED do break traverse

				base, off := base_and_offset(ctx, onode.inps[2])
				if base != node.inps[2] do break traverse

				#partial switch onode.itype {
				case .Store, .Set, .Copy:
					if cursor != 0 do break traverse
					cursor = out.id
					offset = off
				case .Load, .Load_S:
					for &slot in slots {
						if slot.offset == off {
							assert(slot.size == DT_SIZE[onode.dt])
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
			size := mem_op_size(ctx, cursor) or_else panic("")
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

		MAX_STORE_UNIT :: 8

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
				assert(fill.size != 0)
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

				if slot.offset == curr.offset + curr.size {
					curr.size += slot.size
				} else {
					keep += 1
					slots[keep] = slot
				}
			}
			resize(&slots, keep + 1)

			for {
				curr := &slots[len(slots) - 1]
				if curr.size <= MAX_STORE_UNIT do break
				new_slot := Slot {
					size   = curr.size - MAX_STORE_UNIT,
					state  = .Needs_Init,
					offset = curr.offset + MAX_STORE_UNIT,
				}
				curr.size = MAX_STORE_UNIT
				append(&slots, new_slot)
			}
		}

		if len(slots) >= 5 {
			peep_ctx_add_trigger(ctx, blocker, id)
			break match
		}

		mem_thread := mm
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
	_: $T,
) -> Node_ID {
	return 0
}
