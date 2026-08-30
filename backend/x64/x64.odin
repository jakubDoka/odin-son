package x64

import backend ".."
import "../../vendored/gam/util/arna"
import "../../vendored/gam/util/bit_arr"
import "base:intrinsics"
import "core:fmt"
import "core:math"
import "core:mem"
import "core:reflect"
import "core:slice"
import "core:sort"

Reg :: backend.Reg
emit :: backend.emit
graph_expand :: backend.graph_expand
graph_get :: backend.graph_get

xtype :: #force_inline proc(node: backend.Expanded_Node) -> X64_Node_Type {
	return X64_Node_Type(node.rtype)
}

// mirrors backend.graph_extra, but resolved against this package's own
// (generated) inherit_idx_of, since that generic proc's body is bound to
// whichever package declares it and backend's copy knows nothing about
// X64-only extra-data types such as X64_Mem_Op
x64_extra :: #force_inline proc(
	graph: ^backend.Graph,
	node: ^backend.Node,
	$T: typeid,
) -> ^T {
	if graph.inheritance_table[node.rtype] & (1 << inherit_idx_of(T)) == 0 {
		return nil
	}
	return (^T)(&node.extra)
}

NOOP_REX :: 0b0100_0000

NO_INDEX :: RSP

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
MASK_SIZE :: backend.MASK_SIZE

// DWARF numbers the x86-64 general purpose registers in a different order than
// the instruction encoding does, so the two have to be mapped explicitly.
@(rodata)
DWARF_GPR := [GPA_REG_COUNT]u8 {
	0,
	2,
	1,
	3,
	7,
	6,
	4,
	5,
	8,
	9,
	10,
	11,
	12,
	13,
	14,
	15,
}

X64_CFI_SPEC :: backend.Cfi_Spec {
	cfa_reg            = 7, // rsp
	return_addr_reg    = 16,
	initial_cfa_offset = 8,
	code_align         = 1,
	data_align         = -8,
}

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
X64_SYSTEMV_CC := backend.Call_Conv {
	name = "X64_SYSTEMV_CC",
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
	cfi_spec = X64_CFI_SPEC,
}

@(rodata)
X64_LINUX_SYSCALL_CC := backend.Call_Conv {
	name = "X64_LINUX_SYSCALL_CC",
	callee_saved = #partial{
		.General = {RBX, RDX, RDI, RSI, RBP, R8, R9, R10, R12, R13, R14, R15},
	},
	caller_saved = #partial{.General = {RAX, RCX, R11}},
	args = #partial{.General = {RAX, RDI, RSI, RDX, R10, R8, R9}},
	rets = #partial{.General = {RAX}},
	is_syscall = true,
	cfi_spec = X64_CFI_SPEC,
}

Instr_Info :: struct {
	opcode: u8,
	ext:    u8,
}

GEN_SPEC :: #config(X64_GEN_SPEC, false)

COMMAND :: "odin run backend/x64 -define:X64_GEN_SPEC=true"

SPEC_NOT_PRESENT :: (#load("node_specs.odin", string) or_else "") == ""

when SPEC_NOT_PRESENT {
	Reg_Kind :: backend.Reg_Kind

	inherit_idx_of :: proc($T: typeid) -> u8 {return 0}

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
		X64_F_Add,
		X64_F_Sub,
		X64_F_Mul,
		X64_F_Div,
		X64_F_Eq,
		X64_F_Ne,
		X64_F_Le,
		X64_F_Lt,
		X64_F_Gt,
		X64_F_Ge,
		X64_Shl,
		X64_Shr,
		X64_U_Shr,
		X64_Mul,
		X64_Lea,
		X64_Load,
		X64_Store,
		X64_CLoad,
		X64_Neg,
		X64_Not,
		X64_Mul8,
		X64_Fma_213,
		X64_Pcmpeq,
		X64_Pshufd,
		X64_Psadbw,
		X64_Pshufb,
		X64_Pextr,
	}

	X64_SIMPLE_BIN_OP_SPEC :: backend.Class_Spec {
		id      = X64_Mem_Op,
		no_ctor = true,
	}

	X64_SIMPLE_SHIFT_OP_SPEC :: backend.Class_Spec {
		id      = X64_Mem_Op,
		no_ctor = true,
	}

	X64_SIMPLE_UN_OP_SPEC :: backend.Class_Spec {
		id      = X64_Mem_Op,
		no_ctor = true,
	}

	@(rodata)
	X64_CLASSES := [X64_Node_Type]backend.Class_Spec {
		.X64_Add ..= .X64_U_Ge = X64_SIMPLE_BIN_OP_SPEC,
		.X64_Shl ..= .X64_U_Shr = X64_SIMPLE_SHIFT_OP_SPEC,
		.X64_Neg ..= .X64_Not = X64_SIMPLE_UN_OP_SPEC,
		.X64_F_Eq ..= .X64_F_Ge = X64_SIMPLE_BIN_OP_SPEC,
		.X64_Pcmpeq = {no_ctor = true},
		.X64_Psadbw = {args = {"lhs", "rhs"}},
		.X64_Pshufd = {id = X64_Mem_Op, no_ctor = true},
		.X64_Pshufb = {id = X64_Mem_Op, no_ctor = true},
		.X64_Pextr = {id = X64_Mem_Op, no_ctor = true},
		.X64_Mul = X64_SIMPLE_BIN_OP_SPEC,
		.X64_Lea = {id = X64_Mem_Op, no_ctor = true},
		.X64_Load = {id = X64_Mem_Op, flags = {.Load}, no_ctor = true},
		.X64_CLoad = {flags = {.Clonable}, no_ctor = true},
		.X64_Store = {id = X64_Mem_Op, flags = {.Store}, no_ctor = true},
		.X64_Mul8 = {no_ctor = true},
		.X64_F_Add ..= .X64_F_Div = {id = X64_Mem_Op, no_ctor = true},
		.X64_Fma_213 = {id = X64_Mem_Op, no_ctor = true},
	}

	when !GEN_SPEC {
		#panic("Missing generated files, run `" + COMMAND + "`")
	}
} else {
	@(rodata)
	X64_CLASSES := [X64_Node_Type]backend.Class_Spec{}
}

@(rodata)
SPILL_SLOT_SIZE := [Reg_Kind]i32 {
	.General = 8,
	.Vector  = 16,
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
	using mt: bit_field u8 {
		signed:   bool                  | 1,
		mem_mode: Mem_Mode              | 2,
		dt:       backend.Node_Datatype | 4,
	},
	aux:      u8,
}

BIN_OP_OFFSET :: transmute(u16)(i16(X64_Node_Type.X64_Add) -
	i16(backend.Ideal_Node_Type.Add))

UN_OP_OFFSET :: transmute(u16)(i16(X64_Node_Type.X64_Neg) -
	i16(backend.Ideal_Node_Type.Neg))

FLOAT_BIN_OP_OFFSET :: transmute(u16)(i16(X64_Node_Type.X64_F_Add) -
	i16(backend.Ideal_Node_Type.F_Add))

x64_peep :: proc(
	ctx: backend.Peep_Ctx,
	node: backend.Expanded_Node,
	_: $T,
) -> backend.Node_ID {
	node := node

	id := backend.graph_id(ctx, node)

	rhs_const: ^backend.CInt
	val_const: ^backend.CInt

	slots := [2]^^backend.CInt{&rhs_const, &val_const}
	idxs := [2]int{1, 3}

	for idx, i in idxs {
		slot := slots[i]
		if idx < len(node.inps) {
			slot^ = backend.graph_extra(ctx, node.inps[idx], backend.CInt)
			if slot^ != nil {
				clamped := i64(i32(slot^.value))
				nd := graph_get(ctx, node.inps[idx])
				if clamped != slot^.value || nd.dt >= .F64 {slot^ = nil}
			}
		}
	}

	base, index: backend.Node_ID
	scale: i32
	displacement: i32
	stack_base: bool

	has_own_index :=
		(xtype(node) == .X64_Store || xtype(node) == .X64_Load) &&
		x64_extra(ctx, node, X64_Mem_Op).scale != 0

	if 2 < len(node.inps) {
		nbase, ndisplacement := backend.base_and_offset(
			ctx,
			node.inps[2],
			x64_addr_add_offset,
		)
		if int(i32(ndisplacement)) == ndisplacement {
			base, displacement = nbase, i32(ndisplacement)
		}

		bnode := graph_expand(ctx, nbase)
		if xtype(bnode) == .X64_Lea {
			mem_op := x64_extra(ctx, bnode, X64_Mem_Op)
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
		} else if bnode.itype == .Global_Addr && index == 0 && !has_own_index {
			base = bnode.inps[0]
			stack_base = true
		} else {
			stack_base =
				bnode.itype == .Local || (bnode.itype == .Global && index == 0)
		}
	}

	mem_op := x64_extra(ctx, node, X64_Mem_Op)

	#partial matchx: switch xtype(node) {
	case .CInt:
		cnst: ^backend.CInt = backend.graph_extra(ctx, node, backend.CInt)
		if node.dt in backend.FLOAT_DTS && cnst.value != 0 {
			global := backend.graph_add_global(ctx, "iglb")
			tup: ^backend.Tup = backend.graph_extra(ctx, global, backend.Tup)
			tup.is_inline = true
			tup.align = backend.DT_SIZE[node.dt]
			tup.size = backend.DT_SIZE[node.dt]

			if node.dt == .F32 {
				arna.clone(ctx.mem, reflect.as_bytes(f32(cnst.fvalue)))
			} else {
				assert(node.dt == .F64)
				arna.clone(ctx.mem, reflect.as_bytes(cnst.fvalue))
			}

			graph_get(ctx, global).extra_dwords = u32(
				backend.DT_SIZE[node.dt] / backend.PRECISION,
			)

			backend.graph_push_tag(ctx, backend.graph_get_tag(ctx, id))
			return backend.graph_add_raw(
				ctx,
				u16(X64_Node_Type.X64_CLoad),
				node.dt,
				{global},
			)
		}
	case .Splat:
		inp := graph_expand(ctx, node.inps[0])
		assert(inp.dt == .I8)

		vec := backend.graph_add_un_op(ctx, "elem", .Cast, .V128, node.inps[0])
		zero := backend.graph_add_c_int(ctx, "zro", node.dt, 0)

		pnode, pshufb := x64_add_node(
			ctx,
			"pshufb",
			.X64_Pshufb,
			node.dt,
			{vec, zero},
		)
		pnode.lane = node.lane

		return pshufb
	case .Simd_Reduce_Add_Bisect:
		inp := graph_expand(ctx, node.inps[0])
		assert(inp.dt == .V128)

		#partial switch node.lane {
		case .I8:
			_, pshufd := x64_add_node(
				ctx,
				"pshufd",
				.X64_Pshufd,
				inp.dt,
				{node.inps[0]},
				{aux = 0b11101110},
			)

			add := backend.graph_add_bin_op(
				ctx,
				"radd",
				.Add,
				inp.dt,
				pshufd,
				node.inps[0],
			)
			graph_get(ctx, add).lane = node.lane
			zero := backend.graph_add_c_int(ctx, "zro", inp.dt, 0)

			psadbw := graph_add_x64_psadbw(ctx, "psadbw", inp.dt, add, zero)
			graph_get(ctx, psadbw).lane = node.lane

			return backend.graph_add_un_op(ctx, "sum", .Cast, .I16, psadbw)
		case .I16:
			_, pshufd := x64_add_node(
				ctx,
				"pshufd",
				.X64_Pshufd,
				inp.dt,
				{node.inps[0]},
				{aux = 0b11101110},
			)

			add := backend.graph_add_bin_op(
				ctx,
				"radd",
				.Add,
				inp.dt,
				pshufd,
				node.inps[0],
			)
			graph_get(ctx, add).lane = node.lane

			_, pshufd2 := x64_add_node(
				ctx,
				"pshufd",
				.X64_Pshufd,
				inp.dt,
				{node.inps[0]},
				{aux = 0b01010101},
			)

			add2 := backend.graph_add_bin_op(
				ctx,
				"radd",
				.Add,
				inp.dt,
				pshufd2,
				add,
			)
			graph_get(ctx, add).lane = node.lane

			_, lhs := x64_add_node(
				ctx,
				"pextrw",
				.X64_Pextr,
				node.dt,
				{add2},
				{aux = 1},
			)
			rhs := backend.graph_add_un_op(ctx, "rhs", .Cast, node.dt, add2)
			return backend.graph_add_bin_op(
				ctx,
				"sum",
				.Add,
				node.dt,
				lhs,
				rhs,
			)
		case .I32:
			_, pshufd := x64_add_node(
				ctx,
				"pshufd",
				.X64_Pshufd,
				inp.dt,
				{node.inps[0]},
				{aux = 0b11101110},
			)

			add := backend.graph_add_bin_op(
				ctx,
				"radd",
				.Add,
				inp.dt,
				pshufd,
				node.inps[0],
			)
			graph_get(ctx, add).lane = node.lane

			_, lhs := x64_add_node(
				ctx,
				"pextrd",
				.X64_Pextr,
				node.dt,
				{add},
				{aux = 1},
			)
			rhs := backend.graph_add_un_op(ctx, "rhs", .Cast, node.dt, add)
			return backend.graph_add_bin_op(
				ctx,
				"sum",
				.Add,
				node.dt,
				lhs,
				rhs,
			)
		case .I64:
			_, lhs := x64_add_node(
				ctx,
				"pextrq",
				.X64_Pextr,
				node.dt,
				{node.inps[0]},
				{aux = 1},
			)
			rhs := backend.graph_add_un_op(
				ctx,
				"rhs",
				.Cast,
				.I64,
				node.inps[0],
			)
			return backend.graph_add_bin_op(
				ctx,
				"sum",
				.Add,
				node.dt,
				lhs,
				rhs,
			)
		case:
			fmt.panicf("TODO: %v", node.lane)
		}

		if node.lane == .I8 {
		}
	case .F_Add:
		lhs := graph_expand(ctx, node.inps[0])
		rhs := graph_expand(ctx, node.inps[1])

		if rhs.itype == .F_Mul {
			lhs, rhs = rhs, lhs
		}

		rhs_id := backend.graph_id(ctx, rhs)

		if lhs.itype == .F_Mul {
			return x64_make_node(
				ctx,
				id,
				u16(X64_Node_Type.X64_Fma_213),
				{lhs.inps[0], lhs.inps[1], rhs_id},
				{},
			)
		}
	case .Add ..= .Xor, .Eq ..= .U_Ge, .Shl ..= .U_Shr, .Mul:
		op := u16(node.itype) + BIN_OP_OFFSET

		if node.dt == .I8 && node.itype == .Mul {
			node.rtype = u16(X64_Node_Type.X64_Mul8)
			return id
		}

		if node.dt == .V128 && node.itype == .Eq {
			node.rtype = u16(X64_Node_Type.X64_Pcmpeq)
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

			if xtype(rhs) == .X64_Mul {
				ascale = x64_extra(ctx, rhs, X64_Mem_Op).imm
				aindex = rhs.inps[0]
			} else if rhs.itype == .Mul {
				arhs_const := backend.graph_extra(
					ctx,
					rhs.inps[1],
					backend.CInt,
				)
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

			abase, offset := backend.base_and_offset(
				ctx,
				node.inps[0],
				x64_addr_add_offset,
			)
			if int(i32(offset)) == offset {
				displacement = i32(offset)
			}

			bnode := graph_expand(ctx, abase)
			if bnode.itype == .Local_Addr {
				abase = bnode.inps[0]
				stack_base = true
			}

			if ascale == 1 && !stack_base && displacement == 0 {
				break indexify
			}

			return x64_make_node(
				ctx,
				id,
				u16(X64_Node_Type.X64_Lea),
				{abase, aindex},
				{scale = u8(ascale), dis = displacement},
			)
		}
	case .F_Eq ..= .F_Ge:
		if node.dt != .Void &&
		   len(node.outs) == 1 &&
		   graph_get(ctx, node.outs[0].id).itype == .If {
			node.dt = .Void
			return id
		}
	case .Load:
		load_inps := [4]backend.Node_ID {
			node.inps[0],
			node.inps[1],
			base,
			index,
		}
		res := x64_make_node(
			ctx,
			id,
			u16(X64_Node_Type.X64_Load),
			load_inps[:3 + int(scale != 0)],
			{dis = displacement, scale = u8(scale), dt = node.dt},
		)

		backend.worklist_add(ctx, ctx.worklist, res)
		return res
	case .Store:
		immediate: i32
		inps := [5]backend.Node_ID {
			node.inps[0],
			node.inps[1],
			base,
			node.inps[3],
			index,
		}
		count := 4
		vl := graph_get(ctx, node.inps[3])
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
				dt = vl.dt,
			},
		)

		backend.worklist_add(ctx, ctx.worklist, res)
		return res
	case .Sext, .Uext:
		inp := graph_get(ctx, node.inps[0])
		if backend.DT_SIZE[inp.dt] >= backend.DT_SIZE[node.dt] {
			return node.inps[0]
		}
	case .X64_Store, .X64_Load:
		changed := false

		if scale != 0 && mem_op.scale != 0 {
			break matchx
		}

		if scale != 0 {
			backend.graph_connect(ctx, id, index)
			mem_op.scale = u8(scale)
			node = graph_expand(ctx, id)
			changed = true
		}

		swap_out_imm :: proc(
			ctx: backend.Peep_Ctx,
			node: backend.Expanded_Node,
		) {
			id := backend.graph_id(ctx, node)
			outs := backend.graph_outs(ctx, node.inps[4])
			oi :=
				slice.linear_search(
					outs,
					backend.Node_Output{idx = 4, id = id},
				) or_else panic("")
			outs[oi].idx = 3
			node.inps[3], node.inps[4] = node.inps[4], node.inps[3]
		}

		mem_op.dis += displacement

		changed |= node.inps[2] != base
		backend.graph_set_input(ctx, id, 2, base)

		widen_load: if xtype(node) == .X64_Load && node.dt < .I64 {
			dominant: backend.Ideal_Node_Type
			for out in node.outs {
				onode := graph_get(ctx, out.id)
				if dominant != {} {
					if dominant != onode.itype do break widen_load
				}
				dominant = onode.itype
			}
			if dominant == .Sext || dominant == .Uext {
				mem_op.dt = node.dt
				node.dt = .I64
				mem_op.signed = dominant == .Sext
				changed = true
			}
		}

		if xtype(node) == .X64_Store &&
		   3 + int(mem_op.scale != 0) < len(node.inps) {
			val := graph_expand(ctx, node.inps[3])
			val_mem := x64_extra(ctx, val, X64_Mem_Op)

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

			IDEAL_TRIGGER_OPS :: bit_set[backend.Ideal_Node_Type] {
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

			IDEAL_TRIGGER_UN_OPS :: bit_set[backend.Ideal_Node_Type] {
				.Not,
				.Neg,
			}

			is_interesting :=
				((xtype(val) in X64_TRIGGER_OPS && len(val.inps) == 1) ||
					val.itype in IDEAL_TRIGGER_OPS)

			is_interesting &= val.dt != .V128

			if is_interesting && len(val.outs) == 1 {
				lhs := graph_expand(ctx, val.inps[0])
				lhs_mem := x64_extra(ctx, lhs, X64_Mem_Op)
				dest_op: if xtype(lhs) == .X64_Load &&
				   lhs.inps[1] == node.inps[1] &&
				   lhs.inps[2] == node.inps[2] &&
				   lhs_mem.scale == mem_op.scale &&
				   (lhs_mem.scale == 0 ||
						   lhs.inps[len(lhs.inps) - 1] ==
							   node.inps[len(node.inps) - 1]) &&
				   lhs_mem.dis == mem_op.dis {

					needs_removal :=
						xtype(val) in X64_TRIGGER_OPS ||
						val.itype in IDEAL_TRIGGER_UN_OPS

					rm_idx := 3 + int(lhs_mem.scale != 0)
					if lhs_mem.scale != 0 && needs_removal {
						swap_out_imm(ctx, node)
					}

					node.rtype = val.rtype

					if val.itype in IDEAL_TRIGGER_UN_OPS {
						assert(node.rtype < len(backend.IDEAL_CLASSES))
						node.rtype += UN_OP_OFFSET
					} else if xtype(val) in X64_TRIGGER_OPS {
						mem_op.imm = val_mem.imm
					}

					if needs_removal {
						backend.graph_remove_output(
							ctx,
							node.inps[rm_idx],
							{idx = 3, id = id},
						)
						node.input_count -= 1
						node.inps = node.inps[:len(node.inps) - 1]
					} else {
						assert(node.rtype < len(backend.IDEAL_CLASSES))
						node.rtype += BIN_OP_OFFSET
						backend.graph_set_input(ctx, id, 3, val.inps[1])
					}

					mem_op.mem_mode = .Dest
					changed = true
				} else {
					backend.peep_ctx_add_trigger(ctx, val.inps[0], id)
					if xtype(lhs) == .X64_Load {
						backend.peep_ctx_add_trigger(ctx, lhs.inps[2], id)
					}
				}
			}
		}

		if changed do return id
		return 0
	}

	return 0
}

x64_add_node :: proc(
	ctx: ^backend.Graph,
	name: string,
	type: X64_Node_Type,
	dt: backend.Node_Datatype,
	inps: []backend.Node_ID,
	extra: X64_Mem_Op = {},
) -> (
	^backend.Node,
	backend.Node_ID,
) {
	backend.graph_push_tag(ctx, name)
	slot := (^X64_Mem_Op)(backend.graph_get_next_extra_slot(ctx, u16(type)))
	slot^ = extra
	id := backend.graph_add_raw(ctx, u16(type), dt, inps)
	return graph_get(ctx, id), id
}

x64_make_node :: proc(
	graph: ^backend.Graph,
	from: backend.Node_ID,
	type: u16,
	inps: []backend.Node_ID,
	extra: X64_Mem_Op,
) -> backend.Node_ID {
	backend.graph_push_tag(graph, backend.graph_get_tag(graph, from))
	fnode := graph_get(graph, from)
	id := backend.graph_add_raw(graph, type, fnode.dt, inps)
	node := graph_get(graph, id)
	// TODO: I no longer understand this, needs better comment
	// NOTE: afaik this is sufficient since we don't insert load ops before
	// scheduling
	node.is_store = fnode.is_store
	node.is_load = fnode.is_load || type == u16(X64_Node_Type.X64_Load)
	node.lane = fnode.lane
	x64_extra(graph, node, X64_Mem_Op)^ = extra
	return id
}

x64_post_schedule_peep :: proc(
	ctx: backend.PS_Peep_Ctx,
	node: backend.Expanded_Node,
	_: $T,
) -> backend.Node_ID {
	id := backend.graph_id(ctx, node)
	#partial matchx: switch xtype(node) {
	case .Add ..= .Xor, .Eq ..= .U_Ge, .F_Add ..= .F_Div, .F_Eq ..= .F_Ge:
		if node.itype == .F_Lt || node.itype == .F_Le do break

		op := node.rtype + BIN_OP_OFFSET
		rhs := graph_expand(ctx, node.inps[1])
		if xtype(rhs) == .X64_Load && len(rhs.outs) == 1 {
			mem_op := x64_extra(ctx, rhs, X64_Mem_Op)
			if mem_op.dt != rhs.dt do break matchx
			if !has_no_clobbers(ctx, node.inps[1]) do break matchx
			mem_op.mem_mode = .Src
			mem_op.dt = rhs.dt

			slots: [5]backend.Node_ID
			copy(slots[:], rhs.inps)
			slots[4] = slots[3]
			slots[3] = node.inps[0]

			return x64_make_node(
				ctx,
				id,
				op,
				slots[:len(slots) - int(slots[4] == 0)],
				mem_op^,
			)
		} else if xtype(rhs) == .X64_CLoad {
			mem_op := X64_Mem_Op {
				mem_mode = .Src,
				dt       = rhs.dt,
			}

			slots := [?]backend.Node_ID{rhs.inps[0], node.inps[0]}

			return x64_make_node(ctx, id, op, slots[:], mem_op)
		}
	case .X64_Eq ..= .X64_U_Ge:
		mem_op := x64_extra(ctx, node, X64_Mem_Op)
		if mem_op.mem_mode != .None do break matchx
		lhs := graph_expand(ctx, node.inps[0])
		if xtype(lhs) == .X64_Load && len(lhs.outs) == 1 {
			om_mem_op := x64_extra(ctx, lhs, X64_Mem_Op)
			if om_mem_op.dt != lhs.dt do break matchx
			if !has_no_clobbers(ctx, node.inps[0]) do break matchx
			om_mem_op.imm = mem_op.imm
			om_mem_op.mem_mode = .Dest
			om_mem_op.dt = lhs.dt

			return x64_make_node(ctx, id, node.rtype, lhs.inps, om_mem_op^)
		}
	case .X64_Fma_213:
		mem_op := x64_extra(ctx, node, X64_Mem_Op)
		rhs := graph_expand(ctx, node.inps[2])

		if xtype(rhs) == .X64_Load {
			if !has_no_clobbers(ctx, node.inps[2]) do break matchx
			//panic("")
		} else if xtype(rhs) == .X64_CLoad {
			mem_op.mem_mode = .Src
			mem_op.dt = rhs.dt

			slots := [?]backend.Node_ID {
				rhs.inps[0],
				node.inps[0],
				node.inps[1],
			}

			return x64_make_node(ctx, id, node.rtype, slots[:], mem_op^)
		}
	}

	has_no_clobbers :: proc(
		ctx: backend.PS_Peep_Ctx,
		inp: backend.Node_ID,
	) -> bool {
		#reverse for pred in ctx.preds {
			if pred == inp do return true
			if graph_get(ctx, pred).rtype == backend.DEAD_NODE_KIND do continue
			pnode := graph_expand(ctx, pred)
			if pnode.is_store do break
		}

		return false
	}

	return 0
}

x64_addr_add_offset :: proc(
	graph: ^backend.Graph,
	node: backend.Expanded_Node,
) -> (
	base: backend.Node_ID,
	off: int,
	ok: bool,
) {
	if xtype(node) != .X64_Add do return
	return node.inps[0], int(x64_extra(graph, node, X64_Mem_Op).imm), true
}

GPA_MASK_IDX :: backend.RM_Intern_Idx{}
XMM_MASK_IDX :: backend.RM_Intern_Idx {
	kind = .Vector,
}
GPA_SPILL_MASK_IDX :: backend.RM_Intern_Idx {
	index = 1,
}
XMM_SPILL_MASK_IDX :: backend.RM_Intern_Idx {
	kind  = .Vector,
	index = 1,
}

@(rodata)
GPA_MASKS := [6]backend.RM_Intern_Idx{}

@(rodata)
XMM_MASKS := [6]backend.RM_Intern_Idx {
	XMM_MASK_IDX,
	XMM_MASK_IDX,
	XMM_MASK_IDX,
	XMM_MASK_IDX,
	XMM_MASK_IDX,
	XMM_MASK_IDX,
}

@(rodata)
GPA_SPILL_MASKS := [6]backend.RM_Intern_Idx {
	GPA_SPILL_MASK_IDX,
	GPA_SPILL_MASK_IDX,
	GPA_SPILL_MASK_IDX,
	GPA_SPILL_MASK_IDX,
	GPA_SPILL_MASK_IDX,
	GPA_SPILL_MASK_IDX,
}

@(rodata)
XMM_SPILL_MASKS := [6]backend.RM_Intern_Idx {
	XMM_SPILL_MASK_IDX,
	XMM_SPILL_MASK_IDX,
	XMM_SPILL_MASK_IDX,
	XMM_SPILL_MASK_IDX,
	XMM_SPILL_MASK_IDX,
	XMM_SPILL_MASK_IDX,
}

x64_meta_of :: proc(
	graph: ^backend.Graph,
	ra: ^backend.Regalloc,
	node: backend.Expanded_Node,
	_: $T,
) -> backend.Regalloc_Node_Meta {
	@(static, rodata)
	GPA_MASK := [?]i64{0xFFFF & ~i64(1 << uint(RSP))}
	@(static, rodata)
	GPA_SPILL_MASK := [?]i64{~i64(1 << uint(RSP))}
	@(static, rodata)
	XMM_MASK := [?]i64{0xFFFF}
	@(static, rodata)
	XMM_SPILL_MASK := [?]i64{~i64(0)}

	@(static, rodata)
	GPA_DIV_MASK := [?]i64 {
		0xFFFF &
		~i64(1 << uint(RSP)) &
		~i64(1 << uint(RAX)) &
		~i64(1 << uint(RDX)),
	}

	if node.gvn == 0 {
		ra.mask_len = MASK_SIZE
		rslice(ra, .General, GPA_MASK[:])
		rslice(ra, .Vector, XMM_MASK[:])
		rslice(ra, .General, GPA_SPILL_MASK[:])
		rslice(ra, .Vector, XMM_SPILL_MASK[:])
	}

	single :: backend.rm_intern_single
	rslice :: backend.rm_intern_slice

	dup :: #force_inline proc(
		msks: []backend.RM_Intern_Idx,
	) -> []backend.RM_Intern_Idx {
		return slice.clone(msks)
	}

	nkind := ra.datatype_to_reg_kind[node.dt]

	masks := [backend.Reg_Kind][]backend.RM_Intern_Idx {
		.General = GPA_MASKS[:],
		.Vector  = XMM_MASKS[:],
	}
	nmasks := masks[nkind]
	out := nmasks[0]

	smasks := [backend.Reg_Kind][]backend.RM_Intern_Idx {
		.General = GPA_SPILL_MASKS[:],
		.Vector  = XMM_SPILL_MASKS[:],
	}
	snmasks := smasks[nkind]
	sout := snmasks[0]

	mem_op: ^X64_Mem_Op = x64_extra(graph, node, X64_Mem_Op)

	switch xtype(node) {
	case .Simd_Reduce_Add_Bisect,
	     .Splat,
	     .Then,
	     .Else,
	     .Start,
	     .Entry,
	     .Region,
	     .Loop,
	     .Call_End:
		fmt.panicf("should not reach these: %v", node)
	case .Poison:
		return {}
	case .Param:
		kind := ra.datatype_to_reg_kind[node.dt]
		args := ra.args[kind]
		arg_ext := backend.graph_extra(graph, node, backend.Tup)
		idx := 0
		for a in ra.param_specs[:arg_ext.idx] {
			if a.dt == .Void do continue
			idx += int(ra.datatype_to_reg_kind[a.dt] == kind)
		}

		mask: backend.RM_Intern_Idx
		if int(idx) < len(args) {
			mask = single(ra, args[idx])
		} else {
			mask = single(
				ra,
				{
					kind = kind,
					index = GPA_REG_COUNT + u16(idx) - u16(len(args)),
				},
			)
		}
		return {out = mask, input_start = 1}
	case .CInt:
		return {out = out}
	case .X64_Pcmpeq,
	     .X64_Psadbw,
	     .X64_Pshufb,
	     .Add ..=
	     .Xor,
	     .F_Add ..=
	     .F_Div,
	     .Mul:
		return {out = out, masks = nmasks[:2], in_place_slot = 1}
	case .Eq ..= .U_Ge:
		return {out = out, masks = nmasks[:2]}
	case .F_Eq ..= .F_Ge:
		return {out = out, masks = XMM_MASKS[:2]}
	case .Shl ..= .U_Shr:
		return {
			out = GPA_MASK_IDX,
			masks = dup({GPA_MASK_IDX, single(ra, RCX)}),
			in_place_slot = 1,
		}
	case .Div, .U_Div:
		rax := single(ra, RAX)
		return {
			out = rax,
			masks = dup({rax, rslice(ra, .General, GPA_DIV_MASK[:])}),
			clobbers = #partial{.General = 1 << uint(RDX)},
			in_place_slot = 1,
		}
	case .Rem, .U_Rem:
		return {
			out = single(ra, RDX),
			masks = dup(
				{single(ra, RAX), rslice(ra, .General, GPA_DIV_MASK[:])},
			),
			clobbers = #partial{.General = 1 << uint(RAX)},
		}
	case .And_Not:
		return {out = out, masks = nmasks[:2], in_place_slot = 2}
	case .Split:
		return {out = sout, masks = snmasks[:1]}
	case .Phi:
		if len(snmasks) < len(node.inps) - 1 {
			elem := sout
			snmasks = make(type_of(snmasks), len(node.inps) - 1)
			slice.fill(snmasks, elem)
		}
		return {
			out = sout,
			masks = snmasks[:len(node.inps) - 1],
			input_start = 1,
		}
	case .Global, .Proc_Addr:
		return {}
	case .Mem, .Root_Mem, .Sym, .Local, .Jump, .Always, .Trap:
		return {input_start = 1}
	case .Local_Addr, .Global_Addr:
		return {out = out, input_start = 1}
	case .Copy, .Set, .Call, .Return:
		cc := &X64_SYSTEMV_CC
		// NOTE: this handles the edge case where there is no memory returned,
		// this happens when we only have infinite loops that terminate the
		// function
		prefix := min(2, len(node.inps))
		call: ^backend.Call = backend.graph_extra(graph, node, backend.Call)
		if call != nil {
			prefix = backend.CALL_PREFIX
			cc = &graph.cc_table[call.ccid]
		}

		nmasks = make(type_of(nmasks), len(node.inps) - prefix)

		inited := prefix

		banks := cc.args
		if node.itype == .Return do banks = ra.rets

		counts: [Reg_Kind]int
		for n, i in node.inps[inited:] {
			rk := graph.datatype_to_reg_kind[graph_get(graph, n).dt]
			nmasks[i] = single(ra, banks[rk][counts[rk]])
			counts[rk] += 1
		}

		if call != nil && call.indirect {
			nmasks[len(nmasks) - 1] = GPA_MASK_IDX
		}

		return {masks = nmasks, input_start = u8(prefix)}
	case .Store:
		return {masks = dup({GPA_MASK_IDX, out}), input_start = 2}
	case .Load:
		return {out = out, masks = GPA_MASKS[:1], input_start = 2}
	case .If:
		cond := graph_get(graph, node.inps[1])
		return {
			masks = nmasks[:int(cond.dt != .Void)],
			input_start = 1 + u8(cond.dt == .Void),
		}
	case .Ret:
		// TODO: this is actually incorrect, we need to iterate the previous
		// rets to figure this out safely
		cend := graph_expand(graph, node.inps[0])
		call := backend.graph_extra(graph, cend.inps[0], backend.Call)
		ret_ext := backend.graph_extra(graph, node, backend.Tup)
		kind := ra.datatype_to_reg_kind[node.dt]
		rets := ra.cc_table[call.ccid].rets[kind]
		return {out = single(ra, rets[ret_ext.idx]), input_start = 1}
	case .Ctz, .Not, .Neg:
		assert(nkind == .General)
		return {out = out, masks = nmasks[:1], in_place_slot = 1}
	case .Sext, .Uext:
		return {out = out, masks = nmasks[:1]}
	case .U_F_From_I:
		panic("TODO")
	case .F_To_I, .F_From_I, .F_Ext, .F_Demote, .Cast:
		inp := graph_get(graph, node.inps[0])
		return {out = out, masks = masks[ra.datatype_to_reg_kind[inp.dt]][:1]}
	case .Simd_Extract_Lsbs:
		return {out = out, masks = XMM_MASKS[:1]}
	case .CV128:
		panic("TODO")
	case .X64_Shl ..=
	     .X64_U_Shr,
	     .X64_F_Eq ..=
	     .X64_F_Ge,
	     .X64_F_Add ..=
	     .X64_F_Div,
	     .X64_Add ..=
	     .X64_Xor,
	     .X64_Eq ..=
	     .X64_U_Ge,
	     .X64_Store,
	     .X64_Neg,
	     .X64_Not,
	     .X64_Fma_213:
		const_off := int(mem_op.scale != 0)

		#partial switch xtype(node) {
		case .X64_F_Eq ..= .X64_F_Ge:
			nmasks = XMM_MASKS[:]
		}

		if xtype(node) == .X64_Store && len(node.inps) - const_off == 4 {
			dt := graph_get(graph, node.inps[3]).dt
			nmasks = masks[ra.datatype_to_reg_kind[dt]]
		}

		start: u8 = 0
		in_place_slot: i8 = 0
		masks: [dynamic; 4]backend.RM_Intern_Idx
		append(&masks, nmasks[0])

		is_cload := graph_get(graph, node.inps[0]).itype == .Global

		#partial switch xtype(node) {
		case .X64_Shl ..= .X64_U_Shr:
			switch mem_op.mem_mode {
			case .None:
				masks = {}
			case .Src:
				panic("does not support")
			case .Dest:
				if len(node.inps) - const_off == 4 {
					masks[0] = single(ra, RCX)
				} else {
					masks = {}
				}
			}
		}
		#partial switch xtype(node) {
		case .X64_Add ..=
		     .X64_Xor,
		     .X64_F_Add ..=
		     .X64_F_Div,
		     .X64_Shl ..=
		     .X64_U_Shr:
			switch mem_op.mem_mode {
			case .None:
				in_place_slot = 1
			case .Src:
				in_place_slot = 2
			case .Dest:
			}
		case .X64_Store:
			mem_op.mem_mode = .Dest
		case .X64_Neg, .X64_Not:
			masks = {}
		case .X64_Fma_213:
			in_place_slot = 1 + i8(is_cload)
			append(&masks, out)
		}

		switch mem_op.mem_mode {
		case .None:
			append(&masks, out)
		case .Dest, .Src:
			if is_cload {
				start = 1
				in_place_slot -= 1
			} else {
				start = 2
				extra_start := graph_get(graph, node.inps[start]).dt == .Void
				start += u8(extra_start)
				in_place_slot -= i8(extra_start)
				if start == 2 {
					inject_at(&masks, 0, GPA_MASK_IDX)
				}
			}
		}

		if mem_op.scale != 0 do append(&masks, GPA_MASK_IDX)

		return {
			out = out,
			masks = dup(masks[:]),
			input_start = start,
			in_place_slot = in_place_slot,
		}
	case .X64_Mul:
		return {out = out, masks = nmasks[:1]}
	case .X64_Lea:
		inp := graph_get(graph, node.inps[0])
		return {
			out = out,
			masks = nmasks[:1 + int(mem_op.scale != 0) - int(inp.dt == .Void)],
			input_start = u8(inp.dt == .Void),
		}
	case .X64_Load:
		return {
			out = out,
			masks = GPA_MASKS[:1 + int(mem_op.scale != 0)],
			input_start = 2 + u8(graph_get(graph, node.inps[2]).dt == .Void),
		}
	case .X64_CLoad:
		return {out = out, input_start = 1}
	case .X64_Mul8:
		rax := single(ra, RAX)
		return {out = rax, masks = dup({GPA_MASK_IDX, rax})}
	case .X64_Pshufd:
		return {out = out, masks = nmasks[:1]}
	case .X64_Pextr:
		return {out = out, masks = XMM_MASKS[:1]}
	}

	fmt.panicf("TODO %v", node)
}

Ctx :: struct {
	using inner:        backend.Codegen_Emit_Ctx,
	spill_slot_base:    [Reg_Kind]i32,
	big_constants:      [dynamic]u8,
	local_relocs:       [dynamic]Local_Reloc,
	stack_size:         i32,
	used:               bit_arr.Bit_Set,
	code_start:         uint,
	stack_param_offset: [Reg_Kind][dynamic]i32,
	last_off:           uint,
	sloc:               backend.Sloc,
	pushed:             i32,
}

Local_Reloc :: struct {
	dest:   u32,
	offset: u32,
}

emit_big_constant :: proc(
	ctx: ^Ctx,
	#any_int align: int,
	bytes: []u8,
) -> (
	id: u32,
) {
	align_up := mem.align_backward_int(len(ctx.big_constants) + 2, align)

	for _ in len(ctx.big_constants) + 2 ..< align_up {
		append(&ctx.big_constants, 0)
	}

	append(&ctx.big_constants, u8(len(bytes)), u8(align))

	id = backend.RELOC_BIG_CONSTANT_BASE + u32(len(ctx.big_constants))

	append(&ctx.big_constants, ..bytes)

	return
}

x64_emit_function :: proc(
	ectx: backend.Codegen_Emit_Ctx,
) -> backend.Codegen_Output {
	context.allocator, _ = arna.scrath()

	reloc_start := ectx.relocs.pos
	sloc_start := ectx.slocs.pos
	cfi_start := ectx.cfi.pos

	ctx: Ctx
	ctx.code_start = ectx.code.pos
	ctx.inner = ectx

	slot: [2]int
	ctx.used = bit_arr.init_from_masks(slot[:])

	has_call := false
	for bb in ctx.schedule.bbs {
		bnode := graph_expand(ctx, bb.head)

		for ins in bb.instrs {
			has_call |= graph_get(ctx, ins).itype in backend.CALLS
		}

		if bnode.itype != .Call_End do continue
		cnode := graph_expand(ctx, bnode.inps[0])
		call_stack_size: i32
		for inp in raw_data(cnode.inps)[cnode.input_count:cnode.input_cap] {
			inode := graph_expand(ctx, inp)
			if inode.itype != .Local do continue
			iext := backend.graph_extra(ctx, inode, backend.Local)
			call_stack_size += iext.size
			iext.offset = call_stack_size - iext.size
		}
		ctx.stack_size = max(ctx.stack_size, call_stack_size)
	}

	emem := ctx.graph.root_mem
	mem_outs := backend.graph_outs(ctx.graph, emem)

	Local_Slot :: bit_field u64 {
		node:     backend.Node_ID | 32,
		priority: i32             | 32,
	}
	locals: [dynamic]Local_Slot

	for mout in mem_outs {
		mnode := graph_expand(ctx.graph, mout.id)
		if mnode.itype == .Local {
			extra := backend.graph_extra(ctx.graph, mnode, backend.Local)
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
		extra := backend.graph_extra(ctx.graph, loc.node, backend.Local)
		ctx.stack_size += extra.size
		extra.offset = ctx.stack_size - extra.size
	}

	params, _ := backend.assemble_args(ctx, len(ctx.param_specs))

	spill_slot_count: [Reg_Kind]i32
	for reg in ctx.allocs {
		spill_slot_count[reg.kind] = max(
			spill_slot_count[reg.kind],
			i32(reg.index) - 16 + 1,
		)
		if reg.kind == .General {
			bit_arr.set_unbounded(ctx.used, int(reg.index))
		}
	}

	mount_sloc(&ctx, ctx.entry)

	pushed: i32
	for reg in ctx.callee_saved[.General] {
		if bit_arr.contains(ctx.used, int(reg)) {
			// push $reg
			emit_single_op(ctx.code, 0x50, reg)
			next_sloc(&ctx)

			pushed += 8
			emit_cfi(
				&ctx,
				.Def_Cfa_Offset,
				arg = u32(pushed) + X64_CFI_SPEC.initial_cfa_offset,
			)
			emit_cfi(
				&ctx,
				.Save_Reg,
				reg = DWARF_GPR[reg.index],
				arg = u32(pushed) + X64_CFI_SPEC.initial_cfa_offset,
			)
		}
	}

	for size, kind in spill_slot_count {
		ctx.spill_slot_base[kind] = i32(ctx.stack_size)
		ctx.stack_size += size * SPILL_SLOT_SIZE[kind]
	}

	param_offset := pushed + 8
	for param, i in ctx.param_specs {
		param_id := params[i]

		extra := backend.graph_extra(ctx.graph, param_id, backend.Local)
		if extra != nil {
			fmt.assertf(
				extra.size == param.size,
				"%v == %v",
				extra.size,
				param.size,
			)
			extra.offset = param_offset
		}

		if param.size > 0 && param.dt != .Void {
			assert(param.size == 8, "TODO")
			ctx.stack_size -= param.size
			kind := ctx.datatype_to_reg_kind[param.dt]
			append(&ctx.stack_param_offset[kind], i32(param_offset))
		}

		param_offset += param.size
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
		local := backend.graph_extra(ctx, mout.id, backend.Local)
		if local == nil do continue
		local.offset -= used_red_zone
	}

	for &slot in ctx.spill_slot_base {
		slot -= used_red_zone
	}

	for param in params {
		enode := graph_expand(ctx, param)
		if enode.itype == .Local {
			extra := backend.graph_extra(ctx.graph, enode, backend.Local)
			extra.offset += ctx.stack_size
		}
	}

	for &group in ctx.stack_param_offset {
		for &off in group do off += i32(ctx.stack_size)
	}

	ctx.pushed = pushed

	if ctx.stack_size != 0 {
		// sub rsp, $ctx.stack_size
		emit_imm_op(ctx.code, 0x81, 0b101, RSP, ctx.stack_size)
		next_sloc(&ctx)
		emit_cfi(
			&ctx,
			.Def_Cfa_Offset,
			arg = u32(pushed + ctx.stack_size) +
			X64_CFI_SPEC.initial_cfa_offset,
		)
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
		[]backend.Reloc,
		ctx.relocs.ptr[reloc_start:ctx.relocs.pos],
	)
	slocs := mem.slice_data_cast(
		[]backend.Sloc,
		ctx.slocs.ptr[sloc_start:ctx.slocs.pos],
	)
	cfi := mem.slice_data_cast(
		[]backend.Cfi_Op,
		ctx.cfi.ptr[cfi_start:ctx.cfi.pos],
	)
	arna.alloc(ctx.code, 0, 8)
	constants := arna.clone(ctx.code, ctx.big_constants[:])

	return {
		code = code,
		relocs = relocs,
		constants = constants,
		slocs = slocs,
		cfi = cfi,
	}
}

emit_cfi :: proc(
	ctx: ^Ctx,
	kind: backend.Cfi_Kind,
	reg: u8 = 0,
	arg: u32 = 0,
) {
	if !ctx.has_dbg do return
	backend.add_cfi(ctx.cfi)^ = {
		offset = u32(ctx.code.pos - ctx.code_start),
		arg    = arg,
		kind   = kind,
		reg    = reg,
	}
}

next_sloc :: proc(ctx: ^Ctx) {
	cx := ctx.sloc
	cx.range = u32(ctx.code.pos - ctx.last_off)
	backend.add_sloc(ctx.slocs)^ = cx
	ctx.last_off = ctx.code.pos
}

mount_sloc :: proc(ctx: ^Ctx, node: backend.Node_ID) {
	dn := backend.graph_dbg_slot(ctx, graph_get(ctx, node))^
	if dn != 0 do ctx.sloc = backend.graph_getd(ctx, dn).sloc
	ctx.last_off = ctx.code.pos
}

@(disabled = GEN_SPEC)
x64_emit_instr :: proc(
	ctx: ^Ctx,
	instr: backend.Node_ID,
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
		.X64_F_Eq  = {0x94, 0},
		.X64_F_Ne  = {0x95, 0},
		.X64_F_Lt  = {0x92, 0},
		.X64_F_Le  = {0x96, 0},
		.X64_F_Gt  = {0x97, 0},
		.X64_F_Ge  = {0x93, 0},
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
		.F_Add     = {0x58, 0},
		.F_Sub     = {0x5C, 0},
		.F_Mul     = {0x59, 0},
		.F_Div     = {0x5E, 0},
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
		.X64_F_Eq = .Ne,
		.X64_F_Ne = .Eq,
		.X64_F_Lt = .U_Le,
		.X64_F_Le = .U_Lt,
		.X64_F_Gt = .U_Le,
		.X64_F_Ge = .U_Lt,
	}

	@(static, rodata)
	SRC_MODE_OPCODE_TABLE := #partial [X64_Node_Type]Instr_Info {
		.X64_Add   = {0x03, 0},
		.X64_Sub   = {0x2B, 0},
		.X64_And   = {0x23, 0},
		.X64_Or    = {0x0B, 0},
		.X64_Xor   = {0x33, 0},
		.X64_F_Add = {0x58, 0},
		.X64_F_Sub = {0x5C, 0},
		.X64_F_Mul = {0x59, 0},
		.X64_F_Div = {0x5E, 0},
	}

	ADD_LANE_TABLE :: #partial [backend.Lane_Type]u8 {
		.I8  = 0xFC,
		.I16 = 0xFD,
		.I32 = 0xFE,
		.I64 = 0xD4,
	}

	SUB_LANE_TABLE :: #partial [backend.Lane_Type]u8 {
		.I8  = 0xF8,
		.I16 = 0xF9,
		.I32 = 0xFA,
		.I64 = 0xFB,
	}

	@(static, rodata)
	SIMD_OPCODE_TABLE := #partial [X64_Node_Type][backend.Lane_Type]u8 {
		.X64_Add = ADD_LANE_TABLE,
		.X64_Sub = SUB_LANE_TABLE,
		.X64_And = #partial{.I8 ..= .I64 = 0xDB},
		.X64_Or = #partial{.I8 ..= .I64 = 0xEB},
		.X64_Xor = #partial{.I8 ..= .I64 = 0xEF},
		.Add = ADD_LANE_TABLE,
		.Sub = SUB_LANE_TABLE,
		.And = #partial{.I8 ..= .I64 = 0xDB},
		.Or = #partial{.I8 ..= .I64 = 0xEB},
		.Xor = #partial{.I8 ..= .I64 = 0xEF},
	}

	block_base := ctx.gvn - u32(len(ctx.bbs))
	node := graph_expand(ctx, instr)
	mem_op_placeholder: X64_Mem_Op
	mem_op := x64_extra(ctx, node, X64_Mem_Op)
	if mem_op == nil {
		mem_op = &mem_op_placeholder
	}

	scl := mem_op.scale
	idx := NO_INDEX
	if scl != 0 do idx = reg_of(ctx, node.inps[len(node.inps) - 1])
	imm_boundary := int(scl != 0)
	pfx: u8 = node.dt == .F64 ? 0xF2 : 0xF3
	wide := node.dt == .F64

	mount_sloc(ctx, instr)

	type := xtype(node)

	switch type {
	case .CV128:
		panic("TODO: CV128 load-from-static emit not implemented")
	case .Splat:
		panic("no")
	case .Simd_Extract_Lsbs:
		// pmovmskb $dst(gpr), $src(xmm)
		dst := reg_of(ctx, instr)
		src := reg_of(ctx, node.inps[0])
		rx := rex(dst, src, RAX, false)
		emit(ctx.code, {0x66, rx, 0x0f, 0xd7, mod_rm(.Direct, dst, src)})
	case .X64_Pshufd:
		dst := reg_of(ctx, instr)
		src := reg_of(ctx, node.inps[0])

		assert(node.dt == .V128)
		assert(node.lane == .I8)

		// pshufd $dst, $src, prj
		rx := rex(dst, src, NO_INDEX, false)
		emit(
			ctx.code,
			{0x66, rx, 0xf, 0x70, mod_rm(.Direct, dst, src), mem_op.aux},
		)
	case .X64_Pshufb:
		dst := reg_of(ctx, node.inps[0])
		proj := reg_of(ctx, node.inps[1])

		assert(node.dt == .V128)
		assert(node.lane == .I8)

		// pshufb $dst, $proj
		rx := rex(dst, proj, NO_INDEX, false)
		emit(ctx.code, {0x66, rx, 0xf, 0x38, 0, mod_rm(.Direct, dst, proj)})
	case .X64_Psadbw:
		dst := reg_of(ctx, instr)
		rhs := reg_of(ctx, node.inps[1])

		assert(node.dt == .V128)
		assert(node.lane == .I8)

		// psadbw $dst, $rhs
		rx := rex(dst, rhs, NO_INDEX, false)
		emit(ctx.code, {0x66, rx, 0x0f, 0xF6, mod_rm(.Direct, dst, rhs)})
	case .X64_Pextr:
		dst := reg_of(ctx, instr)
		src := reg_of(ctx, node.inps[0])
		aux := mem_op.aux

		if node.dt != .I16 {
			dst, src = src, dst
		}

		rx := rex(dst, src, NO_INDEX, backend.DT_SIZE[node.dt] == 8)
		rm := mod_rm(.Direct, dst, src)
		#partial switch node.dt {
		case .I8:
			// pextrb $dst, $src, $auc
			emit(ctx.code, {0x66, rx, 0x0f, 0x3A, 0x14, rm, aux})
		case .I16:
			// pextrw $dst, $src, $auc
			emit(ctx.code, {0x66, rx, 0x0f, 0xC5, rm, aux})
		case .I32, .I64:
			// pextrd $dst, $src, $auc
			emit(ctx.code, {0x66, rx, 0x0f, 0x3A, 0x16, rm, aux})
		}
	case .Simd_Reduce_Add_Bisect:
		when false {
			// TODO: maybe exploding this into more primitive nodes can help
			dst := reg_of(ctx, instr)
			src := reg_of(ctx, node.inps[1])
			prj :: 0b11101110

			assert(node.dt == .V128)
			assert(node.lane == .I8)

			// pshufd $dst, $src, prj
			rx := rex(dst, src, NO_INDEX, false)
			emit(
				ctx.code,
				{0x66, rx, 0xf, 0x70, mod_rm(.Direct, dst, src), prj},
			)

			// paddb $dst, $src
			rx = rex(dst, src, NO_INDEX, false)
			emit(ctx.code, {rx, 0xf, 0xfc, mod_rm(.Direct, dst, src)})

			// pxor $tmp, $tmp
			rx = rex(tmp, tmp, NO_INDEX, false)
			emit(ctx.code, {0x66, rx, 0x0f, 0xEF, mod_rm(.Direct, tmp, tmp)})

			// movd $dst
		}

		panic("we should not reach this")
	case .Ctz:
		// tzcnt $dst, $src (dst == src in place)
		dst := reg_of(ctx, instr)
		src := reg_of(ctx, node.inps[0])
		rx := rex(dst, src, RAX, false)
		emit(ctx.code, {0xf3, rx, 0x0f, 0xbc, mod_rm(.Direct, dst, src)})
	case .Global:
	case .Local:
	case .Local_Addr, .Global_Addr:
		dst := reg_of(ctx, instr)
		addr, dis, id := reg_and_disp_of(ctx, node.inps[0])
		// lea $dst, [rsp/rip + $offset]
		emit(ctx.code, {rex(dst, addr, RAX, true), 0x8d})
		emit_indirect_addr(ctx, dst, addr, NO_INDEX, 1, dis, id)
	case .Proc_Addr:
		id := backend.graph_extra(ctx, instr, backend.Tup).idx + 1
		dst := reg_of(ctx, instr)
		// lea $dst, [rip + $offset]
		emit(ctx.code, {rex(dst, RIP, NO_INDEX, true), 0x8d})
		emit_indirect_addr(ctx, dst, RIP, NO_INDEX, 1, 0, id, kind = .Text)
	case .X64_Lea:
		dst := reg_of(ctx, instr)
		bse, sdis, id := reg_and_disp_of(ctx, node.inps[0])
		dis := mem_op.dis

		// lea $dst, [$bse + $idx * $scl + $sdis + $dis]
		rx := rex(dst, bse, idx, true)
		emit(ctx.code, {rx, 0x8D})
		emit_indirect_addr(ctx, dst, bse, idx, scl, sdis + dis, id)
	case .X64_CLoad:
		dst := reg_of(ctx, instr)
		bse, sdis, id := reg_and_disp_of(ctx, node.inps[0])

		// movss/movsd $dst, [rsp + $src_off]
		emit(ctx.code, {pfx, rex(dst, bse, RAX, false), 0x0f, 0x10})
		emit_indirect_addr(ctx, dst, bse, NO_INDEX, 1, sdis, id)
	case .Store, .X64_Store:
		bse, sdis, id := reg_and_disp_of(ctx, node.inps[2])
		dis := mem_op.dis
		dt := mem_op.dt

		if 3 + imm_boundary < len(node.inps) {
			vdt := graph_get(ctx, node.inps[3]).dt
			val := reg_of(ctx, node.inps[3])

			if vdt in backend.FLOAT_DTS {
				// movss/movsd [$bse + ...], $val
				pfx: u8 = vdt == .F64 ? 0xF2 : 0xF3
				rx := rex(val, bse, idx, false)
				emit(ctx.code, {pfx, rx, 0x0f, 0x11})
				emit_indirect_addr(ctx, val, bse, idx, scl, dis + sdis, id)
				break
			}

			if vdt == .V128 || vdt == .V256 || vdt == .V512 {
				assert(vdt == .V128, "TODO")
				// movups [$bse + ...], $val
				rx := rex(val, bse, idx, false)
				emit(ctx.code, {rx, 0x0f, 0x11})
				emit_indirect_addr(ctx, val, bse, idx, scl, dis + sdis, id)
				break
			}

			rx := rex(val, bse, idx, backend.DT_SIZE[vdt] == 8)
			emit_sized_opcode(ctx.code, vdt, rx, 0x89)
			emit_indirect_addr(ctx, val, bse, idx, scl, dis + sdis, id)
		} else {
			imm := mem_op.imm
			rx := rex(RAX, bse, idx, backend.DT_SIZE[dt] == 8)
			emit_sized_opcode(ctx.code, dt, rx, 0xC7)
			emit_indirect_addr(
				ctx,
				RAX,
				bse,
				idx,
				scl,
				dis + sdis,
				id,
				backend.DT_SIZE[dt],
			)
			emit_imm_for_dt(ctx.code, dt, imm)
		}
	case .Load, .X64_Load:
		dt := mem_op.dt
		bse, sdis, id := reg_and_disp_of(ctx, node.inps[2])
		val := reg_of(ctx, instr)
		dis := mem_op.dis
		signed := mem_op.signed

		if dt in backend.FLOAT_DTS {
			// movss/movsd $val, [$bse + ...]
			rx := rex(val, bse, idx, false)
			emit(ctx.code, {pfx, rx, 0x0f, 0x10})
			emit_indirect_addr(ctx, val, bse, idx, scl, dis + sdis, id)
			break
		}

		if dt == .V128 || dt == .V256 || dt == .V512 {
			assert(dt == .V128, "TODO")

			// movups $val, [$bse + ...]
			rx := rex(val, bse, idx, false)
			emit(ctx.code, {rx, 0x0f, 0x10})
			emit_indirect_addr(ctx, val, bse, idx, scl, dis + sdis, id)
			break
		}

		rx := rex(val, bse, idx, backend.DT_SIZE[dt] == 8 || signed)
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

		rx := rex(dst, src, RAX, backend.DT_SIZE[dt] == 8)
		#partial switch dt {
		case .Void:
		case .I8:
			// movzx $val, $src
			emit(ctx.code, {rx, 0x0f, 0xb6})
		case .I16:
			// movzx $val, $src
			emit(ctx.code, {rx, 0x0f, 0xb7})
		case .I32, .I64:
			// mov $val, $src
			emit(ctx.code, {rx, 0x8b})
		}
		emit(ctx.code, {mod_rm(.Direct, dst, src)})
	case .Cast:
		dst := reg_of(ctx, instr)
		src := reg_of(ctx, node.inps[0])

		if src == dst do break

		if src.kind == dst.kind {
			assert(dst.kind == .General)
			rx := rex(src, dst, RAX, true)
			emit(ctx.code, {rx, 0x89, mod_rm(.Direct, src, dst)})
		} else {
			table := [Reg_Kind]u8 {
				.Vector  = 0x6E,
				.General = 0x7E,
			}
			op := table[dst.kind]
			a, b := dst, src
			if dst.kind == .General do a, b = b, a
			rx := rex(a, b, NO_INDEX, backend.DT_SIZE[node.dt] == 8)
			emit(ctx.code, {0x66, rx, 0x0f, op, mod_rm(.Direct, a, b)})
		}
	case .Start, .Entry, .Then, .Else, .Region, .Loop, .Call_End:
		fmt.panicf("Not reachable form here %v", node.node)
	case .If:
		cnode := graph_expand(ctx, node.inps[1])
		if cnode.dt != .Void {
			// test $cond, $cond
			cond := reg_of(ctx, node.inps[1])
			rx := rex(cond, cond, RAX, backend.DT_SIZE[cnode.dt] == 8)
			emit_sized_opcode(ctx.code, cnode.dt, rx, 0x85)
			emit(ctx.code, {mod_rm(.Direct, cond, cond)})
			next_sloc(ctx)
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
			op = CMP_OP_REVERSE[xtype(cnode)]
			if !is_consecutive {
				op = CMP_OP_REVERSE[op]
			}
		}

		emit(ctx.code, {0x0f, JCC_TABLE[op], 0, 0, 0, 0})

		if !is_consecutive do break

		next_sloc(ctx)
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
	case .Trap:
		emit(ctx.code, {0x0F, 0x0B})
	case .Call:
		call := backend.graph_extra(ctx, node, backend.Call)

		cc := ctx.graph.cc_table[call.ccid]
		if cc.is_syscall {
			// syscall
			emit(ctx.code, {0x0F, 0x05})
		} else if call.indirect {
			// call $ptr
			ptr := reg_of(ctx, node.inps[len(node.inps) - 1])
			rx := rex(RAX, ptr, NO_INDEX, false)
			emit(ctx.code, {rx, 0xFF, mod_sm(.Direct, 0b010, ptr)})
		} else if call.imported && ctx.emit_got_imports {
			// call [rip + $lib_call.id]
			emit(ctx.code, {0xFF, mod_sm(.Indirect, 0b010, RIP), 0, 0, 0, 0})
			backend.add_reloc(ctx.relocs)^ = {
				offset = u32(ctx.code.pos - ctx.code_start),
				kind   = .Got,
				size   = .r4,
				id     = call.cid,
			}
		} else {
			// call $call.cid
			emit(ctx.code, {0xe8, 0, 0, 0, 0})
			backend.add_reloc(ctx.relocs)^ = {
				offset = u32(ctx.code.pos - ctx.code_start),
				kind   = .Text,
				size   = .r4,
				id     = call.cid,
			}
		}
	case .Copy, .Set:
		lib_call: backend.Lib_Call
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
			backend.add_reloc(ctx.relocs)^ = {
				offset = u32(ctx.code.pos - ctx.code_start),
				kind   = .Got,
				size   = .r4,
				id     = lib_call.id,
			}
		} else {
			// call $lib_call.id
			emit(ctx.code, {0xe8, 0, 0, 0, 0})
			backend.add_reloc(ctx.relocs)^ = {
				offset = u32(ctx.code.pos - ctx.code_start),
				kind   = .Text,
				size   = .r4,
				id     = lib_call.id,
			}
		}
	case .Poison, .Param, .Phi, .Ret, .Mem, .Root_Mem, .Sym:
	case .CInt:
		dst := reg_of(ctx, instr)
		imm := backend.graph_extra(ctx, node, backend.CInt).value

		if imm == 0 && dst.kind == .Vector {
			// pxor $dst, $dst
			rx := rex(dst, dst, NO_INDEX, false)
			emit(ctx.code, {0x66, rx, 0x0f, 0xEF, mod_rm(.Direct, dst, dst)})
			break
		}

		if imm == 0 {
			// xor $dst, $dst
			rx := rex(dst, dst, NO_INDEX, false)
			emit(ctx.code, {rx, 0x33, mod_rm(.Direct, dst, dst)})
			break
		}

		switch node.dt {
		case .Void:
			panic("")
		case .I8:
			emit_single_op(ctx.code, 0xb0, dst)
			emit(ctx.code, {u8(imm)})
		case .I16 ..= .I64:
			if i64(i32(imm)) == imm {
				rx := rex(RAX, dst, RAX, true)
				emit(ctx.code, {rx, 0xC7, mod_sm(.Direct, 0, dst)})
				backend.emit_anys(ctx.code, i32(imm))
				break
			}

			// mov $dst, $imm
			emit_single_op(ctx.code, 0xb8, dst)
			backend.emit_anys(ctx.code, imm)
		case .F32, .F64, .V128, .V256, .V512:
			panic("")
		}
	case .X64_Add ..= .X64_Xor, .X64_Shl ..= .X64_U_Shr:
		imm := mem_op.imm

		is_shift := .X64_Shl <= xtype(node) && xtype(node) <= .X64_U_Shr

		switch mem_op.mem_mode {
		case .None:
			op := OPCODE_TABLE[xtype(node)]
			dst := reg_of(ctx, node.inps[0])

			// add/sub/and/or/xor $dst, $imm
			rx := rex(RAX, dst, RAX, backend.DT_SIZE[node.dt] == 8)
			emit_sized_opcode(ctx.code, node.dt, rx, op.opcode)
			emit(ctx.code, {mod_sm(.Direct, op.ext, dst)})
			if is_shift {
				emit(ctx.code, {u8(imm)})
			} else {
				emit_imm_for_dt(ctx.code, node.dt, imm)
			}
		case .Dest:
			dst, sdis, id := reg_and_disp_of(ctx, node.inps[2])
			dis := mem_op.dis

			op := OPCODE_TABLE[xtype(node)]
			src := Reg(op.ext)
			if 3 + imm_boundary < len(node.inps) {
				op = DEST_MODE_OPCODE_TABLE[xtype(node)]
				if !is_shift {
					src = reg_of(ctx, node.inps[3])
				}
			}

			tb: int = 0
			if 3 + imm_boundary >= len(node.inps) {
				tb = is_shift ? 1 : backend.DT_SIZE[mem_op.dt]
			}

			// add/sub/and/or/xor [$dst + $idx * $scl + $sdis + $dis], $src/$imm
			rx := rex(src, dst, idx, backend.DT_SIZE[mem_op.dt] == 8)
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

			if node.dt == .V128 {
				// paddb $dst, [$bse + $idx * $scl + $sdis + $dis]
				rx := rex(dst, bse, idx, false)
				op := SIMD_OPCODE_TABLE[type][node.lane]
				assert(op != 0)
				emit(ctx.code, {0x66, rx, 0x0f, op})
				emit_indirect_addr(ctx, dst, bse, idx, scl, dis + sdis, id)
				break
			}
			op := SRC_MODE_OPCODE_TABLE[xtype(node)]

			// add/sub/and/or/xor $dst, [$bse + $sdis + $dis]
			rx := rex(dst, bse, idx, backend.DT_SIZE[node.dt] == 8)
			emit_sized_opcode(ctx.code, node.dt, rx, op.opcode)
			emit_indirect_addr(ctx, dst, bse, idx, scl, dis + sdis, id)
		}
	case .Add ..= .Xor:
		dst := reg_of(ctx, node.inps[0])
		rhs := reg_of(ctx, node.inps[1])

		if node.dt == .V128 {
			opcode := SIMD_OPCODE_TABLE[type][node.lane]
			fmt.assertf(opcode != 0, "%v %v", type, node.lane)

			// paddb $dst, $rhs
			rx := rex(dst, rhs, NO_INDEX, false)
			emit(ctx.code, {0x66, rx, 0x0f, opcode, mod_rm(.Direct, dst, rhs)})
			break
		}

		// add/sub/and/or/xor $dst, $rhs
		rx := rex(rhs, dst, RAX, backend.DT_SIZE[node.dt] == 8)
		op := OPCODE_TABLE[xtype(node)].opcode
		emit_sized_opcode(ctx.code, node.dt, rx, op)
		emit(ctx.code, {mod_rm(.Direct, rhs, dst)})
	case .X64_Pcmpeq:
		dst := reg_of(ctx, node.inps[0])
		rhs := reg_of(ctx, node.inps[1])

		assert(node.dt == .V128)
		assert(node.lane == .I8)

		// pcmpeq* $dst, $src
		rx := rex(dst, rhs, RAX, false)
		emit(ctx.code, {0x66, rx, 0x0f, 0x74, mod_rm(.Direct, dst, rhs)})
	case .Eq ..= .U_Ge, .X64_Eq ..= .X64_U_Ge:
		switch mem_op.mem_mode {
		case .Dest:
			bse, sdis, id := reg_and_disp_of(ctx, node.inps[2])
			dis := mem_op.dis
			op_dt := mem_op.dt

			// cmp [$bse + $idx * $scl + $sdis + $dis], $imm
			rx := rex(RAX, bse, idx, backend.DT_SIZE[op_dt] == 8)
			emit_sized_opcode(ctx.code, op_dt, rx, 0x81)
			tb := backend.DT_SIZE[op_dt]
			emit_indirect_addr(ctx, 0b111, bse, idx, scl, dis + sdis, id, tb)
			emit_imm_for_dt(ctx.code, op_dt, mem_op.imm)
		case .Src:
			lhs := reg_of(ctx, node.inps[3])

			bse, sdis, id := reg_and_disp_of(ctx, node.inps[2])
			dis := mem_op.dis

			// cmp $dst, [$bse + $idx * $scl + $sdis + $dis]
			rx := rex(lhs, bse, idx, backend.DT_SIZE[mem_op.dt] == 8)
			emit_sized_opcode(ctx.code, mem_op.dt, rx, 0x3b)
			emit_indirect_addr(ctx, lhs, bse, idx, scl, dis + sdis, id)
		case .None:
			lhs := reg_of(ctx, node.inps[0])
			op_dt := graph_get(ctx, node.inps[0]).dt
			if 1 < len(node.inps) {
				// cmp $lhs, $rhs
				rhs := reg_of(ctx, node.inps[1])
				rx := rex(lhs, rhs, RAX, backend.DT_SIZE[op_dt] == 8)
				emit_sized_opcode(ctx.code, op_dt, rx, 0x3b)
				emit(ctx.code, {mod_rm(.Direct, lhs, rhs)})
			} else {
				// cmp $lhs, $imm
				rx := rex(RAX, lhs, RAX, backend.DT_SIZE[op_dt] == 8)
				emit_sized_opcode(ctx.code, op_dt, rx, 0x81)
				emit(ctx.code, {mod_sm(.Direct, 0b111, lhs)})
				emit_imm_for_dt(ctx.code, op_dt, mem_op.imm)
			}
		}

		if node.dt != .Void {
			next_sloc(ctx)

			dst := reg_of(ctx, instr)

			// setcc $lhs
			rx := rex(RAX, dst, RAX, true)
			op := OPCODE_TABLE[xtype(node)].opcode
			emit(ctx.code, {rx, 0x0F, op, mod_sm(.Direct, 0b000, dst)})

			next_sloc(ctx)

			// movzx $lhs, $lhs
			rx = rex(dst, dst, RAX, true)
			emit(ctx.code, {rx, 0x0F, 0xB6, mod_rm(.Direct, dst, dst)})
		}
	case .And_Not:
		dst := reg_of(ctx, node.inps[1])
		lhs := reg_of(ctx, node.inps[0])
		// not $dst
		rx := rex(RAX, dst, RAX, backend.DT_SIZE[node.dt] == 8)
		emit_sized_opcode(ctx.code, node.dt, rx, 0xf7)
		emit(ctx.code, {mod_sm(.Direct, 0b010, dst)})

		next_sloc(ctx)

		// and $dst, $lhs
		rx = rex(lhs, dst, RAX, backend.DT_SIZE[node.dt] == 8)
		emit_sized_opcode(ctx.code, node.dt, rx, 0x21)
		emit(ctx.code, {mod_rm(.Direct, lhs, dst)})
	case .Shl ..= .U_Shr:
		// shl/shr $dst, cl
		dst := reg_of(ctx, node.inps[0])
		rx := rex(RAX, dst, RAX, backend.DT_SIZE[node.dt] == 8)
		op := OPCODE_TABLE[xtype(node)].ext
		emit_sized_opcode(ctx.code, node.dt, rx, 0xd3)
		emit(ctx.code, {mod_sm(.Direct, op, dst)})
	case .X64_Neg ..= .X64_Not:
		assert(mem_op.mem_mode == .Dest)
		dis := mem_op.dis
		dst, sdis, id := reg_and_disp_of(ctx, node.inps[2])

		op := DEST_MODE_OPCODE_TABLE[xtype(node)]

		// neg/not [$dst + $idx * $scl + $sdis + $dis]
		rx := rex(RAX, dst, idx, backend.DT_SIZE[mem_op.dt] == 8)
		emit_sized_opcode(ctx.code, mem_op.dt, rx, op.opcode)
		emit_indirect_addr(ctx, op.ext, dst, idx, scl, dis + sdis, id)
	case .Neg ..= .Not:
		// neg/not $dst
		dst := reg_of(ctx, node.inps[0])
		op := OPCODE_TABLE[xtype(node)]
		rx := rex(RAX, dst, RAX, backend.DT_SIZE[node.dt] == 8)
		emit_sized_opcode(ctx.code, node.dt, rx, op.opcode)
		emit(ctx.code, {mod_sm(.Direct, op.ext, dst)})
	case .Mul:
		dst := reg_of(ctx, node.inps[0])
		rhs := reg_of(ctx, node.inps[1])

		// imul $dst, $rhs
		rx := rex(dst, rhs, RAX, backend.DT_SIZE[node.dt] == 8)
		emit_extended_sized_opcode(ctx.code, node.dt, rx, 0xaf)
		emit(ctx.code, {mod_rm(.Direct, dst, rhs)})
	case .X64_Mul:
		dst := reg_of(ctx, instr)
		lhs := reg_of(ctx, node.inps[0])
		imm := mem_op.imm

		// imul $dst, $lhs, $imm
		rx := rex(dst, lhs, RAX, backend.DT_SIZE[node.dt] == 8)
		emit_sized_opcode(ctx.code, node.dt, rx, 0x69)
		emit(ctx.code, {mod_rm(.Direct, dst, lhs)})
		emit_imm_for_dt(ctx.code, node.dt, imm)
	case .X64_Mul8:
		// imul $op
		dst := reg_of(ctx, node.inps[0])
		rx := rex(RAX, dst, NO_INDEX, false)
		emit(ctx.code, {rx, 0xf6, mod_sm(.Direct, 0b101, dst)})
	case .F_Add ..= .F_Div:
		// dst == lhs (in place); op dst, rhs
		dst := reg_of(ctx, node.inps[0])
		rhs := reg_of(ctx, node.inps[1])

		rx := rex(dst, rhs, RAX, false)
		op := OPCODE_TABLE[xtype(node)].opcode
		emit(ctx.code, {pfx, rx, 0x0f, op, mod_rm(.Direct, dst, rhs)})
	case .X64_Fma_213:
		switch mem_op.mem_mode {
		case .None:
			dst := reg_of(ctx, node.inps[0])
			smul := reg_of(ctx, node.inps[1])
			sadd := reg_of(ctx, node.inps[2])
			emit(
				ctx.code,
				{
					vex3(dst, sadd, idx, smul, wide, ._0F38, .P66, false),
					0xa9,
					mod_rm(.Direct, dst, sadd),
				},
			)
		case .Src:
			dst := reg_of(ctx, node.inps[1])
			smul := reg_of(ctx, node.inps[2])
			mem_idx := graph_get(ctx, node.inps[0]).itype == .Global ? 0 : 2
			sadd, sdis, id := reg_and_disp_of(ctx, node.inps[mem_idx])
			dis := mem_op.dis
			emit(
				ctx.code,
				{vex3(dst, sadd, idx, smul, wide, ._0F38, .P66, false), 0xa9},
			)
			emit_indirect_addr(ctx, dst, sadd, idx, scl, sdis + dis, id)
			if mem_idx == 2 {
				panic("bra")
			}
		case .Dest:
			panic("")
		}
	case .X64_F_Add ..= .X64_F_Div:
		is_cload := graph_get(ctx, node.inps[0]).itype == .Global
		mem_idx := is_cload ? 0 : 2

		dst := reg_of(ctx, node.inps[mem_idx + 1])
		bse, sdis, id := reg_and_disp_of(ctx, node.inps[mem_idx])
		dis := mem_op.dis

		// op dst, [$bse + $idx * $scl + $sdis + $dis].
		rx := rex(dst, bse, idx, false)
		op := SRC_MODE_OPCODE_TABLE[xtype(node)].opcode
		emit(ctx.code, {pfx, rx, 0x0f, op})
		emit_indirect_addr(ctx, dst, bse, idx, scl, dis + sdis, id)
	case .F_Eq ..= .F_Ge, .X64_F_Eq ..= .X64_F_Ge:
		switch mem_op.mem_mode {
		case .Dest:
			panic("never")
		case .Src:
			is_cload := graph_get(ctx, node.inps[0]).itype == .Global

			lhs_idx := is_cload ? 1 : 3
			lhs := reg_of(ctx, node.inps[lhs_idx])
			mem_idx := is_cload ? 0 : 2
			bse, sdis, id := reg_and_disp_of(ctx, node.inps[mem_idx])
			odt := graph_get(ctx, node.inps[lhs_idx]).dt
			dis := mem_op.dis

			// ucomiss/ucomisd $lhs, [$rhs + $idx * scl + $sdis + $dis]
			if odt == .F64 do emit(ctx.code, {0x66})
			rx := rex(lhs, bse, idx, false)
			emit(ctx.code, {rx, 0x0f, 0x2e})
			emit_indirect_addr(ctx, lhs, bse, idx, scl, dis + sdis, id)
		case .None:
			// ucomiss/ucomisd $lhs, $rhs
			lhs := reg_of(ctx, node.inps[0])
			rhs := reg_of(ctx, node.inps[1])
			odt := graph_get(ctx, node.inps[0]).dt

			a, b := lhs, rhs
			#partial switch xtype(node) {
			case .F_Lt, .F_Le:
				a, b = rhs, lhs
			}

			// [66] 0F 2E /r  (ucomisd needs the 0x66 prefix, ucomiss none)
			if odt == .F64 do emit(ctx.code, {0x66})
			rx := rex(a, b, RAX, false)
			emit(ctx.code, {rx, 0x0f, 0x2e, mod_rm(.Direct, a, b)})
		}

		if node.dt != .Void {
			next_sloc(ctx)

			setcc: u8 = OPCODE_TABLE[xtype(node)].opcode

			dst := reg_of(ctx, instr)
			// setcc $dst
			rxs := rex(RAX, dst, RAX, true)
			emit(ctx.code, {rxs, 0x0F, setcc, mod_sm(.Direct, 0b000, dst)})

			next_sloc(ctx)

			// movzx $dst, $dst
			rxz := rex(dst, dst, RAX, true)
			emit(ctx.code, {rxz, 0x0F, 0xB6, mod_rm(.Direct, dst, dst)})
		}
	case .U_F_From_I:
		panic("TODO")
	case .F_From_I:
		// cvtsi2ss/cvtsi2sd $dst(xmm), $src(gpr)
		dst := reg_of(ctx, instr)
		src := reg_of(ctx, node.inps[0])
		sdt := graph_get(ctx, node.inps[0]).dt
		rx := rex(dst, src, RAX, backend.DT_SIZE[sdt] == 8)
		emit(ctx.code, {pfx, rx, 0x0f, 0x2a, mod_rm(.Direct, dst, src)})
	case .F_To_I:
		// cvttss2si/cvttsd2si $dst(gpr), $src(xmm)
		dst := reg_of(ctx, instr)
		src := reg_of(ctx, node.inps[0])
		sdt := graph_get(ctx, node.inps[0]).dt
		pfx: u8 = sdt == .F64 ? 0xF2 : 0xF3
		rx := rex(dst, src, RAX, backend.DT_SIZE[node.dt] == 8)
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
		rx := rex(RAX, rhs, RAX, backend.DT_SIZE[node.dt] == 8)
		emit_sized_opcode(ctx.code, node.dt, rx, 0xf7)
		emit(ctx.code, {mod_sm(.Direct, 0b111, rhs)})
		if node.itype == .Rem && node.dt == .I8 {
			next_sloc(ctx)
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

		next_sloc(ctx)

		// div $rhs
		rx := rex(RAX, rhs, RAX, backend.DT_SIZE[node.dt] == 8)
		emit_sized_opcode(ctx.code, node.dt, rx, 0xf7)
		emit(ctx.code, {mod_sm(.Direct, 0b110, rhs)})
		if node.itype == .U_Rem && node.dt == .I8 {
			next_sloc(ctx)

			// movsx edx, ah
			emit(ctx.code, {0x0F, 0xBE, 0xD4})
		}
	case .Split:
		dst := reg_of(ctx, instr)
		src := reg_of(ctx, node.inps[0])
		dst_off := spill_slot_offset(ctx, dst)
		src_off := spill_slot_offset(ctx, src)
		assert(dst.kind == src.kind)

		d_spill := dst.index >= GPA_REG_COUNT
		s_spill := src.index >= GPA_REG_COUNT

		if dst.kind == .Vector && node.dt == .V128 {
			if d_spill && s_spill {
				panic("no")
			} else if d_spill {
				// movups [rsp + $dst_off], $src
				emit(ctx.code, {rex(src, RSP, RAX, false), 0x0f, 0x11})
				spill_indirect_addr(ctx, src, dst_off)
			} else if s_spill {
				// movups $dst, [rsp + $src_off]
				emit(ctx.code, {rex(dst, RSP, RAX, false), 0x0f, 0x10})
				spill_indirect_addr(ctx, dst, src_off)
			} else {
				// movups $dst, $src
				rx := rex(dst, src, RAX, false)
				emit(ctx.code, {rx, 0x0f, 0x10, mod_rm(.Direct, dst, src)})
			}
			break
		}

		if dst.kind == .Vector {
			// movss/movsd based moves for xmm live ranges
			pfx: u8 = node.dt == .F64 ? 0xF2 : 0xF3

			if d_spill && s_spill {
				// pure memory-to-memory move: copy the 8-byte spill slot via
				// the stack with push/pop, which never touches an xmm register.
				// (slots are 8-byte sized, so this is correct for f32 too.)
				// push [rsp + $src_off]
				emit(ctx.code, {0xff})
				spill_indirect_addr(ctx, Reg(0b110), src_off)
				next_sloc(ctx)

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
				rx := rex(dst, src, RAX, false)
				emit(
					ctx.code,
					{pfx, rx, 0x0f, 0x10, mod_rm(.Direct, dst, src)},
				)
			}
			break
		}

		if d_spill && s_spill {
			// push [rsp + $src_offset]
			emit(ctx.code, {0xff})
			spill_indirect_addr(ctx, Reg(0b110), src_off)
			next_sloc(ctx)

			// pop [rsp + $dst_off]
			emit(ctx.code, {0x8F})
			spill_indirect_addr(ctx, Reg(0b000), dst_off)
		} else if d_spill {
			// mov [rsp + $dst_offset], $src
			fmt.assertf(int(src) < 16, "%v", node.node)

			emit(ctx.code, {rex(src, RSP, RAX, true), 0x89})
			spill_indirect_addr(ctx, src, dst_off)
		} else if s_spill {
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
				(i32(reg.index) - i32(param_count) - GPA_REG_COUNT) *
					SPILL_SLOT_SIZE[reg.kind] \
			)
		}
	case .Return:
		if backend.graph_has_unreachable_return(ctx) do break

		emit_cfi(ctx, .Remember_State)

		cfa := u32(ctx.pushed) + X64_CFI_SPEC.initial_cfa_offset

		if ctx.stack_size != 0 {
			// sub rsp, -$ctx.stack_size
			emit_imm_op(ctx.code, 0x81, 0b000, RSP, ctx.stack_size)
			next_sloc(ctx)
			emit_cfi(ctx, .Def_Cfa_Offset, arg = cfa)
		}

		#reverse for reg in ctx.callee_saved[.General] {
			if bit_arr.contains(ctx.used, int(reg)) {
				// pop $reg
				emit_single_op(ctx.code, 0x58, reg)
				next_sloc(ctx)

				cfa -= 8
				emit_cfi(ctx, .Restore_Reg, reg = DWARF_GPR[reg.index])
				emit_cfi(ctx, .Def_Cfa_Offset, arg = cfa)
			}
		}

		// ret
		emit(ctx.code, {0xc3})
		emit_cfi(ctx, .Restore_State)
	}

	next_sloc(ctx)
}

reg_of :: proc(ctx: backend.Codegen_Emit_Ctx, id: backend.Node_ID) -> Reg {
	node := graph_get(ctx, id)
	fmt.assertf(int(node.gvn) < len(ctx.allocs), "%v", node)
	return ctx.allocs[node.gvn]
}

reg_and_disp_of :: proc(ctx: ^Ctx, id: backend.Node_ID) -> (Reg, i32, u32) {
	node := graph_get(ctx, id)
	if node.itype == .Global {
		tup: ^backend.Tup = backend.graph_extra(ctx, node, backend.Tup)

		if tup.is_inline {
			tup.idx = emit_big_constant(
				ctx,
				tup.align,
				([^]u8)(node)[backend.graph_size(ctx, node.rtype):][:tup.size],
			)
		}

		// bias by one so that global 0 is distinguishable from the "no
		// relocation" sentinel used by emit_indirect_addr
		return RIP, 0, tup.idx + 1
	}
	if node.itype == .Local {
		return RSP,
			i32(backend.graph_extra(ctx, node, backend.Local).offset),
			0
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
	kind: backend.Reloc_Kind = .Global,
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
		if rip_relative do backend.emit_anys(ctx.code, u32(dis - timm))
	case .Indirect_Disp8:
		emit(ctx.code, {u8(dis)})
	case .Indirect_Disp32:
		backend.emit_anys(ctx.code, u32(dis))
	case .Direct:
		fallthrough
	case:
		panic("unreachable")
	}

	if reloc != 0 {
		backend.add_reloc(ctx.relocs)^ = {
			offset = u32(ctx.code.pos - ctx.code_start),
			kind   = kind,
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
		backend.emit_anys(code, u32(imm))
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

VEX3 :: struct {
	b0, b1, b2: u8,
}

Vex_Map :: enum u8 {
	_0F   = 1,
	_0F38 = 2,
	_0F3A = 3,
}

Vex_PP :: enum u8 {
	None = 0,
	P66  = 1,
	F3   = 2,
	F2   = 3,
}

vex3 :: proc(
	reg, ptr, idx, vvvv: Reg,
	wide: bool,
	mapa: Vex_Map,
	pp: Vex_PP,
	l: bool,
) -> (
	b0: u8 = 0xC4,
	b1: u8,
	b2: u8,
) {
	if reg.index < 8 do b1 |= 0b1000_0000
	if idx.index < 8 do b1 |= 0b0100_0000
	if ptr.index < 8 do b1 |= 0b0010_0000

	b1 |= u8(mapa) & 0b1_1111

	if wide do b2 |= 0b1000_0000

	b2 |= (u8(~vvvv.index) & 0b1111) << 3

	if l do b2 |= 0b0000_0100

	b2 |= u8(pp)

	return 0xC4, b1, b2
}

emit_imm_for_dt :: proc(
	code: ^arna.Allocator,
	dt: backend.Node_Datatype,
	imm: i32,
) {
	switch dt {
	case .Void:
		panic("")
	case .I8:
		backend.emit_anys(code, i8(imm))
	case .I16:
		backend.emit_anys(code, i16(imm))
	case .I64, .I32, .F32:
		backend.emit_anys(code, imm)
	case .F64, .V128, .V256, .V512:
		panic("no")
	}
}

emit_extended_sized_opcode :: proc(
	code: ^arna.Allocator,
	dt: backend.Node_Datatype,
	rx: u8,
	op: u8,
) {
	switch dt {
	case .Void:
		panic("")
	case .I8:
		emit(code, {rx, 0x0f, op - 1})
	case .I16:
		emit(code, {0x66, rx, 0x0f, op})
	case .I32, .I64:
		emit(code, {rx, 0x0f, op})
	case .F32, .F64, .V128, .V256, .V512:
		panic("no")
	}
}

emit_sized_opcode :: proc(
	code: ^arna.Allocator,
	dt: backend.Node_Datatype,
	rx: u8,
	op: u8,
) {
	switch dt {
	case .Void:
		panic("")
	case .I8:
		emit(code, {rx, op - 1})
	case .I16:
		emit(code, {0x66, rx, op})
	case .I32, .I64, .F32:
		emit(code, {rx, op})
	case .F64, .V128, .V256, .V512:
		panic("no")
	}
}
