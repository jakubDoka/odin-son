package bac_arm
import bac ".."
Reg_Kind :: bac.Reg_Kind
Class_Flag :: bac.Class_Flag
// NOTE: this file is generated: 

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
	inheritance_table = {
		0b1, // Nil
		0b1, // Entry
		0b1, // Then
		0b1, // Else
		0b1, // Region
		0b1, // Loop
		0b1, // Call_End
		0b10, // End
		0b100, // Dbg_Sym_Decl
		0b10, // Dbg_Sym_Update
		0b10, // Dbg_Scope
		0b1, // If
		0b1, // Jump
		0b1, // Trap
		0b1001, // Call
		0b1, // Always
		0b1, // Return
		0b10, // Poison
		0b10, // Mem
		0b10, // Split_Mem
		0b10, // Merge_Mem
		0b10, // Sym
		0b10000, // Local
		0b100000, // Global
		0b100000, // Param
		0b100000, // Ret
		0b10, // Phi
		0b1000000, // CInt
		0b10, // Add
		0b10, // Sub
		0b10, // And
		0b10, // Or
		0b10, // Xor
		0b10, // Eq
		0b10, // Ne
		0b10, // Le
		0b10, // Lt
		0b10, // Gt
		0b10, // Ge
		0b10, // U_Lt
		0b10, // U_Gt
		0b10, // U_Le
		0b10, // U_Ge
		0b10, // Shl
		0b10, // Shr
		0b10, // U_Shr
		0b10, // Mul
		0b10, // Div
		0b10, // U_Div
		0b10, // Rem
		0b10, // U_Rem
		0b10, // And_Not
		0b10, // Split
		0b10, // Local_Addr
		0b10, // Global_Addr
		0b100000, // Proc_Addr
		0b10, // Copy
		0b10, // Set
		0b10, // Store
		0b10, // Load
		0b10, // Neg
		0b10, // Not
		0b10, // Cast
		0b10, // Conv
		0b10, // U_Conv
		0b10, // Splat
		0b10, // Ctz
		0b10, // Simd_Extract_Lsbs
		0b10, // Simd_Extract_Msbs
		0b10, // Simd_Reduce_Add_Bisect
		0b10, // Select
		0b10, // Msub
		0b10, // Cmlt
		0b10000000, // Ext
		0b10, // Zip1
		0b10, // Addv128
		0b10000000, // Umov
		0b10, // Lslv
		0b10, // Asrv
		0b10, // Lsrv
	},
	node_extra_sizes = {
		0 = 1, // Nil -> Cfg
		1 = 1, // Entry -> Cfg
		2 = 1, // Then -> Cfg
		3 = 1, // Else -> Cfg
		4 = 1, // Region -> Cfg
		5 = 1, // Loop -> Cfg
		6 = 1, // Call_End -> Cfg
		8 = 6, // Dbg_Sym_Decl -> Dbg_Sym
		11 = 1, // If -> Cfg
		12 = 1, // Jump -> Cfg
		13 = 1, // Trap -> Cfg
		14 = 4, // Call -> Call
		15 = 1, // Always -> Cfg
		16 = 1, // Return -> Cfg
		22 = 2, // Local -> Local
		23 = 1, // Global -> Tup
		24 = 1, // Param -> Tup
		25 = 1, // Ret -> Tup
		27 = 2, // CInt -> CInt
		55 = 1, // Proc_Addr -> Tup
		73 = 1, // Ext -> Arm_Op
		76 = 1, // Umov -> Arm_Op
		79 = 0,
	},
	node_flags = {
		{}, // Nil
		{Class_Flag.Is_Basic_Block_Start}, // Entry
		{Class_Flag.Is_Basic_Block_Start}, // Then
		{Class_Flag.Is_Basic_Block_Start}, // Else
		{Class_Flag.Is_Basic_Block_Start}, // Region
		{Class_Flag.Is_Basic_Block_Start}, // Loop
		{Class_Flag.Is_Basic_Block_Start}, // Call_End
		{}, // End
		{}, // Dbg_Sym_Decl
		{}, // Dbg_Sym_Update
		{}, // Dbg_Scope
		{}, // If
		{}, // Jump
		{}, // Trap
		{}, // Call
		{}, // Always
		{}, // Return
		{Class_Flag.Interned}, // Poison
		{Class_Flag.Store}, // Mem
		{Class_Flag.Store}, // Split_Mem
		{Class_Flag.Store}, // Merge_Mem
		{}, // Sym
		{}, // Local
		{}, // Global
		{}, // Param
		{}, // Ret
		{Class_Flag.Interned}, // Phi
		{Class_Flag.Interned, Class_Flag.Clonable}, // CInt
		{Class_Flag.Interned, Class_Flag.Comutes}, // Add
		{Class_Flag.Interned}, // Sub
		{Class_Flag.Interned, Class_Flag.Comutes}, // And
		{Class_Flag.Interned, Class_Flag.Comutes}, // Or
		{Class_Flag.Interned, Class_Flag.Comutes}, // Xor
		{Class_Flag.Interned, Class_Flag.Comutes}, // Eq
		{Class_Flag.Interned, Class_Flag.Comutes}, // Ne
		{Class_Flag.Interned}, // Le
		{Class_Flag.Interned}, // Lt
		{Class_Flag.Interned}, // Gt
		{Class_Flag.Interned}, // Ge
		{Class_Flag.Interned}, // U_Lt
		{Class_Flag.Interned}, // U_Gt
		{Class_Flag.Interned}, // U_Le
		{Class_Flag.Interned}, // U_Ge
		{Class_Flag.Interned}, // Shl
		{Class_Flag.Interned}, // Shr
		{Class_Flag.Interned}, // U_Shr
		{Class_Flag.Interned, Class_Flag.Comutes}, // Mul
		{Class_Flag.Interned}, // Div
		{Class_Flag.Interned}, // U_Div
		{Class_Flag.Interned}, // Rem
		{Class_Flag.Interned}, // U_Rem
		{Class_Flag.Interned}, // And_Not
		{}, // Split
		{Class_Flag.Clonable}, // Local_Addr
		{Class_Flag.Interned, Class_Flag.Clonable}, // Global_Addr
		{Class_Flag.Interned, Class_Flag.Clonable}, // Proc_Addr
		{Class_Flag.Store}, // Copy
		{Class_Flag.Store}, // Set
		{Class_Flag.Store}, // Store
		{Class_Flag.Interned, Class_Flag.Load}, // Load
		{Class_Flag.Interned}, // Neg
		{Class_Flag.Interned}, // Not
		{Class_Flag.Interned}, // Cast
		{Class_Flag.Interned}, // Conv
		{Class_Flag.Interned}, // U_Conv
		{Class_Flag.Interned}, // Splat
		{Class_Flag.Interned}, // Ctz
		{Class_Flag.Interned}, // Simd_Extract_Lsbs
		{Class_Flag.Interned}, // Simd_Extract_Msbs
		{Class_Flag.Interned}, // Simd_Reduce_Add_Bisect
		{Class_Flag.Interned}, // Select
		{}, // Msub
		{}, // Cmlt
		{}, // Ext
		{}, // Zip1
		{}, // Addv128
		{}, // Umov
		{}, // Lslv
		{}, // Asrv
		{}, // Lsrv
	},
	node_extra_types = ({}) when #config(NO_FMT, false) else ([]typeid{
		0 = bac.Cfg,
		1 = bac.Cfg,
		2 = bac.Cfg,
		3 = bac.Cfg,
		4 = bac.Cfg,
		5 = bac.Cfg,
		6 = bac.Cfg,
		8 = bac.Dbg_Sym,
		11 = bac.Cfg,
		12 = bac.Cfg,
		13 = bac.Cfg,
		14 = bac.Call,
		15 = bac.Cfg,
		16 = bac.Cfg,
		22 = bac.Local,
		23 = bac.Tup,
		24 = bac.Tup,
		25 = bac.Tup,
		27 = bac.CInt,
		55 = bac.Tup,
		73 = Arm_Op,
		76 = Arm_Op,
		79 = {},
	}),
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
