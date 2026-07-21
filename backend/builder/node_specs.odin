package builder
import backend ".."
Reg_Kind :: backend.Reg_Kind
Class_Flag :: backend.Class_Flag
// NOTE: this file is generated: odin run backend/builder -define:BUILDER_GEN_SPEC=true

when !GEN_SPEC {
SPEC := backend.Node_Spec{
	cc_table = {
	},
	call_clobbers = {
	},
	class_lengths = {.General = 0, .Vector = 0},
	datatype_to_reg_kind = {.Void = Reg_Kind.General, .I8 = Reg_Kind.General, .I16 = Reg_Kind.General, .I32 = Reg_Kind.General, .I64 = Reg_Kind.General, .F32 = Reg_Kind.General, .F64 = Reg_Kind.General},
	clobbers = {
		{.General = 0, .Vector = 0}, // Start
		{.General = 0, .Vector = 0}, // Entry
		{.General = 0, .Vector = 0}, // Poison
		{.General = 0, .Vector = 0}, // Param
		{.General = 0, .Vector = 0}, // CInt
		{.General = 0, .Vector = 0}, // Add
		{.General = 0, .Vector = 0}, // Sub
		{.General = 0, .Vector = 0}, // And
		{.General = 0, .Vector = 0}, // Or
		{.General = 0, .Vector = 0}, // Xor
		{.General = 0, .Vector = 0}, // Eq
		{.General = 0, .Vector = 0}, // Ne
		{.General = 0, .Vector = 0}, // Le
		{.General = 0, .Vector = 0}, // Lt
		{.General = 0, .Vector = 0}, // Gt
		{.General = 0, .Vector = 0}, // Ge
		{.General = 0, .Vector = 0}, // U_Lt
		{.General = 0, .Vector = 0}, // U_Gt
		{.General = 0, .Vector = 0}, // U_Le
		{.General = 0, .Vector = 0}, // U_Ge
		{.General = 0, .Vector = 0}, // F_Add
		{.General = 0, .Vector = 0}, // F_Sub
		{.General = 0, .Vector = 0}, // F_Mul
		{.General = 0, .Vector = 0}, // F_Div
		{.General = 0, .Vector = 0}, // F_Eq
		{.General = 0, .Vector = 0}, // F_Ne
		{.General = 0, .Vector = 0}, // F_Lt
		{.General = 0, .Vector = 0}, // F_Le
		{.General = 0, .Vector = 0}, // F_Gt
		{.General = 0, .Vector = 0}, // F_Ge
		{.General = 0, .Vector = 0}, // Shl
		{.General = 0, .Vector = 0}, // Shr
		{.General = 0, .Vector = 0}, // U_Shr
		{.General = 0, .Vector = 0}, // Mul
		{.General = 0, .Vector = 0}, // Div
		{.General = 0, .Vector = 0}, // U_Div
		{.General = 0, .Vector = 0}, // Rem
		{.General = 0, .Vector = 0}, // U_Rem
		{.General = 0, .Vector = 0}, // And_Not
		{.General = 0, .Vector = 0}, // Split
		{.General = 0, .Vector = 0}, // Phi
		{.General = 0, .Vector = 0}, // Mem
		{.General = 0, .Vector = 0}, // Sym
		{.General = 0, .Vector = 0}, // Local
		{.General = 0, .Vector = 0}, // Local_Addr
		{.General = 0, .Vector = 0}, // Global
		{.General = 0, .Vector = 0}, // Global_Addr
		{.General = 0, .Vector = 0}, // Proc_Addr
		{.General = 0, .Vector = 0}, // Copy
		{.General = 0, .Vector = 0}, // Set
		{.General = 0, .Vector = 0}, // Store
		{.General = 0, .Vector = 0}, // Load
		{.General = 0, .Vector = 0}, // Load_S
		{.General = 0, .Vector = 0}, // If
		{.General = 0, .Vector = 0}, // Then
		{.General = 0, .Vector = 0}, // Else
		{.General = 0, .Vector = 0}, // Jump
		{.General = 0, .Vector = 0}, // Region
		{.General = 0, .Vector = 0}, // Loop
		{.General = 0, .Vector = 0}, // Always
		{.General = 0, .Vector = 0}, // Call
		{.General = 0, .Vector = 0}, // Call_End
		{.General = 0, .Vector = 0}, // Ret
		{.General = 0, .Vector = 0}, // Return
		{.General = 0, .Vector = 0}, // Neg
		{.General = 0, .Vector = 0}, // Not
		{.General = 0, .Vector = 0}, // Sext
		{.General = 0, .Vector = 0}, // Uext
		{.General = 0, .Vector = 0}, // Cast
		{.General = 0, .Vector = 0}, // F_To_I
		{.General = 0, .Vector = 0}, // F_From_I
		{.General = 0, .Vector = 0}, // F_Ext
		{.General = 0, .Vector = 0}, // F_Demote
		{.General = 0, .Vector = 0}, // Scope
		{.General = 0, .Vector = 0}, // Lazy_Phi
		{.General = 0, .Vector = 0}, // Dead
	},
	interned_reg_masks = {
		raw_data([]i64{}),
	},
	reg_masks = {
		{}, // Start
		{}, // Entry
		{}, // Poison
		{}, // Param
		{}, // CInt
		{}, // Add
		{}, // Sub
		{}, // And
		{}, // Or
		{}, // Xor
		{}, // Eq
		{}, // Ne
		{}, // Le
		{}, // Lt
		{}, // Gt
		{}, // Ge
		{}, // U_Lt
		{}, // U_Gt
		{}, // U_Le
		{}, // U_Ge
		{}, // F_Add
		{}, // F_Sub
		{}, // F_Mul
		{}, // F_Div
		{}, // F_Eq
		{}, // F_Ne
		{}, // F_Lt
		{}, // F_Le
		{}, // F_Gt
		{}, // F_Ge
		{}, // Shl
		{}, // Shr
		{}, // U_Shr
		{}, // Mul
		{}, // Div
		{}, // U_Div
		{}, // Rem
		{}, // U_Rem
		{}, // And_Not
		{}, // Split
		{}, // Phi
		{}, // Mem
		{}, // Sym
		{}, // Local
		{}, // Local_Addr
		{}, // Global
		{}, // Global_Addr
		{}, // Proc_Addr
		{}, // Copy
		{}, // Set
		{}, // Store
		{}, // Load
		{}, // Load_S
		{}, // If
		{}, // Then
		{}, // Else
		{}, // Jump
		{}, // Region
		{}, // Loop
		{}, // Always
		{}, // Call
		{}, // Call_End
		{}, // Ret
		{}, // Return
		{}, // Neg
		{}, // Not
		{}, // Sext
		{}, // Uext
		{}, // Cast
		{}, // F_To_I
		{}, // F_From_I
		{}, // F_Ext
		{}, // F_Demote
		{}, // Scope
		{}, // Lazy_Phi
		{}, // Dead
	},
	inplace_slot_idxs = {
		-16, //Start
		-16, //Entry
		-16, //Poison
		-16, //Param
		-16, //CInt
		-16, //Add
		-16, //Sub
		-16, //And
		-16, //Or
		-16, //Xor
		-16, //Eq
		-16, //Ne
		-16, //Le
		-16, //Lt
		-16, //Gt
		-16, //Ge
		-16, //U_Lt
		-16, //U_Gt
		-16, //U_Le
		-16, //U_Ge
		-16, //F_Add
		-16, //F_Sub
		-16, //F_Mul
		-16, //F_Div
		-16, //F_Eq
		-16, //F_Ne
		-16, //F_Lt
		-16, //F_Le
		-16, //F_Gt
		-16, //F_Ge
		-16, //Shl
		-16, //Shr
		-16, //U_Shr
		-16, //Mul
		-16, //Div
		-16, //U_Div
		-16, //Rem
		-16, //U_Rem
		-16, //And_Not
		-16, //Split
		-16, //Phi
		-16, //Mem
		-16, //Sym
		-16, //Local
		-16, //Local_Addr
		-16, //Global
		-16, //Global_Addr
		-16, //Proc_Addr
		-16, //Copy
		-16, //Set
		-16, //Store
		-16, //Load
		-16, //Load_S
		-16, //If
		-16, //Then
		-16, //Else
		-16, //Jump
		-16, //Region
		-16, //Loop
		-16, //Always
		-16, //Call
		-16, //Call_End
		-16, //Ret
		-16, //Return
		-16, //Neg
		-16, //Not
		-16, //Sext
		-16, //Uext
		-16, //Cast
		-16, //F_To_I
		-16, //F_From_I
		-16, //F_Ext
		-16, //F_Demote
		-16, //Scope
		-16, //Lazy_Phi
		-16, //Dead
	},
	peep = builder_peep_inst,
	post_schedule_peep = builder_post_schedule_peep_inst,
	intern = true,
	first_input_idxs = {
		0, //Start
		0, //Entry
		0, //Poison
		0, //Param
		0, //CInt
		0, //Add
		0, //Sub
		0, //And
		0, //Or
		0, //Xor
		0, //Eq
		0, //Ne
		0, //Le
		0, //Lt
		0, //Gt
		0, //Ge
		0, //U_Lt
		0, //U_Gt
		0, //U_Le
		0, //U_Ge
		0, //F_Add
		0, //F_Sub
		0, //F_Mul
		0, //F_Div
		0, //F_Eq
		0, //F_Ne
		0, //F_Lt
		0, //F_Le
		0, //F_Gt
		0, //F_Ge
		0, //Shl
		0, //Shr
		0, //U_Shr
		0, //Mul
		0, //Div
		0, //U_Div
		0, //Rem
		0, //U_Rem
		0, //And_Not
		0, //Split
		0, //Phi
		0, //Mem
		0, //Sym
		0, //Local
		0, //Local_Addr
		0, //Global
		0, //Global_Addr
		0, //Proc_Addr
		0, //Copy
		0, //Set
		0, //Store
		0, //Load
		0, //Load_S
		0, //If
		0, //Then
		0, //Else
		0, //Jump
		0, //Region
		0, //Loop
		0, //Always
		0, //Call
		0, //Call_End
		0, //Ret
		0, //Return
		0, //Neg
		0, //Not
		0, //Sext
		0, //Uext
		0, //Cast
		0, //F_To_I
		0, //F_From_I
		0, //F_Ext
		0, //F_Demote
		0, //Scope
		0, //Lazy_Phi
		0, //Dead
	},
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
		0b10, // Load_S
		0b1, // If
		0b1, // Then
		0b1, // Else
		0b1, // Jump
		0b1, // Region
		0b1, // Loop
		0b1, // Always
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
		0b1000000, // Scope
		0b10, // Lazy_Phi
		0b10, // Dead
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
		0, // Load_S -> No_Extra
		1, // If -> Cfg
		1, // Then -> Cfg
		1, // Else -> Cfg
		1, // Jump -> Cfg
		1, // Region -> Cfg
		1, // Loop -> Cfg
		1, // Always -> Cfg
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
		1, // Scope -> Scope
		0, // Lazy_Phi -> No_Extra
		0, // Dead -> No_Extra
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
		{Class_Flag.Interned, Class_Flag.Load}, // Load_S
		{}, // If
		{Class_Flag.Is_Basic_Block_Start}, // Then
		{Class_Flag.Is_Basic_Block_Start}, // Else
		{}, // Jump
		{Class_Flag.Is_Basic_Block_Start}, // Region
		{Class_Flag.Is_Basic_Block_Start}, // Loop
		{}, // Always
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
		{}, // Scope
		{}, // Lazy_Phi
		{}, // Dead
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
		backend.No_Extra,
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
		Scope,
		backend.No_Extra,
		backend.No_Extra,
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
		`Load_S`,
		`If`,
		`Then`,
		`Else`,
		`Jump`,
		`Region`,
		`Loop`,
		`Always`,
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
		`Scope`,
		`Lazy_Phi`,
		`Dead`,
	},
}

Builder_Node_Type :: enum u16 {
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
	Load_S,
	If,
	Then,
	Else,
	Jump,
	Region,
	Loop,
	Always,
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
	Scope,
	Lazy_Phi,
	Dead,
}

builder_peep_inst :: proc(ctx: backend.Peep_Ctx, node: backend.Expanded_Node) -> backend.Node_ID {
	return builder_peep(ctx, node, struct{}{})
}
builder_post_schedule_peep_inst :: proc(
	ctx: backend.PS_Peep_Ctx, node: backend.Expanded_Node) -> backend.Node_ID {
	return builder_post_schedule_peep(ctx, node, struct{}{})
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
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
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
#assert(size_of(Scope) % backend.PRECISION == 0)
graph_add_scope :: #force_inline proc(graph: ^backend.Graph, name: string, cfg: backend.Node_ID) -> (id: backend.Node_ID) {
	backend.push_node_name(graph, name)
	(^Scope)(backend.graph_get_next_extra_slot(graph, u16(Builder_Node_Type.Scope)))^ = {}
	return backend.graph_add_raw(graph, u16(Builder_Node_Type.Scope), .Void, {cfg})
}
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
graph_add_lazy_phi :: #force_inline proc(graph: ^backend.Graph, name: string, dt: backend.Node_Datatype, reg: backend.Node_ID, lhs: backend.Node_ID) -> (id: backend.Node_ID) {
	backend.push_node_name(graph, name)
	return backend.graph_add_raw(graph, u16(Builder_Node_Type.Lazy_Phi), dt, {reg, lhs}, extra_capacity = 1)
}
#assert(size_of(backend.No_Extra) % backend.PRECISION == 0)
graph_add_dead :: #force_inline proc(graph: ^backend.Graph, name: string) -> (id: backend.Node_ID) {
	backend.push_node_name(graph, name)
	return backend.graph_add_raw(graph, u16(Builder_Node_Type.Dead), .Void, {})
}

inherit_idx_of :: #force_inline proc($T: typeid) -> u8 {
	when false {}
	else when T == backend.CInt {return 3}
	else when T == backend.Tup {return 2}
	else when T == backend.Local {return 4}
	else when T == Scope {return 6}
	else when T == backend.No_Extra {return 1}
	else when T == backend.Call {return 5}
	else when T == backend.Cfg {return 0}
	else {#panic(`the passed type is not subclass of anything`)}
}
}
