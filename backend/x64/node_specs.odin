package x64
import backend ".."
Reg_Kind :: backend.Reg_Kind
Class_Flag :: backend.Class_Flag
// NOTE: this file is generated: odin run backend/x64 -define:X64_GEN_SPEC=true

when !GEN_SPEC {
SPEC := backend.Node_Spec{
	cc_table = {
		X64_SYSTEMV_CC,
		X64_LINUX_SYSCALL_CC,
	},
	call_clobbers = {
		{.General = 4039, .Vector = 65535},
		{.General = 2051, .Vector = 0},
	},
	datatype_to_reg_kind = {.Void = Reg_Kind.General, .I8 = Reg_Kind.General, .I16 = Reg_Kind.General, .I32 = Reg_Kind.General, .I64 = Reg_Kind.General, .F32 = Reg_Kind.Vector, .F64 = Reg_Kind.Vector, .V128 = Reg_Kind.Vector, .V256 = Reg_Kind.Vector, .V512 = Reg_Kind.Vector},
	collect_meta = x64_collect_meta,
	emit_function = x64_emit_function,
	peep = x64_peep_inst,
	post_schedule_peep = x64_post_schedule_peep_inst,
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
		0b10, // F_Ext
		0b10, // F_Demote
		0b10, // Splat
		0b10, // Ctz
		0b10, // Simd_Extract_Lsbs
		0b10, // Simd_Reduce_Add_Bisect
		0b1000000, // CV128
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
		0b10000000, // X64_F_Add
		0b10000000, // X64_F_Sub
		0b10000000, // X64_F_Mul
		0b10000000, // X64_F_Div
		0b10000000, // X64_F_Eq
		0b10000000, // X64_F_Ne
		0b10000000, // X64_F_Le
		0b10000000, // X64_F_Lt
		0b10000000, // X64_F_Gt
		0b10000000, // X64_F_Ge
		0b10000000, // X64_Shl
		0b10000000, // X64_Shr
		0b10000000, // X64_U_Shr
		0b10000000, // X64_Mul
		0b10000000, // X64_Lea
		0b10000000, // X64_Load
		0b10000000, // X64_Store
		0b10, // X64_CLoad
		0b10000000, // X64_Neg
		0b10000000, // X64_Not
		0b10, // X64_Mul8
		0b10000000, // X64_Fma_213
		0b10, // X64_Pcmpeq
		0b10000000, // X64_Pshufd
		0b10, // X64_Psadbw
		0b10000000, // X64_Pshufb
		0b10000000, // X64_Pextr
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
		1, // Region -> Cfg
		1, // Loop -> Cfg
		1, // Always -> Cfg
		1, // Trap -> Cfg
		3, // Call -> Call
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
		0, // F_Ext -> No_Extra
		0, // F_Demote -> No_Extra
		0, // Splat -> No_Extra
		0, // Ctz -> No_Extra
		0, // Simd_Extract_Lsbs -> No_Extra
		0, // Simd_Reduce_Add_Bisect -> No_Extra
		4, // CV128 -> CV128
		3, // X64_Add -> X64_Mem_Op
		3, // X64_Sub -> X64_Mem_Op
		3, // X64_And -> X64_Mem_Op
		3, // X64_Or -> X64_Mem_Op
		3, // X64_Xor -> X64_Mem_Op
		3, // X64_Eq -> X64_Mem_Op
		3, // X64_Ne -> X64_Mem_Op
		3, // X64_Le -> X64_Mem_Op
		3, // X64_Lt -> X64_Mem_Op
		3, // X64_Gt -> X64_Mem_Op
		3, // X64_Ge -> X64_Mem_Op
		3, // X64_U_Lt -> X64_Mem_Op
		3, // X64_U_Gt -> X64_Mem_Op
		3, // X64_U_Le -> X64_Mem_Op
		3, // X64_U_Ge -> X64_Mem_Op
		3, // X64_F_Add -> X64_Mem_Op
		3, // X64_F_Sub -> X64_Mem_Op
		3, // X64_F_Mul -> X64_Mem_Op
		3, // X64_F_Div -> X64_Mem_Op
		3, // X64_F_Eq -> X64_Mem_Op
		3, // X64_F_Ne -> X64_Mem_Op
		3, // X64_F_Le -> X64_Mem_Op
		3, // X64_F_Lt -> X64_Mem_Op
		3, // X64_F_Gt -> X64_Mem_Op
		3, // X64_F_Ge -> X64_Mem_Op
		3, // X64_Shl -> X64_Mem_Op
		3, // X64_Shr -> X64_Mem_Op
		3, // X64_U_Shr -> X64_Mem_Op
		3, // X64_Mul -> X64_Mem_Op
		3, // X64_Lea -> X64_Mem_Op
		3, // X64_Load -> X64_Mem_Op
		3, // X64_Store -> X64_Mem_Op
		0, // X64_CLoad -> No_Extra
		3, // X64_Neg -> X64_Mem_Op
		3, // X64_Not -> X64_Mem_Op
		0, // X64_Mul8 -> No_Extra
		3, // X64_Fma_213 -> X64_Mem_Op
		0, // X64_Pcmpeq -> No_Extra
		3, // X64_Pshufd -> X64_Mem_Op
		0, // X64_Psadbw -> No_Extra
		3, // X64_Pshufb -> X64_Mem_Op
		3, // X64_Pextr -> X64_Mem_Op
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
		{Class_Flag.Interned}, // F_Ext
		{Class_Flag.Interned}, // F_Demote
		{Class_Flag.Interned}, // Splat
		{Class_Flag.Interned}, // Ctz
		{Class_Flag.Interned}, // Simd_Extract_Lsbs
		{Class_Flag.Interned}, // Simd_Reduce_Add_Bisect
		{Class_Flag.Interned, Class_Flag.Clonable}, // CV128
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
		{}, // X64_F_Add
		{}, // X64_F_Sub
		{}, // X64_F_Mul
		{}, // X64_F_Div
		{}, // X64_F_Eq
		{}, // X64_F_Ne
		{}, // X64_F_Le
		{}, // X64_F_Lt
		{}, // X64_F_Gt
		{}, // X64_F_Ge
		{}, // X64_Shl
		{}, // X64_Shr
		{}, // X64_U_Shr
		{}, // X64_Mul
		{}, // X64_Lea
		{Class_Flag.Load}, // X64_Load
		{Class_Flag.Store}, // X64_Store
		{Class_Flag.Clonable}, // X64_CLoad
		{}, // X64_Neg
		{}, // X64_Not
		{}, // X64_Mul8
		{}, // X64_Fma_213
		{}, // X64_Pcmpeq
		{}, // X64_Pshufd
		{}, // X64_Psadbw
		{}, // X64_Pshufb
		{}, // X64_Pextr
	},
	node_extra_types = {
		backend.Cfg,
		backend.Cfg,
		backend.No_Extra,
		backend.Tup,
		backend.CInt,
		backend.No_Extra,
		backend.No_Extra,
		backend.No_Extra,
		backend.No_Extra,
		backend.No_Extra,
		backend.No_Extra,
		backend.No_Extra,
		backend.No_Extra,
		backend.No_Extra,
		backend.No_Extra,
		backend.No_Extra,
		backend.No_Extra,
		backend.No_Extra,
		backend.No_Extra,
		backend.No_Extra,
		backend.No_Extra,
		backend.No_Extra,
		backend.No_Extra,
		backend.No_Extra,
		backend.No_Extra,
		backend.No_Extra,
		backend.No_Extra,
		backend.No_Extra,
		backend.No_Extra,
		backend.No_Extra,
		backend.No_Extra,
		backend.No_Extra,
		backend.No_Extra,
		backend.No_Extra,
		backend.No_Extra,
		backend.No_Extra,
		backend.No_Extra,
		backend.No_Extra,
		backend.No_Extra,
		backend.No_Extra,
		backend.No_Extra,
		backend.No_Extra,
		backend.No_Extra,
		backend.Local,
		backend.No_Extra,
		backend.Tup,
		backend.No_Extra,
		backend.Tup,
		backend.No_Extra,
		backend.No_Extra,
		backend.No_Extra,
		backend.No_Extra,
		backend.Cfg,
		backend.Cfg,
		backend.Cfg,
		backend.Cfg,
		backend.Cfg,
		backend.Cfg,
		backend.Cfg,
		backend.Cfg,
		backend.Call,
		backend.Cfg,
		backend.Tup,
		backend.Cfg,
		backend.No_Extra,
		backend.No_Extra,
		backend.No_Extra,
		backend.No_Extra,
		backend.No_Extra,
		backend.No_Extra,
		backend.No_Extra,
		backend.No_Extra,
		backend.No_Extra,
		backend.No_Extra,
		backend.No_Extra,
		backend.No_Extra,
		backend.No_Extra,
		backend.CV128,
		X64_Mem_Op,
		X64_Mem_Op,
		X64_Mem_Op,
		X64_Mem_Op,
		X64_Mem_Op,
		X64_Mem_Op,
		X64_Mem_Op,
		X64_Mem_Op,
		X64_Mem_Op,
		X64_Mem_Op,
		X64_Mem_Op,
		X64_Mem_Op,
		X64_Mem_Op,
		X64_Mem_Op,
		X64_Mem_Op,
		X64_Mem_Op,
		X64_Mem_Op,
		X64_Mem_Op,
		X64_Mem_Op,
		X64_Mem_Op,
		X64_Mem_Op,
		X64_Mem_Op,
		X64_Mem_Op,
		X64_Mem_Op,
		X64_Mem_Op,
		X64_Mem_Op,
		X64_Mem_Op,
		X64_Mem_Op,
		X64_Mem_Op,
		X64_Mem_Op,
		X64_Mem_Op,
		X64_Mem_Op,
		backend.No_Extra,
		X64_Mem_Op,
		X64_Mem_Op,
		backend.No_Extra,
		X64_Mem_Op,
		backend.No_Extra,
		X64_Mem_Op,
		backend.No_Extra,
		X64_Mem_Op,
		X64_Mem_Op,
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
		`F_Ext`,
		`F_Demote`,
		`Splat`,
		`Ctz`,
		`Simd_Extract_Lsbs`,
		`Simd_Reduce_Add_Bisect`,
		`CV128`,
		`X64_Add`,
		`X64_Sub`,
		`X64_And`,
		`X64_Or`,
		`X64_Xor`,
		`X64_Eq`,
		`X64_Ne`,
		`X64_Le`,
		`X64_Lt`,
		`X64_Gt`,
		`X64_Ge`,
		`X64_U_Lt`,
		`X64_U_Gt`,
		`X64_U_Le`,
		`X64_U_Ge`,
		`X64_F_Add`,
		`X64_F_Sub`,
		`X64_F_Mul`,
		`X64_F_Div`,
		`X64_F_Eq`,
		`X64_F_Ne`,
		`X64_F_Le`,
		`X64_F_Lt`,
		`X64_F_Gt`,
		`X64_F_Ge`,
		`X64_Shl`,
		`X64_Shr`,
		`X64_U_Shr`,
		`X64_Mul`,
		`X64_Lea`,
		`X64_Load`,
		`X64_Store`,
		`X64_CLoad`,
		`X64_Neg`,
		`X64_Not`,
		`X64_Mul8`,
		`X64_Fma_213`,
		`X64_Pcmpeq`,
		`X64_Pshufd`,
		`X64_Psadbw`,
		`X64_Pshufb`,
		`X64_Pextr`,
	},
}

X64_Node_Type :: enum u16 {
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
	F_Ext,
	F_Demote,
	Splat,
	Ctz,
	Simd_Extract_Lsbs,
	Simd_Reduce_Add_Bisect,
	CV128,
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

x64_peep_inst :: proc(ctx: backend.Peep_Ctx, node: backend.Expanded_Node) -> backend.Node_ID {
	return x64_peep(ctx, node, struct{}{})
}
x64_post_schedule_peep_inst :: proc(
	ctx: backend.PS_Peep_Ctx, node: backend.Expanded_Node) -> backend.Node_ID {
	return x64_post_schedule_peep(ctx, node, struct{}{})
}


x64_collect_meta :: proc(ctx: ^backend.Graph,
	ra: ^backend.Regalloc, sched: ^backend.Graph_Schedule) -> []backend.Regalloc_Node_Meta {

	meta_of :: proc(ctx: ^backend.Graph, ra: ^backend.Regalloc,
		node: backend.Expanded_Node) -> backend.Regalloc_Node_Meta {
		return x64_meta_of(ctx, ra, node, struct{}{})
	}
	return backend.regalloc_collect_meta(ctx, ra, sched, meta_of)
}

#assert(size_of(backend.Cfg) % backend.PRECISION == 0)
#assert(size_of(backend.Cfg) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.Tup) % backend.PRECISION == 0)
#assert(size_of(backend.CInt) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.Local) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.Tup) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.Tup) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.Cfg) % backend.PRECISION == 0)
#assert(size_of(backend.Cfg) % backend.PRECISION == 0)
#assert(size_of(backend.Cfg) % backend.PRECISION == 0)
#assert(size_of(backend.Cfg) % backend.PRECISION == 0)
#assert(size_of(backend.Cfg) % backend.PRECISION == 0)
#assert(size_of(backend.Cfg) % backend.PRECISION == 0)
#assert(size_of(backend.Cfg) % backend.PRECISION == 0)
#assert(size_of(backend.Cfg) % backend.PRECISION == 0)
#assert(size_of(backend.Call) % backend.PRECISION == 0)
#assert(size_of(backend.Cfg) % backend.PRECISION == 0)
#assert(size_of(backend.Tup) % backend.PRECISION == 0)
#assert(size_of(backend.Cfg) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(backend.CV128) % backend.PRECISION == 0)
#assert(size_of(X64_Mem_Op) % backend.PRECISION == 0)
#assert(size_of(X64_Mem_Op) % backend.PRECISION == 0)
#assert(size_of(X64_Mem_Op) % backend.PRECISION == 0)
#assert(size_of(X64_Mem_Op) % backend.PRECISION == 0)
#assert(size_of(X64_Mem_Op) % backend.PRECISION == 0)
#assert(size_of(X64_Mem_Op) % backend.PRECISION == 0)
#assert(size_of(X64_Mem_Op) % backend.PRECISION == 0)
#assert(size_of(X64_Mem_Op) % backend.PRECISION == 0)
#assert(size_of(X64_Mem_Op) % backend.PRECISION == 0)
#assert(size_of(X64_Mem_Op) % backend.PRECISION == 0)
#assert(size_of(X64_Mem_Op) % backend.PRECISION == 0)
#assert(size_of(X64_Mem_Op) % backend.PRECISION == 0)
#assert(size_of(X64_Mem_Op) % backend.PRECISION == 0)
#assert(size_of(X64_Mem_Op) % backend.PRECISION == 0)
#assert(size_of(X64_Mem_Op) % backend.PRECISION == 0)
#assert(size_of(X64_Mem_Op) % backend.PRECISION == 0)
#assert(size_of(X64_Mem_Op) % backend.PRECISION == 0)
#assert(size_of(X64_Mem_Op) % backend.PRECISION == 0)
#assert(size_of(X64_Mem_Op) % backend.PRECISION == 0)
#assert(size_of(X64_Mem_Op) % backend.PRECISION == 0)
#assert(size_of(X64_Mem_Op) % backend.PRECISION == 0)
#assert(size_of(X64_Mem_Op) % backend.PRECISION == 0)
#assert(size_of(X64_Mem_Op) % backend.PRECISION == 0)
#assert(size_of(X64_Mem_Op) % backend.PRECISION == 0)
#assert(size_of(X64_Mem_Op) % backend.PRECISION == 0)
#assert(size_of(X64_Mem_Op) % backend.PRECISION == 0)
#assert(size_of(X64_Mem_Op) % backend.PRECISION == 0)
#assert(size_of(X64_Mem_Op) % backend.PRECISION == 0)
#assert(size_of(X64_Mem_Op) % backend.PRECISION == 0)
#assert(size_of(X64_Mem_Op) % backend.PRECISION == 0)
#assert(size_of(X64_Mem_Op) % backend.PRECISION == 0)
#assert(size_of(X64_Mem_Op) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(X64_Mem_Op) % backend.PRECISION == 0)
#assert(size_of(X64_Mem_Op) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(X64_Mem_Op) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
#assert(size_of(X64_Mem_Op) % backend.PRECISION == 0)
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
graph_add_x64_psadbw :: #force_inline proc(graph: ^backend.Graph, name: string, dt: backend.Node_Datatype, lhs: backend.Node_ID, rhs: backend.Node_ID) -> (id: backend.Node_ID) {
	backend.push_node_name(graph, name)
	return backend.graph_add_raw(graph, u16(X64_Node_Type.X64_Psadbw), dt, {lhs, rhs})
}
#assert(size_of(X64_Mem_Op) % backend.PRECISION == 0)
#assert(size_of(X64_Mem_Op) % backend.PRECISION == 0)

inherit_idx_of :: #force_inline proc($T: typeid) -> u8 {
	when false {}
	else when T == backend.CInt {return 3}
	else when T == backend.Tup {return 2}
	else when T == backend.Local {return 4}
	else when T == backend.No_Extra {return 1}
	else when T == backend.Call {return 5}
	else when T == X64_Mem_Op {return 7}
	else when T == backend.Cfg {return 0}
	else when T == backend.CV128 {return 6}
	else {#panic(`the passed type is not subclass of anything`)}
}
}
