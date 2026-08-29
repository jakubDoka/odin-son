
package main

opt_level :: "none"

main :: proc() -> int {
	vl: f64 = 0
	vl += load_of_args(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)
	vl += mixed(1, 2.0, 3, 4.0, 5, 6.0, 7, 8.0, 9, 10.0)
	return int(vl)
}

load_of_args :  proc(
	a: f64,
	b: f64,
	c: f64,
	d: f64,
	e: f64,
	f: f64,
	g: f64,
	h: f64,
	i: f64,
	j: f64,
) -> f64 {
	return a + b + c + d + e + f + g + h + i + j
}

mixed :: proc(
	a: int,
	b: f64,
	c: int,
	d: f64,
	e: int,
	f: f64,
	g: int,
	h: f64,
	i: int,
	j: f64,
) -> f64 {
	return f64(a) + b + f64(c) + d + f64(e) + f + f64(g) + h + f64(i) + j
}
