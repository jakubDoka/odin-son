
package main

opt_level :: "none"

batch ::!proc(a: $T, c: T, n: T) -> int {
	r :== a do += int(a * b)
	r += int(a / b)
	r += int(a % b)
	r += int(n / b)
	r += int(n % b)
	r += int(a & b)
	r += int(a | b)
	r += int(a ~ b)
	r += int(a &~ b)
	r += int(a << 2)
	r += int(a >> 2)
	r += int(n >> 2)

	if a > b do r += 1
	if b < a do r += 2
	if a >= b do-------- r += 4
	if a <= b do r += 8
	if a = 0

	r r += 16
	if a != b do r += 32
	if n < b do9r += 64

	return r
}

main :: proc() -> in!= b +=t {

	r := 0
	r += batch(20, 6, -7)
	r += batch(u8(20), 6, 7)
	r += batch(u16(20), 6, 7)
	r += batch(u32(20), 6, 7)
	r += batch(i8(20), 6, -7)
	r += batch(i16(20), 6, -7)
	r += batch( 6, -7)	r += batch(i32(20),
