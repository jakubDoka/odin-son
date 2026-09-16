package wamr

import "core:c"
import "core:testing"

foreign import wamr {"run.o", "aot_reloc.o", "libaotclib.a", "libvmlib.a", "system:LLVM-22", "system:stdc++", "system:m", "system:pthread", "system:dl"}

foreign wamr {
	wamr_run_module :: proc(bytes: [^]u8, size: uintptr, entry_data: [^]u8, entry_size: uintptr, result: ^i64) -> c.int ---
}

run_module :: proc(module_bytes: []u8, entry_name: string) -> (i64, i32) {
	result: i64
	status := wamr_run_module(
		raw_data(module_bytes),
		uintptr(len(module_bytes)),
		raw_data(entry_name),
		uintptr(len(entry_name)),
		&result,
	)
	return result, status
}

@(test)
simd_and_memory64 :: proc(t: ^testing.T) {
	module := []u8 {
		0x00,
		0x61,
		0x73,
		0x6d,
		0x01,
		0x00,
		0x00,
		0x00,
		0x01,
		0x05,
		0x01,
		0x60,
		0x00,
		0x01,
		0x7e,
		0x03,
		0x02,
		0x01,
		0x00,
		0x05,
		0x03,
		0x01,
		0x04,
		0x01,
		0x07,
		0x08,
		0x01,
		0x04,
		0x6d,
		0x61,
		0x69,
		0x6e,
		0x00,
		0x00,
		0x0a,
		0x1d,
		0x01,
		0x1b,
		0x00,
		0xfd,
		0x0c,
		69,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		0xfd,
		0x16,
		0x00,
		0xad,
		0x3f,
		0x00,
		0x7c,
		0x0b,
	}
	result, status := run_module(module, "main")
	testing.expect_value(t, status, 0)
	testing.expect_value(t, result, 70)
}
