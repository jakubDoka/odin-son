package bac_amd64
import bac ".."
Reg_Kind :: bac.Reg_Kind
Class_Flag :: bac.Class_Flag
import "base:intrinsics"// NOTE: this file is generated, see: /home/mlokis/personal/odin/jit/bac/meta2/meta2.odin(125:3)

@(tag = "api", rodata, export, link_name = "bac_amd64_SPEC")SPEC := bac.Node_Spec{
	call_clobbers = {
		{69575, 65535},
		{67587, 0},
	},
	datatype_to_reg_kind = {.Void = 0, .Mem = 0, .I8 = 0, .I16 = 0, .I32 = 0, .I64 = 0, .F32 = 1, .F64 = 1, .V128 = 1, .V256 = 1, .V512 = 1},
	spill_boundary = {17, 16},
	collect_meta = collect_meta,
	emit_function = emit_function,
	peep = peep_inst,
	post_schedule_peep = post_schedule_peep_inst,
	inheritance_table = intrinsics.concatenate(bac.INHERITANCE_TABLE, []u16{
		0b10000000, // AMD64_Add
		0b10000000, // AMD64_Sub
		0b10000000, // AMD64_And
		0b10000000, // AMD64_Or
		0b10000000, // AMD64_Xor
		0b10000000, // AMD64_Eq
		0b10000000, // AMD64_Ne
		0b10000000, // AMD64_Le
		0b10000000, // AMD64_Lt
		0b10000000, // AMD64_Gt
		0b10000000, // AMD64_Ge
		0b10000000, // AMD64_U_Lt
		0b10000000, // AMD64_U_Gt
		0b10000000, // AMD64_U_Le
		0b10000000, // AMD64_U_Ge
		0b10000000, // AMD64_Shl
		0b10000000, // AMD64_Shr
		0b10000000, // AMD64_U_Shr
		0b10000000, // AMD64_Mul
		0b10000000, // AMD64_Div
		0b10000000, // AMD64_Lea
		0b10000000, // AMD64_Load
		0b10000000, // AMD64_Store
		0b10000000, // AMD64_Neg
		0b10000000, // AMD64_Not
		0b10, // AMD64_Mul8
		0b10000000, // AMD64_Fma_213
		0b10, // AMD64_Pcmpeq
		0b10000000, // AMD64_Padd
		0b10000000, // AMD64_Psub
		0b10000000, // AMD64_Pshufd
		0b10000000, // AMD64_Pshuflw
		0b10, // AMD64_Psadbw
		0b10000000, // AMD64_Pshufb
		0b10000000, // AMD64_Pextr
	}),
	node_extra_sizes = intrinsics.concatenate(bac.NODE_EXTRA_SIZES, []u8{
		3, // AMD64_Add -> Mem_Op
		3, // AMD64_Sub -> Mem_Op
		3, // AMD64_And -> Mem_Op
		3, // AMD64_Or -> Mem_Op
		3, // AMD64_Xor -> Mem_Op
		3, // AMD64_Eq -> Mem_Op
		3, // AMD64_Ne -> Mem_Op
		3, // AMD64_Le -> Mem_Op
		3, // AMD64_Lt -> Mem_Op
		3, // AMD64_Gt -> Mem_Op
		3, // AMD64_Ge -> Mem_Op
		3, // AMD64_U_Lt -> Mem_Op
		3, // AMD64_U_Gt -> Mem_Op
		3, // AMD64_U_Le -> Mem_Op
		3, // AMD64_U_Ge -> Mem_Op
		3, // AMD64_Shl -> Mem_Op
		3, // AMD64_Shr -> Mem_Op
		3, // AMD64_U_Shr -> Mem_Op
		3, // AMD64_Mul -> Mem_Op
		3, // AMD64_Div -> Mem_Op
		3, // AMD64_Lea -> Mem_Op
		3, // AMD64_Load -> Mem_Op
		3, // AMD64_Store -> Mem_Op
		3, // AMD64_Neg -> Mem_Op
		3, // AMD64_Not -> Mem_Op
		0, // AMD64_Mul8 -> No_Extra
		3, // AMD64_Fma_213 -> Mem_Op
		0, // AMD64_Pcmpeq -> No_Extra
		3, // AMD64_Padd -> Mem_Op
		3, // AMD64_Psub -> Mem_Op
		3, // AMD64_Pshufd -> Mem_Op
		3, // AMD64_Pshuflw -> Mem_Op
		0, // AMD64_Psadbw -> No_Extra
		3, // AMD64_Pshufb -> Mem_Op
		3, // AMD64_Pextr -> Mem_Op
	}),
	node_flags = intrinsics.concatenate(bac.NODE_FLAGS, []bac.Class_Flags{
		{}, // AMD64_Add
		{}, // AMD64_Sub
		{}, // AMD64_And
		{}, // AMD64_Or
		{}, // AMD64_Xor
		{}, // AMD64_Eq
		{}, // AMD64_Ne
		{}, // AMD64_Le
		{}, // AMD64_Lt
		{}, // AMD64_Gt
		{}, // AMD64_Ge
		{}, // AMD64_U_Lt
		{}, // AMD64_U_Gt
		{}, // AMD64_U_Le
		{}, // AMD64_U_Ge
		{}, // AMD64_Shl
		{}, // AMD64_Shr
		{}, // AMD64_U_Shr
		{}, // AMD64_Mul
		{}, // AMD64_Div
		{}, // AMD64_Lea
		{Class_Flag.Load}, // AMD64_Load
		{Class_Flag.Store}, // AMD64_Store
		{}, // AMD64_Neg
		{}, // AMD64_Not
		{Class_Flag.Interned}, // AMD64_Mul8
		{}, // AMD64_Fma_213
		{Class_Flag.Interned}, // AMD64_Pcmpeq
		{}, // AMD64_Padd
		{}, // AMD64_Psub
		{}, // AMD64_Pshufd
		{}, // AMD64_Pshuflw
		{}, // AMD64_Psadbw
		{}, // AMD64_Pshufb
		{}, // AMD64_Pextr
	}),
	node_extra_types = ({}) when #config(NO_FMT, false) else (intrinsics.concatenate(bac.NODE_EXTRA_TYPES, []typeid{
		Mem_Op,
		Mem_Op,
		Mem_Op,
		Mem_Op,
		Mem_Op,
		Mem_Op,
		Mem_Op,
		Mem_Op,
		Mem_Op,
		Mem_Op,
		Mem_Op,
		Mem_Op,
		Mem_Op,
		Mem_Op,
		Mem_Op,
		Mem_Op,
		Mem_Op,
		Mem_Op,
		Mem_Op,
		Mem_Op,
		Mem_Op,
		Mem_Op,
		Mem_Op,
		Mem_Op,
		Mem_Op,
		bac.No_Extra,
		Mem_Op,
		bac.No_Extra,
		Mem_Op,
		Mem_Op,
		Mem_Op,
		Mem_Op,
		bac.No_Extra,
		Mem_Op,
		Mem_Op,
	})),
	node_kind = nil when #config(NO_FMT, false) else Node_Type,
}

Node_Type :: enum u16 {
	Nil,
	Entry,
	Then,
	Else,
	Region,
	Loop,
	Call_End,
	End,
	Dbg_Sym_Decl,
	Dbg_Sym_Update,
	Dbg_Scope,
	If,
	Jump,
	Trap,
	Call,
	Always,
	Return,
	Poison,
	Mem,
	Split_Mem,
	Merge_Mem,
	Sym,
	Local,
	Global,
	Param,
	Ret,
	Phi,
	CInt,
	Add,
	Sub,
	And,
	Or,
	Xor,
	Eq,
	Ne,
	Le,
	Lt,
	Gt,
	Ge,
	U_Lt,
	U_Gt,
	U_Le,
	U_Ge,
	Shl,
	Shr,
	U_Shr,
	Mul,
	Div,
	U_Div,
	Rem,
	U_Rem,
	And_Not,
	Split,
	Local_Addr,
	Global_Addr,
	Proc_Addr,
	Copy,
	Set,
	Store,
	Load,
	Neg,
	Not,
	Cast,
	Conv,
	U_Conv,
	Splat,
	Ctz,
	Simd_Extract_Lsbs,
	Simd_Extract_Msbs,
	Simd_Reduce_Add_Bisect,
	Select,
	Thread_Id,
	Lane_Id,
	Uniform_Addr,
	AMD64_Add,
	AMD64_Sub,
	AMD64_And,
	AMD64_Or,
	AMD64_Xor,
	AMD64_Eq,
	AMD64_Ne,
	AMD64_Le,
	AMD64_Lt,
	AMD64_Gt,
	AMD64_Ge,
	AMD64_U_Lt,
	AMD64_U_Gt,
	AMD64_U_Le,
	AMD64_U_Ge,
	AMD64_Shl,
	AMD64_Shr,
	AMD64_U_Shr,
	AMD64_Mul,
	AMD64_Div,
	AMD64_Lea,
	AMD64_Load,
	AMD64_Store,
	AMD64_Neg,
	AMD64_Not,
	AMD64_Mul8,
	AMD64_Fma_213,
	AMD64_Pcmpeq,
	AMD64_Padd,
	AMD64_Psub,
	AMD64_Pshufd,
	AMD64_Pshuflw,
	AMD64_Psadbw,
	AMD64_Pshufb,
	AMD64_Pextr,
}

peep_inst :: proc(ctx: bac.Peep_Ctx, node: bac.Expanded_Node) -> Maybe(bac.Node_ID) {
	res := peep(ctx, node, struct{}{})
	#assert(type_of(res) == Maybe(bac.Node_ID))
	return res
}
post_schedule_peep_inst :: proc(
	ctx: bac.PS_Peep_Ctx, node: bac.Expanded_Node) -> bac.Node_ID {
	return post_schedule_peep(ctx, node, struct{}{})
}


collect_meta :: proc(ctx: ^bac.Proc,
	ra: ^bac.Regalloc, sched: ^bac.Schedule) -> ([]bac.Regalloc_Node_Meta, int) {

	meta_of_ :: proc(ctx: ^bac.Proc, ra: ^bac.Regalloc,
		node: bac.Expanded_Node) -> bac.Regalloc_Node_Meta {
		return meta_of(ctx, ra, node, struct{}{})
	}
	return bac.regalloc_collect_meta(ctx, ra, sched, meta_of_)
}

add_amd64_psadbw :: #force_inline proc(prc: ^bac.Proc, name: string, dt: bac.Node_Datatype, lhs: bac.Node_ID, rhs: bac.Node_ID) -> (_id: bac.Node_ID) {
	return bac.add_raw(prc, name, u16(Node_Type.AMD64_Psadbw), dt, {lhs, rhs})
}

inherit_idx_of :: #force_inline proc($T: typeid) -> u8 {
	when false {}
	else when T == bac.CInt {return 6}
	else when T == bac.Call {return 3}
	else when T == bac.Cfg {return 0}
	else when T == bac.Dbg_Sym {return 2}
	else when T == bac.Local {return 4}
	else when T == Mem_Op {return 7}
	else when T == bac.No_Extra {return 1}
	else when T == bac.Tup {return 5}
	else {#panic(`the passed type is not subclass of anything`)}
}
#assert(size_of(bac.CInt) % bac.PRECISION == 0)
#assert(size_of(bac.Call) % bac.PRECISION == 0)
#assert(size_of(bac.Cfg) % bac.PRECISION == 0)
#assert(size_of(bac.Dbg_Sym) % bac.PRECISION == 0)
#assert(size_of(bac.Local) % bac.PRECISION == 0)
#assert(size_of(Mem_Op) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.Tup) % bac.PRECISION == 0)

@(rodata) GPA_MASK := [?]i64{transmute(i64)u64(0x000000000000ffef)}
GPA_MASK_IDX :: bac.RM_Intern_Idx{index = 0, kind = 0}
@(rodata) GPA_MASKS := [6]bac.RM_Intern_Idx{0 ..< 6 = GPA_MASK_IDX}

@(rodata) GPA_SPILL_MASK := [?]i64{transmute(i64)u64(0xfffffffffffeffef)}
GPA_SPILL_MASK_IDX :: bac.RM_Intern_Idx{index = 1, kind = 0}
@(rodata) GPA_SPILL_MASKS := [6]bac.RM_Intern_Idx{0 ..< 6 = GPA_SPILL_MASK_IDX}

@(rodata) GPA_SPLIT_MASK := [?]i64{transmute(i64)u64(0xffffffffffffffef)}
GPA_SPLIT_MASK_IDX :: bac.RM_Intern_Idx{index = 2, kind = 0}
@(rodata) GPA_SPLIT_MASKS := [6]bac.RM_Intern_Idx{0 ..< 6 = GPA_SPLIT_MASK_IDX}

@(rodata) XMM_MASK := [?]i64{transmute(i64)u64(0x000000000000ffff)}
XMM_MASK_IDX :: bac.RM_Intern_Idx{index = 0, kind = 1}
@(rodata) XMM_MASKS := [6]bac.RM_Intern_Idx{0 ..< 6 = XMM_MASK_IDX}

@(rodata) XMM_SPILL_MASK := [?]i64{transmute(i64)u64(0xffffffffffffffff)}
XMM_SPILL_MASK_IDX :: bac.RM_Intern_Idx{index = 1, kind = 1}
@(rodata) XMM_SPILL_MASKS := [6]bac.RM_Intern_Idx{0 ..< 6 = XMM_SPILL_MASK_IDX}

seed_rm_interner :: proc(ra: ^bac.Regalloc) {
	ra.mask_len = MASK_SIZE
	bac.rm_intern_slice(ra, 0, GPA_MASK[:])
	bac.rm_intern_slice(ra, 0, GPA_SPILL_MASK[:])
	bac.rm_intern_slice(ra, 0, GPA_SPLIT_MASK[:])
	bac.rm_intern_slice(ra, 1, XMM_MASK[:])
	bac.rm_intern_slice(ra, 1, XMM_SPILL_MASK[:])
}

atype :: #force_inline proc(node: bac.Expanded_Node) -> Node_Type {
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
