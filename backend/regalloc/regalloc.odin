package regalloc

import ".."
import "../../vendored/gam/util/arna"
import "../../vendored/gam/util/bit_arr"
import "../x64"
import "base:runtime"
import "core:container/queue"
import "core:fmt"
import "core:io"
import "core:log"
import "core:mem"
import "core:slice"
import "core:strings"

Call :: backend.Call
Node_ID :: backend.Node_ID
graph_expand :: backend.graph_expand
graph_get :: backend.graph_get

Mode :: enum {
	with_scan,
	with_coloring,
}

regalloc :: proc(
	ra: ^backend.Regalloc,
	graph: ^backend.Graph,
	sched: ^backend.Graph_Schedule,
	mode: Mode,
	scratch := context.allocator,
) -> []backend.Reg {
	if graph.node_spec.collect_meta == nil do return {}

	base := int(graph.gvn)
	total := base
	for i in 0 ..< 7 {
		res, ok := regalloc_round(ra, graph, sched, scratch, mode, i)
		if ok {
			backend.add_efficiency_stat(graph, .regalloc_rounds, total, base)
			if backend.REGLOGS do log.info("regalloc rounds:", i)
			return res
		}
		total += int(graph.gvn)
	}

	panic("Ralloc took too many rounds")
}

regalloc_round :: proc(
	ra: ^backend.Regalloc,
	graph: ^backend.Graph,
	sched: ^backend.Graph_Schedule,
	scratch: runtime.Allocator,
	mode: Mode,
	round: int,
) -> (
	res: []backend.Reg,
	ok: bool = true,
) {
	context.allocator, _ = arna.scrath(scratch)

	graph.dont_intern = true
	defer graph.dont_intern = false

	Instr_Placement :: struct {
		block: u32,
	}

	Ctx :: struct {
		graph:           ^backend.Graph,
		ra:              ^backend.Regalloc,
		sched:           ^backend.Graph_Schedule,
		mode:            Mode,
		instr_placement: [dynamic]Instr_Placement,
		lrg_table:       []^backend.Lrg,
		self_conflicts:  map[Self_Conflict]Node_ID,
		adj:             [][]u32,
		gmetas:          []backend.Regalloc_Node_Meta,
		smetas:          []Lrg_Meta,
		color_ord:       []u32,
		slrgs:           [dynamic]Slrg,
		block_offset:    int,
		blocks:          []Block,
		res:             []backend.Reg,
		block_base:      int,
	}

	ctx: Ctx
	ctx.mode = mode
	ctx.ra = ra
	ctx.ra.rms = {}
	ctx.graph = graph
	ctx.sched = sched

	def_count := 0
	block_base := int(graph.gvn) - len(sched.bbs)
	ctx.block_base = block_base
	ctx.instr_placement = make([dynamic]Instr_Placement, block_base)
	rev_gvn := block_base

	rev_gvn -= 1
	graph_get(graph, graph.start).gvn = u32(rev_gvn)

	for bb, j in sched.bbs {
		graph_get(graph, bb.head).gvn = u32(block_base + j)
		for instr in bb.instrs {
			instr_node := graph_get(graph, instr)
			if instr_node.dt != .Void {
				instr_node.gvn = u32(def_count)
				def_count += 1
			} else {
				rev_gvn -= 1
				instr_node.gvn = u32(rev_gvn)
			}
			ctx.instr_placement[instr_node.gvn] = {
				block = u32(j),
			}
		}
	}

	ctx.gmetas = graph.collect_meta(graph, ra, sched)

	lrgs := make([]backend.Lrg, def_count)
	used_lrgs: u32

	ctx.lrg_table = make([]^backend.Lrg, def_count)

	for bb in sched.bbs {
		for instr in bb.instrs {
			inode := graph_expand(graph, instr)

			if inode.dt != .Void {
				lrg: ^backend.Lrg

				if backend.graph_has_flag(graph, inode, .Comutes) {
					lhs := graph_expand(graph, inode.inps[0])
					rhs := graph_expand(graph, inode.inps[1])

					swap_becuase_use := true
					swap_becuase_use &= rhs.output_count == 1
					swap_becuase_use &= lhs.output_count > 1
					swap_becuase_use &=
						len(inode.outs) != 1 ||
						inode.outs[0].id != inode.inps[0]

					if swap_becuase_use {
						backend.swap_inputs(ctx.graph, inode, 0, 1)
					}
				}

				inplace_slot := ctx.gmetas[inode.gvn].in_place_slot
				if inplace_slot >= 0 {
					inplace_node := graph_get(graph, inode.inps[inplace_slot])
					lrg = ctx.lrg_table[inplace_node.gvn]
				} else if inode.itype == .Phi {
					for inp in inode.inps[1:] {
						lrg = unify(lrg, get_lrg(ctx, inp))
					}
				}

				for o in inode.outs {
					onode := graph_expand(graph, o.id)
					if ctx.gmetas[onode.gvn].in_place_slot == i8(o.idx) {
						lrg = unify(lrg, ctx.lrg_table[onode.gvn])
					}
				}

				mask := backend.rm_get(ctx.ra, ctx.gmetas[inode.gvn].out)
				if lrg == nil {
					lrg = &lrgs[used_lrgs]
					lrg.node = instr
					lrg.index = used_lrgs
					lrg.mask = backend.reg_mask_clone(mask)
					lrg.reg = -1
					used_lrgs += 1
				} else {
					lrg = find(lrg)
					intersect(lrg, mask)
				}

				for o in inode.outs {
					onode := graph_expand(graph, o.id)
					if !is_data_dep(ctx, onode, o.idx) do continue

					if onode.itype == .Phi {
						lrg = unify(lrg, ctx.lrg_table[onode.gvn])
					}

					umask := rm_get_use(ctx, onode, o.idx)
					intersect(lrg, umask)
				}

				ctx.lrg_table[inode.gvn] = lrg
			}
		}
	}

	failed_any := false
	for &l in ctx.lrg_table {
		failed_any |= l.fails != {}
		l = find(l)
	}

	projection := make([]u32, used_lrgs)
	preserved: u32
	for &lrg, i in lrgs[:used_lrgs] {
		if lrg.parent == nil {
			projection[i] = preserved
			lrg.index = preserved
			lrgs[preserved] = lrg
			preserved += 1
		}
	}

	used_lrgs = preserved

	for &lrg in ctx.lrg_table {
		idx := (uintptr(lrg) - uintptr(raw_data(lrgs))) / size_of(backend.Lrg)
		lrg = &lrgs[projection[idx]]
	}

	Liveout :: struct {
		lrg:  u32,
		node: Node_ID,
	}

	Liveouts :: struct {
		data: #soa[]backend.SS_Entry(Liveout),
		len:  int,
		old:  int,
	}

	liveouts_clone_into :: proc(into: ^Liveouts, from: Liveouts) {
		if len(into.data) < len(from.data) {
			backend.grow_search_space(
				&into.data,
				len(from.data),
				context.allocator,
			)
		}

		mem.zero_slice(
			into.data.hash[from.len - from.old:max(into.len, from.len)],
		)
		into.len = from.len - from.old
		mem.copy_non_overlapping(
			into.data.hash,
			from.data.hash[from.old:],
			into.len,
		)
		mem.copy_non_overlapping(
			into.data.id,
			from.data.id[from.old:],
			into.len * size_of(Liveout),
		)

		for id in into.data[:into.len] {
			assert(id.hash != 0)
			assert(id.id.node != 0)
		}
	}

	lrg_hash :: #force_inline proc(id: u32) -> u8 {
		return max(u8(id), 1)
	}

	liveouts_find :: proc(l: ^Liveouts, lrg: u32) -> (int, bool) {
		iter := backend.simd_iter_from(
			l.data.hash[:mem.align_forward_int(
				l.len,
				size_of(backend.Intern_Vec),
			)],
			lrg_hash(lrg),
		)
		for idx in backend.simd_iter_next(&iter) {
			if l.data.id[idx].lrg == lrg do return idx, true
		}
		return -1, false
	}

	liveouts_delete :: proc(into: ^Liveouts, lrg: u32) -> (v: Liveout) {
		assert(into.old == 0)

		idx, ok := liveouts_find(into, lrg)
		if !ok do return

		v = into.data.id[idx]
		into.len -= 1
		into.data[idx] = into.data[into.len]
		e: backend.SS_Entry(Liveout)
		into.data[into.len] = e

		for id in into.data[:into.len] {
			assert(id.hash != 0)
			assert(id.id.node != 0)
		}

		return
	}

	liveouts_slot :: proc(
		into: ^Liveouts,
		lrg: u32,
	) -> (
		v: ^Liveout,
		new: bool,
	) {
		if idx, ok := liveouts_find(into, lrg); ok {
			return &into.data.id[idx], true
		}

		if into.len == len(into.data) {
			new_cap := len(into.data) + size_of(backend.Intern_Vec)
			backend.grow_search_space(&into.data, new_cap, context.allocator)
		}

		into.data.hash[into.len] = lrg_hash(lrg)
		v = &into.data.id[into.len]
		into.len += 1

		return
	}

	Slrg :: backend.Slrg

	Block :: struct {
		liveouts: Liveouts,
		start:    int,
	}

	interference: bit_arr.Bit_Set

	switch mode {
	case .with_scan:
	case .with_coloring:
		interference = bit_arr.init(used_lrgs * used_lrgs)
	}

	blocks := make([]Block, len(sched.bbs))
	ctx.blocks = blocks

	Self_Conflict :: struct {
		lrg:  u32,
		node: Node_ID,
	}

	worklist: queue.Queue(u32)
	queue.init(&worklist, len(sched.bbs))
	in_queue := bit_arr.init(len(sched.bbs))

	if !failed_any {
		bit_arr.set_all(in_queue)
		instr_count := 0
		for b, j in sched.bbs {
			blocks[j].start = instr_count
			instr_count += len(b.instrs)
			queue.push_front(&worklist, u32(j))
		}
	}

	rounds: int
	curr_live: Liveouts
	for b in queue.pop_front_safe(&worklist) {
		context.user_index = int(b)
		bit_arr.set(in_queue, b, value = false)
		rounds += 1

		bb := sched.bbs[b]
		lbb := &blocks[b]

		// NOTE: we are only interested in the new liveranges that force us to
		// rewalk a block so we mark others as old and dont resseed then to the
		// current liveouts next time
		visited := lbb.liveouts.old != 0
		liveouts_clone_into(&curr_live, lbb.liveouts)
		lbb.liveouts.old = lbb.liveouts.len

		#reverse for instr, j in bb.instrs {
			inode := graph_expand(graph, instr)

			if inode.dt != .Void {
				lrg := ctx.lrg_table[inode.gvn]
				v := liveouts_delete(&curr_live, lrg.index)
				if v.node != 0 {
					// NOTE: this will not happen twice for a given def since
					// we make sure to not repropagate old lrgs
					if add_conflict(&ctx, lrg, v.node, instr) {

					}
				}

				if interference.bit_length != 0 {
					for l in curr_live.data.id[:curr_live.len] {
						l := &lrgs[l.lrg]
						if !backend.reg_mask_intersects(l.mask, lrg.mask) do continue

						pair := []^backend.Lrg{lrg, l}

						for k in 0 ..< 2 {
							ll, rl := pair[k], pair[1 - k]

							// TODO: this could be a single operation
							if backend.reg_mask_pop_count(ll.mask) == 1 {
								backend.reg_mask_set(
									rl.mask,
									backend.reg_mask_first_set(
										ll.mask,
									) or_else panic(""),
									false,
								)

								// TODO: one of them will fail, and its pretty
								// arbitrary maby its worth selecting here based on
								// a longer liverange
								if backend.reg_mask_is_empty(rl.mask) {
									rl.killed = true
								}
							}

							bit_arr.set(
								interference,
								rl.index * used_lrgs + ll.index,
							)
						}
					}
				}
			}

			clobbers_tmp := ctx.gmetas[inode.gvn].clobbers
			clobbers := [backend.Reg_Kind]i64 {
				.Vector  = i64(clobbers_tmp[.Vector]),
				.General = i64(clobbers_tmp[.General]),
			}
			if inode.itype == .Call {
				call := backend.graph_extra(graph, inode, Call)
				clobbers = ra.call_clobbers[call.ccid]
			} else if inode.itype in backend.CALLS {
				clobbers = ra.call_clobbers[0]
			}

			if clobbers != {} {
				for l in curr_live.data.id[:curr_live.len] {
					l := &lrgs[l.lrg]
					assert(l.mask.bit_length != 0)
					l.mask.masks[0] &= ~clobbers[l.mask.kind]
					if backend.reg_mask_is_empty(l.mask) {
						l.killed = true
					}
				}
			}

			if !visited {
				if inode.itype != .Phi {
					for inp in data_deps(ctx, inode) {
						inp_node := graph_get(graph, inp)
						lrg := ctx.lrg_table[inp_node.gvn]

						add_liveout(&ctx, &curr_live, lrg, {node = inp})
					}
				}
			}
		}

		head := graph_expand(graph, bb.head)
		for pred, j in head.inps[:len(head.inps) - int(head.itype == .Region)] {
			if pred == graph.start do break

			pred_block := graph_get(graph, backend.graph_idom(graph, pred))
			fmt.assertf(
				backend.graph_has_flag(
					graph,
					pred_block,
					.Is_Basic_Block_Start,
				),
				"%v",
				pred_block,
			)

			pred_bb_idx := int(pred_block.gvn) - block_base
			assert(pred_bb_idx >= 0)

			pred_bb := sched.bbs[pred_bb_idx]
			pred_liveouts := &blocks[pred_bb_idx].liveouts

			changed := false

			for vl in curr_live.data[:curr_live.len] {
				lrg := &lrgs[vl.id.lrg]
				n := vl.id
				changed |= add_liveout(&ctx, pred_liveouts, lrg, n)
			}

			if !visited {
				for out in head.outs {
					onode := graph_expand(graph, out.id)
					if onode.itype == .Phi && onode.dt != .Void {
						lrg := ctx.lrg_table[onode.gvn]
						n := onode.inps[1 + j]

						if graph_get(graph, n).itype == .Poison do continue

						changed |= add_liveout(
							&ctx,
							pred_liveouts,
							lrg,
							{node = n},
						)
					}
				}
			}

			if changed && bit_arr.set(in_queue, pred_bb_idx, value = true) {
				queue.push_back(&worklist, u32(pred_bb_idx))
			}
		}

		add_liveout :: proc(
			ctx: ^Ctx,
			louts: ^Liveouts,
			lrg: ^backend.Lrg,
			n: Liveout,
		) -> (
			chanded: bool,
		) {
			n := n
			n.lrg = lrg.index
			assert(n.node != 0)

			v, ok := liveouts_slot(louts, lrg.index)
			if ok {
				if !add_conflict(ctx, lrg, n.node, v.node) {
					//fmt.println(n.node, v.node, louts.data.id[:louts.len])
					return
				}
			}
			chanded = v.node != n.node
			v^ = n

			return
		}

		add_conflict :: proc(
			ctx: ^Ctx,
			lrg: ^backend.Lrg,
			a, b: Node_ID,
		) -> bool {
			assert(a != 0)
			assert(b != 0)

			if a != b {
				lrg.self_conflict = true
				ctx.self_conflicts[Self_Conflict{lrg.index, a}] = b
				ctx.self_conflicts[Self_Conflict{lrg.index, b}] = a
			}

			return a == b
		}
	}

	backend.add_efficiency_stat(graph, .ifg_rounds, rounds, len(sched.bbs))

	used_lrgs_check := used_lrgs
	for lrg in lrgs {
		failed_any |= lrg.fails != {}
	}

	if len(ctx.self_conflicts) != 0 || failed_any {
		used_lrgs = 0
		interference.bit_length = 0
		ok = false
	}

	Slrg_ID :: backend.Slrg_ID

	Lrg_Meta :: struct {
		current_slrg: Slrg_ID,
	}

	can_spill :: proc(ctx: Ctx, lrg: ^backend.Lrg) -> bool {
		spill_boundary := ctx.ra.spill_boundary[lrg.mask.kind]
		// TODO: remove this, its a hack, sepecific to x64
		return (backend.reg_mask_last_set(lrg.mask) or_else 0) > spill_boundary
	}

	switch mode {
	case .with_scan:
		if ok {
			// NOTE: Good estimate but still can grow on pathological cases. Thats
			// why we use ids
			ctx.slrgs = make([dynamic]Slrg, 1, max(1, used_lrgs * 2))

			ctx.smetas = make([]Lrg_Meta, used_lrgs)
		}

		for bb, bi in sched.bbs {
			if !ok do break

			slrg_checkpoint := len(ctx.slrgs)

			for instr, i in bb.instrs {
				instr_idx := ctx.block_offset + i
				inode := graph_expand(ctx.graph, instr)

				if inode.dt != .Void || inode.itype != .Phi {
					for dd in data_deps(ctx, inode) {
						ddnode := graph_expand(ctx.graph, dd)
						if ddnode.itype == .Poison do continue
						add_slrg_use(&ctx, ctx.lrg_table[ddnode.gvn], bi, i)
					}
				}

				if inode.dt != .Void {
					lrg := ctx.lrg_table[inode.gvn]
					meta := &ctx.smetas[lrg.index]
					if meta.current_slrg == 0 {
						meta.current_slrg = alloc_slrg(
							&ctx,
							{start = instr_idx, lrg = lrg},
						)
					}
					ctx.slrgs[meta.current_slrg].end = instr_idx
				}
			}

			louts := &blocks[bi].liveouts
			for lout in louts.data[:louts.len] {
				add_slrg_use(&ctx, &lrgs[lout.id.lrg], bi, len(bb.instrs))
			}

			// NOTE: The scan liveranges are sorted cross blocks but not
			// nescessarly sorted within blocks, insertion sort is good here,
			// because casual blocks are sorted anyway so sort with O(N) on
			// sorted list is good
			insertion_sort_slrg(ctx.slrgs[slrg_checkpoint:])
			keep := slrg_checkpoint
			for slrg, i in ctx.slrgs[slrg_checkpoint:] {
				ctx.slrgs[keep] = slrg
				ctx.smetas[slrg.lrg.index].current_slrg = Slrg_ID(keep)
				keep += 1
			}

			ctx.block_offset += len(bb.instrs)

			add_slrg_use :: proc(
				ctx: ^Ctx,
				lrg: ^backend.Lrg,
				current_block: int,
				end: int,
			) {
				meta := &ctx.smetas[lrg.index]
				assert(ctx.slrgs[meta.current_slrg].lrg == lrg)
				if false &&
				   ctx.slrgs[meta.current_slrg].end < ctx.block_offset {
					meta.current_slrg = alloc_slrg(
						ctx,
						{start = ctx.block_offset, lrg = lrg},
					)
				}
				ctx.slrgs[meta.current_slrg].end = ctx.block_offset + end
			}

			alloc_slrg :: proc(ctx: ^Ctx, init: Slrg) -> Slrg_ID {
				append(&ctx.slrgs, init)
				return Slrg_ID(len(ctx.slrgs) - 1)
			}

			insertion_sort_slrg :: proc(items: []Slrg) {
				for i := 1; i < len(items); i += 1 {
					key := items[i]
					j := i - 1
					for j >= 0 && items[j].start > key.start {
						items[j + 1] = items[j]
						j -= 1
					}
					items[j + 1] = key
				}
			}
		}

		assert(slice.is_sorted_by(ctx.slrgs[:], proc(a, b: Slrg) -> bool {
				return a.start < b.start}))

		for i in 0 ..< 3 {
			if !ok do break

			free_regs_slots: [backend.Reg_Kind][8]i64
			free_regs: [backend.Reg_Kind]backend.Reg_Mask
			for &s, kind in free_regs_slots {
				slice.fill(s[:], -1)
				free_regs[kind] = {
					masks      = raw_data(&s),
					bit_length = ctx.ra.mask_len,
					kind       = kind,
				}
			}

			assert(i < 2)

			Entry :: backend.SS_Entry

			Active :: struct {
				items: #soa[]Entry(^Slrg),
				len:   int,
			}

			end_hash :: proc(end: int) -> u8 {
				return min(u8(end), 254) + 1
			}

			active_push :: proc(active: ^Active, slrg: ^Slrg) {
				if len(active.items) == active.len {
					backend.grow_search_space(
						&active.items,
						len(active.items) + size_of(backend.Intern_Vec),
						context.allocator,
					)
				}
				active.items[active.len] = {end_hash(slrg.end), slrg}
				active.len += 1
			}

			active_slrgs: [backend.Reg_Kind]Active
			crossed_slrgs := 1
			recoverable_failure := false

			for &slrg in ctx.slrgs[1:] {
				slrg.lrg.reg = -1
			}

			// TODO: we could skip program points that cause no changes, mabye a
			// bitset
			for j in 0 ..< ctx.block_offset {
				for &active, kind in active_slrgs {
					siter := backend.simd_iter_from(
						active.items.hash[:mem.align_forward_int(
							active.len,
							size_of(backend.Intern_Vec),
						)],
						end_hash(j),
					)

					for i in backend.simd_iter_next_rev(&siter) {
						if active.items.id[i].end == j {
							backend.reg_mask_set(
								free_regs[kind],
								active.items.id[i].lrg.reg,
							)
							active.len -= 1
							active.items[active.len], active.items[i] =
								active.items[i], active.items[active.len]
						}
					}

					if !ODIN_DISABLE_ASSERT {
						for i, k in active.items.id[:active.len] {
							assert(i.end != j)
						}
					}
				}

				for ; crossed_slrgs < len(ctx.slrgs) &&
				    ctx.slrgs[crossed_slrgs].start == j;
				    crossed_slrgs += 1 {

					slrg := &ctx.slrgs[crossed_slrgs]
					available := free_regs[slrg.lrg.mask.kind]
					spill_boundary := ctx.ra.spill_boundary[slrg.lrg.mask.kind]
					active := &active_slrgs[slrg.lrg.mask.kind]
					// TODO: remove this, its a hack, sepecific to x64
					if can_spill(ctx, slrg.lrg) {
						slrg.lrg.mask.masks[0] &= -1 << uint(spill_boundary)
					}

					reg := -1
					if slrg.lrg.reg != -1 &&
					   backend.reg_mask_contains(available, slrg.lrg.reg) {
						reg = int(slrg.lrg.reg)
					} else {
						reg, _ = backend.reg_mask_first_common_set(
							available,
							slrg.lrg.mask,
						)
					}

					recoverable_failure |= reg == -1

					// NOTE: we do this even if we already failed as we
					// also mark the killed lrgs
					if backend.reg_mask_pop_count(slrg.lrg.mask) == 1 &&
					   i == 0 {
						reg =
							backend.reg_mask_first_set(
								slrg.lrg.mask,
							) or_else panic("")
						for oslrg in active.items.id[:active.len] {
							backend.reg_mask_set(
								oslrg.lrg.mask,
								reg,
								value = false,
							)
							if backend.reg_mask_pop_count(oslrg.lrg.mask) ==
							   0 {
								ok = false
								oslrg.lrg.killed = true
							}
						}
					} else {
						ok &= reg != -1
					}

					// TODO: i don't know if its better to migrate the main lrg
					// here to this new register, it might not matter

					slrg.lrg.reg = i16(reg)

					if slrg.lrg.reg != -1 {
						active_push(active, slrg)
						backend.reg_mask_set(available, slrg.lrg.reg, false)
					} else {
						best := slrg
						best_idx := -1
						for oslrg, i in active.items.id[:active.len] {
							if (oslrg.start < best.start &&
								   oslrg.lrg.fails == {} &&
								   !can_spill(ctx, oslrg.lrg)) ||
							   can_spill(ctx, best.lrg) ||
							   best.lrg.fails != {} {
								best = oslrg
								best_idx = i
							}
						}
						best.lrg.failed_to_assign = true
						if best_idx >= 0 {
							active.items[best_idx] = {end_hash(slrg.end), slrg}
							slrg.lrg.reg = best.lrg.reg
						}
					}

					if slrg.lrg.reg == -1 {
						slrg.lrg.reg = i16(reg)
					}
				}
			}

			if !ok || !recoverable_failure do break
		}
	case .with_coloring:
		ifg := make([][]u32, used_lrgs)
		ifg_counts := make([]int, used_lrgs)
		ctx.adj = ifg
		slices := make([]u32, bit_arr.pop_count(interference))
		cursor := 0
		slice_base := 0
		slice_cursor := 0

		backend.add_efficiency_stat(
			graph,
			.regalloc_memory_overhead,
			len(slices),
			used_lrgs,
		)

		iter := bit_arr.iter(interference)
		for edge in bit_arr.iter_next(&iter) {
			assert(edge != cursor)

			assert(ok)

			for {
				base := cursor * int(used_lrgs)
				end := base + int(used_lrgs)

				if edge >= end {
					ifg[cursor] = slices[slice_base:slice_cursor]
					ifg_counts[cursor] = len(ifg[cursor])
					slice_base = slice_cursor
					cursor += 1
					continue
				}

				slices[slice_cursor] = u32(edge - base)
				slice_cursor += 1
				break
			}
		}

		if len(ifg) != 0 {
			ifg[cursor] = slices[slice_base:slice_cursor]
			ifg_counts[cursor] = len(ifg[cursor])
		}

		coalesced := false
		// TODO: add priority to at least the blocks by loop depth
		for &bb in sched.bbs {
			if !ok do break

			#reverse for instr, j in bb.instrs {
				inode := graph_expand(graph, instr)
				if inode.itype != .Split do continue

				ilrg := find(get_lrg(ctx, instr))
				inlrg := find(get_lrg(ctx, inode.inps[0]))

				if ilrg == inlrg do continue

				iadj, inadj := ifg[ilrg.index], ifg[inlrg.index]

				collision := false
				to_move := 0
				for &a in iadj {
					collision |= a == inlrg.index
					if !lrg_contains(inadj, a) {
						a, iadj[to_move] = iadj[to_move], a
						to_move += 1
					}
				}
				if collision {
					continue
				}
				total := to_move + len(inadj)

				leeway := backend.reg_mask_intersection_pop_count(
					ilrg.mask,
					inlrg.mask,
				)

				if total >= leeway &&
				   (leeway == 0 ||
						   max(len(inadj), len(iadj)) != total ||
						   graph_get(graph, inode.inps[0]).itype != .Split ||
						   j == 0 ||
						   bb.instrs[j - 1] != inode.inps[0]) {
					continue
				}

				coalesced = true

				buf := make([]u32, total)
				copy(buf, iadj[:to_move])
				copy(buf[to_move:], inadj)

				winner := unify(ilrg, inlrg)
				fmt.assertf(winner.fails == {}, "%v", winner.fails)

				to_patch := winner == ilrg ? inadj : iadj
				other := winner == ilrg ? inlrg : ilrg
				for adj in to_patch {
					assert(lrgs[adj].parent == nil)
					oadj := ifg[adj]
					idx, _ := lrg_search(oadj, other.index)

					if lrg_contains(oadj, winner.index) {
						oadj[idx] = oadj[len(oadj) - 1]
						ifg[adj] = oadj[:len(oadj) - 1]
					} else {
						oadj[idx] = winner.index
					}
				}

				winner.node = inlrg.node
				ifg[winner.index] = buf
				ifg[other.index] = {}

				ordered_remove(&bb.instrs, j)
				backend.graph_subsume(graph, inode.inps[0], instr)
			}
		}

		if coalesced {
			when !ODIN_DISABLE_ASSERT {
				for adj, i in ifg {
					if lrgs[i].parent != nil do continue

					for a, i in adj {
						for b, j in adj {
							if i == j do continue
							assert(a != b)
						}
					}

					for a in adj {
						assert(lrg_contains(ifg[a], u32(i)))
					}
				}
			}

			for &l in ctx.lrg_table {
				l = find(l)
			}
		}

		when !ODIN_DISABLE_ASSERT {
			sum := 0
			for i in ifg {
				sum += len(i)
			}
		}

		ctx.color_ord = make(type_of(ctx.color_ord), len(ifg))

		alive_lrgs := 0
		for &lrg in lrgs[:used_lrgs] {
			if !ok do break
			if lrg.parent != nil do continue
			ctx.color_ord[alive_lrgs] = lrg.index
			lrg.color_ord_idx = u32(alive_lrgs)
			alive_lrgs += 1
		}

		ctx.color_ord = ctx.color_ord[:alive_lrgs]

		backend.add_efficiency_stat(
			graph,
			.regalloc_wasted_lrgs,
			used_lrgs,
			len(ctx.color_ord),
		)

		ready := 0
		done := 0

		for elm, i in ctx.color_ord {
			lrg := &lrgs[elm]
			if is_colorable(ctx, lrg, ready) {
				swap_ord(ctx, lrg, &lrgs[ctx.color_ord[ready]])
				ready += 1
			}
		}

		for {
			for ; done < ready; done += 1 {
				lrg := &lrgs[ctx.color_ord[done]]
				remove_from_ifg(ctx, lrg)

				for olrg in ctx.adj[lrg.index] {
					if is_colorable(ctx, &lrgs[olrg], ready) {
						swap_ord(ctx, &lrgs[olrg], &lrgs[ctx.color_ord[ready]])
						ready += 1
					}
				}
			}

			if done >= len(ctx.color_ord) do break

			// this will basically fail, but pick somebody who is low cost to
			// spill

			best := ready
			for pick in ready + 1 ..< len(ctx.color_ord) {
				blrg := &lrgs[ctx.color_ord[best]]
				lrg := &lrgs[ctx.color_ord[pick]]

				if can_spill(ctx, blrg) {
					continue
				}

				if ifg_counts[blrg.index] > ifg_counts[lrg.index] {
					continue
				}

				best = pick
			}

			swap_ord(
				ctx,
				&lrgs[ctx.color_ord[ready]],
				&lrgs[ctx.color_ord[best]],
			)
			ready += 1

			assert(ready <= len(ctx.color_ord))
		}

		swap_ord :: proc(ctx: Ctx, a, b: ^backend.Lrg) {
			assert(ctx.color_ord[a.color_ord_idx] == a.index)
			assert(ctx.color_ord[b.color_ord_idx] == b.index)

			a.color_ord_idx, b.color_ord_idx = b.color_ord_idx, a.color_ord_idx
			ctx.color_ord[a.color_ord_idx], ctx.color_ord[b.color_ord_idx] =
				ctx.color_ord[b.color_ord_idx], ctx.color_ord[a.color_ord_idx]

			assert(ctx.color_ord[a.color_ord_idx] == a.index)
			assert(ctx.color_ord[b.color_ord_idx] == b.index)
		}

		remove_from_ifg :: proc(ctx: Ctx, lrg: ^backend.Lrg) {
			for adj in ctx.adj[lrg.index] {
				slc := &ctx.adj[adj]
				idx :=
					lrg_search(slc^, lrg.index) or_else panic(
						"removed a lrg twice",
					)
				slc[idx], slc[len(slc) - 1] = slc[len(slc) - 1], slc[idx]
				slc^ = slc[:len(slc) - 1]
			}
		}

		is_colorable :: #force_inline proc(
			ctx: Ctx,
			lrg: ^backend.Lrg,
			ready: int,
		) -> (
			yes: bool,
		) {
			return(
				backend.reg_mask_pop_count(lrg.mask) >
					len(ctx.adj[lrg.index]) &&
				lrg.color_ord_idx >= u32(ready) \
			)
		}

		if failed_any do ctx.color_ord = {}

		#reverse for co in ctx.color_ord {
			n := ifg[co]
			lrg := &lrgs[co]
			assert(lrg.parent == nil)

			for inter in n {
				adjs := &ifg[inter]
				adjs^ = raw_data(adjs^)[:len(adjs) + 1]
				assert(adjs[len(adjs) - 1] == lrg.index)
				if lrgs[inter].reg != -1 {
					backend.reg_mask_set(lrg.mask, lrgs[inter].reg, false)
				}
			}

			clobbs := ctx.ra.call_clobbers[0][lrg.mask.kind]
			if lrg.mask.masks[0] & clobbs != 0 {
				lrg.mask.masks[0] &= clobbs
			}

			first_set, fok := backend.reg_mask_first_set(lrg.mask)
			if !fok {
				lrg.failed_to_color = true
				//assert(lrg.low_cost_spill)
				continue
			}

			assert(first_set != -1)

			lrg.reg = i16(first_set)
		}

		when !ODIN_DISABLE_ASSERT {
			for i in ifg {
				sum -= len(i)
			}
			assert(sum == 0)
		}

	}

	res = make([]backend.Reg, def_count)
	for lrg, j in ctx.lrg_table {
		res[j] = {
			kind  = lrg.mask.kind,
			index = u16(lrg.reg),
		}
	}

	ctx.res = res

	lrg_search :: proc(lrgs: []u32, vl: u32) -> (int, bool) {
		return arna.simd_search(lrgs, vl)
	}

	lrg_contains :: proc(lrgs: []u32, vl: u32) -> bool {
		_, ok := lrg_search(lrgs, vl)
		return ok
	}

	unify :: proc(a, b: ^backend.Lrg) -> ^backend.Lrg {
		a, b := a, b
		if a == nil do return b
		if b == nil do return a
		if a == b do return a

		a, b = find(a), find(b)
		if a == b do return a

		if a.rank < b.rank {
			a, b = b, a
		}

		b.parent = a

		intersect(a, b.mask)

		if a.rank == b.rank {
			a.rank += 1
		}

		return a
	}

	intersect :: proc(l: ^backend.Lrg, mask: backend.Reg_Mask) {
		fmt.assertf(
			l.mask.kind == mask.kind,
			"%v == %v %v",
			l.mask.kind,
			mask.kind,
			l,
		)
		assert(l.parent == nil)
		backend.reg_mask_intersection(l.mask, mask)
		if backend.reg_mask_is_empty(l.mask) {
			l.reg_conflict = true
		}
	}

	find :: proc(l: ^backend.Lrg) -> ^backend.Lrg {
		if l == nil do return nil
		if l.parent == nil do return l
		if l.parent.parent == nil do return l.parent

		cursor := l
		for cursor.parent != nil {
			assert(cursor.parent.rank > cursor.rank)
			root := cursor.parent.parent
			if root == nil do root = cursor.parent
			cursor, cursor.parent = cursor.parent, root
		}

		return cursor
	}

	prev_gvn := graph.gvn

	any_fails := false

	fail_count := 0

	for &lrg in lrgs[:used_lrgs_check] {
		id := lrg.node

		if lrg.fails == {} {
			assert(!backend.reg_mask_is_empty(lrg.mask))
			continue
		}

		fail_count += 1
		any_fails = true

		members := collect_lrg_members(ctx, &lrg)
		ok = false

		if lrg.failed_to_color {
			inserted_splits := 0
			for m in members {
				is_internal := true
				for out in backend.graph_outs(graph, m) {
					if get_lrg(ctx, out.id) == &lrg do continue
					if graph_get(graph, out.id).itype == .Split {
						block, placement := get_node_block_and_idx(ctx, m)
						if block.instrs[placement + 1] == out.id {
							continue
						}
					}
					is_internal = false
				}

				id = m
				fnode := graph_get(graph, m)

				fmt.assertf(fnode.output_count > 0, "%v", members)

				outs := slice.clone(backend.graph_outs(graph, m))

				if fnode.itype != .Split {
					id = split_after(ctx, "sdef", m, must = is_internal)
					fnode = graph_get(graph, id)
					inserted_splits += 1
				}

				for out in outs {
					out_node := graph_get(graph, out.id)

					split := id
					if out_node.itype != .Split {
						assert(out_node.gvn < prev_gvn)
						split = split_before(
							ctx,
							out.id,
							out.idx,
							"suse",
							redirect = id,
						)
						inserted_splits += 1
					}

					backend.graph_set_input(graph, out.id, out.idx, split)
				}

				if fnode.output_count == 0 {
					block := get_node_block(ctx, m)
					idx :=
						slice.linear_search(block.instrs[:], id) or_else panic(
							"",
						)
					ordered_remove(&block.instrs, idx)
					backend.graph_delete(ctx.graph, fnode)
				}
			}

			backend.add_efficiency_stat(
				graph,
				.pressure_splits_inserted,
				inserted_splits,
				1,
			)

			continue
		}

		if lrg.killed {
			inserted_splits := 0
			for m in members {
				mnode := graph_expand(graph, m)
				redirect := m
				for out in slice.clone(mnode.outs) {
					onode := graph_expand(graph, out.id)
					oblock := get_node_block(ctx, out.id)
					if onode.itype == .Phi {
						last :=
							backend.graph_inps(ctx.graph, onode.inps[0])[out.idx - 1]
						oblock = get_node_block(ctx, last)
					}

					if redirect == m {
						redirect = split_after(ctx, "kla", m)
						inserted_splits += int(redirect != m)
					}

					split := redirect
					if onode.itype != .Split {
						split = split_before(
							ctx,
							out.id,
							out.idx,
							"klb",
							redirect,
						)
						inserted_splits += int(split != redirect)
					}
					backend.graph_set_input(graph, out.id, out.idx, split)
				}
			}

			backend.add_efficiency_stat(
				graph,
				.kill_splits_inserted,
				inserted_splits,
				1,
			)

			continue
		}

		if lrg.reg_conflict {
			inserted_splits := 0
			for m in members {
				split := m

				has_call_use := false
				for out in backend.graph_outs(graph, m) {
					if graph_get(graph, out.id).itype in backend.CALLS {
						has_call_use = true
						break
					}
				}

				for out in backend.graph_outs(graph, m) {
					if split == m {
						split = split_after(ctx, "rcd", m)
						inserted_splits += int(split != m)
					}

					splita := split
					if graph_get(graph, out.id).itype != .Split {
						splita = split_before(
							ctx,
							out.id,
							out.idx,
							"rcu",
							redirect = split,
						)
						inserted_splits += int(splita != split)
					}

					backend.graph_set_input(graph, out.id, out.idx, splita)
				}
			}

			backend.add_efficiency_stat(
				graph,
				.conflict_splits_inserted,
				inserted_splits,
				1,
			)

			continue
		}

		if lrg.failed_to_assign {
			inserted_splits := 0

			for m in members {
				mnode := graph_expand(graph, m)
				redirect := m
				for out in slice.clone(mnode.outs) {
					onode := graph_expand(graph, out.id)
					oblock := get_node_block(ctx, out.id)
					if onode.itype == .Phi {
						last :=
							backend.graph_inps(ctx.graph, onode.inps[0])[out.idx - 1]
						oblock = get_node_block(ctx, last)
					}

					if redirect == m {
						redirect = split_after(
							ctx,
							"assa",
							m,
							must = onode.itype == .Phi,
						)
						inserted_splits += 1
					}

					split := redirect
					if onode.itype != .Split && onode.itype != .Phi {
						split = split_before(
							ctx,
							out.id,
							out.idx,
							"assb",
							redirect,
						)
						inserted_splits += 1
					}
					backend.graph_set_input(graph, out.id, out.idx, split)
				}
			}

			backend.add_efficiency_stat(
				graph,
				.pressure_splits_inserted,
				inserted_splits,
				1,
			)

			continue
		}
	}

	backend.add_efficiency_stat(
		graph,
		.fail_count_ratio,
		int(fail_count == 1 && round > 0),
		0,
	)

	assert(any_fails == !ok)

	resolve: for sc, oth in ctx.self_conflicts {
		lrg := &lrgs[sc.lrg]
		id := sc.node

		node := graph_expand(graph, id)
		node.outs = slice.clone(node.outs)

		// NOTE: we could be using the same value multiple times, so since we
		// are at it, lets reuse the immediate split
		last_split: Node_ID

		for out in node.outs {
			onode := graph_expand(graph, out.id)

			if oth == out.id && onode.itype == .Phi {
				nd := split_after(ctx, "scp", oth, must = true)
				onode = graph_expand(graph, out.id)

				#reverse for out in onode.outs[:len(onode.outs) - 1] {
					backend.graph_set_input(ctx.graph, out.id, out.idx, nd)
				}

				continue resolve
			}
		}

		for inp, j in node.inps {
			if get_lrg(ctx, inp) == nil do continue

			inode := graph_get(graph, inp)

			if j != int(ctx.gmetas[node.gvn].in_place_slot) &&
			   node.itype != .Phi {
				continue
			}

			if inode.dt == .Void do continue
			if inode.gvn >= prev_gvn {
				if graph_get(graph, inp).itype == .Split {
					last_split = inp
				}
				continue
			}

			inp_lrg := ctx.lrg_table[inode.gvn]
			if inp_lrg == lrg &&
			   ((inode.itype != .Split &&
						   (ctx.instr_placement[inode.gvn] !=
									   ctx.instr_placement[node.gvn] ||
								   inode.gvn != node.gvn - 1)) ||
					   inode.output_count > 1) {
				split: Node_ID
				if last_split != 0 &&
				   backend.graph_inps(graph, last_split)[0] == inp &&
				   node.itype != .Phi {
					split = last_split
				} else {
					split = split_before(ctx, id, j, "sci")
				}

				if graph_get(graph, split).itype == .Split {
					last_split = split
				}

				backend.graph_set_input(graph, id, j, split)
			}
		}

		last_split = 0
		last_split_out: Node_ID
		for out in slice.clone(node.outs) {
			onode := graph_expand(graph, out.id)

			if onode.dt == .Void do continue
			if onode.gvn >= prev_gvn do continue

			if out.idx == int(ctx.gmetas[onode.gvn].in_place_slot) ||
			   onode.itype == .Phi {
				split: Node_ID
				if last_split != 0 &&
				   last_split_out == out.id &&
				   onode.itype != .Phi {
					split = last_split
				} else {
					split = split_before(ctx, out.id, out.idx, "sco")
				}

				if graph_get(graph, split).itype == .Split {
					last_split_out = out.id
					last_split = split
				}

				backend.graph_set_input(graph, out.id, out.idx, split)
			}
		}
	}

	backend.verify_schedule_integrity(ctx.graph, ctx.sched)
	if ok {
		total_splits := 0
		redundant_splits := 0

		for &bb in sched.bbs {
			keep := len(bb.instrs) - 1
			#reverse for instr, i in bb.instrs[:keep] {
				inode := graph_expand(graph, instr)

				if inode.itype == .Split {
					total_splits += 1
					redundant_splits += 1
					inp := graph_expand(graph, inode.inps[0])

					if res[inode.gvn] == res[inp.gvn] {
						continue
					}

					if inp.output_count == 1 &&
					   0 < i &&
					   bb.instrs[i - 1] == inode.inps[0] &&
					   !inp.scan_split &&
					   ctx.gmetas[inp.gvn].in_place_slot >= 0 {

						in_slot_id :=
							inp.inps[ctx.gmetas[inp.gvn].in_place_slot]
						in_slot_node := graph_expand(graph, in_slot_id)

						umask := rm_get_use(
							ctx,
							inp,
							ctx.gmetas[inp.gvn].in_place_slot,
						)

						overlaps := backend.reg_mask_contains(
							umask,
							res[inode.gvn].index,
						)

						if overlaps &&
						   1 < i &&
						   bb.instrs[i - 2] == in_slot_id &&
						   in_slot_node.output_count == 1 &&
						   in_slot_node.itype == .Split {

							if res[graph_get(graph, in_slot_node.inps[0]).gvn] ==
							   res[inode.gvn] {

								res[inp.gvn] = res[inode.gvn]
								res[in_slot_node.gvn] = res[inode.gvn]
								//if true do panic("")
								continue
							}
						}
					}

					if i + 1 < len(bb.instrs) &&
					   len(inode.outs) == 1 &&
					   inode.outs[0].id == bb.instrs[keep] {
						o := inode.outs[0]
						onode := graph_expand(graph, o.id)

						umask := rm_get_use(ctx, onode, o.idx)
						overlaps := backend.reg_mask_contains(
							umask,
							res[inp.gvn].index,
						)

						if overlaps &&
						   get_lrg(ctx, instr) != get_lrg(ctx, o.id) {
							backend.graph_subsume(graph, inode.inps[0], instr)
							continue
						}
					}

					redundant_splits -= 1
				}

				keep -= 1
				bb.instrs[keep] = instr
			}

			remove_range(&bb.instrs, 0, keep)
		}

		backend.add_efficiency_stat(
			graph,
			.splits_inserted,
			total_splits,
			total_splits - redundant_splits,
		)
	}

	if ok do verify_alloc_integrity(ctx, res)

	log_lrgs(&ctx)

	return

	assert_matching_masks :: proc(
		a, b: backend.Reg_Mask,
		node: ^backend.Node,
	) {
		fmt.assertf(
			backend.reg_mask_intersection_pop_count(a, b) ==
			max(backend.reg_mask_pop_count(a), backend.reg_mask_pop_count(b)),
			"%v != %v %v",
			a,
			b,
			node,
		)
	}

	rm_get_use :: proc(
		ctx: Ctx,
		node: ^backend.Node,
		#any_int pos: int,
	) -> backend.Reg_Mask {
		if node.scan_split {
			@(static, rodata)
			slts: [8]i64
			return {
				bit_length = ctx.ra.mask_len,
				kind = .General,
				masks = raw_data(&slts),
			}
		}

		meta := &ctx.gmetas[node.gvn]
		idx := i8(pos) - i8(meta.input_start)
		fmt.assertf(
			0 <= idx && int(idx) < len(meta.masks),
			"%v %v %v %v",
			node,
			pos,
			meta.input_start,
			len(meta.masks),
		)
		umask_idx := meta.masks[idx]
		return backend.rm_get(ctx.ra, umask_idx)
	}

	@(disabled = ODIN_DISABLE_ASSERT)
	verify_alloc_integrity :: proc(ctx: Ctx, res: []backend.Reg) {
		seen := bit_arr.init(ctx.graph.gvn)
		for &bb in ctx.sched.bbs {
			if !ODIN_DISABLE_ASSERT {
				seen_phi := false
				#reverse for instr in bb.instrs {
					inode := graph_get(ctx.graph, instr)
					is_phi_or_mem := inode.itype == .Phi || inode.itype == .Mem
					fmt.assertf(!seen_phi || is_phi_or_mem, "%v", inode)
					seen_phi |= inode.itype == .Phi
				}
			}

			for instr, i in bb.instrs {
				inode := graph_expand(ctx.graph, instr)
				if inode.dt == .Void && inode.itype == .Phi do continue

				deps := inode.inps
				if inode.itype != .Split {
					deps = data_deps(ctx, inode)
				}

				for inp, idx in deps {
					inp := inp

					block := &bb
					i := i
					if inode.itype == .Phi {
						last :=
							backend.graph_inps(ctx.graph, inode.inps[0])[idx]
						block = get_node_block(ctx, last)
						i = len(block.instrs)
					}

					for {
						iblck := get_node_block(ctx, inp)
						if slice.contains(iblck.instrs[:], inp) do break
						inode := graph_expand(ctx.graph, inp)
						assert(inode.itype == .Split)
						inp = inode.inps[0]
					}

					bit_arr.set_all(seen, value = false)

					nd := graph_get(ctx.graph, inp)
					if nd.itype == .Poison do continue

					fmt.assertf(nd.dt != .Void, "%v", nd)

					check_blocks(ctx, res, inp, block.head, i, seen)
				}
			}
		}

		check_blocks :: proc(
			ctx: Ctx,
			res: []backend.Reg,
			inp: Node_ID,
			cb: Node_ID,
			sindex: int,
			seen: bit_arr.Bit_Set,
		) {
			cbnode := graph_expand(ctx.graph, cb)

			bb: ^backend.Graph_Basic_Block
			for &b in ctx.sched.bbs {
				if b.head == cb {
					bb = &b
				}
			}
			inpnode := graph_expand(ctx.graph, inp)
			block, idx := get_node_block_and_idx(ctx, inp)
			if block != bb do idx = -1
			for j in idx + 1 ..< sindex {
				clobber := graph_expand(ctx.graph, bb.instrs[j])
				if clobber.dt == .Void do continue
				if res[inpnode.gvn] == res[clobber.gvn] {
					//backend.graph_display(
					//	os.to_writer(os.stderr),
					//	ctx.graph,
					//	ctx.sched,
					//)
					fmt.assertf(
						false,
						"%v %v %v %v %v",
						inpnode.node,
						clobber.node,
						cb,
						rawptr(bb),
						rawptr(block),
					)
				}
			}

			if block == bb {
				return
			}

			is_reg := int(cbnode.itype == .Region)

			for cbinp in cbnode.inps[:len(cbnode.inps) - is_reg] {
				if backend.is_cfg(ctx.graph, cbinp) {
					cbinode := graph_expand(ctx.graph, cbinp)
					if !bit_arr.set(seen, cbinode.gvn) {
						return
					}
					b := get_node_block(ctx, cbinp)
					check_blocks(ctx, res, inp, b.head, len(b.instrs), seen)
				}
			}
		}
	}

	collect_lrg_members :: proc(ctx: Ctx, lrg: ^backend.Lrg) -> []Node_ID {
		graph := ctx.graph
		members := make([dynamic]Node_ID)
		append(&members, lrg.node)
		for i := 0; i < len(members); i += 1 {
			member := members[i]
			for out in backend.graph_outs(graph, member) {
				if get_lrg(ctx, out.id) == lrg &&
				   !slice.contains(members[:], out.id) {
					append(&members, out.id)
				}
			}
			for inp in backend.graph_inps(graph, member) {
				if get_lrg(ctx, inp) == lrg &&
				   !slice.contains(members[:], inp) {
					append(&members, inp)
				}
			}
		}
		return members[:]
	}

	get_lrg :: proc(ctx: Ctx, node: Node_ID, logg := false) -> ^backend.Lrg {
		node := graph_get(ctx.graph, node)
		if int(node.gvn) >= len(ctx.lrg_table) {
			if logg {
				log.error("lrg table out of bounds")
			}
			return nil
		}
		return ctx.lrg_table[node.gvn]
	}

	split_after :: proc(
		ctx: Ctx,
		name: string,
		use: Node_ID,
		must := false,
	) -> Node_ID {
		graph := ctx.graph
		fnode := graph_get(graph, use)

		if backend.graph_has_flag(graph, fnode, .Clonable) && !must {
			return use
		}

		umask := backend.rm_get(ctx.ra, ctx.gmetas[fnode.gvn].out)
		if (backend.reg_mask_first_set(umask) or_else 0) >= x64.GPA_REG_COUNT {
			return use
		}

		split := backend.graph_add_split(graph, name, fnode.dt, use)

		block, idx := get_node_block_and_idx(ctx, use)
		for {
			nd := graph_get(ctx.graph, block.instrs[idx + 1])
			if nd.itype != .Phi && nd.itype != .Mem do break
			idx += 1
		}

		inject_at(&block.instrs, idx + 1, split)

		return split
	}

	split_before :: proc(
		ctx: Ctx,
		id: Node_ID,
		#any_int idx: int,
		name: string,
		redirect: Node_ID = 0,
		must := false,
	) -> Node_ID {
		node := graph_expand(ctx.graph, id)
		inp := redirect if redirect != 0 else node.inps[idx]
		inp_node := graph_get(ctx.graph, inp)

		if inp_node.dt == .Void do return inp

		split: Node_ID
		if backend.graph_has_flag(ctx.graph, inp_node, .Clonable) && !must {
			if int(inp_node.gvn) > len(ctx.instr_placement) {
				// NOTE: means we already split this to the largest extent
				return inp
			}
			if inp_node.output_count == 1 {
				block, bidx := get_node_block_and_idx(ctx, inp)
				ordered_remove(&block.instrs, bidx)

				inp_node.gvn = ctx.graph.gvn
				ctx.graph.gvn += 1
				split = inp
			} else {
				backend.add_efficiency_stat(ctx.graph, .clones, 1)
				split = backend.graph_clone(ctx.graph, inp)
			}
		} else {
			split = backend.graph_add_split(ctx.graph, name, inp_node.dt, inp)
		}

		block: ^backend.Graph_Basic_Block
		bidx: int
		if node.itype == .Phi {
			last := backend.graph_inps(ctx.graph, node.inps[0])[idx - 1]
			block = get_node_block(ctx, last)
			bidx = len(block.instrs) - 1
		} else {
			block, bidx = get_node_block_and_idx(ctx, id)
		}

		inject_at(&block.instrs, bidx, split)
		return split
	}

	get_node_block :: #force_inline proc(
		ctx: Ctx,
		node: Node_ID,
	) -> ^backend.Graph_Basic_Block {
		node := graph_get(ctx.graph, node)
		fmt.assertf(
			int(node.gvn) < len(ctx.instr_placement),
			"%v %v",
			len(ctx.instr_placement[:]),
			node,
		)
		return &ctx.sched.bbs[ctx.instr_placement[node.gvn].block]
	}

	get_node_block_and_idx :: proc(
		ctx: Ctx,
		id: Node_ID,
	) -> (
		block: ^backend.Graph_Basic_Block,
		idx: int,
	) {
		block = get_node_block(ctx, id)
		idx =
			arna.simd_search(block.instrs[:], id) or_else fmt.panicf("%v", id)
		return
	}

	forward_lrg :: proc(
		graph: ^backend.Graph,
		lrg: ^backend.Lrg,
		lrg_table: []^backend.Lrg,
	) -> Node_ID {
		id := lrg.node
		fnode := graph_get(graph, id)
		fouts := backend.graph_outs(graph, fnode)

		if fnode.itype == .Split && fnode.output_count == 1 {
			sid := fouts[0].id
			snode := graph_get(graph, sid)
			if int(snode.gvn) >= len(lrg_table) do return id
			if lrg_table[snode.gvn] != lrg do return id
			id = sid
		}

		return id
	}

	@(disabled = !backend.REGLOGS)
	log_lrgs :: proc(ctx: ^Ctx) {
		sb: strings.Builder

		append(&sb.buf, "\n")

		context.user_ptr = ctx
		backend.graph_display(
			strings.to_writer(&sb),
			ctx.graph,
			ctx.sched,
			prefix = prefix,
		)

		prefix :: proc(
			w: io.Writer,
			instr: ^backend.Node,
			bb: backend.Graph_Basic_Block,
		) {
			ctx := (^Ctx)(context.user_ptr)
			if instr.dt != .Void && len(ctx.lrg_table) != 0 {
				lrg := get_lrg(ctx^, backend.graph_id(ctx.graph, instr))
				if lrg == nil {
					return
				}
				fmt.wprintf(w, "%v:", lrg.mask)
				backend.ansi_start(w, lrg.index)
				fmt.wprintf(w, "%3i", lrg.index)
				backend.ansi_end(w)
				if len(ctx.res) != 0 {
					fmt.wprintf(w, " %02i ", ctx.res[instr.gvn].index)
				} else {
					fmt.wprint(w, "       ")
				}
			} else {
				fmt.wprint(w, "                            ")
			}
		}

		log.info(string(sb.buf[:]))
	}

	is_data_dep :: proc(
		ctx: Ctx,
		inode: backend.Expanded_Node,
		#any_int idx: int,
	) -> bool {
		meta := ctx.gmetas[inode.gvn]
		if idx < int(meta.input_start) do return false
		if idx >=
		   min(len(meta.masks) + int(meta.input_start), len(inode.inps)) {
			return false
		}
		return true
	}

	data_deps :: proc(ctx: Ctx, inode: backend.Expanded_Node) -> []Node_ID {
		meta := ctx.gmetas[inode.gvn]
		len := min(len(meta.masks), len(inode.inps) - int(meta.input_start))
		return inode.inps[meta.input_start:][:len]
	}
}
