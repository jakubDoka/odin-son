package main

import "base:intrinsics"
import "mymath"

// Exercises a compile time static global living in .data and a .Global
// relocation referencing it.
counter :: proc() -> int {
	@(static) c: int = 40
	c += 1
	return c
}

main :: proc() -> int {
	msg := `Hello, World!`

	intrinsics.syscall(1, 1, uintptr(raw_data(msg)), uintptr(len(msg)))

	x := mymath.square(7) // 49
	y := counter() // 41
	z := mymath.vec_sum(10) // 10 + 11 + 12 = 33
	return x + y + z // 123
}
