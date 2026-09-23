package wasm
import bac ".."
Reg_Kind :: bac.Reg_Kind
Class_Flag :: bac.Class_Flag
// NOTE: this file is generated: 

SPEC := bac.Node_Spec{
	cc_table = {
		WASM_SYSTEMV_CC,
	},
	call_clobbers = {
		{},
	},
	datatype_to_reg_kind = {.Void = 0, .I8 = 1, .I16 = 1, .I32 = 1, .I64 = 0, .F32 = 3, .F64 = 2, .V128 = 4, .V256 = 0, .V512 = 0},
	spill_boundary = {64, 64, 64, 64, 64, 64},
	collect_meta = collect_meta,
	pre_regalloc_hook = pre_regalloc_hook,
	emit_function = emit_function,
	peep = peep_inst,
	post_schedule_peep = post_schedule_peep_inst,
	intern = false,
	inheritance_table = {
		0b1, // Start
		0b1, // Entry
		0b10, // Poison
		0b100, // Param
		0b1000, // CInt
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
		0b10, // F_Add
		0b10, // F_Sub
		0b10, // F_Mul
		0b10, // F_Div
		0b10, // F_Eq
		0b10, // F_Ne
		0b10, // F_Lt
		0b10, // F_Le
		0b10, // F_Gt
		0b10, // F_Ge
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
		0b10, // Phi
		0b10, // Mem
		0b10, // Root_Mem
		0b10, // Sym
		0b10000, // Local
		0b10, // Local_Addr
		0b100, // Global
		0b10, // Global_Addr
		0b100, // Proc_Addr
		0b10, // Copy
		0b10, // Set
		0b10, // Store
		0b10, // Load
		0b1, // If
		0b1, // Then
		0b1, // Else
		0b1, // Jump
		0b1, // Dead
		0b1, // Region
		0b1, // Loop
		0b1, // Always
		0b1, // Trap
		0b100001, // Call
		0b1, // Call_End
		0b100, // Ret
		0b1, // Return
		0b10, // Neg
		0b10, // Not
		0b10, // Sext
		0b10, // Uext
		0b10, // Cast
		0b10, // F_To_I
		0b10, // F_From_I
		0b10, // U_F_From_I
		0b10, // F_Ext
		0b10, // F_Demote
		0b10, // Splat
		0b10, // Ctz
		0b10, // Simd_Extract_Lsbs
		0b10, // Simd_Reduce_Add_Bisect
		0b1000000, // CV128
		0b10000000, // WASM_Store
		0b10000000, // WASM_Load
		0b10, // Get_Local
		0b10, // Set_Local
		0b10, // Tee_Local
		0b10, // Drop
		0b10, // Stub
		0b100000000, // Extract_Lane_U
	},
	node_extra_sizes = {
		1, // Start -> Cfg
		1, // Entry -> Cfg
		0, // Poison -> No_Extra
		1, // Param -> Tup
		2, // CInt -> CInt
		0, // Add -> No_Extra
		0, // Sub -> No_Extra
		0, // And -> No_Extra
		0, // Or -> No_Extra
		0, // Xor -> No_Extra
		0, // Eq -> No_Extra
		0, // Ne -> No_Extra
		0, // Le -> No_Extra
		0, // Lt -> No_Extra
		0, // Gt -> No_Extra
		0, // Ge -> No_Extra
		0, // U_Lt -> No_Extra
		0, // U_Gt -> No_Extra
		0, // U_Le -> No_Extra
		0, // U_Ge -> No_Extra
		0, // F_Add -> No_Extra
		0, // F_Sub -> No_Extra
		0, // F_Mul -> No_Extra
		0, // F_Div -> No_Extra
		0, // F_Eq -> No_Extra
		0, // F_Ne -> No_Extra
		0, // F_Lt -> No_Extra
		0, // F_Le -> No_Extra
		0, // F_Gt -> No_Extra
		0, // F_Ge -> No_Extra
		0, // Shl -> No_Extra
		0, // Shr -> No_Extra
		0, // U_Shr -> No_Extra
		0, // Mul -> No_Extra
		0, // Div -> No_Extra
		0, // U_Div -> No_Extra
		0, // Rem -> No_Extra
		0, // U_Rem -> No_Extra
		0, // And_Not -> No_Extra
		0, // Split -> No_Extra
		0, // Phi -> No_Extra
		0, // Mem -> No_Extra
		0, // Root_Mem -> No_Extra
		0, // Sym -> No_Extra
		2, // Local -> Local
		0, // Local_Addr -> No_Extra
		1, // Global -> Tup
		0, // Global_Addr -> No_Extra
		1, // Proc_Addr -> Tup
		0, // Copy -> No_Extra
		0, // Set -> No_Extra
		0, // Store -> No_Extra
		0, // Load -> No_Extra
		1, // If -> Cfg
		1, // Then -> Cfg
		1, // Else -> Cfg
		1, // Jump -> Cfg
		1, // Dead -> Cfg
		1, // Region -> Cfg
		1, // Loop -> Cfg
		1, // Always -> Cfg
		1, // Trap -> Cfg
		4, // Call -> Call
		1, // Call_End -> Cfg
		1, // Ret -> Tup
		1, // Return -> Cfg
		0, // Neg -> No_Extra
		0, // Not -> No_Extra
		0, // Sext -> No_Extra
		0, // Uext -> No_Extra
		0, // Cast -> No_Extra
		0, // F_To_I -> No_Extra
		0, // F_From_I -> No_Extra
		0, // U_F_From_I -> No_Extra
		0, // F_Ext -> No_Extra
		0, // F_Demote -> No_Extra
		0, // Splat -> No_Extra
		0, // Ctz -> No_Extra
		0, // Simd_Extract_Lsbs -> No_Extra
		0, // Simd_Reduce_Add_Bisect -> No_Extra
		4, // CV128 -> CV128
		2, // WASM_Store -> Mem_Op
		2, // WASM_Load -> Mem_Op
		0, // Get_Local -> No_Extra
		0, // Set_Local -> No_Extra
		0, // Tee_Local -> No_Extra
		0, // Drop -> No_Extra
		0, // Stub -> No_Extra
		1, // Extract_Lane_U -> Lane_Op
	},
	node_flags = {
		{}, // Start
		{Class_Flag.Is_Basic_Block_Start}, // Entry
		{Class_Flag.Interned}, // Poison
		{}, // Param
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
		{Class_Flag.Interned, Class_Flag.Comutes}, // F_Add
		{Class_Flag.Interned}, // F_Sub
		{Class_Flag.Interned, Class_Flag.Comutes}, // F_Mul
		{Class_Flag.Interned}, // F_Div
		{Class_Flag.Interned, Class_Flag.Comutes}, // F_Eq
		{Class_Flag.Interned, Class_Flag.Comutes}, // F_Ne
		{Class_Flag.Interned}, // F_Lt
		{Class_Flag.Interned}, // F_Le
		{Class_Flag.Interned}, // F_Gt
		{Class_Flag.Interned}, // F_Ge
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
		{Class_Flag.Interned}, // Phi
		{Class_Flag.Store}, // Mem
		{Class_Flag.Immortal, Class_Flag.Store}, // Root_Mem
		{Class_Flag.Immortal}, // Sym
		{}, // Local
		{Class_Flag.Clonable}, // Local_Addr
		{}, // Global
		{Class_Flag.Interned, Class_Flag.Clonable}, // Global_Addr
		{Class_Flag.Interned, Class_Flag.Clonable}, // Proc_Addr
		{Class_Flag.Store}, // Copy
		{Class_Flag.Store}, // Set
		{Class_Flag.Store}, // Store
		{Class_Flag.Interned, Class_Flag.Load}, // Load
		{}, // If
		{Class_Flag.Is_Basic_Block_Start}, // Then
		{Class_Flag.Is_Basic_Block_Start}, // Else
		{}, // Jump
		{}, // Dead
		{Class_Flag.Is_Basic_Block_Start}, // Region
		{Class_Flag.Is_Basic_Block_Start}, // Loop
		{}, // Always
		{}, // Trap
		{}, // Call
		{Class_Flag.Is_Basic_Block_Start}, // Call_End
		{}, // Ret
		{Class_Flag.Immortal}, // Return
		{Class_Flag.Interned}, // Neg
		{Class_Flag.Interned}, // Not
		{Class_Flag.Interned}, // Sext
		{Class_Flag.Interned}, // Uext
		{Class_Flag.Interned}, // Cast
		{Class_Flag.Interned}, // F_To_I
		{Class_Flag.Interned}, // F_From_I
		{Class_Flag.Interned}, // U_F_From_I
		{Class_Flag.Interned}, // F_Ext
		{Class_Flag.Interned}, // F_Demote
		{Class_Flag.Interned}, // Splat
		{Class_Flag.Interned}, // Ctz
		{Class_Flag.Interned}, // Simd_Extract_Lsbs
		{Class_Flag.Interned}, // Simd_Reduce_Add_Bisect
		{Class_Flag.Interned, Class_Flag.Clonable}, // CV128
		{Class_Flag.Store}, // WASM_Store
		{Class_Flag.Load}, // WASM_Load
		{}, // Get_Local
		{}, // Set_Local
		{}, // Tee_Local
		{}, // Drop
		{}, // Stub
		{}, // Extract_Lane_U
	},
	node_extra_types = {
		bac.Cfg,
		bac.Cfg,
		bac.No_Extra,
		bac.Tup,
		bac.CInt,
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
		bac.No_Extra,
		bac.No_Extra,
		bac.No_Extra,
		bac.No_Extra,
		bac.No_Extra,
		bac.No_Extra,
		bac.Local,
		bac.No_Extra,
		bac.Tup,
		bac.No_Extra,
		bac.Tup,
		bac.No_Extra,
		bac.No_Extra,
		bac.No_Extra,
		bac.No_Extra,
		bac.Cfg,
		bac.Cfg,
		bac.Cfg,
		bac.Cfg,
		bac.Cfg,
		bac.Cfg,
		bac.Cfg,
		bac.Cfg,
		bac.Cfg,
		bac.Call,
		bac.Cfg,
		bac.Tup,
		bac.Cfg,
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
		bac.No_Extra,
		bac.No_Extra,
		bac.No_Extra,
		bac.CV128,
		Mem_Op,
		Mem_Op,
		bac.No_Extra,
		bac.No_Extra,
		bac.No_Extra,
		bac.No_Extra,
		bac.No_Extra,
		Lane_Op,
	},
	node_kind_name = {
		`Start`,
		`Entry`,
		`Poison`,
		`Param`,
		`CInt`,
		`Add`,
		`Sub`,
		`And`,
		`Or`,
		`Xor`,
		`Eq`,
		`Ne`,
		`Le`,
		`Lt`,
		`Gt`,
		`Ge`,
		`U_Lt`,
		`U_Gt`,
		`U_Le`,
		`U_Ge`,
		`F_Add`,
		`F_Sub`,
		`F_Mul`,
		`F_Div`,
		`F_Eq`,
		`F_Ne`,
		`F_Lt`,
		`F_Le`,
		`F_Gt`,
		`F_Ge`,
		`Shl`,
		`Shr`,
		`U_Shr`,
		`Mul`,
		`Div`,
		`U_Div`,
		`Rem`,
		`U_Rem`,
		`And_Not`,
		`Split`,
		`Phi`,
		`Mem`,
		`Root_Mem`,
		`Sym`,
		`Local`,
		`Local_Addr`,
		`Global`,
		`Global_Addr`,
		`Proc_Addr`,
		`Copy`,
		`Set`,
		`Store`,
		`Load`,
		`If`,
		`Then`,
		`Else`,
		`Jump`,
		`Dead`,
		`Region`,
		`Loop`,
		`Always`,
		`Trap`,
		`Call`,
		`Call_End`,
		`Ret`,
		`Return`,
		`Neg`,
		`Not`,
		`Sext`,
		`Uext`,
		`Cast`,
		`F_To_I`,
		`F_From_I`,
		`U_F_From_I`,
		`F_Ext`,
		`F_Demote`,
		`Splat`,
		`Ctz`,
		`Simd_Extract_Lsbs`,
		`Simd_Reduce_Add_Bisect`,
		`CV128`,
		`WASM_Store`,
		`WASM_Load`,
		`Get_Local`,
		`Set_Local`,
		`Tee_Local`,
		`Drop`,
		`Stub`,
		`Extract_Lane_U`,
	},
}

Node_Type :: enum u16 {
	Start,
	Entry,
	Poison,
	Param,
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
	F_Add,
	F_Sub,
	F_Mul,
	F_Div,
	F_Eq,
	F_Ne,
	F_Lt,
	F_Le,
	F_Gt,
	F_Ge,
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
	Phi,
	Mem,
	Root_Mem,
	Sym,
	Local,
	Local_Addr,
	Global,
	Global_Addr,
	Proc_Addr,
	Copy,
	Set,
	Store,
	Load,
	If,
	Then,
	Else,
	Jump,
	Dead,
	Region,
	Loop,
	Always,
	Trap,
	Call,
	Call_End,
	Ret,
	Return,
	Neg,
	Not,
	Sext,
	Uext,
	Cast,
	F_To_I,
	F_From_I,
	U_F_From_I,
	F_Ext,
	F_Demote,
	Splat,
	Ctz,
	Simd_Extract_Lsbs,
	Simd_Reduce_Add_Bisect,
	CV128,
	WASM_Store,
	WASM_Load,
	Get_Local,
	Set_Local,
	Tee_Local,
	Drop,
	Stub,
	Extract_Lane_U,
}

peep_inst :: proc(ctx: bac.Peep_Ctx, node: bac.Expanded_Node) -> bac.Node_ID {
	return peep(ctx, node, struct{}{})
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

#assert(size_of(bac.Cfg) % bac.PRECISION == 0)
#assert(size_of(bac.Cfg) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.Tup) % bac.PRECISION == 0)
#assert(size_of(bac.CInt) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.Local) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.Tup) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.Tup) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.Cfg) % bac.PRECISION == 0)
#assert(size_of(bac.Cfg) % bac.PRECISION == 0)
#assert(size_of(bac.Cfg) % bac.PRECISION == 0)
#assert(size_of(bac.Cfg) % bac.PRECISION == 0)
#assert(size_of(bac.Cfg) % bac.PRECISION == 0)
#assert(size_of(bac.Cfg) % bac.PRECISION == 0)
#assert(size_of(bac.Cfg) % bac.PRECISION == 0)
#assert(size_of(bac.Cfg) % bac.PRECISION == 0)
#assert(size_of(bac.Cfg) % bac.PRECISION == 0)
#assert(size_of(bac.Call) % bac.PRECISION == 0)
#assert(size_of(bac.Cfg) % bac.PRECISION == 0)
#assert(size_of(bac.Tup) % bac.PRECISION == 0)
#assert(size_of(bac.Cfg) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.CV128) % bac.PRECISION == 0)
#assert(size_of(Mem_Op) % bac.PRECISION == 0)
#assert(size_of(Mem_Op) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(Lane_Op) % bac.PRECISION == 0)
add_extract_lane_u :: #force_inline proc(graph: ^bac.Proc, name: string, dt: bac.Node_Datatype, vec: bac.Node_ID, laneidx: u32, lane: bac.Lane_Type = {}) -> (_id: bac.Node_ID) {
	(^Lane_Op)(bac.get_next_extra_slot(graph, u16(Node_Type.Extract_Lane_U), 0))^ = {
		laneidx = laneidx,
	}
	return bac.add_raw(graph, name, u16(Node_Type.Extract_Lane_U), dt, {vec}, {lane = lane,})
}

inherit_idx_of :: #force_inline proc($T: typeid) -> u8 {
	when false {}
	else when T == bac.Local {return 4}
	else when T == Mem_Op {return 7}
	else when T == bac.Tup {return 2}
	else when T == bac.No_Extra {return 1}
	else when T == bac.Call {return 5}
	else when T == bac.Cfg {return 0}
	else when T == bac.CInt {return 3}
	else when T == bac.CV128 {return 6}
	else when T == Lane_Op {return 8}
	else {#panic(`the passed type is not subclass of anything`)}
}
