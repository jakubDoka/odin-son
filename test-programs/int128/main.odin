package main

Acc :: struct {
	sum:  u128,
	prod: i128,
}

step :: proc(acc: ^Acc, v: i128) {
	acc.sum += u128(v) * 0x1_0000_0001
	acc.prod = acc.prod * v / 3 % 0x7fff_ffff_ffff_ffff_ffff
}

fold :: proc(x: u128) -> int {
	return int(u64(x) ~ u64(x >> 64) * 3)
}

main :: proc() -> int {
	acc := Acc{0, 1}
	for i in 1 ..< 40 {
		v := i128(i) << u128(i * 3) - 0x1234_5678_9abc
		step(&acc, i % 2 == 0 ? v : -v)
	}

	f := f64(acc.prod) / 1.0e10
	g := u128(f32(acc.sum >> 40))
	q := acc.sum / 0x1_0000_0000_0000_0007
	m := i128(acc.sum % 0xffff_ffff_fffb) - 0x8000

	r := fold(acc.sum) ~ fold(u128(acc.prod)) * 7
	r = r * 31 + int(f) + fold(g) + fold(q) + fold(u128(m))
	return r & 0xff
}
