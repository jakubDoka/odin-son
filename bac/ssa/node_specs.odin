package bac_ssa
import bac ".."
Reg_Kind :: bac.Reg_Kind
Class_Flag :: bac.Class_Flag
import "base:intrinsics"// NOTE: this file is generated, see: /home/mlokis/personal/odin/jit/bac/meta2/meta2.odin(24:3)

@(tag = "api", rodata, export, link_name = "bac_ssa_SPEC")SPEC := bac.Node_Spec{
	call_clobbers = {
	},
	datatype_to_reg_kind = {.Void = 0, .Mem = 0, .I8 = 0, .I16 = 0, .I32 = 0, .I64 = 0, .F32 = 0, .F64 = 0, .V128 = 0, .V256 = 0, .V512 = 0},
	spill_boundary = {},
	sccp_compute = sccp_compute,
	emit_function = emit_function,
	peep = peep_inst,
	post_schedule_peep = post_schedule_peep_inst,
	inheritance_table = intrinsics.concatenate(bac.INHERITANCE_TABLE, []u16{
		0b10000000, // Scope
		0b10, // Lazy_Phi
	}),
	node_extra_sizes = intrinsics.concatenate(bac.NODE_EXTRA_SIZES, []u8{
		1, // Scope -> Scope
		0, // Lazy_Phi -> No_Extra
	}),
	node_flags = intrinsics.concatenate(bac.NODE_FLAGS, []bac.Class_Flags{
		{}, // Scope
		{}, // Lazy_Phi
	}),
	node_extra_types = ({}) when #config(NO_FMT, false) else (intrinsics.concatenate(bac.NODE_EXTRA_TYPES, []typeid{
		Scope,
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
	Scope,
	Lazy_Phi,
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

@(tag = "api")
add_scope :: #force_inline proc(prc: ^bac.Proc, name: string, cfg: bac.Node_ID) -> (_id: bac.Node_ID) {
	(^Scope)(bac.get_next_extra_slot(prc, u16(Node_Type.Scope), 0))^ = {
	}
	return bac.add_raw(prc, name, u16(Node_Type.Scope), .Void, {cfg})
}
add_lazy_phi :: #force_inline proc(prc: ^bac.Proc, name: string, dt: bac.Node_Datatype, reg: bac.Node_ID, lhs: bac.Node_ID) -> (_id: bac.Node_ID) {
	return bac.add_raw(prc, name, u16(Node_Type.Lazy_Phi), dt, {reg, lhs}, {extra_capacity = 1,})
}

inherit_idx_of :: #force_inline proc($T: typeid) -> u8 {
	when false {}
	else when T == bac.CInt {return 6}
	else when T == bac.Call {return 3}
	else when T == bac.Cfg {return 0}
	else when T == bac.Dbg_Sym {return 2}
	else when T == bac.Local {return 4}
	else when T == bac.No_Extra {return 1}
	else when T == Scope {return 7}
	else when T == bac.Tup {return 5}
	else {#panic(`the passed type is not subclass of anything`)}
}
#assert(size_of(bac.CInt) % bac.PRECISION == 0)
#assert(size_of(bac.Call) % bac.PRECISION == 0)
#assert(size_of(bac.Cfg) % bac.PRECISION == 0)
#assert(size_of(bac.Dbg_Sym) % bac.PRECISION == 0)
#assert(size_of(bac.Local) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(Scope) % bac.PRECISION == 0)
#assert(size_of(bac.Tup) % bac.PRECISION == 0)

stype :: #force_inline proc(node: bac.Expanded_Node) -> Node_Type {
	return Node_Type(node.rtype)
}

sextra :: #force_inline proc(
	prc: ^bac.Proc,
	node: ^bac.Node,
	$T: typeid,
) -> ^T {
	if prc.inheritance_table[node.rtype] & (1 << inherit_idx_of(T)) == 0 {
		return nil
	}
	return (^T)(&node.extra)
}
