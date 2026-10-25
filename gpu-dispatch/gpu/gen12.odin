#+build linux, amd64
#+private
package gpu

import "core:mem"

PAGE_BYTES :: 4096
MOCS_UNCACHED :: u32(3)
OUTPUT_CANARY :: u32(0xcacacaca)

SIMD_Config :: struct {
	encoding, mask: u32,
}

@(rodata)
SIMD_CONFIG := [SIMD_Size]SIMD_Config {
	.SIMD8  = {0 << 30, 0xff},
	.SIMD16 = {1 << 30, 0xffff},
	.SIMD32 = {2 << 30, 0xffffffff},
}

GFXPIPE :: u32(3 << 29)
PIPELINE_SELECT :: GFXPIPE | 1 << 27 | 1 << 24 | 4 << 16
STATE_BASE_ADDRESS :: GFXPIPE | 1 << 24 | 1 << 16
MEDIA_VFE_STATE :: GFXPIPE | 2 << 27
MEDIA_CURBE_LOAD :: GFXPIPE | 2 << 27 | 1 << 16
MEDIA_INTERFACE_DESCRIPTOR_LOAD :: GFXPIPE | 2 << 27 | 2 << 16
MEDIA_STATE_FLUSH :: GFXPIPE | 2 << 27 | 4 << 16
GPGPU_WALKER :: GFXPIPE | 2 << 27 | 1 << 24 | 5 << 16
PIPE_CONTROL :: GFXPIPE | 3 << 27 | 2 << 24

PC_CS_STALL :: u32(1 << 20)
PC_DC_FLUSH :: u32(1 << 5)
PC_RT_FLUSH :: u32(1 << 12)
PC_STATE_INVAL :: u32(1 << 2)
PC_CONST_INVAL :: u32(1 << 3)
PC_TEX_INVAL :: u32(1 << 10)
PC_INSTR_INVAL :: u32(1 << 11)

Dword_Buffer :: struct {
	data: []u32,
	used: int,
}

State_Layout :: struct {
	curbe, binding_table, surface, kernel, descriptor: u32,
	curbe_bytes, read_grfs, size:                      int,
}

align_up :: proc(value, alignment: int) -> int {
	return (value + alignment - 1) & ~(alignment - 1)
}

reserve :: proc(
	b: ^Dword_Buffer,
	words: int,
	alignment: int,
) -> (
	offset: u32,
	data: []u32,
) {
	start := align_up(b.used * size_of(u32), alignment) / size_of(u32)
	end := start + words
	assert(end <= len(b.data))
	b.used = end
	return u32(start * size_of(u32)), b.data[start:end]
}

packet :: proc(b: ^Dword_Buffer, opcode: u32, words: int) -> []u32 {
	_, data := reserve(b, words, size_of(u32))
	data[0] = opcode | u32(words - 2)
	return data
}

put_address :: proc(data: []u32, index: int, address: u64) {
	data[index] = u32(address)
	data[index + 1] = u32(address >> 32)
}

state_layout :: proc(parameter_count, code_bytes: int) -> State_Layout {
	layout: State_Layout
	layout.read_grfs = parameter_count
	layout.curbe_bytes = max(64, align_up(layout.read_grfs * 32, 64))
	layout.surface = u32(align_up(layout.curbe_bytes, 64))
	layout.binding_table = layout.surface + 64
	layout.kernel = u32(align_up(int(layout.binding_table) + 32, 64))
	// Keep instruction prefetch out of the interface descriptor.
	layout.descriptor = u32(align_up(int(layout.kernel) + code_bytes + 64, 64))
	layout.size = align_up(int(layout.descriptor) + 32, PAGE_BYTES)
	return layout
}

pack_state :: proc(
	data: []u32,
	layout: State_Layout,
	kernel: Kernel,
	parameters: [][8]u32,
	output_address: u64,
) {
	copy(data[layout.curbe / 4:], mem.slice_data_cast([]u32, parameters))
	surface := data[layout.surface / 4:][:16]
	surface[0] = 1 << 29 | 0x140 << 18 | 1 << 16 | 1 << 14 | 1 << 8
	surface[1] = MOCS_UNCACHED << 25
	surface[2] = PAGE_BYTES / size_of(u32) - 1
	surface[3] = PAGE_BYTES - 1
	surface[7] = 4 << 25 | 5 << 22 | 6 << 19 | 7 << 16
	put_address(surface, 8, output_address)

	data[layout.binding_table / 4] = layout.surface
	copy(data[layout.kernel / 4:], kernel.code)
	idd := data[layout.descriptor / 4:][:8]
	idd[0] = layout.kernel
	idd[4] = layout.binding_table | 1
	idd[5] = u32(layout.read_grfs) << 16
	idd[6] = 1
}

emit_pipe_control :: proc(b: ^Dword_Buffer, flags: u32, hdc_flush := false) {
	pc := packet(b, PIPE_CONTROL, 6)
	if hdc_flush do pc[0] |= 1 << 9
	pc[1] = flags
}

emit_state_base_address :: proc(
	b: ^Dword_Buffer,
	state_address: u64,
	state_size: u64,
) {
	sba := packet(b, STATE_BASE_ADDRESS, 22)
	mocs := MOCS_UNCACHED << 5
	sba[1] = mocs | 1
	sba[3] = MOCS_UNCACHED << 17
	put_address(sba, 4, state_address | u64(mocs) | 1)
	put_address(sba, 6, state_address | u64(mocs) | 1)
	sba[8] = mocs | 1
	put_address(sba, 10, state_address | u64(mocs) | 1)
	sba[12] = 1
	sba[13] = u32(state_size) | 1
	sba[14] = 1
	// The modify-enable bit is required even on the first dispatch.
	sba[15] = u32(state_size) | 1
	sba[16] = mocs | 1
	sba[19] = mocs | 1
}

pack_commands :: proc(
	b: ^Dword_Buffer,
	layout: State_Layout,
	simd: SIMD_Size,
	state_address, state_size: u64,
) {
	emit_pipe_control(b, PC_CS_STALL | PC_DC_FLUSH | PC_RT_FLUSH)

	// PIPELINE_SELECT PipelineSelection=GPGPU, MaskBits=3
	_, select := reserve(b, 1, 4)
	select[0] = PIPELINE_SELECT | 3 << 8 | 2

	emit_pipe_control(
		b,
		PC_CS_STALL |
		PC_DC_FLUSH |
		PC_STATE_INVAL |
		PC_CONST_INVAL |
		PC_TEX_INVAL |
		PC_INSTR_INVAL,
	)
	emit_state_base_address(b, state_address, state_size)

	vfe := packet(b, MEDIA_VFE_STATE, 9)
	vfe[3] = (2 - 1) << 16 | 1 << 8
	vfe[5] = u32(layout.curbe_bytes / 32)

	curbe := packet(b, MEDIA_CURBE_LOAD, 4)
	curbe[2] = u32(layout.curbe_bytes)
	curbe[3] = layout.curbe

	idd := packet(b, MEDIA_INTERFACE_DESCRIPTOR_LOAD, 4)
	idd[2] = 8 * size_of(u32)
	idd[3] = layout.descriptor

	walker := packet(b, GPGPU_WALKER, 15)
	walker[4] = SIMD_CONFIG[simd].encoding
	walker[7], walker[10], walker[12] = 1, 1, 1
	walker[13] = SIMD_CONFIG[simd].mask
	walker[14] = 0xffffffff

	packet(b, MEDIA_STATE_FLUSH, 2)
	// DC flush alone does not drain Gen12's HDC pipeline before CPU readback.
	emit_pipe_control(b, PC_CS_STALL | PC_DC_FLUSH, true)

	// MI_BATCH_BUFFER_END
	_, end := reserve(b, 1, 4)
	end[0] = 0x0a << 23
	reserve(b, 0, 8)
}
