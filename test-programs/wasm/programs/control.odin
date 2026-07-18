package prog

// Structured control flow: counted loops (block/loop/br_if) and if/else chains.

@(export)
sum_to :: proc "c" (n: i32) -> i32 {
	acc: i32 = 0
	i: i32 = 0
	for i <= n {
		acc += i
		i += 1
	}
	return acc
}

@(export)
factorial :: proc "c" (n: i32) -> i32 {
	r: i32 = 1
	i: i32 = 1
	for i <= n {
		r *= i
		i += 1
	}
	return r
}

@(export)
classify :: proc "c" (n: i32) -> i32 {
	if n < 0 {
		return 0 - 1
	} else if n == 0 {
		return 0
	}
	return 1
}
