package main

import "base:intrinsics"

Point :: struct {
	x: int,
	y: i32,
}

global_value: int = 91

inspect :: proc(arg: int) {
	value := arg + 5
	negative: i32 = -17
	unsigned_value: u16 = 65000
	point := Point{7, 11}
	pointer := &point
	value += 9
	intrinsics.trap()
}

main :: proc() -> int {
	inspect(28)
	return 0
}
