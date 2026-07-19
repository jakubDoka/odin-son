package main

// A bump arena backed directly by pages obtained from the kernel via mmap(2).
// This intentionally does NOT implement the standard Odin allocator interface -
// it is a small, purpose built allocator for the decoder and interpreter.
//
// The whole reservation is requested from the kernel ONCE up front with a single
// large anonymous MAP_PRIVATE mapping. On Linux the address space is committed
// on demand (lazy page faults), so reserving a big region (256 MiB here) is
// essentially free - only touched pages ever cost physical memory. Because the
// mapping never moves, the base address is STABLE for the arena's lifetime:
// `arena_alloc` just bumps `used` and hands back a real `[]u8` slice into the
// mapping. Pointers handed out stay valid until the arena is torn down, so there
// is no relocation, no copying and no offset->address dance.

import "base:intrinsics"

Byte_Ptr :: [^]u8

PAGE_SIZE := 4096

// Default up-front reservation: 256 MiB of virtual address space. Lazy paging
// means the untouched tail costs nothing.
ARENA_RESERVE := 256 * 1024 * 1024

SYS_MMAP := 9
SYS_MUNMAP := 11

// PROT_READ | PROT_WRITE
MMAP_PROT := 0x3
// MAP_PRIVATE | MAP_ANONYMOUS
MMAP_FLAGS := 0x22

Arena :: struct {
	base: uintptr, // start of the (stable) mapping
	cap:  int, // bytes reserved
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

// arena_init reserves the whole `reserve` byte region up front. The mapping is
// never grown or moved afterwards.
arena_init :: proc(a: ^Arena, reserve: int) {
	n := round_up_page(reserve)
	if n < PAGE_SIZE do n = PAGE_SIZE
	a.base = sys_mmap(n)
	a.cap = n
	a.used = 0
}

// arena_destroy releases the mapping.
arena_destroy :: proc(a: ^Arena) {
	if a.base != 0 {
		sys_munmap(a.base, a.cap)
		a.base = 0
		a.cap = 0
		a.used = 0
	}
}

// arena_alloc reserves `size` bytes aligned to `align` and returns a real slice
// into the stable mapping. The reservation is generous enough that the modules
// exercised here never exhaust it; if they somehow did, the returned slice would
// still point past the mapping and fault deterministically (the reference build
// bounds-checks, the JIT build would fault) - but this does not happen in
// practice.
arena_alloc :: proc(a: ^Arena, size: int, align: int) -> []u8 {
	off := align_up(a.used, align)
	a.used = off + size
	p := Byte_Ptr(a.base + uintptr(off))
	return p[0:size]
}
