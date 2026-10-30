package bac_intel_xelp

import bac ".."
import "../../utils/arna"
import "base:intrinsics"
import "core:fmt"
import "core:mem"
import "core:slice"

expand_node :: bac.expand_node
get_node :: bac.get_node

Reg :: bac.Reg
Op :: [4]u32

MASK_SIZE :: GRF_COUNT

GRF_BYTES :: 32
GRF_COUNT :: 128
RK_GRF :: Reg_Kind(0)
RK_FLAG :: Reg_Kind(1)
FLAG_COUNT :: 4
RK_COUNT :: 2
VALUE_CMP_FLAG :: Reg {
	kind  = RK_FLAG,
	index = 3,
}

// A GRF destination does not suppress cmp's architectural flag write.
@(rodata)
VALUE_CMP_CLOBBERS := [RK_COUNT]i64 {
	RK_FLAG = 1 << VALUE_CMP_FLAG.index,
}

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
SPILL_SLOT_SIZE := [RK_COUNT]i32{128, 2}

EU_SRC0_IMMEDIATE :: u32(1 << 14)
EU_SRC1_IMMEDIATE :: u32(1 << 15)

XELP_CC :: 0

SPEC_NOT_PRESENT :: (#load("node_specs.odin", string) or_else "") == ""

when SPEC_NOT_PRESENT {
	Reg_Kind :: bac.Reg_Kind

	Node_Type :: enum u16 {
		Inv,
		Value_Eq,
		Value_Ne,
		Value_Le,
		Value_Lt,
		Value_Gt,
		Value_Ge,
	}

	inherit_idx_of :: proc($T: typeid) -> u8 {return 0}
}

@(tag = "api", rodata, export, link_name = "bac_intel_xelp_OPT_HINTS")
OPT_HINTS := bac.Opt_Hints{}

@(tag = "api", rodata, export, link_name = "bac_intel_xelp_CC_TABLE")
CC_TABLE := [1]bac.Call_Conv {
	XELP_CC = {
		args = {{R1, R2, R3, R4, R5, R6, R7, R8}, {}},
		rets = {{R120, R121, R122, R123, R124, R125, R126, R127}, {}},
	},
}

peep :: proc(
	ctx: bac.Peep_Ctx,
	node: bac.Expanded_Node,
	_: $T,
) -> Maybe(bac.Node_ID) {
	#partial switch xtype(node) {
	case .Eq ..= .Ge:
		value: bac.Node_ID
		#reverse for use in node.outs {
			if get_node(ctx, use.id).itype == .If && use.idx == 1 do continue
			if value == 0 {
				value = bac.add_raw(
					ctx,
					"cmpv",
					u16(Node_Type.Value_Eq) + u16(node.itype) - u16(bac.Node_Type.Eq),
					node.dt,
					node.inps,
				)
			}
			bac.set_input(ctx, use.id, use.idx, value)
		}
	case .If:
		condition := expand_node(ctx, node.inps[1])
		if condition.itype < .Eq || condition.itype > .Ge {
			flag := bac.add_bin_op(
				ctx,
				"boolflag",
				.Ne,
				.I8,
				node.inps[1],
				bac.add_c_int(ctx, "false", condition.dt, 0),
			)
			bac.set_input(ctx, bac.get_node_id(ctx, node), 1, flag)
			return bac.get_node_id(ctx, node)
		}
	case .Div:
		if node.dt == .F32 {
			inv := bac.add_raw(ctx, "inv", u16(Node_Type.Inv), .F32, {node.inps[1]})
			return bac.add_bin_op(ctx, "fdiv", .Mul, .F32, node.inps[0], inv)
		}
	}

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
		RK_GRF  = GRF_MASKS[:],
		RK_FLAG = FLAG_MASKS[:],
	}
	nmasks := masks[nkind]
	out := nmasks[0]

	if node.dt <= .Mem {
		out = IOUT
	}

	#partial switch xtype(node) {
	case .Nil ..= .Dbg_Scope:
		fmt.panicf("should not reach these: %v", node)
	case .Poison ..= .Global:
		return {out = out}
	case .CInt:
		return {out = out}
	case .Add, .Sub, .Mul:
		return {out = out, masks = nmasks[:2]}
	case .Value_Eq ..= .Value_Ge:
		return {out = out, masks = GRF_MASKS[:2], clobbers = VALUE_CMP_CLOBBERS[:]}
	case .Eq ..= .Ge:
		return {out = FLAG_MASK_IDX, masks = GRF_MASKS[:2]}
	case .If:
		return {out = IOUT, input_start = 1, masks = FLAG_MASKS[:1]}
	case .Jump, .Always:
		return {out = IOUT}
	case .Phi:
		if out == IOUT do return {out = out}
		inputs := make([]bac.RM_Intern_Idx, len(node.inps) - 1)
		slice.fill(inputs, out)
		return {out = out, input_start = 1, masks = inputs}
	case .Neg, .Inv:
		return {out = out, masks = nmasks[:1]}
	case .Split:
		source := expand_node(prc, node.inps[0])
		for source.itype == .Split do source = expand_node(prc, source.inps[0])
		if .Eq <= source.itype && source.itype <= .Ge {
			return {out = FLAG_MASK_IDX, masks = FLAG_MASKS[:1]}
		}
		return {out = out, masks = nmasks[:1]}
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
	blocks:      []Block_Info,
	labels:      []uint,
	branches:    [dynamic]Branch,
}

Branch :: struct {
	pos:      uint,
	jip, uip: int,
}

Jump_Type :: enum int {
	None,
	Goto,
	If,
	Else,
	Endif,
	Break,
	Cont,
	While,
	Uncond_While,
}

Block_Info :: struct {
	parent_if: u32,
	has_join:  bool,
	type:      Jump_Type,
	jip, uip:  int,
}

emit_function :: proc(ectx: bac.Codegen_Emit_Ctx) -> bac.Codegen_Emit_Output {
	context.allocator, _ = arna.scrath(ectx.prc.temps)
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

	prepare_blocks(&ctx)
	ctx.labels = make([]uint, (len(ctx.blocks) + 1) * 2)
	slice.fill(ctx.labels, max(uint))

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
		block := ctx.blocks[bidx]
		ctx.labels[(bidx + 1) * 2] = ctx.code.pos
		if block.has_join {
			emit_branch(&ctx, .Join, 0, 0)
		}

		for instr in bb.instrs {
			emit_instr(&ctx, instr, bidx, struct{}{})
		}
	}

	next := uint(0)
	#reverse for branch in ctx.branches {
		op := (^Op)(&ctx.code.ptr[branch.pos])
		opcode := Opcode(op[0] & 0x7f)
		jip := branch.jip == 0 ? branch.pos + size_of(Op) : ctx.labels[branch.jip]
		if opcode == .Join && next != 0 do jip = next
		assert(jip != max(uint))
		op[3] = transmute(u32)i32(int(jip) - int(branch.pos))
		if branch.uip != 0 {
			assert(ctx.labels[branch.uip] != max(uint))
			op[2] = transmute(u32)i32(int(ctx.labels[branch.uip]) - int(branch.pos))
		}
		if opcode in (bit_set[Opcode]{.Join, .Else, .Endif, .While}) {
			next = branch.pos
		}
	}

	return {}
}

@(disabled = SPEC_NOT_PRESENT)
emit_instr :: proc(ctx: ^Ctx, instr: bac.Node_ID, block_idx: int, _: $T) {
	node := expand_node(ctx, instr)

	#partial switch xtype(node) {
	case .Nil ..= .Dbg_Scope:
		fmt.panicf("should not reach these: %v", node)
	case .Poison ..= .Phi:
	case .CInt:
		value := bac.get_extra(ctx, node, bac.CInt)
		bits := u32(value.value)
		if node.dt == .F32 do bits = transmute(u32)f32(value.fvalue)
		// mov (8|M0) r{dst}.0<1>:ud {bits}:ud {@1}
		emit_op(
			ctx.code,
			{
				eu_control(.Mov, 8, swsb = eu_swsb_regdist(1)),
				eu_dst(reg_of(ctx, instr), 0, .UD) |
				eu_src0_type(.UD) |
				EU_SRC0_IMMEDIATE,
				0,
				bits,
			},
		)
	case .Split:
		dst := reg_of(ctx, instr)
		src := reg_of(ctx, node.inps[0])
		if dst.kind == RK_FLAG {
			assert(src.kind == RK_FLAG)
			// (W) mov (1|M0) f{dst/2}.{dst%2}<1>:uw f{src/2}.{src%2}<0;1,0>:uw {@1}
			emit_op(
				ctx.code,
				{
					eu_control(.Mov, 1, swsb = eu_swsb_regdist(1), no_mask = true),
					eu_dst(
						Reg(0x30 + dst.index / 2),
						u8(dst.index % 2 * 2),
						.UW,
						file = .ARF,
					) |
					eu_src0_type(.UW),
					eu_src(
						Reg(0x30 + src.index / 2),
						u8(src.index % 2 * 2),
						0,
						1,
						0,
						file = .ARF,
					),
					0,
				},
			)
		} else {
			// mov (8|M0) r{dst}.0<1>:ud r{src}.0<8;8,1>:ud {@1}
			emit_op(
				ctx.code,
				{
					eu_control(.Mov, 8, swsb = eu_swsb_regdist(1)),
					eu_dst(dst, 0, .UD) | eu_src0_type(.UD),
					eu_src(src, 0, 8, 8, 1),
					0,
				},
			)
		}
	case .Eq ..= .Ge, .Value_Eq ..= .Value_Ge:
		materialized := xtype(node) >= .Value_Eq
		kind :=
			materialized ? Node_Type(u16(Node_Type.Eq) + node.rtype - u16(Node_Type.Value_Eq)) : xtype(node)
		dst := reg_of(ctx, instr)
		op := FLOAT_OPS[kind]
		dt := get_node(ctx, node.inps[0]).dt
		assert(dt == .F32 || dt in bit_set[bac.Node_Datatype]{.I8, .I32})
		if dt != .F32 {
			op[1] = eu_dst(R0, 0, .D, file = .ARF) | eu_src0_type(.D)
			op[2] = (op[2] & 0xf0000000) | eu_src(R0, 0, 8, 8, 1) | eu_src1_type(.D)
		}
		if materialized {
			op[0] |= eu_flag(VALUE_CMP_FLAG)
			op[1] |= eu_reg_number(dst, .GRF) << 24 | 1 << 18
		} else {
			op[0] |= eu_flag(dst)
			op[1] &= ~u32(1 << 18)
		}
		op[2] |= eu_reg_number(reg_of(ctx, node.inps[0]), .GRF) << 8
		op[3] |= eu_reg_number(reg_of(ctx, node.inps[1]), .GRF) << 8
		emit_op(ctx.code, op)
		if materialized {
			// EU masks must be canonicalized without overwriting allocated predicate flags.
			// and (8|M0) r{dst}.0<1>:ud r{dst}.0<8;8,1>:ud 0x1:ud {@1}
			emit_op(
				ctx.code,
				{
					eu_control(.And, 8, swsb = eu_swsb_regdist(1)),
					eu_dst(dst, 0, .UD) | eu_src0_type(.UD) | EU_SRC1_IMMEDIATE,
					eu_src(dst, 0, 8, 8, 1) | eu_src1_type(.UD),
					1,
				},
			)
		}
	case .Add, .Sub, .Mul, .Neg, .Inv:
		assert(bac.operation_datatype(ctx, node) == .F32)
		dst := reg_of(ctx, instr)
		op := FLOAT_OPS[xtype(node)]
		op[1] |= eu_reg_number(dst, .GRF) << 24
		op[2] |= eu_reg_number(reg_of(ctx, node.inps[0]), .GRF) << 8
		if len(node.inps) == 2 {
			op[3] |= eu_reg_number(reg_of(ctx, node.inps[1]), .GRF) << 8
		}
		emit_op(ctx.code, op)

		if xtype(node) == .Inv {
			// Math is out of order; register-distance dependencies alone cannot wait for it.
			// sync.nop (1|M0) null {$2.dst}
			emit_op(
				ctx.code,
				{
					eu_control(.Sync, 1, swsb = eu_swsb_sbid(2, .Wait_Dst)),
					1 << 16,
					0,
					0,
				},
			)
		}
	case .If, .Jump, .Always:
		block := ctx.blocks[block_idx]
		ctx.labels[(block_idx + 1) * 2 + 1] = ctx.code.pos
		if block.type == .None do break

		predicate: u32
		if node.itype == .If {
			next_head := ctx.bbs[block_idx + 1].head
			assert(node.outs[0].id == next_head || node.outs[1].id == next_head)
			predicate = eu_predicate(
				reg_of(ctx, node.inps[1]),
				(node.outs[0].id == next_head) != (block.type == .If),
			)
		}

		@(static, rodata)
		TYPE_TO_OP := [Jump_Type]Opcode {
			.Goto  = .Goto,
			.If    = .If,
			.Break = .Break,
			.Cont  = .Cont,
			.While ..= .Uncond_While       = .While,
			.Endif = .Endif,
			.Else  = .Else,
			.None  = {},
		}
		NEEDS_UIP :: bit_set[Jump_Type]{.Goto, .If, .Else, .Break, .Cont}

		jip, uip: int
		if target := block.jip; target != 0 {
			at_end :=
				block.type not_in bit_set[Jump_Type]{.If, .While, .Uncond_While} &&
				(block.type == .Else || !ctx.blocks[target].has_join)
			jip = (target + 1) * 2 + int(at_end)
		}
		if block.type in NEEDS_UIP {
			target := block.uip
			assert(target != 0)
			uip = (target + 1) * 2 + int(block.type != .Goto)
		}

		emit_branch(ctx, TYPE_TO_OP[block.type], jip, uip, predicate)
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

prepare_blocks :: proc(ctx: ^Ctx) {
	ctx.blocks = make([]Block_Info, len(ctx.bbs))
	for bb, i in ctx.bbs do get_node(ctx, bb.head).gvn = u32(i)

	active_loops: [dynamic]int
	append(&active_loops, 0)

	for bb, bidx in ctx.bbs {
		info := &ctx.blocks[bidx]
		hnode := expand_node(ctx, bb.head)
		tnode := expand_node(ctx, bb.tail)
		if 0 < len(hnode.inps) {
			pred := expand_node(ctx, hnode.inps[0])
			idx := get_node(ctx, pred.inps[0]).gvn
			#partial match: switch pred.itype {
			case .If:
				info.parent_if = 1 + idx
			case:
				info.parent_if = ctx.blocks[idx].parent_if
			}
		}

		if tnode.itype == .If && info.type == .None {
			info.type = .Goto
		}

		ififiy: if hnode.itype == .Region {
			// I think this also handles 0 if parent for loops as the loop can only
			// be breaked trough nested if
			min_parent_if := max(u32)
			max_parent_if := min(u32)
			for inp in hnode.inps {
				pred := bac.get_node(ctx, bac.get_inputs(ctx, inp)[0])
				parif := ctx.blocks[pred.gvn].parent_if
				max_parent_if = max(max_parent_if, parif)
				min_parent_if = min(min_parent_if, parif)
			}

			is_continue := false
			if tnode.itype == .Jump && len(bb.instrs) == 1 {
				for out in tnode.outs {
					onode := expand_node(ctx, out.id)
					if onode.itype == .Loop && out.idx == 1 {
						is_continue = true
						info.type = .None
						break
					}
				}
			}

			for inp in hnode.inps {
				pred := bac.get_node(ctx, bac.get_inputs(ctx, inp)[0])
				parif := ctx.blocks[pred.gvn].parent_if - 1

				is_adj := int(pred.gvn) == bidx - 1

				if !is_adj {
					ctx.blocks[pred.gvn].type = .Goto
				}

				if is_continue {
					ctx.blocks[pred.gvn].type = is_adj ? .Uncond_While : .Cont
				}

				if ctx.bbs[parif].loop_tree.parent == bb.loop_tree &&
				   ctx.bbs[slice.last(active_loops[:])].loop_tree ==
					   ctx.bbs[parif].loop_tree {
					assert(!is_continue)
					ctx.blocks[pred.gvn].type = .Break
					unreachable()
				}
			}

			// recover the parent of the highest input, should offer good recovery
			info.parent_if = ctx.blocks[min_parent_if - 1].parent_if

			if len(hnode.inps) != 2 do break ififiy
			if max_parent_if != min_parent_if do break ififiy

			parif := &ctx.blocks[min_parent_if - 1]
			parif.type = .If

			for inp in hnode.inps {
				pred := bac.get_node(ctx, bac.get_inputs(ctx, inp)[0])
				is_end := int(pred.gvn) == bidx - 1
				ctx.blocks[pred.gvn].type = is_end ? .Endif : .Else
			}
		}

		if hnode.itype == .Loop {
			append(&active_loops, bidx)
			bnode := bac.expand_node(ctx, hnode.inps[1])
			pred := bac.get_node(ctx, bnode.inps[0])
			ctx.blocks[pred.gvn].type = bnode.itype == .If ? .While : .Uncond_While
		}

		for out in tnode.outs {
			node := get_node(ctx, out.id)
			if out.idx == 1 && node.itype == .Loop {
				prev := pop(&active_loops)
				assert(prev == int(node.gvn))
			}
		}
	}

	for bb, bidx in ctx.bbs {
		info := &ctx.blocks[bidx]
		if info.type != .Goto do continue
		tnode := expand_node(ctx, bb.tail)
		assert(tnode.itype == .If || tnode.itype == .Jump)
		target := get_node(ctx, tnode.outs[0].id)
		assert(tnode.itype != .Jump || target.itype == .Region)
		info.uip = int(target.gvn)
		ctx.blocks[target.gvn].has_join = true
	}

	active_cfg: [dynamic]int
	append(&active_cfg, 0)

	last_join := 0

	#reverse for bb, bidx in ctx.bbs {
		info := &ctx.blocks[bidx]
		hnode := expand_node(ctx, bb.head)

		acfg := slice.last(active_cfg[:])
		next := min(
			acfg != 0 ? acfg : max(int),
			last_join != 0 ? last_join : max(int),
		)

		switch info.type {
		case .None:
		case .Goto:
			info.jip = min(info.uip, next)
		case .If:
			else_idx := pop(&active_cfg)
			einfo := &ctx.blocks[else_idx]
			info.jip = else_idx + 1
			info.uip = einfo.jip
		case .Else:
			info.jip = pop(&active_cfg)
			info.uip = info.jip
			append(&active_cfg, bidx)
		case .Endif:
			info.jip = next
			append(&active_cfg, bidx)
		case .Break, .Cont:
			info.jip = next

			#reverse for cfg in active_cfg {
				if ctx.blocks[cfg].type == .Uncond_While ||
				   ctx.blocks[cfg].type == .While {
					info.uip = cfg
					break
				}
			}
		case .While, .Uncond_While:
			append(&active_cfg, bidx)
		}

		if info.jip == max(int) do info.jip = 0

		#partial switch hnode.itype {
		case .Loop:
			loop := pop(&active_cfg)
			assert(loop != 0)
			linfo := &ctx.blocks[loop]
			assert(linfo.type == .While || linfo.type == .Uncond_While)
			linfo.jip = bidx
		}

		if info.has_join {
			last_join = bidx
		}
	}

	assert(len(active_cfg) == 1)
}

emit_branch :: proc(
	ctx: ^Ctx,
	opcode: Opcode,
	jip, uip: int,
	predicate: u32 = 0,
) {
	append(&ctx.branches, Branch{ctx.code.pos, jip, uip})
	// [{predicate}] {opcode} (8|M0) {JIP} [{UIP}] {@1}
	emit_op(
		ctx.code,
		{
			eu_control(opcode, 8, swsb = eu_swsb_regdist(1)) | predicate,
			uip != 0 ? 0xc000 : 0x4000,
			0,
			0,
		},
	)
}

eu_flag :: proc(reg: Reg) -> u32 {
	assert(reg.kind == RK_FLAG && reg.index < FLAG_COUNT)
	return u32(reg.index) << 22
}

eu_predicate :: proc(reg: Reg, negate: bool = false) -> u32 {
	return eu_flag(reg) | 1 << 24 | u32(negate) << 28
}

emit_op :: proc(code: ^arna.Allocator, op: Op) {
	op := op
	bac.emit(code, mem.ptr_to_bytes(&op))
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
