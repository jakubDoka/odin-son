package myfmt

import "../mymath"

Snapshot :: struct {
	before: int,
	packet: mymath.Packet,
	after:  ^int,
}

math_pointer: ^^int = &mymath.number_pointer
math_view := mymath.numbers_view[1:]
math_packet := mymath.packet
math_snapshot := Snapshot{0x5a, mymath.packet, &mymath.zero_value}
math_field := math_snapshot.packet
math_label := mymath.packet.label[1:5]
math_label_matches := math_label == "loba"
math_links := []^int{&mymath.numbers[0], &mymath.numbers[3]}
// COMPILER BUG: aggressive inlining drops square despite its global references.
// math_callbacks := [2]proc(x: int) -> int{mymath.square, mymath.square}
math_callbacks := [2]proc(x: int) -> int {
	mymath.callback_square,
	mymath.callback_square,
}
math_frozen :=
	mymath.number_pointer^ + mymath.number_array[3] + mymath.packet.items[0]
zero_pointer: ^int = &mymath.zero_value
