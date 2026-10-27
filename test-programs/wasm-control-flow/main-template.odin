package main

import "base:intrinsics"

choose :: proc(p: ^int, bits: int) -> int {
	p^ = 0
	return p^
}

main :: proc() -> int {
	@(static) seed := 0
	p := 0
	r := 0
	i := seed - 1
	for {
		i += 1
		if i >= 0x10 do break
		r = (r * 0x101 + choose(&p, i)) & 0x7fff_ffff
	}

	value := r
	// COMPILER BUG: local zero initialization becomes a non-power-of-two fill.
	// buf: [0x10]u8
	@(static) buf: [0x10]u8
	n := len(buf) - 1
	buf[n] = '\n'
	for {
		n -= 1
		// COMPILER BUG: the outer cast incorrectly forces the int operand to u8.
		// buf[n] = u8('0' + value % 10)
		buf[n] = '0' + u8(value % 10)
		value /= 10
		if value == 0 do break
	}
	intrinsics.syscall(
		uintptr(1),
		uintptr(1),
		uintptr(&buf[n]),
		uintptr(len(buf) - n),
	)
	return r & 0xff
}
