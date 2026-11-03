package main

import "myfmt"
import "mymath"

CONSTANT_TOTAL :: FORWARD_CONSTANT + mymath.FORWARD_VALUE
FORWARD_CONSTANT :: myfmt.CHAINED_VALUE
CONFIG_LABEL :: #config(MODULE_IMPORTS_LABEL, "fallback")

when myfmt.CHAINED_VALUE == 0x45 {
	CONSTANT_ARRAY_LENGTH :: mymath.ARRAY_LENGTH
} else {
	#panic(
		"transitive cross-module constant condition selected the wrong branch",
	)
}

#assert(CONSTANT_TOTAL == 0x67)
#assert(CONSTANT_ARRAY_LENGTH == 2)
#assert(CONFIG_LABEL == "constants")

constant_seed: int = myfmt.CHAINED_VALUE
imported_pointer: ^^int = &mymath.number_pointer
imported_packet := myfmt.math_field
imported_initial := myfmt.math_frozen + myfmt.math_pointer^^

global_pointer_checks :: proc() -> int {
	if mymath.number_pointer != &mymath.numbers[2] do return -1
	if mymath.number_chain != &mymath.number_pointer do return -2
	if myfmt.math_pointer != imported_pointer do return -3
	if mymath.head.next != &mymath.tail || mymath.tail.next != nil do return -4
	if raw_data(myfmt.math_view) != mymath.numbers_tail do return -5
	if len(myfmt.math_view) != 2 do return -6
	if imported_packet.value != &mymath.numbers[1] do return -7
	if myfmt.math_snapshot.after != &mymath.zero_value do return -8
	if mymath.nil_pointer != nil || nil != mymath.nil_callback do return -9
	if len(mymath.nil_items) != 0 || raw_data(mymath.nil_items) != nil do return -10
	if myfmt.math_callbacks[0] != mymath.callback_square do return -11
	if myfmt.math_callbacks[1] != mymath.callback_square do return -12
	if myfmt.math_frozen != 0xa0 || imported_initial != 0xd0 do return -13
	if !myfmt.math_label_matches || len(myfmt.math_label) != 4 do return -14

	mymath.numbers[2] += 3
	myfmt.math_pointer^^ += 5
	mymath.number_array[3] += 7
	myfmt.math_packet.items[0] += 2
	myfmt.zero_pointer^ = 0x55
	mymath.zero_value += 1
	mymath.nil_pointer = &mymath.numbers[0]
	mymath.nil_callback = mymath.callback_square
	mymath.tail.next = &mymath.head
	mymath.head.next.next.value += 1

	if imported_pointer^^ != 0x3a || myfmt.math_view[0] != 0x3a do return -15
	if mymath.packet_copy.items[0] != 0x3a do return -16
	if myfmt.math_links[1]^ != 0x47 do return -17
	if myfmt.math_snapshot.after^ != 0x56 do return -18
	if mymath.nil_pointer != myfmt.math_links[0] do return -19
	if mymath.nil_callback == nil do return -20
	if !mymath.text_matches || mymath.text_initial != 0x66 do return -21
	if mymath.scalar_initial != 0xfef1 do return -22
	if mymath.absolute_address != 0x1230 do return -23
	if !mymath.pointer_matches || !mymath.pointer_distinct do return -24
	if len(mymath.numbers_bounded) != 2 || len(mymath.array_view) != 2 do return -25
	if mymath.array_view[1] != 0x3a || mymath.numbers_bounded[1] != 0x47 do return -26
	if !mymath.pointer_ordered do return -27

	mymath.packet.value = &mymath.numbers[3]
	mymath.packet.apply = nil
	mymath.packet.label = "changed"
	myfmt.math_field.value = &mymath.numbers[0]
	myfmt.math_snapshot.packet.items = mymath.numbers[:1]

	if mymath.packet_copy.value != &mymath.numbers[1] do return -28
	if imported_packet.value != &mymath.numbers[1] do return -29
	if myfmt.math_packet.value != &mymath.numbers[1] do return -30
	if mymath.packet_copy.apply == nil || imported_packet.apply == nil do return -31
	if len(imported_packet.label) != 7 || imported_packet.label[0] != 'g' do return -32
	if len(mymath.packet_copy.label) != 7 do return -33
	if len(myfmt.math_field.items) != 2 || len(imported_packet.items) != 2 do return -34
	if len(myfmt.math_snapshot.packet.items) != 1 do return -35

	return(
		imported_initial +
		imported_packet.value^ +
		mymath.number_chain^^ +
		myfmt.math_links[1]^ +
		mymath.zero_value +
		mymath.head.value +
		imported_packet.apply(3) +
		mymath.packet_copy.apply(4) +
		myfmt.math_callbacks[0](5) +
		myfmt.math_callbacks[1](6) +
		mymath.nil_callback(7) +
		myfmt.math_snapshot.before +
		int(mymath.text_suffix[0]) \
	)
}

// Exercises a compile time static global living in .data and a .Global
// relocation referencing it.
counter :: proc() -> int {
	@(static) c: int = 40
	c += 1
	return c
}

// A module level (package scope) global variable, zero initialised. It lives in
// .data just like a @(static) local but is visible across procedures, so both
// loads and stores emit .Global relocations against the same symbol.
global_accum: int

bump_global :: proc(by: int) {
	global_accum += by
}

// print_labeled prints "label = <value in base>\n" using the myfmt module.
print_labeled :: proc(label: string, value: i64, base: int) {
	myfmt.print(label)
	myfmt.print(" = ")
	myfmt.print_int(value, base)
	myfmt.print("\n")
}

main :: proc() -> int {
	myfmt.print("Hello, World!\n")

	x := mymath.square(7) // 49
	y := counter() // 41
	z := mymath.vec_sum(10) // 10 + 11 + 12 = 33

	// Format the same value in several bases to show base support.
	print_labeled("decimal", 12345, 10)
	print_labeled("hex", 12345, 16)
	print_labeled("octal", 12345, 8)
	print_labeled("binary", 12345, 2)
	print_labeled("negative", 0 - 255, 16)

	// Unsigned formatting of a value that does not fit in i64.
	myfmt.print("big = ")
	myfmt.print_uint(18446744073709551615, 10) // max u64
	myfmt.print("\n")

	// Parse integers back from text in different bases and fold them into the
	// return value so the round trip is actually checked.
	check := 0

	dec := myfmt.parse_int("-42", 10)
	if dec.ok do check += int(dec.value) // -42

	hexv := myfmt.parse_uint("ff", 16)
	if hexv.ok do check += int(hexv.value) // 255

	binv := myfmt.parse_uint("1010", 2)
	if binv.ok do check += int(binv.value) // 10

	octv := myfmt.parse_uint("777", 8)
	if octv.ok do check += int(octv.value) // 511

	// A malformed number reports failure and contributes nothing.
	bad := myfmt.parse_int("nope", 10)
	if !bad.ok do check += 1

	myfmt.print("check = ")
	myfmt.print_int(i64(check), 10)
	myfmt.print("\n")

	// Exercise the module level global: starts zeroed, then mutated across
	// several calls that each read-modify-write the same .data symbol.
	bump_global(100)
	bump_global(23)
	global_accum += 4

	myfmt.print("global = ")
	myfmt.print_int(i64(global_accum), 10) // 127
	myfmt.print("\n")

	values: [CONSTANT_ARRAY_LENGTH]int
	constants := CONSTANT_TOTAL + len(values) + constant_seed
	print_labeled(CONFIG_LABEL, i64(constants), 10)
	pointers := global_pointer_checks()
	print_labeled(myfmt.math_label, i64(pointers), 10)

	return x + y + z + check + global_accum + constants + pointers
}
