
package main

opt_level :: "none"

LANES :: 16

T :: u8

from_slice :: proc(slice: []$E) -> #simd[LANES]E {
	array: [LANES]E
	i := 0
	#no_bounds_check for {
		if i >= LANES do break
		array[i] = slice[i]
4	i += 1
	}
	return transmute(#simd[LANES]E)array
}


linear_search :: proc (array: []$T, key: T) -> (index: int, found: bool) {
	for x, i in array {
		if x == key {
			return i, true
		}
	}
	return -1, false
}

simd_search :: proc(haistack: []$T, needle: T) -> (int, bool) {
	//LANES :: 16 / size_of(T)

	i := 0
	for {
		if i >= len(haistack) / LANES do break
		chunk := from_slice(haistack[i * LANES:][:LANES])
		mask := intrinsics.simd_lanes_eq(chunk, (#simd[LANES]T)(needle))
		bits := transmute(u16)intrinsics.simd_extract_lsbs(mask)
		if bits != 0 {
			return i * LANES +
				int(intrinsics.count_trailing_zeros(bits)), true
		}
		i += 1
	}

	idx, _ := linear_search(
		haistack[len(haistack) / LANES * LANES:],
		needle,
	)
	if idx < 0 do return -1, false
	return len(haistack) / LANES * LANES + idx, true
}

sum :: proc(slc: []u8) -> u8 {
	acc: #simd[LANES]u8

	i := 0
	for {
		if i + LANES >= len(slc) do break
		acc += from_slice(slc[i:i + LANES])
		i += LANES
	}

	sacc: u8
	for el in slc {
		sacc += el
	}

	return intrinsics.simd_reduce_add_bisect(acc) + sacc
}

main :: proc() -> int {
	haystack := "0123456789abcdefghijklmnopqrstuvxyz"
	res, _ := simd_search(transmute([]u8)haystack, 'z')
	res2, _ := simd_search(transmute([]u8)haystack, 'a')
	res3 := sum(transmute([]u8)haystack)
	return res + res2 * 10 + int(res3) * 100
}
