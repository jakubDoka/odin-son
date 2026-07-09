package mymath

square :: proc(x: int) -> int {
	return x * x
}

add :: proc(a: int, b: int) -> int {
	return a + b
}

// A struct wider than 16 bytes so the by-value copy is lowered to a memcpy,
// exercising the .Data relocation towards libc.
Vec :: struct {
	x: int,
	y: int,
	z: int,
}

vec_sum :: proc(a: int) -> int {
	v := Vec{a, a + 1, a + 2}
	w := v
	return w.x + w.y + w.z
}
