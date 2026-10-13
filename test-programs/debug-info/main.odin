package main

Debug_Leaf :: struct {
	delta:   i16,
	enabled: bool,
}

Debug_Record :: struct {
	prefix: u8,
	count:  int,
	code:   u32,
	leaf:   Debug_Leaf,
}

digit_value :: proc(c: int) -> int {
	if c < 0 do return -1
	if c < 10 do return c
	return -1
}

observe :: proc(a: int, b: int, c: int) -> int {
	if c < 0 do return observe(a, b, 0)
	return a + b + c
}

debug_checkpoint :: proc(
	record: ^Debug_Record,
	i: int,
	total: int,
	v0: int,
	v5: int,
	v11: int,
	v16: int,
) -> int {
	if i < 0 do return debug_checkpoint(record, 0, total, v0, v5, v11, v16)
	return(
		int(record.prefix) +
		record.count +
		int(record.code) +
		int(record.leaf.delta) +
		i +
		total +
		v0 +
		v5 +
		v11 +
		v16 \
	)
}

main :: proc() -> int {
	parse_base := 10
	parse_acc := 0
	parse_count := 0
	parse_i := 0
	parse_observed := 0
	for {
		if parse_i >= 4 do break
		digit := digit_value(parse_i + 1)
		if digit < 0 do break
		if digit >= parse_base do break
		parse_acc = parse_acc * parse_base + digit
		parse_i += 1
		parse_count += 1
		parse_observed += observe(parse_acc, parse_count, parse_i)
	}

	total := parse_acc + parse_count + parse_observed
	debug_record := Debug_Record{0xa5, parse_acc, 0x10203040, {-321, true}}
	i := 0
	v0 := 1
	v1 := 2
	v2 := 3
	v3 := 4
	v4 := 5
	v5 := 6
	v6 := 7
	v7 := 8
	v8 := 9
	v9 := 10
	v10 := 11
	v11 := 12
	v12 := 13
	v13 := 14
	v14 := 15
	v15 := 16
	v16 := 17
	for {
		if i >= 4 do break
		checkpoint :=
			total +
			v0 +
			v1 +
			v2 +
			v3 +
			v4 +
			v5 +
			v6 +
			v7 +
			v8 +
			v9 +
			v10 +
			v11 +
			v12 +
			v13 +
			v14 +
			v15 +
			v16
		checkpoint += debug_checkpoint(
			&debug_record,
			i,
			total,
			v0,
			v5,
			v11,
			v16,
		)
		total = checkpoint + i
		v0 += i + 1
		v1 += i + 2
		v2 += i + 3
		v3 += i + 4
		v4 += i + 5
		v5 += i + 6
		v6 += i + 7
		v7 += i + 8
		v8 += i + 9
		v9 += i + 10
		v10 += i + 11
		v11 += i + 12
		v12 += i + 13
		v13 += i + 14
		v14 += i + 15
		v15 += i + 16
		v16 += i + 17
		i += 1
	}
	return total & 255
}
