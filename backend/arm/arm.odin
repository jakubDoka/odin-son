package arm

import backend ".."
import "../../vendored/gam/util/arna"
import "core:fmt"
import "core:mem"
import "core:slice"

Reg :: backend.Reg
Node :: backend.Node
Node_ID :: backend.Node_ID
emit :: backend.emit
graph_expand :: backend.graph_expand
graph_get :: backend.graph_get

MASK_SIZE :: 64

RK_GENERAL :: Reg_Kind(0)
RK_VECTOR :: Reg_Kind(1)
RK_COUNT :: 2

X0 :: Reg(0)
X1 :: Reg(1)
X2 :: Reg(2)
X3 :: Reg(3)
X4 :: Reg(4)
X5 :: Reg(5)
X6 :: Reg(6)
X7 :: Reg(7)
X8 :: Reg(8)
X9 :: Reg(9)
X10 :: Reg(10)
X11 :: Reg(11)
X12 :: Reg(12)
X13 :: Reg(13)
X14 :: Reg(14)
X15 :: Reg(15)
X16 :: Reg(16)
X17 :: Reg(17)
X18 :: Reg(18)
X19 :: Reg(19)
X20 :: Reg(20)
X21 :: Reg(21)
X22 :: Reg(22)
X23 :: Reg(23)
X24 :: Reg(24)
X25 :: Reg(25)
X26 :: Reg(26)
X27 :: Reg(27)
X28 :: Reg(28)
X29 :: Reg(29)
X30 :: Reg(30)
XZR :: Reg(31)
SP :: Reg(31)

V_BANK :: u16(RK_VECTOR) << 12
V0 :: Reg(V_BANK | 0)
V1 :: Reg(V_BANK | 1)
V2 :: Reg(V_BANK | 2)
V3 :: Reg(V_BANK | 3)
V4 :: Reg(V_BANK | 4)
V5 :: Reg(V_BANK | 5)
V6 :: Reg(V_BANK | 6)
V7 :: Reg(V_BANK | 7)
V8 :: Reg(V_BANK | 8)
V9 :: Reg(V_BANK | 9)
V10 :: Reg(V_BANK | 10)
V11 :: Reg(V_BANK | 11)
V12 :: Reg(V_BANK | 12)
V13 :: Reg(V_BANK | 13)
V14 :: Reg(V_BANK | 14)
V15 :: Reg(V_BANK | 15)
V16 :: Reg(V_BANK | 16)
V17 :: Reg(V_BANK | 17)
V18 :: Reg(V_BANK | 18)
V19 :: Reg(V_BANK | 19)
V20 :: Reg(V_BANK | 20)
V21 :: Reg(V_BANK | 21)
V22 :: Reg(V_BANK | 22)
V23 :: Reg(V_BANK | 23)
V24 :: Reg(V_BANK | 24)
V25 :: Reg(V_BANK | 25)
V26 :: Reg(V_BANK | 26)
V27 :: Reg(V_BANK | 27)
V28 :: Reg(V_BANK | 28)
V29 :: Reg(V_BANK | 29)
V30 :: Reg(V_BANK | 30)
V31 :: Reg(V_BANK | 31)

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

	Node_Type :: enum u16 {}
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
	GPA_MASK := [?]i64{0x7FFFFFF}
	@(static, rodata)
	GPA_SPILL_MASK := [?]i64{~i64(1 << uint(SP))}
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
	case .Root_Mem, .Sym, .Jump:
		return {out = IOUT}
	case .Mul, .Add, .Sub:
		return {out = out, masks = nmasks[:2]}
	case .Eq:
		return {out = out, masks = GPA_MASKS[:2]}
	case .CInt:
		return {out = out}
	case .Phi:
		return {
			out = out,
			input_start = 1,
			masks = nmasks[:len(node.inps) - 1],
		}
	case .Split:
		return {out = out, masks = nmasks[:1]}
	case .If:
		return {
			out = IOUT,
			input_start = 1,
			masks = nmasks[:1 -
			int(graph_get(graph, node.inps[0]).dt == .Void)],
		}
	case .Return:
		return {
			out = IOUT,
			input_start = backend.RET_PREFIX,
			masks = dup(
				{
					single(ra, ARM_SYSTEMV_CC.args[0][0]),
					single(ra, ARM_SYSTEMV_CC.args[0][1]),
				},
			),
		}
	}

	fmt.panicf("TODO %v", node)
}

Ctx :: struct {
	using inner:  backend.Codegen_Emit_Ctx,
	code_start:   uint,
	local_relocs: [dynamic]Local_Reloc,
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

	arna.alloc(ctx.code, 0, 4)

	ctx.code_start = ctx.code.pos

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
		jump := (dst_offset - reloc.offset) / 4

		slot := (^backend.Reloc_Slot)(ctx.code.ptr[reloc.offset:])
		if reloc.is_bcond {
			slot.r3.addend_19 = jump
		} else {
			slot.r2.addend_26 = jump
		}
	}

	code := ctx.code.ptr[ctx.code_start:ctx.code.pos]

	return {code = code}
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
	}

	@(static, rodata)
	NODE_TO_OP := #partial [Node_Type]u8 {
		.Add = 0b0001011,
		.Sub = 0b1001011,
		.Eq ..= .U_Ge     = 0b1101011,
	}

	cc_neg :: proc(c: Cond) -> Cond {return Cond(u8(c) ~ 1)}

	node := graph_expand(ctx, instr)
	kind := atype(node)
	block_base := ctx.gvn - u32(len(ctx.schedule.bbs))
	op := NODE_TO_OP[kind]

	#partial switch kind {
	case .Root_Mem, .Sym, .Phi:
	case .Split:
		rm := reg_of(ctx, node.inps[0])
		rd := reg_of(ctx, instr)

		assert(rm.index < 32, "TODO")
		assert(rd.index < 32, "TODO")

		emit_op(ctx.code, sh_instr(.x, 0b0101010, nil, rd, XZR, rm))
	case .Add, .Sub:
		rd := reg_of(ctx, instr)
		rn := reg_of(ctx, node.inps[0])
		rm := reg_of(ctx, node.inps[1])

		emit_op(ctx.code, sh_instr(.x, op, nil, rd, rn, rm))
	case .Mul:
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
	case .Eq:
		rn := reg_of(ctx, node.inps[0])
		rm := reg_of(ctx, node.inps[1])

		emit_op(ctx.code, sh_instr(.x, op, nil, XZR, rn, rm))

		if node.dt != .Void {
			op :: 0b10011010100
			rm :: XZR
			cond := CC_TABLE[kind]
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
			op :: 0b110100101
			hw :: 0b00

			imm := i16(cint.value)
			assert(i64(imm) == cint.value, "TODO")

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

		if graph_get(ctx, node.inps[1]).dt == .Void {
			op :: 0b01010100
			imm19 :: 0
			pd :: 0

			cond := cc_neg(CC_TABLE[kind])
			if !is_consecutive do cond = cc_neg(cond)

			emit_op(ctx.code, op << 24 | imm19 << 5 | pd << 4 | u32(cond))
		} else {
			op: u32 = 0b10110100 // cbnz
			if !is_consecutive do op = 0b10110101 // cbz

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
			op :: 0b000101
			emit_op(ctx.code, op << 26)
		}
	case .Return:
		emit_op(ctx.code, 0b1101011001011111000000_11110_00000)
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
