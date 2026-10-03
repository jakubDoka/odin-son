package main

import "base:intrinsics"
import "base:runtime"
//import "core:log"
//import "core:math/rand"
//import "core:mem"
//import "core:slice"
//import "core:testing"

Intern_Vec :: #simd[16]u8

Arm_Simd_Iter :: struct {
	haystack: []Intern_Vec,
	i:        int,
	mask:     u64,
	needle:   u8,
}

arm_simd_iter_next :: proc(siter: ^Arm_Simd_Iter) -> (int, bool) {
	for {
		if siter.mask != 0 {
			idx :=
				(siter.i - 1) * size_of(Intern_Vec) +
				int(intrinsics.count_trailing_zeros(siter.mask))
			siter.mask &= siter.mask - 1

			return idx, true
		}

		if siter.i < len(siter.haystack) {
			mask := intrinsics.simd_lanes_eq(
				siter.haystack[siter.i],
				Intern_Vec(siter.needle),
			)
			siter.mask = u64(transmute(u16)intrinsics.simd_extract_lsbs(mask))
			siter.i += 1
		} else {
			return -1, false
		}
	}
}

arm_simd_iter_next_ :: proc(siter: ^Arm_Simd_Iter) -> (int, bool) {
	MSB_MASK :: 0x1010101010101010

	for {
		for i in 0 ..< 2 {
			m := u64(MSB_MASK >> (u64(1 - i) * 4))
			if siter.mask & m != 0 {
				trail := intrinsics.count_trailing_zeros(siter.mask & m)
				mask_offset := trail / 8 + 8 * u64(i)
				siter.mask &= ~(1 << trail)
				return (siter.i - 1) * size_of(Intern_Vec) + int(mask_offset),
					true
			}
		}

		if siter.i < len(siter.haystack) {
			mask := intrinsics.simd_lanes_eq(
				siter.haystack[siter.i],
				Intern_Vec(siter.needle),
			)

			siter.i += 1

			masks := transmute([2]u64)mask

			siter.mask = (masks[0] & MSB_MASK) >> 4
			siter.mask |= masks[1] & MSB_MASK
		} else {
			return -1, false
		}
	}
}

slice_data_cast :: proc "contextless" ($T: typeid/[]$A, slice: $S/[]$B) -> T {
	when size_of(A) == 0 || size_of(B) == 0 {
		return nil
	} else {
		s := transmute(runtime.Raw_Slice)slice
		s.len = (len(slice) * size_of(B)) / size_of(A)
		return transmute(T)s
	}
}

@(export)
find :: proc(a, b: #simd[16]u8) -> u16 {
	return(
		transmute(u16)intrinsics.simd_extract_msbs(
			intrinsics.simd_lanes_eq(a, b),
		) \
	)
}

when false {
	@(test)
	sanity :: proc(t: ^testing.T) {

		haystack, _ := mem.alloc_bytes(64, 16)
		for _ in 0 ..< 1000 {
			_ = runtime.random_generator_read_bytes(
				context.random_generator,
				haystack,
			)
			vl := rand.choice(haystack)

			res, _ := find(haystack, vl)
			res2, _ := slice.linear_search(haystack, vl)
			testing.expect_value(t, res, res2)
		}

		haystack_vl := "0123456789abcdefghijklmnopqrstuv"

		assert(len(haystack_vl) == 32)

		copy(haystack, haystack_vl)

		res, _ := find(transmute([]u8)haystack, 'v')
		testing.expect_value(t, res, 31)
		res2, _ := find(transmute([]u8)haystack, 'a')
		testing.expect_value(t, res2, 10)
	}
}
