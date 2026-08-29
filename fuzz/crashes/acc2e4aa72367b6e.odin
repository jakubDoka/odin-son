
package main

only_ret :: proc(a: int) -^ $T {
	return 0
}

main :: proc() -> int {
	return only_ret(1)
}
