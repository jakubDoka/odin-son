package backend

import "../vendored/gam/util/arna"
import "../vendored/gam/util/bit_arr"
import "base:intrinsics"
import "base:runtime"
import "core:container/queue"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:strings"

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
	kind:  Reg_Kind | 4,
	index: u16      | 12,
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
	using alloc: arna.Allocator,
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
			mem.copy(
				mask.masks,
				re.interned_reg_masks[id],
				int(re.class_lengths[reg_kind]),
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
	for _ in 0 ..< 7 {
		res, ok := regalloc_round(ra, graph, sched)
		if ok do return res
	}

	panic("Ralloc took too many rounds")
}

regalloc_round :: proc(
	ra: ^Regalloc,
	graph: ^Graph,
	sched: ^Graph_Schedule,
) -> (
	res: []Reg,
	ok: bool,
) {
	arna.scrath(ra)

	max_lrg_count := 0
	block_base := int(graph.gvn) - len(sched.bbs)
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
		}
	}

	instr_gvn_base: u32 = 0
	max_lrg_count -= int(instr_gvn_base)

	Stage :: enum int {
		None,
		Build_Lrgs,
		Build_Ifg,
		Color,
	}

	Lrg_Meta :: bit_field u32 {
		index:  u32  | 24,
		failed: bool | 1,
		rank:   u8   | 7,
	}

	Lrg :: struct {
		node:    Node_ID,
		using _: Lrg_Meta,
		mask:    Reg_Mask,
		parent:  ^Lrg,
		// TODO: this should go into meta instead of the index
		reg:     i16,
	}

	failed_stage: Stage

	lrgs := arna.smake(ra, []Lrg, max_lrg_count)
	used_lrgs: u32

	lrg_table := arna.smake(ra, []^Lrg, max_lrg_count)

	for bb, i in sched.bbs {
		for instr in bb.instrs {
			instr_node := graph_get(graph, instr)
			instr_inputs := graph_inputs(graph, instr_node)
			instr_outputs := graph_outputs(graph, instr_node)
			first_input := ra.first_input_idxs[instr_node.rtype]
			inplace_slot := ra.inplace_slot_idxs[instr_node.rtype]

			if instr_node.dt != .Void {
				lrg: ^Lrg

				if inplace_slot >= 0 {
					inplace_node := graph_get(
						graph,
						instr_inputs[inplace_slot],
					)
					lrg = lrg_table[inplace_node.gvn]
				}

				for o in instr_outputs {
					out_node := graph_get(graph, o.id)
					if u8(ra.inplace_slot_idxs[out_node.rtype]) == o.idx {
						lrg = unify(
							lrg,
							lrg_table[out_node.gvn - instr_gvn_base],
						)
					}
				}

				mask := reg_mask_of(graph, ra, instr, 0)
				if lrg == nil {
					lrg = &lrgs[used_lrgs]
					lrg.index = used_lrgs
					lrg.mask = mask
					lrg.reg = -1
					used_lrgs += 1
				} else {
					intersect(lrg, mask)
				}

				for o in instr_outputs {
					out_node := graph_get(graph, o.id)
					if o.idx < ra.first_input_idxs[out_node.rtype] ||
					   u16(o.idx) >= out_node.ordered_input_count {
						continue
					}

					mask := reg_mask_of(graph, ra, o.id, o.idx)
					intersect(lrg, mask)
				}

				lrg_table[instr_node.gvn - instr_gvn_base] = lrg
			}

		}
	}

	for &l in lrg_table {
		assert(!l.failed)
		l = find(l)
	}

	log_lrgs(graph, sched, lrg_table, instr_gvn_base)

	arena := arna.allocator(ra)

	Liveouts :: map[^Lrg]Node_ID

	Block :: struct {
		liveouts: Liveouts,
	}

	// TODO: round these up to teh mask size, that should allow us to optimize the set bit collection
	interference := bit_arr.init(used_lrgs * used_lrgs, arena)
	blocks := arna.smake(ra, []Block, len(sched.bbs))

	worklist: queue.Queue(u32)
	queue.init(&worklist, len(sched.bbs), arena)

	for _, i in sched.bbs {
		queue.push_front(&worklist, u32(i))
	}

	current_liveouts: Liveouts
	for b in queue.pop_back_safe(&worklist) {
		bb := sched.bbs[b]
		lbb := blocks[b]
		bb_head := graph_get(graph, bb.head)

		clear(&current_liveouts)
		for k, v in lbb.liveouts do current_liveouts[k] = v

		#reverse for instr in bb.instrs {
			instr_node := graph_get(graph, instr)
			instr_inputs := graph_inputs(graph, instr_node)
			input_start := ra.first_input_idxs[instr_node.rtype]

			if instr_node.dt != .Void {
				lrg := lrg_table[instr_node.gvn - instr_gvn_base]
				_, v := delete_key(&current_liveouts, lrg)
				if v != instr {
					panic("TODO: self conflict")
				}

				for l in current_liveouts {
					if !reg_mask_intersects(l.mask, lrg.mask) do continue

					pair := []^Lrg{lrg, l}

					for i in 0 ..< 2 {
						l, r := pair[i], pair[i - 1]

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
							l.index * used_lrgs + r.index,
						)
					}
				}
			}

			for inp in instr_inputs[input_start:] {
				inp_node := graph_get(graph, inp)
				lrg := lrg_table[inp_node.gvn - instr_gvn_base]
				current_liveouts[lrg] = inp
			}
		}
	}

	log_lrgs(graph, sched, lrg_table, instr_gvn_base)

	ifg := arna.smake(ra, [][]^Lrg, used_lrgs)
	slices := arna.smake(ra, []^Lrg, bit_arr.pop_count(interference))
	cursor := 0
	slice_base := 0
	slice_cursor := 0

	iter := bit_arr.iter(interference)
	for edge in bit_arr.iter_next(&iter) {
		assert(edge != cursor)

		for {
			base := cursor * int(used_lrgs)
			end := base + int(used_lrgs)

			if edge > end {
				ifg[cursor] = slices[slice_base:slice_cursor]
				slice_base = slice_cursor
				cursor += 1
				continue
			}

			slices[slice_cursor] = &lrgs[edge]
			slice_cursor += 1
			break
		}
	}

	if REGLOGS {
		log.info(ifg)
	}

	res = make([]Reg, used_lrgs)
	for n, i in ifg {
		lrg := lrgs[i]
		for inter in n {
			if inter.reg == -1 do continue
			reg_mask_set(lrg.mask, inter.reg, false)
		}

		first_set, ok := reg_mask_first_set(lrg.mask)
		if !ok {
			panic("TODO")
		}

		lrg.reg = i16(first_set)
		res[i] = {
			kind  = lrg.mask.kind,
			index = u16(lrg.reg),
		}
	}

	ok = true
	return

	unify :: proc(a, b: ^Lrg) -> ^Lrg {
		a, b := a, b
		if a == nil do return b
		if b == nil do return a

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
			cursor, cursor.parent = cursor.parent, cursor.parent.parent
		}

		return cursor
	}

	@(disabled = !REGLOGS)
	log_lrgs :: proc(
		graph: ^Graph,
		sched: ^Graph_Schedule,
		lrg_table: []^Lrg,
		instr_gvn_base: u32,
	) {
		sb: strings.Builder
		append(&sb.buf, "\n")
		for bb in sched.bbs {
			graph_display_node(&sb, graph, bb.head)
			append(&sb.buf, "\n")
			for instr in bb.instrs {
				instr_node := graph_get(graph, instr)
				if instr_node.dt != .Void {
					lrg := lrg_table[instr_node.gvn - instr_gvn_base]
					fmt.sbprintf(&sb, "%v", lrg.mask)
				}
				graph_display_node(&sb, graph, instr)
				append(&sb.buf, "\n")
			}
		}
		log.info(string(sb.buf[:]))
	}
}
