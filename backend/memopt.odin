package backend

import "../vendored/gam/util/arna"
import "core:container/queue"
import "core:fmt"
import "core:mem"
import "core:slice"

memopt :: proc(graph: ^Graph) -> (optimized: bool) {
	assert(graph.node_spec == &SPECS[.Builder])

	if .MemOpt not_in graph.opt_flags do return
	defer graph.peeped &= !optimized

	context.allocator, _ = arna.scrath()

	emem := find_node(graph, .Mem) or_return

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
	}

	Edit_Slot :: struct {
		prev: u32,
		node: Node_ID,
	}

	Value_Entry :: bit_field u32 {
		node:    Node_ID | 31,
		is_loop: bool    | 1,
	}

	Ctx :: struct {
		using graph:       ^Graph,
		slot_count:        u32,
		deleted_lazy_phys: [dynamic]Node_ID,
		joins:             [dynamic]Join,
		loops:             [dynamic]Loop,
		scope:             []Value_Entry,
		slot_idx:          []u32,
	}

	Loop :: struct {
		scope:     []Value_Entry,
		loop_node: Node_ID,
		done:      bool,
	}

	Join :: struct {
		entries: [][]Value_Entry,
		filled:  int,
	}

	edit_node_id :: proc(ctx: ^Ctx, id: Node_ID, new: u32) {
		node := graph_get(ctx, id)
		ctx.slot_idx[node.gvn] = new + 1
	}

	get_edited_node_idx :: proc(ctx: ^Ctx, node: ^Node) -> (u32, bool) {
		return ctx.slot_idx[node.gvn] - 1, ctx.slot_idx[node.gvn] != 0
	}

	ctx: Ctx
	ctx.graph = graph
	ctx.slot_idx = make([]u32, graph.gvn)
	ctx.graph.dont_delete = true

	collect_rename_slot: for mout in graph_outs(graph, emem) {
		mnode := graph_expand(graph, mout.id)
		if mnode.itype != .Local do continue

		assert(len(mnode.outs) == 1)

		iter: Offset_Iter
		iter.curr = mnode.outs[0].id
		for op in offset_iter_next(graph, &iter) {
			if iter.offset != 0 do continue collect_rename_slot
			if op.idx != 2 do continue collect_rename_slot
			mem_op_size(graph, op.id) or_continue collect_rename_slot
		}

		iter = {}
		iter.curr = mnode.outs[0].id
		for op in offset_iter_next(graph, &iter) {
			edit_node_id(&ctx, op.id, ctx.slot_count)
		}
		ctx.slot_count += 1
	}

	ctx.scope = make([]Value_Entry, ctx.slot_count)
	if ctx.slot_count != 0 do walk_thread(&ctx, emem)

	ctx.dont_delete = false

	for phi in ctx.deleted_lazy_phys {
		if graph_get(graph, phi).rtype == DEAD_NODE_KIND do continue
		graph_subsume(graph, graph_inps(graph, phi)[1], phi)
	}

	if !ODIN_DISABLE_ASSERT {
		wl: queue.Queue(Node_ID)
		queue.init(&wl, int(graph.gvn))
		collect_nodes(graph, &wl)

		for n in wl.data[:wl.len] {
			node := graph_expand(graph, n)
			node.in_worklist = false
			fmt.assertf(u16(node.itype) < len(IDEAL_CLASSES), "%v", node.node)
		}
	}

	return true

	walk_thread :: proc(ctx: ^Ctx, thread: Node_ID) {
		cursor := thread
		for {
			cnode := graph_expand(ctx, cursor)
			pcursor := cursor
			cursor = 0

			assert(len(ctx.scope) == int(ctx.slot_count))

			#partial switch cnode.itype {
			case .Store:
				id := get_edited_node_idx(ctx, cnode) or_break
				slot := &ctx.scope[id]
				slot^ = Value_Entry(cnode.inps[3])
			case .Call:
				assert(len(cnode.outs) == 1)
				cursor = cnode.outs[0].id
				cursor = find_node(ctx, .Mem, cursor) or_else panic("")
				continue
			case .Mem, .Set, .Copy, .Phi, .Return:
			case:
				fmt.panicf("%v", cnode.node)
			}

			outs: [dynamic]Node_Output
			for cout in slice.clone(cnode.outs) {
				conode := graph_expand(ctx, cout.id)
				#partial switch conode.itype {
				case .Load, .Load_S:
					id := get_edited_node_idx(ctx, conode) or_break
					value := get_scope_value(ctx, ctx.scope, id)
					graph_subsume(ctx, value, cout.id)
				case .Store, .Call, .Set, .Copy, .Return, .Phi:
					append(&outs, cout)
				}
			}

			cnode = graph_expand(ctx, pcursor)

			original_scope := ctx.scope

			for cout, i in outs {
				last := i == len(outs) - 1

				if last {
					cursor = cout.id
					ctx.scope = original_scope
				} else {
					ctx.scope = slice.clone(original_scope)
				}

				conode := graph_expand(ctx, cout.id)
				#partial switch conode.itype {
				case .Local:
				case .Load, .Load_S:
				case .Phi:
					reg := graph_get(ctx, conode.inps[0])

					if reg.itype == .Region {
						id, ok := get_edited_node_idx(ctx, conode)
						if !ok {
							id = u32(len(ctx.joins))
							edit_node_id(ctx, cout.id, id)
							entries := make(
								[][]Value_Entry,
								len(conode.inps) - 1,
							)
							append(&ctx.joins, Join{entries, 0})
						}

						join := &ctx.joins[id]

						join.entries[cout.idx - 1] = ctx.scope

						join.filled += 1
						if join.filled < len(join.entries) {
							cursor = 0
							break
						}

						sloter := make([]Value_Entry, len(join.entries) + 1)
						sloter[0] = Value_Entry(conode.inps[0])
						next_scope := join.entries[0]
						for i in 0 ..< ctx.slot_count {
							res, dirty := Value_Entry{}, false
							for &v, j in sloter[1:] {
								vl := join.entries[j][i]
								v = vl
								if res == {} do res = vl
								dirty |= vl != res
							}

							if dirty {
								res, dirty = {}, false
								for &v, j in sloter[1:] {
									v = Value_Entry(
										get_scope_value(
											ctx,
											join.entries[j],
											i,
										),
									)
									if res == {} do res = v
									dirty |= v != res
								}
							}

							if dirty {
								push_node_name(ctx, "srphi")
								res = Value_Entry(
									graph_add_raw(
										ctx,
										u16(Ideal_Node_Type.Phi),
										graph_get(ctx, res.node).dt,
										mem.slice_data_cast([]Node_ID, sloter),
									),
								)
							}

							next_scope[i] = res
						}
						ctx.scope = next_scope
					} else if reg.itype == .Loop {
						id, ok := get_edited_node_idx(ctx, conode)
						if !ok {
							id = u32(len(ctx.loops))
							edit_node_id(ctx, cout.id, id)

							loop_scope := slice.clone(ctx.scope)
							scope := make([]Value_Entry, ctx.slot_count)
							slice.fill(
								scope,
								Value_Entry {
									node = Node_ID(id),
									is_loop = true,
								},
							)

							append(
								&ctx.loops,
								Loop{loop_scope, conode.inps[0], false},
							)

							ctx.scope = scope
						} else {
							loop := &ctx.loops[id]
							backedge := ctx.scope

							for i in 0 ..< ctx.slot_count {
								init := loop.scope[i]
								bnode := &backedge[i]
								if init.is_loop do continue

								inode := graph_expand(ctx, init.node)
								if inode.btype != .Lazy_Phi do continue

								for bnode.is_loop {
									loop := ctx.loops[bnode.node]
									if !loop.done || id == u32(bnode.node) {
										break
									}
									bnode^ = loop.scope[i]
								}

								if bnode.is_loop || init == bnode^ {
									append(&ctx.deleted_lazy_phys, init.node)
									graph_subsume(
										ctx,
										inode.inps[1],
										init.node,
									)
								} else {
									graph_connect(ctx, init.node, bnode.node)
									inode.itype = .Phi
									graph_intern(ctx, init.node)
								}
							}

							loop.done = true

							ctx.scope = {}
							cursor = 0

							break
						}
					} else do panic("")

					fallthrough
				case .Store, .Call, .Set, .Copy, .Return:
					if !last {
						walk_thread(ctx, cout.id)
					}
				case:
					fmt.panicf("%v", conode.node)
				}

			}

			get_scope_value :: proc(
				ctx: ^Ctx,
				scope: []Value_Entry,
				#any_int idx: int,
			) -> Node_ID {
				val := scope[idx].node
				if scope[idx].is_loop {
					loop := &ctx.loops[val]
					val = get_scope_value(ctx, loop.scope, idx)
					vnode := graph_expand(ctx, val)
					if (vnode.btype != .Lazy_Phi ||
						   vnode.inps[0] != loop.loop_node) &&
					   !loop.done {
						assert(
							vnode.itype != .Phi ||
							vnode.inps[0] != loop.loop_node,
						)
						val = graph_add_lazy_phi(
							ctx,
							"srlphi",
							vnode.dt,
							loop.loop_node,
							val,
						)
						loop.scope[idx] = Value_Entry(val)
					}

					scope[idx] = Value_Entry(val)
				}
				return val
			}

			if cursor == 0 do break

			assert(len(ctx.scope) == int(ctx.slot_count))
		}
	}
}
