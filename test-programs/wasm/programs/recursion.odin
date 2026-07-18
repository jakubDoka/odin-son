package prog

// Recursion and iterative reductions: direct self-calls (call), plus loops that
// mix remainder, comparison and branch. All well-behaved for small arguments.

@(export)
fib :: proc "c" (n: i32) -> i32 {
	if n < 2 {
		return n
	}
	return fib(n - 1) + fib(n - 2)
}

@(export)
gcd :: proc "c" (a: i32, b: i32) -> i32 {
	x := a
	y := b
	for y != 0 {
		t := x % y
		x = y
		y = t
	}
	return x
}

@(export)
collatz :: proc "c" (n: i32) -> i32 {
	v := n
	steps: i32 = 0
	for v > 1 {
		if (v & 1) == 0 {
			v = v / 2
		} else {
			v = 3 * v + 1
		}
		steps += 1
	}
	return steps
}
