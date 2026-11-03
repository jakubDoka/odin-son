package mymath

Packet :: struct {
	value: ^int,
	items: []int,
	label: string,
	apply: proc(x: int) -> int,
}

Node :: struct {
	value: int,
	next:  ^Node,
}

Scalars :: struct {
	signed:   i8,
	unsigned: u16,
	fraction: f32,
}

number_chain: ^^int = &number_pointer
number_pointer: ^int = &numbers[2]
number_array: ^[4]int = &numbers
numbers := [4]int{0x10, 0x20, 0x30, 0x40}
numbers_view := numbers[1:4]
numbers_data := raw_data(number_array)
numbers_tail := numbers_data[2:]
numbers_bounded := numbers_tail[:2]
array_view := number_array[1:3]
zero_value: int
head: Node = {0x12, &tail}
tail: Node = {0x23, nil}

// COMPILER BUG: aggressive inlining drops square despite its global references.
// packet := Packet{&numbers[1], numbers[2:], "gl\x6fbals", square}
packet := Packet{&numbers[1], numbers[2:], "gl\x6fbals", callback_square}
packet_copy := packet
nil_pointer: ^int = nil
nil_callback: proc(x: int) -> int = nil
nil_items: []int = nil

text: string = "a\x62\x00cdef"
text_middle := text[1:5]
text_suffix := text_middle[2:]
text_data := raw_data(text_middle)
text_matches := text_middle == "b\x00cd" && text_suffix == "cd"
text_initial := int(text[2]) + int(text_data[3]) + len(text_suffix)

scalars := Scalars{-0x12, 0xff00, 1.5}
scalar_initial :=
	int(scalars.signed) + int(scalars.unsigned) + int(scalars.fraction * 2)
absolute: ^int = cast(^int)uintptr(0x1230)
absolute_raw := rawptr(absolute)
absolute_address := uintptr(absolute_raw)
pointer_matches :=
	absolute == cast(^int)uintptr(0x1230) &&
	absolute != nil &&
	nil_pointer == nil &&
	nil_callback == nil &&
	packet.apply == callback_square
pointer_distinct := &numbers[0] != &zero_value
pointer_ordered :=
	&numbers[0] < &numbers[3] &&
	&numbers[1] <= &numbers[1] &&
	absolute > cast(^int)uintptr(0x1200)

callback_square :: proc(x: int) -> int {
	return x * x
}
