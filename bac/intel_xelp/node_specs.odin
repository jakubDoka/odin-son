package bac_intel_xelp
import bac ".."
Reg_Kind :: bac.Reg_Kind
Class_Flag :: bac.Class_Flag
import "base:intrinsics"// NOTE: this file is generated, see: /home/mlokis/personal/odin/jit/bac/meta2/meta2.odin(65:3)

@(tag = "api", rodata, export, link_name = "bac_intel_xelp_SPEC")SPEC := bac.Node_Spec{
	call_clobbers = {
		{},
	},
	datatype_to_reg_kind = {.Void = 0, .Mem = 0, .I8 = 0, .I16 = 0, .I32 = 0, .I64 = 0, .F32 = 0, .F64 = 0, .V128 = 0, .V256 = 0, .V512 = 0},
	spill_boundary = {128, 4},
	collect_meta = collect_meta,
	emit_function = emit_function,
	peep = peep_inst,
	post_schedule_peep = post_schedule_peep_inst,
	inheritance_table = intrinsics.concatenate(bac.INHERITANCE_TABLE, []u16{
		0b10, // Inv
		0b10, // Value_Eq
		0b10, // Value_Ne
		0b10, // Value_Le
		0b10, // Value_Lt
		0b10, // Value_Gt
		0b10, // Value_Ge
		0b10, // Value_U_Lt
		0b10, // Value_U_Gt
		0b10, // Value_U_Le
		0b10, // Value_U_Ge
		0b100000, // Extract_Lane
		0b10, // Address_Payload
		0b10, // Store_A64
		0b10, // Lane_Sequence
		0b10, // Mul_Lo16
		0b10, // Mul_Hi16
	}),
	node_extra_sizes = intrinsics.concatenate(bac.NODE_EXTRA_SIZES, []u8{
		0, // Inv -> No_Extra
		0, // Value_Eq -> No_Extra
		0, // Value_Ne -> No_Extra
		0, // Value_Le -> No_Extra
		0, // Value_Lt -> No_Extra
		0, // Value_Gt -> No_Extra
		0, // Value_Ge -> No_Extra
		0, // Value_U_Lt -> No_Extra
		0, // Value_U_Gt -> No_Extra
		0, // Value_U_Le -> No_Extra
		0, // Value_U_Ge -> No_Extra
		1, // Extract_Lane -> Tup
		0, // Address_Payload -> No_Extra
		0, // Store_A64 -> No_Extra
		0, // Lane_Sequence -> No_Extra
		0, // Mul_Lo16 -> No_Extra
		0, // Mul_Hi16 -> No_Extra
	}),
	node_flags = intrinsics.concatenate(bac.NODE_FLAGS, []bac.Class_Flags{
		{Class_Flag.Interned}, // Inv
		{Class_Flag.Interned}, // Value_Eq
		{Class_Flag.Interned}, // Value_Ne
		{Class_Flag.Interned}, // Value_Le
		{Class_Flag.Interned}, // Value_Lt
		{Class_Flag.Interned}, // Value_Gt
		{Class_Flag.Interned}, // Value_Ge
		{Class_Flag.Interned}, // Value_U_Lt
		{Class_Flag.Interned}, // Value_U_Gt
		{Class_Flag.Interned}, // Value_U_Le
		{Class_Flag.Interned}, // Value_U_Ge
		{Class_Flag.Interned}, // Extract_Lane
		{}, // Address_Payload
		{Class_Flag.Store}, // Store_A64
		{Class_Flag.Interned}, // Lane_Sequence
		{Class_Flag.Interned}, // Mul_Lo16
		{Class_Flag.Interned}, // Mul_Hi16
	}),
	node_extra_types = ({}) when #config(NO_FMT, false) else (intrinsics.concatenate(bac.NODE_EXTRA_TYPES, []typeid{
		bac.No_Extra,
		bac.No_Extra,
		bac.No_Extra,
		bac.No_Extra,
		bac.No_Extra,
		bac.No_Extra,
		bac.No_Extra,
		bac.No_Extra,
		bac.No_Extra,
		bac.No_Extra,
		bac.No_Extra,
		bac.Tup,
		bac.No_Extra,
		bac.No_Extra,
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
	Inv,
	Value_Eq,
	Value_Ne,
	Value_Le,
	Value_Lt,
	Value_Gt,
	Value_Ge,
	Value_U_Lt,
	Value_U_Gt,
	Value_U_Le,
	Value_U_Ge,
	Extract_Lane,
	Address_Payload,
	Store_A64,
	Lane_Sequence,
	Mul_Lo16,
	Mul_Hi16,
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


inherit_idx_of :: #force_inline proc($T: typeid) -> u8 {
	when false {}
	else when T == bac.CInt {return 6}
	else when T == bac.Call {return 3}
	else when T == bac.Cfg {return 0}
	else when T == bac.Dbg_Sym {return 2}
	else when T == bac.Local {return 4}
	else when T == bac.No_Extra {return 1}
	else when T == bac.Tup {return 5}
	else {#panic(`the passed type is not subclass of anything`)}
}
#assert(size_of(bac.CInt) % bac.PRECISION == 0)
#assert(size_of(bac.Call) % bac.PRECISION == 0)
#assert(size_of(bac.Cfg) % bac.PRECISION == 0)
#assert(size_of(bac.Dbg_Sym) % bac.PRECISION == 0)
#assert(size_of(bac.Local) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.Tup) % bac.PRECISION == 0)

@(rodata) GRF_MASK := [?]i64{transmute(i64)u64(0xfffffffffffffffe), transmute(i64)u64(0xff0fffffffffffff)}
GRF_MASK_IDX :: bac.RM_Intern_Idx{index = 0, kind = 0}
@(rodata) GRF_MASKS := [6]bac.RM_Intern_Idx{0 ..< 6 = GRF_MASK_IDX}

@(rodata) FLAG_MASK := [?]i64{transmute(i64)u64(0x000000000000000f), transmute(i64)u64(0x0000000000000000)}
FLAG_MASK_IDX :: bac.RM_Intern_Idx{index = 0, kind = 1}
@(rodata) FLAG_MASKS := [6]bac.RM_Intern_Idx{0 ..< 6 = FLAG_MASK_IDX}

seed_rm_interner :: proc(ra: ^bac.Regalloc) {
	ra.mask_len = MASK_SIZE
	bac.rm_intern_slice(ra, 0, GRF_MASK[:])
	bac.rm_intern_slice(ra, 1, FLAG_MASK[:])
}

xtype :: #force_inline proc(node: bac.Expanded_Node) -> Node_Type {
	return Node_Type(node.rtype)
}

xextra :: #force_inline proc(
	prc: ^bac.Proc,
	node: ^bac.Node,
	$T: typeid,
) -> ^T {
	if prc.inheritance_table[node.rtype] & (1 << inherit_idx_of(T)) == 0 {
		return nil
	}
	return (^T)(&node.extra)
}
