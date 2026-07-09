package main

import "myfmt"
import "mymath"

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

	// x + y + z = 123, check = -42 + 255 + 10 + 511 + 1 = 735,
	// global_accum = 127
	return x + y + z + check + global_accum // 985
}
