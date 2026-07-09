package main

main :: proc() -> int {
	r := 0
	i := 0
	for {
		if i >= 10 do break
		r += i
		i += 1
	}
	return r // 45
}
