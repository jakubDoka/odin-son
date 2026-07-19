package main

// A generic growable array. The JIT frontend now supports generic STRUCTS, so
// `Array(T)` carries a real typed multi-pointer into the arena plus a length and
// capacity. Growth allocates a fresh, bigger block from the arena and copies the
// live elements across; because the arena base is stable, element pointers handed
// out earlier stay valid, but `data` itself moves to the new block on growth (so
// do not cache `array_at` results across a push that may grow the array).

Array :: struct($T: typeid) {
	data: [^]T,
	len:  int,
	cap:  int,
}

// array_reserve makes room for at least `need` more elements, moving the buffer
// to a fresh, bigger block in the arena and copying the live elements across.
array_reserve :: proc(a: ^Arena, arr: ^Array($T), need: int) {
	// Element byte size: the JIT has no size_of, so measure the distance
	// between two adjacent elements of a [2]T directly.
	//
	// COMPILER BUG: this `[2]T` local (a generic-typed fixed array) must be
	// declared BEFORE any `if`/branch in the proc; a branch preceding it makes
	// the JIT backend segfault while placing the alloca. Repro: move this decl
	// below the early-out `if` and rebuild.
	//   if arr.len + need <= arr.cap do return   // <- crashes if probe is after
	probe: [2]T = {}
	stride := int(uintptr(&probe[1]) - uintptr(&probe[0]))
	if arr.len + need <= arr.cap do return
	newcap := arr.cap * 2
	if newcap < arr.len + need do newcap = arr.len + need
	if newcap < 8 do newcap = 8
	block := arena_alloc(a, newcap * stride, 8)
	new_data := ([^]T)(raw_data(block))
	i := 0
	for {
		if i >= arr.len do break
		new_data[i] = arr.data[i]
		i += 1
	}
	arr.data = new_data
	arr.cap = newcap
}

// array_push appends a copy of `v^` and returns its index. The element is taken
// by pointer: passing a struct by value into a generic `$T` parameter crashes
// the JIT backend (unbounded inline recursion), so by-pointer is the one uniform
// convention for pushes.
array_push :: proc(a: ^Arena, arr: ^Array($T), v: ^T) -> int {
	array_reserve(a, arr, 1)
	idx := arr.len
	arr.data[idx] = v^
	arr.len += 1
	return idx
}

// array_at returns a real pointer to element `i`; callers read/write fields
// through it directly.
array_at :: proc(arr: ^Array($T), i: int) -> ^T {
	return &arr.data[i]
}
