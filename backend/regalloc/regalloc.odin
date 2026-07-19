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
import "core:os"
import "core:slice"
import "core:sort"
import "core:strings"

regalloc :: proc(
	ra: ^backend.Regalloc,
	graph: ^backend.Graph,
	sched: ^backend.Graph_Schedule,
	scratch: runtime.Allocator,
) -> []backend.Reg {
	for i in 0 ..< 7 {
		res, ok := regalloc_round(ra, graph, sched, scratch, i)
		if ok {
			if backend.REGLOGS do log.info("regalloc rounds:", i)
			return res
		}
	}

	panic("Ralloc took too many rounds")
}

regalloc_round :: proc(
	ra: ^backend.Regalloc,
	graph: ^backend.Graph,
	sched: ^backend.Graph_Schedule,
	scratch: runtime.Allocator,
	i: int,
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
		instr_placement: []Instr_Placement,
		lrg_table:       []^backend.Lrg,
		self_conflicts:  map[Self_Conflict]struct{},
		adj:             [][]^backend.Lrg,
	}

	ctx: Ctx
	ctx.ra = ra
	ctx.graph = graph
	ctx.sched = sched

	max_lrg_count := 0
	block_base := int(graph.gvn) - len(sched.bbs)
	ctx.instr_placement = make([]Instr_Placement, block_base)
	rev_gvn := block_base

	rev_gvn -= 1
	backend.graph_get(graph, graph.start).gvn = u32(rev_gvn)

	//	if i == 0 do log_lrgs(&ctx)

	for bb, j in sched.bbs {
		backend.graph_get(graph, bb.head).gvn = u32(block_base + j)
		for instr in bb.instrs {
			instr_node := backend.graph_get(graph, instr)
			if instr_node.dt != .Void {
				instr_node.gvn = u32(max_lrg_count)
				max_lrg_count += 1
			} else {
				rev_gvn -= 1
				instr_node.gvn = u32(rev_gvn)
			}
			ctx.instr_placement[instr_node.gvn] = {
				block = u32(j),
			}
		}
	}

	lrgs := make([]backend.Lrg, max_lrg_count)
	used_lrgs: u32

	ctx.lrg_table = make([]^backend.Lrg, max_lrg_count)

	for bb in sched.bbs {
		for instr in bb.instrs {
			inode := backend.graph_expand(graph, instr)

			if inode.dt != .Void {
				lrg: ^backend.Lrg

				if backend.graph_has_flag(graph, inode, .Comutes) {
					if backend.graph_get(graph, inode.inps[0]).output_count >
						   1 &&
					   backend.graph_get(graph, inode.inps[1]).output_count ==
						   1 {
						backend.graph_outs(graph, inode.inps[1])[0].idx = 0

						for &out in backend.graph_outs(graph, inode.inps[0]) {
							if out.id == instr && out.idx == 0 {
								out.idx = 1
								break
							}
						}

						inode.inps[0], inode.inps[1] =
							inode.inps[1], inode.inps[0]
					}
				}

				if inode.inplace_slot >= 0 {
					inplace_node := backend.graph_get(
						graph,
						inode.inps[inode.inplace_slot],
					)
					if int(inplace_node.gvn) > len(ctx.lrg_table) {
						backend.graph_display(
							os.to_writer(os.stderr),
							graph,
							sched,
						)
						log.info(inode.node, inode.inplace_slot)
					}
					lrg = ctx.lrg_table[inplace_node.gvn]
				} else if inode.itype == .Phi {
					for inp in inode.inps[1:] {
						lrg = unify(lrg, get_lrg(ctx, inp))
					}
				}

				for o in inode.outs {
					onode := backend.graph_expand(graph, o.id)
					if onode.inplace_slot == o.idx {
						lrg = unify(lrg, ctx.lrg_table[onode.gvn])
					}
				}

				mask := backend.reg_mask_of(graph, ra, instr, 0)
				if lrg == nil {
					lrg = &lrgs[used_lrgs]
					lrg.node = instr
					lrg.index = used_lrgs
					lrg.mask = mask
					lrg.reg = -1
					used_lrgs += 1
				} else {
					intersect(lrg, mask)
				}

				for o in inode.outs {
					onode := backend.graph_expand(graph, o.id)
					if int(o.idx) < onode.data_start ||
					   u16(o.idx) >= onode.input_count {
						continue
					}

					if onode.itype == .Phi {
						lrg = unify(lrg, ctx.lrg_table[onode.gvn])
					}

					umask := backend.reg_mask_of(
						graph,
						ra,
						o.id,
						o.idx + 1 - onode.data_start,
					)
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

	//log_lrgs(graph, sched, lrg_table)

	Liveout :: struct {
		lrg:      u32,
		node:     backend.Node_ID,
		area:     u32,
		last_pos: u32,
	}

	Liveouts :: struct {
		data: #soa[]backend.SS_Entry(Liveout),
		len:  int,
	}

	liveouts_clone_into :: proc(into: ^Liveouts, from: Liveouts) {
		if len(into.data) < len(from.data) {
			backend.grow_search_space(&into.data, len(from.data))
		}

		mem.zero_slice(into.data.hash[from.len:max(into.len, from.len)])
		into.len = from.len
		mem.copy_non_overlapping(into.data.hash, from.data.hash, into.len)
		mem.copy_non_overlapping(
			into.data.id,
			from.data.id,
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
			l.data.hash[:len(l.data)],
			lrg_hash(lrg),
		)
		for idx in backend.simd_iter_next(&iter) {
			if l.data.id[idx].lrg == lrg do return idx, true
		}
		return -1, false
	}

	liveouts_delete :: proc(into: ^Liveouts, lrg: u32) -> (v: Liveout) {
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
			backend.grow_search_space(&into.data, new_cap)
		}

		into.data.hash[into.len] = lrg_hash(lrg)
		v = &into.data.id[into.len]
		into.len += 1

		return
	}

	Block :: struct {
		liveouts: Liveouts,
	}

	interference := bit_arr.init(used_lrgs * used_lrgs)
	blocks := make([]Block, len(sched.bbs))

	Self_Conflict :: struct {
		lrg:  u32,
		node: backend.Node_ID,
	}

	worklist: queue.Queue(u32)
	queue.init(&worklist, len(sched.bbs))
	in_queue := bit_arr.init(len(sched.bbs))

	if !failed_any {
		bit_arr.set_all(in_queue)
		for _, j in sched.bbs {
			queue.push_front(&worklist, u32(j))
		}
	}

	// TODO: used only once for now, dont forget to inline
	add_area :: proc(lrg: ^backend.Lrg, out: Liveout) {
		if out.area > lrg.longest_use_area {
			lrg.longest_use_area = out.area
			lrg.longest_def = out.node
		}
	}

	rounds: int

	current_liveouts: Liveouts
	for b in queue.pop_front_safe(&worklist) {
		bit_arr.set(in_queue, b, value = false)
		rounds += 1

		bb := sched.bbs[b]
		lbb := &blocks[b]

		liveouts_clone_into(&current_liveouts, lbb.liveouts)

		#reverse for instr, j in bb.instrs {
			inode := backend.graph_expand(graph, instr)

			if inode.dt != .Void {
				lrg := ctx.lrg_table[inode.gvn]
				v := liveouts_delete(&current_liveouts, lrg.index)
				if v.node != 0 {
					if add_conflict(&ctx, lrg, v.node, instr) {
						v.area += v.last_pos - u32(j)
						add_area(lrg, v)
					}
				}

				for l in current_liveouts.data.id[:current_liveouts.len] {
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

			clobbers := ra.clobbers[inode.rtype]
			if inode.itype == .Call {
				call := backend.graph_extra(graph, inode, backend.Call)
				clobbers = ra.call_clobbers[call.ccid]
			} else if inode.itype in backend.CALLS {
				clobbers = ra.call_clobbers[0]
			}

			if clobbers != {} {
				for l in current_liveouts.data.id[:current_liveouts.len] {
					l := &lrgs[l.lrg]
					assert(l.mask.bit_length != 0)
					l.mask.masks[0] &= ~clobbers[l.mask.kind]
					if backend.reg_mask_is_empty(l.mask) {
						l.killed = true
					}
				}
			}

			if inode.itype != .Phi {
				for inp in inode.inps[inode.data_start:] {
					inp_node := backend.graph_get(graph, inp)
					lrg := ctx.lrg_table[inp_node.gvn]

					add_liveout(
						&ctx,
						&current_liveouts,
						lrg,
						{node = inp, last_pos = u32(j)},
					)
				}
			}
		}

		head := backend.graph_expand(graph, bb.head)
		for pred, j in head.inps[:len(head.inps) - int(head.itype == .Region)] {
			if pred == graph.start do break

			pred_block := backend.graph_get(
				graph,
				backend.graph_idom(graph, pred),
			)
			assert(
				backend.graph_has_flag(
					graph,
					pred_block,
					.Is_Basic_Block_Start,
				),
			)

			pred_bb_idx := int(pred_block.gvn) - block_base
			assert(pred_bb_idx >= 0)

			pred_bb := sched.bbs[pred_bb_idx]
			pred_liveouts := &blocks[pred_bb_idx].liveouts

			changed := false

			for vl in current_liveouts.data[:current_liveouts.len] {
				lrg := &lrgs[vl.id.lrg]
				n := vl.id
				n.area += n.last_pos
				n.last_pos = u32(len(pred_bb.instrs))
				changed |= add_liveout(&ctx, pred_liveouts, lrg, n)
			}

			for out in head.outs {
				onode := backend.graph_expand(graph, out.id)
				if onode.itype == .Phi && onode.dt != .Void {
					lrg := ctx.lrg_table[onode.gvn]
					n := onode.inps[1 + j]

					changed |= add_liveout(
						&ctx,
						pred_liveouts,
						lrg,
						{node = n, last_pos = u32(len(pred_bb.instrs))},
					)
				}
			}

			if changed && bit_arr.set(in_queue, pred_bb_idx, value = true) {
				queue.push_back(&worklist, u32(pred_bb_idx))
			}
		}
	}

	backend.add_efficiency_stat(graph, .ifg_rounds, rounds, len(sched.bbs))

	//log_lrgs(graph, sched, lrg_table)

	used_lrgs_check := used_lrgs
	for lrg in lrgs {
		failed_any |= lrg.fails != {}
	}

	if len(ctx.self_conflicts) != 0 || failed_any {
		used_lrgs = 0
		interference.bit_length = 0
		ok = false
	}

	ifg := make([][]^backend.Lrg, used_lrgs)
	ctx.adj = ifg
	slices := make([]^backend.Lrg, bit_arr.pop_count(interference))
	cursor := 0
	slice_base := 0
	slice_cursor := 0

	iter := bit_arr.iter(interference)
	for edge in bit_arr.iter_next(&iter) {
		assert(edge != cursor)

		assert(ok)

		for {
			base := cursor * int(used_lrgs)
			end := base + int(used_lrgs)

			if edge >= end {
				ifg[cursor] = slices[slice_base:slice_cursor]
				slice_base = slice_cursor
				cursor += 1
				continue
			}

			slices[slice_cursor] = &lrgs[edge - base]
			slice_cursor += 1
			break
		}
	}

	if len(ifg) != 0 {
		ifg[cursor] = slices[slice_base:slice_cursor]
	}

	//log_lrgs(&ctx)

	coalesced := false
	// TODO: add priority to at least the blocks by loop depth
	for &bb in sched.bbs {
		if !ok do break

		#reverse for instr, j in bb.instrs {
			inode := backend.graph_expand(graph, instr)
			if inode.itype != .Split do continue

			ilrg := find(get_lrg(ctx, instr))
			inlrg := find(get_lrg(ctx, inode.inps[0]))

			assert(backend.graph_get(graph, inlrg.longest_def).dt != .Void)
			assert(backend.graph_get(graph, ilrg.longest_def).dt != .Void)

			if ilrg == inlrg do continue

			iadj, inadj := ifg[ilrg.index], ifg[inlrg.index]

			collision := false
			to_move := 0
			for &a in iadj {
				collision |= a == inlrg
				if !slice.contains(inadj, a) {
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
					   backend.graph_get(graph, inode.inps[0]).itype !=
						   .Split ||
					   j == 0 ||
					   bb.instrs[j - 1] != inode.inps[0]) {
				continue
			}

			coalesced = true

			buf := make([]^backend.Lrg, total)
			copy(buf, iadj[:to_move])
			copy(buf[to_move:], inadj)

			winner := unify(ilrg, inlrg)
			fmt.assertf(winner.fails == {}, "%v", winner.fails)

			to_patch := winner == ilrg ? inadj : iadj
			other := winner == ilrg ? inlrg : ilrg
			for adj in to_patch {
				assert(adj.parent == nil)
				oadj := ifg[adj.index]
				idx, _ := slice.linear_search(oadj, other)

				if slice.contains(oadj, winner) {
					oadj[idx] = oadj[len(oadj) - 1]
					ifg[adj.index] = oadj[:len(oadj) - 1]
				} else {
					oadj[idx] = winner
				}
			}

			winner.node = inlrg.node
			winner.longest_use_area = inlrg.longest_use_area
			winner.longest_def = inlrg.longest_def
			ifg[winner.index] = buf

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
					assert(slice.contains(ifg[a.index], &lrgs[i]))
				}
			}
		}

		for &l in ctx.lrg_table {
			l = find(l)
		}
	}

	color_order := make([]bit_field u64 {
			idx:      u32 | 32,
			priority: u32 | 32,
		}, len(ifg))

	alive_lrgs := 0
	for &lrg in lrgs[:used_lrgs] {
		if !ok do break
		if lrg.parent != nil do continue
		color_order[alive_lrgs] = {
			idx      = u32(lrg.index),
			priority = 10000 - color_priority(ctx, &lrg, ifg[lrg.index]),
		}
		alive_lrgs += 1
	}

	color_order = color_order[:alive_lrgs]

	sort.quick_sort(color_order)

	if failed_any do color_order = {}

	for co in color_order {
		n := ifg[co.idx]
		lrg := &lrgs[co.idx]
		assert(lrg.parent == nil)
		for inter in n {
			if inter.reg == -1 do continue
			backend.reg_mask_set(lrg.mask, inter.reg, false)
		}

		if lrg.mask.masks[0] & ctx.ra.call_clobbers[0][lrg.mask.kind] != 0 {
			lrg.mask.masks[0] &= ctx.ra.call_clobbers[0][lrg.mask.kind]
		}

		first_set, fok := backend.reg_mask_first_set(lrg.mask)
		if !fok {
			lrg.failed_to_color = true
			continue
		}

		assert(first_set != -1)

		lrg.reg = i16(first_set)
	}

	//log_lrgs(&ctx)

	res = make([]backend.Reg, max_lrg_count)

	for lrg, j in ctx.lrg_table {
		res[j] = {
			kind  = lrg.mask.kind,
			index = u16(lrg.reg),
		}
	}

	prev_gvn := graph.gvn

	color_fails: int

	for &lrg in lrgs[:used_lrgs_check] {
		id := lrg.node

		if lrg.fails == {} {
			assert(!backend.reg_mask_is_empty(lrg.mask))
			continue
		}

		members := collect_lrg_members(ctx, &lrg)

		ok = false

		if lrg.failed_to_color {
			color_fails += int(lrg.failed_to_color)

			for m in members {
				is_internal := true
				for out in backend.graph_outs(graph, m) {
					if get_lrg(ctx, out.id) == &lrg do continue
					if backend.graph_get(graph, out.id).itype == .Split {
						block, placement := get_node_block_and_idx(ctx, m)
						if block.instrs[placement + 1] == out.id {
							continue
						}
					}
					is_internal = false
				}

				if is_internal do continue

				id = m
				fnode := backend.graph_get(graph, m)

				assert(fnode.output_count > 0)

				if fnode.itype != .Split {
					id = split_after(ctx, "sdef", m)
					fnode = backend.graph_get(graph, id)
				}

				for out in slice.clone(backend.graph_outs(graph, m)) {
					olrg := get_lrg(ctx, out.id)
					if olrg == &lrg || olrg == nil do continue

					out_node := backend.graph_get(graph, out.id)

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
					}

					backend.graph_set_input(graph, out.id, out.idx, split)
				}

				if fnode.output_count == 0 {
					block, idx := get_node_block_and_idx(ctx, m)
					ordered_remove(&block.instrs, idx + 1)
					backend.graph_delete(ctx.graph, fnode)
				}
			}

			continue
		}

		if lrg.killed {
			for m in members {

				mnode := backend.graph_expand(graph, m)
				redirect := m
				for out in slice.clone(mnode.outs) {
					onode := backend.graph_expand(graph, out.id)
					oblock := get_node_block(ctx, out.id)
					if onode.itype == .Phi {
						last :=
							backend.graph_inps(ctx.graph, onode.inps[0])[out.idx - 1]
						oblock = get_node_block(ctx, last)
					}

					// TODO: we request reg masks needlessly since we never
					// modify them, maybe if it shows up, adda readonly flag to
					// the backend.reg_mask_of

					if redirect == m {
						redirect = split_after(ctx, "kla", m)
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
					}
					backend.graph_set_input(graph, out.id, out.idx, split)
				}
			}

			continue
		}

		if lrg.reg_conflict {
			for m in members {
				split := m

				has_call_use := false
				for out in backend.graph_outs(graph, m) {
					if backend.graph_get(graph, out.id).itype in
					   backend.CALLS {
						has_call_use = true
						break
					}
				}

				for out in backend.graph_outs(graph, m) {
					if split == m {
						split = split_after(ctx, "rcd", m)
					}

					split := split
					if backend.graph_get(graph, out.id).itype != .Split {
						split = split_before(
							ctx,
							out.id,
							out.idx,
							"rcu",
							redirect = split,
						)
					}

					backend.graph_set_input(graph, out.id, out.idx, split)
				}
			}

			continue
		}
	}

	if color_fails > 0 {
		ocursor := 0
		order := make([]bit_field u64 {
				id:            u32 | 32,
				biggest_split: u32 | 32,
			}, used_lrgs_check)

		for lrg in lrgs[:used_lrgs_check] {
			if lrg.parent != nil do continue
			order[ocursor] = {
				id            = u32(lrg.index),
				biggest_split = 100000 - lrg.longest_use_area,
			}
			ocursor += 1
		}
		order = order[:ocursor]

		sort.quick_sort(order)

		for ord in order[:min(16, len(order))] {
			lrg := lrgs[ord.id]
			id := lrg.longest_def

			fnode := backend.graph_expand(graph, id)

			split: if lrg.longest_def != 0 && lrg.longest_use_area > 1 {

				fnode.outs = slice.clone(fnode.outs)

				split := split_after(ctx, "cdef", id)

				for o in fnode.outs {
					onode := backend.graph_get(graph, o.id)
					split := split
					if onode.itype != .Split {
						split = split_before(
							ctx,
							o.id,
							o.idx,
							"cuse",
							redirect = split,
						)
					}
					backend.graph_set_input(graph, o.id, o.idx, split)
				}
			}
		}
	}

	for sc in ctx.self_conflicts {
		lrg := &lrgs[sc.lrg]
		id := sc.node

		node := backend.graph_expand(graph, id)
		node.outs = slice.clone(node.outs)

		// NOTE: we could be using the same value multiple times, so since we
		// are at it, lets reuse the immediate split
		last_split: backend.Node_ID

		for inp, j in node.inps {
			if j != int(node.inplace_slot) && node.itype != .Phi {
				continue
			}

			inode := backend.graph_get(graph, inp)
			if inode.dt == .Void do continue
			if inode.gvn >= prev_gvn {
				if backend.graph_get(graph, inp).itype == .Split {
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
				split: backend.Node_ID
				if last_split != 0 &&
				   backend.graph_inps(graph, last_split)[0] == inp &&
				   node.itype != .Phi {
					split = last_split
				} else {
					split = split_before(ctx, id, j, "sci")
				}

				if backend.graph_get(graph, split).itype == .Split {
					last_split = split
				}

				backend.graph_set_input(graph, id, j, split)
			}
		}

		last_split = 0
		last_split_out: backend.Node_ID
		for out in slice.clone(node.outs) {
			onode := backend.graph_expand(graph, out.id)
			if onode.dt == .Void do continue
			if onode.gvn >= prev_gvn do continue

			if out.idx == onode.inplace_slot || onode.itype == .Phi {
				split: backend.Node_ID
				if last_split != 0 &&
				   last_split_out == out.id &&
				   onode.itype != .Phi {
					split = last_split
				} else {
					split = split_before(ctx, out.id, out.idx, "sco")
				}

				if backend.graph_get(graph, split).itype == .Split {
					last_split_out = out.id
					last_split = split
				}

				backend.graph_set_input(graph, out.id, out.idx, split)
			}
		}
	}

	log_lrgs(&ctx)

	backend.verify_schedule_integrity(ctx.graph, ctx.sched)
	if ok do verify_alloc_integrity(ctx, res)
	if ok {
		for &bb in sched.bbs {
			keep := len(bb.instrs) - 1
			#reverse for instr, i in bb.instrs[:keep] {
				inode := backend.graph_expand(graph, instr)

				if inode.itype == .Split {
					inp := backend.graph_get(graph, inode.inps[0])

					if res[inode.gvn] == res[inp.gvn] {
						continue
					}

					if i + 1 < len(bb.instrs) &&
					   len(inode.outs) == 1 &&
					   inode.outs[0].id == bb.instrs[keep] {
						o := inode.outs[0]
						onode := backend.graph_expand(graph, o.id)
						umask := backend.reg_mask_of(
							graph,
							ra,
							o.id,
							o.idx + 1 - onode.data_start,
						)

						if backend.reg_mask_contains(
							   umask,
							   res[inp.gvn].index,
						   ) &&
						   get_lrg(ctx, instr) != get_lrg(ctx, o.id) {
							backend.graph_subsume(graph, inode.inps[0], instr)
							continue
						}
					}

					backend.add_efficiency_stat(
						graph.stats,
						.splits_inserted,
						1,
					)
				}
				keep -= 1
				bb.instrs[keep] = instr
			}

			remove_range(&bb.instrs, 0, keep)
		}
	}

	return

	@(disabled = ODIN_DISABLE_ASSERT)
	verify_alloc_integrity :: proc(ctx: Ctx, res: []backend.Reg) {
		seen := bit_arr.init(ctx.graph.gvn)
		for &bb in ctx.sched.bbs {
			seen_phi := false
			#reverse for instr in bb.instrs {
				inode := backend.graph_get(ctx.graph, instr)
				is_phi_or_mem := inode.itype == .Phi || inode.itype == .Mem
				fmt.assertf(!seen_phi || is_phi_or_mem, "%v", inode)
				seen_phi |= inode.itype == .Phi
			}

			for instr, i in bb.instrs {
				inode := backend.graph_expand(ctx.graph, instr)
				if inode.dt == .Void && inode.itype == .Phi do continue
				for inp, idx in inode.inps[inode.data_start:] {

					block := &bb
					i := i
					if inode.itype == .Phi {
						last :=
							backend.graph_inps(ctx.graph, inode.inps[0])[idx]
						block = get_node_block(ctx, last)
						assert(block != &bb)
						i = len(block.instrs)
					}

					bit_arr.set_all(seen, value = false)

					nd := backend.graph_get(ctx.graph, inp)
					if nd.itype == .Poison do continue

					fmt.assertf(nd.dt != .Void, "%v", nd)

					check_blocks(ctx, res, inp, block.head, i, seen)
				}
			}
		}

		check_blocks :: proc(
			ctx: Ctx,
			res: []backend.Reg,
			inp: backend.Node_ID,
			cb: backend.Node_ID,
			sindex: int,
			seen: bit_arr.Bit_Set,
		) {
			cbnode := backend.graph_expand(ctx.graph, cb)
			if !bit_arr.set(seen, cbnode.gvn) {
				return
			}

			bb: ^backend.Graph_Basic_Block
			for &b in ctx.sched.bbs {
				if b.head == cb {
					bb = &b
				}
			}
			inpnode := backend.graph_expand(ctx.graph, inp)
			block, idx := get_node_block_and_idx(ctx, inp)
			if block != bb do idx = -1
			for j in idx + 1 ..< sindex {
				clobber := backend.graph_expand(ctx.graph, bb.instrs[j])
				if clobber.dt == .Void do continue
				fmt.assertf(
					res[inpnode.gvn] != res[clobber.gvn],
					"%v %v",
					inpnode.node,
					clobber.node,
				)
			}

			if block == bb {
				return
			}

			for cbinp in cbnode.inps {
				if backend.is_cfg(ctx.graph, cbinp) {
					b := get_node_block(ctx, cbinp)
					check_blocks(ctx, res, inp, b.head, len(b.instrs), seen)
				}
			}
		}
	}

	collect_lrg_members :: proc(
		ctx: Ctx,
		lrg: ^backend.Lrg,
	) -> []backend.Node_ID {
		graph := ctx.graph
		members := make([dynamic]backend.Node_ID)
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
			if !add_conflict(ctx, lrg, n.node, v.node) do return
		}
		chanded = v.node != n.node
		n.area = max(n.area, v.area)
		v^ = n

		return

		// TODO: there is most likey a bug in the builting hash map
		// implementation, once it gets fixed, we will use this again

		//k, slot, just_inserted, err := map_entry(louts, lrg)
		//assert(k^ == lrg)
		//assert(err == nil)
		//if !just_inserted {
		//	add_conflict(ctx, lrg, n.node, slot^.node)
		//}
		//n.area = max(n.area, slot.area)
		//slot^ = n
	}

	get_lrg :: proc(
		ctx: Ctx,
		node: backend.Node_ID,
		logg := false,
	) -> ^backend.Lrg {
		node := backend.graph_get(ctx.graph, node)
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
		use: backend.Node_ID,
	) -> backend.Node_ID {
		graph := ctx.graph
		fnode := backend.graph_get(graph, use)

		if backend.graph_has_flag(graph, fnode, .Clonable) ||
		   (backend.reg_mask_first_set(
					   backend.reg_mask_of(
						   ctx.graph,
						   ctx.ra,
						   use,
						   0,
						   readonly = true,
					   ),
				   ) or_else 0) >=
			   x64.GPA_REG_COUNT {
			return use
		}

		split := backend.graph_add_split(graph, name, fnode.dt, use)

		block, idx := get_node_block_and_idx(ctx, use)
		for {
			nd := backend.graph_get(ctx.graph, block.instrs[idx + 1])
			if nd.itype != .Phi && nd.itype != .Mem do break
			idx += 1
		}

		inject_at(&block.instrs, idx + 1, split)

		return split
	}

	split_before :: proc(
		ctx: Ctx,
		id: backend.Node_ID,
		#any_int idx: int,
		name: string,
		redirect: backend.Node_ID = 0,
	) -> backend.Node_ID {
		node := backend.graph_expand(ctx.graph, id)
		inp := redirect if redirect != 0 else node.inps[idx]
		inp_node := backend.graph_get(ctx.graph, inp)

		if inp_node.dt == .Void do return inp

		split: backend.Node_ID
		if backend.graph_has_flag(ctx.graph, inp_node, .Clonable) {
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
		node: backend.Node_ID,
	) -> ^backend.Graph_Basic_Block {
		node := backend.graph_get(ctx.graph, node)
		assert(int(node.gvn) < len(ctx.instr_placement))
		return &ctx.sched.bbs[ctx.instr_placement[node.gvn].block]
	}

	get_node_block_and_idx :: proc(
		ctx: Ctx,
		id: backend.Node_ID,
	) -> (
		block: ^backend.Graph_Basic_Block,
		idx: int,
	) {
		block = get_node_block(ctx, id)
		idx = arna.simd_search(block.instrs[:], id) or_else panic("")
		return
	}

	forward_lrg :: proc(
		graph: ^backend.Graph,
		lrg: ^backend.Lrg,
		lrg_table: []^backend.Lrg,
	) -> backend.Node_ID {
		id := lrg.node
		fnode := backend.graph_get(graph, id)
		fouts := backend.graph_outs(graph, fnode)

		if fnode.itype == .Split && fnode.output_count == 1 {
			sid := fouts[0].id
			snode := backend.graph_get(graph, sid)
			if int(snode.gvn) >= len(lrg_table) do return id
			if lrg_table[snode.gvn] != lrg do return id
			id = sid
		}

		return id
	}

	color_priority :: proc(
		ctx: Ctx,
		lrg: ^backend.Lrg,
		adj: []^backend.Lrg,
	) -> (
		vl: u32,
	) {
		graph := ctx.graph
		lrg_table := ctx.lrg_table
		instr_placement := ctx.instr_placement

		if backend.reg_mask_pop_count(lrg.mask) > len(adj) {
			return 0
		}

		id := forward_lrg(graph, lrg, lrg_table)

		members := collect_lrg_members(ctx, lrg)

		has_non_split := false
		for m in members {
			for o in backend.graph_outs(graph, m) {
				has_non_split |= backend.graph_get(graph, o.id).itype != .Split
			}
		}
		if !has_non_split {
			return 0
		}

		fnode := backend.graph_expand(graph, id)

		if fnode.output_count == 1 {
			onode := backend.graph_get(graph, fnode.outs[0].id)
			if int(onode.gvn) < len(ctx.lrg_table) {

				if instr_placement[onode.gvn].block ==
					   instr_placement[fnode.gvn].block &&
				   ctx.lrg_table[onode.gvn] != ctx.lrg_table[fnode.gvn] {
					assert(onode.gvn > fnode.gvn)
					return u32(
						max(1000 - int((onode.gvn - fnode.gvn) * 100), 0),
					)
				}
			}
		}

		if fnode.itype == .Split {
			if backend.graph_get(graph, fnode.inps[0]).itype == .Split {
				if fnode.output_count == 1 {
					return 30
				}
			}
			return 10
		}

		return 100 + (u32(len(members)) - 1) * 100
	}

	add_conflict :: proc(
		ctx: ^Ctx,
		lrg: ^backend.Lrg,
		a, b: backend.Node_ID,
	) -> bool {
		assert(a != 0)
		assert(b != 0)

		if a != b {
			lrg.self_conflict = true
			ctx.self_conflicts[Self_Conflict{lrg.index, a}] = {}
			ctx.self_conflicts[Self_Conflict{lrg.index, b}] = {}
		}

		return a == b
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

	@(disabled = !backend.REGLOGS)
	log_lrgs :: proc(ctx: ^Ctx) {
		sb: strings.Builder

		append(&sb.buf, "\n")

		context.user_ptr = ctx
		backend.graph_display(
			strings.to_writer(&sb),
			ctx.graph,
			ctx.sched,
			//prefix = prefix,
		)

		prefix :: proc(
			w: io.Writer,
			instr: ^backend.Node,
			bb: backend.Graph_Basic_Block,
		) {
			ctx := (^Ctx)(context.user_ptr)
			if len(ctx.lrg_table) == 0 do return
			if instr.dt != .Void {
				lrg := ctx.lrg_table[instr.gvn]
				fmt.wprintf(w, "%v:", lrg.mask)
				backend.ansi_start(w, lrg.index)
				fmt.wprintf(w, "%3i", lrg.index)
				backend.ansi_end(w)
				if len(ctx.adj) != 0 {
					priority := color_priority(ctx^, lrg, ctx.adj[lrg.index])
					fmt.wprintf(w, " %04i ", priority)
				} else {
					fmt.wprint(w, "      ")
				}
			} else {
				fmt.wprint(w, "                           ")
			}
		}

		log.info(string(sb.buf[:]))
	}
}
