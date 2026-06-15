package backend

import "../vendored/gam/util/arna"
import "../vendored/gam/util/bit_arr"
import "base:intrinsics"
import "base:runtime"
import "core:container/queue"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:sort"
import "core:strings"

REGLOGS :: #config(REGLOGS, false)

Reg_Kind :: enum u16 {
	General,
}

reg_kind_char :: proc(kind: Reg_Kind) -> rune {
	table := [Reg_Kind]rune {
		.General = 'g',
	}
	return (table)[kind]
}

Reg :: bit_field u16 {
	index: u16      | 12,
	kind:  Reg_Kind | 4,
}

Reg_Mask :: struct {
	masks:      [^]int,
	using meta: bit_field int {
		kind:       Reg_Kind | 4,
		bit_length: int      | 60,
	},
}

reg_mask_simple :: proc(
	ra: ^Regalloc,
	kind: Reg_Kind,
	first_mask: int,
) -> (
	rm: Reg_Mask,
) {
	rm = reg_mask_empty(ra, kind)
	assert(rm.bit_length >= MASK_SIZE)
	rm.masks[0] = first_mask
	return
}

reg_mask_single :: proc(ra: ^Regalloc, reg: Reg) -> (rm: Reg_Mask) {
	rm = reg_mask_empty(ra, reg.kind)
	reg_mask_set(rm, reg.index)
	return
}

reg_mask_set :: proc(rm: Reg_Mask, #any_int index: int, value := true) {
	assert(index < rm.bit_length)
	if value {
		rm.masks[index / MASK_SIZE] |= 1 << uint(index % MASK_SIZE)
	} else {
		rm.masks[index / MASK_SIZE] &= ~(1 << uint(index % MASK_SIZE))
	}
}

reg_mask_empty :: proc(ra: ^Regalloc, kind: Reg_Kind) -> Reg_Mask {
	return {
		masks = raw_data(arna.smake(ra, []int, ra.class_lengths[kind])),
		bit_length = int(ra.class_lengths[kind]) * MASK_SIZE,
		kind = kind,
	}
}

reg_mask_first_set :: proc(rm: Reg_Mask) -> (int, bool) {
	for i in 0 ..< rm.bit_length / MASK_SIZE {
		if rm.masks[i] != 0 {
			return i * MASK_SIZE +
				intrinsics.count_trailing_zeros(rm.masks[i]),
				true
		}
	}
	return -1, false
}

reg_mask_pop_count :: proc(rm: Reg_Mask) -> (count: int) {
	for i in 0 ..< rm.bit_length / MASK_SIZE {
		count += intrinsics.count_ones(rm.masks[i])
	}
	return
}

reg_mask_intersects :: proc(a, b: Reg_Mask) -> bool {
	if a.kind != b.kind do return false
	assert(a.bit_length == b.bit_length)
	for i in 0 ..< a.bit_length / MASK_SIZE {
		if a.masks[i] & b.masks[i] != 0 do return true
	}
	return false
}

reg_mask_intersection :: proc(a, b: Reg_Mask) {
	ml := min(a.bit_length, b.bit_length) / MASK_SIZE
	for i in 0 ..< ml {
		a.masks[i] &= b.masks[i]
	}
	for i in ml ..< a.bit_length / MASK_SIZE {
		a.masks[i] = 0
	}
}

reg_mask_is_empty :: proc(mask: Reg_Mask) -> bool {
	for i in 0 ..< mask.bit_length / MASK_SIZE {
		if mask.masks[i] != 0 do return false
	}
	return true
}

Regalloc_Spec :: struct {
	class_lengths:        [Reg_Kind]u8,
	datatype_to_reg_kind: [Node_Datatype]Reg_Kind,
	inplace_slot_idxs:    []i8,
	first_input_idxs:     []u8,
	interned_reg_masks:   [][^]int,
	reg_masks:            [][][Reg_Kind]Mask_Intern_Key,
	reg_mask_of:          proc(
		_: ^Graph,
		_: ^Regalloc,
		_: Node_ID,
		_: int,
	) -> Reg_Mask,
}

Regalloc :: struct {
	using spec:  ^Regalloc_Spec,
	using alloc: ^arna.Allocator,
}

MASK_SIZE :: size_of(int) * 8

reg_mask_of :: proc(
	graph: ^Graph,
	re: ^Regalloc,
	id: Node_ID,
	#any_int idx: int,
) -> Reg_Mask {
	node := graph_get(graph, id)
	masks := re.reg_masks[node.rtype]
	reg_kind := re.datatype_to_reg_kind[node.dt]
	if idx < len(masks) {
		id := masks[idx][reg_kind]
		if id != 0 {
			mask := reg_mask_empty(re, reg_kind)
			mem.copy_non_overlapping(
				mask.masks,
				re.interned_reg_masks[id],
				int(re.class_lengths[reg_kind]) * size_of(int),
			)
			return mask
		}
	}

	return re.reg_mask_of(graph, re, id, idx)
}

regalloc :: proc(
	ra: ^Regalloc,
	graph: ^Graph,
	sched: ^Graph_Schedule,
) -> []Reg {
	for i in 0 ..< 7 {
		res, ok := regalloc_round(ra, graph, sched)
		if ok {
			if REGLOGS do log.info("regalloc rounds:", i)
			return res
		}
	}

	panic("Ralloc took too many rounds")
}

Lrg_Meta :: bit_field u32 {
	index:           u32  | 22,
	failed_to_color: bool | 1,
	failed:          bool | 1,
	self_conflict:   bool | 1,
	rank:            u8   | 7,
}

Lrg :: struct {
	node:    Node_ID,
	using _: Lrg_Meta,
	mask:    Reg_Mask,
	parent:  ^Lrg,
	// TODO: this should go into meta instead of the index
	reg:     i16,
	area:    u32,
}

regalloc_round :: proc(
	ra: ^Regalloc,
	graph: ^Graph,
	sched: ^Graph_Schedule,
) -> (
	res: []Reg,
	ok: bool = true,
) {
	arna.scrath(ra)

	graph.dont_intern = true
	defer graph.dont_intern = false

	Instr_Placement :: struct {
		block: u32,
	}

	Ctx :: struct {
		graph:           ^Graph,
		ra:              ^Regalloc,
		sched:           ^Graph_Schedule,
		instr_placement: []Instr_Placement,
		lrg_table:       []^Lrg,
		self_conflicts:  [dynamic]Self_Conflict,
		adj:             [][]^Lrg,
	}

	ctx: Ctx
	ctx.ra = ra
	ctx.graph = graph
	ctx.sched = sched

	max_lrg_count := 0
	block_base := int(graph.gvn) - len(sched.bbs)
	ctx.instr_placement = arna.smake(ra, []Instr_Placement, block_base)
	rev_gvn := block_base

	rev_gvn -= 1
	graph_get(graph, NODE_START).gvn = u32(rev_gvn)

	for bb, i in sched.bbs {
		graph_get(graph, bb.head).gvn = u32(block_base + i)
		for instr in bb.instrs {
			instr_node := graph_get(graph, instr)
			if instr_node.dt != .Void {
				instr_node.gvn = u32(max_lrg_count)
				max_lrg_count += 1
			} else {
				rev_gvn -= 1
				instr_node.gvn = u32(rev_gvn)
			}
			ctx.instr_placement[instr_node.gvn] = {
				block = u32(i),
			}
		}
	}

	Stage :: enum int {
		None,
		Build_Lrgs,
		Build_Ifg,
		Color,
	}

	failed_stage: Stage

	lrgs := arna.smake(ra, []Lrg, max_lrg_count)
	used_lrgs: u32

	ctx.lrg_table = arna.smake(ra, []^Lrg, max_lrg_count)

	for bb, i in sched.bbs {
		for instr in bb.instrs {
			inode := graph_expand(graph, instr)

			if inode.dt != .Void {
				lrg: ^Lrg

				if .Comutes in graph.node_flags[inode.rtype] {
					if graph_get(graph, inode.inps[0]).output_count > 1 &&
					   graph_get(graph, inode.inps[1]).output_count == 1 {
						graph_outs(graph, inode.inps[1])[0].idx = 0

						for &out in graph_outs(graph, inode.inps[0]) {
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
					inplace_node := graph_get(
						graph,
						inode.inps[inode.inplace_slot],
					)
					lrg = ctx.lrg_table[inplace_node.gvn]
				} else if inode.itype == .Phi {
					for inp in inode.inps[1:] {
						inp_node := graph_get(graph, inp)
						lrg = unify(lrg, ctx.lrg_table[inp_node.gvn])
					}
				}

				for o in inode.outs {
					onode := graph_expand(graph, o.id)
					if onode.inplace_slot == o.idx {
						lrg = unify(lrg, ctx.lrg_table[onode.gvn])
					}
				}

				mask := reg_mask_of(graph, ra, instr, 0)
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
					onode := graph_expand(graph, o.id)
					if int(o.idx) < onode.data_start ||
					   u16(o.idx) >= onode.ordered_input_count {
						continue
					}

					mask := reg_mask_of(graph, ra, o.id, o.idx)
					intersect(lrg, mask)
				}

				ctx.lrg_table[inode.gvn] = lrg
			}

		}
	}

	for &l in ctx.lrg_table {
		assert(!l.failed)
		l = find(l)
	}

	//log_lrgs(graph, sched, lrg_table)

	arena := arna.allocator(ra)

	Liveouts :: map[^Lrg]Node_ID

	Block :: struct {
		liveouts: Liveouts,
	}

	interference := bit_arr.init(used_lrgs * used_lrgs, arena)
	blocks := arna.smake(ra, []Block, len(sched.bbs))

	Self_Conflict :: struct {
		lrg:  ^Lrg,
		node: Node_ID,
	}

	ctx.self_conflicts = make([dynamic]Self_Conflict, arena)

	worklist: queue.Queue(u32)
	queue.init(&worklist, len(sched.bbs), arena)

	for _, i in sched.bbs {
		queue.push_front(&worklist, u32(i))
	}

	current_liveouts: Liveouts
	for b in queue.pop_front_safe(&worklist) {

		bb := sched.bbs[b]
		lbb := blocks[b]
		bb_head := graph_get(graph, bb.head)

		clear(&current_liveouts)
		for k, v in lbb.liveouts {
			current_liveouts[k] = v
		}

		#reverse for instr in bb.instrs {
			inode := graph_expand(graph, instr)

			if inode.dt != .Void {
				lrg := ctx.lrg_table[inode.gvn]
				k, v := delete_key(&current_liveouts, lrg)
				if k == lrg && v != instr {
					add_conflict(&ctx, lrg, v, instr)
				}

				for l in current_liveouts {
					if !reg_mask_intersects(l.mask, lrg.mask) do continue

					pair := []^Lrg{lrg, l}

					for i in 0 ..< 2 {
						l, r := pair[i], pair[1 - i]

						// TODO: this could be a single operation
						if reg_mask_pop_count(l.mask) == 1 {
							reg_mask_set(
								r.mask,
								reg_mask_first_set(l.mask) or_else panic(""),
								false,
							)

							if reg_mask_is_empty(r.mask) {
								r.failed = true
								failed_stage = .Build_Ifg
								panic("TODO: ifg failure")
							}
						}

						bit_arr.set(
							interference,
							r.index * used_lrgs + l.index,
						)
					}
				}
			}

			if inode.itype != .Phi {
				for inp in inode.inps[inode.data_start:] {
					inp_node := graph_get(graph, inp)
					lrg := ctx.lrg_table[inp_node.gvn]
					add_liveout(&ctx, &current_liveouts, lrg, inp)
				}
			}
		}

		head := graph_expand(graph, bb.head)
		for pred, i in head.inps {
			if pred == NODE_START do break

			pred_block := graph_get(graph, graph_idom(graph, pred))
			assert(.Is_Basic_Block_Start in graph.node_flags[pred_block.rtype])

			pred_bb_idx := int(pred_block.gvn) - block_base
			assert(pred_bb_idx >= 0)

			pred_liveouts := &blocks[pred_bb_idx].liveouts

			for lrg, n in current_liveouts {
				add_liveout(&ctx, pred_liveouts, lrg, n)
			}

			for out in head.outs {
				onode := graph_expand(graph, out.id)
				if onode.itype == .Phi {
					lrg := ctx.lrg_table[onode.gvn]
					n := onode.inps[1 + i]

					add_liveout(&ctx, pred_liveouts, lrg, n)
				}
			}
		}

	}

	//log_lrgs(graph, sched, lrg_table)

	used_lrgs_check := used_lrgs

	if len(ctx.self_conflicts) != 0 {
		used_lrgs = 0
		interference.bit_length = 0
		ok = false
	}

	ifg := arna.smake(ra, [][]^Lrg, used_lrgs)
	ctx.adj = ifg
	slices := arna.smake(ra, []^Lrg, bit_arr.pop_count(interference))
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

	when REGLOGS && false {
		sb: strings.Builder
		append(&sb.buf, "\n")
		for n, i in ifg {
			fmt.sbprintln(&sb, lrgs[i], n)
		}
		log.info(string(sb.buf[:]))
	}

	color_order := arna.smake(ra, []bit_field u64 {
			idx:      u32 | 32,
			priority: u32 | 32,
		}, len(ifg))
	for &s, i in color_order {
		s = {
			idx      = u32(i),
			priority = 10000 - color_priority(ctx, &lrgs[i], ifg[i]),
		}
	}

	sort.quick_sort(color_order)

	for co in color_order {
		n := ifg[co.idx]
		lrg := &lrgs[co.idx]
		for inter in n {
			if inter.reg == -1 do continue
			reg_mask_set(lrg.mask, inter.reg, false)
		}

		first_set, ok := reg_mask_first_set(lrg.mask)
		if !ok {
			lrg.failed = true
			lrg.failed_to_color = true
			continue
		}

		assert(first_set != -1)

		lrg.reg = i16(first_set)
	}

	log_lrgs(&ctx)

	res = make([]Reg, max_lrg_count)

	for lrg, i in ctx.lrg_table {
		res[i] = {
			kind  = lrg.mask.kind,
			index = u16(lrg.reg),
		}
	}

	prev_gvn := graph.gvn

	for &lrg in lrgs[:used_lrgs_check] {
		id := lrg.node
		if lrg.failed {
			ok = false
			members := make([dynamic]Node_ID, arena)
			append(&members, id)
			for i := 0; i < len(members); i += 1 {
				member := members[i]
				for out in graph_outs(graph, member) {
					if get_lrg(ctx, out.id) == &lrg {
						append(&members, out.id)
					}
				}
			}

			for m in members {
				is_internal := true
				for out in graph_outs(graph, m) {
					if get_lrg(ctx, out.id) == &lrg do continue
					if graph_get(graph, out.id).itype == .Split {
						continue
					}
					is_internal = false
				}

				if is_internal do continue

				id = m
				fnode := graph_get(graph, m)

				if fnode.itype != .Split {
					split := graph_add_split(graph, "sdef", fnode.dt, m)

					placement_block := get_node_block(ctx, id)
					placement_idx, _ := arna.simd_search(
						placement_block.instrs[:],
						id,
					)

					inject_at(
						&placement_block.instrs,
						placement_idx + 1,
						split,
					)

					id = split
					fnode = graph_get(graph, id)
				}

				for out in arna.clone(ra, graph_outs(graph, m)) {
					olrg := get_lrg(ctx, out.id)
					if olrg == &lrg || olrg == nil do continue

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
					}

					graph_set_input(graph, out.id, out.idx, split)
				}
			}
		}
	}

	for sc in ctx.self_conflicts {
		lrg := sc.lrg
		id := sc.node

		node := graph_expand(graph, id)
		node.outs = arna.clone(ra, node.outs)

		// NOTE: we could be using the same value multiple times, so since we
		// are at it, lets reuse the immediate split
		last_split: Node_ID

		for inp, i in node.inps {
			if i != int(node.inplace_slot) {
				continue
			}

			inode := graph_get(graph, inp)
			if inode.dt == .Void do continue
			if inode.gvn >= prev_gvn {
				last_split = inp
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
				if last_split != 0 && graph_inps(graph, last_split)[0] == inp {
					split = last_split
				} else {
					split = split_before(ctx, id, i, "sci")
				}

				last_split = split

				graph_set_input(graph, id, i, split)
			}
		}

		last_split = 0
		last_split_out: Node_ID
		for out, i in node.outs {
			onode := graph_expand(graph, out.id)
			if onode.dt == .Void do continue
			if onode.gvn >= prev_gvn do continue

			out_lrg := ctx.lrg_table[onode.gvn]
			if out.idx == onode.inplace_slot || onode.itype == .Phi {
				split: Node_ID
				if last_split != 0 && last_split_out == out.id {
					split = last_split
				} else {
					split = split_before(ctx, out.id, out.idx, "sco")
				}

				last_split_out = out.id
				last_split = split

				graph_set_input(graph, out.id, out.idx, split)
			}
		}
	}

	return

	add_liveout :: proc(ctx: ^Ctx, louts: ^Liveouts, lrg: ^Lrg, n: Node_ID) {
		_, slot, just_inserted, _ := map_entry(louts, lrg)
		if !just_inserted {
			add_conflict(ctx, lrg, n, slot^)
		}
		slot^ = n
	}

	get_lrg :: proc(ctx: Ctx, node: Node_ID) -> ^Lrg {
		node := graph_get(ctx.graph, node)
		if int(node.gvn) >= len(ctx.lrg_table) do return nil
		return ctx.lrg_table[node.gvn]
	}

	split_before :: proc(
		ctx: Ctx,
		id: Node_ID,
		#any_int idx: int,
		name: string,
		redirect: Node_ID = 0,
	) -> Node_ID {
		node := graph_expand(ctx.graph, id)
		inp := redirect if redirect != 0 else node.inps[idx]
		inp_node := graph_get(ctx.graph, inp)

		placement_block: ^Graph_Basic_Block
		placement_idx: int
		if node.itype == .Phi {
			last := graph_inps(ctx.graph, node.inps[0])[idx - 1]
			placement_block = get_node_block(ctx, last)
			placement_idx = len(placement_block.instrs) - 1
		} else {
			placement_block = get_node_block(ctx, id)
			placement_idx, _ = arna.simd_search(placement_block.instrs[:], id)
		}

		split := graph_add_split(ctx.graph, name, inp_node.dt, inp)
		inject_at(&placement_block.instrs, placement_idx, split)
		return split
	}

	get_node_block :: #force_inline proc(
		ctx: Ctx,
		node: Node_ID,
	) -> ^Graph_Basic_Block {
		node := graph_get(ctx.graph, node)
		return &ctx.sched.bbs[ctx.instr_placement[node.gvn].block]
	}

	forward_lrg :: proc(
		graph: ^Graph,
		lrg: ^Lrg,
		lrg_table: []^Lrg,
	) -> Node_ID {
		id := lrg.node
		fnode := graph_get(graph, id)
		fouts := graph_outs(graph, fnode)

		if fnode.itype == .Split && fnode.output_count == 1 {
			sid := fouts[0].id
			snode := graph_get(graph, sid)
			if int(snode.gvn) >= len(lrg_table) do return id
			if lrg_table[snode.gvn] != lrg do return id
			id = sid
		}

		return id
	}

	color_priority :: proc(ctx: Ctx, lrg: ^Lrg, adj: []^Lrg) -> (vl: u32) {
		graph := ctx.graph
		lrg_table := ctx.lrg_table
		instr_placement := ctx.instr_placement

		if reg_mask_pop_count(lrg.mask) > len(adj) {
			return 0
		}

		id := forward_lrg(graph, lrg, lrg_table)

		members := make([dynamic]Node_ID, arna.allocator(ctx.ra))
		append(&members, id)
		for i := 0; i < len(members); i += 1 {
			member := members[i]
			for out in graph_outs(graph, member) {
				if int(graph_get(graph, out.id).gvn) >= len(ctx.lrg_table) do continue
				if ctx.lrg_table[graph_get(graph, out.id).gvn] == lrg {
					append(&members, out.id)
				}
			}
		}

		fnode := graph_expand(graph, id)

		if fnode.output_count == 1 {
			onode := graph_get(graph, fnode.outs[0].id)
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
			if graph_get(graph, fnode.inps[0]).itype == .Split {
				if fnode.output_count == 1 {
					return 30
				}
			}
			return 10
		}

		return 100 + (u32(len(members)) - 1) * 100
	}

	add_conflict :: proc(ctx: ^Ctx, lrg: ^Lrg, a, b: Node_ID) {
		assert(a != 0)
		assert(b != 0)

		if a != b {
			lrg.self_conflict = true
			append(&ctx.self_conflicts, Self_Conflict{lrg, a})
			append(&ctx.self_conflicts, Self_Conflict{lrg, b})
		}
	}

	unify :: proc(a, b: ^Lrg) -> ^Lrg {
		a, b := a, b
		if a == nil do return b
		if b == nil do return a
		if a == b do return a

		a, b = find(a), find(b)

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

	intersect :: proc(l: ^Lrg, mask: Reg_Mask) {
		reg_mask_intersection(l.mask, mask)
		if reg_mask_is_empty(l.mask) {
			l.failed = true
		}
	}

	find :: proc(l: ^Lrg) -> ^Lrg {
		if l.parent == nil do return l
		if l.parent.parent == nil do return l.parent

		cursor := l
		for cursor.parent != nil {
			assert(cursor.parent.rank > cursor.rank)
			cursor, cursor.parent = cursor.parent, cursor.parent.parent
		}

		return cursor
	}

	@(disabled = !REGLOGS)
	log_lrgs :: proc(ctx: ^Ctx) {

		graph := ctx.graph
		sched := ctx.sched
		lrg_table := ctx.lrg_table
		instr_placement := ctx.instr_placement

		sb: strings.Builder

		context.user_ptr = ctx
		graph_display(&sb, ctx.graph, ctx.sched, prefix = prefix)

		prefix :: proc(
			sb: ^strings.Builder,
			instr: ^Node,
			bb: Graph_Basic_Block,
		) {
			ctx := (^Ctx)(context.user_ptr)
			if instr.dt != .Void {
				lrg := ctx.lrg_table[instr.gvn]
				fmt.sbprintf(sb, "%v:", lrg.mask)
				ansi_start(sb, lrg.index)
				fmt.sbprintf(sb, "%3i", lrg.index)
				ansi_end(sb)
				if len(ctx.adj) != 0 {
					priority := color_priority(ctx^, lrg, ctx.adj[lrg.index])
					fmt.sbprintf(sb, " %04i ", priority)
				} else {
					fmt.sbprint(sb, "      ")
				}
			} else {
				fmt.sbprint(sb, "                           ")
			}
		}

		log.info(string(sb.buf[:]))
	}
}
