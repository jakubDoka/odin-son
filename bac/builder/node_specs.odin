package builder
import bac ".."
Reg_Kind :: bac.Reg_Kind
Class_Flag :: bac.Class_Flag
// NOTE: this file is generated: 

SPEC := bac.Node_Spec{
	cc_table = {
	},
	call_clobbers = {
	},
	datatype_to_reg_kind = {.Void = 0, .Mem = 0, .I8 = 0, .I16 = 0, .I32 = 0, .I64 = 0, .F32 = 0, .F64 = 0, .V128 = 0, .V256 = 0, .V512 = 0},
	spill_boundary = {},
	emit_function = emit_function,
	peep = peep_inst,
	post_schedule_peep = post_schedule_peep_inst,
	intern = true,
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
		0b10, // Simd_Reduce_Add_Bisect
		0b10000000, // Scope
		0b10, // Lazy_Phi
	},
	node_extra_sizes = {
		1, // Nil -> Cfg
		1, // Entry -> Cfg
		1, // Then -> Cfg
		1, // Else -> Cfg
		1, // Region -> Cfg
		1, // Loop -> Cfg
		1, // Call_End -> Cfg
		0, // End -> No_Extra
		6, // Dbg_Sym_Decl -> Dbg_Sym
		0, // Dbg_Sym_Update -> No_Extra
		0, // Dbg_Scope -> No_Extra
		1, // If -> Cfg
		1, // Jump -> Cfg
		1, // Trap -> Cfg
		4, // Call -> Call
		1, // Always -> Cfg
		1, // Return -> Cfg
		0, // Poison -> No_Extra
		0, // Mem -> No_Extra
		0, // Split_Mem -> No_Extra
		0, // Merge_Mem -> No_Extra
		0, // Sym -> No_Extra
		2, // Local -> Local
		1, // Global -> Tup
		1, // Param -> Tup
		1, // Ret -> Tup
		0, // Phi -> No_Extra
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
		0, // Local_Addr -> No_Extra
		0, // Global_Addr -> No_Extra
		1, // Proc_Addr -> Tup
		0, // Copy -> No_Extra
		0, // Set -> No_Extra
		0, // Store -> No_Extra
		0, // Load -> No_Extra
		0, // Neg -> No_Extra
		0, // Not -> No_Extra
		0, // Cast -> No_Extra
		0, // Conv -> No_Extra
		0, // U_Conv -> No_Extra
		0, // Splat -> No_Extra
		0, // Ctz -> No_Extra
		0, // Simd_Extract_Lsbs -> No_Extra
		0, // Simd_Reduce_Add_Bisect -> No_Extra
		1, // Scope -> Scope
		0, // Lazy_Phi -> No_Extra
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
		{Class_Flag.Interned}, // Simd_Reduce_Add_Bisect
		{}, // Scope
		{}, // Lazy_Phi
	},
	node_extra_types = {
		bac.Cfg,
		bac.Cfg,
		bac.Cfg,
		bac.Cfg,
		bac.Cfg,
		bac.Cfg,
		bac.Cfg,
		bac.No_Extra,
		bac.Dbg_Sym,
		bac.No_Extra,
		bac.No_Extra,
		bac.Cfg,
		bac.Cfg,
		bac.Cfg,
		bac.Call,
		bac.Cfg,
		bac.Cfg,
		bac.No_Extra,
		bac.No_Extra,
		bac.No_Extra,
		bac.No_Extra,
		bac.No_Extra,
		bac.Local,
		bac.Tup,
		bac.Tup,
		bac.Tup,
		bac.No_Extra,
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
		bac.Tup,
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
		Scope,
		bac.No_Extra,
	},
	node_kind_name = {
		`Nil`,
		`Entry`,
		`Then`,
		`Else`,
		`Region`,
		`Loop`,
		`Call_End`,
		`End`,
		`Dbg_Sym_Decl`,
		`Dbg_Sym_Update`,
		`Dbg_Scope`,
		`If`,
		`Jump`,
		`Trap`,
		`Call`,
		`Always`,
		`Return`,
		`Poison`,
		`Mem`,
		`Split_Mem`,
		`Merge_Mem`,
		`Sym`,
		`Local`,
		`Global`,
		`Param`,
		`Ret`,
		`Phi`,
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
		`Local_Addr`,
		`Global_Addr`,
		`Proc_Addr`,
		`Copy`,
		`Set`,
		`Store`,
		`Load`,
		`Neg`,
		`Not`,
		`Cast`,
		`Conv`,
		`U_Conv`,
		`Splat`,
		`Ctz`,
		`Simd_Extract_Lsbs`,
		`Simd_Reduce_Add_Bisect`,
		`Scope`,
		`Lazy_Phi`,
	},
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
	Simd_Reduce_Add_Bisect,
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

add_scope :: #force_inline proc(graph: ^bac.Proc, name: string, cfg: bac.Node_ID) -> (_id: bac.Node_ID) {
	(^Scope)(bac.get_next_extra_slot(graph, u16(Node_Type.Scope), 0))^ = {}
	return bac.add_raw(graph, name, u16(Node_Type.Scope), .Void, {cfg})
}
add_lazy_phi :: #force_inline proc(graph: ^bac.Proc, name: string, dt: bac.Node_Datatype, reg: bac.Node_ID, lhs: bac.Node_ID) -> (_id: bac.Node_ID) {
	return bac.add_raw(graph, name, u16(Node_Type.Lazy_Phi), dt, {reg, lhs}, {extra_capacity = 1,})
}

inherit_idx_of :: #force_inline proc($T: typeid) -> u8 {
	when false {}
	else when T == bac.Local {return 4}
	else when T == bac.Dbg_Sym {return 2}
	else when T == bac.Tup {return 5}
	else when T == bac.No_Extra {return 1}
	else when T == bac.Call {return 3}
	else when T == bac.Cfg {return 0}
	else when T == bac.CInt {return 6}
	else when T == Scope {return 7}
	else {#panic(`the passed type is not subclass of anything`)}
}
#assert(size_of(bac.Local) % bac.PRECISION == 0)
#assert(size_of(bac.Dbg_Sym) % bac.PRECISION == 0)
#assert(size_of(bac.Tup) % bac.PRECISION == 0)
#assert(size_of(bac.No_Extra) % bac.PRECISION == 0)
#assert(size_of(bac.Call) % bac.PRECISION == 0)
#assert(size_of(bac.Cfg) % bac.PRECISION == 0)
#assert(size_of(bac.CInt) % bac.PRECISION == 0)
#assert(size_of(Scope) % bac.PRECISION == 0)
