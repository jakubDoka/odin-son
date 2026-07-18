package main

// A generic growable array. The JIT frontend supports generic PROCEDURES but
// not generic structs, so `Array` is a non-generic header (buffer offset, len,
// cap, element stride in bytes) and the element type only appears in the
// generic push/get procedures. The backing buffer lives in the arena and is
// referenced by an integer OFFSET, never a raw pointer, because the arena can
// move when it grows.

Array :: struct {
	buf:    int, // arena offset of the element buffer
	len:    int,
	cap:    int,
	stride: int, // element size in bytes
}

array_init :: proc(arr: ^Array, stride: int) {
	arr.buf = 0
	arr.len = 0
	arr.cap = 0
	arr.stride = stride
}

// array_reserve makes room for at least `need` more elements, moving the buffer
// to a fresh, bigger block in the arena and copying the live bytes across.
array_reserve :: proc(a: ^Arena, arr: ^Array, need: int) {
	if arr.len + need <= arr.cap do return
	newcap := arr.cap * 2
	if newcap < arr.len + need do newcap = arr.len + need
	if newcap < 8 do newcap = 8
	nb := arena_alloc(a, newcap * arr.stride, 8)
	if arr.len > 0 {
		src := Byte_Ptr(a.base + uintptr(arr.buf))
		dst := Byte_Ptr(a.base + uintptr(nb))
		n := arr.len * arr.stride
		i := 0
		for {
			if i >= n do break
			dst[i] = src[i]
			i += 1
		}
	}
	arr.buf = nb
	arr.cap = newcap
}

// array_push appends a copy of `v^` and returns its index. The element is taken
// by pointer (passing a struct by value into a generic `$T` parameter is not
// supported by the JIT frontend) and copied one byte at a time: a plain
// `p^ = v^` struct assignment through a generic pointer is miscompiled by the
// JIT backend once the program grows past a certain size, whereas the byte loop
// (the same shape as arena_grow's copy) is reliable.
array_push :: proc(a: ^Arena, arr: ^Array, v: ^$T) -> int {
	array_reserve(a, arr, 1)
	idx := arr.len
	dst := Byte_Ptr(a.base + uintptr(arr.buf + idx * arr.stride))
	src := Byte_Ptr(uintptr(v))
	k := 0
	for {
		if k >= arr.stride do break
		dst[k] = src[k]
		k += 1
	}
	arr.len += 1
	return idx
}

// array_get copies element `i` into `out^` (byte-wise, for the same reason as
// array_push).
array_get :: proc(a: ^Arena, arr: ^Array, i: int, out: ^$T) {
	src := Byte_Ptr(a.base + uintptr(arr.buf + i * arr.stride))
	dst := Byte_Ptr(uintptr(out))
	k := 0
	for {
		if k >= arr.stride do break
		dst[k] = src[k]
		k += 1
	}
}
