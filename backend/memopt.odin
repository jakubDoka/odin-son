package backend

import "../vendored/gam/util/arna"
import "core:log"

memopt :: proc(graph: ^Graph) -> (ok: bool) {
	if .MemOpt not_in graph.opt_flags do return

	context.allocator, _ = arna.scrath()

	emem := find_entry_node(graph, .Mem) or_return

	sroa: for mout in graph_outs(graph, emem) {
		mnode := graph_expand(graph, mout.id)
		if mnode.itype != .Local do continue

		slot_size := graph_extra(graph, mnode, Local).size

		assert(len(mnode.outs) == 1)
		local_addr := graph_expand(graph, mnode.outs[0].id)

		assert(local_addr.itype == .Local_Addr)

		Slot :: struct {
			start: i32,
			end:   i32,
			local: Node_ID,
		}

		slots: [dynamic; 8]Slot

		iter: Offset_Iter
		iter.curr = mnode.outs[0].id
		collect_slot: for out in offset_iter_next(graph, &iter) {
			size := mem_op_size(graph, out.id) or_continue sroa
			if i32(iter.offset + size) > slot_size do continue sroa
			if out.idx != 2 do continue sroa

			new_slot := Slot {
				start = i32(iter.offset),
				end   = i32(iter.offset + size),
			}

			for slot in slots {
				if slot.end <= new_slot.start || new_slot.end <= slot.start {
					continue
				}

				if slot != new_slot do continue sroa

				continue collect_slot
			}

			if append(&slots, new_slot) == 0 {
				continue sroa
			}
		}

		if len(slots) == 1 do continue

		for &slot in slots {
			local := graph_add_local(graph, "sroal", emem)
			graph_extra(graph, local, Local).size = slot.end - slot.start
			slot.local = graph_add_local_addr(graph, "sroadr", local)
		}

		Op :: struct {
			local: Node_ID,
			id:    Node_ID,
		}

		ops: [dynamic]Op

		iter = {}
		iter.curr = mnode.outs[0].id
		for out in offset_iter_next(graph, &iter) {
			for &slt, i in slots {
				if int(slt.start) == iter.offset {
					append(&ops, Op{slt.local, out.id})
					break
				}
			}
		}

		for op in ops {
			graph_set_input(graph, op.id, 2, op.local)
		}

		//log.error(slots)
	}

	return true
}
