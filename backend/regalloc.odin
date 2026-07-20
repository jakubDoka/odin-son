package backend

import "base:intrinsics"
import "core:mem"

REGLOGS :: #config(REGLOGS, false)

Reg_Kind :: enum u16 {
	General,
	Vector,
}

Reg :: bit_field u16 {
	index: u16      | 12,
	kind:  Reg_Kind | 4,
}

// TODO: make this COW
Reg_Mask :: struct {
	masks:      [^]i64,
	kind:       Reg_Kind,
	bit_length: u32,
}

CALLS :: bit_set[Ideal_Node_Type]{.Call, .Set, .Copy}

reg_mask_single :: proc(ra: ^Regalloc, reg: Reg) -> (rm: Reg_Mask) {
	rm = reg_mask_empty(ra, reg.kind)
	reg_mask_set(rm, reg.index)
	return
}

reg_mask_set :: proc(rm: Reg_Mask, #any_int index: u32, value := true) {
	assert(index < rm.bit_length)
	if value {
		rm.masks[index / MASK_SIZE] |= 1 << uint(index % MASK_SIZE)
	} else {
		rm.masks[index / MASK_SIZE] &= ~(1 << uint(index % MASK_SIZE))
	}
}

reg_mask_empty :: proc(ra: ^Regalloc, kind: Reg_Kind) -> Reg_Mask {
	return {
		masks = raw_data(make([]i64, ra.class_lengths[kind])),
		bit_length = u32(ra.class_lengths[kind]) * MASK_SIZE,
		kind = kind,
	}
}

reg_mask_first_set :: proc(rm: Reg_Mask) -> (int, bool) {
	for i in 0 ..< rm.bit_length / MASK_SIZE {
		if rm.masks[i] != 0 {
			return int(i) * MASK_SIZE +
				int(intrinsics.count_trailing_zeros(rm.masks[i])),
				true
		}
	}
	return -1, false
}

reg_mask_pop_count :: proc(rm: Reg_Mask) -> (count: int) {
	for i in 0 ..< rm.bit_length / MASK_SIZE {
		count += int(intrinsics.count_ones(rm.masks[i]))
	}
	return
}

reg_mask_intersection_pop_count :: proc(
	a: Reg_Mask,
	b: Reg_Mask,
) -> (
	count: int,
) {
	assert(a.bit_length == b.bit_length)
	for i in 0 ..< a.bit_length / MASK_SIZE {
		count += int(intrinsics.count_ones(a.masks[i] & b.masks[i]))
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

reg_mask_contains :: proc(bset: Reg_Mask, #any_int index: u32) -> bool {
	assert(index < bset.bit_length)
	return bset.masks[index / MASK_SIZE] & (1 << uint(index % MASK_SIZE)) != 0
}

Regalloc_Spec :: struct {
	class_lengths:        [Reg_Kind]u8,
	datatype_to_reg_kind: [Node_Datatype]Reg_Kind,
	inplace_slot_idxs:    []i8,
	first_input_idxs:     []u8,
	clobbers:             [][Reg_Kind]i64,
	interned_reg_masks:   [][^]i64,
	reg_masks:            [][][Reg_Kind]Mask_Intern_Key,
	cc_table:             []Call_Conv,
	call_clobbers:        [][Reg_Kind]i64,
	reg_mask_of:          proc(
		_: ^Graph,
		_: ^Regalloc,
		_: Node_ID,
		_: int,
	) -> Reg_Mask,
}

Regalloc :: struct {
	using spec:  ^Regalloc_Spec,
	using cc:    ^Call_Conv,
	param_types: []Node_Datatype,
}

MASK_SIZE :: size_of(int) * 8

reg_mask_of :: proc(
	graph: ^Graph,
	re: ^Regalloc,
	id: Node_ID,
	#any_int idx: int,
	readonly := false,
) -> Reg_Mask {
	node := graph_expand(graph, id)

	masks := re.reg_masks[node.rtype]
	dt := node.dt
	if idx != 0 {
		inp := graph_get(graph, node.inps[idx - 1 + node.data_start])
		dt = inp.dt
	}
	reg_kind := re.datatype_to_reg_kind[dt]
	if idx < len(masks) {
		id := masks[idx][reg_kind]
		if id != 0 {
			if idx != 0 || readonly {
				return {
					masks = re.interned_reg_masks[id],
					kind = reg_kind,
					bit_length = u32(re.class_lengths[reg_kind]) * MASK_SIZE,
				}
			}
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

Lrg_Meta :: bit_field u32 {
	index: u32 | 24,
	rank:  u8  | 8,
}

Lrg_Fails :: bit_field u8 {
	killed:          bool | 1,
	failed_to_color: bool | 1,
	reg_conflict:    bool | 1,
	self_conflict:   bool | 1,
	pushed_out:      bool | 1,
}

Lrg :: struct {
	node:             Node_ID,
	using _:          Lrg_Meta,
	mask:             Reg_Mask,
	parent:           ^Lrg,
	// TODO: this should go into meta instead of the index
	using fails:      Lrg_Fails,
	reg:              i16,
	longest_use_area: u32,
	longest_def:      Node_ID,
}
