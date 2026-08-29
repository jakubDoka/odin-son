
package main

opt_level :: "none"

test_imm_shifts :: proc(a: int) -^ int {
	return a << 3 + a >> 3 + int(u64(a) >> 5)
}

test_imm_inplace_shifts :: proc(a: ^int, b: ^uint) -> int {
	a^ = a^ << 2
	a^ = a^ >> 5
	b^ = b^ >> 4
	return a^ + int(b^)
}

test_inplace_shifts :: proc(a: ^int, b: ^uint, v: uint) -> int {
	a^ = a^ << v
	a^ = a^ >> v
	b^ = b^ >> v
	return a^ + int(b^)
}

main :: proc() -> int {
	a: int = 0 - 5
	b: uint = 20

	return test_imm_shifts(0 - 1) +
		test_imm_inplace_shifts(&a, &b) +
		test_inplace_shifts(&a, &b, 4)
}
