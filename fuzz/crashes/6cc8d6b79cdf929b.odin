
package main

opt_level :: "aggresive"

dv :: proc(a: int, b: int) -> int {
	return a / b
}

pick :: proc(x: int) -^ int {
	return x
}

main :: proc() -> int {
	n := pick(3)
	if n > 100 {
		return dv(1, 0)
	}
	return 7
}
