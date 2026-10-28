package bac_intel_xelp_poc

import bac ".."
import "../../utils/arna"
import "base:intrinsics"
import "core:fmt"
import "core:mem"

expand_node :: bac.expand_node
get_node :: bac.get_node

Reg :: bac.Reg
Op :: [4]u32

MASK_SIZE :: GRF_COUNT

GRF_BYTES :: 32
GRF_COUNT :: 128
RK_GRF :: Reg_Kind(0)
RK_COUNT :: 1

R0 :: Reg(0)
R1 :: Reg(1)
R2 :: Reg(2)
R3 :: Reg(3)
R4 :: Reg(4)
R5 :: Reg(5)
R6 :: Reg(6)
R7 :: Reg(7)
R8 :: Reg(8)

R118 :: Reg(118)
R119 :: Reg(119)
R120 :: Reg(120)
R121 :: Reg(121)
R122 :: Reg(122)
R123 :: Reg(123)
R124 :: Reg(124)
R125 :: Reg(125)
R126 :: Reg(126)
R127 :: Reg(127)

@(rodata)
SPILL_SLOT_SIZE := [?]i32{128}

EU_SRC0_IMMEDIATE :: u32(1 << 14)
EU_SRC1_IMMEDIATE :: u32(1 << 15)

XELP_CC :: 0

SPEC_NOT_PRESENT :: (#load("node_specs.odin", string) or_else "") == ""

when SPEC_NOT_PRESENT {
	Reg_Kind :: bac.Reg_Kind

	Node_Type :: enum u16 {}

	inherit_idx_of :: proc($T: typeid) -> u8 {return 0}
}

@(tag = "api", rodata, export, link_name = "bac_intel_xelp_poc_OPT_HINTS")
OPT_HINTS := bac.Opt_Hints{}

@(tag = "api", rodata, export, link_name = "bac_intel_xelp_poc_CC_TABLE")
CC_TABLE := [1]bac.Call_Conv {
	XELP_CC = {
		args = {{R1, R2, R3, R4, R5, R6, R7, R8}},
		rets = {{R120, R121, R122, R123, R124, R125, R126, R127}},
	},
}

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
	prc: ^bac.Proc,
	ra: ^bac.Regalloc,
	node: bac.Expanded_Node,
	_: $T,
) -> bac.Regalloc_Node_Meta {
	IOUT :: bac.INVALID_RM_INDEX

	if node.gvn == 1 {
		if ra.cc == nil {
			ra.cc = &CC_TABLE[XELP_CC]
		}

		seed_rm_interner(ra)
	}

	single :: bac.rm_intern_single
	rslice :: bac.rm_intern_slice
	dup :: bac.rm_dup

	nkind := ra.datatype_to_reg_kind[node.dt]

	masks := [RK_COUNT][]bac.RM_Intern_Idx {
		RK_GRF = GRF_MASKS[:],
	}
	nmasks := masks[nkind]
	out := nmasks[0]

	if node.dt <= .Mem {
		out = IOUT
	}

	#partial switch ptype(node) {
	case .Nil ..= .Dbg_Scope:
		fmt.panicf("should not reach these: %v", node)
	case .Poison ..= .Global:
		return {out = out}
	case .Add:
		return {out = out, masks = nmasks[:2]}
	case .Param:
		return {out = bac.param_mask(prc, ra, node)}
	case .Return:
		return bac.cc_node_meta(prc, ra, node, CC_TABLE[:])
	case:
		fmt.panicf("TODO: %v", node)
	}
}

Ctx :: struct {
	using inner: bac.Codegen_Emit_Ctx,
}

emit_function :: proc(ectx: bac.Codegen_Emit_Ctx) -> bac.Codegen_Emit_Output {
	spill_slot_base: [RK_COUNT]i32
	stack_param_offset: [RK_COUNT][dynamic]i32

	ctx: Ctx
	ctx.inner = ectx
	ctx.code_start = ctx.code.pos
	ctx.constants_start = ctx.constants.pos
	ctx.instr_offsets = make([]u32, ctx.gvn)

	if ctx.abi == nil {
		ctx.abi = &CC_TABLE[XELP_CC]
	}

	ctx.stack_param_offset = stack_param_offset[:]
	ctx.spill_slot_base = spill_slot_base[:]
	ctx.spill_slot_size = SPILL_SLOT_SIZE[:]

	emit_op(
		ctx.code,
		{
			eu_control(.Mov, 8),
			eu_dst(R119, 0, .UD) | eu_src0_type(.UD),
			eu_src(R0, 0, 8, 8, 1),
			0,
		},
	)
	emit_op(
		ctx.code,
		{
			eu_control(.Mov, 2),
			eu_dst(R119, 0, .UD) | eu_src0_type(.UD) | EU_SRC0_IMMEDIATE,
			0,
			0,
		},
	)
	emit_op(
		ctx.code,
		{
			eu_control(.Mov, 1),
			eu_dst(R119, eu_subreg(2, .UD), .UD) |
			eu_src0_type(.UD) |
			EU_SRC0_IMMEDIATE,
			0,
			GRF_BYTES - 1,
		},
	)

	for bb, bidx in ctx.schedule.bbs {
		assert(bidx == 0)
		for instr, i in bb.instrs {
			emit_instr(&ctx, instr, struct{}{})
		}
	}

	return {}
}

@(disabled = SPEC_NOT_PRESENT)
emit_instr :: proc(ctx: ^Ctx, instr: bac.Node_ID, _: $T) {
	node := expand_node(ctx, instr)

	#partial switch ptype(node) {
	case .Nil ..= .Dbg_Scope:
		fmt.panicf("should not reach these: %v", node)
	case .Poison ..= .Phi:
	case .Add:
		dst := reg_of(ctx, instr)
		lhs := reg_of(ctx, node.inps[0])
		rhs := reg_of(ctx, node.inps[1])
		emit_op(
			ctx.code,
			{
				eu_control(.Add, 8, swsb = eu_swsb_regdist(1)),
				eu_dst(dst, 0, .F) | eu_src0_type(.F),
				eu_src(lhs, 0, 8, 8, 1) | eu_src1_type(.F),
				eu_src(rhs, 0, 8, 8, 1),
			},
		)
	case .Return:
		return_count := len(node.inps) - min(2, len(node.inps))
		return_regs := CC_TABLE[XELP_CC].rets[RK_GRF]
		assert(return_count <= len(return_regs))
		for i in 0 ..< return_count {
			message_grfs: u8 = 2
			src1 := R0
			src1_file: Register_File = .ARF
			ex_desc: u32
			if i != 0 {
				// The previous send must finish reading r119 before its X offset changes.
				emit_op(
					ctx.code,
					{
						eu_control(.Mov, 1, swsb = eu_swsb_sbid(0, .Wait_Src)),
						eu_dst(R119, 0, .UD) | eu_src0_type(.UD) | EU_SRC0_IMMEDIATE,
						0,
						u32(i * GRF_BYTES),
					},
				)
				message_grfs = 1
				src1 = return_regs[i]
				src1_file = .GRF
				ex_desc = eu_message_ex_desc(1)
			}

			d1, d2, d3 := eu_send_desc(eu_dc1_desc(0xa, 0, 0, message_grfs))
			e1, e2, e3 := eu_send_ex_desc(ex_desc)
			emit_op(
				ctx.code,
				{
					eu_control(.Send, 8, swsb = eu_swsb_combined(1, 0)),
					eu_send_dst(R0, .ARF) | d1 | e1,
					eu_send_target(.DC1) | eu_send_src(R119) | d2 | e2,
					eu_send_src(src1, src1_file) | d3 | e3,
				},
			)
		}

		emit_op(
			ctx.code,
			{
				eu_control(.Mov, 8),
				eu_dst(R118, 0, .UD) | eu_src0_type(.UD),
				eu_src(R0, 0, 8, 8, 1),
				0,
			},
		)
		d1, d2, d3 := eu_send_desc(eu_message_desc(0x10, 1, 0))
		e1, e2, e3 := eu_send_ex_desc(0x10000000)
		emit_op(
			ctx.code,
			{
				eu_control(.Send, 8, swsb = eu_swsb_combined(1, 1)),
				eu_send_dst(R0, .ARF, eot = true) | d1 | e1,
				eu_send_target(.TS) | eu_send_src(R118) | d2 | e2,
				eu_send_src(R0, .ARF) | d3 | e3,
			},
		)
	case:
		fmt.panicf("TODO: %v", node)
	}
}

reg_of :: proc(ctx: ^Ctx, node: bac.Node_ID) -> Reg {
	return ctx.allocs[get_node(ctx, node).gvn]
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

eu_message_ex_desc :: proc(message_grfs: u8) -> u32 {
	assert(message_grfs < 32)
	return u32(message_grfs) << 6
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
