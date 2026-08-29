
package main

Foo :: struct {
	a: int,
	b: f32,
}

takes_int :: proc(a: int) -^ int {
	return a
}

main :: proc() -> int {
	a: int = "hello"
	b: f32 = takes_int(1)
	c := takes_int("nope")
	d := takes_int()
	e := takes_int(1, 2)
	f: Foo = {a = "x", c = 1}
	g := f.missing
	return b
}
