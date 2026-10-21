package main

main :: proc() -> int {
	return int(process(10, 100))
}

@(tag = "gpu")
process :: proc(a, b: f32) -> f32 {
	return a + b * b / a
}
