package bac_wasm
import bac ".."

Reg_Kind :: bac.Reg_Kind

Class_Flag :: bac.Class_Flag

import "base:intrinsics"// NOTE: this file is generated, see: /home/mlokis/personal/odin/jit/bac/meta2/meta2.odin(179:3)

@(tag = "api", rodata, export, link_name = "bac_wasm_SPEC")SPEC := bac.Node_Spec{
	call_clobbers = {
		{},
	},
	datatype_to_reg_kind = {.Void = 0, .Mem = 0, .I8 = 1, .I16 = 1, .I32 = 1, .I64 = 0, .F32 = 3, .F64 = 2, .V128 = 4, .V256 = 0, .V512 = 0},
	spill_boundary = {64, 64, 64, 64, 64, 64},
	collect_meta = collect_meta,
	pre_regalloc_hook = pre_regalloc_hook,
	emit_function = emit_function,
	peep = peep_inst,
	post_schedule_peep = post_schedule_peep_inst,
	inheritance_table = intrinsics.concatenate(bac.INHERITANCE_TABLE, []u16{
		0b10000000, // WASM_Store
		0b10000000, // WASM_Load
		0b10, // Get_Local
		0b10, // Set_Local
		0b10, // Tee_Local
		0b10, // Drop
		0b10, // Stub
		0b100000000, // Extract_Lane_U
		0b10, // WASM_Shl
		0b10, // WASM_Shr
		0b10, // WASM_U_Shr
	}),
	node_extra_sizes = intrinsics.concatenate(bac.NODE_EXTRA_SIZES, []u8{
		2, // WASM_Store -> Mem_Op
		2, // WASM_Load -> Mem_Op
		0, // Get_Local -> No_Extra
		0, // Set_Local -> No_Extra
		0, // Tee_Local -> No_Extra
		0, // Drop -> No_Extra
		0, // Stub -> No_Extra
		1, // Extract_Lane_U -> Lane_Op
		0, // WASM_Shl -> No_Extra
		0, // WASM_Shr -> No_Extra
		0, // WASM_U_Shr -> No_Extra
	}),
	node_flags = intrinsics.concatenate(bac.NODE_FLAGS, []bac.Class_Flags{
		{Class_Flag.Store}, // WASM_Store
		{Class_Flag.Load}, // WASM_Load
		{}, // Get_Local
		{}, // Set_Local
		{}, // Tee_Local
		{}, // Drop
		{}, // Stub
		{}, // Extract_Lane_U
		{}, // WASM_Shl
		{}, // WASM_Shr
		{}, // WASM_U_Shr
	}),
	node_extra_types = ({}) when #config(NO_FMT, false) else (intrinsics.concatenate(bac.NODE_EXTRA_TYPES, []typeid{
		Mem_Op,
		Mem_Op,
		bac.No_Extra,
		bac.No_Extra,
		bac.No_Extra,
		bac.No_Extra,
		bac.No_Extra,
		Lane_Op,
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
	WASM_Store,
	WASM_Load,
	Get_Local,
	Set_Local,
	Tee_Local,
	Drop,
	Stub,
	Extract_Lane_U,
	WASM_Shl,
	WASM_Shr,
	WASM_U_Shr,
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

add_extract_lane_u :: #force_inline proc(prc: ^bac.Proc, name: string, dt: bac.Node_Datatype, vec: bac.Node_ID, laneidx: u32, lane: bac.Lane_Type = {}) -> (_id: bac.Node_ID) {
	return bac.add_raw(prc, name, u16(Node_Type.Extract_Lane_U), dt, {vec}, extra = &Lane_Op{
		laneidx = laneidx,
	}, meta = {lane = lane,})
}

inherit_idx_of :: #force_inline proc($T: typeid) -> u8 {
	when false {}
	else when T == bac.CInt {return 6}
	else when T == bac.Call {return 3}
	else when T == bac.Cfg {return 0}
	else when T == bac.Dbg_Sym {return 2}
	else when T == Lane_Op {return 8}
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
#assert(size_of(Lane_Op) % bac.PRECISION == 0)
#assert(size_of(bac.Local) % bac.PRECISION == 0)
#assert(size_of(Mem_Op) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.Tup) % bac.PRECISION == 0)

wtype :: #force_inline proc(node: bac.Expanded_Node) -> Node_Type {
	return Node_Type(node.rtype)
}

wextra :: #force_inline proc(
	prc: ^bac.Proc,
	node: ^bac.Node,
	$T: typeid,
) -> ^T {
	if prc.inheritance_table[node.rtype] & (1 << inherit_idx_of(T)) == 0 {
		return nil
	}
	return (^T)(&node.extra)
}
