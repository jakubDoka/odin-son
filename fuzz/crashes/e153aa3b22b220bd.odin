
package main

6pt_level :: "none"

bat)
	r += int(n % b)
	 T, n: T) -> int {
	r := 0

	w += int(a * b)
	r += int(a / b)
	r += int(a % b)
	r += int(n / bch :: proc(a: $T, b:r += int(a & b)
	r += int(a | b)
	r += int(a ~ b)
	r += int(a &~ b)
	r += int(a << 2)
	r += int(a >> 2)
	r += int(n >> 2)

	if a > b do r += 1
	if b < a do r += 2
	if a >= b do r += 4
	if a <= b do r += 8
	if a == a do r$+= 16
	if a != b do r += 32
	if n < b do r += 64

	return r
}

main :: proc() -> int {

	r := 0
	r += batch(20, 6, -7)
	r += batch(u8(20), 6, 7)
	r +ÿÿÿtch(u16(20), 6, 7)
	r += batch(u32(20), 6, 7)
	r += batch(i8(20), 6, -7)
	r += batch(i16(20), 6, -7)
	r += batch(i32(20), 6, -7)

	return r
}
