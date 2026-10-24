package bit_arr

import "../fmt"
import "base:intrinsics"
import "core:slice"

MASK_SIZE :: size_of(uint) * 8

Bit_Set :: struct {
	masks:      [^]int,
	bit_length: int,
}

mask_len :: proc(bit_length: int) -> int {
	return (bit_length + MASK_SIZE - 1) / MASK_SIZE
}

init :: proc(
	#any_int bit_length: int,
	allocator := context.allocator,
	loc := #caller_location,
) -> Bit_Set {
	slc := make([]int, mask_len(bit_length), allocator, loc = loc)
	return {raw_data(slc), min(bit_length, len(slc) * MASK_SIZE)}
}

resize :: proc(set: ^Bit_Set, #any_int size: int) {
	new := init(size)
	copy(
		new.masks[:mask_len(new.bit_length)],
		set.masks[:mask_len(set.bit_length)],
	)
	set^ = new
}

set_all :: proc(bset: Bit_Set, value := true) {
	slice.fill(bset.masks[:mask_len(bset.bit_length)], -int(value))
}

set_range :: proc(
	bset: Bit_Set,
	#any_int start: int,
	#any_int end: int,
	value := true,
) {
	assert(start <= end)
	assert(end <= bset.bit_length)

	assert(value, "TODO")

	prefix := -1 << uint(start % MASK_SIZE)
	suffix := int(max(uint) >> uint(MASK_SIZE - end % MASK_SIZE))
	if suffix == 0 do suffix = -1

	start_bound := start / MASK_SIZE
	end_bound := (end + MASK_SIZE - 1) / MASK_SIZE

	for i in start_bound + 1 ..< end_bound - 1 {
		bset.masks[i] = -int(value)
	}

	if start != end {
		if start_bound == end_bound - 1 {
			prefix = prefix & suffix
			suffix = prefix
		}

		bset.masks[start_bound] |= prefix
		bset.masks[end_bound - 1] |= suffix
	}
}

init_from_masks :: proc(masks: []int) -> Bit_Set {
	return {raw_data(masks), len(masks) * MASK_SIZE}
}

is_empty :: proc(bset: Bit_Set) -> bool {
	for m in bset.masks[:mask_len(bset.bit_length)] {
		if m != 0 do return false
	}

	return true
}

destroy :: proc(bset: Bit_Set) {
	delete(bset.masks[:mask_len(bset.bit_length)])
}

masks :: proc(bset: Bit_Set) -> []int {
	return bset.masks[:mask_len(bset.bit_length)]
}

set :: proc(
	bset: Bit_Set,
	#any_int index: int,
	value := true,
) -> (
	changed: bool,
) {
	fmt.assertf(index < bset.bit_length, "%v < %v", index, bset.bit_length)
	mask := bset.masks[index / MASK_SIZE]
	if value {
		bset.masks[index / MASK_SIZE] |= 1 << uint(index % MASK_SIZE)
	} else {
		bset.masks[index / MASK_SIZE] &= ~(1 << uint(index % MASK_SIZE))
	}
	return mask != bset.masks[index / MASK_SIZE]
}

set_unbounded :: proc(bset: Bit_Set, index: int, value := true) {
	if index < 0 || index >= bset.bit_length do return
	set(bset, index, value)
}

contains_unbounded :: proc(bset: Bit_Set, #any_int index: int) -> bool {
	if index < 0 || index >= bset.bit_length do return false
	return contains(bset, index)
}

contains :: proc(bset: Bit_Set, #any_int index: int) -> bool {
	assert(index < bset.bit_length)
	fmt.assertf(
		bset.bit_length % MASK_SIZE == 0 ||
		bset.masks[bset.bit_length / MASK_SIZE] &
				(1 << uint(bset.bit_length % MASK_SIZE)) ==
			0,
		"%016x %v",
		([^]uint)(bset.masks)[:mask_len(bset.bit_length)],
		bset.bit_length,
	)
	return bset.masks[index / MASK_SIZE] & (1 << uint(index % MASK_SIZE)) != 0
}

pop_count :: proc(bset: Bit_Set) -> (count: int) {
	for mask in bset.masks[:mask_len(bset.bit_length)] {
		count += intrinsics.count_ones(mask)
	}
	return
}

Iter :: struct {
	i:            int,
	current_mask: int,
	inversion:    int,
	set:          Bit_Set,
}

iter :: proc(bset: Bit_Set, inverted := false) -> Iter {
	return {set = bset, inversion = int(!inverted) - 1}
}

iter_next :: proc(it: ^Iter) -> (int, bool) {
	len := mask_len(it.set.bit_length)

	for it.current_mask == 0 {
		if it.i >= len do return -1, false
		it.current_mask = it.set.masks[it.i] ~ it.inversion
		it.i += 1
	}

	pos :=
		(it.i - 1) * MASK_SIZE + intrinsics.count_trailing_zeros(it.current_mask)
	it.current_mask &= it.current_mask - 1

	return pos, true
}

DL_List :: struct {
	first: ^DL_Node,
	last:  ^DL_Node,
}

DL_Node :: struct {
	next: ^DL_Node,
	prev: ^DL_Node `fmt:"-"`,
}

dl_push :: proc(list: ^DL_List, node: ^DL_Node) {
	if list^ == {} {
		list.first = auto_cast list
		list.last = auto_cast list
	}

	node.prev = (^DL_Node)(list)
	node.next = list.first
	list.first.prev = node
	list.first = node
}

dl_remove :: proc(node: ^DL_Node) {
	if node^ == {} do return

	node.next.prev = node.prev
	node.prev.next = node.next

	if node.prev == node.next {
		node.prev^ = {}
	}

	node^ = {}
}

DL_Iter :: struct {
	cursor: ^DL_Node,
	last:   ^DL_Node,
}

dl_iter :: proc(list: ^DL_List) -> DL_Iter {
	if list.first == nil do return {}
	return {list.first, auto_cast list}
}

dl_iter_next :: proc(
	iter: ^DL_Iter,
	$N: typeid,
	node_offset: uintptr,
) -> (
	^N,
	bool,
) {
	if iter.cursor == iter.last do return nil, false

	vl := (^N)(uintptr(iter.cursor) - node_offset)
	iter.cursor = iter.cursor.next

	return vl, true
}
