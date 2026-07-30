package backend

import "../vendored/gam/util/bit_arr"
import "base:intrinsics"
import "core:fmt"
import "core:mem"
import "core:slice"

REGLOGS :: #config(REGLOGS, false)

Reg_Kind :: enum u16 {
	General,
	Vector,
}

Reg :: bit_field u16 {
	index: u16      | 12,
	kind:  Reg_Kind | 4,
}

// TODO: this can be a single pointer
Reg_Mask :: struct {
	masks:      [^]i64,
	kind:       Reg_Kind,
	bit_length: u32,
}

CALLS :: bit_set[Ideal_Node_Type]{.Call, .Set, .Copy}

reg_mask_clone :: proc(rm: Reg_Mask) -> (res: Reg_Mask) {
	res = rm
	res.masks = raw_data(slice.clone(rm.masks[:rm.bit_length / MASK_SIZE]))
	return
}

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
	collect_meta:         proc(
		graph: ^Graph,
		ra: ^Regalloc,
		sched: ^Graph_Schedule,
	) -> []Regalloc_Node_Meta,
}

Param_Spec :: struct {
	dt:   Node_Datatype,
	size: i32,
}

Regalloc :: struct {
	using spec:  ^Regalloc_Spec,
	using cc:    ^Call_Conv,
	using rms:   RM_Interner,
	param_specs: []Param_Spec,
}

RM_Interner :: struct {
	slots:    [Reg_Kind]#soa[]SS_Entry([^]i64),
	lens:     [Reg_Kind]int,
	mask_len: u32,
}

rm_hash :: proc(data: []i64) -> u8 {
	h: u64 = cast(u64)len(data)

	for x in data {
		h ~= transmute(u64)x
		h *= 0x9e3779b185ebca87
		h ~= h >> 32
	}

	return max(u8(h), 1)
}

rm_get :: proc(interner: ^RM_Interner, idx: RM_Intern_Idx) -> Reg_Mask {
	return {
		masks = interner.slots[idx.kind][idx.index].id,
		bit_length = interner.mask_len,
		kind = idx.kind,
	}
}

rm_intern_slice :: proc(
	interner: ^RM_Interner,
	kind: Reg_Kind,
	masks: []i64,
) -> RM_Intern_Idx {
	return rm_intern(
		interner,
		{
			kind = kind,
			masks = raw_data(masks),
			bit_length = u32(len(masks)) * MASK_SIZE,
		},
	)
}

rm_intern_single :: proc(interner: ^RM_Interner, reg: Reg) -> RM_Intern_Idx {
	buf: [4]i64
	mask := Reg_Mask {
		masks      = raw_data(&buf),
		kind       = reg.kind,
		bit_length = interner.mask_len,
	}
	reg_mask_set(mask, reg.index)
	idx := rm_intern(interner, mask)

	if rm_get(interner, idx).masks == mask.masks {
		interner.slots[idx.kind][idx.index].id = raw_data(
			slice.clone(buf[:interner.mask_len / MASK_SIZE]),
		)
	}

	return idx
}

rm_intern :: proc(interner: ^RM_Interner, mask: Reg_Mask) -> RM_Intern_Idx {
	assert(mask.bit_length == interner.mask_len)

	masks := mask.masks[:mask.bit_length / MASK_SIZE]
	hash := rm_hash(masks)

	slot := &interner.slots[mask.kind]
	ln := &interner.lens[mask.kind]

	ex, ok := find(slot^, hash, masks)
	if ok do return {index = ex, kind = mask.kind}

	if ln^ == len(slot) {
		grow_search_space(
			slot,
			len(slot) + size_of(Intern_Vec),
			context.allocator,
		)
	}

	slot[ln^] = {hash, mask.masks}
	ln^ += 1

	return {index = ln^ - 1, kind = mask.kind}

	find :: proc(
		l: #soa[]SS_Entry([^]i64),
		hash: u8,
		mask: []i64,
	) -> (
		int,
		bool,
	) {
		iter := simd_iter_from(l.hash[:len(l)], hash)
		for idx in simd_iter_next(&iter) {
			if slice.equal(l.id[idx][:len(mask)], mask) do return idx, true
		}
		return -1, false
	}
}

RM_Intern_Idx :: bit_field u16 {
	index: int      | 15,
	kind:  Reg_Kind | 1,
}

// TODO: compress this
Regalloc_Node_Meta :: struct {
	masks:         []RM_Intern_Idx,
	out:           RM_Intern_Idx,
	in_place_slot: i8,
	input_start:   u8,
	clobbers:      [Reg_Kind]u16,
}

regalloc_collect_meta :: proc(
	graph: ^Graph,
	ra: ^Regalloc,
	sched: ^Graph_Schedule,
	$meta_of: proc(
		_: ^Graph,
		_: ^Regalloc,
		_: Expanded_Node,
	) -> Regalloc_Node_Meta,
) -> []Regalloc_Node_Meta {
	slots := make([]Regalloc_Node_Meta, int(graph.gvn) - len(sched.bbs))

	when !ODIN_DISABLE_ASSERT {
		seen := bit_arr.init(graph.gvn)
	}

	for bb in sched.bbs {
		for instr in bb.instrs {
			inode := graph_expand(graph, instr)
			when !ODIN_DISABLE_ASSERT {
				fmt.assertf(bit_arr.set(seen, inode.gvn), "%v", inode)
			}
			slots[inode.gvn] = meta_of(graph, ra, inode)
			slots[inode.gvn].in_place_slot -= 1
			if slots[inode.gvn].in_place_slot >= 0 {
				slots[inode.gvn].in_place_slot += i8(
					slots[inode.gvn].input_start,
				)
			}
		}
	}

	return slots
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
