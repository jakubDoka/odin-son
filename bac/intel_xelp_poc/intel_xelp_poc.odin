package bac_intel_xelp_poc

import bac ".."
import "../../utils/arna"
import "base:intrinsics"
import "core:mem"

Reg :: bac.Reg
Op :: [4]u32

GRF_BYTES :: 32
GRF_COUNT :: 128
RK_GRF :: Reg_Kind(0)
RK_COUNT :: 1

EU_SRC0_IMMEDIATE :: u32(1 << 14)
EU_SRC1_IMMEDIATE :: u32(1 << 15)

SPEC_NOT_PRESENT :: (#load("node_specs.odin", string) or_else "") == ""

when SPEC_NOT_PRESENT {
	Reg_Kind :: bac.Reg_Kind

	Node_Type :: enum u16 {}

	inherit_idx_of :: proc($T: typeid) -> u8 {return 0}
}

@(tag = "api", rodata, export, link_name = "bac_intel_xelp_poc_OPT_HINTS")
OPT_HINTS := bac.Opt_Hints{}

@(tag = "api", rodata, export, link_name = "bac_intel_xelp_poc_CC_TABLE")
CC_TABLE := [0]bac.Call_Conv{}

peep :: proc(
	_: bac.Peep_Ctx,
	_: bac.Expanded_Node,
	_: $T,
) -> Maybe(bac.Node_ID) {
	return nil
}

post_schedule_peep :: proc(
	_: bac.PS_Peep_Ctx,
	_: bac.Expanded_Node,
	_: $T,
) -> bac.Node_ID {
	return 0
}

meta_of :: proc(
	_: ^bac.Proc,
	_: ^bac.Regalloc,
	_: bac.Expanded_Node,
	_: $T,
) -> bac.Regalloc_Node_Meta {
	panic("intel_xelp_poc: register allocation is not implemented")
}

emit_function :: proc(_: bac.Codegen_Emit_Ctx) -> bac.Codegen_Emit_Output {
	panic("intel_xelp_poc: code emission is not implemented")
}

emit_op :: proc(code: ^arna.Allocator, op: Op) {
	op := op
	bac.emit(code, mem.ptr_to_bytes(&op))
}

Opcode :: enum u8 {
	// Control / synchronization
	Illegal  = 0x00,
	Sync     = 0x01,
	Jmpi     = 0x20,
	Brd      = 0x21,
	If       = 0x22,
	Brc      = 0x23,
	Else     = 0x24,
	Endif    = 0x25,
	While    = 0x27,
	Break    = 0x28,
	Continue = 0x29,
	Halt     = 0x2A,
	Calla    = 0x2B,
	Call     = 0x2C,
	Ret      = 0x2D,
	Goto     = 0x2E,

	// Messages
	Send     = 0x31,
	Sendc    = 0x32,

	// Math / arithmetic
	Math     = 0x38,
	Add      = 0x40,
	Mul      = 0x41,
	Avg      = 0x42,
	Frc      = 0x43,
	Rndu     = 0x44,
	Rndd     = 0x45,
	Rnde     = 0x46,
	Rndz     = 0x47,
	Mac      = 0x48,
	Mach     = 0x49,
	Lzd      = 0x4A,
	Fbh      = 0x4B,
	Fbl      = 0x4C,
	Cbit     = 0x4D,
	Addc     = 0x4E,
	Subb     = 0x4F,
	Mad      = 0x5B,
	Madm     = 0x5D,

	// Data movement / selection
	Nop      = 0x60,
	Mov      = 0x61,
	Sel      = 0x62,
	Movi     = 0x63,

	// Logic / bit operations
	Not      = 0x64,
	And      = 0x65,
	Or       = 0x66,
	Xor      = 0x67,
	Shr      = 0x68,
	Shl      = 0x69,
	Smov     = 0x6A,
	Asr      = 0x6C,
	Ror      = 0x6E,
	Rol      = 0x6F,

	// Comparisons / conditional selection
	Cmp      = 0x70,
	Cmpn     = 0x71,
	Csel     = 0x72,

	// Bitfield operations
	Bfrev    = 0x77,
	Bfe      = 0x78,
	Bfi1     = 0x79,
	Bfi2     = 0x7A,
}

Data_Type :: enum u8 {
	UB = 0x0,
	UW = 0x1,
	UD = 0x2,
	B  = 0x4,
	W  = 0x5,
	D  = 0x6,
	HF = 0x9,
	F  = 0xa,
}

Register_File :: enum u8 {
	ARF,
	GRF,
}

SFID :: enum u8 {
	TS  = 0x7,
	DC1 = 0xc,
}

SBID_Mode :: enum u8 {
	Wait_Dst = 0x20,
	Wait_Src = 0x30,
	Set      = 0x40,
}

eu_control :: proc(
	opcode: Opcode,
	#any_int lanes: u32,
	#any_int mask_offset: u32 = 0,
	swsb: u8 = 0,
	no_mask: bool = false,
) -> u32 {
	assert(intrinsics.count_ones(lanes) == 1 && lanes <= 32)
	assert(mask_offset < 32 && mask_offset % 4 == 0)
	assert(mask_offset + lanes <= 32)
	return(
		u32(opcode) |
		u32(intrinsics.count_trailing_zeros(lanes)) << 16 |
		(mask_offset / 4) << 19 |
		u32(swsb) << 8 |
		u32(no_mask) << 31 \
	)
}

eu_reg_number :: proc(reg: Reg, file: Register_File) -> u32 {
	assert(reg.kind == RK_GRF)
	assert(reg.index < (file == .GRF ? GRF_COUNT : 256))
	return u32(reg.index)
}

eu_stride :: proc(stride, limit: u8) -> u32 {
	assert(
		stride <= limit && (stride == 0 || intrinsics.count_ones(stride) == 1),
	)
	if stride == 0 do return 0
	return 1 + u32(intrinsics.count_trailing_zeros(stride))
}

eu_subreg :: proc(#any_int element: u32, dt: Data_Type) -> u8 {
	size := u32(1) << (u32(dt) & 3)
	assert(element < GRF_BYTES / size)
	return u8(element * size)
}

eu_dst :: proc(
	reg: Reg,
	byte_offset: u8,
	dt: Data_Type,
	hstride: u8 = 1,
	file: Register_File = .GRF,
) -> u32 {
	assert(byte_offset < GRF_BYTES && byte_offset % (1 << (u8(dt) & 3)) == 0)
	assert(hstride != 0)
	return(
		eu_reg_number(reg, file) << 24 |
		u32(byte_offset) << 19 |
		u32(file) << 18 |
		eu_stride(hstride, 4) << 16 |
		u32(dt) << 4 \
	)
}

eu_src :: proc(
	reg: Reg,
	byte_offset: u8,
	vstride, width, hstride: u8,
	file: Register_File = .GRF,
) -> u32 {
	assert(byte_offset < GRF_BYTES)
	assert(intrinsics.count_ones(width) == 1 && width <= 16)
	return(
		eu_reg_number(reg, file) << 8 |
		u32(byte_offset) << 3 |
		u32(file) << 2 |
		eu_stride(vstride, 32) << 20 |
		u32(intrinsics.count_trailing_zeros(width)) << 17 |
		eu_stride(hstride, 4) \
	)
}

eu_src0_type :: proc(dt: Data_Type) -> u32 {
	return u32(dt) << 8
}

eu_src1_type :: proc(dt: Data_Type) -> u32 {
	return u32(dt) << 24
}

eu_src0_mod :: proc(negate, absolute: bool) -> u32 {
	return u32(negate) << 13 | u32(absolute) << 12
}

eu_src1_mod :: proc(negate, absolute: bool) -> u32 {
	return u32(negate) << 25 | u32(absolute) << 24
}

eu_swsb_regdist :: proc(distance: u8) -> u8 {
	assert(distance < 8)
	return distance
}

eu_swsb_sbid :: proc(sbid: u8, mode: SBID_Mode) -> u8 {
	assert(sbid < 16)
	return u8(mode) | sbid
}

eu_swsb_combined :: proc(distance, sbid: u8) -> u8 {
	assert(0 < distance && distance < 8 && sbid < 16)
	// The opcode determines whether the combined SBID is allocated or waited on.
	return 0x80 | distance << 4 | sbid
}

eu_send_dst :: proc(
	reg: Reg,
	file: Register_File = .GRF,
	eot: bool = false,
) -> u32 {
	return eu_reg_number(reg, file) << 24 | u32(file) << 18 | u32(eot) << 2
}

eu_send_src :: proc(reg: Reg, file: Register_File = .GRF) -> u32 {
	return eu_reg_number(reg, file) << 8 | u32(file) << 2
}

eu_send_target :: proc(sfid: SFID) -> u32 {
	return u32(sfid) << 28
}

eu_message_desc :: proc(
	function_control: u32,
	message_grfs, response_grfs: u8,
	header: bool = false,
) -> u32 {
	assert(function_control < 1 << 19)
	assert(message_grfs < 16 && response_grfs < 32)
	return(
		function_control |
		u32(header) << 19 |
		u32(response_grfs) << 20 |
		u32(message_grfs) << 25 \
	)
}

eu_dc1_desc :: proc(
	message_type, control, binding_table_index: u8,
	message_grfs: u8,
	response_grfs: u8 = 0,
	header: bool = true,
) -> u32 {
	assert(message_type < 32 && control < 64)
	return eu_message_desc(
		u32(message_type) << 14 | u32(control) << 8 | u32(binding_table_index),
		message_grfs,
		response_grfs,
		header,
	)
}

eu_send_desc :: proc(desc: u32) -> (word1, word2, word3: u32) {
	word1 = ((desc >> 20) & 0x1f) << 19
	word2 = ((desc >> 25) & 0x1f) << 3 | (desc & 0x7ff) << 17
	word3 = ((desc >> 30) & 0x3) << 26 | ((desc >> 11) & 0x1ff) << 17
	return
}

eu_send_ex_desc :: proc(desc: u32) -> (word1, word2, word3: u32) {
	assert(desc & 0x3f == 0)
	word1 = ((desc >> 11) & 0x1fff) << 3
	word2 = (desc >> 24) & 0x3
	word3 =
		(desc & 0xf0000000) | ((desc >> 26) & 0x3) | ((desc >> 6) & 0x1f) << 3
	return
}
