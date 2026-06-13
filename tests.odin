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
