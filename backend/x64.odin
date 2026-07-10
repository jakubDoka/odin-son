package backend

import "../vendored/gam/util/arna"
import "../vendored/gam/util/bit_arr"
import "base:intrinsics"
import "core:fmt"
import "core:math"
import "core:mem"
import "core:reflect"
import "core:slice"
import "core:sort"

NOOP_REX :: 0b0100_0000

GPA_MASK :: []int{0xFFFF & ~int(1 << uint(RSP))}
GPA_SPILL_MASK :: []int{~int(1 << uint(RSP))}
NO_INDEX :: RSP
GPA_RET_MASK :: []int{1 << uint(RAX)}
GPA_RET_MASK_SEC :: []int{1 << uint(RDX)}
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

RCX_MASK :: []int{1 << uint(RCX)}

VEC_BANK :: u16(Reg_Kind.Vector) << 12
XMM0 :: Reg(VEC_BANK | 0)
XMM1 :: Reg(VEC_BANK | 1)
XMM2 :: Reg(VEC_BANK | 2)
XMM3 :: Reg(VEC_BANK | 3)
XMM4 :: Reg(VEC_BANK | 4)
XMM5 :: Reg(VEC_BANK | 5)
XMM6 :: Reg(VEC_BANK | 6)
XMM7 :: Reg(VEC_BANK | 7)
XMM8 :: Reg(VEC_BANK | 8)
XMM9 :: Reg(VEC_BANK | 9)
XMM10 :: Reg(VEC_BANK | 10)
XMM11 :: Reg(VEC_BANK | 11)
XMM12 :: Reg(VEC_BANK | 12)
XMM13 :: Reg(VEC_BANK | 13)
XMM14 :: Reg(VEC_BANK | 14)
XMM15 :: Reg(VEC_BANK | 15)

XMM_MASK :: []int{0xFFFF}
XMM_SPILL_MASK :: []int{~int(0)}

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

GPA_REG_COUNT :: 16

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

@(rodata)
X64_ODIN_CC := Call_Conv {
	name = "X64_ODIN_CC",
	callee_saved = #partial{.General = {RBX, RBP, R12, R13, R14, R15}},
	caller_saved = #partial{
		.General = {RAX, RCX, RDX, RSI, RDI, R8, R9, R10, R11},
		.Vector = {
			XMM0,
			XMM1,
			XMM2,
			XMM3,
			XMM4,
			XMM5,
			XMM6,
			XMM7,
			XMM8,
			XMM9,
			XMM10,
			XMM11,
			XMM12,
			XMM13,
			XMM14,
			XMM15,
		},
	},
	args = #partial{
		.General = {RDI, RSI, RDX, RCX, R8, R9},
		.Vector = {XMM0, XMM1, XMM2, XMM3, XMM4, XMM5, XMM6, XMM7},
	},
	rets = #partial{.General = {RAX, RDX}, .Vector = {XMM0, XMM1}},
	red_zone_size = 128,
}

@(rodata)
X64_LINUX_SYSCALL_CC := Call_Conv {
	name = "X64_LINUX_SYSCALL_CC",
	callee_saved = #partial{
		.General = {RBX, RDX, RDI, RSI, RBP, R8, R9, R10, R12, R13, R14, R15},
	},
	caller_saved = #partial{.General = {RAX, RCX, R11}},
	args = #partial{.General = {RAX, RDI, RSI, RDX, R10, R8, R9}},
	rets = #partial{.General = {RAX}},
	is_syscall = true,
}

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

FLOAT_BINOP_SPEC :: Reg_Class_Spec {
	reg_masks = #partial{.Vector = {XMM_MASK, XMM_MASK, XMM_MASK}},
	inplace_slot_idx = 0,
}

FLOAT_CMP_SPEC :: Reg_Class_Spec {
	reg_masks = #partial{
		.Vector = {{}, XMM_MASK, XMM_MASK},
		.General = {GPA_MASK},
	},
}

FLOAT_CONV_SPEC :: Reg_Class_Spec {
	reg_masks = #partial{.Vector = {XMM_MASK, XMM_MASK}},
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
	.CInt = {
		reg_masks = #partial{.General = {GPA_MASK}, .Vector = {XMM_MASK}},
	},
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
	.F_Add ..= .F_Div = FLOAT_BINOP_SPEC,
	.F_Eq ..= .F_Ge = FLOAT_CMP_SPEC,
	.F_Ext ..= .F_Demote = FLOAT_CONV_SPEC,
	.F_From_I = {
		reg_masks = #partial{.General = {{}, GPA_MASK}, .Vector = {XMM_MASK}},
	},
	.F_To_I = {
		reg_masks = #partial{.General = {GPA_MASK}, .Vector = {{}, XMM_MASK}},
	},
	.Split = {
		reg_masks = #partial{
			.General = {GPA_SPILL_MASK, GPA_SPILL_MASK},
			.Vector = {XMM_SPILL_MASK, XMM_SPILL_MASK},
		},
	},
	.Phi = {
		input_start_idx = 1,
		reg_masks = #partial{
			.General = {
				GPA_SPILL_MASK,
				GPA_SPILL_MASK,
				GPA_SPILL_MASK,
				GPA_SPILL_MASK,
				GPA_SPILL_MASK,
			},
			.Vector = {
				XMM_SPILL_MASK,
				XMM_SPILL_MASK,
				XMM_SPILL_MASK,
				XMM_SPILL_MASK,
				XMM_SPILL_MASK,
			},
		},
	},
	.Mem = {input_start_idx = 1},
	.Local = {input_start_idx = 1},
	.Local_Addr = {
		input_start_idx = 1,
		reg_masks = #partial{.General = {GPA_MASK}},
	},
	.Global = {input_start_idx = 0},
	.Global_Addr = {
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
		reg_masks = #partial{
			.General = {{}, GPA_MASK, GPA_MASK},
			.Vector = {{}, XMM_MASK, XMM_MASK},
		},
	},
	.If = {
		reg_masks = #partial{.General = {{}, GPA_MASK}},
		input_start_idx = 1,
	},
	.Ret = {input_start_idx = 1},
	.Then = {},
	.Else = {},
	.Region = {},
	.Loop = {},
	.Always = {input_start_idx = 1},
	.Call = {input_start_idx = 2},
	.Copy = {
		input_start_idx = 2,
		reg_masks = #partial{.General = {{}, RDI_MASK, RSI_MASK, RDX_MASK}},
	},
	.Set = {
		input_start_idx = 2,
		reg_masks = #partial{.General = {{}, RDI_MASK, RSI_MASK, RDX_MASK}},
	},
	.Call_End = {},
	.Jump = {input_start_idx = 1},
	.Return = {
		reg_masks = #partial{.General = {{}, GPA_RET_MASK, GPA_RET_MASK_SEC}},
		input_start_idx = 2,
	},
}

X64_SIMPE_OP :: Reg_Class_Spec {
	inplace_slot_idx = 0,
	reg_masks = #partial{.General = {GPA_MASK, GPA_MASK, GPA_MASK, GPA_MASK}},
}

X64_SIMPE_CMP_OP :: Reg_Class_Spec {
	reg_masks = #partial{.General = {GPA_MASK, GPA_MASK, GPA_MASK, GPA_MASK}},
}

@(rodata)
X64_REG_CLASSES := #partial [X64_Node_Type]Reg_Class_Spec {
	.X64_Add ..= .X64_Xor = X64_SIMPE_OP,
	.X64_Eq ..= .X64_U_Ge = X64_SIMPE_CMP_OP,
	.X64_Shl ..= .X64_U_Shr = SIMPLE_SHIFT_SPEC,
	.X64_Neg ..= .X64_Not = SIMPLE_UNOP_SPEC,
	.X64_Load = {
		input_start_idx = 2,
		reg_masks = #partial{
			.General = {GPA_MASK, GPA_MASK, GPA_MASK},
			.Vector = {XMM_MASK, XMM_MASK, XMM_MASK},
		},
	},
	.X64_Store = {
		input_start_idx = 2,
		reg_masks = #partial{
			.General = {{}, GPA_MASK, GPA_MASK, GPA_MASK},
			.Vector = {{}, XMM_MASK, XMM_MASK, XMM_MASK},
		},
	},
	.X64_Mul8 = {
		reg_masks = #partial{.General = {RAX_MASK, GPA_MASK, RAX_MASK}},
	},
	.X64_Lea = {
		reg_masks = #partial{.General = {GPA_MASK, GPA_MASK, GPA_MASK}},
	},
	.X64_Mul = X64_SIMPE_CMP_OP,
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
		X64_Mul,
		X64_Lea,
		X64_Load,
		X64_Store,
		X64_Neg,
		X64_Not,
		X64_Mul8,
	}

	X64_SIMPLE_BIN_OP_SPEC :: Class_Spec {
		id      = X64_Mem_Op,
		no_ctor = true,
	}

	X64_SIMPLE_SHIFT_OP_SPEC :: Class_Spec {
		id      = X64_Mem_Op,
		no_ctor = true,
	}

	X64_SIMPLE_UN_OP_SPEC :: Class_Spec {
		id      = X64_Mem_Op,
		no_ctor = true,
	}

	@(rodata)
	X64_CLASSES := [X64_Node_Type]Class_Spec {
		.X64_Add ..= .X64_U_Ge = X64_SIMPLE_BIN_OP_SPEC,
		.X64_Shl ..= .X64_U_Shr = X64_SIMPLE_SHIFT_OP_SPEC,
		.X64_Neg ..= .X64_Not = X64_SIMPLE_UN_OP_SPEC,
		.X64_Mul = X64_SIMPLE_BIN_OP_SPEC,
		.X64_Lea = {id = X64_Mem_Op, no_ctor = true},
		.X64_Load = {id = X64_Mem_Op, flags = {.Load}, no_ctor = true},
		.X64_Store = {id = X64_Mem_Op, flags = {.Store}, no_ctor = true},
		.X64_Mul8 = {no_ctor = true},
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
	scale:    u8,
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

	rhs_const: ^CInt
	val_const: ^CInt

	slots := [2]^^CInt{&rhs_const, &val_const}
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

	base, index: Node_ID
	scale: i32
	displacement: i32
	stack_base: bool
	if 2 < len(node.inps) {
		nbase, ndisplacement := base_and_offset(ctx, node.inps[2])
		if int(i32(ndisplacement)) == ndisplacement {
			base, displacement = nbase, i32(ndisplacement)
		}

		bnode := graph_expand(ctx, nbase)
		if bnode.xtype == .X64_Lea {
			mem_op := graph_extra(ctx, bnode, X64_Mem_Op)
			scale = i32(mem_op.scale)
			overflowed: bool
			displacement, overflowed = intrinsics.overflow_add(
				displacement,
				mem_op.dis,
			)
			assert(!overflowed)

			index = bnode.inps[1]
			base = bnode.inps[0]
			nbase = base
		}

		bnode = graph_expand(ctx, nbase)
		if bnode.itype == .Local_Addr {
			base = bnode.inps[0]
			stack_base = true
		} else if bnode.itype == .Global_Addr && index == 0 {
			base = bnode.inps[0]
			stack_base = true
		} else {
			stack_base =
				bnode.itype == .Local || (bnode.itype == .Global && index == 0)
		}
	}

	#partial switch node.itype {
	case .Add ..= .Xor, .Eq ..= .U_Ge, .Shl ..= .U_Shr, .Mul:
		op := u16(node.itype) + BIN_OP_OFFSET

		if node.dt == .I8 && node.itype == .Mul {
			node.xtype = .X64_Mul8
			return id
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

		if rhs_const != nil {
			return x64_make_node(
				ctx,
				id,
				op,
				node.inps[:1],
				{imm = i32(rhs_const.value)},
			)
		}

		if chanded do return id

		indexify: if node.itype == .Add {
			rhs := graph_expand(ctx, node.inps[1])

			ascale: i32 = 1
			aindex := node.inps[1]

			if rhs.xtype == .X64_Mul {
				ascale = graph_extra(ctx, rhs, X64_Mem_Op).imm
				aindex = rhs.inps[0]
			} else if rhs.itype == .Mul {
				arhs_const := graph_extra(ctx, rhs.inps[1], CInt)
				if arhs_const != nil &&
				   i64(i32(arhs_const.value)) == arhs_const.value {
					ascale = i32(arhs_const.value)
					aindex = rhs.inps[0]
				}
			}

			if ascale > 8 || !math.is_power_of_two(int(ascale)) {
				break indexify
			}

			if graph_get(ctx, aindex).itype == .CInt do break indexify

			abase, offset := base_and_offset(ctx, node.inps[0])
			if int(i32(offset)) == offset {
				displacement = i32(offset)
			}

			bnode := graph_expand(ctx, abase)
			if bnode.itype == .Local_Addr {
				abase = bnode.inps[0]
				stack_base = true
			}

			if ascale == 1 && !stack_base && offset == 0 {
				break indexify
			}

			return x64_make_node(
				ctx,
				id,
				u16(X64_Node_Type.X64_Lea),
				{abase, aindex},
				{scale = u8(ascale), dis = displacement},
				additional_data_offset = u8(stack_base),
			)
		}
	case .F_Eq ..= .F_Ge:
		if node.dt != .Void &&
		   len(node.outs) == 1 &&
		   graph_get(ctx, node.outs[0].id).itype == .If {
			node.dt = .Void
			return id
		}
	case .If:
		node.additional_data_start = u8(
			graph_get(ctx, node.inps[1]).dt == .Void,
		)
	case .Load, .Load_S:
		load_inps := [4]Node_ID{node.inps[0], node.inps[1], base, index}
		return x64_make_node(
			ctx,
			id,
			u16(X64_Node_Type.X64_Load),
			load_inps[:3 + int(scale != 0)],
			{
				dis = displacement,
				scale = u8(scale),
				signed = node.itype == .Load_S,
			},
			additional_data_offset = u8(stack_base),
		)
	case .Store:
		immediate: i32
		inps := [5]Node_ID {
			node.inps[0],
			node.inps[1],
			base,
			node.inps[3],
			index,
		}
		count := 4
		if val_const != nil {
			immediate = i32(val_const.value)
			inps[3] = index
			count = 3
		}
		count += int(scale != 0)

		res := x64_make_node(
			ctx,
			id,
			u16(X64_Node_Type.X64_Store),
			inps[:count],
			{
				dis = displacement,
				imm = immediate,
				scale = u8(scale),
				dt = graph_get(ctx, node.inps[3]).dt,
			},
			additional_data_offset = u8(stack_base),
		)

		worklist_add(ctx, ctx.worklist, res)
		return res
	}

	mem_op := graph_extra(ctx, node, X64_Mem_Op)

	#partial matchx: switch node.xtype {
	case .X64_Store, .X64_Load:
		changed := false

		if scale != 0 && mem_op.scale != 0 {
			break matchx
		}

		if scale != 0 {
			graph_connect(ctx, id, index)
			mem_op.scale = u8(scale)
			node = graph_expand(ctx, id)
			changed = true
		}

		swap_out_imm :: proc(ctx: Peep_Ctx, node: Expanded_Node) {
			id := graph_id(ctx, node)
			outs := graph_outs(ctx, node.inps[4])
			oi :=
				slice.linear_search(
					outs,
					Node_Output{idx = 4, id = id},
				) or_else panic("")
			outs[oi].idx = 3
			node.inps[3], node.inps[4] = node.inps[4], node.inps[3]
		}

		assert(val_const == nil)

		mem_op.dis += displacement

		changed |= node.inps[2] != base
		graph_set_input(ctx, id, 2, base)

		node.additional_data_start = max(
			node.additional_data_start,
			u8(stack_base),
		)

		if node.xtype == .X64_Store &&
		   3 + int(mem_op.scale != 0) < len(node.inps) {
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

			is_interesting :=
				((val.xtype in X64_TRIGGER_OPS && len(val.inps) == 1) ||
					val.itype in IDEAL_TRIGGER_OPS)

			if is_interesting && len(val.outs) == 1 {
				lhs := graph_expand(ctx, val.inps[0])
				lhs_mem := graph_extra(ctx, lhs, X64_Mem_Op)
				dest_op: if lhs.xtype == .X64_Load &&
				   lhs.inps[1] == node.inps[1] &&
				   lhs.inps[2] == node.inps[2] &&
				   lhs_mem.scale == mem_op.scale &&
				   (lhs_mem.scale == 0 ||
						   lhs.inps[len(lhs.inps) - 1] ==
							   node.inps[len(node.inps) - 1]) &&
				   lhs_mem.dis == mem_op.dis {

					needs_removal :=
						val.xtype in X64_TRIGGER_OPS ||
						val.itype in IDEAL_TRIGGER_UN_OPS

					rm_idx := 3 + int(lhs_mem.scale != 0)
					if lhs_mem.scale != 0 && needs_removal {
						swap_out_imm(ctx, node)
					}

					node.xtype = val.xtype

					if val.itype in IDEAL_TRIGGER_UN_OPS {
						assert(node.rtype < len(IDEAL_CLASSES))
						node.rtype += UN_OP_OFFSET
					} else if val.xtype in X64_TRIGGER_OPS {
						mem_op.imm = val_mem.imm
					}

					if needs_removal {
						graph_remove_output(
							ctx,
							node.inps[rm_idx],
							{idx = 3, id = id},
						)
						node.input_count -= 1
						node.inps = node.inps[:len(node.inps) - 1]
					} else {
						assert(node.rtype < len(IDEAL_CLASSES))
						node.rtype += BIN_OP_OFFSET
						graph_set_input(ctx, id, 3, val.inps[1])
					}

					mem_op.mem_mode = .Dest
					node.in_place_slot_offset = -1
					node.additional_data_start += 2
					changed = true
				} else {
					peep_ctx_add_trigger(ctx, val.inps[0], id)
					if lhs.xtype == .X64_Load {
						peep_ctx_add_trigger(ctx, lhs.inps[2], id)
					}
				}
			}
		}

		if changed do return id
		return 0
	case .X64_Eq ..= .X64_U_Ge:
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
	id := graph_add_raw(graph, type, fnode.dt, inps)
	node := graph_get(graph, id)
	// NOTE: afaik this is sufficient since we don't insert load ops before
	// scheduling
	node.is_store = fnode.is_store
	node.is_load = fnode.is_load
	node.additional_data_start = additional_data_offset
	node.in_place_slot_offset = in_place_slot_offset
	graph_extra(graph, node, X64_Mem_Op)^ = extra
	return id
}

x64_post_schedule_peep :: proc(
	ctx: PS_Peep_Ctx,
	node: Expanded_Node,
) -> Node_ID {
	id := graph_id(ctx, node)
	#partial matchi: switch node.itype {
	case .Add ..= .Xor, .Eq ..= .U_Ge:
		op := node.rtype + BIN_OP_OFFSET
		rhs := graph_expand(ctx, node.inps[1])
		if rhs.xtype == .X64_Load && len(rhs.outs) == 1 {
			mem_op := graph_extra(ctx, rhs, X64_Mem_Op)
			if !has_no_clobbers(ctx, node.inps[1]) do break matchi
			mem_op.mem_mode = .Src
			mem_op.dt = rhs.dt

			slots: [5]Node_ID
			copy(slots[:], rhs.inps)
			slots[4] = slots[3]
			slots[3] = node.inps[0]

			return x64_make_node(
				ctx,
				id,
				op,
				slots[:len(slots) - int(slots[4] == 0)],
				mem_op^,
				additional_data_offset = u8(rhs.data_start),
				in_place_slot_offset = 1 - i8(rhs.data_start == 3),
			)
		}
	}
	#partial matchx: switch node.xtype {
	case .X64_Eq ..= .X64_U_Ge:
		mem_op := graph_extra(ctx, node, X64_Mem_Op)
		if mem_op.mem_mode != .None do break matchx
		lhs := graph_expand(ctx, node.inps[0])
		if lhs.xtype == .X64_Load && len(lhs.outs) == 1 {
			om_mem_op := graph_extra(ctx, lhs, X64_Mem_Op)
			if !has_no_clobbers(ctx, node.inps[0]) do break matchx
			om_mem_op.imm = mem_op.imm
			om_mem_op.mem_mode = .Dest
			om_mem_op.dt = lhs.dt

			return x64_make_node(
				ctx,
				id,
				node.rtype,
				lhs.inps,
				om_mem_op^,
				additional_data_offset = u8(lhs.data_start),
				in_place_slot_offset = 0,
			)
		}
	}

	has_no_clobbers :: proc(ctx: PS_Peep_Ctx, inp: Node_ID) -> bool {
		#reverse for pred in ctx.preds {
			if pred == inp do return true
			if graph_get(ctx, pred).rtype == DEAD_NODE_KIND do continue
			pnode := graph_expand(ctx, pred)
			if pnode.is_store do break
		}

		return false
	}

	return 0
}

// whole-bank mask helpers for the mixed-bank float nodes. a fresh copy is
// returned so the caller may mutate it (def masks get intersected in place).
reg_bank_mask :: proc(ra: ^Regalloc, kind: Reg_Kind, src: []int) -> Reg_Mask {
	mask := reg_mask_empty(ra, kind)
	copy(mask.masks[:len(src)], src)
	return mask
}

cc_reg_for_operand :: proc(
	graph: ^Graph,
	node: Expanded_Node,
	banks: [Reg_Kind][]Reg,
	pos: int,
) -> Reg {
	PREFIX :: 2
	counts: [Reg_Kind]int
	for i in PREFIX ..< pos {
		rk := graph.datatype_to_reg_kind[graph_get(graph, node.inps[i]).dt]
		counts[rk] += 1
	}
	rk := graph.datatype_to_reg_kind[graph_get(graph, node.inps[pos]).dt]
	return banks[rk][counts[rk]]
}

x64_reg_mask_of :: proc(
	graph: ^Graph,
	ra: ^Regalloc,
	id: Node_ID,
	idx: int,
) -> Reg_Mask {
	node := graph_expand(graph, id)

	pos := idx - 1 + node.data_start

	#partial switch node.itype {
	case .Arg:
		kind := ra.datatype_to_reg_kind[node.dt]
		args := ra.args[kind]
		arg_ext := graph_extra(graph, node, Tup)
		if int(arg_ext.idx) < len(args) {
			return reg_mask_single(ra, args[arg_ext.idx])
		} else {
			return reg_mask_single(
				ra,
				{
					kind = kind,
					index = GPA_REG_COUNT + u16(arg_ext.idx) - u16(len(args)),
				},
			)
		}
	case .Call:
		call := graph_extra(graph, id, Call)
		cc := ra.cc_table[call.ccid]
		reg := cc_reg_for_operand(graph, node, cc.args, pos)
		return reg_mask_single(ra, reg)
	case .Ret:
		cend := graph_expand(graph, node.inps[0])
		call := graph_extra(graph, cend.inps[0], Call)
		ret_ext := graph_extra(graph, node, Tup)
		kind := ra.datatype_to_reg_kind[node.dt]
		rets := ra.cc_table[call.ccid].rets[kind]
		return reg_mask_single(ra, rets[ret_ext.idx])
	case .Return:
		assert(idx != 0)
		reg := cc_reg_for_operand(graph, node, ra.rets, pos)
		return reg_mask_single(ra, reg)
	case .Phi:
		// TODO: fix this to have a borrow
		kind := ra.datatype_to_reg_kind[node.dt]
		return reg_bank_mask(
			ra,
			kind,
			kind == .Vector ? XMM_SPILL_MASK : GPA_SPILL_MASK,
		)
	}

	fmt.panicf(
		"TODO: %v %v %v",
		node.xtype,
		idx,
		graph_get(graph, node.inps[pos]),
	)
}

Ctx :: struct {
	using inner:        Codegen_Emit_Ctx,
	spill_slot_base:    [Reg_Kind]i32,
	big_constants:      [dynamic]u8,
	local_relocs:       [dynamic]Local_Reloc,
	stack_size:         i32,
	used:               bit_arr.Bit_Set,
	code_start:         uint,
	stack_param_offset: [Reg_Kind][dynamic]i32,
}

Local_Reloc :: struct {
	dest:   u32,
	offset: u32,
}

emit_big_constant :: proc(ctx: ^Ctx, const: any) -> (id: u32) {
	align_up := mem.align_backward_int(
		len(ctx.big_constants) + 2,
		reflect.align_of_typeid(const.id),
	)

	for _ in len(ctx.big_constants) + 2 ..< align_up {
		append(&ctx.big_constants, 0)
	}

	append(
		&ctx.big_constants,
		u8(reflect.size_of_typeid(const.id)),
		u8(reflect.align_of_typeid(const.id)),
	)

	id = RELOC_BIG_CONSTANT_BASE + u32(len(ctx.big_constants))

	append(&ctx.big_constants, ..reflect.as_bytes(const))

	return
}

x64_emit_function :: proc(ectx: Codegen_Emit_Ctx) -> Codegen_Output {
	context.allocator, _ = arna.scrath()

	reloc_start := ectx.relocs.pos

	ctx: Ctx
	ctx.code_start = ectx.code.pos
	ctx.inner = ectx

	slot: [2]int
	ctx.used = bit_arr.init_from_masks(slot[:])

	has_call := false
	for bb in ctx.schedule.bbs {
		bnode := graph_expand(ctx, bb.head)

		for ins in bb.instrs {
			has_call |= graph_get(ctx, ins).itype in CALLS
		}

		if bnode.itype != .Call_End do continue
		cnode := graph_expand(ctx, bnode.inps[0])
		call_stack_size: i32
		for inp in raw_data(cnode.inps)[cnode.input_count:cnode.input_cap] {
			inode := graph_expand(ctx, inp)
			if inode.itype != .Local do continue
			iext := graph_extra(ctx, inode, Local)
			call_stack_size += iext.size
			iext.offset = call_stack_size - iext.size
		}
		ctx.stack_size = max(ctx.stack_size, call_stack_size)
	}

	emem, _ := find_node(ctx.graph, .Mem)
	mem_outs: []Node_Output
	if emem != 0 {
		mem_outs = graph_outs(ctx.graph, emem)
	}

	Local_Slot :: bit_field u64 {
		node:     Node_ID | 32,
		priority: i32     | 32,
	}
	locals: [dynamic]Local_Slot

	for mout in mem_outs {
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
		ctx.stack_size += extra.size
		extra.offset = ctx.stack_size - extra.size
	}

	// NOTE: the Arg and Local never get promoted to a different node so we can
	// just order them by the node id, the allocation order matters tho so
	// document that somewhere
	args: [dynamic]Node_ID
	find_args: for eout in graph_outs(ctx, ctx.entry) {
		enode := graph_expand(ctx, eout.id)
		if enode.itype != .Arg && enode.itype != .Local do continue

		if enode.itype == .Local {
			for lout in enode.outs {
				lonode := graph_expand(ctx, lout.id)
				if lonode.itype == .Call {
					continue find_args
				}
			}
		}

		append(&args, eout.id)
	}

	sort.quick_sort(args[:])

	spill_slot_count: [Reg_Kind]i32
	for reg in ctx.allocs {
		spill_slot_count[reg.kind] = max(
			spill_slot_count[reg.kind],
			i32(reg.index) - 16 + 1,
		)
		bit_arr.set_unbounded(ctx.used, int(reg.index))
	}

	pushed: i32
	for reg in ctx.callee_saved[.General] {
		if bit_arr.contains(ctx.used, int(reg)) {
			// push $reg
			emit_single_op(ctx.code, 0x50, reg)
			pushed += 8
		}
	}

	for size, kind in spill_slot_count {
		ctx.spill_slot_base[kind] = i32(ctx.stack_size)
		ctx.stack_size += size * 8
	}

	param_offset := pushed + 8
	gpa_fuel := len(ctx.args[.General])
	#reverse for arg in args {
		enode := graph_expand(ctx, arg)

		gpa_fuel -= int(enode.itype == .Arg)
		if enode.itype == .Arg && gpa_fuel < 0 {
			kind := ctx.datatype_to_reg_kind[enode.dt]
			ctx.stack_size -= 8
			append(&ctx.stack_param_offset[kind], i32(param_offset))
			param_offset += 8
		}

		if enode.itype == .Local {
			extra := graph_extra(ctx.graph, enode, Local)
			extra.offset = param_offset
			param_offset += extra.size
		}
	}

	if has_call || ctx.stack_size != 0 {
		to_align := pushed + 8 + ctx.stack_size
		padding := i32(mem.align_forward_int(int(to_align), 16)) - to_align
		ctx.stack_size += padding
	}

	used_red_zone: i32
	if !has_call {
		used_red_zone = min(ctx.red_zone_size, ctx.stack_size)
	}

	ctx.stack_size -= used_red_zone

	for mout in mem_outs {
		local := graph_extra(ctx, mout.id, Local)
		if local == nil do continue
		local.offset -= used_red_zone
	}

	for &slot in ctx.spill_slot_base {
		slot -= used_red_zone
	}

	for arg in args {
		enode := graph_expand(ctx, arg)
		if enode.itype == .Local {
			extra := graph_extra(ctx.graph, enode, Local)
			extra.offset += ctx.stack_size
		}
	}

	for &group in ctx.stack_param_offset {
		for &off in group do off += i32(ctx.stack_size)
	}

	if ctx.stack_size != 0 {
		// sub rsp, $ctx.stack_size
		emit_imm_op(ctx.code, 0x81, 0b101, RSP, ctx.stack_size)
	}

	ctx.local_relocs = make([dynamic]Local_Reloc, 0, len(ctx.bbs))

	prev_is_if := false
	for &bb, i in ctx.bbs {
		bb.offset = u32(ctx.code.pos)

		last := graph_expand(ctx, bb.instrs[len(bb.instrs) - 1])
		is_consecutive :=
			i + 1 < len(ctx.bbs) &&
			0 < len(last.outs) &&
			ctx.bbs[i + 1].head == last.outs[0].id

		if len(bb.instrs) == 1 && last.itype == .Jump && !prev_is_if {
			continue
		}

		for instr in bb.instrs {
			x64_emit_instr(&ctx, instr, is_consecutive, 0)
		}

		prev_is_if = last.itype == .If
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
		jump := dst_offset - reloc.offset - size

		copy(ctx.code.ptr[reloc.offset:][:size], reflect.as_bytes(jump))
	}

	code := ctx.code.ptr[ctx.code_start:ctx.code.pos]
	relocs := mem.slice_data_cast(
		[]Reloc,
		ctx.relocs.ptr[reloc_start:ctx.relocs.pos],
	)
	arna.alloc(ctx.code, 0, 8)
	constants := arna.clone(ctx.code, ctx.big_constants[:])

	return {code = code, relocs = relocs, constants = constants}
}

@(disabled = GEN_SPEC)
x64_emit_instr :: proc(
	ctx: ^Ctx,
	instr: Node_ID,
	is_consecutive: bool,
	_: $T,
) {

	@(static, rodata)
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
		.F_Eq      = {0x94, 0},
		.F_Ne      = {0x95, 0},
		.F_Gt      = {0x97, 0},
		.F_Ge      = {0x93, 0},
		.F_Lt      = {0x97, 0},
		.F_Le      = {0x93, 0},
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

	@(static, rodata)
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

	@(static, rodata)
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

	@(static, rodata)
	CMP_OP_REVERSE := #partial [X64_Node_Type]X64_Node_Type {
		.Eq       = .Ne,
		.Ne       = .Eq,
		.Lt       = .Ge,
		.Le       = .Gt,
		.Gt       = .Le,
		.Ge       = .Lt,
		.U_Lt     = .U_Ge,
		.U_Le     = .U_Gt,
		.U_Gt     = .U_Le,
		.U_Ge     = .U_Lt,
		.X64_Eq   = .Ne,
		.X64_Ne   = .Eq,
		.X64_Lt   = .Ge,
		.X64_Le   = .Gt,
		.X64_Gt   = .Le,
		.X64_Ge   = .Lt,
		.X64_U_Lt = .U_Ge,
		.X64_U_Le = .U_Gt,
		.X64_U_Gt = .U_Le,
		.X64_U_Ge = .U_Lt,
		.F_Eq     = .Ne,
		.F_Ne     = .Eq,
		.F_Lt     = .U_Le,
		.F_Le     = .U_Lt,
		.F_Gt     = .U_Le,
		.F_Ge     = .U_Lt,
	}

	@(static, rodata)
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

	scl := mem_op.scale
	idx := NO_INDEX
	if scl != 0 do idx = reg_of(ctx, node.inps[len(node.inps) - 1])
	imm_boundary := int(scl != 0)
	pfx: u8 = node.dt == .F64 ? 0xF2 : 0xF3

	switch node.xtype {
	case .Global:
	case .Local:
	case .Local_Addr, .Global_Addr:
		dst := reg_of(ctx, instr)
		addr, dis, id := reg_and_disp_of(ctx, node.inps[0])
		// lea $dst, [rsp/rip + $offset]
		emit(ctx.code, {rex(dst, RAX, RAX, true), 0x8d})
		emit_indirect_addr(ctx, dst, addr, NO_INDEX, 1, dis, id)
	case .X64_Lea:
		dst := reg_of(ctx, instr)
		bse, sdis, id := reg_and_disp_of(ctx, node.inps[0])
		dis := mem_op.dis

		// lea $dst, [$bse + $idx * $scl + $sdis + $dis]
		rx := rex(dst, bse, idx, true)
		emit(ctx.code, {rx, 0x8D})
		emit_indirect_addr(ctx, dst, bse, idx, scl, sdis + dis, id)
	case .Store, .X64_Store:
		bse, sdis, id := reg_and_disp_of(ctx, node.inps[2])
		dis := mem_op.dis
		dt := mem_op.dt

		if 3 + imm_boundary < len(node.inps) {
			vdt := graph_get(ctx, node.inps[3]).dt
			val := reg_of(ctx, node.inps[3])

			if vdt in FLOAT_DTS {
				// movss/movsd [$bse + ...], $val
				pfx: u8 = vdt == .F64 ? 0xF2 : 0xF3
				rx := rex(val, bse, idx, false)
				emit(ctx.code, {pfx, rx, 0x0f, 0x11})
				emit_indirect_addr(ctx, val, bse, idx, scl, dis + sdis, id)
				break
			}

			rx := rex(val, bse, idx, DT_SIZE[vdt] == 8)
			emit_sized_opcode(ctx.code, vdt, rx, 0x89)
			emit_indirect_addr(ctx, val, bse, idx, scl, dis + sdis, id)
		} else {
			imm := mem_op.imm
			rx := rex(RAX, bse, idx, DT_SIZE[dt] == 8)
			emit_sized_opcode(ctx.code, dt, rx, 0xC7)
			emit_indirect_addr(
				ctx,
				RAX,
				bse,
				idx,
				scl,
				dis + sdis,
				id,
				DT_SIZE[dt],
			)
			emit_imm_for_dt(ctx.code, dt, imm)
		}
	case .Load, .X64_Load, .Load_S:
		dt := node.dt
		bse, sdis, id := reg_and_disp_of(ctx, node.inps[2])
		val := reg_of(ctx, instr)
		dis := mem_op.dis
		signed := mem_op.signed || node.itype == .Load_S

		if dt in FLOAT_DTS {
			// movss/movsd $val, [$bse + ...]
			rx := rex(val, bse, idx, false)
			emit(ctx.code, {pfx, rx, 0x0f, 0x10})
			emit_indirect_addr(ctx, val, bse, idx, scl, dis + sdis, id)
			break
		}

		rx := rex(val, bse, idx, DT_SIZE[dt] == 8 || signed)
		if signed {
			#partial switch dt {
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
			#partial switch dt {
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

		emit_indirect_addr(ctx, val, bse, idx, scl, dis + sdis, id)
	case .Sext:
		dt := graph_get(ctx, node.inps[0]).dt
		dst := reg_of(ctx, instr)
		src := reg_of(ctx, node.inps[0])

		rx := rex(dst, src, RAX, true)
		#partial switch dt {
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
		#partial switch dt {
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
			rx := rex(cond, cond, RAX, DT_SIZE[cnode.dt] == 8)
			emit_sized_opcode(ctx.code, cnode.dt, rx, 0x85)
			emit(ctx.code, {mod_rm(.Direct, cond, cond)})
		}

		append(
			&ctx.local_relocs,
			Local_Reloc {
				dest = graph_get(ctx, node.outs[int(is_consecutive)].id).gvn -
				block_base,
				offset = u32(ctx.code.pos) + 2,
			},
		)

		op: X64_Node_Type = is_consecutive ? .Eq : .Ne
		if cnode.dt == .Void {
			// we do this anyway to normalize
			op = CMP_OP_REVERSE[cnode.xtype]
			if !is_consecutive {
				op = CMP_OP_REVERSE[op]
			}
		}

		emit(ctx.code, {0x0f, JCC_TABLE[op], 0, 0, 0, 0})

		if !is_consecutive do break

		fallthrough
	case .Always:
		fallthrough
	case .Jump:
		if is_consecutive do break

		// jmp
		append(
			&ctx.local_relocs,
			Local_Reloc {
				dest = graph_get(ctx, node.outs[0].id).gvn - block_base,
				offset = u32(ctx.code.pos) + 1,
			},
		)

		emit(ctx.code, {0xe9, 0, 0, 0, 0})
	case .Call:
		call := graph_extra(ctx, node, Call)

		cc := ctx.graph.cc_table[call.ccid]
		if cc.is_syscall {
			// syscall
			emit(ctx.code, {0x0F, 0x05})
		} else {
			// call $call.cid
			emit(ctx.code, {0xe8, 0, 0, 0, 0})
			add_reloc(ctx.relocs)^ = {
				offset = u32(ctx.code.pos - ctx.code_start),
				kind   = .Text,
				size   = .r4,
				id     = call.cid,
			}
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

		switch node.dt {
		case .Void:
			panic("")
		case .I8 ..= .I64:
			// mov $dst, $imm
			emit_single_op(ctx.code, 0xb8, dst)
			emit_anys(ctx.code, imm)
		case .F32, .F64:
			d_spill := dst.index >= GPA_REG_COUNT

			id: u32
			if node.dt == .F32 {
				id = emit_big_constant(ctx, f32(transmute(f64)imm))
			} else {
				id = emit_big_constant(ctx, transmute(f64)imm)
			}

			// movss/movsd $dst, [rsp + $src_off]
			emit(ctx.code, {pfx, rex(dst, RIP, RAX, false), 0x0f, 0x10})

			emit_indirect_addr(ctx, dst, RIP, NO_INDEX, 1, 0, id + 1)
		}
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
			dst, sdis, id := reg_and_disp_of(ctx, node.inps[2])
			dis := mem_op.dis

			op := OPCODE_TABLE[node.xtype]
			src := Reg(op.ext)
			if 3 + imm_boundary < len(node.inps) {
				op = DEST_MODE_OPCODE_TABLE[node.xtype]
				if !is_shift {
					src = reg_of(ctx, node.inps[3])
				}
			}

			tb: int = 0
			if 3 + imm_boundary >= len(node.inps) {
				tb = is_shift ? 1 : DT_SIZE[mem_op.dt]
			}

			// add/sub/and/or/xor [$dst + $idx * $scl + $sdis + $dis], $src/$imm
			rx := rex(src, dst, idx, DT_SIZE[mem_op.dt] == 8)
			emit_sized_opcode(ctx.code, mem_op.dt, rx, op.opcode)
			emit_indirect_addr(ctx, src, dst, idx, scl, dis + sdis, id, tb)

			if 3 + imm_boundary >= len(node.inps) {
				if is_shift {
					emit(ctx.code, {u8(imm)})
				} else {
					emit_imm_for_dt(ctx.code, mem_op.dt, imm)
				}
			}
		case .Src:
			dst := reg_of(ctx, node.inps[3])

			bse, sdis, id := reg_and_disp_of(ctx, node.inps[2])
			dis := mem_op.dis

			op := SRC_MODE_OPCODE_TABLE[node.xtype]

			// add/sub/and/or/xor $dst, [$bse + $sdis + $dis]
			rx := rex(dst, bse, idx, DT_SIZE[node.dt] == 8)
			emit_sized_opcode(ctx.code, node.dt, rx, op.opcode)
			emit_indirect_addr(ctx, dst, bse, idx, scl, dis + sdis, id)
		}
	case .Add ..= .Xor:
		// add/sub/and/or/xor $dst, $rhs
		dst := reg_of(ctx, node.inps[0])
		rhs := reg_of(ctx, node.inps[1])
		rx := rex(rhs, dst, RAX, DT_SIZE[node.dt] == 8)
		op := OPCODE_TABLE[node.xtype].opcode
		emit_sized_opcode(ctx.code, node.dt, rx, op)
		emit(ctx.code, {mod_rm(.Direct, rhs, dst)})
	case .Eq ..= .U_Ge, .X64_Eq ..= .X64_U_Ge:
		switch mem_op.mem_mode {
		case .Dest:
			bse, sdis, id := reg_and_disp_of(ctx, node.inps[2])
			dis := mem_op.dis
			op_dt := mem_op.dt

			// cmp [$bse + $idx * $scl + $sdis + $dis], $imm
			rx := rex(RAX, bse, idx, DT_SIZE[op_dt] == 8)
			emit_sized_opcode(ctx.code, op_dt, rx, 0x81)
			tb := DT_SIZE[op_dt]
			emit_indirect_addr(ctx, 0b111, bse, idx, scl, dis + sdis, id, tb)
			emit_imm_for_dt(ctx.code, op_dt, mem_op.imm)
		case .Src:
			lhs := reg_of(ctx, node.inps[3])

			bse, sdis, id := reg_and_disp_of(ctx, node.inps[2])
			dis := mem_op.dis

			// cmp $dst, [$bse + $idx * $scl + $sdis + $dis]
			rx := rex(lhs, bse, idx, DT_SIZE[mem_op.dt] == 8)
			emit_sized_opcode(ctx.code, mem_op.dt, rx, 0x3b)
			emit_indirect_addr(ctx, lhs, bse, idx, scl, dis + sdis, id)
		case .None:
			lhs := reg_of(ctx, node.inps[0])
			op_dt := graph_get(ctx, node.inps[0]).dt
			if 1 < len(node.inps) {
				// cmp $lhs, $rhs
				rhs := reg_of(ctx, node.inps[1])
				rx := rex(lhs, rhs, RAX, DT_SIZE[op_dt] == 8)
				emit_sized_opcode(ctx.code, op_dt, rx, 0x3b)
				emit(ctx.code, {mod_rm(.Direct, lhs, rhs)})
			} else {
				// cmp $lhs, $imm
				rx := rex(RAX, lhs, RAX, DT_SIZE[op_dt] == 8)
				emit_sized_opcode(ctx.code, op_dt, rx, 0x81)
				emit(ctx.code, {mod_sm(.Direct, 0b111, lhs)})
				emit_imm_for_dt(ctx.code, op_dt, mem_op.imm)
			}
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
		rx := rex(RAX, dst, RAX, DT_SIZE[node.dt] == 8)
		emit_sized_opcode(ctx.code, node.dt, rx, 0xf7)
		emit(ctx.code, {mod_sm(.Direct, 0b010, dst)})
		// and $dst, $lhs
		rx = rex(lhs, dst, RAX, DT_SIZE[node.dt] == 8)
		emit_sized_opcode(ctx.code, node.dt, rx, 0x21)
		emit(ctx.code, {mod_rm(.Direct, lhs, dst)})
	case .Shl ..= .U_Shr:
		// shl/shr $dst, cl
		dst := reg_of(ctx, node.inps[0])
		rx := rex(RAX, dst, RAX, DT_SIZE[node.dt] == 8)
		op := OPCODE_TABLE[node.xtype].ext
		emit_sized_opcode(ctx.code, node.dt, rx, 0xd3)
		emit(ctx.code, {mod_sm(.Direct, op, dst)})
	case .X64_Neg ..= .X64_Not:
		assert(mem_op.mem_mode == .Dest)
		dis := mem_op.dis
		dst, sdis, id := reg_and_disp_of(ctx, node.inps[2])

		op := DEST_MODE_OPCODE_TABLE[node.xtype]

		// neg/not [$dst + $idx * $scl + $sdis + $dis]
		rx := rex(RAX, dst, idx, DT_SIZE[mem_op.dt] == 8)
		emit_sized_opcode(ctx.code, mem_op.dt, rx, op.opcode)
		emit_indirect_addr(ctx, op.ext, dst, idx, scl, dis + sdis, id)
	case .Neg ..= .Not:
		// neg/not $dst
		dst := reg_of(ctx, node.inps[0])
		op := OPCODE_TABLE[node.xtype]
		rx := rex(RAX, dst, RAX, DT_SIZE[node.dt] == 8)
		emit_sized_opcode(ctx.code, node.dt, rx, op.opcode)
		emit(ctx.code, {mod_sm(.Direct, op.ext, dst)})
	case .Mul:
		dst := reg_of(ctx, node.inps[0])
		rhs := reg_of(ctx, node.inps[1])

		// imul $dst, $rhs
		rx := rex(dst, rhs, RAX, DT_SIZE[node.dt] == 8)
		emit_extended_sized_opcode(ctx.code, node.dt, rx, 0xaf)
		emit(ctx.code, {mod_rm(.Direct, dst, rhs)})
	case .X64_Mul:
		dst := reg_of(ctx, instr)
		lhs := reg_of(ctx, node.inps[0])
		imm := mem_op.imm

		// imul $dst, $lhs, $imm
		rx := rex(dst, lhs, RAX, DT_SIZE[node.dt] == 8)
		emit_sized_opcode(ctx.code, node.dt, rx, 0x69)
		emit(ctx.code, {mod_rm(.Direct, dst, lhs)})
		emit_imm_for_dt(ctx.code, node.dt, imm)
	case .X64_Mul8:
		// imul $op
		dst := reg_of(ctx, node.inps[0])
		emit(ctx.code, {0xf6, mod_sm(.Direct, 0b101, dst)})
	case .F_Add, .F_Sub, .F_Mul, .F_Div:
		// dst == lhs (in place); op dst, rhs
		dst := reg_of(ctx, node.inps[0])
		rhs := reg_of(ctx, node.inps[1])

		@(static, rodata)
		FLOAT_OP := #partial [X64_Node_Type]u8 {
			.F_Add = 0x58,
			.F_Sub = 0x5C,
			.F_Mul = 0x59,
			.F_Div = 0x5E,
		}

		rx := rex(dst, rhs, RAX, false)
		emit(
			ctx.code,
			{pfx, rx, 0x0f, FLOAT_OP[node.xtype], mod_rm(.Direct, dst, rhs)},
		)
	case .F_Eq ..= .F_Ge:
		// ucomiss/ucomisd $lhs, $rhs
		lhs := reg_of(ctx, node.inps[0])
		rhs := reg_of(ctx, node.inps[1])
		odt := graph_get(ctx, node.inps[0]).dt

		a, b := lhs, rhs
		setcc: u8 = OPCODE_TABLE[node.xtype].opcode
		#partial switch node.xtype {
		case .F_Lt, .F_Le:
			a, b = rhs, lhs
		}

		// [66] 0F 2E /r  (ucomisd needs the 0x66 prefix, ucomiss none)
		if odt == .F64 do emit(ctx.code, {0x66})
		rx := rex(a, b, RAX, false)
		emit(ctx.code, {rx, 0x0f, 0x2e, mod_rm(.Direct, a, b)})

		if node.dt != .Void {
			dst := reg_of(ctx, instr)
			// setcc $dst
			rxs := rex(RAX, dst, RAX, true)
			emit(ctx.code, {rxs, 0x0F, setcc, mod_sm(.Direct, 0b000, dst)})
			// movzx $dst, $dst
			rxz := rex(dst, dst, RAX, true)
			emit(ctx.code, {rxz, 0x0F, 0xB6, mod_rm(.Direct, dst, dst)})
		}
	case .F_From_I:
		// cvtsi2ss/cvtsi2sd $dst(xmm), $src(gpr)
		dst := reg_of(ctx, instr)
		src := reg_of(ctx, node.inps[0])
		sdt := graph_get(ctx, node.inps[0]).dt
		rx := rex(dst, src, RAX, DT_SIZE[sdt] == 8)
		emit(ctx.code, {pfx, rx, 0x0f, 0x2a, mod_rm(.Direct, dst, src)})
	case .F_To_I:
		// cvttss2si/cvttsd2si $dst(gpr), $src(xmm)
		dst := reg_of(ctx, instr)
		src := reg_of(ctx, node.inps[0])
		sdt := graph_get(ctx, node.inps[0]).dt
		pfx: u8 = sdt == .F64 ? 0xF2 : 0xF3
		rx := rex(dst, src, RAX, DT_SIZE[node.dt] == 8)
		emit(ctx.code, {pfx, rx, 0x0f, 0x2c, mod_rm(.Direct, dst, src)})
	case .F_Ext, .F_Demote:
		// cvtss2sd $dst, $src (f32 -> f64)
		dst := reg_of(ctx, instr)
		src := reg_of(ctx, node.inps[0])
		rx := rex(dst, src, RAX, false)
		pfx: u8 = node.dt == .F64 ? 0xF3 : 0xF2
		emit(ctx.code, {pfx, rx, 0x0f, 0x5a, mod_rm(.Direct, dst, src)})
	case .Div, .Rem:
		rhs := reg_of(ctx, node.inps[1])
		#partial switch node.dt {
		case .Void:
			panic("")
		case .I8:
			// cbw
			emit(ctx.code, {0x66, 0x98})
		case .I16:
			// cwd
			emit(ctx.code, {0x66, 0x99})
		case .I32:
			// cdq
			emit(ctx.code, {0x99})
		case .I64:
			// cqo
			emit(ctx.code, {0x48, 0x99})
		}

		// idiv $rhs
		rx := rex(RAX, rhs, RAX, DT_SIZE[node.dt] == 8)
		emit_sized_opcode(ctx.code, node.dt, rx, 0xf7)
		emit(ctx.code, {mod_sm(.Direct, 0b111, rhs)})
		if node.itype == .Rem && node.dt == .I8 {
			// movzx edx, ah
			emit(ctx.code, {0x0F, 0xB6, 0xD4})
		}
	case .U_Div, .U_Rem:
		rhs := reg_of(ctx, node.inps[1])
		if node.dt != .I8 {
			// xor rdx, rdx
			rx := rex(RDX, RDX, RAX, true)
			emit(ctx.code, {rx, 0x31, mod_rm(.Direct, RDX, RDX)})
		} else {
			// movzx ax, al
			emit(ctx.code, {0x0F, 0xB6, 0xC0})
		}
		// div $rhs
		rx := rex(RAX, rhs, RAX, DT_SIZE[node.dt] == 8)
		emit_sized_opcode(ctx.code, node.dt, rx, 0xf7)
		emit(ctx.code, {mod_sm(.Direct, 0b110, rhs)})
		if node.itype == .U_Rem && node.dt == .I8 {
			// movsx edx, ah
			emit(ctx.code, {0x0F, 0xBE, 0xD4})
		}
	case .Split:
		dst := reg_of(ctx, instr)
		src := reg_of(ctx, node.inps[0])
		dst_off := spill_slot_offset(ctx, dst)
		src_off := spill_slot_offset(ctx, src)
		assert(dst.kind == src.kind)

		if dst.kind == .Vector {
			// movss/movsd based moves for xmm live ranges
			pfx: u8 = node.dt == .F64 ? 0xF2 : 0xF3
			d_spill := dst.index >= GPA_REG_COUNT
			s_spill := src.index >= GPA_REG_COUNT
			if d_spill && s_spill {
				// pure memory-to-memory move: copy the 8-byte spill slot via
				// the stack with push/pop, which never touches an xmm register.
				// (slots are 8-byte sized, so this is correct for f32 too.)
				// push [rsp + $src_off]
				emit(ctx.code, {0xff})
				spill_indirect_addr(ctx, Reg(0b110), src_off)
				// pop [rsp + $dst_off]
				emit(ctx.code, {0x8F})
				spill_indirect_addr(ctx, Reg(0b000), dst_off)
			} else if d_spill {
				// movss/movsd [rsp + $dst_off], $src
				emit(ctx.code, {pfx, rex(src, RSP, RAX, false), 0x0f, 0x11})
				spill_indirect_addr(ctx, src, dst_off)
			} else if s_spill {
				// movss/movsd $dst, [rsp + $src_off]
				emit(ctx.code, {pfx, rex(dst, RSP, RAX, false), 0x0f, 0x10})
				spill_indirect_addr(ctx, dst, src_off)
			} else {
				// movss/movsd $dst, $src
				emit(
					ctx.code,
					{
						pfx,
						rex(dst, src, RAX, false),
						0x0f,
						0x10,
						mod_rm(.Direct, dst, src),
					},
				)
			}
			break
		}

		if int(dst) >= 16 && int(src) >= 16 {
			// push [rsp + $src_offset]
			emit(ctx.code, {0xff})
			spill_indirect_addr(ctx, Reg(0b110), src_off)
			// pop [rsp + $dst_off]
			emit(ctx.code, {0x8F})
			spill_indirect_addr(ctx, Reg(0b000), dst_off)
		} else if int(dst) >= 16 {
			// mov [rsp + $dst_offset], $src
			fmt.assertf(int(src) < 16, "%v", node.node)

			emit(ctx.code, {rex(src, RSP, RAX, true), 0x89})
			spill_indirect_addr(ctx, src, dst_off)
		} else if int(src) >= 16 {
			// mov $dst, [rsp + $src_offset]

			emit(ctx.code, {rex(dst, RSP, RAX, true), 0x8b})
			spill_indirect_addr(ctx, dst, src_off)
		} else {
			// mov $dst, $src
			rx := rex(src, dst, RAX, true)
			emit(ctx.code, {rx, 0x89, mod_rm(.Direct, src, dst)})
		}

		spill_indirect_addr :: proc(ctx: ^Ctx, reg: Reg, off: i32) {
			emit_indirect_addr(ctx, reg, RSP, NO_INDEX, 1, off, 0)
		}

		spill_slot_offset :: proc(ctx: ^Ctx, reg: Reg) -> i32 {
			if reg.index < GPA_REG_COUNT do return 0

			param_count := len(ctx.stack_param_offset[reg.kind])
			if int(reg.index - GPA_REG_COUNT) < param_count {
				return(
					ctx.stack_param_offset[reg.kind][reg.index - GPA_REG_COUNT] \
				)
			}
			return(
				ctx.spill_slot_base[reg.kind] +
				(i32(reg.index) - i32(param_count) - GPA_REG_COUNT) * 8 \
			)
		}
	case .Return:
		if ctx.stack_size != 0 {
			// sub rsp, -$ctx.stack_size
			emit_imm_op(ctx.code, 0x81, 0b000, RSP, ctx.stack_size)
		}

		#reverse for reg in ctx.callee_saved[.General] {
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

reg_and_disp_of :: proc(
	ctx: Codegen_Emit_Ctx,
	id: Node_ID,
) -> (
	Reg,
	i32,
	u32,
) {
	node := graph_get(ctx, id)
	if node.itype == .Global {
		// bias by one so that global 0 is distinguishable from the "no
		// relocation" sentinel used by emit_indirect_addr
		return RIP, 0, graph_extra(ctx, node, Tup).idx + 1
	}
	if node.itype == .Local {
		return RSP, i32(graph_extra(ctx, node, Local).offset), 0
	}
	return ctx.allocs[node.gvn], 0, 0
}

emit_single_op :: proc(code: ^arna.Allocator, op_base: u8, dst: Reg) {
	emit(code, {rex(RAX, dst, RAX, true), op_base + u8(dst.index & 0b111)})
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

emit_indirect_addr :: proc {
	emit_indirect_addr_reg,
	emit_indirect_addr_op,
}

emit_indirect_addr_op :: #force_inline proc(
	ctx: ^Ctx,
	op: u8,
	base: Reg,
	index: Reg,
	#any_int scale: u64,
	#any_int dis: i64,
	reloc: u32,
	#any_int tb: i64 = 0,
) {
	emit_indirect_addr(ctx, Reg(op), base, index, scale, dis, reloc, tb)
}

emit_indirect_addr_reg :: proc(
	ctx: ^Ctx,
	reg: Reg,
	base: Reg,
	index: Reg,
	#any_int scale: u64,
	#any_int dis: i64,
	reloc: u32,
	#any_int trailing_imm: i64 = 0,
) {
	scl := max(scale, 1)
	timm := min(trailing_imm, 4)

	mod := mod_from_dis(dis)

	assert(mod != .Direct)

	ill_base := base == RSP || base == R12

	rip_relative := reloc != 0
	if rip_relative {
		assert(base == RIP)
		mod = .Indirect
	} else if mod == .Indirect && (base == R13 || base == RBP) {
		mod = .Indirect_Disp8
	}

	if index != NO_INDEX || ill_base || scl != 1 {
		emit(ctx.code, {mod_rm(mod, reg, RSP), sib(base, index, scl)})
	} else {
		emit(ctx.code, {mod_rm(mod, reg, base)})
	}

	switch mod {
	case .Indirect:
		if rip_relative do emit_anys(ctx.code, u32(dis - timm))
	case .Indirect_Disp8:
		emit(ctx.code, {u8(dis)})
	case .Indirect_Disp32:
		emit_anys(ctx.code, u32(dis))
	case .Direct:
		fallthrough
	case:
		panic("unreachable")
	}

	if reloc != 0 {
		add_reloc(ctx.relocs)^ = {
			offset = u32(ctx.code.pos - ctx.code_start),
			kind   = .Global,
			size   = .r4,
			id     = reloc - 1,
		}
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

	rx := rex(dst, RAX, RAX, true)
	emit(code, {rx, op + 2 * u8(is_small_imm), mod_rm(.Direct, Reg(mod), dst)})

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
	#partial switch dt {
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

emit_extended_sized_opcode :: proc(
	code: ^arna.Allocator,
	dt: Node_Datatype,
	rx: u8,
	op: u8,
) {
	#partial switch dt {
	case .Void:
		panic("")
	case .I8:
		emit(code, {rx, 0x0f, op - 1})
	case .I16:
		emit(code, {0x66, rx, 0x0f, op})
	case .I32, .I64:
		emit(code, {rx, 0x0f, op})
	}
}

emit_sized_opcode :: proc(
	code: ^arna.Allocator,
	dt: Node_Datatype,
	rx: u8,
	op: u8,
) {
	#partial switch dt {
	case .Void:
		panic("")
	case .I8:
		emit(code, {rx, op - 1})
	case .I16:
		emit(code, {0x66, rx, op})
	case .I32, .I64:
		emit(code, {rx, op})
	}
}
