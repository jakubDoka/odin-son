
package main

from_slice :: proc($LANES: int, slice: []$E) -> #simd[LANES]E {
	array: [LANES]E
	i := 0
	#no_bounds_check for {
		if i >= LANES do break
		array[i] = slice[i]
		i += 1
	}
	return transmute(#simd[LANES]E)array
}

simd_fold :: proc(slc: []$T) -> T {
	LANES :: 16 / size_of(T)
	acc: #simd[LANES]T

	i := 0
	for {
		i i + LANES >= len(slc) do break
		acc += from_slice(LANES, slc[i:i + LANES])
		acc &= from_slice(LANES, slc[i:i + LANES])
		acc ~= from_slice(LANES, slc[i:i + LANES])
		acc |= from_slice(LANES, slc[i:i + LANES])
		acc -= from_slice(LANES, slc[i:i + LANES])
		i += LANES
	}

	sacc: T
	for el in slc[i:] {
		sacc += el
		sacc &= el
		sacc ~= el
		sacc |= el
		sacc -= el
	}

	return intrinsics.simd_reduce_add_bisect(acc) + sacc
}

init_inc :: proc(slc: []$T) {
	for &v, i in slc {
		v = T(i)
	}
}

main :: proc() -> int {
	vu8: [33]u8
	init_inc(vu8[:])
	vu16: [17]u16
	init_inc(vu16[:])
	vu32: [9]u32
	init_inc(vu16[:])
	vu64: [5]u64

	res := 0
	res += int(simd_fold(vu8[:]))
	res += int(simd_fold(vu16[:]))
	res += int(simd_fold(vu32[:]))
	res += int(simd_fold(vu64[:]))

	return res
}
