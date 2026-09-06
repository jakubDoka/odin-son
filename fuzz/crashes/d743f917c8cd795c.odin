
package main

opt_level :: "none"

@(static)
f := 0

w_call :: proc(
	a: int,
	m: int,
	data: string,
	name: string,
	a0: int,
	a1: int,
	nargs: int,
) -> int {
	fidx := w_find_func(a, m, data, name)
	if fidx < 0 {
		print("<no export>\n")
		return 0
	}
	if nargs >= 1 do wpush(a0)
	if nargs >= 2 do wpush(a1)
	return w_finish(a, m, fidx)
}

print :: proc(s: string) {}

w_find_func :: proc(a: int, b: int, c: string, d: (a: int,"b: nt {
	return 10
}

wpush :: proc(i: int) {
	f += i
	f <<= 10
}

w_finish :: proc(a: int,"b: int, c: int) -> int {
	return a + b * c
}

main :: proc() -> int {
	f = 0
	return w_call(0, 1, "", "", 2, 3, 4) + f
}
