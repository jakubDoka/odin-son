package bac_arm
import bac ".."
Reg_Kind :: bac.Reg_Kind
Class_Flag :: bac.Class_Flag
import "base:intrinsics"// NOTE: this file is generated: 

@(tag = "api", rodata, export, link_name = "bac_arm_SPEC")SPEC := bac.Node_Spec{
	call_clobbers = {
		{4295491583, 4294902015},
	},
	datatype_to_reg_kind = {.Void = 0, .Mem = 0, .I8 = 0, .I16 = 0, .I32 = 0, .I64 = 0, .F32 = 1, .F64 = 1, .V128 = 1, .V256 = 1, .V512 = 1},
	spill_boundary = {33, 32},
	collect_meta = collect_meta,
	emit_function = emit_function,
	peep = peep_inst,
	post_schedule_peep = post_schedule_peep_inst,
	inheritance_table = intrinsics.concatenate(bac.INHERITANCE_TABLE, []u16{
		0b10, // Msub
		0b10, // Cmlt
		0b10000000, // Ext
		0b10, // Zip1
		0b10, // Addv128
		0b10000000, // Umov
		0b10, // Lslv
		0b10, // Asrv
		0b10, // Lsrv
	}),
	node_extra_sizes = intrinsics.concatenate(bac.NODE_EXTRA_SIZES, []u8{
		0, // Msub -> No_Extra
		0, // Cmlt -> No_Extra
		1, // Ext -> Arm_Op
		0, // Zip1 -> No_Extra
		0, // Addv128 -> No_Extra
		1, // Umov -> Arm_Op
		0, // Lslv -> No_Extra
		0, // Asrv -> No_Extra
		0, // Lsrv -> No_Extra
	}),
	node_flags = intrinsics.concatenate(bac.NODE_FLAGS, []bac.Class_Flags{
		{}, // Msub
		{}, // Cmlt
		{}, // Ext
		{}, // Zip1
		{}, // Addv128
		{}, // Umov
		{}, // Lslv
		{}, // Asrv
		{}, // Lsrv
	}),
	node_extra_types = ({}) when #config(NO_FMT, false) else (intrinsics.concatenate(bac.NODE_EXTRA_TYPES, []typeid{
		bac.No_Extra,
		bac.No_Extra,
		Arm_Op,
		bac.No_Extra,
		bac.No_Extra,
		Arm_Op,
		bac.No_Extra,
		bac.No_Extra,
		bac.No_Extra,
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

add_msub :: #force_inline proc(prc: ^bac.Proc, name: string, dt: bac.Node_Datatype, multiplicant: bac.Node_ID, multiplier: bac.Node_ID, subtractant: bac.Node_ID) -> (_id: bac.Node_ID) {
	return bac.add_raw(prc, name, u16(Node_Type.Msub), dt, {multiplicant, multiplier, subtractant})
}
add_cmlt :: #force_inline proc(prc: ^bac.Proc, name: string, lhs: bac.Node_ID, lane: bac.Lane_Type = {}) -> (_id: bac.Node_ID) {
	return bac.add_raw(prc, name, u16(Node_Type.Cmlt), .V128, {lhs}, {lane = lane,})
}
add_ext :: #force_inline proc(prc: ^bac.Proc, name: string, lhs: bac.Node_ID, rhs: bac.Node_ID, aux: u32, lane: bac.Lane_Type = {}) -> (_id: bac.Node_ID) {
	(^Arm_Op)(bac.get_next_extra_slot(prc, u16(Node_Type.Ext), 0))^ = {
		aux = aux,
	}
	return bac.add_raw(prc, name, u16(Node_Type.Ext), .V128, {lhs, rhs}, {lane = lane,})
}
add_zip1 :: #force_inline proc(prc: ^bac.Proc, name: string, lsh: bac.Node_ID, rhs: bac.Node_ID, lane: bac.Lane_Type = {}) -> (_id: bac.Node_ID) {
	return bac.add_raw(prc, name, u16(Node_Type.Zip1), .V128, {lsh, rhs}, {lane = lane,})
}
add_addv128 :: #force_inline proc(prc: ^bac.Proc, name: string, dt: bac.Node_Datatype, vec: bac.Node_ID, lane: bac.Lane_Type = {}) -> (_id: bac.Node_ID) {
	return bac.add_raw(prc, name, u16(Node_Type.Addv128), dt, {vec}, {lane = lane,})
}
add_umov :: #force_inline proc(prc: ^bac.Proc, name: string, dt: bac.Node_Datatype, vec: bac.Node_ID, aux: u32) -> (_id: bac.Node_ID) {
	(^Arm_Op)(bac.get_next_extra_slot(prc, u16(Node_Type.Umov), 0))^ = {
		aux = aux,
	}
	return bac.add_raw(prc, name, u16(Node_Type.Umov), dt, {vec})
}

inherit_idx_of :: #force_inline proc($T: typeid) -> u8 {
	when false {}
	else when T == Arm_Op {return 7}
	else when T == bac.CInt {return 6}
	else when T == bac.Call {return 3}
	else when T == bac.Cfg {return 0}
	else when T == bac.Dbg_Sym {return 2}
	else when T == bac.Local {return 4}
	else when T == bac.No_Extra {return 1}
	else when T == bac.Tup {return 5}
	else {#panic(`the passed type is not subclass of anything`)}
}
#assert(size_of(Arm_Op) % bac.PRECISION == 0)
#assert(size_of(bac.CInt) % bac.PRECISION == 0)
#assert(size_of(bac.Call) % bac.PRECISION == 0)
#assert(size_of(bac.Cfg) % bac.PRECISION == 0)
#assert(size_of(bac.Dbg_Sym) % bac.PRECISION == 0)
#assert(size_of(bac.Local) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.Tup) % bac.PRECISION == 0)

@(rodata) GPA_MASK := [?]i64{transmute(i64)u64(0x000000003fffffff)}
GPA_MASK_IDX :: bac.RM_Intern_Idx{index = 0, kind = 0}
@(rodata) GPA_MASKS := [6]bac.RM_Intern_Idx{0 ..< 6 = GPA_MASK_IDX}

@(rodata) GPA_SPILL_MASK := [?]i64{transmute(i64)u64(0xfffffffe3fffffff)}
GPA_SPILL_MASK_IDX :: bac.RM_Intern_Idx{index = 1, kind = 0}
@(rodata) GPA_SPILL_MASKS := [6]bac.RM_Intern_Idx{0 ..< 6 = GPA_SPILL_MASK_IDX}

@(rodata) GPA_SPLIT_MASK := [?]i64{transmute(i64)u64(0xffffffff3fffffff)}
GPA_SPLIT_MASK_IDX :: bac.RM_Intern_Idx{index = 2, kind = 0}
@(rodata) GPA_SPLIT_MASKS := [6]bac.RM_Intern_Idx{0 ..< 6 = GPA_SPLIT_MASK_IDX}

@(rodata) VEC_MASK := [?]i64{transmute(i64)u64(0x00000000ffffffff)}
VEC_MASK_IDX :: bac.RM_Intern_Idx{index = 0, kind = 1}
@(rodata) VEC_MASKS := [6]bac.RM_Intern_Idx{0 ..< 6 = VEC_MASK_IDX}

@(rodata) VEC_SPILL_MASK := [?]i64{transmute(i64)u64(0xffffffffffffffff)}
VEC_SPILL_MASK_IDX :: bac.RM_Intern_Idx{index = 1, kind = 1}
@(rodata) VEC_SPILL_MASKS := [6]bac.RM_Intern_Idx{0 ..< 6 = VEC_SPILL_MASK_IDX}

seed_rm_interner :: proc(ra: ^bac.Regalloc) {
	ra.mask_len = MASK_SIZE
	bac.rm_intern_slice(ra, 0, GPA_MASK[:])
	bac.rm_intern_slice(ra, 0, GPA_SPILL_MASK[:])
	bac.rm_intern_slice(ra, 0, GPA_SPLIT_MASK[:])
	bac.rm_intern_slice(ra, 1, VEC_MASK[:])
	bac.rm_intern_slice(ra, 1, VEC_SPILL_MASK[:])
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
