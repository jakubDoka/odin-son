package arm

import backend ".."
import "../../vendored/gam/util/arna"
import "../../vendored/gam/util/bit_arr"
import "core:fmt"
import "core:mem"
import "core:slice"

Reg :: backend.Reg
Node :: backend.Node
Node_ID :: backend.Node_ID
emit :: backend.emit
graph_expand :: backend.graph_expand
graph_get :: backend.graph_get

STACK_ALIGNMENT :: 16

MASK_SIZE :: 64

RK_GENERAL :: Reg_Kind(0)
RK_VECTOR :: Reg_Kind(1)
RK_COUNT :: 2

@(rodata)
SPILL_SLOT_SIZE := [RK_COUNT]i32 {
	RK_GENERAL = 8,
	RK_VECTOR  = 16,
}

X0, X1, X2, X3, X4, X5 :: Reg(0), Reg(1), Reg(2), Reg(3), Reg(4), Reg(5)
X6, X7, X8, X9, X10, X11 :: Reg(6), Reg(7), Reg(8), Reg(9), Reg(10), Reg(11)
X12, X13, X14, X15, X16 :: Reg(12), Reg(13), Reg(14), Reg(15), Reg(16)
X17, X18, X19, X20, X21 :: Reg(17), Reg(18), Reg(19), Reg(20), Reg(21)
X22, X23, X24, X25, X26 :: Reg(22), Reg(23), Reg(24), Reg(25), Reg(26)
X27, X28, X29, X30 :: Reg(27), Reg(28), Reg(29), Reg(30)
XZR, SP :: Reg(31), Reg(31)

V_BANK :: u16(RK_VECTOR) << 12
V0, V1, V2 :: Reg(V_BANK | 0), Reg(V_BANK | 1), Reg(V_BANK | 2)
V3, V4, V5 :: Reg(V_BANK | 3), Reg(V_BANK | 4), Reg(V_BANK | 5)
V6, V7, V8 :: Reg(V_BANK | 6), Reg(V_BANK | 7), Reg(V_BANK | 8)
V9, V10, V11 :: Reg(V_BANK | 9), Reg(V_BANK | 10), Reg(V_BANK | 11)
V12, V13, V14 :: Reg(V_BANK | 12), Reg(V_BANK | 13), Reg(V_BANK | 14)
V15, V16, V17 :: Reg(V_BANK | 15), Reg(V_BANK | 16), Reg(V_BANK | 17)
V18, V19, V20 :: Reg(V_BANK | 18), Reg(V_BANK | 19), Reg(V_BANK | 20)
V21, V22, V23 :: Reg(V_BANK | 21), Reg(V_BANK | 22), Reg(V_BANK | 23)
V24, V25, V26 :: Reg(V_BANK | 24), Reg(V_BANK | 25), Reg(V_BANK | 26)
V27, V28, V29 :: Reg(V_BANK | 27), Reg(V_BANK | 28), Reg(V_BANK | 29)
V30, V31 :: Reg(V_BANK | 30), Reg(V_BANK | 31)

ARM_SYSTEMV_CC := backend.Call_Conv {
	name         = "ARM_SYSTEMV_CC",
	caller_saved = {
		{
			X0,
			X1,
			X2,
			X3,
			X4,
			X5,
			X6,
			X7,
			X8,
			X9,
			X10,
			X11,
			X12,
			X13,
			X14,
			X15,
			X16,
			X17,
			X18,
		},
		{
			V0,
			V1,
			V2,
			V3,
			V4,
			V5,
			V6,
			V7,
			V16,
			V17,
			V18,
			V19,
			V20,
			V21,
			V22,
			V23,
			V24,
			V25,
			V26,
			V27,
			V28,
			V29,
			V30,
			V31,
		},
	},
	callee_saved = {
		{X19, X20, X21, X22, X23, X24, X25, X26, X27, X28},
		{V8, V9, V10, V11, V12, V13, V14, V15},
	},
	args         = {
		{X0, X1, X2, X3, X4, X5, X6, X7},
		{V0, V1, V2, V3, V4, V5, V6, V7},
	},
	rets         = {{X0, X1}, {V0, V1}},
}

SPEC_NOT_PRESENT :: (#load("node_specs.odin", string) or_else "") == ""

when SPEC_NOT_PRESENT {
	Reg_Kind :: backend.Reg_Kind

	inherit_idx_of :: proc($T: typeid) -> u8 {return 0}

	Node_Type :: enum u16 {
		Msub,
		CLoad,
	}
}

Op :: u32

emit_op :: proc(code: ^arna.Allocator, instr: Op) {
	instr := instr
	emit(code, mem.ptr_to_bytes(&instr))
}

atype :: proc(node: ^Node) -> Node_Type {
	return Node_Type(node.rtype)
}

peep :: proc(
	ctx: backend.Peep_Ctx,
	node: backend.Expanded_Node,
	_: $T,
) -> backend.Node_ID {
	id := backend.graph_id(ctx, node)
	kind := atype(node)

	#partial switch kind {
	case .Eq ..= .U_Ge:
		if len(node.outs) == 1 &&
		   graph_get(ctx, node.outs[0].id).itype == .If &&
		   node.dt != .Void {
			node.dt = .Void
			return id
		}
	case .Rem, .U_Rem:
		return graph_add_msub(
			ctx,
			"rmms",
			node.dt,
			backend.graph_add_bin_op(
				ctx,
				"rmdv",
				kind == .Rem ? .Div : .U_Div,
				node.dt,
				node.inps[0],
				node.inps[1],
			),
			node.inps[1],
			node.inps[0],
		)
	}

	return 0
}

post_schedule_peep :: proc(
	_: backend.PS_Peep_Ctx,
	_: backend.Expanded_Node,
	_: $T,
) -> backend.Node_ID {
	return 0
}

meta_of :: #force_inline proc(
	graph: ^backend.Graph,
	ra: ^backend.Regalloc,
	node: backend.Expanded_Node,
	_: $T,
) -> backend.Regalloc_Node_Meta {
	IOUT :: backend.INVALID_RM_INDEX

	@(static, rodata)
	GPA_MASK := [?]i64{0x3FFFFFFF}
	@(static, rodata)
	GPA_SPILL_MASK := [?]i64{~i64(1 << uint(SP) | 1 << 30)}
	@(static, rodata)
	VEC_MASK := [?]i64{0xFFFFFFFF}
	@(static, rodata)
	VEC_SPILL_MASK := [?]i64{~i64(0)}

	GPA_MASK_IDX :: backend.RM_Intern_Idx{}
	VEC_MASK_IDX :: backend.RM_Intern_Idx {
		kind = RK_VECTOR,
	}
	GPA_SPILL_MASK_IDX :: backend.RM_Intern_Idx {
		index = 1,
	}
	VEC_SPILL_MASK_IDX :: backend.RM_Intern_Idx {
		kind  = RK_VECTOR,
		index = 1,
	}

	@(static, rodata)
	GPA_MASKS := [6]backend.RM_Intern_Idx{}

	@(static, rodata)
	VEC_MASKS := [6]backend.RM_Intern_Idx {
		0 ..< 6 = VEC_MASK_IDX,
	}

	@(static, rodata)
	GPA_SPILL_MASKS := [6]backend.RM_Intern_Idx {
		0 ..< 6 = GPA_SPILL_MASK_IDX,
	}

	@(static, rodata)
	VEC_SPILL_MASKS := [6]backend.RM_Intern_Idx {
		0 ..< 6 = VEC_SPILL_MASK_IDX,
	}

	if node.gvn == 0 {
		ra.mask_len = MASK_SIZE
		rslice(ra, RK_GENERAL, GPA_MASK[:])
		rslice(ra, RK_VECTOR, VEC_MASK[:])
		rslice(ra, RK_GENERAL, GPA_SPILL_MASK[:])
		rslice(ra, RK_VECTOR, VEC_SPILL_MASK[:])
	}

	single :: backend.rm_intern_single
	rslice :: backend.rm_intern_slice

	dup :: #force_inline proc(
		msks: []backend.RM_Intern_Idx,
	) -> []backend.RM_Intern_Idx {
		return slice.clone(msks)
	}

	nkind := ra.datatype_to_reg_kind[node.dt]

	masks := [RK_COUNT][]backend.RM_Intern_Idx {
		RK_GENERAL = GPA_MASKS[:],
		RK_VECTOR  = VEC_MASKS[:],
	}
	nmasks := masks[nkind]
	out := nmasks[0]

	smasks := [RK_COUNT][]backend.RM_Intern_Idx {
		RK_GENERAL = GPA_SPILL_MASKS[:],
		RK_VECTOR  = VEC_SPILL_MASKS[:],
	}
	snmasks := smasks[nkind]
	sout := snmasks[0]

	if node.dt == .Void {
		out = IOUT
		sout = IOUT
	}

	#partial switch atype(node) {
	case .Root_Mem, .Sym, .Jump, .Mem, .Local:
		return {out = IOUT}
	case .Add ..= .Xor, .Shl ..= .And_Not, .F_Add ..= .F_Div:
		return {out = out, masks = nmasks[:2]}
	case .Msub:
		return {out = out, masks = nmasks[:3]}
	case .Eq ..= .U_Ge:
		return {out = out, masks = GPA_MASKS[:2]}
	case .F_Eq ..= .F_Ge:
		if out != IOUT {
			out = GPA_MASK_IDX
		}
		return {out = out, masks = VEC_MASKS[:2]}
	case .F_To_I:
		return {out = out, masks = VEC_MASKS[:1]}
	case .CInt, .Local_Addr:
		return {out = out}
	case .Phi:
		return {
			out = out,
			input_start = 1,
			masks = nmasks[:len(node.inps) - 1],
		}
	case .Split, .Uext, .Sext:
		return {out = sout, masks = snmasks[:1]}
	case .If:
		return {
			out = IOUT,
			input_start = 1,
			masks = nmasks[:1 -
			int(graph_get(graph, node.inps[1]).dt == .Void)],
		}
	case .Call:
		real_len := len(node.inps)
		for ; graph_get(graph, node.inps[real_len - 1]).itype == .Local;
		    real_len -= 1 {}

		masks := make([]backend.RM_Intern_Idx, real_len - backend.CALL_PREFIX)
		for inp, i in node.inps[backend.CALL_PREFIX:real_len] {
			inode := graph_get(graph, inp)
			nkind := ra.datatype_to_reg_kind[inode.dt]
			assert(nkind == RK_GENERAL)
			masks[i] = single(ra, ARM_SYSTEMV_CC.args[0][i])
		}

		return {out = IOUT, input_start = backend.CALL_PREFIX, masks = masks}
	case .Set, .Copy:
		return {
			out = IOUT,
			input_start = 2,
			masks = dup(
				{
					single(ra, ARM_SYSTEMV_CC.args[0][0]),
					single(ra, ARM_SYSTEMV_CC.args[0][1]),
					single(ra, ARM_SYSTEMV_CC.args[0][2]),
				},
			),
		}
	case .Store:
		vl := graph_get(graph, node.inps[3])
		nkind := ra.datatype_to_reg_kind[vl.dt]
		return {
			out = IOUT,
			input_start = 2,
			masks = dup({GPA_MASK_IDX, masks[nkind][0]}),
		}
	case .Load:
		return {out = out, input_start = 2, masks = GPA_MASKS[:1]}
	case .Ret:
		idx := backend.graph_extra(graph, node, backend.Tup).idx
		assert(nkind == RK_GENERAL)
		return {out = single(ra, ARM_SYSTEMV_CC.rets[0][idx])}
	case .Param:
		idx := backend.graph_extra(graph, node, backend.Tup).idx
		assert(nkind == RK_GENERAL)
		return {out = single(ra, ARM_SYSTEMV_CC.args[0][idx])}
	case .Return:
		return {
			out = IOUT,
			input_start = min(backend.RET_PREFIX, u8(len(node.inps))),
			masks = dup(
				{
					single(ra, ARM_SYSTEMV_CC.rets[0][0]),
					single(ra, ARM_SYSTEMV_CC.rets[0][1]),
				},
			),
		}
	}

	fmt.panicf("TODO %v", node)
}

Ctx :: struct {
	using inner:        backend.Codegen_Emit_Ctx,
	code_start:         uint,
	spill_slot_base:    [RK_COUNT]i32,
	stack_param_offset: [RK_COUNT][dynamic]i32,
	local_relocs:       [dynamic]Local_Reloc,
	used:               bit_arr.Bit_Set,
	stack_size:         i32,
	push_base:          i32,
	has_call:           bool,
}

Local_Reloc :: struct {
	offset:   u32,
	dest:     u32,
	is_bcond: bool,
}

emit_function :: proc(
	ectx: backend.Codegen_Emit_Ctx,
) -> backend.Codegen_Output {

	ctx: Ctx
	ctx.inner = ectx
	ctx.used = bit_arr.init(MASK_SIZE)

	relocs_start := ctx.relocs.pos

	arna.alloc(ctx.code, 0, 4)

	ctx.code_start = ctx.code.pos

	for reg in ctx.allocs {
		if reg.kind == RK_GENERAL {
			bit_arr.set_unbounded(ctx.used, int(reg.index))
		}
	}

	idx := ctx.code.pos
	emit_op(ctx.code, 0)

	ctx.has_call = backend.layout_call_args(ctx, ctx.schedule, &ctx.stack_size)

	prelude: {
		ctx.push_base = ctx.stack_size
		for reg in ctx.callee_saved[RK_GENERAL] {
			if bit_arr.contains(ctx.used, int(reg)) {
				// str rt, [rn, $imm12]
				emit_op(
					ctx.code,
					imm12_instr(0b1111100100, reg, SP, ctx.stack_size / 8),
				)

				ctx.stack_size += 8
			}
		}

		if ctx.has_call {
			// stp.post x29, x30, [SP, pushed / 8]
			op: u32 : 0b1010100100
			imm7 := ctx.stack_size / 8
			assert(imm7 << 25 >> 25 == imm7)
			rt2 :: X30
			rn :: SP
			rt :: X29

			emit_op(
				ctx.code,
				op << 22 |
				u32(imm7 & 0x7f) << 15 |
				u32(rt2.index) << 10 |
				u32(rn.index) << 5 |
				u32(rt.index),
			)
			ctx.stack_size += 16
		}
	}

	backend.layout_spill_slots(
		ctx,
		ctx.spill_slot_base[:],
		SPILL_SLOT_SIZE[:],
		&ctx.stack_size,
	)

	backend.layout_locals(ctx, ctx.schedule, &ctx.stack_size)

	ctx.stack_size = i32(
		mem.align_forward_int(int(ctx.stack_size), STACK_ALIGNMENT),
	)

	if ctx.stack_size != 0 {
		// sub sp, sp, ctx.stack_size
		(^Op)(ctx.code.ptr[idx:])^ = imm12_instr(
			0b1101000100,
			SP,
			SP,
			ctx.stack_size,
		)
	} else {
		ctx.code.pos = idx
	}

	for &bb, i in ctx.schedule.bbs {
		bb.offset = u32(ctx.code.pos)

		last := graph_expand(ctx, bb.instrs[len(bb.instrs) - 1])
		is_consecutive :=
			i + 1 < len(ctx.bbs) &&
			0 < len(last.outs) &&
			ctx.bbs[i + 1].head == last.outs[0].id

		for instr in bb.instrs {
			emit_instr(&ctx, instr, is_consecutive, struct{}{})
		}
	}

	block_base := ctx.gvn - u32(len(ctx.bbs))
	for &reloc in ctx.local_relocs {
		size: u32 = 4

		for {
			bb := &ctx.bbs[reloc.dest]

			if len(bb.instrs) > 1 do break
			jmp := graph_expand(ctx, bb.instrs[0])
			if jmp.itype != .Jump do break

			reloc.dest = graph_get(ctx, jmp.outs[0].id).gvn - block_base
		}

		dst_offset := ctx.bbs[reloc.dest].offset
		jump := i32(dst_offset - reloc.offset) / 4

		slot := (^backend.Reloc_Slot)(ctx.code.ptr[reloc.offset:])
		if reloc.is_bcond {
			slot.r3.addend_19 = jump
		} else {
			slot.r2.addend_26 = jump
		}
	}

	code := ctx.code.ptr[ctx.code_start:ctx.code.pos]
	relocs := mem.slice_data_cast(
		[]backend.Reloc,
		ctx.relocs.ptr[relocs_start:ctx.relocs.pos],
	)

	return {code = code, relocs = relocs}
}

@(disabled = SPEC_NOT_PRESENT)
emit_instr :: proc(
	ctx: ^Ctx,
	instr: backend.Node_ID,
	is_consecutive: bool,
	_: $T,
) {
	Cond :: enum u8 {
		EQ,
		NE,
		CS,
		CC,
		MI,
		PL,
		VS,
		VC,
		HI,
		LS,
		GE,
		LT,
		GT,
		LE,
		AL,
		NV,
	}

	@(static, rodata)
	CC_TABLE := #partial [Node_Type]Cond {
		.Eq   = .EQ,
		.Ne   = .NE,
		.U_Ge = .CS,
		.U_Lt = .CC,
		.U_Gt = .HI,
		.U_Le = .LS,
		.Ge   = .GE,
		.Lt   = .LT,
		.Gt   = .GT,
		.Le   = .LE,
		.F_Eq = .EQ,
		.F_Ne = .NE,
		.F_Lt = .MI,
		.F_Le = .LS,
		.F_Gt = .GT,
		.F_Ge = .GE,
	}

	@(static, rodata)
	NODE_TO_OP := #partial [Node_Type]u32 {
		.Add     = 0x0B000000,
		.Sub     = 0x4B000000,
		.And     = 0x0A000000,
		.Or      = 0x2A000000,
		.Xor     = 0x4A000000,
		.And_Not = 0x0A200000,
		.Eq ..= .U_Ge         = 0x6B00001F,
		.Shl     = 0x1AC02000,
		.U_Shr   = 0x1AC02400,
		.Shr     = 0x1AC02800,
		.Mul     = 0x1B007C00,
		.U_Div   = 0x1AC00800,
		.Div     = 0x1AC00C00,
		.U_Rem   = 0x1AC00800,
		.Rem     = 0x1AC00C00,
		.F_Add   = 0x1E202800,
		.F_Sub   = 0x1E203800,
		.F_Mul   = 0x1E200800,
		.F_Div   = 0x1E201800,
		.F_Eq ..= .F_Ge         = 0x1E202000,
	}
	cc_neg :: proc(c: Cond) -> Cond {return Cond(u8(c) ~ 1)}

	node := graph_expand(ctx, instr)
	kind := atype(node)
	block_base := ctx.gvn - u32(len(ctx.schedule.bbs))
	op := NODE_TO_OP[kind]
	is_64 := node.dt == .I64

	inp: backend.Expanded_Node
	is_f64: bool
	if 0 < len(node.inps) {
		inp = graph_expand(ctx, node.inps[0])
		is_f64 = inp.dt == .F64
	}

	#partial switch kind {
	case .Root_Mem, .Sym, .Phi, .Ret, .Mem, .Param, .Local:
	case .Local_Addr:
		offset := backend.graph_extra(ctx, node.inps[0], backend.Local).offset
		assert(offset < 4096)

		// add rinstr, sp, #offset
		emit_op(
			ctx.code,
			imm12_instr(0b1001000100, reg_of(ctx, instr), SP, offset),
		)
	case .Store:
		vl := graph_get(ctx, node.inps[3])

		// str rvl, [rinp2, $imm12]
		op: u32
		#partial switch vl.dt {
		case .I64:
			op = 0b1111100100
		case .I8:
			op = 0b0011100100
		case:
			fmt.panicf("TODO: %v", vl)
		}

		emit_op(
			ctx.code,
			imm12_instr(
				op,
				reg_of(ctx, node.inps[3]),
				reg_of(ctx, node.inps[2]),
				0,
			),
		)
	case .Load:
		// ldr rinstr, [rinp2, $imm12]
		emit_op(
			ctx.code,
			imm12_instr(
				0b1111100101,
				reg_of(ctx, instr),
				reg_of(ctx, node.inps[2]),
				0,
			),
		)
	case .Split:
		rd := reg_of(ctx, instr)
		rm := reg_of(ctx, node.inps[0])

		rd_off := spill_slot_offset(ctx, rd) / 8
		rm_off := spill_slot_offset(ctx, rm) / 8

		assert(rd_off < 4096)
		assert(rm_off < 4096)
		assert(rm.kind == RK_GENERAL)
		assert(rd.kind == RK_GENERAL)

		if rm.index >= 32 && rd.index >= 32 {
			panic("TODO")
		} else if rm.index >= 32 {
			// ldr rd, [SP, rm_off]
			emit_op(ctx.code, imm12_instr(0b1111100101, rd, SP, rm_off))
		} else if rd.index >= 32 {
			// str rm, [SP, rd_off]
			emit_op(ctx.code, imm12_instr(0b1111100100, rm, SP, rd_off))
		} else {
			// mov rd, rm
			emit_op(ctx.code, sh_instr(.x, 0b0101010, nil, rd, XZR, rm))
		}

		spill_slot_offset :: proc(ctx: ^Ctx, reg: Reg) -> i32 {
			return backend.spill_slot_offset(
				ctx,
				ctx.stack_param_offset[:],
				ctx.spill_slot_base[:],
				SPILL_SLOT_SIZE[:],
				reg,
			)
		}
	case .Uext:
		rd := reg_of(ctx, instr)
		rm := reg_of(ctx, node.inps[0])

		UXTB :: u32(0x53001C00)
		UXTH :: u32(0x53003C00)
		MOV_W :: u32(0x2A0003E0)

		op: u32
		#partial switch inp.dt {
		case .I8:
			op = UXTB | u32(rm.index) << 5 | u32(rd.index)
		case .I16:
			op = UXTH | u32(rm.index) << 5 | u32(rd.index)
		case .I32:
			op = MOV_W | u32(rm.index) << 16 | u32(rd.index)
		case:
			panic("no")
		}

		emit_op(ctx.code, op)
	case .Sext:
		rd := reg_of(ctx, instr)
		rm := reg_of(ctx, node.inps[0])

		SXTB_W :: u32(0x13001C00)
		SXTH_W :: u32(0x13003C00)

		SXTB_X :: u32(0x93401C00)
		SXTH_X :: u32(0x93403C00)
		SXTW_X :: u32(0x93407C00)

		op: u32
		#partial switch inp.dt {
		case .I8:
			op = is_64 ? SXTB_X : SXTB_W
		case .I16:
			op = is_64 ? SXTH_X : SXTH_W
		case .I32:
			assert(is_64)
			op = SXTW_X
		case:
			panic("no")
		}

		op |= u32(rm.index) << 5 | u32(rd.index)

		emit_op(ctx.code, op)
	case .F_Add ..= .F_Div:
		rd := reg_of(ctx, instr)
		rn := reg_of(ctx, node.inps[0])
		rm := reg_of(ctx, node.inps[1])

		// add/sub rd, rn, rm
		emit_op(ctx.code, fff(is_f64, op, rd, rn, rm))
	case .Add ..= .Xor, .Div, .U_Div, .And_Not, .Shl ..= .U_Shr:
		rd := reg_of(ctx, instr)
		rn := reg_of(ctx, node.inps[0])
		rm := reg_of(ctx, node.inps[1])

		// add/sub rd, rn, rm
		emit_op(ctx.code, rrr(is_64, op, rd, rn, rm))
	case .Rem, .U_Rem:
		panic("no")
	case .Msub:
		rd := reg_of(ctx, instr)
		rn := reg_of(ctx, node.inps[0])
		rm := reg_of(ctx, node.inps[1])
		ra := reg_of(ctx, node.inps[2])

		// msub rd, rd, rm, rn
		op :: 0b0011011000
		pd :: 0b1

		emit_op(
			ctx.code,
			u32(is_64) << 31 |
			op << 21 |
			u32(rm) << 16 |
			pd << 15 |
			u32(ra) << 10 |
			u32(rn) << 5 |
			u32(rd),
		)
	case .Mul:
		// mul rd, rn, rm
		op :: 0b10011011000
		rm := reg_of(ctx, node.inps[1])
		pd :: 0b0
		ra := XZR
		rn := reg_of(ctx, node.inps[0])
		rd := reg_of(ctx, instr)

		emit_op(
			ctx.code,
			op << 21 |
			u32(rm) << 16 |
			pd << 15 |
			u32(ra) << 10 |
			u32(rn) << 5 |
			u32(rd),
		)
	case .Eq ..= .U_Ge, .F_Eq ..= .F_Ge:
		rn := reg_of(ctx, node.inps[0])
		rm := reg_of(ctx, node.inps[1])

		if inp.dt >= .F32 {
			// fcmp rn, rm
			emit_op(ctx.code, fff(is_f64, op, XZR, rn, rm))
		} else {
			// cmp rn, rm
			emit_op(ctx.code, rrr(is_64, op, XZR, rn, rm))
		}

		if node.dt != .Void {
			// csinc rd, xzr, xzr, cc
			op :: 0b10011010100
			rm :: XZR
			cond := cc_neg(CC_TABLE[kind])
			pd :: 0b01
			rn :: XZR
			rd := reg_of(ctx, instr)
			emit_op(
				ctx.code,
				op << 21 |
				u32(rm.index) << 16 |
				u32(cond) << 12 |
				pd << 10 |
				u32(rn.index) << 5 |
				u32(rd.index),
			)
		}
	case .CInt:
		cint := backend.graph_extra(ctx, node, backend.CInt)

		#partial switch node.dt {
		case .I8 ..= .I64:
			// movz reg, imm, hw
			op: u32 = 0b110100101
			imm := i16(cint.value)
			fmt.assertf(i64(imm) == cint.value, "TODO: %v", cint.value)

			if cint.value < 0 {
				// movn reg, ~imm, hw
				op = 0b100100101
				imm = ~imm
			}

			hw :: 0b00

			reg := reg_of(ctx, instr)

			emit_op(
				ctx.code,
				op << 23 | hw << 21 | u32(imm) << 5 | u32(reg.index),
			)
		case:
			fmt.panicf("TODO: %v", node)
		}
	case .If:
		append(
			&ctx.local_relocs,
			Local_Reloc {
				offset = u32(ctx.code.pos),
				dest = graph_get(ctx, node.outs[int(is_consecutive)].id).gvn -
				block_base,
				is_bcond = true,
			},
		)

		cond := graph_get(ctx, node.inps[1])

		if cond.dt == .Void {
			// b.<cond> <imm19>
			op :: 0b01010100
			imm19 :: 0
			pd :: 0

			cond := cc_neg(CC_TABLE[atype(cond)])
			if !is_consecutive do cond = cc_neg(cond)

			emit_op(ctx.code, op << 24 | imm19 << 5 | pd << 4 | u32(cond))
		} else {
			op: u32 = 0b10110100 // cbnz <imm19>, rt
			if !is_consecutive do op = 0b10110101 // cbz <imm19>, rt

			imm19 :: 0
			rt := reg_of(ctx, node.inps[1])

			emit_op(ctx.code, op << 24 | imm19 << 5 | u32(rt.index))
		}

		if !is_consecutive do break
		fallthrough
	case .Jump:
		if !is_consecutive {
			append(
				&ctx.local_relocs,
				Local_Reloc {
					offset = u32(ctx.code.pos),
					dest = graph_get(ctx, node.outs[0].id).gvn - block_base,
				},
			)

			// b <imm26>
			op :: 0b000101
			emit_op(ctx.code, op << 26)
		}
	case .Call, .Set, .Copy:
		id: u32
		#partial switch kind {
		case .Call:
			id = backend.graph_extra(ctx, node, backend.Call).cid
		case .Set:
			id = ctx.lib_calls.set.id
		case .Copy:
			id = ctx.lib_calls.copy.id
		}

		// bl <imm26>
		op :: 0b100101
		imm26 :: 0

		backend.add_reloc(ctx.relocs)^ = {
			offset = u32(ctx.code.pos - ctx.code_start),
			kind   = .Text,
			size   = .r26,
			id     = id,
		}
		emit_op(ctx.code, op << 26 | imm26)
	case .Return:
		postlude: {
			pushed := ctx.push_base
			for reg in ctx.callee_saved[RK_GENERAL] {
				if bit_arr.contains(ctx.used, int(reg)) {
					// ldr rt, [sp, $imm12]
					emit_op(
						ctx.code,
						imm12_instr(0b1111100101, reg, SP, pushed / 8),
					)
					pushed += 8
				}
			}

			if ctx.has_call {
				// ldp x29, x30, [sp, pushed / 8]
				op: u32 : 0b1010100101
				imm7 := pushed / 8
				rt2 :: X30
				rn :: SP
				rt :: X29

				emit_op(
					ctx.code,
					op << 22 |
					u32(imm7 & 0x7f) << 15 |
					u32(rt2.index) << 10 |
					u32(rn.index) << 5 |
					u32(rt.index),
				)

				pushed += 16
			}

			if ctx.stack_size != 0 {
				// add sp, sp, ctx.stack_size
				emit_op(
					ctx.code,
					imm12_instr(0b1001000100, SP, SP, ctx.stack_size),
				)
			}
		}

		// ret
		emit_op(ctx.code, 0xd65f03c0)
	case:
		fmt.panicf("TODO %v", node)
	}

}

reg_of :: proc(ctx: ^Ctx, node: Node_ID) -> Reg {
	return ctx.allocs[graph_get(ctx, node).gvn]
}

Op_Width :: enum u32 {
	w,
	x,
}

Shift :: enum u32 {
	LSL,
	LSR,
	ASR,
	ROR,
}

sh_instr :: proc(
	width: Op_Width,
	#any_int opc: u32,
	shift: Shift,
	rd, rn, rm: Reg,
	imm: u32 = 0,
) -> Op {
	Layout :: bit_field u32 {
		rd:    u16      | 5,
		rn:    u16      | 5,
		imm:   u32      | 6,
		rm:    u16      | 5,
		n:     u32      | 1,
		shift: Shift    | 2,
		opc:   u32      | 7,
		width: Op_Width | 1,
	}

	return u32(
		Layout {
			width = width,
			opc = opc,
			shift = shift,
			imm = imm,
			rd = rd.index,
			rn = rn.index,
			rm = rm.index,
		},
	)
}

imm12_instr :: proc(#any_int opc: u32, rt, rn: Reg, #any_int imm: i32) -> Op {
	Layout :: bit_field u32 {
		rt:  u16 | 5,
		rn:  u16 | 5,
		imm: u32 | 12,
		opc: u32 | 10,
	}

	return u32(Layout{opc = opc, imm = u32(imm), rt = rt.index, rn = rn.index})
}

rrr :: proc(is_64: bool, op: u32, rd, rn, rm: Reg) -> u32 {
	inst := op

	if is_64 {
		inst |= 1 << 31
	}

	inst |= u32(rm.index) << 16
	inst |= u32(rn.index) << 5
	inst |= u32(rd.index)

	return inst
}

fff :: proc(is_64: bool, op: u32, rd, rn, rm: Reg) -> u32 {
	instr := op

	if is_64 {
		instr |= 1 << 22
	}

	instr |= u32(rm.index) << 16
	instr |= u32(rn.index) << 5
	instr |= u32(rd.index)

	return instr
}
