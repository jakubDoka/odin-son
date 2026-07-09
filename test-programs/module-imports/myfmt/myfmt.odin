package myfmt

// Basic integer formatting, parsing and printing that works with the subset
// of Odin the JIT understands. The only external code we may call is the linux
// syscall interface, so all output goes through `write(2)` (syscall 1) on fd 1.

import "base:intrinsics"

// Result of parsing an unsigned integer. Kept at 16 bytes (two registers) so
// it is returned in registers rather than through memory.
Parse_Uint :: struct {
	value: u64,
	ok:    bool,
}

// Result of parsing a signed integer.
Parse_Int :: struct {
	value: i64,
	ok:    bool,
}

// digit_value maps an ascii character to its numeric value, or -1 when the
// character is not a valid digit.
digit_value :: proc(c: u8) -> int {
	if (c >= '0') & (c <= '9') do return int(c - '0')
	if (c >= 'a') & (c <= 'z') do return int(c - 'a') + 10
	if (c >= 'A') & (c <= 'Z') do return int(c - 'A') + 10
	return -1
}

// format_uint writes `value` in the given base into `buf`, most significant
// digit first, and returns the number of bytes written. `buf` must be large
// enough (65 bytes is enough for base 2 of a 64 bit value).
format_uint :: proc(buf: []u8, value: u64, base: int) -> int {
	digits := "0123456789abcdefghijklmnopqrstuvxyz"

	b := u64(base)

	if value == 0 {
		buf[0] = '0'
		return 1
	}

	// Emit the digits least significant first into a scratch buffer, then
	// reverse them into `buf`. Digit characters are computed arithmetically
	// (0-9 then a-z) so every base from 2 up to 36 is supported.
	tmp: [65]u8 = {}
	v := value
	n := 0
	for {
		if v == 0 do break
		d := v % b
		tmp[n] = digits[d]
		v /= b
		n += 1
	}

	i := 0
	for {
		if i >= n do break
		buf[i] = tmp[n - 1 - i]
		i += 1
	}

	return n
}

// format_int writes a signed `value` in the given base into `buf`, prefixing a
// '-' for negatives, and returns the number of bytes written.
format_int :: proc(buf: []u8, value: i64, base: int) -> int {
	if value < 0 {
		buf[0] = '-'
		// 0 - u64(value) yields the magnitude for every value, including
		// the most negative one where -value would overflow.
		mag := u64(0) - u64(value)
		return format_uint(buf[1:], mag, base) + 1
	}
	return format_uint(buf, u64(value), base)
}

// parse_uint reads an unsigned integer in the given base from the start of `s`.
// It stops at the first character that is not a valid digit for the base. `ok`
// is false when no digits were consumed.
parse_uint :: proc(s: string, base: int) -> Parse_Uint {
	b := u64(base)
	acc: u64 = 0
	count := 0

	i := 0
	for {
		if i >= len(s) do break
		d := digit_value(s[i])
		if d < 0 do break
		if d >= base do break
		acc = acc * b + u64(d)
		i += 1
		count += 1
	}

	return Parse_Uint{value = acc, ok = count > 0}
}

// parse_int reads a signed integer in the given base, accepting an optional
// leading '+' or '-'.
parse_int :: proc(s: string, base: int) -> Parse_Int {
	b := u64(base)
	neg := false

	i := 0
	if len(s) > 0 {
		if s[0] == '-' {
			neg = true
			i = 1
		} else if s[0] == '+' {
			i = 1
		}
	}

	acc: u64 = 0
	count := 0
	for {
		if i >= len(s) do break
		d := digit_value(s[i])
		if d < 0 do break
		if d >= base do break
		acc = acc * b + u64(d)
		i += 1
		count += 1
	}

	if count == 0 do return Parse_Int{value = 0, ok = false}

	v := i64(acc)
	if neg do v = -v
	return Parse_Int{value = v, ok = true}
}

// print writes a raw string to stdout.
print :: proc(s: string) {
	intrinsics.syscall(1, 1, uintptr(raw_data(s)), uintptr(len(s)))
}

// print_uint formats `value` in the given base and writes it to stdout.
print_uint :: proc(value: u64, base: int) {
	buf: [65]u8 = {}
	n := format_uint(buf[:], value, base)
	intrinsics.syscall(1, 1, uintptr(raw_data(buf[:])), uintptr(n))
}

// print_int formats a signed `value` in the given base and writes it to stdout.
print_int :: proc(value: i64, base: int) {
	buf: [66]u8 = {}
	n := format_int(buf[:], value, base)
	intrinsics.syscall(1, 1, uintptr(raw_data(buf[:])), uintptr(n))
}
