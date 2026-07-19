package builder

import backend ".."
import "../../vendored/gam/util/arna"
import "core:container/queue"
import "core:fmt"
import "core:mem"
import "core:slice"

memopt :: proc(graph: ^backend.Graph) -> (optimized: bool) {
	assert(graph.node_spec == &SPEC)

	if .Mem_Opt not_in graph.opt_flags do return
	defer graph.peeped &= !optimized

	context.allocator, _ = arna.scrath()

	emem := backend.graph_find_node(graph, .Mem) or_return

	sroa: for mout in backend.graph_outs(graph, emem) {
		mnode := backend.graph_expand(graph, mout.id)
		if mnode.itype != .Local do continue

		slot_size := backend.graph_extra(graph, mnode, backend.Local).size

		assert(len(mnode.outs) == 1)
		local_addr := backend.graph_expand(graph, mnode.outs[0].id)

		assert(local_addr.itype == .Local_Addr)

		Slot :: struct {
			start: i32,
			end:   i32,
			local: backend.Node_ID,
		}

		slots: [dynamic; 8]Slot

		iter: backend.Offset_Iter
		iter.curr = mnode.outs[0].id
		collect_slot: for out in backend.offset_iter_next(graph, &iter) {
			size := backend.mem_op_size(graph, out.id) or_continue sroa
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
			local := backend.graph_add_local(graph, "sroal", emem)
			backend.graph_extra(graph, local, backend.Local).size = slot.end - slot.start
			slot.local = backend.graph_add_local_addr(graph, "sroadr", local)
		}

		Op :: struct {
			local: backend.Node_ID,
			id:    backend.Node_ID,
		}

		ops: [dynamic]Op

		iter = {}
		iter.curr = mnode.outs[0].id
		for out in backend.offset_iter_next(graph, &iter) {
			for &slt, i in slots {
				if int(slt.start) == iter.offset {
					append(&ops, Op{slt.local, out.id})
					break
				}
			}
		}

		for op in ops {
			backend.graph_set_input(graph, op.id, 2, op.local)
		}
	}

	Edit_Slot :: struct {
		prev: u32,
		node: backend.Node_ID,
	}

	Value_Entry :: bit_field u32 {
		node:    backend.Node_ID | 31,
		is_loop: bool    | 1,
	}

	Ctx :: struct {
		using graph:       ^backend.Graph,
		slot_count:        u32,
		deleted_lazy_phys: [dynamic]backend.Node_ID,
		joins:             [dynamic]Join,
		loops:             [dynamic]Loop,
		scope:             []Value_Entry,
		slot_idx:          []u32,
	}

	Loop :: struct {
		scope:     []Value_Entry,
		loop_node: backend.Node_ID,
		done:      bool,
	}

	Join :: struct {
		entries: [][]Value_Entry,
		filled:  int,
	}

	edit_node_id :: proc(ctx: ^Ctx, id: backend.Node_ID, new: u32) {
		node := backend.graph_get(ctx, id)
		ctx.slot_idx[node.gvn] = new + 1
	}

	get_edited_node_idx :: proc(ctx: ^Ctx, node: ^backend.Node) -> (u32, bool) {
		return ctx.slot_idx[node.gvn] - 1, ctx.slot_idx[node.gvn] != 0
	}

	ctx: Ctx
	ctx.graph = graph
	ctx.slot_idx = make([]u32, graph.gvn)
	ctx.graph.dont_delete = true

	collect_rename_slot: for mout in backend.graph_outs(graph, emem) {
		mnode := backend.graph_expand(graph, mout.id)
		if mnode.itype != .Local do continue

		assert(len(mnode.outs) == 1)

		iter: backend.Offset_Iter
		iter.curr = mnode.outs[0].id
		for op in backend.offset_iter_next(graph, &iter) {
			if iter.offset != 0 do continue collect_rename_slot
			if op.idx != 2 do continue collect_rename_slot
			backend.mem_op_size(graph, op.id) or_continue collect_rename_slot
		}

		iter = {}
		iter.curr = mnode.outs[0].id
		for op in backend.offset_iter_next(graph, &iter) {
			edit_node_id(&ctx, op.id, ctx.slot_count)
		}
		ctx.slot_count += 1
	}

	ctx.scope = make([]Value_Entry, ctx.slot_count)
	if ctx.slot_count != 0 do walk_thread(&ctx, emem)

	ctx.dont_delete = false

	for phi in ctx.deleted_lazy_phys {
		if backend.graph_get(graph, phi).rtype == backend.DEAD_NODE_KIND do continue
		backend.graph_subsume(graph, backend.graph_inps(graph, phi)[1], phi)
	}

	if !ODIN_DISABLE_ASSERT {
		wl: queue.Queue(backend.Node_ID)
		queue.init(&wl, int(graph.gvn))
		backend.collect_nodes(graph, &wl)

		for n in wl.data[:wl.len] {
			node := backend.graph_expand(graph, n)
			node.in_worklist = false
			fmt.assertf(u16(node.itype) < len(backend.IDEAL_CLASSES), "%v", node.node)
		}
	}

	return true

	walk_thread :: proc(ctx: ^Ctx, thread: backend.Node_ID) {
		cursor := thread
		for {
			cnode := backend.graph_expand(ctx, cursor)
			pcursor := cursor
			cursor = 0

			assert(len(ctx.scope) == int(ctx.slot_count))

			#partial switch cnode.itype {
			case .Store:
				id := get_edited_node_idx(ctx, cnode) or_break
				slot := &ctx.scope[id]
				slot^ = Value_Entry(cnode.inps[3])
				assert(slot^ != {})
			case .Call:
				assert(len(cnode.outs) == 1)
				cursor = cnode.outs[0].id
				cursor = backend.graph_find_node(ctx, .Mem, cursor) or_else panic("")
				continue
			case .Mem, .Set, .Copy, .Phi, .Return:
			case:
				fmt.panicf("%v", cnode.node)
			}

			outs: [dynamic]backend.Node_Output
			for cout in slice.clone(cnode.outs) {
				conode := backend.graph_expand(ctx, cout.id)
				#partial switch conode.itype {
				case .Load, .Load_S:
					id := get_edited_node_idx(ctx, conode) or_break
					value := get_scope_value(ctx, ctx.scope, id)
					backend.graph_subsume(ctx, value, cout.id)
				case .Store, .Call, .Set, .Copy, .Return, .Phi:
					append(&outs, cout)
				}
			}

			cnode = backend.graph_expand(ctx, pcursor)

			original_scope := ctx.scope

			for cout, i in outs {
				last := i == len(outs) - 1

				if last {
					cursor = cout.id
					ctx.scope = original_scope
				} else {
					ctx.scope = slice.clone(original_scope)
				}

				conode := backend.graph_expand(ctx, cout.id)
				#partial switch conode.itype {
				case .Local:
				case .Load, .Load_S:
				case .Phi:
					reg := backend.graph_get(ctx, conode.inps[0])

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
								backend.push_node_name(ctx, "srphi")
								res = Value_Entry(
									backend.graph_add_raw(
										ctx,
										u16(backend.Ideal_Node_Type.Phi),
										backend.graph_get(ctx, res.node).dt,
										mem.slice_data_cast([]backend.Node_ID, sloter),
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
							for &s, i in scope {
								if loop_scope[i] != {} {
									s = Value_Entry {
										node    = backend.Node_ID(id),
										is_loop = true,
									}
								}
							}

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
								if init.node == 0 do continue

								inode := backend.graph_expand(ctx, init.node)
								if btype(inode) != .Lazy_Phi do continue

								for bnode.is_loop {
									loop := ctx.loops[bnode.node]
									if !loop.done || id == u32(bnode.node) {
										break
									}
									bnode^ = loop.scope[i]
								}

								if bnode.is_loop || init == bnode^ {
									append(&ctx.deleted_lazy_phys, init.node)
									backend.graph_subsume(
										ctx,
										inode.inps[1],
										init.node,
									)
								} else {
									backend.graph_connect(ctx, init.node, bnode.node)
									inode.itype = .Phi
									backend.graph_intern(ctx, init.node)
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
			) -> backend.Node_ID {
				val := scope[idx].node
				if scope[idx].is_loop {
					loop := &ctx.loops[val]
					val = get_scope_value(ctx, loop.scope, idx)
					vnode := backend.graph_expand(ctx, val)
					if (btype(vnode) != .Lazy_Phi ||
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
