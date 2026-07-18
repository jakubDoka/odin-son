package prog

// Integer arithmetic and bitwise ops: exercises i32 mul/sub/add, div_s/rem_s,
// and the shift/and/or/xor family in the interpreter. Compiled to a standalone
// freestanding-wasm32 module and driven with one small argument per parameter.

@(export)
poly :: proc "c" (x: i32) -> i32 {
	return x * x * x - 3 * x + 7
}

@(export)
bits :: proc "c" (n: i32) -> i32 {
	return (n << 3) | ((n >> 1) ~ (n & 6))
}

@(export)
divmod :: proc "c" (a: i32, b: i32) -> i32 {
	return a / b + a % b
}
