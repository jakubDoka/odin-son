package backend

import "../vendored/gam/util/bit_arr"
import "base:intrinsics"
import "core:fmt"
import "core:slice"

REGLOGS :: #config(REGLOGS, false)

Reg_Kind :: distinct u16

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

reg_mask_set :: proc(rm: Reg_Mask, #any_int index: u32, value := true) {
	fmt.assertf(index < rm.bit_length, "%v < %v", index, rm.bit_length)
	if value {
		rm.masks[index / MASK_SIZE] |= 1 << uint(index % MASK_SIZE)
	} else {
		rm.masks[index / MASK_SIZE] &= ~(1 << uint(index % MASK_SIZE))
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

reg_mask_last_set :: proc(rm: Reg_Mask) -> (int, bool) {
	for i in 0 ..< rm.bit_length / MASK_SIZE {
		i := rm.bit_length / MASK_SIZE - i - 1
		if rm.masks[i] != 0 {
			return int(i) * MASK_SIZE +
				MASK_SIZE -
				int(intrinsics.count_leading_zeros(rm.masks[i])) -
				1,
				true
		}
	}
	return -1, false
}

reg_mask_first_common_set :: proc(a, b: Reg_Mask) -> (int, bool) {
	assert(a.bit_length == b.bit_length)
	for i in 0 ..< a.bit_length / MASK_SIZE {
		inter := a.masks[i] & b.masks[i]
		if inter != 0 {
			return int(i) * MASK_SIZE +
				int(intrinsics.count_trailing_zeros(inter)),
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
	if a.kind != b.kind do ml = 0
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
	datatype_to_reg_kind: [Node_Datatype]Reg_Kind,
	spill_boundary:       []int,
	cc_table:             []Call_Conv,
	call_clobbers:        [][]i64,
	collect_meta:         proc(
		graph: ^Graph,
		ra: ^Regalloc,
		sched: ^Graph_Schedule,
	) -> (
		slots: []Regalloc_Node_Meta,
		def_count: int,
	),
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
	slots:    []#soa[]SS_Entry([^]i64),
	lens:     []int,
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
	assert(idx != INVALID_RM_INDEX)
	return {
		masks = interner.slots[idx.kind][idx.index].id,
		bit_length = interner.mask_len,
		kind = idx.kind,
	}
}

rm_intern_slice :: proc(
	interner: ^RM_Interner,
	#any_int kind: Reg_Kind,
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

INVALID_RM_INDEX :: RM_Intern_Idx(max(u16))

RM_Intern_Idx :: bit_field u16 {
	index: int      | 15,
	kind:  Reg_Kind | 1,
}

// TODO: compress this
Regalloc_Node_Meta :: struct {
	masks:         []RM_Intern_Idx,
	clobbers:      []i64,
	out:           RM_Intern_Idx,
	in_place_slot: i8,
	input_start:   u8,
}

regalloc_collect_meta :: #force_inline proc(
	graph: ^Graph,
	ra: ^Regalloc,
	sched: ^Graph_Schedule,
	meta_of: proc(
		_: ^Graph,
		_: ^Regalloc,
		_: Expanded_Node,
	) -> Regalloc_Node_Meta,
) -> (
	slots: []Regalloc_Node_Meta,
	def_count: int,
) {
	ra.rms.slots = make(type_of(ra.rms.slots), len(ra.spill_boundary))
	ra.rms.lens = make(type_of(ra.rms.lens), len(ra.spill_boundary))

	slots = make([]Regalloc_Node_Meta, int(graph.gvn) - len(sched.bbs) - 1)
	rev_count := int(graph.gvn) - len(sched.bbs)

	when !ODIN_DISABLE_ASSERT {
		seen := bit_arr.init(graph.gvn)
	}

	rev_count -= 1
	graph_get(graph, graph.start).gvn = u32(rev_count)

	idx := 0
	for bb, j in sched.bbs {
		graph_get(graph, bb.head).gvn = u32(len(slots) + 1 + j)
		for instr in bb.instrs {
			inode := graph_expand(graph, instr)
			when !ODIN_DISABLE_ASSERT {
				fmt.assertf(bit_arr.set(seen, inode.gvn), "%v", inode)
			}

			inode.gvn = u32(idx)
			idx += 1

			meta := meta_of(graph, ra, inode)

			if meta.out == INVALID_RM_INDEX {
				rev_count -= 1
				inode.gvn = u32(rev_count)
			} else {
				inode.gvn = u32(def_count)
				def_count += 1
			}

			slots[inode.gvn] = meta
			slots[inode.gvn].in_place_slot -= 1
			if slots[inode.gvn].in_place_slot >= 0 {
				slots[inode.gvn].in_place_slot += i8(
					slots[inode.gvn].input_start,
				)
			}
		}
	}

	return
}

is_def :: #force_inline proc(meta: Regalloc_Node_Meta) -> bool {
	return meta.out != INVALID_RM_INDEX
}

is_data_dep :: proc(
	meta: Regalloc_Node_Meta,
	inode: Expanded_Node,
	#any_int idx: int,
) -> bool {
	if idx < int(meta.input_start) do return false
	if idx >= min(len(meta.masks) + int(meta.input_start), len(inode.inps)) {
		return false
	}
	return true
}

data_deps :: proc(
	meta: Regalloc_Node_Meta,
	inode: Expanded_Node,
) -> []Node_ID {
	len := min(len(meta.masks), len(inode.inps) - int(meta.input_start))
	return inode.inps[meta.input_start:][:len]
}

MASK_SIZE :: size_of(int) * 8

Lrg_Meta :: bit_field u32 {
	index: u32 | 24,
	rank:  u8  | 8,
}

Lrg_Fails :: bit_field u8 {
	killed:           bool | 1,
	failed_to_color:  bool | 1,
	failed_to_assign: bool | 1,
	reg_conflict:     bool | 1,
	self_conflict:    bool | 1,
	pushed_out:       bool | 1,
}

Lrg :: struct {
	node:          Node_ID,
	using _:       Lrg_Meta,
	mask:          Reg_Mask,
	parent:        ^Lrg,
	// TODO: this should go into meta instead of the index
	using fails:   Lrg_Fails,
	reg:           i16,
	color_ord_idx: u32,
}

Slrg_ID :: distinct int

Slrg :: struct {
	start: int,
	end:   int,
	lrg:   ^Lrg,
}
