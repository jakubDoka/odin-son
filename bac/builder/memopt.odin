package builder

import bac ".."
import "../../vendored/gam/util/arna"
import "core:fmt"
import "core:mem"
import "core:slice"

Local :: bac.Local
Node_ID :: bac.Node_ID
expand_node :: bac.expand_node

memopt :: proc(graph: ^bac.Proc) -> (optimized: bool) {
	assert(graph.node_spec == &SPEC)

	if .Mem_Opt not_in graph.opt_flags do return
	defer graph.peeped &= !optimized

	context.allocator, _ = arna.scrath()

	bac.verify(graph)

	Edit_Slot :: struct {
		prev: u32,
		node: Node_ID,
	}

	Value_Entry :: bit_field u32 {
		node:    Node_ID | 31,
		is_loop: bool    | 1,
	}

	Merge :: struct {
		seen_cnt: int,
	}

	Ctx :: struct {
		using graph:       ^bac.Proc,
		deleted_lazy_phys: [dynamic]Node_ID,
		joins:             [dynamic]Join,
		loops:             [dynamic]Loop,
		merges:            [dynamic]Merge,
		threads_start:     u32,
		scope:             []Value_Entry,
		slot_idx:          []u32,
		split_slot:        ^Split_Slot,
	}

	Split_Slot :: struct {
		prev:  ^Split_Slot,
		scope: []Value_Entry,
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

	ctx: Ctx
	ctx.graph = graph
	ctx.slot_idx = make([]u32, graph.gvn)
	ctx.graph.dont_delete = true

	threads: [dynamic]Node_ID

	emem := bac.find_node(graph, .Mem)

	sroad := 0
	total := 0
	mismatches := 0
	rename_slot_count: u32
	sroa: for mout in bac.get_outputs(graph, emem) {
		mnode := expand_node(graph, mout.id)
		if mnode.itype != .Local do continue

		can_split := true

		total += 1

		slot_size := bac.get_extra(graph, mnode, Local).size

		assert(len(mnode.outs) == 1)
		local_addr := expand_node(graph, mnode.outs[0].id)

		assert(local_addr.itype == .Local_Addr)

		Slot :: struct {
			start: i32,
			end:   i32,
			local: Node_ID,
		}

		slots: [dynamic; 8]Slot

		failed_sroa := false
		failed_split := false

		iter: bac.Offset_Iter
		iter.curr = mnode.outs[0].id
		collect_slot: for out in bac.offset_iter_next(graph, &iter) {
			size, ok := bac.mem_op_size(graph, out.id)
			if !ok {
				failed_sroa = true
				failed_split = true
				break
			}
			onode := get_node(graph, out.id)
			if onode.itype == .Copy {
				failed_split = true
			}
			if i32(iter.offset + size) > slot_size {
				failed_sroa = true
				continue
			}
			if out.idx != 2 do continue sroa
			if onode.itype == .Copy || onode.itype == .Set {
				failed_sroa = true
				continue
			}

			new_slot := Slot {
				start = i32(iter.offset),
				end   = i32(iter.offset + size),
			}

			for slot in slots {
				if slot.end <= new_slot.start || new_slot.end <= slot.start {
					continue
				}

				if slot != new_slot {
					mismatches += 1
					failed_sroa = true
				}

				continue collect_slot
			}

			if append(&slots, new_slot) == 0 {
				failed_sroa = true
			}
		}

		loc := bac.get_extra(ctx, mout.id, Local)
		if !failed_split && failed_sroa && !loc.is_split && false {
			append(&threads, mnode.outs[0].id)
			loc.is_split = true
		}

		if failed_sroa do continue

		sroad += 1
		if len(slots) != 1 {
			for &slot in slots {
				local := bac.add_local(graph, "sroal", emem)
				bac.get_extra(graph, local, Local).size = slot.end - slot.start
				slot.local = bac.add_local_addr(graph, "sroadr", local)
			}

			Op :: struct {
				local: Node_ID,
				id:    Node_ID,
			}

			ops: [dynamic]Op

			iter = {}
			iter.curr = mnode.outs[0].id
			for out in bac.offset_iter_next(graph, &iter) {
				for &slt, i in slots {
					if int(slt.start) == iter.offset {
						append(&ops, Op{slt.local, out.id})
						break
					}
				}
			}

			for op in ops {
				bac.set_input(graph, op.id, 2, op.local)
			}
		} else {
			slots[0].local = mnode.outs[0].id
		}

		for slot in slots {
			iter = {}
			iter.curr = slot.local
			for op in bac.offset_iter_next(graph, &iter) {
				edit_node_id(&ctx, op.id, rename_slot_count)
			}
			rename_slot_count += 1
		}
	}

	ctx.threads_start = rename_slot_count

	iter: bac.Offset_Iter
	for thread in threads {
		iter = {}
		iter.curr = thread
		for op in bac.offset_iter_next(graph, &iter) {
			edit_node_id(&ctx, op.id, rename_slot_count)
		}
		rename_slot_count += 1
	}

	bac.add_efficiency_stat(graph, .sroa_slot_mismatch, mismatches, 0)
	bac.add_efficiency_stat(graph, .sroad_locals, total, sroad)

	edit_node_id :: proc(ctx: ^Ctx, id: Node_ID, new: u32) {
		node := get_node(ctx, id)
		ctx.slot_idx[node.gvn] = new + 1
	}

	get_edited_node_idx :: proc(ctx: ^Ctx, node: ^bac.Node) -> (u32, bool) {
		return ctx.slot_idx[node.gvn] - 1, ctx.slot_idx[node.gvn] != 0
	}

	ctx.scope = make([]Value_Entry, rename_slot_count)

	if len(ctx.scope) > int(ctx.threads_start) {
		emem = bac.find_or_create_node(ctx, .Mem)
	}

	split_mem := emem
	if len(ctx.scope) > int(ctx.threads_start) {
		split := bac.add_split_mem(ctx, "ptspl", emem)
		for &slot in ctx.scope[ctx.threads_start:] {
			slot.node = bac.add_mem(ctx, "slcm", split)
		}
		split_mem = bac.add_mem(ctx, "mscm", split)
		for out in bac.get_outputs(ctx, emem) {
			if out.id != split && get_node(graph, out.id).itype != .Local {
				bac.set_input(ctx, out.id, out.idx, split_mem)
			}
		}
	}

	if rename_slot_count != 0 do walk_thread(&ctx, split_mem)

	ctx.dont_delete = false

	for phi in ctx.deleted_lazy_phys {
		if get_node(graph, phi).rtype == bac.DEAD_NODE_KIND do continue
		bac.subsume(graph, bac.get_inputs(graph, phi)[1], phi)
	}

	if int(ctx.threads_start) < len(ctx.scope) {
		for einp in bac.get_inputs(ctx, ctx.end) {
			connect_to := einp
			node := expand_node(ctx, einp)
			if node.itype == .Return {
				connect_to = bac.add_merge_mem(ctx, "mmrg", {node.inps[1]})
				bac.set_input(ctx, einp, 1, connect_to)
			}
			for i in int(ctx.threads_start) ..< len(ctx.scope) {
				value := get_scope_value(&ctx, ctx.scope, i)
				bac.connect(ctx, connect_to, value)
			}
		}
	}

	if !ODIN_DISABLE_ASSERT {
		wl: bac.Worklist
		bac.worklist_init(&wl, int(graph.gvn))
		bac.collect_nodes(graph, &wl)

		for n in wl.data[:wl.len] {
			expand_node(graph, n)
		}
	}

	return rename_slot_count != 0

	walk_thread :: proc(ctx: ^Ctx, thread: Node_ID) {

		slot: Split_Slot
		slot.prev = ctx.split_slot

		cursor := thread
		limita := 1000
		for {
			assert(limita > 0)
			limita -= 1
			cnode := expand_node(ctx, cursor)
			pcursor := cursor
			cursor = 0

			outs := slice.clone(cnode.outs)
			prev: Node_ID

			#partial switch cnode.itype {
			case .Store, .Set, .Copy:
				id := get_edited_node_idx(ctx, cnode) or_break
				slot := &ctx.scope[id]
				if id < ctx.threads_start {
					slot^ = Value_Entry(cnode.inps[3])
				} else {
					prev = cnode.inps[1]
					value := get_scope_value(ctx, ctx.scope, id)
					bac.set_input(ctx, pcursor, 1, value)
					slot^ = {
						node = pcursor,
					}
				}
				assert(slot^ != {})
			case .Call:
				assert(len(cnode.outs) == 1)
				cursor = cnode.outs[0].id
				cursor = bac.find_node(ctx, .Mem, cursor) or_else panic("")
				continue
			case .Mem, .Phi, .Return, .Split_Mem, .Merge_Mem:
			case:
				fmt.panicf("%v", cnode.node)
			}

			fin_outs: [dynamic]bac.Node_Output
			for cout in outs {
				conode := expand_node(ctx, cout.id)

				#partial switch conode.itype {
				case .Load:
					id := get_edited_node_idx(ctx, conode) or_break
					if id < ctx.threads_start {
						value := get_scope_value(ctx, ctx.scope, id)
						bac.subsume(ctx, value, cout.id)
					} else {
						value := get_scope_value(ctx, ctx.scope, id)
						bac.set_input(
							ctx,
							cout.id,
							1,
							value,
							subsume_on_intern = true,
						)
					}
				case .Store,
				     .Call,
				     .Set,
				     .Copy,
				     .Return,
				     .Phi,
				     .Split_Mem,
				     .Merge_Mem,
				     .Mem:
					if prev != 0 {
						bac.set_input(ctx, cout.id, cout.idx, prev)
					}
					append(&fin_outs, cout)
				}
			}

			slot.scope = ctx.scope

			if cnode.itype == .Split_Mem {
				ctx.split_slot = &slot
			}

			for cout, i in fin_outs {
				last := i == len(fin_outs) - 1

				if last || cnode.itype == .Split_Mem {
					cursor = cout.id
					ctx.scope = slot.scope
				} else {
					ctx.scope = slice.clone(slot.scope)
				}

				conode := expand_node(ctx, cout.id)
				#partial switch conode.itype {
				case .Local:
				case .Load:
				case .Merge_Mem:
					id, ok := get_edited_node_idx(ctx, conode)
					if !ok {
						id = u32(len(ctx.merges))
						edit_node_id(ctx, cout.id, id)
						append(&ctx.merges, Merge{})
					}

					ctx.merges[id].seen_cnt += 1
					fmt.assertf(ctx.split_slot != nil, "%v")
					ctx.split_slot.scope = ctx.scope
					if ctx.merges[id].seen_cnt < len(conode.inps) {
						cursor = 0
					}
				case .Phi:
					reg := get_node(ctx, conode.inps[0])

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
						for i in 0 ..< len(ctx.scope) {
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
								res = Value_Entry(
									bac.add_raw(
										ctx,
										"srphi",
										u16(bac.Node_Type.Phi),
										get_node(ctx, res.node).dt,
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
							scope := make([]Value_Entry, len(ctx.scope))
							for &s, i in scope {
								if loop_scope[i] != {} {
									s = Value_Entry {
										node    = Node_ID(id),
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

							for i in 0 ..< len(ctx.scope) {
								init := loop.scope[i]
								bnode := &backedge[i]
								if init.is_loop do continue

								inode := expand_node(ctx, init.node)
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
									bac.subsume(ctx, inode.inps[1], init.node)
								} else {
									bac.connect(ctx, init.node, bnode.node)
									inode.itype = .Phi
									vl := bac.intern(ctx, init.node)
									assert(vl == init.node)
								}
							}

							loop.done = true

							ctx.scope = {}
							cursor = 0

							break
						}
					} else do panic("")

					fallthrough
				case .Store, .Call, .Set, .Copy, .Return, .Mem, .Split_Mem:
					if !last {
						walk_thread(ctx, cout.id)
					}
				case:
					fmt.panicf("%v", conode.node)
				}
			}

			if cursor == 0 do break
		}

		ctx.split_slot = slot.prev
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
			vnode := expand_node(ctx, val)
			if (btype(vnode) != .Lazy_Phi ||
				   vnode.inps[0] != loop.loop_node) &&
			   !loop.done {
				assert(vnode.itype != .Phi || vnode.inps[0] != loop.loop_node)
				val = add_lazy_phi(
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
}
