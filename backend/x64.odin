package backend

import "../vendored/gam/util/arna"
import "../vendored/gam/util/bit_arr"
import "base:intrinsics"
import "core:fmt"
import "core:mem"
import "core:reflect"
import "core:sort"

NOOP_REX :: 0b0100_0000

GPA_MASK :: []int{0xFFFF & ~int(1 << uint(RSP))}
GPA_SPILL_MASK :: []int{~int(1 << uint(RSP))}
NO_INDEX :: RSP
GPA_RET_MASK :: []int{1 << uint(RAX)}
GPA_DIV_MASK :: []int {
	0xFFFF &
	~int(1 << uint(RSP)) &
	~int(1 << uint(RAX)) &
	~int(1 << uint(RDX)),
}
RAX_MASK :: []int{1 << uint(RAX)}
RDX_MASK :: []int{1 << uint(RDX)}
// variable shift counts must be in CL
RCX_MASK :: []int{1 << uint(RCX)}
CALL_CLOBBERS ::
	1 << uint(CALLER_SAVED[0]) |
	1 << uint(CALLER_SAVED[1]) |
	1 << uint(CALLER_SAVED[2]) |
	1 << uint(CALLER_SAVED[3]) |
	1 << uint(CALLER_SAVED[4]) |
	1 << uint(CALLER_SAVED[5]) |
	1 << uint(CALLER_SAVED[6]) |
	1 << uint(CALLER_SAVED[7]) |
	1 << uint(CALLER_SAVED[8])

RAX :: Reg(0)
RCX :: Reg(1)
RDX :: Reg(2)
RBX :: Reg(3)
RSP :: Reg(4)
RBP :: Reg(5)
RSI :: Reg(6)
RDI :: Reg(7)
R8 :: Reg(8)
R9 :: Reg(9)
R10 :: Reg(10)
R11 :: Reg(11)
R12 :: Reg(12)
R13 :: Reg(13)
R14 :: Reg(14)
R15 :: Reg(15)
RIP :: RBP

//* Large parameters (> 16 bytes) will be implicitly passed by pointer
//* Multiple return values are handled as the following
//  * If all of the return value can be passed in a register if they were
//  treated as a struct, they will
//  * If they cannot, then the values are treated separately with everything
//  but the last value being passed by pointer after the input parameters
//    * The end value is then treated as the "normal" return value according to
//    the calling conventioN
// * The `context` pointer is then the last parameter to the procedure
// arguments

CALLE_SAVED := []Reg{RBX, RBP, R12, R13, R14, R15}
CALLER_SAVED :: []Reg{RAX, RCX, RDX, RSI, RDI, R8, R9, R10, R11}
ARGS := []Reg{RDI, RSI, RDX, RCX, R8, R9}

SIMPLE_BINOP_SPEC :: Reg_Class_Spec {
	reg_masks = #partial{.General = {GPA_MASK, GPA_MASK, GPA_MASK}},
	inplace_slot_idx = 0,
}

SIMPLE_SHIFT_SPEC :: Reg_Class_Spec {
	reg_masks = #partial{.General = {GPA_MASK, GPA_MASK, RCX_MASK}},
	inplace_slot_idx = 0,
}

DIV_SPEC :: Reg_Class_Spec {
	reg_masks = #partial{.General = {RAX_MASK, RAX_MASK, GPA_DIV_MASK}},
	inplace_slot_idx = 0,
	clobbers = #partial{.General = 1 << uint(RDX)},
}

REM_SPEC :: Reg_Class_Spec {
	reg_masks = #partial{.General = {RDX_MASK, RAX_MASK, GPA_DIV_MASK}},
	clobbers = #partial{.General = 1 << uint(RAX)},
}

Instr_Info :: struct {
	opcode: u8,
	ext:    u8,
}

@(rodata)
X64_IDEAL_REG_CLASSES := [Ideal_Node_Type]Reg_Class_Spec {
	.Start = {},
	.Entry = {},
	.Poison = {},
	.Arg = {input_start_idx = 1},
	.CInt = {reg_masks = #partial{.General = {GPA_MASK}}},
	.Add = SIMPLE_BINOP_SPEC,
	.Sub = SIMPLE_BINOP_SPEC,
	.Mul = SIMPLE_BINOP_SPEC,
	.Eq = SIMPLE_BINOP_SPEC,
	.Ne = SIMPLE_BINOP_SPEC,
	.Le = SIMPLE_BINOP_SPEC,
	.Lt = SIMPLE_BINOP_SPEC,
	.Gt = SIMPLE_BINOP_SPEC,
	.Ge = SIMPLE_BINOP_SPEC,
	.And = SIMPLE_BINOP_SPEC,
	.Or = SIMPLE_BINOP_SPEC,
	.Xor = SIMPLE_BINOP_SPEC,
	// a &~ b is emitted as `not rhs; and rhs, lhs`, so the destination shares
	// the rhs slot (index 1) which we are free to clobber
	.And_Not = {
		reg_masks = #partial{.General = {GPA_MASK, GPA_MASK, GPA_MASK}},
		inplace_slot_idx = 1,
	},
	.Shl = SIMPLE_SHIFT_SPEC,
	.Shr = SIMPLE_SHIFT_SPEC,
	// idiv divides RDX:RAX by the divisor; quotient -> RAX, remainder -> RDX
	.Div = DIV_SPEC,
	.Rem = REM_SPEC,
	.U_Lt = SIMPLE_BINOP_SPEC,
	.U_Gt = SIMPLE_BINOP_SPEC,
	.U_Le = SIMPLE_BINOP_SPEC,
	.U_Ge = SIMPLE_BINOP_SPEC,
	.U_Shr = SIMPLE_SHIFT_SPEC,
	// idiv divides RDX:RAX by the divisor; quotient -> RAX, remainder -> RDX
	.U_Div = DIV_SPEC,
	.U_Rem = REM_SPEC,
	.Split = {
		reg_masks = #partial{.General = {GPA_SPILL_MASK, GPA_SPILL_MASK}},
	},
	.Phi = {
		input_start_idx = 1,
		reg_masks = #partial{
			.General = {GPA_SPILL_MASK, GPA_SPILL_MASK, GPA_SPILL_MASK},
		},
	},
	.Mem = {input_start_idx = 1},
	.Local = {input_start_idx = 1},
	.Local_Addr = {
		input_start_idx = 1,
		reg_masks = #partial{.General = {GPA_MASK}},
	},
	.Load = {
		input_start_idx = 2,
		reg_masks = #partial{.General = {GPA_MASK, GPA_MASK}},
	},
	.Store = {
		input_start_idx = 2,
		reg_masks = #partial{.General = {{}, GPA_MASK, GPA_MASK}},
	},
	.If = {
		reg_masks = #partial{.General = {{}, GPA_MASK}},
		input_start_idx = 1,
	},
	.Ret = {
		reg_masks = #partial{.General = {GPA_RET_MASK}},
		input_start_idx = 1,
	},
	.Then = {},
	.Else = {},
	.Region = {},
	.Loop = {},
	.Always = {input_start_idx = 1},
	.Call = {
		input_start_idx = 2,
		clobbers = #partial{.General = CALL_CLOBBERS},
	},
	.Call_End = {},
	.Jump = {input_start_idx = 1},
	.Return = {
		reg_masks = #partial{.General = {{}, GPA_RET_MASK}},
		input_start_idx = 2,
	},
}

@(rodata)
X64_REG_CLASSES := [X64_Node_Type]Reg_Class_Spec{}

x64_reg_mask_of :: proc(
	graph: ^Graph,
	ra: ^Regalloc,
	id: Node_ID,
	idx: int,
) -> Reg_Mask {
	node := graph_get(graph, id)

	#partial switch node.itype {
	case .Arg:
		arg := graph_extra(graph, node, Tup)
		return reg_mask_single(ra, ARGS[arg.idx])
	case .Call:
		return reg_mask_single(ra, ARGS[idx - 1])
	case:
		fmt.panicf("TODO: %v %v", node.itype, idx)
	}
}

Ctx :: struct {
	using inner:     Codegen_Emit_Ctx,
	spill_slot_base: [Reg_Kind]int,
	local_relocs:    [dynamic]Local_Reloc,
	stack_size:      int,
	used:            bit_arr.Bit_Set,
	code_start:      uint,
}

Local_Reloc :: struct {
	dest:   u32,
	offset: u32,
	off:    u32,
}

x64_emit_function :: proc(ectx: Codegen_Emit_Ctx) -> Codegen_Output {
	reloc_start := ectx.relocs.pos

	ctx: Ctx
	ctx.code_start = ectx.code.pos
	ctx.inner = ectx

	spill_slot_count: [Reg_Kind]int

	slot: [2]int
	ctx.used = bit_arr.init_from_masks(slot[:])

	for reg in ctx.allocs {
		spill_slot_count[reg.kind] = max(
			spill_slot_count[reg.kind],
			int(reg.index) - 16 + 1,
		)
		bit_arr.set_unbounded(ctx.used, int(reg.index))
	}

	total_spill_size := 0
	for size, kind in spill_slot_count {
		ctx.spill_slot_base[kind] = total_spill_size
		total_spill_size += size
	}

	ctx.stack_size = total_spill_size * 8

	emem: Node_ID
	for eout in graph_outs(ctx.graph, ectx.schedule.bbs[0].head) {
		enode := graph_expand(ctx.graph, eout.id)
		if enode.itype == .Mem {
			emem = eout.id
			break
		}
	}

	if emem != 0 {
		Local_Slot :: bit_field u64 {
			node:     Node_ID | 32,
			priority: u32     | 32,
		}
		locals: [dynamic]Local_Slot

		for mout in graph_outs(ctx.graph, emem) {
			mnode := graph_expand(ctx.graph, mout.id)
			if mnode.itype == .Local {
				extra := graph_extra(ctx.graph, mnode, Local)
				append(
					&locals,
					Local_Slot {
						node = mout.id,
						priority = intrinsics.count_trailing_zeros(extra.size),
					},
				)
			}
		}

		sort.quick_sort(locals[:])

		for loc in locals {
			extra := graph_extra(ctx.graph, loc.node, Local)
			ctx.stack_size += int(extra.size)
			extra.offset = u32(ctx.stack_size) - extra.size
		}
	}

	for reg in CALLE_SAVED {
		if bit_arr.contains(ctx.used, int(reg)) {
			emit_single_op(ctx.code, 0x50, reg)
		}
	}

	if ctx.stack_size != 0 {
		emit_imm_op(ctx.code, 0x81, 0b101, RSP, ctx.stack_size)
	}

	ctx.local_relocs = make([dynamic]Local_Reloc, 0, len(ctx.bbs))

	for &bb, i in ctx.bbs {
		bb.offset = u32(ctx.code.pos)
		for instr in bb.instrs {
			x64_emit_instr(&ctx, instr, 0)
		}
	}

	for reloc in ctx.local_relocs {
		size: u32 = 4

		dst_offset := ctx.bbs[reloc.dest].offset
		jump := dst_offset - reloc.offset - size - reloc.off

		copy(
			ctx.code.ptr[reloc.offset + reloc.off:][:size],
			reflect.as_bytes(jump),
		)
	}

	return {
		code = ctx.code.ptr[ctx.code_start:ctx.code.pos],
		relocs = mem.slice_data_cast(
			[]Reloc,
			ctx.relocs.ptr[reloc_start:ctx.relocs.pos],
		),
	}
}

@(disabled = GEN_SPEC)
x64_emit_instr :: proc(ctx: ^Ctx, instr: Node_ID, _: $T) {

	@(static)
	@(rodata)
	OPCODE_TABLE := #partial [X64_Node_Type]Instr_Info {
		.Add     = {0x01, 0},
		.Sub     = {0x29, 0},
		.And     = {0x21, 0},
		.Or      = {0x09, 0},
		.Xor     = {0x31, 0},
		.Eq      = {0x94, 0},
		.Ne      = {0x95, 0},
		.Lt      = {0x9C, 0},
		.Le      = {0x9E, 0},
		.Gt      = {0x9F, 0},
		.Ge      = {0x9D, 0},
		.U_Lt    = {0x92, 0},
		.U_Le    = {0x96, 0},
		.U_Gt    = {0x97, 0},
		.U_Ge    = {0x93, 0},
		.Shl     = {0xD3, 0b100},
		.U_Shr   = {0xD3, 0b101},
		.Shr     = {0xD3, 0b111},
		.And_Not = {0xF7, 0b010},
		.U_Div   = {0xF7, 0b110},
		.U_Rem   = {0xF7, 0b110},
		.Div     = {0xF7, 0b111},
		.Rem     = {0xF7, 0b111},
	}

	block_base := ctx.gvn - u32(len(ctx.bbs))
	node := graph_expand(ctx, instr)
	switch node.xtype {
	case .Local:
	case .Local_Addr:
		offset := graph_extra(ctx, node.inps[0], Local).offset
		emit_stack_lea(ctx.code, reg_of(ctx, instr), offset)
	case .Store:
		bse := reg_of(ctx, node.inps[2])
		val := reg_of(ctx, node.inps[3])
		emit(ctx.code, {rex(val, bse, NO_INDEX, true), 0x89})
		emit_indirect_addr(ctx.code, val, bse, NO_INDEX, 1, 0)
	case .Load:
		bse := reg_of(ctx, node.inps[2])
		val := reg_of(ctx, instr)
		emit(ctx.code, {rex(val, bse, NO_INDEX, true), 0x8b})
		emit_indirect_addr(ctx.code, val, bse, NO_INDEX, 1, 0)
	case .Start, .Entry, .Then, .Else, .Region, .Loop, .Call_End:
		panic("Not reachable form here")
	case .If:
		cond := reg_of(ctx, node.inps[1])
		rx := rex(cond, cond, RAX, true)
		emit(ctx.code, {rx, 0x85, mod_rm(.Direct, cond, cond)})

		assert(len(node.outs) == 2)
		append(
			&ctx.local_relocs,
			Local_Reloc {
				dest = graph_get(ctx, node.outs[1].id).gvn - block_base,
				offset = u32(ctx.code.pos),
				off = 2,
			},
		)

		emit(ctx.code, {0x0f, 0x84, 0, 0, 0, 0})

		fallthrough
	case .Always:
		fallthrough
	case .Jump:
		append(
			&ctx.local_relocs,
			Local_Reloc {
				dest = graph_get(ctx, node.outs[0].id).gvn - block_base,
				offset = u32(ctx.code.pos),
				off = 1,
			},
		)

		emit(ctx.code, {0xe9, 0, 0, 0, 0})
	case .Call:
		call := graph_extra(ctx, node, Call)
		emit(ctx.code, {0xe8, 0, 0, 0, 0})
		add_reloc(ctx.relocs)^ = {
			offset = u32(ctx.code.pos - ctx.code_start),
			kind   = .Func,
			size   = .r4,
			id     = call.cid,
		}
	case .Poison, .Arg, .Phi, .Ret, .Mem:
	case .CInt:
		emit_single_op(ctx.code, 0xb8, reg_of(ctx, instr))
		emit_anys(ctx.code, graph_extra(ctx, node, CInt).value)
	case .Add, .Sub, .And, .Or, .Xor:
		dst := reg_of(ctx, node.inps[0])
		rhs := reg_of(ctx, node.inps[1])
		rx := rex(rhs, dst, RAX, true)
		op := OPCODE_TABLE[node.xtype].opcode
		emit(ctx.code, {rx, op, mod_rm(.Direct, rhs, dst)})
	case .Mul:
		dst := reg_of(ctx, node.inps[0])
		rhs := reg_of(ctx, node.inps[1])
		rx := rex(dst, rhs, RAX, true)
		emit(ctx.code, {rx, 0x0f, 0xaf, mod_rm(.Direct, dst, rhs)})
	case .Eq, .Ne, .Lt, .Gt, .Ge, .Le, .U_Lt, .U_Gt, .U_Ge, .U_Le:
		lhs := reg_of(ctx, node.inps[0])
		rhs := reg_of(ctx, node.inps[1])
		rx := rex(lhs, rhs, RAX, true)
		emit(ctx.code, {rx, 0x3b, mod_rm(.Direct, lhs, rhs)})

		rx = rex(RAX, lhs, RAX, true)
		op := OPCODE_TABLE[node.xtype].opcode
		emit(ctx.code, {rx, 0x0F, op, mod_sm(.Direct, 0b000, lhs)})

		rx = rex(lhs, lhs, RAX, true)
		emit(ctx.code, {rx, 0x0F, 0xB6, mod_rm(.Direct, lhs, lhs)})
	case .And_Not:
		// dst aliases the rhs slot; compute `dst = ~rhs & lhs`
		dst := reg_of(ctx, node.inps[1])
		lhs := reg_of(ctx, node.inps[0])
		rx := rex(RAX, dst, RAX, true)
		emit(ctx.code, {rx, 0xf7, mod_sm(.Direct, 0b010, dst)})
		rx = rex(lhs, dst, RAX, true)
		emit(ctx.code, {rx, 0x21, mod_rm(.Direct, lhs, dst)})
	case .Shl, .Shr, .U_Shr:
		dst := reg_of(ctx, node.inps[0])
		rx := rex(RAX, dst, RAX, true)
		op := OPCODE_TABLE[node.xtype].ext
		emit(ctx.code, {rx, 0xd3, mod_sm(.Direct, op, dst)})
	case .Div, .Rem:
		rhs := reg_of(ctx, node.inps[1])
		emit(ctx.code, {rex(RAX, RAX, RAX, true), 0x99})
		rx := rex(RAX, rhs, RAX, true)
		emit(ctx.code, {rx, 0xf7, mod_sm(.Direct, 0b111, rhs)})
	case .U_Div, .U_Rem:
		rhs := reg_of(ctx, node.inps[1])
		rx := rex(RDX, RDX, RAX, true)
		emit(ctx.code, {rx, 0x31, mod_rm(.Direct, RDX, RDX)})
		rx = rex(RAX, rhs, RAX, true)
		emit(ctx.code, {rx, 0xf7, mod_sm(.Direct, 0b110, rhs)})
	case .Split:
		dst := reg_of(ctx, instr)
		src := reg_of(ctx, node.inps[0])
		assert(dst.kind == src.kind)
		if dst == src do break
		if int(dst) >= 16 {
			dst_offset := ctx.spill_slot_base[dst.kind] + 8 * (int(dst) - 16)

			assert(int(src) < 16)

			emit(ctx.code, {rex(src, RSP, RAX, true), 0x89})
			emit_indirect_addr(ctx.code, src, RSP, NO_INDEX, 1, dst_offset)
		} else if int(src) >= 16 {
			src_offset := ctx.spill_slot_base[dst.kind] + 8 * (int(src) - 16)
			assert(int(dst) < 16)

			emit(ctx.code, {rex(dst, RSP, RAX, true), 0x8b})
			emit_indirect_addr(ctx.code, dst, RSP, NO_INDEX, 1, src_offset)
		} else {
			assert(int(dst) < 16)
			assert(int(src) < 16)

			emit_reg_op(ctx.code, 0x89, src, dst)
		}
	case .Return:
		if ctx.stack_size != 0 {
			emit_imm_op(ctx.code, 0x81, 0b101, RSP, -ctx.stack_size)
		}

		#reverse for reg in CALLE_SAVED {
			if bit_arr.contains(ctx.used, int(reg)) {
				emit_single_op(ctx.code, 0x58, reg)
			}
		}

		emit(ctx.code, {0xc3})
	}
}

reg_of :: proc(ctx: Codegen_Emit_Ctx, id: Node_ID) -> Reg {
	node := graph_get(ctx, id)
	return ctx.allocs[node.gvn]
}

emit_single_op :: proc(code: ^arna.Allocator, op_base: u8, dst: Reg) {
	emit(code, {rex(RAX, dst, RAX, true), op_base + u8(dst.index & 0b111)})
}

emit_reg_op :: proc(code: ^arna.Allocator, op: u8, dst: Reg, src: Reg) {
	emit(code, {rex(dst, src, RAX, true), op, mod_rm(.Direct, dst, src)})
}

mod_from_dis :: proc(dis: i64) -> Mod {
	switch dis {
	case 0:
		return .Indirect
	case -128 ..< 127:
		return .Indirect_Disp8
	case:
		return .Indirect_Disp32
	}
}

emit_stack_lea :: proc(code: ^arna.Allocator, dst: Reg, #any_int dis: i64) {
	emit(code, {rex(dst, RAX, RAX, true), 0x8d})
	emit_indirect_addr(code, dst, RSP, NO_INDEX, 1, dis)
}

emit_indirect_addr :: proc(
	code: ^arna.Allocator,
	reg: Reg,
	base: Reg,
	index: Reg,
	scale: u64,
	#any_int dis: i64,
	is_reloc: bool = false,
) {
	mod := mod_from_dis(dis)

	assert(mod != .Direct)

	ill_base := base == RSP || base == R12

	if mod == .Indirect && !is_reloc && (base == RIP || base == R13) {
		mod = .Indirect_Disp8
	}

	if index != NO_INDEX || ill_base || scale != 1 {
		emit(code, {mod_rm(mod, reg, RSP), sib(base, index, scale)})
	} else {
		emit(code, {mod_rm(mod, reg, base)})
	}

	switch mod {
	case .Indirect:
	case .Indirect_Disp8:
		emit(code, {u8(dis)})
	case .Indirect_Disp32:
		emit_anys(code, u32(dis))
	case .Direct:
		fallthrough
	case:
		panic("unreachable")
	}
}

emit_imm_op :: proc(
	code: ^arna.Allocator,
	op: u8,
	mod: u8,
	dst: Reg,
	#any_int imm: i64,
) {
	is_small_imm := imm >= -128 && imm <= 127

	emit(
		code,
		{
			rex(dst, RAX, RAX, true),
			op + 2 * u8(is_small_imm),
			mod_rm(.Direct, Reg(mod), dst),
		},
	)

	if is_small_imm {
		emit(code, {u8(imm)})
	} else {
		emit_anys(code, u32(imm))
	}
}

Mod :: enum u8 {
	Indirect,
	Indirect_Disp8,
	Indirect_Disp32,
	Direct,
}

mod_rm :: proc(mod: Mod, reg: Reg, r_m: Reg) -> u8 {
	Mod_Rm :: bit_field u8 {
		r_m: u16 | 3,
		reg: u16 | 3,
		mod: Mod | 2,
	}

	return u8(Mod_Rm{mod = mod, reg = reg.index, r_m = r_m.index})
}

mod_sm :: #force_inline proc(mod: Mod, #any_int sub: int, r_m: Reg) -> u8 {
	return mod_rm(mod, Reg(sub), r_m)
}

sib :: proc(base: Reg, index: Reg, #any_int scale: int) -> u8 {
	Sib :: bit_field u8 {
		base:  u16 | 3,
		index: u16 | 3,
		scale: u8  | 2,
	}

	assert(intrinsics.count_ones(scale) == 1 && scale <= 8)

	return u8(
		Sib {
			base = base.index,
			index = index.index,
			scale = u8(intrinsics.count_trailing_zeros(scale)),
		},
	)
}

rex :: proc(reg, ptr, idx: Reg, wide: bool) -> u8 {
	res: u8 = NOOP_REX

	if wide do res |= 0b0000_1000
	if reg.index >= 8 do res |= 0b0000_0100
	if idx.index >= 8 do res |= 0b0000_0010
	if ptr.index >= 8 do res |= 0b0000_0001

	return res
}
