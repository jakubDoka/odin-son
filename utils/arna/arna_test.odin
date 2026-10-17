#+build !wasm32
#+build !freestanding
package arna

import "core:testing"

@(test)
test_arena_sanity :: proc(t: ^testing.T) {
	buf: [1024]u8
	arena := init_from_buffer(buf[:])
	context.allocator = allocator(&arena)

	bf, err := make([]u8, 1024)
	assert(err == nil)
	delete(bf)

	bf, err = make([]u8, 1024)
	assert(err == nil)
	delete(bf)

	bfa: [dynamic]u8
	for _ in 0 ..< 256 {
		_, err = append(&bfa, 0)
		assert(err == nil)
	}

	resize(&bfa, 16)
	shrink(&bfa, 16)

	bf, err = make([]u8, 1024 - 16)
	assert(err == nil)
	delete(bf)

	s := new(u8)
	s^ = 1

	append(&bfa, 0)

	testing.expect_value(t, s^, 1)

	init(&arena, 1024 * 1024)

	bf, err = make([]u8, 1024 * 1024 / 2)
	assert(err == nil)
	bf, err = make([]u8, 1024 * 1024 / 2)
	assert(err == nil)
}
