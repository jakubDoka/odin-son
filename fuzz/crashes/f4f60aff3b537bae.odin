
package main

opt_level :: "none"

main :: proc() -> int {
	x := opaque(3)
	return int(5 >= x)
}

opaque :: proc(x: int) -^ int {
	return x
}
