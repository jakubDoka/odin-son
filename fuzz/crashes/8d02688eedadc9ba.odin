
package main

En :: enum {
	A,
	B,
}

Un :: union {
	int,
	f32,
}

main :: proc() -> int {
	e := En.C
	f: En = .D
	u: Un = "str"
	v := u.(bool)
	w := 1
	switch x in w {
	case int:
	}
	switch ^ in u {
	case bool:
	}
	return 0
}
