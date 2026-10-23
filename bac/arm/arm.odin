package bac_arm

import bac ".."
import "../../utils/arna"
import "../../utils/bit_arr"
import "../../utils/fmt"
import "base:intrinsics"
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

ARM_SYSTEMV_CC :: 0

@(tag = "api", rodata, export, link_name = "bac_arm_OPT_HINTS")
OPT_HINTS := bac.Opt_Hints {
	select_types = {.I8, .I16, .I32, .I64, .F32, .F64},
}

@(tag = "api", rodata, export, link_name = "bac_arm_CC_TABLE")
CC_TABLE := [?]bac.Call_Conv {
	ARM_SYSTEMV_CC = {
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
		args = {
			{X0, X1, X2, X3, X4, X5, X6, X7},
			{V0, V1, V2, V3, V4, V5, V6, V7},
		},
		rets = {{X0, X1}, {V0, V1}},
		stack_pointer = SP,
	},
}

SPEC_NOT_PRESENT :: (#load("node_specs.odin", string) or_else "") == ""

when SPEC_NOT_PRESENT {
	Reg_Kind :: bac.Reg_Kind

	inherit_idx_of :: proc($T: typeid) -> u8 {return 0}

	Node_Type :: enum u16 {
		Msub,
		Cmlt,
		Ext,
		Zip1,
		Addv128,
		Umov,
		Lslv,
		Asrv,
		Lsrv,
	}
}

Arm_Op :: struct #align (4) {
	aux: u32,
}

Op :: u32

emit_op :: proc(code: ^arna.Allocator, instr: Op) {
	instr := instr
	emit(code, mem.ptr_to_bytes(&instr))
}

atype :: proc(node: ^Node) -> Node_Type {
	return Node_Type(node.rtype)
}

aextra :: #force_inline proc(
	prc: ^bac.Proc,
	node: ^bac.Node,
	$T: typeid,
) -> ^T {
	if prc.inheritance_table[node.rtype] & (1 << inherit_idx_of(T)) == 0 {
		return nil
	}
	return (^T)(&node.extra)
}

peep :: proc(
	ctx: bac.Peep_Ctx,
	node: bac.Expanded_Node,
	_: $T,
) -> Maybe(bac.Node_ID) {
	id := bac.get_node_id(ctx, node)
	kind := atype(node)

	#partial switch kind {
	case .Add ..= .And_Not, .Neg, .Not:
		NARROW_DTS :: bit_set[bac.Node_Datatype]{.I8, .I16}
		if node.dt in bac.VECTOR_DTS ||
		   bac.operation_datatype(ctx, node) not_in NARROW_DTS {
			break
		}

		signed := kind in bit_set[Node_Type]{.Le, .Lt, .Gt, .Ge, .Div, .Rem, .Shr}
		ext: bac.Un_Op = signed ? .Conv : .U_Conv
		inps: [2]bac.Node_ID
		for inp, i in node.inps {
			inps[i] = inp
			inp_dt := get_node(ctx, inp).dt
			if inp_dt in NARROW_DTS {
				inp_ext := ext
				if .Shl <= kind && kind <= .U_Shr && i == 1 do inp_ext = .U_Conv
				inps[i] = bac.add_un_op(ctx, "iext", inp_ext, .I32, inp)
				bac.worklist_add(ctx, ctx.worklist, inps[i])
			}
		}

		comparison := .Eq <= kind && kind <= .U_Ge
		dt := comparison ? node.dt : bac.Node_Datatype.I32
		wide := bac.add_raw(ctx, "iwide", node.rtype, dt, inps[:len(node.inps)])
		bac.worklist_add(ctx, ctx.worklist, wide)
		if comparison do return wide

		// Consumers must still observe overflow at the original width, including stores.
		return bac.add_un_op(ctx, "inar", .U_Conv, node.dt, wide)
	}

	#partial switch kind {
	case .Shl ..= .U_Shr:
		if node.dt not_in bac.INT_DTS do break

		count := node.inps[1]
		count_dt := get_node(ctx, count).dt
		constant := bac.get_extra(ctx, count, bac.CInt)
		bits := i64(bac.DT_SIZE[node.dt] * 8)
		if constant != nil && constant.value == 0 do return node.inps[0]
		if count_dt < .I32 {
			count_dt = .I32
			count = bac.add_un_op(ctx, "shcext", .U_Conv, count_dt, count)
			bac.worklist_add(ctx, ctx.worklist, count)
		}

		in_range: bac.Node_ID
		if constant != nil {
			if u64(constant.value) >= u64(bits) {
				if kind != .Shr do return bac.add_c_int(ctx, "shzero", node.dt, 0)
				count = bac.add_c_int(ctx, "shlimit", count_dt, bits - 1)
			}
		} else {
			in_range = bac.add_bin_op(
				ctx,
				"shrange",
				.U_Lt,
				.I8,
				count,
				bac.add_c_int(ctx, "shwidth", count_dt, bits),
			)
			bac.worklist_add(ctx, ctx.worklist, in_range)
			if kind == .Shr {
				count = bac.add_select(
					ctx,
					"shclamp",
					count_dt,
					count,
					bac.add_c_int(ctx, "shlimit", count_dt, bits - 1),
					in_range,
				)
				bac.worklist_add(ctx, ctx.worklist, count)
			}
		}

		@(static, rodata)
		NATIVE_SHIFTS := [3]Node_Type{.Lslv, .Asrv, .Lsrv}
		shift := bac.add_raw(
			ctx,
			"shnative",
			u16(NATIVE_SHIFTS[int(kind) - int(Node_Type.Shl)]),
			node.dt,
			{node.inps[0], count},
		)
		if constant != nil || kind == .Shr do return shift
		guard := bac.add_select(
			ctx,
			"shguard",
			node.dt,
			shift,
			bac.add_c_int(ctx, "shzero", node.dt, 0),
			in_range,
		)
		bac.worklist_add(ctx, ctx.worklist, guard)
		return guard
	case .CInt:
		cnst: ^bac.CInt = bac.get_extra(ctx, node, bac.CInt)
		if node.dt in bac.FLOAT_DTS && cnst.value != 0 {
			global := bac.c_int_as_global(ctx, node)
			addr := bac.add_global_addr(ctx, "caddr", global)
			cmem := bac.get_or_add_const_mem(ctx)
			return bac.add_load(ctx, "cild", node.dt, 0, cmem, addr)
		}
	case .Simd_Reduce_Add_Bisect:
		if node.dt == .I64 {
			a := add_umov(ctx, "sraa", .I64, node.inps[0], 0)
			b := add_umov(ctx, "srab", .I64, node.inps[0], 1)
			return bac.add_bin_op(ctx, "sras", .Add, .I64, a, b)
		}

		if node.dt != .F32 {
			sub := bac.add_un_op(ctx, "srabc", .Cast, node.dt, id)
			#reverse for out in node.outs {
				bac.set_input(ctx, out.id, out.idx, sub)
			}
			node.dt = .F32
			return id
		}
	case .Simd_Extract_Lsbs:
		dat := []u8{1, 2, 4, 8, 16, 32, 64, 128, 1, 2, 4, 8, 16, 32, 64, 128}
		size := len(dat) / size_of(u32)
		slot := bac.get_next_extra_slot(ctx, u16(Node_Type.Global), size)
		dst := mem.slice_data_cast([]u8, slot[1:][:size])
		copy(dst, dat)
		fmt.assertf(string(dst) == string(dat), "%v %v", dst, size)
		(^bac.Node_Datatype)(slot)^ = .V128
		msk := bac.add_raw(
			ctx,
			"selmk",
			u16(Node_Type.Global),
			.Void,
			meta = {extra_dwords = size},
		)
		addr := bac.add_global_addr(ctx, "selmka", msk)
		cmem := bac.get_or_add_const_mem(ctx)
		mskld := bac.add_load(ctx, "seld", .V128, 0, cmem, addr)

		shl := bac.add_bin_op(
			ctx,
			"selsh",
			.Shl,
			.V128,
			node.inps[0],
			bac.add_un_op(
				ctx,
				"selspl",
				.Splat,
				.V128,
				bac.add_c_int(
					ctx,
					"selshc",
					bac.LANE_TO_DT[node.lane],
					i64(bac.LANE_SIZE[node.lane] * 8 - 1),
				),
			),
			lane = node.lane,
		)
		cmlt := add_cmlt(ctx, "selct", shl, lane = node.lane)
		and := bac.add_bin_op(
			ctx,
			"selnd",
			.And,
			.V128,
			cmlt,
			mskld,
			lane = node.lane,
		)
		ext := add_ext(
			ctx,
			"selxt",
			and,
			and,
			u32(8 / bac.LANE_SIZE[node.lane]),
			lane = node.lane,
		)
		zip1 := add_zip1(ctx, "selzp1", and, ext, lane = node.lane)
		addv := add_addv128(ctx, "seldv", .F32, zip1, lane = .I16)
		return bac.add_un_op(ctx, "selct", .Cast, .I16, addv)
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

	return nil
}

post_schedule_peep :: proc(
	ctx: bac.PS_Peep_Ctx,
	node: bac.Expanded_Node,
	_: $T,
) -> bac.Node_ID {
	#partial switch node.itype {
	case .If, .Select:
		cond := node.inps[len(node.inps) - 1]
		if 0 < len(ctx.preds) && ctx.preds[len(ctx.preds) - 1] == cond {
			cnode := expand_node(ctx, cond)
			if len(cnode.outs) != 1 || cnode.dt in bac.VECTOR_DTS do break
			#partial switch cnode.itype {
			case .Eq ..= .U_Ge:
				cnode.dt = .Void
			}
		}
	}
	return 0
}

meta_of :: #force_inline proc(
	prc: ^bac.Proc,
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

	if node.gvn == 1 {
		if ra.cc == nil {
			ra.cc = &CC_TABLE[ARM_SYSTEMV_CC]
		}

		ra.mask_len = MASK_SIZE
		rslice(ra, RK_GENERAL, GPA_MASK[:])
		rslice(ra, RK_VECTOR, VEC_MASK[:])
		rslice(ra, RK_GENERAL, GPA_SPILL_MASK[:])
		rslice(ra, RK_VECTOR, VEC_SPILL_MASK[:])
	}

	single :: bac.rm_intern_single
	rslice :: bac.rm_intern_slice

	dup :: #force_inline proc(msks: []bac.RM_Intern_Idx) -> []bac.RM_Intern_Idx {
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

	if node.dt <= .Mem {
		out = IOUT
		sout = IOUT
	}

	switch atype(node) {
	case:
		fallthrough
	case .Nil ..= .Dbg_Scope, .Simd_Extract_Lsbs, .Simd_Extract_Msbs:
		fmt.panicf("should not reach this: %v", node)
	case .Poison ..= .Global, .Jump, .Always, .Trap:
		return {out = IOUT}
	case .Simd_Reduce_Add_Bisect, .Addv128, .Umov:
		return {out = out, masks = VEC_MASKS[:1]}
	case .Splat:
		return {out = out, masks = GPA_MASKS[:1]}
	case .Add ..= .Xor, .Shl ..= .And_Not, .Zip1, .Ext, .Lslv ..= .Lsrv:
		return {out = out, masks = nmasks[:2]}
	case .Msub:
		return {out = out, masks = nmasks[:3]}
	case .Select:
		masks := dup({out, out, GPA_MASK_IDX})
		return {
			out = out,
			masks = masks[:2 + int(get_node(prc, node.inps[2]).dt != .Void)],
		}
	case .Eq ..= .U_Ge:
		ikind := ra.datatype_to_reg_kind[get_node(prc, node.inps[0]).dt]
		return {
			out = out,
			masks = masks[ikind][:2],
			is_flag_dep = node.dt == .Void,
		}
	case .Conv, .U_Conv, .Cast:
		vl := get_node(prc, node.inps[0])
		ckind := ra.datatype_to_reg_kind[vl.dt]
		return {out = out, masks = masks[ckind][:1]}
	case .CInt, .Local_Addr, .Global_Addr, .Proc_Addr:
		return {out = out}
	case .Phi:
		masks := make([]bac.RM_Intern_Idx, len(node.inps) - 1)
		slice.fill(masks, sout)
		return {out = sout, input_start = 1, masks = masks}
	case .Neg, .Not, .Cmlt, .Ctz:
		return {out = out, masks = nmasks[:1]}
	case .Split:
		return {out = sout, masks = snmasks[:1]}
	case .If:
		return {
			out = IOUT,
			input_start = 1,
			masks = nmasks[:1 - int(get_node(prc, node.inps[1]).dt == .Void)],
		}
	case .Call, .Return, .Set, .Copy:
		return bac.cc_node_meta(prc, ra, node, CC_TABLE[:])
	case .Ret:
		return {out = bac.ret_mask(prc, ra, node)}
	case .Param:
		return {out = bac.param_mask(prc, ra, node)}
	case .Store:
		vl := get_node(prc, node.inps[3])
		vkind := ra.datatype_to_reg_kind[vl.dt]
		return {
			out = IOUT,
			input_start = 2,
			masks = dup({GPA_MASK_IDX, masks[vkind][0]}),
		}
	case .Load:
		return {out = out, input_start = 2, masks = GPA_MASKS[:1]}
	}
}

Ctx :: struct {
	using inner:  bac.Codegen_Emit_Ctx,
	local_relocs: [dynamic]Local_Reloc,
	used:         bit_arr.Bit_Set,
	stack_size:   i32,
	push_base:    i32,
	has_call:     bool,
}

Local_Reloc :: struct {
	offset:   u32,
	dest:     u32,
	is_bcond: bool,
}

emit_function :: proc(ectx: bac.Codegen_Emit_Ctx) -> bac.Codegen_Emit_Output {
	spill_slot_base: [RK_COUNT]i32
	stack_param_offset: [RK_COUNT][dynamic]i32

	ctx: Ctx
	ctx.inner = ectx
	ctx.used = bit_arr.init(MASK_SIZE)
	ctx.spill_slot_base = spill_slot_base[:]
	ctx.stack_param_offset = stack_param_offset[:]
	ctx.spill_slot_size = SPILL_SLOT_SIZE[:]

	if ctx.abi == nil {
		ctx.abi = &CC_TABLE[ARM_SYSTEMV_CC]
	}

	arna.alloc(ctx.code, 0, 4)

	ctx.code_start = ctx.code.pos
	ctx.constants_start = ctx.constants.pos

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

	bac.layout_spill_slots(ctx, &ctx.stack_size)

	bac.compute_param_offsets(ctx, params, &ctx.stack_size, 0)

	bac.layout_locals(ctx, ctx.schedule, &ctx.stack_size)

	ctx.stack_size = i32(
		mem.align_forward_int(int(ctx.stack_size), STACK_ALIGNMENT),
	)

	for param in params {
		enode := expand_node(ctx, param)
		if enode.itype == .Local {
			extra := bac.get_extra(ctx.prc, enode, bac.Local)
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

	return {}
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

	// TODO: compact this
	@(static, rodata)
	CC_TABLE := #partial [Node_Type][2]Cond {
		.Eq   = {.EQ, .EQ},
		.Ne   = {.NE, .NE},
		.U_Ge = {.CS, {}},
		.U_Lt = {.CC, {}},
		.U_Gt = {.HI, {}},
		.U_Le = {.LS, {}},
		.Ge   = {.GE, .GE},
		.Lt   = {.LT, .MI},
		.Gt   = {.GT, .GT},
		.Le   = {.LE, .LS},
	}

	condition_for :: proc(kind: Node_Type, dt: bac.Node_Datatype) -> Cond {
		return CC_TABLE[kind][int(dt in bac.FLOAT_DTS)]
	}

	Op_Type :: enum {
		Scalar,
		Float,
		Vector,
	}

	@(static, rodata)
	NODE_TO_OP := #partial [Op_Type][Node_Type]u32 {
		.Scalar = #partial{
			.Add = 0x0B000000,
			.Sub = 0x4B000000,
			.And = 0x0A000000,
			.Or = 0x2A000000,
			.Xor = 0x4A000000,
			.And_Not = 0x0A200000,
			.Eq ..= .U_Ge = 0x6B00001F,
			.Lslv = 0x1AC02000,
			.Lsrv = 0x1AC02400,
			.Asrv = 0x1AC02800,
			.Mul = 0x1B007C00,
			.U_Div = 0x1AC00800,
			.Div = 0x1AC00C00,
			.U_Rem = 0x1AC00800,
			.Rem = 0x1AC00C00,
			.Global_Addr = 0x10000000,
			.Proc_Addr = 0x10000000,
			.Neg = 0x4B000000,
			.Not = 0x2a200000,
			.Cast = 0x1e260000,
			.Simd_Reduce_Add_Bisect = 0x4E31B800,
			.Splat = 0x4E000C00,
			.Cmlt = 0x4E20A800,
			.Ext = 0x6E000000,
			.Zip1 = 0x4E003800,
			.Addv128 = 0x4E31B800,
			.Umov = 0x0E003C00,
		},
		.Float = #partial{
			.Add = 0x1E202800,
			.Sub = 0x1E203800,
			.Mul = 0x1E200800,
			.Div = 0x1E201800,
			.Eq ..= .Ge = 0x1E202000,
		},
		.Vector = #partial{
			.Add = 0x4E208400,
			.Sub = 0x6E208400,
			.Xor = 0x6E201C00,
			.Or = 0x4EA01C00,
			.Shl = 0x4EE04400,
			.And = 0x4E201C00,
			.Eq = 0x6E208C00,
		},
	}

	cc_neg :: proc(c: Cond) -> Cond {return Cond(u8(c) ~ 1)}

	node := expand_node(ctx, instr)
	kind := atype(node)
	block_base := ctx.gvn - u32(len(ctx.schedule.bbs))
	sz_pow := intrinsics.count_trailing_zeros(u32(bac.DT_SIZE[node.dt]))
	lsz_pow := intrinsics.count_trailing_zeros(u32(bac.LANE_SIZE[node.lane]))

	arm_op: Arm_Op
	arm_op_ptr := aextra(ctx, node, Arm_Op)
	if arm_op_ptr != nil do arm_op = arm_op_ptr^

	inp: bac.Expanded_Node
	is_f64: bool
	if 0 < len(node.inps) {
		inp = expand_node(ctx, node.inps[0])
	}

	op_dt := node.dt
	#partial switch kind {
	case .Eq ..= .U_Ge:
		op_dt = inp.dt
	}
	op := NODE_TO_OP[.Scalar][kind]
	if op_dt in bac.FLOAT_DTS && NODE_TO_OP[.Float][kind] != 0 {
		op = NODE_TO_OP[.Float][kind]
	}
	is_64 := op_dt == .I64
	is_f64 = op_dt == .F64

	emit: switch kind {
	case:
		fallthrough
	case .Nil ..=
	     .Dbg_Scope,
	     .Simd_Extract_Lsbs,
	     .Simd_Extract_Msbs,
	     .Rem,
	     .U_Rem:
		fmt.panicf("should not reach this: %v", node)
	case .Poison ..= .Phi:
	case .Umov:
		dst := reg_of(ctx, instr)
		src := reg_of(ctx, node.inps[0])

		imm := ((arm_op.aux << 1) | 1) << sz_pow

		emit_op(
			ctx.code,
			op | u32(is_64) << 30 | imm << 16 | u32(src.index) << 5 | u32(dst.index),
		)
	case .Ext:
		dst := reg_of(ctx, instr)
		lhs := reg_of(ctx, node.inps[0])
		rhs := reg_of(ctx, node.inps[1])

		assert(node.lane == .I8)

		emit_op(
			ctx.code,
			op |
			u32(rhs.index) << 16 |
			arm_op.aux << 11 |
			u32(lhs.index) << 5 |
			u32(dst.index),
		)
	case .Zip1:
		dst := reg_of(ctx, instr)
		lsh := reg_of(ctx, node.inps[0])
		rhs := reg_of(ctx, node.inps[1])

		emit_op(
			ctx.code,
			op |
			lsz_pow << 22 |
			u32(rhs.index) << 16 |
			u32(lsh.index) << 5 |
			u32(dst.index),
		)
	case .Addv128, .Cmlt, .Simd_Reduce_Add_Bisect:
		dst := reg_of(ctx, instr)
		src := reg_of(ctx, node.inps[0])

		emit_op(
			ctx.code,
			op | lsz_pow << 22 | u32(src.index) << 5 | u32(dst.index),
		)
	case .Ctz:
		CLZ: u32 = 0x5AC01000
		RBIT: u32 = 0x5AC00000

		dst := reg_of(ctx, instr)
		src := reg_of(ctx, node.inps[0])

		emit_op(
			ctx.code,
			RBIT | u32(is_64) << 31 | u32(src.index) << 5 | u32(dst.index),
		)
		emit_op(
			ctx.code,
			CLZ | u32(is_64) << 31 | u32(dst.index) << 5 | u32(dst.index),
		)
	case .Splat:
		imm := u32(bac.LANE_SIZE[node.lane])

		dst := reg_of(ctx, instr)
		src := reg_of(ctx, node.inps[0])

		emit_op(ctx.code, op | imm << 16 | u32(src.index) << 5 | u32(dst.index))
	case .Global_Addr, .Proc_Addr:
		scale_pow, id: u32
		if kind == .Proc_Addr {
			id = bac.get_extra(ctx, node, bac.Tup).idx
		} else {
			if bac.emit_big_constant_from_global(ctx, inp) {
				scale_pow = 2
			}
			id = bac.get_extra(ctx, inp, bac.Tup).idx
		}

		bac.add_reloc(ctx.relocs)^ = {
			offset    = u32(ctx.code.pos - ctx.code_start),
			kind      = kind == .Proc_Addr ? .Text : .Global,
			size      = scale_pow == 0 ? .r2_19 : .r19,
			scale_pow = scale_pow,
			id        = id,
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
	case .Conv, .U_Conv:
		assert(inp.dt != node.dt)
		rd := reg_of(ctx, instr)
		rn := reg_of(ctx, node.inps[0])
		unsigned := kind == .U_Conv

		if inp.dt in bac.INT_DTS && node.dt in bac.INT_DTS {
			int_dt := inp.dt < node.dt ? inp.dt : node.dt
			unsigned |= inp.dt > node.dt

			UXTB :: 0x53001C00
			UXTH :: 0x53003C00
			MOV_W :: 0x2A0003E0
			SXTB_W :: 0x13001C00
			SXTH_W :: 0x13003C00
			SXTB_X :: 0x93401C00
			SXTH_X :: 0x93403C00
			SXTW_X :: 0x93407C00

			if unsigned && int_dt == .I32 {
				emit_op(ctx.code, MOV_W | u32(rn.index) << 16 | u32(rd.index))
				break
			}

			conv_op: u32
			#partial switch int_dt {
			case .I8:
				conv_op = unsigned ? UXTB : (is_64 ? SXTB_X : SXTB_W)
			case .I16:
				conv_op = unsigned ? UXTH : (is_64 ? SXTH_X : SXTH_W)
			case .I32:
				conv_op = SXTW_X
			case:
				fmt.panicf("no")
			}

			emit_op(ctx.code, conv_op | u32(rn.index) << 5 | u32(rd.index))
			break
		}

		if inp.dt in bac.FLOAT_DTS && node.dt in bac.FLOAT_DTS {
			conv_op: u32 = node.dt == .F64 ? 0x1E22C000 : 0x1E624000
			emit_op(ctx.code, conv_op | u32(rn.index) << 5 | u32(rd.index))
			break
		}

		int_dt := node.dt
		float_dt := inp.dt
		conv_op: u32
		if inp.dt in bac.INT_DTS {
			assert(node.dt in bac.FLOAT_DTS)
			int_dt = inp.dt
			float_dt = node.dt
			conv_op = unsigned ? 0x1E230000 : 0x1E220000
		} else {
			assert(inp.dt in bac.FLOAT_DTS && node.dt in bac.INT_DTS)
			conv_op = unsigned ? 0x1e390000 : 0x1e380000
		}

		emit_op(
			ctx.code,
			conv_op |
			u32(int_dt == .I64) << 31 |
			u32(float_dt == .F64) << 22 |
			u32(rn.index) << 5 |
			u32(rd.index),
		)
	case .Store:
		vl := get_node(ctx, node.inps[3])

		// str rvl, [rinp2, $imm12]
		// TODO: this can be simplified
		sz_pow = intrinsics.count_trailing_zeros(u32(bac.DT_SIZE[vl.dt]))
		#partial switch vl.dt {
		case .I8 ..= .I64:
			op = 0b0011100100 | sz_pow << 8
		case .F32 ..= .F64:
			op = 0b0011110100 | sz_pow << 8
		case .V128:
			op = 0b0011110110
		case:
			fmt.panicf("TODO: %v", vl)
		}

		emit_op(
			ctx.code,
			imm12_instr(op, reg_of(ctx, node.inps[3]), reg_of(ctx, node.inps[2]), 0),
		)
	case .Load:
		// ldr rinstr, [rinp2, $imm12]

		// TODO: this can be simplified
		#partial switch node.dt {
		case .I8 ..= .I64:
			op = 0b0011100101 | sz_pow << 8
		case .F32 ..= .F64:
			op = 0b0011110101 | sz_pow << 8
		case .V128:
			op = 0b0011110111
		case:
			fmt.panicf("TODO: %v", node)
		}

		emit_op(
			ctx.code,
			imm12_instr(op, reg_of(ctx, instr), reg_of(ctx, node.inps[2]), 0),
		)
	case .Split:
		rd := reg_of(ctx, instr)
		rm := reg_of(ctx, node.inps[0])

		rd_off := bac.spill_slot_offset(ctx, rd) / 8
		rm_off := bac.spill_slot_offset(ctx, rm) / 8

		assert(rd_off < 4096)
		assert(rm_off < 4096)

		if rm.kind == RK_VECTOR {
			if rm.index >= 32 && rd.index >= 32 {
				// this is atroucious

				// sub sp, sp, #16
				emit_op(ctx.code, 0xD10043FF)

				// str q31, [sp]
				emit_op(ctx.code, 0x3D8003FF)

				// ldr d31, [sp, rm_off + 16]
				emit_op(ctx.code, imm12_instr(0b1111110101, V31, SP, rm_off + 2))

				// str d31, [sp, rd_off + 16]
				emit_op(ctx.code, imm12_instr(0b1111110100, V31, SP, rd_off + 2))

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
				MOV :: 0x4EA01C00
				emit_op(
					ctx.code,
					MOV | u32(rm.index) << 16 | u32(rm.index) << 5 | u32(rd.index),
				)
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

	case .Select:
		cnode := expand_node(ctx, node.inps[2])
		cc := Cond.NE
		if cnode.dt == .Void {
			cc = condition_for(atype(cnode), get_node(ctx, cnode.inps[0]).dt)
		} else {
			cond := reg_of(ctx, node.inps[2])
			cond_64 := cnode.dt == .I64
			// cmp wcond/xcond, #0
			emit_op(
				ctx.code,
				imm12_instr(cond_64 ? 0b1111000100 : 0b0111000100, XZR, cond, 0),
			)
		}
		dst := reg_of(ctx, instr)
		on_true := reg_of(ctx, node.inps[0])
		on_false := reg_of(ctx, node.inps[1])
		if node.dt in bac.FLOAT_DTS {
			// fcsel sdst/ddst, son_true/don_true, son_false/don_false, cc
			emit_op(
				ctx.code,
				fff(is_f64, 0x1E200C00 | u32(cc) << 12, dst, on_true, on_false),
			)
		} else {
			assert(node.dt in bac.INT_DTS)
			// csel wdst/xdst, won_true/xon_true, won_false/xon_false, cc
			emit_op(
				ctx.code,
				rrr(is_64, 0x1A800000 | u32(cc) << 12, dst, on_true, on_false),
			)
		}
	case .Add ..= .Xor, .Div, .U_Div, .And_Not, .Shl ..= .U_Shr, .Lslv ..= .Lsrv:
		rd := reg_of(ctx, instr)
		rn := reg_of(ctx, node.inps[0])
		rm := reg_of(ctx, node.inps[1])

		if node.dt in bac.FLOAT_DTS {
			emit_op(ctx.code, fff(is_f64, op, rd, rn, rm))
		} else if node.dt == .V128 {
			assert(node.lane != .F32 && node.lane != .F64)
			UNSIZED :: bit_set[Node_Type]{.And, .Xor, .Or}
			if kind in UNSIZED do lsz_pow = 0

			op = NODE_TO_OP[.Vector][kind]
			fmt.assertf(op != 0, "%v", node)

			emit_op(
				ctx.code,
				op |
				(lsz_pow << 22) |
				u32(rm.index) << 16 |
				u32(rn.index) << 5 |
				u32(rd.index),
			)
		} else {
			assert(!(.Shl <= kind && kind <= .U_Shr))
			emit_op(ctx.code, rrr(is_64, op, rd, rn, rm))
		}
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
		rm := reg_of(ctx, node.inps[1])
		rn := reg_of(ctx, node.inps[0])
		rd := reg_of(ctx, instr)

		if node.dt in bac.FLOAT_DTS {
			emit_op(ctx.code, fff(is_f64, op, rd, rn, rm))
			break
		}

		// mul rd, rn, rm
		mul_op :: 0b10011011000
		pd :: 0b0
		ra := XZR
		emit_op(
			ctx.code,
			mul_op << 21 |
			u32(rm) << 16 |
			pd << 15 |
			u32(ra) << 10 |
			u32(rn) << 5 |
			u32(rd),
		)
	case .Eq ..= .U_Ge:
		rn := reg_of(ctx, node.inps[0])
		rm := reg_of(ctx, node.inps[1])

		if node.dt == .V128 {
			assert(node.lane != .F32 && node.lane != .F64)
			rd := reg_of(ctx, instr)

			op = NODE_TO_OP[.Vector][kind]
			fmt.assertf(op != 0, "%v", node)

			emit_op(
				ctx.code,
				op |
				(lsz_pow << 22) |
				u32(rm.index) << 16 |
				u32(rn.index) << 5 |
				u32(rd.index),
			)
			break
		}

		if inp.dt in bac.FLOAT_DTS {
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
			cond := cc_neg(condition_for(kind, inp.dt))
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
		assert(rn.kind != rd.kind)

		sf: u32 = 0b1
		ftype: u32 = 0b01
		rmode: u32 = 0b00
		opcode: u32 = 0b110

		if rd.kind == RK_VECTOR {
			opcode = 0b111
		}

		emit_op(
			ctx.code,
			op |
			sf << 31 |
			ftype << 22 |
			rmode << 19 |
			opcode << 16 |
			u32(rn.index) << 5 |
			u32(rd.index),
		)
	case .CInt:
		cint := bac.get_extra(ctx, node, bac.CInt)
		reg := reg_of(ctx, instr)

		#partial switch node.dt {
		case .I8 ..= .I64:
			// TODO: this is primitive but good enough for now

			// movz reg, imm, hw
			op = 0b110100101

			imm := u16(cint.value)

			if cint.value < 0 {
				// movn reg, ~imm, hw
				op = 0b100100101
				imm = ~imm
			}

			hw: u32 = 0b00

			emit_op(ctx.code, op << 23 | hw << 21 | u32(imm) << 5 | u32(reg.index))

			remining_subs :=
				(64 - intrinsics.count_leading_ones(cint.value) + 16 - 1) / 16
			if cint.value >= 0 {
				remining_subs =
					(64 - intrinsics.count_leading_zeros(cint.value) + 16 - 1) / 16
			}

			op = 0b111100101
			for i in 1 ..< remining_subs {
				hw = u32(i)
				vl := u16(cint.value >> (hw * 16))
				if (vl != 0 || cint.value < 0) && (vl != max(u16) || cint.value >= 0) {
					emit_op(
						ctx.code,
						op << 23 | hw << 21 | u32(vl) << 5 | u32(reg.index),
					)
				}
			}
		case .V128, .F32, .F64:
			assert(cint.value == 0)
			op = 0x6e201c00

			emit_op(ctx.code, rrr(false, op, reg, reg, reg))
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

			operand_dt := get_node(ctx, bac.get_inputs(ctx, cond)[0]).dt
			cond := cc_neg(condition_for(atype(cond), operand_dt))
			if !is_consecutive do cond = cc_neg(cond)

			emit_op(ctx.code, op << 24 | imm19 << 5 | pd << 4 | u32(cond))
		} else {
			op = 0b10110100 // cbnz <imm19>, rt
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

			if bac.is_indirect_call(node) {
				op = 0xd63f0000

				idx := len(node.inps) - 1
				for ; get_node(ctx, node.inps[idx]).itype == .Local; idx -= 1 {}
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
		op = 0b100101
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
					emit_op(ctx.code, imm12_instr(0b1111100101, reg, SP, pushed / 8))
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
				emit_op(ctx.code, imm12_instr(0b1001000100, SP, SP, ctx.stack_size))
			}
		}

		// ret
		emit_op(ctx.code, 0xd65f03c0)
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
