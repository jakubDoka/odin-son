package arm

import bac ".."
import "../../vendored/gam/util/arna"
import "../../vendored/gam/util/bit_arr"
import "base:intrinsics"
import "core:fmt"
import "core:mem"
import "core:slice"

Reg :: bac.Reg
Node :: bac.Node
Node_ID :: bac.Node_ID
emit :: bac.emit
expand_node :: bac.expand_node
get_node :: bac.get_node

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

ARM_SYSTEMV_CC := bac.Call_Conv {
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
	Reg_Kind :: bac.Reg_Kind

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
	ctx: bac.Peep_Ctx,
	node: bac.Expanded_Node,
	_: $T,
) -> bac.Node_ID {
	id := bac.get_node_id(ctx, node)
	kind := atype(node)

	signed := false
	#partial switch kind {
	case .Le ..= .Ge, .Div, .Shr:
		signed = true
	}

	ext: bac.Un_Op = signed ? .Sext : .Uext

	changed := false

	#partial switch kind {
	case .Eq ..= .U_Ge, .Div, .Shl ..= .U_Shr:
		for inp, i in node.inps {
			if get_node(ctx, inp).dt < .I32 {
				new := bac.add_un_op(ctx, "shext", ext, .I32, inp)
				bac.set_input(ctx, id, i, new)
				bac.worklist_add(ctx, ctx.worklist, new)
				changed = true
			}
		}
	}

	#partial switch kind {
	case .CInt:
		cnst: ^bac.CInt = bac.get_extra(ctx, node, bac.CInt)
		if node.dt in bac.FLOAT_DTS && cnst.value != 0 {
			size := bac.DT_SIZE[node.dt] / 4 - 1
			slot := bac.get_next_extra_slot(
				ctx,
				u16(bac.Node_Type.Global),
				size,
			)

			if node.dt == .F32 {
				(^f32)(slot)^ = f32(cnst.fvalue)
			} else {
				assert(node.dt == .F64)
				(^f64)(slot)^ = cnst.fvalue
			}

			global := bac.add_raw(
				ctx,
				"iglb",
				u16(bac.Node_Type.Global),
				node.dt,
				meta = {extra_dwords = size},
			)

			return bac.add_raw(
				ctx,
				node.name,
				u16(Node_Type.CLoad),
				node.dt,
				{global},
			)
		}
	case .Eq ..= .U_Ge:
		if len(node.outs) == 1 &&
		   get_node(ctx, node.outs[0].id).itype == .If &&
		   node.dt != .Void {
			node.dt = .Void
			return id
		}
	case .Rem, .U_Rem:
		dv := bac.add_bin_op(
			ctx,
			"rmdv",
			kind == .Rem ? .Div : .U_Div,
			node.dt,
			node.inps[0],
			node.inps[1],
		)
		bac.worklist_add(ctx, ctx.worklist, dv)
		return add_msub(ctx, "rmms", node.dt, dv, node.inps[1], node.inps[0])
	}

	if changed do return id

	return 0
}

post_schedule_peep :: proc(
	_: bac.PS_Peep_Ctx,
	_: bac.Expanded_Node,
	_: $T,
) -> bac.Node_ID {
	return 0
}

meta_of :: #force_inline proc(
	graph: ^bac.Proc,
	ra: ^bac.Regalloc,
	node: bac.Expanded_Node,
	_: $T,
) -> bac.Regalloc_Node_Meta {
	IOUT :: bac.INVALID_RM_INDEX

	@(static, rodata)
	GPA_MASK := [?]i64{0x3FFFFFFF}
	@(static, rodata)
	GPA_SPILL_MASK := [?]i64{~i64(1 << uint(SP) | 1 << 30)}
	@(static, rodata)
	VEC_MASK := [?]i64{0xFFFFFFFF}
	@(static, rodata)
	VEC_SPILL_MASK := [?]i64{~i64(0)}

	GPA_MASK_IDX :: bac.RM_Intern_Idx{}
	VEC_MASK_IDX :: bac.RM_Intern_Idx {
		kind = RK_VECTOR,
	}
	GPA_SPILL_MASK_IDX :: bac.RM_Intern_Idx {
		index = 1,
	}
	VEC_SPILL_MASK_IDX :: bac.RM_Intern_Idx {
		kind  = RK_VECTOR,
		index = 1,
	}

	@(static, rodata)
	GPA_MASKS := [6]bac.RM_Intern_Idx{}

	@(static, rodata)
	VEC_MASKS := [6]bac.RM_Intern_Idx {
		0 ..< 6 = VEC_MASK_IDX,
	}

	@(static, rodata)
	GPA_SPILL_MASKS := [6]bac.RM_Intern_Idx {
		0 ..< 6 = GPA_SPILL_MASK_IDX,
	}

	@(static, rodata)
	VEC_SPILL_MASKS := [6]bac.RM_Intern_Idx {
		0 ..< 6 = VEC_SPILL_MASK_IDX,
	}

	if node.gvn == 0 {
		ra.mask_len = MASK_SIZE
		rslice(ra, RK_GENERAL, GPA_MASK[:])
		rslice(ra, RK_VECTOR, VEC_MASK[:])
		rslice(ra, RK_GENERAL, GPA_SPILL_MASK[:])
		rslice(ra, RK_VECTOR, VEC_SPILL_MASK[:])
	}

	single :: bac.rm_intern_single
	rslice :: bac.rm_intern_slice

	dup :: #force_inline proc(
		msks: []bac.RM_Intern_Idx,
	) -> []bac.RM_Intern_Idx {
		return slice.clone(msks)
	}

	nkind := ra.datatype_to_reg_kind[node.dt]

	masks := [RK_COUNT][]bac.RM_Intern_Idx {
		RK_GENERAL = GPA_MASKS[:],
		RK_VECTOR  = VEC_MASKS[:],
	}
	nmasks := masks[nkind]
	out := nmasks[0]

	smasks := [RK_COUNT][]bac.RM_Intern_Idx {
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
	case .Root_Mem,
	     .Sym,
	     .Jump,
	     .Mem,
	     .Local,
	     .Global,
	     .Always,
	     .Trap,
	     .Poison:
		return {out = IOUT}
	case .Add ..= .Xor, .Shl ..= .And_Not, .F_Add ..= .F_Div:
		return {out = out, masks = nmasks[:2]}
	case .Msub:
		return {out = out, masks = nmasks[:3]}
	case .Eq ..= .U_Ge:
		return {out = out, masks = GPA_MASKS[:2]}
	case .F_Eq ..= .F_Ge:
		return {out = out, masks = VEC_MASKS[:2]}
	case .F_To_I:
		return {out = out, masks = VEC_MASKS[:1]}
	case .F_From_I, .U_F_From_I:
		return {out = out, masks = GPA_MASKS[:1]}
	case .Cast:
		vl := get_node(graph, node.inps[0])
		nkind := ra.datatype_to_reg_kind[vl.dt]
		return {out = out, masks = masks[nkind][:1]}
	case .CInt, .Local_Addr, .Global_Addr, .Proc_Addr, .CLoad:
		return {out = out}
	case .Phi:
		masks := make([]bac.RM_Intern_Idx, len(node.inps) - 1)
		slice.fill(masks, sout)
		return {out = sout, input_start = 1, masks = masks}
	case .Uext, .Sext, .Neg, .Not, .F_Demote, .F_Ext:
		return {out = out, masks = nmasks[:1]}
	case .Split:
		return {out = sout, masks = snmasks[:1]}
	case .If:
		return {
			out = IOUT,
			input_start = 1,
			masks = nmasks[:1 -
			int(get_node(graph, node.inps[1]).dt == .Void)],
		}
	case .Call, .Return, .Set, .Copy:
		return bac.cc_node_meta(graph, ra, node)
	case .Ret:
		return {out = bac.ret_mask(graph, ra, node)}
	case .Param:
		return {out = bac.param_mask(graph, ra, node)}
	case .Store:
		vl := get_node(graph, node.inps[3])
		nkind := ra.datatype_to_reg_kind[vl.dt]
		return {
			out = IOUT,
			input_start = 2,
			masks = dup({GPA_MASK_IDX, masks[nkind][0]}),
		}
	case .Load:
		return {out = out, input_start = 2, masks = GPA_MASKS[:1]}
	}

	fmt.panicf("TODO %v", node)
}

Ctx :: struct {
	using inner:        bac.Codegen_Emit_Ctx,
	code_start:         uint,
	spill_slot_base:    [RK_COUNT]i32,
	stack_param_offset: [RK_COUNT][dynamic]i32,
	local_relocs:       [dynamic]Local_Reloc,
	used:               bit_arr.Bit_Set,
	stack_size:         i32,
	push_base:          i32,
	has_call:           bool,
	big_constants:      [dynamic]u8,
}

Local_Reloc :: struct {
	offset:   u32,
	dest:     u32,
	is_bcond: bool,
}

emit_function :: proc(ectx: bac.Codegen_Emit_Ctx) -> bac.Codegen_Output {

	ctx: Ctx
	ctx.inner = ectx
	ctx.used = bit_arr.init(MASK_SIZE)

	relocs_start := ctx.relocs.pos

	arna.alloc(ctx.code, 0, 4)

	ctx.code_start = ctx.code.pos

	params, _ := bac.assemble_args(ctx, len(ctx.param_specs))

	for reg in ctx.allocs {
		if reg.kind == RK_GENERAL {
			bit_arr.set_unbounded(ctx.used, int(reg.index))
		}
	}

	idx := ctx.code.pos
	emit_op(ctx.code, 0)

	ctx.has_call = bac.layout_call_args(ctx, ctx.schedule, &ctx.stack_size)

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

	bac.layout_spill_slots(
		ctx,
		ctx.spill_slot_base[:],
		SPILL_SLOT_SIZE[:],
		&ctx.stack_size,
	)

	bac.compute_param_offsets(
		ctx,
		params,
		&ctx.stack_size,
		ctx.stack_param_offset[:],
		0,
	)

	bac.layout_locals(ctx, ctx.schedule, &ctx.stack_size)

	ctx.stack_size = i32(
		mem.align_forward_int(int(ctx.stack_size), STACK_ALIGNMENT),
	)

	for param in params {
		enode := expand_node(ctx, param)
		if enode.itype == .Local {
			extra := bac.get_extra(ctx.graph, enode, bac.Local)
			extra.offset += ctx.stack_size
		}
	}

	for spo in ctx.stack_param_offset {
		for &off in spo do off += ctx.stack_size
	}

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

		last := expand_node(ctx, bb.instrs[len(bb.instrs) - 1])
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
			jmp := expand_node(ctx, bb.instrs[0])
			if jmp.itype != .Jump do break

			reloc.dest = get_node(ctx, jmp.outs[0].id).gvn - block_base
		}

		dst_offset := ctx.bbs[reloc.dest].offset
		jump := i32(dst_offset - reloc.offset) / 4

		slot := (^bac.Reloc_Slot)(ctx.code.ptr[reloc.offset:])
		if reloc.is_bcond {
			slot.r3.addend_19 = jump
		} else {
			slot.r2.addend_26 = jump
		}
	}

	code := ctx.code.ptr[ctx.code_start:ctx.code.pos]
	emit(ctx.code, ctx.big_constants[:])
	constants := ctx.code.ptr[ctx.code.pos -
	len(ctx.big_constants):ctx.code.pos]
	relocs := mem.slice_data_cast(
		[]bac.Reloc,
		ctx.relocs.ptr[relocs_start:ctx.relocs.pos],
	)

	return {code = code, relocs = relocs, constants = constants}
}

@(disabled = SPEC_NOT_PRESENT)
emit_instr :: proc(
	ctx: ^Ctx,
	instr: bac.Node_ID,
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
		.Add         = 0x0B000000,
		.Sub         = 0x4B000000,
		.And         = 0x0A000000,
		.Or          = 0x2A000000,
		.Xor         = 0x4A000000,
		.And_Not     = 0x0A200000,
		.Eq ..= .U_Ge             = 0x6B00001F,
		.Shl         = 0x1AC02000,
		.U_Shr       = 0x1AC02400,
		.Shr         = 0x1AC02800,
		.Mul         = 0x1B007C00,
		.U_Div       = 0x1AC00800,
		.Div         = 0x1AC00C00,
		.U_Rem       = 0x1AC00800,
		.Rem         = 0x1AC00C00,
		.F_Add       = 0x1E202800,
		.F_Sub       = 0x1E203800,
		.F_Mul       = 0x1E200800,
		.F_Div       = 0x1E201800,
		.F_Eq ..= .F_Ge             = 0x1E202000,
		.Global_Addr = 0x10000000,
		.Proc_Addr   = 0x10000000,
		.Neg         = 0x4B000000,
		.Not         = 0x2a200000,
		.Cast        = 0x1e260000,
		.F_To_I      = 0x1e380000,
		.F_Ext       = 0b00011110001000101100000000000000,
		.F_Demote    = 0b00011110011000100100000000000000,
		.F_From_I    = 0b00011110001000100000000000000000,
	}
	cc_neg :: proc(c: Cond) -> Cond {return Cond(u8(c) ~ 1)}

	node := expand_node(ctx, instr)
	kind := atype(node)
	block_base := ctx.gvn - u32(len(ctx.schedule.bbs))
	op := NODE_TO_OP[kind]
	is_64 := node.dt == .I64

	inp: bac.Expanded_Node
	is_f64: bool
	if 0 < len(node.inps) {
		inp = expand_node(ctx, node.inps[0])
		is_f64 = inp.dt == .F64
	}

	#partial emit: switch kind {
	case .Root_Mem, .Sym, .Phi, .Ret, .Mem, .Param, .Local, .Global, .Poison:
	case .Global_Addr, .Proc_Addr:
		id: u32
		if kind == .Proc_Addr {
			id = bac.get_extra(ctx, node, bac.Tup).idx
		} else {
			id = bac.get_extra(ctx, inp, bac.Tup).idx
		}
		bac.add_reloc(ctx.relocs)^ = {
			offset = u32(ctx.code.pos - ctx.code_start),
			kind   = kind == .Proc_Addr ? .Text : .Global,
			size   = .r2_19,
			id     = id,
		}
		emit_op(ctx.code, op | u32(reg_of(ctx, instr).index))
	case .Local_Addr:
		offset := bac.get_extra(ctx, node.inps[0], bac.Local).offset
		assert(offset < 4096)

		// add rinstr, sp, #offset
		emit_op(
			ctx.code,
			imm12_instr(0b1001000100, reg_of(ctx, instr), SP, offset),
		)
	case .F_To_I:
		rd := reg_of(ctx, instr)
		rn := reg_of(ctx, node.inps[0])

		ftype: u32
		#partial switch inp.dt {
		case .F64:
			ftype = 0b01
		case .F32:
			ftype = 0b00
		case:
			panic("TODO")
		}

		emit_op(
			ctx.code,
			op |
			u32(is_64) << 31 |
			ftype << 22 |
			u32(rn.index) << 5 |
			u32(rd.index),
		)
	case .F_From_I:
		rd := reg_of(ctx, instr)
		rn := reg_of(ctx, node.inps[0])

		ftype: u32
		#partial switch node.dt {
		case .F32:
			ftype = 0b00
		case .F64:
			ftype = 0b01
		case:
			panic("no")
		}

		emit_op(
			ctx.code,
			op |
			u32(node.dt == .F64) << 31 |
			ftype << 22 |
			u32(rn.index) << 5 |
			u32(rd.index),
		)
	case .F_Ext, .F_Demote:
		rd := reg_of(ctx, instr)
		rn := reg_of(ctx, node.inps[0])

		emit_op(ctx.code, op | u32(rn.index) << 5 | u32(rd.index))
	case .Store:
		vl := get_node(ctx, node.inps[3])

		// str rvl, [rinp2, $imm12]
		// TODO: this can be simplified
		op: u32
		#partial switch vl.dt {
		case .I64:
			op = 0b1111100100
		case .I32:
			op = 0b1011100100
		case .I16:
			op = 0b0111100100
		case .I8:
			op = 0b0011100100
		case .F32:
			op = 0b1011110100
		case .F64:
			op = 0b1111110100
		case .V128:
			op = 0b0011110110
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

		// TODO: this can be simplified
		op: u32
		#partial switch node.dt {
		case .I64:
			op = 0b1111100101
		case .I32:
			op = 0b1011100101
		case .I16:
			op = 0b0111100101
		case .I8:
			op = 0b0011100101
		case .F32:
			op = 0b1011110101
		case .F64:
			op = 0b1111110101
		case .V128:
			op = 0b0011110111
		case:
			fmt.panicf("TODO: %v", node)
		}

		emit_op(
			ctx.code,
			imm12_instr(op, reg_of(ctx, instr), reg_of(ctx, node.inps[2]), 0),
		)
	case .CLoad:
		rt := reg_of(ctx, instr)

		tup: ^bac.Tup = bac.get_extra(ctx, inp, bac.Tup)

		if inp.dt != .Void {
			tup.idx = bac.emit_big_constant(
				&ctx.big_constants,
				bac.DT_SIZE[inp.dt],
				mem.slice_data_cast([]u8, bac.get_extra_dwords(ctx, inp)),
			)
			inp.dt = .Void
		}

		bac.add_reloc(ctx.relocs)^ = {
			offset    = u32(ctx.code.pos - ctx.code_start),
			kind      = .Global,
			size      = .r19,
			scale_pow = 2,
			id        = tup.idx,
		}

		op: u32
		#partial switch node.dt {
		case .F32:
			op = 0b00011100
		case .F64:
			op = 0b01011100
		case .V128:
			op = 0b10011100
		case:
			fmt.panicf("TODO %v", node)
		}

		emit_op(ctx.code, op << 24 | u32(rt.index))
	case .Split:
		rd := reg_of(ctx, instr)
		rm := reg_of(ctx, node.inps[0])

		rd_off := spill_slot_offset(ctx, rd) / 8
		rm_off := spill_slot_offset(ctx, rm) / 8

		assert(rd_off < 4096)
		assert(rm_off < 4096)

		if rm.kind == RK_VECTOR {
			op: u32 = 0x1e604000

			if rm.index >= 32 && rd.index >= 32 {
				// this is atroucious

				// sub sp, sp, #16
				emit_op(ctx.code, 0xD10043FF)

				// str q31, [sp]
				emit_op(ctx.code, 0x3D8003FF)

				// ldr d31, [sp, rm_off + 16]
				emit_op(
					ctx.code,
					imm12_instr(0b1111110101, V31, SP, rm_off + 2),
				)

				// str d31, [sp, rd_off + 16]
				emit_op(
					ctx.code,
					imm12_instr(0b1111110100, V31, SP, rd_off + 2),
				)

				// ldr q31, [sp]
				emit_op(ctx.code, 0x3DC003FF)

				// add sp, sp, #16
				emit_op(ctx.code, 0x910043FF)
			} else if rm.index >= 32 {
				// ldr rd, [SP, rm_off]
				emit_op(ctx.code, imm12_instr(0b1111110101, rd, SP, rm_off))
			} else if rd.index >= 32 {
				// str rm, [SP, rd_off]
				emit_op(ctx.code, imm12_instr(0b1111110100, rm, SP, rd_off))
			} else {
				emit_op(ctx.code, op | u32(rm.index) << 5 | u32(rd.index))
			}
			break
		}

		if rm.index >= 32 && rd.index >= 32 {
			// str x17, [sp, #-16]!
			emit_op(ctx.code, 0xF81F0FF1)

			// ldr x17, [sp, rm_off + 16]
			// +16 because we just moved SP down by 16 bytes.
			emit_op(ctx.code, imm12_instr(0b1111100101, X17, SP, rm_off + 2))

			// str x17, [sp, rd_off + 16]
			emit_op(ctx.code, imm12_instr(0b1111100100, X17, SP, rd_off + 2))

			// ldr x17, [sp], #16
			emit_op(ctx.code, 0xF84107F1)
		} else if rm.index >= 32 {
			// ldr rd, [SP, rm_off]
			emit_op(ctx.code, imm12_instr(0b1111100101, rd, SP, rm_off))
		} else if rd.index >= 32 {
			// str rm, [SP, rd_off]
			emit_op(ctx.code, imm12_instr(0b1111100100, rm, SP, rd_off))
		} else {
			// mov rd, rm
			emit_op(ctx.code, sh_instr(true, 0b0101010, nil, rd, XZR, rm))
		}

		spill_slot_offset :: proc(ctx: ^Ctx, reg: Reg) -> i32 {
			return bac.spill_slot_offset(
				ctx,
				ctx.stack_param_offset[:],
				ctx.spill_slot_base[:],
				SPILL_SLOT_SIZE[:],
				reg,
			)
		}
	case .Uext:
		rd := reg_of(ctx, instr)
		rn := reg_of(ctx, node.inps[0])

		UXTB :: u32(0x53001C00)
		UXTH :: u32(0x53003C00)
		MOV_W :: u32(0x2A0003E0)

		op: u32
		#partial switch inp.dt {
		case .I8:
			op = UXTB | u32(rn.index) << 5 | u32(rd.index)
		case .I16:
			op = UXTH | u32(rn.index) << 5 | u32(rd.index)
		case .I32:
			op = MOV_W | u32(rn.index) << 16 | u32(rd.index)
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
			emit_op(ctx.code, fff(is_f64, op, Reg(0), rn, rm))
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
	case .Neg, .Not:
		emit_op(
			ctx.code,
			rrr(is_64, op, reg_of(ctx, instr), XZR, reg_of(ctx, node.inps[0])),
		)
	case .Cast:
		rn := reg_of(ctx, node.inps[0])
		rd := reg_of(ctx, instr)

		if rn.kind == rd.kind {
			rd := reg_of(ctx, instr)
			rn := reg_of(ctx, node.inps[0])

			UXTB :: u32(0x53001C00)
			UXTH :: u32(0x53003C00)
			MOV_W :: u32(0x2A0003E0)

			op: u32
			#partial switch node.dt {
			case .I8:
				op = UXTB | u32(rn.index) << 5 | u32(rd.index)
			case .I16:
				op = UXTH | u32(rn.index) << 5 | u32(rd.index)
			case .I32:
				op = MOV_W | u32(rn.index) << 16 | u32(rd.index)
			case:
				panic("no")
			}

			emit_op(ctx.code, op)
		} else {
			sf: u32 = 0b1
			ftype: u32 = 0b01
			rmode: u32 = 0b01
			opcode: u32 = 0b110

			if rd.kind == RK_VECTOR do opcode = 0b111

			emit_op(
				ctx.code,
				op |
				sf << 31 |
				ftype << 22 |
				rmode << 19 |
				opcode << 16 |
				u32(rn.index) |
				u32(rd.index),
			)
		}
	case .CInt:
		cint := bac.get_extra(ctx, node, bac.CInt)
		reg := reg_of(ctx, instr)

		#partial switch node.dt {
		case .I8 ..= .I64:
			// TODO: this is primitive but good enough for now

			// movz reg, imm, hw
			op: u32 = 0b110100101

			imm := u16(cint.value)

			if cint.value < 0 {
				// movn reg, ~imm, hw
				op = 0b100100101
				imm = ~imm
			}

			hw: u32 = 0b00

			emit_op(
				ctx.code,
				op << 23 | hw << 21 | u32(imm) << 5 | u32(reg.index),
			)

			remining_subs :=
				(64 - intrinsics.count_leading_ones(cint.value) + 16 - 1) / 16
			if cint.value >= 0 {
				remining_subs =
					(64 -
						intrinsics.count_leading_zeros(cint.value) +
						16 -
						1) /
					16
			}

			op = 0b111100101
			for i in 1 ..< remining_subs {
				hw = u32(i)
				vl := u16(cint.value >> (hw * 16))
				if vl != 0 {
					emit_op(
						ctx.code,
						op << 23 | hw << 21 | u32(vl) << 5 | u32(reg.index),
					)
				}
			}
		case .V128, .F32, .F64:
			assert(cint.value == 0)
			op: u32 = 0x6e201c00

			emit_op(
				ctx.code,
				op |
				u32(reg.index) << 16 |
				u32(reg.index) << 5 |
				u32(reg.index),
			)
		case:
			fmt.panicf("TODO: %v", node)
		}
	case .If:
		append(
			&ctx.local_relocs,
			Local_Reloc {
				offset = u32(ctx.code.pos),
				dest = get_node(ctx, node.outs[int(is_consecutive)].id).gvn -
				block_base,
				is_bcond = true,
			},
		)

		cond := get_node(ctx, node.inps[1])

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
	case .Always:
		fallthrough
	case .Jump:
		if !is_consecutive {
			append(
				&ctx.local_relocs,
				Local_Reloc {
					offset = u32(ctx.code.pos),
					dest = get_node(ctx, node.outs[0].id).gvn - block_base,
				},
			)

			// b <imm26>
			op :: 0b000101
			emit_op(ctx.code, op << 26)
		}
	case .Trap:
		emit_op(ctx.code, 0xD4200000)
	case .Call, .Set, .Copy:
		call := bac.get_extra(ctx, node, bac.Call)

		id: u32
		#partial switch kind {
		case .Call:
			id = call.cid

			if call.indirect {
				op: u32 = 0xd63f0000

				idx := len(node.inps) - 1
				for ; get_node(ctx, node.inps[idx]).itype == .Local;
				    idx -= 1 {}
				ptr := reg_of(ctx, node.inps[idx])

				emit_op(ctx.code, op | u32(ptr.index) << 5)

				break emit
			}
		case .Set:
			id = ctx.lib_calls.set.id
		case .Copy:
			id = ctx.lib_calls.copy.id
		}

		// bl <imm26>
		op: u32 = 0b100101
		imm26 :: 0

		bac.add_reloc(ctx.relocs)^ = {
			offset    = u32(ctx.code.pos - ctx.code_start),
			kind      = .Text,
			size      = .r26,
			scale_pow = 2,
			id        = id,
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
	return ctx.allocs[get_node(ctx, node).gvn]
}

Shift :: enum u32 {
	LSL,
	LSR,
	ASR,
	ROR,
}

sh_instr :: proc(
	is_64: bool,
	#any_int opc: u32,
	shift: Shift,
	rd, rn, rm: Reg,
	imm: u32 = 0,
) -> Op {
	Layout :: bit_field u32 {
		rd:    u16   | 5,
		rn:    u16   | 5,
		imm:   u32   | 6,
		rm:    u16   | 5,
		n:     u32   | 1,
		shift: Shift | 2,
		opc:   u32   | 7,
		is_64: bool  | 1,
	}

	return u32(
		Layout {
			is_64 = is_64,
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
