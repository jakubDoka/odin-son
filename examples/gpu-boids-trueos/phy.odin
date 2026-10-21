package main

foreign _ {
	trueos_cabi_async_fs_read_start :: proc(path: [^]u8, path_len: uintptr) -> i32 ---
	trueos_cabi_async_fs_write_begin :: proc(path: [^]u8, path_len: uintptr, size: uintptr) -> i32 ---
	trueos_cabi_async_fs_write_chunk :: proc(id: u32, offset: uintptr, data: [^]u8, size: uintptr) -> i32 ---
	trueos_cabi_async_fs_write_commit :: proc(id: u32) -> i32 ---
	trueos_cabi_async_fs_status :: proc(id: u32) -> i32 ---
	trueos_cabi_async_fs_result_len :: proc(id: u32) -> int ---
	trueos_cabi_async_fs_result_read :: proc(id: u32, offset: uintptr, data: ^u8, size: uintptr) -> int ---
	trueos_cabi_async_fs_discard :: proc(id: u32) -> i32 ---
	trueos_cabi_poll_once :: proc() ---
}

phy_empty: [1]u32
phy_request: [288]u8
phy_response: [24]u8
phy_handle: u64
phy_completed: u64

phy_put32 :: proc(offset: int, value: u32) {
	i := 0
	for {
		if i >= 4 do break
		phy_request[offset + i] = u8(value >> uint(i * 8))
		i += 1
	}
}

phy_put64 :: proc(offset: int, value: u64) {
	i := 0
	for {
		if i >= 8 do break
		phy_request[offset + i] = u8(value >> uint(i * 8))
		i += 1
	}
}

phy_get32 :: proc(offset: int) -> u32 {
	value := u32(0)
	i := 0
	for {
		if i >= 4 do break
		value |= u32(phy_response[offset + i]) << uint(i * 8)
		i += 1
	}
	return value
}

phy_get64 :: proc(offset: int) -> u64 {
	value := u64(0)
	i := 0
	for {
		if i >= 8 do break
		value |= u64(phy_response[offset + i]) << uint(i * 8)
		i += 1
	}
	return value
}

phy_exchange :: proc(operation: u32, handle: u64, frame: u64, words: [^]u32, word_count: uintptr) -> i32 {
	if word_count > 64 do return -1
	phy_put32(0, 0x3143424f)
	phy_put32(4, operation)
	phy_put64(8, handle)
	phy_put64(16, frame)
	phy_put32(24, u32(word_count))
	phy_put32(28, 0)
	i := uintptr(0)
	for {
		if i >= word_count do break
		phy_put32(32 + int(i) * 4, words[i])
		i += 1
	}
	path := "vFile:compute-boids"
	request_size := 32 + word_count * 4
	start := trueos_cabi_async_fs_write_begin(raw_data(path), uintptr(len(path)), request_size)
	if start <= 0 do return -1
	id := u32(start)
	result := trueos_cabi_async_fs_write_chunk(id, 0, raw_data(phy_request[:]), request_size)
	if result == 0 do result = trueos_cabi_async_fs_write_commit(id)
	if result != 0 {
		trueos_cabi_async_fs_discard(id)
		return result
	}
	for {
		result = trueos_cabi_async_fs_status(id)
		if result != 0 do break
		trueos_cabi_poll_once()
	}
	if result != 1 {
		trueos_cabi_async_fs_discard(id)
		return -1
	}
	if trueos_cabi_async_fs_result_len(id) != 24 {
		trueos_cabi_async_fs_discard(id)
		return -1
	}
	offset := 0
	for {
		if offset >= 24 do break
		got := trueos_cabi_async_fs_result_read(id, uintptr(offset), &phy_response[offset], uintptr(24 - offset))
		if (got <= 0) | (got > 24 - offset) {
			trueos_cabi_async_fs_discard(id)
			return -1
		}
		offset += got
	}
	trueos_cabi_async_fs_discard(id)
	if phy_get32(0) != 0x3152424f do return -1
	phy_handle = phy_get64(8)
	phy_completed = phy_get64(16)
	return i32(phy_get32(4))
}

// COMPILER BUG: nil multipointer call arguments cannot be materialized.
// phy_exchange(1, 0, 0, nil, 0)
phy_create :: proc() -> u64 {
	attempt := 0
	for {
		result := phy_exchange(1, 0, 0, raw_data(phy_empty[:]), 0)
		if result == 0 do return phy_handle
		if (result != -11) & (result != -16) do return 0
		attempt += 1
		if attempt >= 256 do return 0
		trueos_cabi_poll_once()
		trueos_cabi_sleep_ms(4)
	}
}

phy_gpu_dispatch :: proc(handle: u64, frame: u64, words: [^]u32, word_count: uintptr) -> i32 {
	return phy_exchange(2, handle, frame, words, word_count)
}

phy_close :: proc(handle: u64) -> i32 {
	return phy_exchange(4, handle, 0, raw_data(phy_empty[:]), 0)
}

phy_batch_requested :: proc() -> bool {
	path := "vFile:launch"
	start := trueos_cabi_async_fs_read_start(raw_data(path), uintptr(len(path)))
	if start <= 0 do return false
	id := u32(start)
	for {
		status := trueos_cabi_async_fs_status(id)
		if status == 0 { trueos_cabi_poll_once(); continue }
		if status != 1 {
			trueos_cabi_async_fs_discard(id)
			return false
		}
		break
	}
	if trueos_cabi_async_fs_result_len(id) != 5 {
		trueos_cabi_async_fs_discard(id)
		return false
	}
	offset := 0
	for {
		if offset >= 5 do break
		got := trueos_cabi_async_fs_result_read(id, uintptr(offset), &phy_response[offset], uintptr(5 - offset))
		if (got <= 0) | (got > 5 - offset) {
			trueos_cabi_async_fs_discard(id)
			return false
		}
		offset += got
	}
	trueos_cabi_async_fs_discard(id)
	return (phy_response[0] == 98) & (phy_response[1] == 97) & (phy_response[2] == 116) & (phy_response[3] == 99) & (phy_response[4] == 104)
}
