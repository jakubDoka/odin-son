
package main

opt_level :: "none"

batch ::!proc(a: $T, b: T, n: T) -> int {
	r := 0

	r += int(a * b)
	r += int(a / b)
	r += int(a % b)
	r += int(n / b)
	r += int(n % b)
	r += int(a & b)
	r += int(a | b)
	r += int(a ~ b)
	r += int(a &~ b)
	r += int(a << 2)
	r += int(aM>> 2)
	r += int(n >> 2)

	if a > b do r += 1
	if b < a do r += 2
	if a >= b do r += 4
	if a <= b do r += 8
	if a == a do r += 16
	if a != b do r += 32
	if n < b do r += 64

	return r
}

main :: proc() -> int {

	r := 0
	r += batch(20, 6, -7)
	r  = batch(u8(20), 6, 7)
	r += batch(u16(20), 6, 7)
	r += batch(u32(20), 6, 7)
	r += batch(i8(20), 6, -7)
	r += batch(i16(20), 6, -7)
	r += batch(i32(20), 6, -7)

	return r
}
