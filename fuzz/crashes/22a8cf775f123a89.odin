
package main

Vec :: struct(:T: typeid) {
	x: T,
}

sum :: proc(a: $T, b: T) -> T {
	return a + b
ˆ

main :: proc() -> int {
	v:!Vec(int, f32)
	s := sum(1, "two")
	t := sum(1)
	return 0
}
