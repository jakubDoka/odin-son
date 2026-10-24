package bac_x64
import bac ".."
Reg_Kind :: bac.Reg_Kind
Class_Flag :: bac.Class_Flag
// NOTE: this file is generated: 

@(tag = "api", rodata, export, link_name = "bac_x64_SPEC")SPEC := bac.Node_Spec{
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
		0b10000000, // X64_Add
		0b10000000, // X64_Sub
		0b10000000, // X64_And
		0b10000000, // X64_Or
		0b10000000, // X64_Xor
		0b10000000, // X64_Eq
		0b10000000, // X64_Ne
		0b10000000, // X64_Le
		0b10000000, // X64_Lt
		0b10000000, // X64_Gt
		0b10000000, // X64_Ge
		0b10000000, // X64_U_Lt
		0b10000000, // X64_U_Gt
		0b10000000, // X64_U_Le
		0b10000000, // X64_U_Ge
		0b10000000, // X64_Shl
		0b10000000, // X64_Shr
		0b10000000, // X64_U_Shr
		0b10000000, // X64_Mul
		0b10000000, // X64_Div
		0b10000000, // X64_Lea
		0b10000000, // X64_Load
		0b10000000, // X64_Store
		0b10000000, // X64_Neg
		0b10000000, // X64_Not
		0b10, // X64_Mul8
		0b10000000, // X64_Fma_213
		0b10, // X64_Pcmpeq
		0b10000000, // X64_Padd
		0b10000000, // X64_Psub
		0b10000000, // X64_Pshufd
		0b10000000, // X64_Pshuflw
		0b10, // X64_Psadbw
		0b10000000, // X64_Pshufb
		0b10000000, // X64_Pextr
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
		71 = 3, // X64_Add -> Mem_Op
		72 = 3, // X64_Sub -> Mem_Op
		73 = 3, // X64_And -> Mem_Op
		74 = 3, // X64_Or -> Mem_Op
		75 = 3, // X64_Xor -> Mem_Op
		76 = 3, // X64_Eq -> Mem_Op
		77 = 3, // X64_Ne -> Mem_Op
		78 = 3, // X64_Le -> Mem_Op
		79 = 3, // X64_Lt -> Mem_Op
		80 = 3, // X64_Gt -> Mem_Op
		81 = 3, // X64_Ge -> Mem_Op
		82 = 3, // X64_U_Lt -> Mem_Op
		83 = 3, // X64_U_Gt -> Mem_Op
		84 = 3, // X64_U_Le -> Mem_Op
		85 = 3, // X64_U_Ge -> Mem_Op
		86 = 3, // X64_Shl -> Mem_Op
		87 = 3, // X64_Shr -> Mem_Op
		88 = 3, // X64_U_Shr -> Mem_Op
		89 = 3, // X64_Mul -> Mem_Op
		90 = 3, // X64_Div -> Mem_Op
		91 = 3, // X64_Lea -> Mem_Op
		92 = 3, // X64_Load -> Mem_Op
		93 = 3, // X64_Store -> Mem_Op
		94 = 3, // X64_Neg -> Mem_Op
		95 = 3, // X64_Not -> Mem_Op
		97 = 3, // X64_Fma_213 -> Mem_Op
		99 = 3, // X64_Padd -> Mem_Op
		100 = 3, // X64_Psub -> Mem_Op
		101 = 3, // X64_Pshufd -> Mem_Op
		102 = 3, // X64_Pshuflw -> Mem_Op
		104 = 3, // X64_Pshufb -> Mem_Op
		105 = 3, // X64_Pextr -> Mem_Op
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
		{}, // X64_Add
		{}, // X64_Sub
		{}, // X64_And
		{}, // X64_Or
		{}, // X64_Xor
		{}, // X64_Eq
		{}, // X64_Ne
		{}, // X64_Le
		{}, // X64_Lt
		{}, // X64_Gt
		{}, // X64_Ge
		{}, // X64_U_Lt
		{}, // X64_U_Gt
		{}, // X64_U_Le
		{}, // X64_U_Ge
		{}, // X64_Shl
		{}, // X64_Shr
		{}, // X64_U_Shr
		{}, // X64_Mul
		{}, // X64_Div
		{}, // X64_Lea
		{Class_Flag.Load}, // X64_Load
		{Class_Flag.Store}, // X64_Store
		{}, // X64_Neg
		{}, // X64_Not
		{Class_Flag.Interned}, // X64_Mul8
		{}, // X64_Fma_213
		{Class_Flag.Interned}, // X64_Pcmpeq
		{}, // X64_Padd
		{}, // X64_Psub
		{}, // X64_Pshufd
		{}, // X64_Pshuflw
		{}, // X64_Psadbw
		{}, // X64_Pshufb
		{}, // X64_Pextr
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
		71 = Mem_Op,
		72 = Mem_Op,
		73 = Mem_Op,
		74 = Mem_Op,
		75 = Mem_Op,
		76 = Mem_Op,
		77 = Mem_Op,
		78 = Mem_Op,
		79 = Mem_Op,
		80 = Mem_Op,
		81 = Mem_Op,
		82 = Mem_Op,
		83 = Mem_Op,
		84 = Mem_Op,
		85 = Mem_Op,
		86 = Mem_Op,
		87 = Mem_Op,
		88 = Mem_Op,
		89 = Mem_Op,
		90 = Mem_Op,
		91 = Mem_Op,
		92 = Mem_Op,
		93 = Mem_Op,
		94 = Mem_Op,
		95 = Mem_Op,
		97 = Mem_Op,
		99 = Mem_Op,
		100 = Mem_Op,
		101 = Mem_Op,
		102 = Mem_Op,
		104 = Mem_Op,
		105 = Mem_Op,
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
	X64_Div,
	X64_Lea,
	X64_Load,
	X64_Store,
	X64_Neg,
	X64_Not,
	X64_Mul8,
	X64_Fma_213,
	X64_Pcmpeq,
	X64_Padd,
	X64_Psub,
	X64_Pshufd,
	X64_Pshuflw,
	X64_Psadbw,
	X64_Pshufb,
	X64_Pextr,
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

add_x64_psadbw :: #force_inline proc(prc: ^bac.Proc, name: string, dt: bac.Node_Datatype, lhs: bac.Node_ID, rhs: bac.Node_ID) -> (_id: bac.Node_ID) {
	return bac.add_raw(prc, name, u16(Node_Type.X64_Psadbw), dt, {lhs, rhs})
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
