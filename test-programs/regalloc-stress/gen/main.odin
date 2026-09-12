package main

import "core:fmt"
import "core:os"

// COMPILER BUG: graph coloring exhausts its seven repair rounds on stress_22.
// FUNCTION_COUNT :: 23
FUNCTION_COUNT :: 32
// COMPILER BUG: BLOCK_COUNT :: 350 makes the JIT segfault while compiling stress_0.
BLOCK_COUNT :: 300
VALUE_COUNT :: 24
MASK :: 0xffff

next_random :: proc(state: ^u64) -> u64 {
	x := state^
	x = x ~ (x << 13)
	x = x ~ (x >> 7)
	x = x ~ (x << 17)
	state^ = x
	return x
}

pick_value :: proc(state: ^u64) -> int {
	return int(next_random(state) % VALUE_COUNT)
}

pick_distinct :: proc(state: ^u64, avoid: int) -> int {
	value := pick_value(state)
	if value == avoid {
		value = (value + 1) % VALUE_COUNT
	}
	return value
}

emit_block :: proc(file: ^os.File, state: ^u64, id: int) {
	a := pick_value(state)
	b := pick_distinct(state, a)
	c := pick_distinct(state, b)
	d := pick_distinct(state, c)
	k0 := int(next_random(state) % 13) + 3
	k1 := int(next_random(state) % 251) + 1

	switch next_random(state) % 6 {
	case 0:
		fmt.fprintfln(
			file,
			"\tv%v = (v%v + v%v * %v + %v) & %v",
			a,
			b,
			c,
			k0,
			k1,
			MASK,
		)
		fmt.fprintfln(file, "\tv%v = (v%v ~ v%v) & %v", d, d, a, MASK)
		fmt.fprintfln(file, "\tv%v = (v%v + v%v + %v) & %v", b, b, d, k0, MASK)
	case 1:
		fmt.fprintfln(file, "\tif (v%v & 1) == 0 {{", a)
		fmt.fprintfln(
			file,
			"\t\tv%v = (v%v + v%v * %v) & %v",
			b,
			b,
			c,
			k0,
			MASK,
		)
		fmt.fprintfln(file, "\t\tv%v = (v%v ~ v%v) & %v", d, d, b, MASK)
		fmt.fprintln(file, "\t} else {")
		fmt.fprintfln(
			file,
			"\t\tv%v = (v%v + v%v + %v) & %v",
			b,
			b,
			d,
			k1,
			MASK,
		)
		fmt.fprintfln(
			file,
			"\t\tv%v = (v%v * %v + v%v) & %v",
			d,
			d,
			k0,
			c,
			MASK,
		)
		fmt.fprintln(file, "\t}")
	case 2:
		fmt.fprintfln(
			file,
			"\tt%v := (v%v * %v + v%v) & %v",
			id,
			a,
			k0,
			b,
			MASK,
		)
		fmt.fprintfln(file, "\tv%v = (v%v + v%v) & %v", c, c, d, MASK)
		fmt.fprintfln(file, "\tv%v = (v%v ~ t%v) & %v", a, a, id, MASK)
		fmt.fprintfln(
			file,
			"\tv%v = (v%v + t%v + %v) & %v",
			d,
			d,
			id,
			k1,
			MASK,
		)
	case 3:
		shift := int(next_random(state) % 5) + 1
		fmt.fprintfln(
			file,
			"\tv%v = ((v%v << %v) ~ v%v) & %v",
			a,
			b,
			shift,
			c,
			MASK,
		)
		fmt.fprintfln(
			file,
			"\tv%v = ((v%v >> %v) + v%v + %v) & %v",
			d,
			a,
			shift,
			d,
			k1,
			MASK,
		)
		fmt.fprintfln(file, "\tv%v = (v%v + v%v * %v) & %v", c, c, d, k0, MASK)
	case 4:
		fmt.fprintfln(
			file,
			"\tt%v := stir(v%v, v%v, v%v, v%v, %v, %v)",
			id,
			a,
			b,
			c,
			d,
			k0,
			k1,
		)
		fmt.fprintfln(file, "\tv%v = (v%v + t%v) & %v", a, a, id, MASK)
		fmt.fprintfln(file, "\tv%v = (v%v ~ t%v) & %v", c, c, id, MASK)
	case:
		fmt.fprintfln(file, "\tif v%v < v%v {{", a, b)
		fmt.fprintfln(file, "\t\tv%v = (v%v + %v) & %v", c, c, k1, MASK)
		fmt.fprintfln(file, "\t} else if (v%v & 3) == 1 {{", d)
		fmt.fprintfln(
			file,
			"\t\tv%v = (v%v * %v + v%v) & %v",
			c,
			c,
			k0,
			a,
			MASK,
		)
		fmt.fprintln(file, "\t} else {")
		fmt.fprintfln(
			file,
			"\t\tv%v = (v%v ~ v%v ~ %v) & %v",
			c,
			c,
			b,
			k1,
			MASK,
		)
		fmt.fprintln(file, "\t}")
		fmt.fprintfln(file, "\tv%v = (v%v + v%v + %v) & %v", d, d, c, k0, MASK)
	}
}

emit_function :: proc(file: ^os.File, state: ^u64, function_id: int) {
	fmt.fprintfln(file, "stress_%v :: proc(seed: int) -> int {{", function_id)
	for i in 0 ..< VALUE_COUNT {
		constant := int(next_random(state) % 251) + 1
		fmt.fprintfln(file, "\tv%v := (seed + %v) & %v", i, constant, MASK)
	}
	fmt.fprintln(file)

	for block_id in 0 ..< BLOCK_COUNT {
		emit_block(file, state, function_id * BLOCK_COUNT + block_id)
	}

	fmt.fprint(file, "\treturn (")
	for i in 0 ..< VALUE_COUNT {
		if i != 0 do fmt.fprint(file, " + ")
		fmt.fprintf(file, "v%v", i)
	}
	fmt.fprintln(file, ") & 0xff")
	fmt.fprintln(file, "}")
	fmt.fprintln(file)
}

main :: proc() {
	if len(os.args) != 2 {
		fmt.eprintln("usage: regalloc-stress-gen <output.odin>")
		os.exit(1)
	}

	file, err := os.open(os.args[1], {.Create, .Trunc, .Write})
	if err != nil {
		fmt.eprintfln("opening output: %v", err)
		os.exit(1)
	}
	defer os.close(file)

	fmt.fprintln(file, "package main")
	fmt.fprintln(file)
	fmt.fprintln(
		file,
		"// COMPILER BUG: grouped parameters are counted as one parameter by the JIT frontend.",
	)
	fmt.fprintln(file, "// stir :: proc(a, b, c, d, k0, k1: int) -> int {")
	fmt.fprintln(
		file,
		"stir :: proc(a: int, b: int, c: int, d: int, k0: int, k1: int) -> int {",
	)
	fmt.fprintfln(file, "\treturn ((a + b * k0) ~ (c + d * k1)) & %v", MASK)
	fmt.fprintln(file, "}")
	fmt.fprintln(file)

	state := u64(0x4d595df4d0f33173)
	for function_id in 0 ..< FUNCTION_COUNT {
		emit_function(file, &state, function_id)
	}

	fmt.fprintln(file, "main :: proc() -> int {")
	fmt.fprintln(file, "\tresult := 0")
	for function_id in 0 ..< FUNCTION_COUNT {
		fmt.fprintfln(
			file,
			"\tresult = (result + stress_%v(result + %v)) & 0xff",
			function_id,
			function_id + 1,
		)
	}
	fmt.fprintln(file, "\treturn result")
	fmt.fprintln(file, "}")
}
