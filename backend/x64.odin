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
RDI_MASK :: []int{1 << uint(RDI)}
RSI_MASK :: []int{1 << uint(RSI)}
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

SIMPLE_CMP_SPEC :: Reg_Class_Spec {
	reg_masks = #partial{.General = {GPA_MASK, GPA_MASK, GPA_MASK}},
}

SIMPLE_SHIFT_SPEC :: Reg_Class_Spec {
	reg_masks = #partial{.General = {GPA_MASK, GPA_MASK, RCX_MASK}},
	inplace_slot_idx = 0,
}

SIMPLE_UNOP_SPEC :: Reg_Class_Spec {
	reg_masks = #partial{.General = {GPA_MASK, GPA_MASK}},
	inplace_slot_idx = 0,
}

RELAXED_UNOP_SPEC :: Reg_Class_Spec {
	reg_masks = #partial{.General = {GPA_MASK, GPA_MASK}},
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
	.Add ..= .Xor = SIMPLE_BINOP_SPEC,
	.Eq ..= .U_Ge = SIMPLE_CMP_SPEC,
	.And_Not = {
		reg_masks = #partial{.General = {GPA_MASK, GPA_MASK, GPA_MASK}},
		inplace_slot_idx = 1,
	},
	.Neg = SIMPLE_UNOP_SPEC,
	.Not = SIMPLE_UNOP_SPEC,
	.Cast = SIMPLE_UNOP_SPEC,
	.Sext = RELAXED_UNOP_SPEC,
	.Uext = RELAXED_UNOP_SPEC,
	.Shl ..= .U_Shr = SIMPLE_SHIFT_SPEC,
	.Mul = SIMPLE_BINOP_SPEC,
	.Div = DIV_SPEC,
	.Rem = REM_SPEC,
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
	.Load_S = {
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
	.Copy = {
		input_start_idx = 2,
		reg_masks = #partial{.General = {{}, RDI_MASK, RSI_MASK, RDX_MASK}},
		clobbers = #partial{.General = CALL_CLOBBERS},
	},
	.Set = {
		input_start_idx = 2,
		reg_masks = #partial{.General = {{}, RDI_MASK, RSI_MASK, RDX_MASK}},
		clobbers = #partial{.General = CALL_CLOBBERS},
	},
	.Call_End = {},
	.Jump = {input_start_idx = 1},
	.Return = {
		reg_masks = #partial{.General = {{}, GPA_RET_MASK}},
		input_start_idx = 2,
	},
}

X64_SIMPE_OP :: Reg_Class_Spec {
	inplace_slot_idx = 0,
	reg_masks = #partial{.General = {GPA_MASK, GPA_MASK, GPA_MASK}},
}

X64_SIMPE_CMP_OP :: Reg_Class_Spec {
	reg_masks = #partial{.General = {GPA_MASK, GPA_MASK, GPA_MASK}},
}

@(rodata)
X64_REG_CLASSES := #partial [X64_Node_Type]Reg_Class_Spec {
	.X64_Add ..= .X64_Xor = X64_SIMPE_OP,
	.X64_Eq ..= .X64_U_Ge = X64_SIMPE_CMP_OP,
	.X64_Shl ..= .X64_U_Shr = SIMPLE_SHIFT_SPEC,
	.X64_Neg ..= .X64_Not = SIMPLE_UNOP_SPEC,
	.X64_Load = {
		input_start_idx = 2,
		reg_masks = #partial{.General = {GPA_MASK, GPA_MASK}},
	},
	.X64_Store = {
		input_start_idx = 2,
		reg_masks = #partial{.General = {{}, GPA_MASK, GPA_MASK}},
	},
}

when SPEC_NOT_PRESENT {
	X64_Node_Type :: enum u16 {
		X64_Add,
		X64_Sub,
		X64_And,
		X64_Or,
		X64_Xor,
		X64_Eq,
		X64_Ne,
		X64_Le,
		X64_Lt,
		X64_Gt,
		X64_Ge,
		X64_U_Lt,
		X64_U_Gt,
		X64_U_Le,
		X64_U_Ge,
		X64_Shl,
		X64_Shr,
		X64_U_Shr,
		X64_Load,
		X64_Store,
		X64_Neg,
		X64_Not,
	}

	X64_SIMPLE_BIN_OP_SPEC :: Class_Spec {
		id = X64_Mem_Op,
	}

	X64_SIMPLE_SHIFT_OP_SPEC :: Class_Spec {
		id = X64_Mem_Op,
	}

	X64_SIMPLE_UN_OP_SPEC :: Class_Spec {
		id = X64_Mem_Op,
	}

	@(rodata)
	X64_CLASSES := [X64_Node_Type]Class_Spec {
		.X64_Add ..= .X64_U_Ge = X64_SIMPLE_BIN_OP_SPEC,
		.X64_Shl ..= .X64_U_Shr = X64_SIMPLE_SHIFT_OP_SPEC,
		.X64_Neg ..= .X64_Not = X64_SIMPLE_UN_OP_SPEC,
		.X64_Load = {id = X64_Mem_Op},
		.X64_Store = {id = X64_Mem_Op, flags = {.Store}},
	}
}

Mem_Mode :: enum u8 {
	None,
	Dest,
	Src,
}

X64_Mem_Op :: struct {
	imm:      i32,
	dis:      i32,
	scale:    u32,
	signed:   bool,
	mem_mode: Mem_Mode,
	dt:       Node_Datatype,
}

BIN_OP_OFFSET :: transmute(u16)(i16(X64_Node_Type.X64_Add) -
	i16(Ideal_Node_Type.Add))

UN_OP_OFFSET :: transmute(u16)(i16(X64_Node_Type.X64_Neg) -
	i16(Ideal_Node_Type.Neg))

x64_peep :: proc(ctx: Peep_Ctx, node: Expanded_Node) -> Node_ID {
	node := node

	id := graph_id(ctx, node)

	rhs_conts: ^CInt
	val_const: ^CInt

	slots := [2]^^CInt{&rhs_conts, &val_const}
	idxs := [2]int{1, 3}

	for idx, i in idxs {
		slot := slots[i]
		if idx < len(node.inps) {
			slot^ = graph_extra(ctx, node.inps[idx], CInt)
			if slot^ != nil {
				clamped := i64(i32(slot^.value))
				if clamped != slot^.value do slot^ = nil
			}
		}
	}

	rhs_load: ^X64_Mem_Op
	if 1 < len(node.inps) {
		rhs := graph_expand(ctx, node.inps[1])
		if rhs.xtype == .X64_Load {
			rhs_load = graph_extra(ctx, rhs, X64_Mem_Op)
		}
	}

	base: Node_ID
	displacement: i32
	stack_base: bool
	if 2 < len(node.inps) {
		base = node.inps[2]
		bnode := graph_expand(ctx, base)
		if bnode.xtype == .X64_Add {
			base = bnode.inps[0]
			displacement = graph_extra(ctx, node.inps[2], X64_Mem_Op).imm
		}

		bnode = graph_expand(ctx, base)
		if bnode.itype == .Local_Addr {
			base = bnode.inps[0]
			stack_base = true
		}
	}

	#partial switch node.xtype {
	case .X64_Store, .X64_Load:
		changed := false

		mem_op := graph_extra(ctx, node, X64_Mem_Op)

		if val_const != nil {
			graph_remove_output(ctx, node.inps[3], {idx = 3, id = id})
			node.ordered_input_count -= 1
			node.input_count -= 1
			mem_op.imm = i32(val_const.value)
			node.inps = node.inps[:len(node.inps)]
			changed = true
		}

		mem_op.dis += displacement

		changed |= node.inps[2] != base
		graph_set_input(ctx, id, 2, base)

		node.additional_data_start = max(
			node.additional_data_start,
			u8(stack_base),
		)

		if node.xtype == .X64_Store && 3 < len(node.inps) {
			val := graph_expand(ctx, node.inps[3])
			val_mem := graph_extra(ctx, val, X64_Mem_Op)

			X64_TRIGGER_OPS :: bit_set[X64_Node_Type] {
				.X64_Add,
				.X64_Sub,
				.X64_And,
				.X64_Or,
				.X64_Xor,
				.X64_Shl,
				.X64_Shr,
				.X64_U_Shr,
			}
			IDEAL_TRIGGER_OPS :: bit_set[Ideal_Node_Type] {
				.Add,
				.Sub,
				.And,
				.Or,
				.Xor,
				.Shl,
				.Shr,
				.U_Shr,
				.Not,
				.Neg,
			}

			IDEAL_TRIGGER_UN_OPS :: bit_set[Ideal_Node_Type]{.Not, .Neg}

			if ((val.xtype in X64_TRIGGER_OPS && len(val.inps) == 1) ||
				   val.itype in IDEAL_TRIGGER_OPS) &&
			   len(val.outs) == 1 {

				lhs := graph_expand(ctx, val.inps[0])
				lhs_mem := graph_extra(ctx, val.inps[0], X64_Mem_Op)
				if lhs.xtype == .X64_Load &&
				   lhs.inps[1] == node.inps[1] &&
				   lhs.inps[2] == node.inps[2] &&
				   lhs_mem.dis == mem_op.dis {
					node.xtype = val.xtype

					if val.xtype in X64_TRIGGER_OPS {
						graph_remove_output(
							ctx,
							node.inps[3],
							{idx = 3, id = id},
						)
						node.ordered_input_count -= 1
						node.input_count -= 1
						mem_op.imm = val_mem.imm
						node.inps = node.inps[:len(node.inps) - 1]
					} else if val.itype in IDEAL_TRIGGER_UN_OPS {
						node.rtype += UN_OP_OFFSET
						graph_remove_output(
							ctx,
							node.inps[3],
							{idx = 3, id = id},
						)
						node.ordered_input_count -= 1
						node.input_count -= 1
						node.inps = node.inps[:len(node.inps) - 1]
					} else {
						node.rtype += BIN_OP_OFFSET
						graph_set_input(ctx, id, 3, val.inps[1])
					}

					mem_op.mem_mode = .Dest
					node.in_place_slot_offset = -1
					node.additional_data_start += 2
					changed = true
				} else {
					peep_ctx_add_trigger(ctx, val.inps[0], id)
				}
			}
		}

		if changed do return id
		return 0
	}

	#partial switch node.itype {
	case .Add ..= .Xor, .Eq ..= .U_Ge, .Shl ..= .U_Shr:
		op := u16(node.itype) + BIN_OP_OFFSET

		// TODO: we can do this one once things are scheduled
		if false && rhs_load != nil {
			load := graph_expand(ctx, node.inps[1])

			return x64_make_node(
				ctx,
				id,
				op,
				{load.inps[0], load.inps[1], node.inps[0], load.inps[2]},
				{},
			)
		}

		chanded := false
		if .Eq <= node.itype && node.itype <= .U_Ge {
			if node.dt != .Void &&
			   len(node.outs) == 1 &&
			   graph_get(ctx, node.outs[0].id).itype == .If {
				node.dt = .Void
				chanded = true
			}
		}

		if rhs_conts != nil {
			return x64_make_node(
				ctx,
				id,
				op,
				node.inps[:1],
				{imm = i32(rhs_conts.value)},
			)
		}

		if chanded do return id
	case .If:
		node.additional_data_start = u8(
			graph_get(ctx, node.inps[1]).dt == .Void,
		)
	case .Load, .Load_S:
		return x64_make_node(
			ctx,
			id,
			u16(X64_Node_Type.X64_Load),
			{node.inps[0], node.inps[1], base},
			{dis = displacement, signed = node.itype == .Load_S},
			additional_data_offset = u8(stack_base),
		)
	case .Store:
		immediate: i32
		inps := []Node_ID{node.inps[0], node.inps[1], base, node.inps[3]}
		if val_const != nil {
			immediate = i32(val_const.value)
			inps = inps[:len(inps) - 1]
		}

		return x64_make_node(
			ctx,
			id,
			u16(X64_Node_Type.X64_Store),
			inps,
			{
				dis = displacement,
				imm = immediate,
				dt = graph_get(ctx, node.inps[3]).dt,
			},
			additional_data_offset = u8(stack_base),
		)
	}

	return 0
}

x64_make_node :: proc(
	graph: ^Graph,
	from: Node_ID,
	type: u16,
	inps: []Node_ID,
	extra: X64_Mem_Op,
	additional_data_offset: u8 = 0,
	in_place_slot_offset: i8 = 0,
) -> Node_ID {
	push_node_name(graph, graph_get_node_name(graph, from))
	fnode := graph_get(graph, from)
	node := graph_add_raw(graph, type, fnode.dt, inps)
	graph_extra(graph, node, X64_Mem_Op)^ = extra
	graph_get(graph, node).additional_data_start = additional_data_offset
	graph_get(graph, node).in_place_slot_offset = in_place_slot_offset
	return node
}

x64_post_schedule_peep :: proc(
	ctx: PS_Peep_Ctx,
	node: Expanded_Node,
) -> Node_ID {
	id := graph_id(ctx, node)
	#partial match: switch node.itype {
	case .Add ..= .Xor, .Eq ..= .U_Ge:
		op := node.rtype + BIN_OP_OFFSET
		rhs := graph_expand(ctx, node.inps[1])
		if rhs.xtype == .X64_Load && len(rhs.outs) == 1 && rhs.dt == node.dt {
			mem_op := graph_extra(ctx, rhs, X64_Mem_Op)
			#reverse for pred in ctx.preds {
				if pred == node.inps[1] do break
				pnode := graph_expand(ctx, pred)
				if pnode.is_store || graph_has_flag(ctx, pnode, .Store) {
					break match
				}
			}
			mem_op.mem_mode = .Src

			return x64_make_node(
				ctx,
				id,
				op,
				{rhs.inps[0], rhs.inps[1], rhs.inps[2], node.inps[0]},
				mem_op^,
				additional_data_offset = u8(rhs.data_start),
				in_place_slot_offset = 1 - i8(rhs.data_start == 3),
			)
		}
	}

	return 0
}

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
		fmt.panicf("TODO: %v %v", node.xtype, idx)
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
	context.allocator, _ = arna.scrath()

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
			// push $reg
			emit_single_op(ctx.code, 0x50, reg)
		}
	}

	if ctx.stack_size != 0 {
		// sub rsp, $ctx.stack_size
		emit_imm_op(ctx.code, 0x81, 0b101, RSP, ctx.stack_size)
	}

	ctx.local_relocs = make([dynamic]Local_Reloc, 0, len(ctx.bbs))

	for &bb in ctx.bbs {
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
		.Add       = {0x01, 0},
		.Sub       = {0x29, 0},
		.And       = {0x21, 0},
		.Or        = {0x09, 0},
		.Xor       = {0x31, 0},
		.Eq        = {0x94, 0},
		.Ne        = {0x95, 0},
		.Lt        = {0x9C, 0},
		.Le        = {0x9E, 0},
		.Gt        = {0x9F, 0},
		.Ge        = {0x9D, 0},
		.U_Lt      = {0x92, 0},
		.U_Le      = {0x96, 0},
		.U_Gt      = {0x97, 0},
		.U_Ge      = {0x93, 0},
		.X64_Eq    = {0x94, 0},
		.X64_Ne    = {0x95, 0},
		.X64_Lt    = {0x9C, 0},
		.X64_Le    = {0x9E, 0},
		.X64_Gt    = {0x9F, 0},
		.X64_Ge    = {0x9D, 0},
		.X64_U_Lt  = {0x92, 0},
		.X64_U_Le  = {0x96, 0},
		.X64_U_Gt  = {0x97, 0},
		.X64_U_Ge  = {0x93, 0},
		.Shl       = {0xD3, 0b100},
		.U_Shr     = {0xD3, 0b101},
		.Shr       = {0xD3, 0b111},
		.And_Not   = {0xF7, 0b010},
		.U_Div     = {0xF7, 0b110},
		.U_Rem     = {0xF7, 0b110},
		.Div       = {0xF7, 0b111},
		.Rem       = {0xF7, 0b111},
		.Load      = {0x8b, 0},
		.Store     = {0x89, 0},
		.X64_Add   = {0x81, 0b000},
		.X64_Sub   = {0x81, 0b101},
		.X64_And   = {0x81, 0b100},
		.X64_Or    = {0x81, 0b001},
		.X64_Xor   = {0x81, 0b110},
		.X64_Shl   = {0xC1, 0b100},
		.X64_Shr   = {0xC1, 0b111},
		.X64_U_Shr = {0xC1, 0b101},
		.Neg       = {0xf7, 0b011},
		.Not       = {0xf7, 0b010},
	}

	@(static)
	@(rodata)
	DEST_MODE_OPCODE_CONST_TABLE := #partial [X64_Node_Type]Instr_Info {
		.X64_Add   = {0x81, 0b000},
		.X64_Sub   = {0x81, 0b101},
		.X64_And   = {0x81, 0b100},
		.X64_Or    = {0x81, 0b001},
		.X64_Xor   = {0x81, 0b110},
		.X64_Shl   = {0xC1, 0b100},
		.X64_Shr   = {0xC1, 0b111},
		.X64_U_Shr = {0xC1, 0b101},
	}

	@(static)
	@(rodata)
	DEST_MODE_OPCODE_TABLE := #partial [X64_Node_Type]Instr_Info {
		.X64_Add   = {0x01, 0b000},
		.X64_Sub   = {0x29, 0b101},
		.X64_And   = {0x21, 0b100},
		.X64_Or    = {0x09, 0b001},
		.X64_Xor   = {0x31, 0b110},
		.X64_Shl   = {0xD3, 0b100},
		.X64_Shr   = {0xD3, 0b111},
		.X64_U_Shr = {0xD3, 0b101},
		.X64_Neg   = {0xf7, 0b011},
		.X64_Not   = {0xf7, 0b010},
	}

	@(static)
	@(rodata)
	JCC_TABLE := #partial [X64_Node_Type]u8 {
		.Eq   = 0x84, // JE / JZ
		.Ne   = 0x85, // JNE / JNZ
		.Lt   = 0x8C, // JL
		.Le   = 0x8E, // JLE
		.Gt   = 0x8F, // JG
		.Ge   = 0x8D, // JGE
		.U_Lt = 0x82, // JB / JNAE
		.U_Le = 0x86, // JBE / JNA
		.U_Gt = 0x87, // JA
		.U_Ge = 0x83, // JAE / JNB
	}

	@(static)
	@(rodata)
	CMP_OP_REVERSE := #partial [X64_Node_Type]X64_Node_Type {
		.Eq       = .Ne,
		.Ne       = .Eq,
		.Lt       = .Ge,
		.Le       = .Gt,
		.Gt       = .Le,
		.Ge       = .Gt,
		.U_Lt     = .U_Ge,
		.U_Le     = .U_Gt,
		.U_Gt     = .U_Le,
		.U_Ge     = .U_Lt,
		.X64_Eq   = .Ne,
		.X64_Ne   = .Eq,
		.X64_Lt   = .Ge,
		.X64_Le   = .Gt,
		.X64_Gt   = .Le,
		.X64_Ge   = .Gt,
		.X64_U_Lt = .U_Ge,
		.X64_U_Le = .U_Gt,
		.X64_U_Gt = .U_Le,
		.X64_U_Ge = .U_Lt,
	}

	@(static)
	@(rodata)
	SRC_MODE_OPCODE_TABLE := #partial [X64_Node_Type]Instr_Info {
		.X64_Add = {0x03, 0},
		.X64_Sub = {0x2B, 0},
		.X64_And = {0x23, 0},
		.X64_Or  = {0x0B, 0},
		.X64_Xor = {0x33, 0},
	}

	block_base := ctx.gvn - u32(len(ctx.bbs))
	node := graph_expand(ctx, instr)
	mem_op_placeholder: X64_Mem_Op
	mem_op := graph_extra(ctx, node, X64_Mem_Op)
	if mem_op == nil {
		mem_op = &mem_op_placeholder
	}

	switch node.xtype {
	case .Local:
	case .Local_Addr:
		// lea [rsp + $offset]
		offset := graph_extra(ctx, node.inps[0], Local).offset
		emit_stack_lea(ctx.code, reg_of(ctx, instr), offset)
	case .Store, .X64_Store:
		bse, sdis := reg_and_disp_of(ctx, node.inps[2])
		dis := mem_op.dis
		dt := mem_op.dt

		if 3 < len(node.inps) {
			dt := graph_get(ctx, node.inps[3]).dt
			val := reg_of(ctx, node.inps[3])

			rx := rex(val, bse, NO_INDEX, DT_SIZE[dt] == 8)
			emit_sized_opcode(ctx.code, dt, rx, 0x89)
			emit_indirect_addr(ctx.code, val, bse, NO_INDEX, 1, dis + sdis)
		} else {
			imm := mem_op.imm

			rx := rex(RAX, bse, NO_INDEX, DT_SIZE[dt] == 8)
			emit_sized_opcode(ctx.code, dt, rx, 0xC7)
			emit_indirect_addr(ctx.code, RAX, bse, NO_INDEX, 1, dis + sdis)
			emit_imm_for_dt(ctx.code, dt, imm)
		}
	case .Load, .X64_Load, .Load_S:
		dt := node.dt
		bse, sdis := reg_and_disp_of(ctx, node.inps[2])
		val := reg_of(ctx, instr)
		dis := mem_op.dis
		signed := mem_op.signed || node.itype == .Load_S

		rx := rex(val, bse, NO_INDEX, DT_SIZE[dt] == 8 || signed)
		if signed {
			switch dt {
			case .Void:
			case .I8:
				// movsx $val, [$bse]
				emit(ctx.code, {rx, 0x0f, 0xbe})
			case .I16:
				// movsx $val, [$bse]
				emit(ctx.code, {rx, 0x0f, 0xbf})
			case .I32:
				// movsxd $val, [$bse]
				emit(ctx.code, {rx, 0x63})
			case .I64:
				// mov $val, [$bse]
				emit(ctx.code, {rx, 0x8b})
			}
		} else {
			switch dt {
			case .Void:
			case .I8:
				// movzx $val, [$bse]
				emit(ctx.code, {rx, 0x0f, 0xb6})
			case .I16:
				// movzx $val, [$bse]
				emit(ctx.code, {rx, 0x0f, 0xb7})
			case .I32, .I64:
				// mov $val, [$bse]
				emit(ctx.code, {rx, 0x8b})
			}
		}

		emit_indirect_addr(ctx.code, val, bse, NO_INDEX, 1, dis + sdis)
	case .Sext:
		dt := graph_get(ctx, node.inps[0]).dt
		dst := reg_of(ctx, instr)
		src := reg_of(ctx, node.inps[0])

		rx := rex(dst, src, RAX, true)
		switch dt {
		case .Void:
		case .I8:
			// movsx r64, r/m8
			emit(ctx.code, {rx, 0x0f, 0xbe})

		case .I16:
			// movsx r64, r/m16
			emit(ctx.code, {rx, 0x0f, 0xbf})

		case .I32:
			// movsxd r64, r/m32
			emit(ctx.code, {rx, 0x63})
		case .I64:
			// mov r64, r/m64
			emit(ctx.code, {rx, 0x8b})
		}
		emit(ctx.code, {mod_rm(.Direct, dst, src)})
	case .Uext:
		dt := graph_get(ctx, node.inps[0]).dt
		dst := reg_of(ctx, instr)
		src := reg_of(ctx, node.inps[0])

		rx := rex(dst, src, RAX, DT_SIZE[dt] == 8)
		switch dt {
		case .Void:
		case .I8:
			// movzx $val, [$bse]
			emit(ctx.code, {rx, 0x0f, 0xb6})
		case .I16:
			// movzx $val, [$bse]
			emit(ctx.code, {rx, 0x0f, 0xb7})
		case .I32, .I64:
			// mov $val, [$bse]
			emit(ctx.code, {rx, 0x8b})
		}
		emit(ctx.code, {mod_rm(.Direct, dst, src)})
	case .Cast:
	case .Start, .Entry, .Then, .Else, .Region, .Loop, .Call_End:
		fmt.panicf("Not reachable form here %v", node.node)
	case .If:
		cnode := graph_expand(ctx, node.inps[1])
		if cnode.dt != .Void {
			// test $cond, $cond
			cond := reg_of(ctx, node.inps[1])
			rx := rex(cond, cond, RAX, true)
			emit(ctx.code, {rx, 0x85, mod_rm(.Direct, cond, cond)})
		}

		assert(len(node.outs) == 2)
		// jz
		append(
			&ctx.local_relocs,
			Local_Reloc {
				dest = graph_get(ctx, node.outs[1].id).gvn - block_base,
				offset = u32(ctx.code.pos),
				off = 2,
			},
		)

		opcode: u8 = 0x84
		if cnode.dt == .Void {
			opcode = JCC_TABLE[CMP_OP_REVERSE[cnode.xtype]]
		}
		emit(ctx.code, {0x0f, opcode, 0, 0, 0, 0})

		fallthrough
	case .Always:
		fallthrough
	case .Jump:
		// jmp
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
		// call $call.cid
		emit(ctx.code, {0xe8, 0, 0, 0, 0})
		add_reloc(ctx.relocs)^ = {
			offset = u32(ctx.code.pos - ctx.code_start),
			kind   = .Text,
			size   = .r4,
			id     = call.cid,
		}
	case .Copy, .Set:
		lib_call: Lib_Call
		#partial switch node.itype {
		case .Copy:
			lib_call = ctx.lib_calls.copy
		case .Set:
			lib_call = ctx.lib_calls.set
		case:
			panic("wuwut")
		}

		if lib_call.absolute {
			// call [rip + $lib_call.id]
			emit(ctx.code, {0xFF, mod_sm(.Indirect, 0b010, RIP), 0, 0, 0, 0})
			add_reloc(ctx.relocs)^ = {
				offset = u32(ctx.code.pos - ctx.code_start),
				kind   = .Data,
				size   = .r4,
				id     = lib_call.id,
			}
		} else {
			// call $lib_call.id
			emit(ctx.code, {0xe8, 0, 0, 0, 0})
			add_reloc(ctx.relocs)^ = {
				offset = u32(ctx.code.pos - ctx.code_start),
				kind   = .Text,
				size   = .r4,
				id     = lib_call.id,
			}
		}
	case .Poison, .Arg, .Phi, .Ret, .Mem:
	case .CInt:
		dst := reg_of(ctx, instr)
		imm := graph_extra(ctx, node, CInt).value

		// mov $dst, $imm
		emit_single_op(ctx.code, 0xb8, dst)
		emit_anys(ctx.code, imm)
	case .X64_Add ..= .X64_Xor, .X64_Shl ..= .X64_U_Shr:
		imm := mem_op.imm

		is_shift := .X64_Shl <= node.xtype && node.xtype <= .X64_U_Shr

		switch mem_op.mem_mode {
		case .None:
			op := OPCODE_TABLE[node.xtype]
			dst := reg_of(ctx, node.inps[0])

			// add/sub/and/or/xor $dst, $imm
			rx := rex(RAX, dst, RAX, true)
			emit(ctx.code, {rx, op.opcode, mod_sm(.Direct, op.ext, dst)})
			if is_shift {
				emit(ctx.code, {u8(imm)})
			} else {
				emit_anys(ctx.code, imm)
			}
		case .Dest:
			dst, sdis := reg_and_disp_of(ctx, node.inps[2])
			dis := mem_op.dis

			op := DEST_MODE_OPCODE_CONST_TABLE[node.xtype]
			src := Reg(op.ext)
			if 3 < len(node.inps) {
				op = DEST_MODE_OPCODE_TABLE[node.xtype]
				if !is_shift {
					src = reg_of(ctx, node.inps[3])
				}
			}

			// add/sub/and/or/xor [$dst + $sdis + $dis], $src/$imm
			rx := rex(src, dst, NO_INDEX, DT_SIZE[mem_op.dt] == 8)
			emit_sized_opcode(ctx.code, mem_op.dt, rx, op.opcode)
			emit_indirect_addr(ctx.code, src, dst, NO_INDEX, 1, dis + sdis)

			if 3 >= len(node.inps) {
				if is_shift {
					emit(ctx.code, {u8(imm)})
				} else {
					emit_imm_for_dt(ctx.code, mem_op.dt, imm)
				}
			}
		case .Src:
			dst := reg_of(ctx, node.inps[3])

			bse, sdis := reg_and_disp_of(ctx, node.inps[2])
			dis := mem_op.dis

			op := SRC_MODE_OPCODE_TABLE[node.xtype]

			// add/sub/and/or/xor $dst, [$bse + $sdis + $dis]
			rx := rex(dst, bse, NO_INDEX, DT_SIZE[node.dt] == 8)
			emit_sized_opcode(ctx.code, node.dt, rx, op.opcode)
			emit_indirect_addr(ctx.code, dst, bse, NO_INDEX, 1, dis + sdis)
		}
	case .Add ..= .Xor:
		// add/sub/and/or/xor $dst, $rhs
		dst := reg_of(ctx, node.inps[0])
		rhs := reg_of(ctx, node.inps[1])
		rx := rex(rhs, dst, RAX, true)
		op := OPCODE_TABLE[node.xtype].opcode
		emit(ctx.code, {rx, op, mod_rm(.Direct, rhs, dst)})
	case .Eq ..= .U_Ge, .X64_Eq ..= .X64_U_Ge:
		lhs := reg_of(ctx, node.inps[0])
		if 1 < len(node.inps) {
			// cmp $lhs, $rhs
			rhs := reg_of(ctx, node.inps[1])
			rx := rex(lhs, rhs, RAX, true)
			emit(ctx.code, {rx, 0x3b, mod_rm(.Direct, lhs, rhs)})
		} else {
			// cmp $lhs, $imm
			rx := rex(RAX, lhs, RAX, true)
			emit(ctx.code, {rx, 0x81, mod_sm(.Direct, 0b111, lhs)})
			emit_anys(ctx.code, mem_op.imm)
		}

		if node.dt != .Void {
			dst := reg_of(ctx, instr)

			// setcc $lhs
			rx := rex(RAX, dst, RAX, true)
			op := OPCODE_TABLE[node.xtype].opcode
			emit(ctx.code, {rx, 0x0F, op, mod_sm(.Direct, 0b000, dst)})

			// movzx $lhs, $lhs
			rx = rex(dst, dst, RAX, true)
			emit(ctx.code, {rx, 0x0F, 0xB6, mod_rm(.Direct, dst, dst)})
		}
	case .And_Not:
		dst := reg_of(ctx, node.inps[1])
		lhs := reg_of(ctx, node.inps[0])
		// not $dst
		rx := rex(RAX, dst, RAX, true)
		emit(ctx.code, {rx, 0xf7, mod_sm(.Direct, 0b010, dst)})
		// and $dst, $lhs
		rx = rex(lhs, dst, RAX, true)
		emit(ctx.code, {rx, 0x21, mod_rm(.Direct, lhs, dst)})
	case .Shl ..= .U_Shr:
		// shl/shr $dst, cl
		dst := reg_of(ctx, node.inps[0])
		rx := rex(RAX, dst, RAX, true)
		op := OPCODE_TABLE[node.xtype].ext
		emit(ctx.code, {rx, 0xd3, mod_sm(.Direct, op, dst)})
	case .X64_Neg ..= .X64_Not:
		assert(mem_op.mem_mode == .Dest)
		dis := mem_op.dis
		dst, sdis := reg_and_disp_of(ctx, node.inps[2])

		op := DEST_MODE_OPCODE_TABLE[node.xtype]

		rx := rex(RAX, dst, NO_INDEX, DT_SIZE[mem_op.dt] == 8)
		emit_sized_opcode(ctx.code, mem_op.dt, rx, op.opcode)
		emit_indirect_addr(ctx.code, Reg(op.ext), dst, NO_INDEX, 1, dis + sdis)
	case .Neg ..= .Not:
		// neg/not $dst
		dst := reg_of(ctx, node.inps[0])
		op := OPCODE_TABLE[node.xtype]
		rx := rex(RAX, dst, RAX, true)
		emit(ctx.code, {rx, op.opcode, mod_sm(.Direct, op.ext, dst)})
	case .Mul:
		// imul $dst, $rhs
		dst := reg_of(ctx, node.inps[0])
		rhs := reg_of(ctx, node.inps[1])
		rx := rex(dst, rhs, RAX, true)
		emit(ctx.code, {rx, 0x0f, 0xaf, mod_rm(.Direct, dst, rhs)})
	case .Div, .Rem:
		rhs := reg_of(ctx, node.inps[1])
		// cqo
		emit(ctx.code, {rex(RAX, RAX, RAX, true), 0x99})
		// idiv $rhs
		rx := rex(RAX, rhs, RAX, true)
		emit(ctx.code, {rx, 0xf7, mod_sm(.Direct, 0b111, rhs)})
	case .U_Div, .U_Rem:
		rhs := reg_of(ctx, node.inps[1])
		// xor rdx, rdx
		rx := rex(RDX, RDX, RAX, true)
		emit(ctx.code, {rx, 0x31, mod_rm(.Direct, RDX, RDX)})
		// div $rhs
		rx = rex(RAX, rhs, RAX, true)
		emit(ctx.code, {rx, 0xf7, mod_sm(.Direct, 0b110, rhs)})
	case .Split:
		dst := reg_of(ctx, instr)
		src := reg_of(ctx, node.inps[0])
		assert(dst.kind == src.kind)
		if dst == src do break
		if int(dst) >= 16 {
			// mov [rsp + $dst_offset], $src
			dst_offset := ctx.spill_slot_base[dst.kind] + 8 * (int(dst) - 16)

			assert(int(src) < 16)

			emit(ctx.code, {rex(src, RSP, RAX, true), 0x89})
			emit_indirect_addr(ctx.code, src, RSP, NO_INDEX, 1, dst_offset)
		} else if int(src) >= 16 {
			// mov $dst, [rsp + $src_offset]
			src_offset := ctx.spill_slot_base[dst.kind] + 8 * (int(src) - 16)
			assert(int(dst) < 16)

			emit(ctx.code, {rex(dst, RSP, RAX, true), 0x8b})
			emit_indirect_addr(ctx.code, dst, RSP, NO_INDEX, 1, src_offset)
		} else {
			assert(int(dst) < 16)
			assert(int(src) < 16)

			// mov $dst, $src
			emit_reg_op(ctx.code, 0x89, src, dst)
		}
	case .Return:
		if ctx.stack_size != 0 {
			// sub rsp, -$ctx.stack_size
			emit_imm_op(ctx.code, 0x81, 0b101, RSP, -ctx.stack_size)
		}

		#reverse for reg in CALLE_SAVED {
			if bit_arr.contains(ctx.used, int(reg)) {
				// pop $reg
				emit_single_op(ctx.code, 0x58, reg)
			}
		}

		// ret
		emit(ctx.code, {0xc3})
	}
}

reg_of :: proc(ctx: Codegen_Emit_Ctx, id: Node_ID) -> Reg {
	node := graph_get(ctx, id)
	assert(int(node.gvn) < len(ctx.allocs))
	return ctx.allocs[node.gvn]
}

reg_and_disp_of :: proc(ctx: Codegen_Emit_Ctx, id: Node_ID) -> (Reg, i32) {
	node := graph_get(ctx, id)
	if node.itype == .Local do return RSP, i32(graph_extra(ctx, node, Local).offset)
	return ctx.allocs[node.gvn], 0
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

emit_imm_for_dt :: proc(code: ^arna.Allocator, dt: Node_Datatype, imm: i32) {
	switch dt {
	case .Void:
		panic("")
	case .I8:
		emit_anys(code, i8(imm))
	case .I16:
		emit_anys(code, i16(imm))
	case .I64, .I32:
		emit_anys(code, imm)
	}
}

emit_sized_opcode :: proc(
	code: ^arna.Allocator,
	dt: Node_Datatype,
	rx: u8,
	op: u8,
) {
	switch dt {
	case .Void:
		panic("")
	case .I8:
		// mov [$bse], $val
		emit(code, {rx, op - 1})
	case .I16:
		// mov [$bse], $val
		emit(code, {0x66, rx, op})
	case .I32, .I64:
		// mov [$bse], $val
		emit(code, {rx, op})
	}
}
