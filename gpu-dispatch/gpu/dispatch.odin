#+build linux, amd64
package gpu

import "core:mem"

MAX_BUFFERS :: 16
MAX_BUFFER_BYTES :: 256 * 1024 * 1024

Buffer :: struct {
	address: u64,
	words:   []u32,
	device:  ^Device,
	storage: GEM_Buffer,
}

Program :: struct {
	device:                       ^Device,
	state, batch:                 GEM_Buffer,
	state_address, batch_address: u64,
	layout:                       State_Layout,
	width:                        SIMD_Width,
	parameter_count:              int,
}

buffer_create :: proc(
	device: ^Device,
	bytes: int,
) -> (
	buffer: Buffer,
	error: Error,
) {
	if device.failed do return {}, Error_Code.Device_Failed
	if bytes <= 0 || bytes > MAX_BUFFER_BYTES || bytes % size_of(u32) != 0 {
		return {}, Error_Code.Invalid_Buffer
	}
	size := align_up(bytes, PAGE_BYTES)
	storage := gem_buffer_create(device.fd, size) or_return
	address := reserve_address(device, size)
	return {address, storage.words[:bytes / size_of(u32)], device, storage}, nil
}

buffer_destroy :: proc(buffer: ^Buffer) {
	if buffer.device == nil do return
	gem_buffer_destroy(buffer.device.fd, buffer.storage)
	buffer^ = {}
}

program_create :: proc(
	device: ^Device,
	kernel: Kernel,
	parameter_count: int,
) -> (
	program: Program,
	error: Error,
) {
	validate(kernel, parameter_count, 0) or_return
	if device.failed do return {}, Error_Code.Device_Failed
	layout := state_layout(parameter_count, len(kernel.code) * size_of(u32))
	state := gem_buffer_create(device.fd, layout.size) or_return
	keep := false
	defer if !keep do gem_buffer_destroy(device.fd, state)
	batch := gem_buffer_create(device.fd, PAGE_BYTES) or_return
	pack_state(state.words, layout, kernel, nil, 0)
	keep = true
	return {
			device = device,
			state = state,
			batch = batch,
			state_address = reserve_address(device, layout.size),
			batch_address = reserve_address(device, PAGE_BYTES),
			layout = layout,
			width = kernel.width,
			parameter_count = parameter_count,
		},
		nil
}

program_destroy :: proc(program: ^Program) {
	if program.device == nil do return
	gem_buffer_destroy(program.device.fd, program.state)
	gem_buffer_destroy(program.device.fd, program.batch)
	program^ = {}
}

dispatch :: proc(
	program: ^Program,
	parameters: []Reg,
	groups_x: u32,
	buffers: []^Buffer,
	timeout_ns := DEFAULT_TIMEOUT_NS,
) -> Error {
	device := program.device
	if device == nil do return Error_Code.Invalid_Program
	if device.failed do return Error_Code.Device_Failed
	if len(parameters) != program.parameter_count do return Error_Code.Invalid_Parameter_Count
	if groups_x == 0 || groups_x > 0x7fff_ffff || len(buffers) > MAX_BUFFERS {
		return Error_Code.Invalid_Dispatch
	}
	if timeout_ns <= 0 || timeout_ns > MAX_TIMEOUT_NS do return Error_Code.Invalid_Timeout
	objects: [MAX_BUFFERS + 2]GEM_Exec_Object
	for buffer, i in buffers {
		if buffer == nil || buffer.device != device do return Error_Code.Invalid_Buffer
		for previous in buffers[:i] {
			if previous == buffer do return Error_Code.Invalid_Buffer
		}
		objects[i] = {
			handle = buffer.storage.handle,
			offset = buffer.address,
			flags  = EXEC_OBJECT_WRITE,
		}
	}
	objects[len(buffers)] = {
		handle = program.state.handle,
		offset = program.state_address,
	}
	objects[len(buffers) + 1] = {
		handle = program.batch.handle,
		offset = program.batch_address,
	}
	for &object in objects[:len(buffers) + 2] {
		object.flags |= EXEC_OBJECT_SUPPORTS_48B | EXEC_OBJECT_PINNED
	}
	gem_set_domain(device.fd, program.state.handle, true) or_return
	gem_set_domain(device.fd, program.batch.handle, true) or_return
	copy(
		program.state.words[program.layout.curbe / 4:],
		mem.slice_data_cast([]u32, parameters),
	)
	if len(buffers) != 0 {
		put_address(
			program.state.words[program.layout.surface / 4:][:16],
			8,
			buffers[0].address,
		)
	}
	commands := Dword_Buffer {
		data = program.batch.words,
	}
	pack_commands(
		&commands,
		program.layout,
		program.width,
		program.state_address,
		u64(program.layout.size),
		groups_x,
	)
	flush_cpu_writes()
	exec := GEM_Execbuffer {
		buffers_ptr  = u64(uintptr(&objects[0])),
		buffer_count = u32(len(buffers) + 2),
		batch_len    = u32(commands.used * size_of(u32)),
		flags        = I915_EXEC_RENDER | I915_EXEC_NO_RELOC,
		context_id   = u64(device.context_id),
	}
	drm_ioctl(device.fd, .I915_GEM_EXECBUFFER2, &exec, IOC_WRITE) or_return
	device.failed = true
	wait := GEM_Wait {
		handle     = program.batch.handle,
		timeout_ns = timeout_ns,
	}
	drm_ioctl(device.fd, .I915_GEM_WAIT, &wait) or_return
	for buffer in buffers do gem_set_domain(device.fd, buffer.storage.handle, false) or_return
	device.failed = false
	return nil
}

@(private)
reserve_address :: proc(device: ^Device, bytes: int) -> u64 {
	address := device.next_address
	device.next_address += u64(bytes)
	assert(device.next_address < 1 << 47)
	return address
}
