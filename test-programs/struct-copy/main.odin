package main

Big :: struct {
	a: int,
	b: int,
	c: int,
	d: int,
}

// Copying through pointers the optimizer cannot prove disjoint keeps the memcpy
// alive, exercising the .Data relocation towards libc.
copy_big :: proc(dst: ^Big, src: ^Big) {
	dst^ = src^
}

main :: proc() -> int {
	x := Big{1, 2, 3, 4}
	y := Big{}
	copy_big(&y, &x)
	return y.a + y.b + y.c + y.d // 10
}
