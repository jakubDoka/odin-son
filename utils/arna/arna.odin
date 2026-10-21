package arna

import "base:intrinsics"
import "base:runtime"
import "core:io"
import "core:math"
import "core:mem"
import "core:simd"
import "core:slice"

_ :: simd
_ :: slice

DISABLE_VIRTUAL :: #config(ARNA_DISABLE_VIRTUAL, false)
DISABLE_THREAD_LOCAL :: #config(ARNA_DISABLE_THREAD_LOCAL, false)

Temps :: distinct [2]Allocator

when !DISABLE_THREAD_LOCAL {
	@(thread_local)
	scratch: Temps
}

Allocator :: struct {
	ptr:      [^]u8,
	pos:      uint,
	commited: uint,
	reserved: uint,
}

reserve :: proc "contextless" (size: uint) -> ([]u8, runtime.Allocator_Error) {
	when ODIN_ARCH == .wasm32 {
		page_size := uintptr(mem.PAGE_SIZE)
		page_count := (uintptr(size) + page_size - 1) / page_size
		off := intrinsics.wasm_memory_grow(0, page_count)
		if off == -1 do return {}, .Out_Of_Memory
		return ([^]u8)(uintptr(off) * page_size)[:page_count * page_size], nil
	} else when ODIN_OS == .Freestanding {
		return {}, .Mode_Not_Implemented
	} else {
		return virtual_reserve(size)
	}
}

commit :: proc "contextless" (
	data: rawptr,
	size: uint,
) -> runtime.Allocator_Error {
	when ODIN_ARCH == .wasm32 || DISABLE_VIRTUAL {
		return nil
	} else when ODIN_OS == .Freestanding {
		return .Mode_Not_Implemented
	} else {
		return virtual_commit(data, size)
	}
}

decommit :: proc "contextless" (data: rawptr, size: uint) {
	when ODIN_ARCH == .wasm32 || ODIN_OS == .Freestanding {
		return
	} else {
		virtual_decommit(data, size)
	}
}

release :: proc "contextless" (data: rawptr, size: uint) {
	when ODIN_ARCH == .wasm32 || ODIN_OS == .Freestanding {
		return
	} else {
		virtual_release(data, size)
	}
}

init :: proc "contextless" (
	slot: ^Allocator,
	size: int,
) -> runtime.Allocator_Error {
	mem := reserve(uint(size)) or_return
	slot^ = {raw_data(mem), 0, 0, uint(size)}
	return .None
}

@(tag = "api")
init_from_buffer :: proc "contextless" (buf: []u8) -> Allocator {
	return {
		ptr = raw_data(buf),
		pos = 0,
		commited = len(buf) + 1,
		reserved = len(buf),
	}
}

destroy :: proc(slot: ^Allocator) {
	if slot.commited > slot.reserved {
		delete(slot.ptr[:slot.reserved])
	} else {
		release(slot.ptr, slot.reserved)
	}
}

reset :: proc "contextless" (arena: ^Allocator, decommit_: bool = true) {
	if arena.commited <= arena.reserved && decommit_ {
		decommit(arena.ptr, arena.commited)
		arena.commited = 0
	}
	arena.pos = 0
}

when DISABLE_THREAD_LOCAL {
	scrath :: proc {
		scrath_temps_with_clobber,
		scrath_temps_no_clobber,
		scrath_existing,
	}
} else {
	init_scratch :: proc(size: int) {
		for &s in scratch do init(&s, size)
	}

	deinit_scratch :: proc() {
		for &s in scratch do destroy(&s)
	}

	scrath :: proc {
		scrath_temps_with_clobber,
		scrath_temps_no_clobber,
		scrath_with_clobber,
		scrath_no_clobber,
		scrath_existing,
	}

	@(deferred_out = scrath_end)
	scrath_no_clobber :: proc "contextless" () -> (runtime.Allocator, uint) {
		return scrath_temps_no_clobber(&scratch)
	}

	@(deferred_out = scrath_end)
	scrath_with_clobber :: proc "contextless" (
		clobber: runtime.Allocator,
	) -> (
		runtime.Allocator,
		uint,
	) {
		return scrath_temps_with_clobber(&scratch, clobber)
	}
}

@(deferred_out = scrath_end)
scrath_temps_no_clobber :: proc "contextless" (
	temps: ^Temps,
) -> (
	runtime.Allocator,
	uint,
) {
	return allocator(&temps[0]), temps[0].pos
}

@(deferred_out = scrath_end)
scrath_temps_with_clobber :: proc "contextless" (
	temps: ^Temps,
	clobber: runtime.Allocator,
) -> (
	runtime.Allocator,
	uint,
) {
	if &temps[0] == clobber.data {
		return allocator(&temps[1]), temps[1].pos
	}
	return allocator(&temps[0]), temps[0].pos
}

@(deferred_in_out = scrath_existing_end)
scrath_existing :: proc "contextless" (arena: ^Allocator) -> uint {
	return arena.pos
}

scrath_existing_end :: proc "contextless" (arena: ^Allocator, pos: uint) {
	arena.pos = pos
}

scrath_end :: proc "contextless" (arena: runtime.Allocator, pos: uint) {
	(^Allocator)(arena.data).pos = pos
}

@(require_results)
bulk_init :: proc "contextless" (
	slots: ..^Allocator,
) -> runtime.Allocator_Error {
	total: uint = 0
	for slot in slots {
		total += slot.reserved
	}

	mem := reserve(total) or_return
	for slot in slots {
		slot.ptr = raw_data(mem)
		slot.pos = 0
		slot.commited = 0
		mem = mem[slot.reserved:]
	}

	return nil
}

bulk_destroy :: proc(slots: ..^Allocator) {
	min_ptr := ~uintptr(0)
	size: uint = 0
	for slot in slots {
		min_ptr = min(min_ptr, uintptr(slot.ptr))
		size += slot.reserved
	}

	for slot in slots {
		rel_offset := uintptr(slot.ptr) - min_ptr
		assert(rel_offset + uintptr(slot.reserved) <= uintptr(size))
	}

	release(rawptr(min_ptr), size)
}

alloc :: proc(
	arena: ^Allocator,
	size: uint,
	alignemnt: uint,
	zeroed := false,
) -> (
	b: []u8,
	e: runtime.Allocator_Error,
) #optional_allocator_error {
	assert(math.is_power_of_two(int(alignemnt)))
	assert(alignemnt <= uint(mem.PAGE_SIZE))

	base := mem.align_forward_uint(arena.pos, alignemnt)
	end := base + size

	if end > arena.reserved {
		return {}, .Out_Of_Memory
	}

	if end > arena.commited {
		commit_chunk: uint = 1024 * 1024
		commit_chunk = max(
			min(commit_chunk, arena.reserved - arena.commited),
			size,
		)
		commit_chunk = mem.align_forward_uint(commit_chunk, uint(mem.PAGE_SIZE))
		commit_pos := uintptr(arena.ptr) + uintptr(arena.commited)
		commit(rawptr(commit_pos), commit_chunk) or_return
		arena.commited += commit_chunk
		assert(arena.commited <= arena.reserved)
		assert(end <= arena.commited)
	}

	arena.pos = end

	slc := arena.ptr[base:][:size]
	if zeroed do mem.zero_slice(slc)

	return slc, .None
}

smake :: proc(
	arena: ^Allocator,
	$T: typeid/[]$E,
	#any_int len: int,
	zeroed := true,
) -> []E {
	return mem.slice_data_cast(
		[]E,
		alloc(arena, uint(size_of(E) * len), align_of(E), zeroed),
	)
}

clone :: proc(arena: ^Allocator, slc: []$T) -> []T {
	slot := smake(arena, []T, len(slc), false)
	mem.copy_non_overlapping(
		raw_data(slot),
		raw_data(slc),
		len(slc) * size_of(T),
	)
	return slot
}

allocator :: proc "contextless" (arena: ^Allocator) -> runtime.Allocator {
	return {procedure = allocator_proc, data = arena}
}

allocator_proc :: proc(
	allocator_data: rawptr,
	mode: runtime.Allocator_Mode,
	size, alignment: int,
	old_memory: rawptr,
	old_size: int,
	location := #caller_location,
) -> (
	b: []u8,
	e: runtime.Allocator_Error,
) {
	arena := (^Allocator)(allocator_data)
	switch (mode) {
	case .Alloc, .Alloc_Non_Zeroed:
		bytes := alloc(
			arena,
			uint(size),
			uint(alignment),
			mode == .Alloc,
		) or_return
		return bytes, nil
	case .Free:
		if uintptr(old_memory) - uintptr(arena.ptr) ==
		   uintptr(arena.pos) - uintptr(old_size) {
			arena.pos -= uint(old_size)
		}
		return {}, nil
	case .Free_All:
		reset(arena, decommit_ = false)
		return {}, nil
	case .Resize, .Resize_Non_Zeroed:
		if uintptr(old_memory) - uintptr(arena.ptr) !=
		   uintptr(arena.pos) - uintptr(old_size) {
			bytes := alloc(
				arena,
				uint(size),
				uint(alignment),
				mode == .Resize,
			) or_return
			mem.copy_non_overlapping(
				raw_data(bytes),
				old_memory,
				min(old_size, size),
			)
			return bytes, nil
		}

		if size < old_size {
			arena.pos -= uint(old_size - size)
		} else {
			extra_size := size - old_size
			_ = alloc(arena, uint(extra_size), 1, mode == .Resize) or_return
		}
		return ([^]u8)(old_memory)[:size], nil
	case .Query_Features, .Query_Info:
	case:
	}
	return {}, .Mode_Not_Implemented
}

to_stream :: proc(a: ^Allocator) -> io.Stream {
	return {stream_proc, a}
}

stream_proc :: proc(
	stream_data: rawptr,
	mode: io.Stream_Mode,
	p: []byte,
	offset: i64,
	whence: io.Seek_From,
) -> (
	n: i64,
	err: io.Error,
) {
	a := (^Allocator)(stream_data)

	#partial switch mode {
	case .Flush:
		return 0, .None
	case .Write:
		clone(a, p)
		return i64(len(p)), .None
	case:
		return 0, .Unsupported
	}
}

simd_search :: proc "contextless" (haistack: []$T, needle: T) -> (int, bool) {
	LANES :: 16 / size_of(T)

	for i in 0 ..< len(haistack) / LANES {
		chunk := intrinsics.unaligned_load(
			(^#simd[LANES]T)(raw_data(haistack)[i * LANES:]),
		)
		mask := simd.lanes_eq(chunk, (#simd[LANES]T)(needle))
		bits := transmute(u8)simd.extract_lsbs(mask)
		if bits == 0 do continue
		return i * LANES + int(simd.count_trailing_zeros(bits)), true
	}

	idx, _ := slice.linear_search(
		haistack[len(haistack) / LANES * LANES:],
		needle,
	)
	if idx < 0 do return -1, false
	return len(haistack) / LANES * LANES + idx, true
}
