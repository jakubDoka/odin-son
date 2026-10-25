#+build linux, amd64
package gpu

import "base:runtime"
import "core:mem"
import "core:sys/linux"

MAX_PARAMETERS :: 8
MAX_RESULTS :: 128
MAX_KERNEL_BYTES :: 16 * 1024 * 1024
DEFAULT_TIMEOUT_NS :: i64(2_000_000_000)
MAX_TIMEOUT_NS :: i64(10_000_000_000)

SIMD_Size :: enum u32 {
	SIMD8,
	SIMD16,
	SIMD32,
}

Kernel :: struct {
	code:            []u32,
	parameter_count: int,
	result_count:    int,
	simd:            SIMD_Size,
}

Device :: struct {
	fd:          linux.Fd,
	context_id:  u32,
	initialized: bool,
	failed:      bool,
}

Error_Code :: enum {
	Invalid_Device,
	Device_Failed,
	Invalid_Path,
	Unsupported_Driver,
	Unsupported_GPU,
	Missing_Capability,
	Invalid_Kernel,
	Invalid_Parameter_Count,
	Invalid_Result_Count,
	Parameter_Count_Mismatch,
	Result_Count_Mismatch,
	Invalid_SIMD_Size,
	Invalid_Timeout,
	Result_Overrun,
	Disassembler_Unavailable,
	Invalid_Disassembler,
}

System_Error :: struct {
	operation: string,
	errno:     linux.Errno,
	request:   u32,
}

Error :: union {
	Error_Code,
	System_Error,
	Disassembler_Error,
	runtime.Allocator_Error,
}

@(private)
check_device :: proc(fd: linux.Fd) -> Error {
	name: [32]u8
	version := DRM_Version {
		name_len = len(name),
		name     = u64(uintptr(&name[0])),
	}
	drm_ioctl(fd, .VERSION, &version) or_return
	if version.name_len > len(name) ||
	   string(name[:version.name_len]) != "i915" {
		return Error_Code.Unsupported_Driver
	}
	device := getparam(fd, 4) or_return
	if device != 0x46a6 do return Error_Code.Unsupported_GPU
	softpin := getparam(fd, 37) or_return
	ppgtt := getparam(fd, 18) or_return
	if softpin == 0 || ppgtt < 2 do return Error_Code.Missing_Capability
	return nil
}

open :: proc(
	device_path := "/dev/dri/renderD128",
) -> (
	device: Device,
	error: Error,
) {
	path: [4096]u8
	if len(device_path) == 0 || len(device_path) >= len(path) {
		return {}, Error_Code.Invalid_Path
	}
	for c in device_path {
		if c == 0 do return {}, Error_Code.Invalid_Path
	}
	copy(path[:], device_path)
	fd, err := linux.open(cstring(&path[0]), {.RDWR, .CLOEXEC})
	if err != .NONE do return {}, System_Error{"open", err, 0}
	keep := false
	defer if !keep do linux.close(fd)
	check_device(fd) or_return
	ctx: GEM_Context
	drm_ioctl(fd, .I915_CONTEXT_CREATE, &ctx) or_return
	keep = true
	return Device{fd = fd, context_id = ctx.id, initialized = true}, nil
}

close :: proc(device: ^Device) -> Error {
	if device == nil || !device.initialized do return nil
	ctx := GEM_Context {
		id = device.context_id,
	}
	context_error := drm_ioctl(device.fd, .I915_CONTEXT_DESTROY, &ctx, IOC_WRITE)
	err := linux.close(device.fd)
	device^ = {}
	if context_error != nil do return context_error
	if err != .NONE do return System_Error{"close", err, 0}
	return nil
}

validate :: proc(kernel: Kernel) -> Error {
	if len(kernel.code) == 0 ||
	   len(kernel.code) % 2 != 0 ||
	   len(kernel.code) > MAX_KERNEL_BYTES / size_of(u32) {
		return Error_Code.Invalid_Kernel
	}
	if kernel.parameter_count < 0 ||
	   kernel.parameter_count > MAX_PARAMETERS {
		return Error_Code.Invalid_Parameter_Count
	}
	if kernel.result_count < 0 || kernel.result_count > MAX_RESULTS {
		return Error_Code.Invalid_Result_Count
	}
	if kernel.simd != .SIMD8 &&
	   kernel.simd != .SIMD16 &&
	   kernel.simd != .SIMD32 {
		return Error_Code.Invalid_SIMD_Size
	}
	return nil
}

execute :: proc(
	device: ^Device,
	kernel: Kernel,
	parameters: [][8]u32,
	results: [][8]u32,
	timeout_ns := DEFAULT_TIMEOUT_NS,
) -> Error {
	validate(kernel) or_return
	if len(parameters) != kernel.parameter_count {
		return Error_Code.Parameter_Count_Mismatch
	}
	if len(results) != kernel.result_count do return Error_Code.Result_Count_Mismatch
	if timeout_ns <= 0 || timeout_ns > MAX_TIMEOUT_NS do return Error_Code.Invalid_Timeout
	if device == nil || !device.initialized do return Error_Code.Invalid_Device
	if device.failed do return Error_Code.Device_Failed

	layout := state_layout(len(parameters), len(kernel.code) * size_of(u32))
	output := gem_buffer_create(device.fd, PAGE_BYTES) or_return
	defer gem_buffer_destroy(device.fd, output)
	state := gem_buffer_create(device.fd, layout.size) or_return
	defer gem_buffer_destroy(device.fd, state)
	batch := gem_buffer_create(device.fd, PAGE_BYTES) or_return
	defer gem_buffer_destroy(device.fd, batch)

	objects := [?]GEM_Exec_Object {
		{handle = output.handle, flags = EXEC_OBJECT_WRITE},
		{handle = state.handle},
		{handle = batch.handle},
	}
	sizes := [?]int{PAGE_BYTES, layout.size, PAGE_BYTES}
	next_address := u64(0x100000)
	for &object, i in objects {
		object.offset = next_address
		object.flags |= EXEC_OBJECT_SUPPORTS_48B | EXEC_OBJECT_PINNED
		next_address += u64(sizes[i])
	}
	for &word in output.words do word = OUTPUT_CANARY
	pack_state(state.words, layout, kernel, parameters, objects[0].offset)
	commands := Dword_Buffer {
		data = batch.words,
	}
	pack_commands(
		&commands,
		layout,
		kernel.simd,
		objects[1].offset,
		u64(layout.size),
	)
	flush_cpu_writes()

	exec := GEM_Execbuffer {
		buffers_ptr  = u64(uintptr(&objects[0])),
		buffer_count = len(objects),
		batch_len    = u32(commands.used * size_of(u32)),
		flags        = I915_EXEC_RENDER | I915_EXEC_NO_RELOC,
		context_id   = u64(device.context_id),
	}
	drm_ioctl(device.fd, .I915_GEM_EXECBUFFER2, &exec, IOC_WRITE) or_return
	// An interrupted/timed-out job can still own these GPU virtual addresses.
	device.failed = true
	wait := GEM_Wait {
		handle     = batch.handle,
		timeout_ns = timeout_ns,
	}
	drm_ioctl(device.fd, .I915_GEM_WAIT, &wait) or_return
	gem_set_domain(device.fd, output.handle, false) or_return
	result_words := mem.slice_data_cast([]u32, results)
	for word in output.words[len(result_words):] {
		if word != OUTPUT_CANARY do return Error_Code.Result_Overrun
	}
	copy(result_words, output.words[:len(result_words)])
	device.failed = false
	return nil
}
