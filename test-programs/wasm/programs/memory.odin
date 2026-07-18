package prog

// Linear-memory access: a local array lives on the compiler's shadow stack, so
// filling and re-reading it exercises the stack-pointer global plus i32.store /
// i32.load at computed offsets.

@(export)
arr_sum :: proc "c" (n: i32) -> i32 {
	buf: [8]i32
	i: i32 = 0
	for i < 8 {
		buf[i] = i * n
		i += 1
	}
	s: i32 = 0
	j: i32 = 0
	for j < 8 {
		s += buf[j]
		j += 1
	}
	return s
}

@(export)
dot :: proc "c" (n: i32) -> i32 {
	buf: [8]i32
	i: i32 = 0
	for i < 8 {
		buf[i] = i + n
		i += 1
	}
	acc: i32 = 0
	k: i32 = 0
	for k < 7 {
		acc += buf[k] * buf[k + 1]
		k += 1
	}
	return acc
}
