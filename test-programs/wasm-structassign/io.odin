package main

// Minimal stdout printing built directly on the linux write(2) syscall, which
// is the only external code the JIT is allowed to call. Everything here is
// deliberately kept inside the subset of Odin the JIT understands: bare `for`
// loops with explicit breaks, `&`/`|` instead of `&&`/`||`, integer "enums"
// expressed as plain constants and call-form casts only.

import "base:intrinsics"

SYS_WRITE :: 1

// write_bytes writes the first `n` bytes of `buf` to stdout (fd 1).
write_bytes :: proc(buf: [^]u8, n: int) {
	intrinsics.syscall(
		uintptr(SYS_WRITE),
		uintptr(1),
		uintptr(buf),
		uintptr(n),
	)
}

// print writes a raw string to stdout.
print :: proc(s: string) {
	if len(s) == 0 do return
	write_bytes(raw_data(s), len(s))
}

// print_uint writes an unsigned integer in base 10.
print_uint :: proc(value: u64) {
	buf: [32]u8 = {}
	if value == 0 {
		buf[0] = '0'
		write_bytes(raw_data(buf[:]), 1)
		return
	}
	// Emit least significant digit first, then reverse.
	tmp: [32]u8 = {}
	v := value
	n := 0
	for {
		if v == 0 do break
		tmp[n] = u8('0' + int(v % 10))
		v /= 10
		n += 1
	}
	i := 0
	for {
		if i >= n do break
		buf[i] = tmp[n - 1 - i]
		i += 1
	}
	write_bytes(raw_data(buf[:]), n)
}

// print_int writes a signed integer in base 10.
print_int :: proc(value: i64) {
	if value < 0 {
		print("-")
		// 0 - u64(value) is the magnitude even for the most negative value.
		print_uint(u64(0) - u64(value))
		return
	}
	print_uint(u64(value))
}

// print_char writes a single byte.
print_char :: proc(c: u8) {
	buf: [1]u8 = {}
	buf[0] = c
	write_bytes(raw_data(buf[:]), 1)
}

// print_indent writes `n` levels of two-space indentation.
print_indent :: proc(n: int) {
	i := 0
	for {
		if i >= n do break
		print("  ")
		i += 1
	}
}
