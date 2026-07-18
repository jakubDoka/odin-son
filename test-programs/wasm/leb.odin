package main

// LEB128 decoding, the core primitive of the binary format. Every count, index,
// size and integer literal is stored this way. The shift is bounded so a
// malformed stream can never spin forever.

read_byte :: proc(d: ^Decoder) -> u8 {
	if d.pos >= len(d.data) {
		d.ok = false
		return 0
	}
	c := d.data[d.pos]
	d.pos += 1
	return c
}

read_uleb64 :: proc(d: ^Decoder) -> u64 {
	result := u64(0)
	shift := uint(0)
	for {
		b := read_byte(d)
		result = result | (u64(b & 0x7f) << shift)
		if (b & 0x80) == 0 do break
		shift += 7
		if shift >= 64 {
			d.ok = false
			break
		}
	}
	return result
}

read_uleb32 :: proc(d: ^Decoder) -> u32 {
	return u32(read_uleb64(d))
}

read_sleb64 :: proc(d: ^Decoder) -> i64 {
	result := i64(0)
	shift := uint(0)
	b := u8(0)
	for {
		b = read_byte(d)
		result = result | (i64(b & 0x7f) << shift)
		shift += 7
		if (b & 0x80) == 0 do break
		if shift >= 64 {
			d.ok = false
			break
		}
	}
	// sign extend if the sign bit of the last group is set
	if shift < 64 {
		if (b & 0x40) != 0 {
			result = result | (~i64(0) << shift)
		}
	}
	return result
}

read_sleb32 :: proc(d: ^Decoder) -> i32 {
	return i32(read_sleb64(d))
}
