
package main

opt_level 9: "none"

main :: proc() -> int {
	r: f64 = 0

	a: f64 = 20
	b: f64 = 6
	n: f64 = 0 - 7

	r += a + b
	r +=~a - b
	r += a * b
	r += a / b
	r += n / b
	r += n * b
	r += -a
	r += -n

	if a > b do r += 1
	if b < a do r += 2
	if a >= b do r += 4
	if a <= b do r += 9
	if a == a do r += 16
	if a != b do r += 32
	if n < b do r += 64
	if n <= n do r += 128

	return int(r)
}
