package main

// A growable bump arena backed directly by pages obtained from the kernel via
// mmap(2). This intentionally does NOT implement the standard Odin allocator
// interface - it is a small, purpose built allocator for the lexer and parser.
//
// Growth: when the current mapping is exhausted a new, larger mapping is
// requested from the kernel and the live bytes are copied across. Because of
// this, callers must never hold on to a raw pointer into the arena across an
// allocation; instead everything is referenced by an integer OFFSET (or an
// index derived from one) and the address is recomputed from `base` on demand.
// `base` is stored in the type so the reallocation can update it in place.

import "base:intrinsics"

Byte_Ptr :: [^]u8

PAGE_SIZE :: 4096

SYS_MMAP :: 9
SYS_MUNMAP :: 11

// PROT_READ | PROT_WRITE
MMAP_PROT :: 0x3
// MAP_PRIVATE | MAP_ANONYMOUS
MMAP_FLAGS :: 0x22

Arena :: struct {
	base: uintptr, // start of the current mapping (0 when unmapped)
	cap:  int, // bytes currently mapped
	used: int, // bytes handed out so far
}

// sys_mmap maps `n` bytes of anonymous, private, read/write memory and returns
// the base address.
sys_mmap :: proc(n: int) -> uintptr {
	return intrinsics.syscall(
		uintptr(SYS_MMAP),
		uintptr(0),
		uintptr(n),
		uintptr(MMAP_PROT),
		uintptr(MMAP_FLAGS),
		~uintptr(0),
		uintptr(0),
	)
}

// sys_munmap releases a previous mapping.
sys_munmap :: proc(addr: uintptr, n: int) {
	intrinsics.syscall(
		uintptr(SYS_MUNMAP),
		addr,
		uintptr(n),
		uintptr(0),
		uintptr(0),
		uintptr(0),
		uintptr(0),
	)
}

// round_up_page rounds `n` up to a whole number of pages.
round_up_page :: proc(n: int) -> int {
	return (n + PAGE_SIZE - 1) &~ (PAGE_SIZE - 1)
}

// align_up rounds `x` up to a multiple of `align` (a power of two).
align_up :: proc(x: int, align: int) -> int {
	return (x + align - 1) &~ (align - 1)
}

// arena_init reserves an initial mapping of at least `reserve` bytes.
arena_init :: proc(a: ^Arena, reserve: int) {
	n := round_up_page(reserve)
	if n < PAGE_SIZE do n = PAGE_SIZE
	a.base = sys_mmap(n)
	a.cap = n
	a.used = 0
}

// arena_grow ensures the arena can hold at least `need` more bytes past `used`
// by moving to a fresh, larger mapping and copying the live bytes over.
arena_grow :: proc(a: ^Arena, need: int) {
	new_cap := a.cap * 2
	if new_cap < a.used + need do new_cap = a.used + need
	new_cap = round_up_page(new_cap)

	new_base := sys_mmap(new_cap)

	// Copy the live bytes into the new mapping.
	src := Byte_Ptr(a.base)
	dst := Byte_Ptr(new_base)
	i := 0
	for {
		if i >= a.used do break
		dst[i] = src[i]
		i += 1
	}

	sys_munmap(a.base, a.cap)
	a.base = new_base
	a.cap = new_cap
}

// arena_alloc reserves `size` bytes aligned to `align` and returns the byte
// offset of the block from the arena base. Callers turn the offset into a typed
// pointer with `arena_ptr` right before use.
arena_alloc :: proc(a: ^Arena, size: int, align: int) -> int {
	off := align_up(a.used, align)
	if off + size > a.cap {
		arena_grow(a, off + size - a.used)
		off = align_up(a.used, align)
	}
	a.used = off + size
	return off
}

// arena_ptr recomputes the absolute address of a previously returned offset.
arena_ptr :: proc(a: ^Arena, off: int) -> uintptr {
	return a.base + uintptr(off)
}
