package main
// NOTE: this file is generated: odin run meta

import "core:testing"

@(test) simplest :: proc(t: ^testing.T) {
run_test(t, `
package main

return_value :: 69

main :: proc() -> int {
	return 69
}
`)
}
@(test) basic_arithmetic :: proc(t: ^testing.T) {
run_test(t, `
package main

return_value :: 7
opt_level :: "none"

main :: proc() -> int {
	return 1 + 2 * 3
}
`)
}
@(test) simple_2_adress_self_conflict :: proc(t: ^testing.T) {
run_test(t, `
package main

return_value :: 6
opt_level :: "none"

main :: proc() -> int {
	return 2 + 2 * 2
}
`)
}
@(test) more_complex_2_adress_self_conflict :: proc(t: ^testing.T) {
run_test(t, `
package main

return_value :: 18
opt_level :: "none"

main :: proc() -> int {
	return 2 + 2 * 2 + 2 * 2 + 2 * 2 + 2 * 2
}
`)
}
@(test) force_spill_with_simple_addition :: proc(t: ^testing.T) {
run_test(t, `
package main

return_value :: 32
opt_level :: "none"

main :: proc() -> int {
	return ((((1 + 1) + (1 + 1)) + ((1 + 1) + (1 + 1))) +
        (((1 + 1) + (1 + 1)) + ((1 + 1) + (1 + 1)))) +
        ((((1 + 1) + (1 + 1)) + ((1 + 1) + (1 + 1))) +
        (((1 + 1) + (1 + 1)) + ((1 + 1) + (1 + 1))))
}
`)
}
@(test) simple_varialbes :: proc(t: ^testing.T) {
run_test(t, `
package main

return_value :: 42
opt_level :: "none"

main :: proc() -> int {
	a := 2
	b, c := 7, 3 * a
	return b * c
}
`)
}
@(test) variables_that_create_register_pressure :: proc(t: ^testing.T) {
run_test(t, `
package main

return_value :: 45701539774315
opt_level :: "none"

package main

main :: proc() -> int {
	x := 0

	a0  := x + 1
	a1  := x + 2
	a2  := x + 3
	a3  := x + 4
	a4  := x + 5
	a5  := x + 6
	a6  := x + 7
	a7  := x + 8
	a8  := x + 9
	a9  := x + 10
	a10 := x + 11
	a11 := x + 12
	a12 := x + 13
	a13 := x + 14
	a14 := x + 15
	a15 := x + 16

	b0 := a0  * a15 + a1
	b1 := a1  * a14 + a2
	b2 := a2  * a13 + a3
	b3 := a3  * a12 + a4
	b4 := a4  * a11 + a5
	b5 := a5  * a10 + a6
	b6 := a6  * a9  + a7
	b7 := a7  * a8  + a0

	c0 := b0 * b4 + b1
	c1 := b1 * b5 + b2
	c2 := b2 * b6 + b3
	c3 := b3 * b7 + b0

	d0 := c0 * c2 + c1
	d1 := c1 * c3 + c2

	e0 := d0 * d1 + c3

	return e0 +
		a0 + a1 + a2 + a3 +
		a4 + a5 + a6 + a7 +
		a8 + a9 + a10 + a11 +
		a12 + a13 + a14 + a15
}
`)
}
