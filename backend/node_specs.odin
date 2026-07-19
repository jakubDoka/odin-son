package backend
// NOTE: this file is generated: odin run backend -define:GEN_SPEC=true

when !GEN_SPEC {
SPECS := [Node_Spec_Name]Node_Spec{
	.Builder = {
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
			{.General = 0, .Vector = 0}, // Arg
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
			{}, // Arg
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
			-16, //Arg
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
		first_input_idxs = {
			0, //Start
			0, //Entry
			0, //Poison
			0, //Arg
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
			0b100, // Arg
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
			1, // Arg -> Tup
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
			1, // Local -> Local
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
			{}, // Arg
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
			Cfg,
			Cfg,
			No_Extra,
			Tup,
			CInt,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			Local,
			No_Extra,
			Tup,
			No_Extra,
			Tup,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			Cfg,
			Cfg,
			Cfg,
			Cfg,
			Cfg,
			Cfg,
			Cfg,
			Call,
			Cfg,
			Tup,
			Cfg,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			Scope,
			No_Extra,
			No_Extra,
		},
		node_kind_name = {
			`Start`,
			`Entry`,
			`Poison`,
			`Arg`,
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
	},
	.X64 = {
		cc_table = {
			X64_SYSTEMV_CC,
			X64_LINUX_SYSCALL_CC,
		},
		call_clobbers = {
			{.General = 4039, .Vector = 65535},
			{.General = 2051, .Vector = 0},
		},
		class_lengths = {.General = 1, .Vector = 1},
		datatype_to_reg_kind = {.Void = Reg_Kind.General, .I8 = Reg_Kind.General, .I16 = Reg_Kind.General, .I32 = Reg_Kind.General, .I64 = Reg_Kind.General, .F32 = Reg_Kind.Vector, .F64 = Reg_Kind.Vector},
		clobbers = {
			{.General = 0, .Vector = 0}, // Start
			{.General = 0, .Vector = 0}, // Entry
			{.General = 0, .Vector = 0}, // Poison
			{.General = 0, .Vector = 0}, // Arg
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
			{.General = 4, .Vector = 0}, // Div
			{.General = 4, .Vector = 0}, // U_Div
			{.General = 1, .Vector = 0}, // Rem
			{.General = 1, .Vector = 0}, // U_Rem
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
			{.General = 0, .Vector = 0}, // X64_Add
			{.General = 0, .Vector = 0}, // X64_Sub
			{.General = 0, .Vector = 0}, // X64_And
			{.General = 0, .Vector = 0}, // X64_Or
			{.General = 0, .Vector = 0}, // X64_Xor
			{.General = 0, .Vector = 0}, // X64_Eq
			{.General = 0, .Vector = 0}, // X64_Ne
			{.General = 0, .Vector = 0}, // X64_Le
			{.General = 0, .Vector = 0}, // X64_Lt
			{.General = 0, .Vector = 0}, // X64_Gt
			{.General = 0, .Vector = 0}, // X64_Ge
			{.General = 0, .Vector = 0}, // X64_U_Lt
			{.General = 0, .Vector = 0}, // X64_U_Gt
			{.General = 0, .Vector = 0}, // X64_U_Le
			{.General = 0, .Vector = 0}, // X64_U_Ge
			{.General = 0, .Vector = 0}, // X64_F_Add
			{.General = 0, .Vector = 0}, // X64_F_Sub
			{.General = 0, .Vector = 0}, // X64_F_Mul
			{.General = 0, .Vector = 0}, // X64_F_Div
			{.General = 0, .Vector = 0}, // X64_F_Eq
			{.General = 0, .Vector = 0}, // X64_F_Ne
			{.General = 0, .Vector = 0}, // X64_F_Le
			{.General = 0, .Vector = 0}, // X64_F_Lt
			{.General = 0, .Vector = 0}, // X64_F_Gt
			{.General = 0, .Vector = 0}, // X64_F_Ge
			{.General = 0, .Vector = 0}, // X64_Shl
			{.General = 0, .Vector = 0}, // X64_Shr
			{.General = 0, .Vector = 0}, // X64_U_Shr
			{.General = 0, .Vector = 0}, // X64_Mul
			{.General = 0, .Vector = 0}, // X64_Lea
			{.General = 0, .Vector = 0}, // X64_Load
			{.General = 0, .Vector = 0}, // X64_Store
			{.General = 0, .Vector = 0}, // X64_CLoad
			{.General = 0, .Vector = 0}, // X64_Neg
			{.General = 0, .Vector = 0}, // X64_Not
			{.General = 0, .Vector = 0}, // X64_Mul8
			{.General = 0, .Vector = 0}, // X64_Fma_213
		},
		interned_reg_masks = {
			raw_data([]i64{}),
			raw_data([]i64{0xffef}),
			raw_data([]i64{0xffff}),
			raw_data([]i64{0x0}),
			raw_data([]i64{0x2}),
			raw_data([]i64{0x1}),
			raw_data([]i64{0xffea}),
			raw_data([]i64{0x4}),
			raw_data([]i64{0xffffffffffffffef}),
			raw_data([]i64{0xffffffffffffffff}),
			raw_data([]i64{0x80}),
			raw_data([]i64{0x40}),
		},
		reg_masks = {
			{}, // Start
			{}, // Entry
			{}, // Poison
			{}, // Arg
			{{.General = 1, .Vector = 2}}, // CInt
			{{.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}}, // Add
			{{.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}}, // Sub
			{{.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}}, // And
			{{.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}}, // Or
			{{.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}}, // Xor
			{{.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}}, // Eq
			{{.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}}, // Ne
			{{.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}}, // Le
			{{.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}}, // Lt
			{{.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}}, // Gt
			{{.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}}, // Ge
			{{.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}}, // U_Lt
			{{.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}}, // U_Gt
			{{.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}}, // U_Le
			{{.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}}, // U_Ge
			{{.General = 0, .Vector = 2}, {.General = 0, .Vector = 2}, {.General = 0, .Vector = 2}}, // F_Add
			{{.General = 0, .Vector = 2}, {.General = 0, .Vector = 2}, {.General = 0, .Vector = 2}}, // F_Sub
			{{.General = 0, .Vector = 2}, {.General = 0, .Vector = 2}, {.General = 0, .Vector = 2}}, // F_Mul
			{{.General = 0, .Vector = 2}, {.General = 0, .Vector = 2}, {.General = 0, .Vector = 2}}, // F_Div
			{{.General = 1, .Vector = 3}, {.General = 0, .Vector = 2}, {.General = 0, .Vector = 2}}, // F_Eq
			{{.General = 1, .Vector = 3}, {.General = 0, .Vector = 2}, {.General = 0, .Vector = 2}}, // F_Ne
			{{.General = 1, .Vector = 3}, {.General = 0, .Vector = 2}, {.General = 0, .Vector = 2}}, // F_Lt
			{{.General = 1, .Vector = 3}, {.General = 0, .Vector = 2}, {.General = 0, .Vector = 2}}, // F_Le
			{{.General = 1, .Vector = 3}, {.General = 0, .Vector = 2}, {.General = 0, .Vector = 2}}, // F_Gt
			{{.General = 1, .Vector = 3}, {.General = 0, .Vector = 2}, {.General = 0, .Vector = 2}}, // F_Ge
			{{.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}, {.General = 4, .Vector = 0}}, // Shl
			{{.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}, {.General = 4, .Vector = 0}}, // Shr
			{{.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}, {.General = 4, .Vector = 0}}, // U_Shr
			{{.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}}, // Mul
			{{.General = 5, .Vector = 0}, {.General = 5, .Vector = 0}, {.General = 6, .Vector = 0}}, // Div
			{{.General = 5, .Vector = 0}, {.General = 5, .Vector = 0}, {.General = 6, .Vector = 0}}, // U_Div
			{{.General = 7, .Vector = 0}, {.General = 5, .Vector = 0}, {.General = 6, .Vector = 0}}, // Rem
			{{.General = 7, .Vector = 0}, {.General = 5, .Vector = 0}, {.General = 6, .Vector = 0}}, // U_Rem
			{{.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}}, // And_Not
			{{.General = 8, .Vector = 9}, {.General = 8, .Vector = 9}}, // Split
			{{.General = 8, .Vector = 9}, {.General = 8, .Vector = 9}, {.General = 8, .Vector = 9}, {.General = 8, .Vector = 9}, {.General = 8, .Vector = 9}}, // Phi
			{}, // Mem
			{}, // Sym
			{}, // Local
			{{.General = 1, .Vector = 0}}, // Local_Addr
			{}, // Global
			{{.General = 1, .Vector = 0}}, // Global_Addr
			{{.General = 1, .Vector = 0}}, // Proc_Addr
			{{.General = 3, .Vector = 0}, {.General = 10, .Vector = 0}, {.General = 11, .Vector = 0}, {.General = 7, .Vector = 0}}, // Copy
			{{.General = 3, .Vector = 0}, {.General = 10, .Vector = 0}, {.General = 11, .Vector = 0}, {.General = 7, .Vector = 0}}, // Set
			{{.General = 3, .Vector = 3}, {.General = 1, .Vector = 2}, {.General = 1, .Vector = 2}}, // Store
			{{.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}}, // Load
			{{.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}}, // Load_S
			{{.General = 3, .Vector = 0}, {.General = 1, .Vector = 0}}, // If
			{}, // Then
			{}, // Else
			{}, // Jump
			{}, // Region
			{}, // Loop
			{}, // Always
			{}, // Call
			{}, // Call_End
			{}, // Ret
			{{.General = 3, .Vector = 0}, {.General = 5, .Vector = 0}, {.General = 7, .Vector = 0}}, // Return
			{{.General = 1, .Vector = 2}, {.General = 1, .Vector = 2}}, // Neg
			{{.General = 1, .Vector = 2}, {.General = 1, .Vector = 2}}, // Not
			{{.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}}, // Sext
			{{.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}}, // Uext
			{{.General = 1, .Vector = 2}, {.General = 1, .Vector = 2}}, // Cast
			{{.General = 1, .Vector = 3}, {.General = 0, .Vector = 2}}, // F_To_I
			{{.General = 3, .Vector = 2}, {.General = 1, .Vector = 0}}, // F_From_I
			{{.General = 0, .Vector = 2}, {.General = 0, .Vector = 2}}, // F_Ext
			{{.General = 0, .Vector = 2}, {.General = 0, .Vector = 2}}, // F_Demote
			{{.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}}, // X64_Add
			{{.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}}, // X64_Sub
			{{.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}}, // X64_And
			{{.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}}, // X64_Or
			{{.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}}, // X64_Xor
			{{.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}}, // X64_Eq
			{{.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}}, // X64_Ne
			{{.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}}, // X64_Le
			{{.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}}, // X64_Lt
			{{.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}}, // X64_Gt
			{{.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}}, // X64_Ge
			{{.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}}, // X64_U_Lt
			{{.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}}, // X64_U_Gt
			{{.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}}, // X64_U_Le
			{{.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}}, // X64_U_Ge
			{{.General = 3, .Vector = 2}, {.General = 1, .Vector = 2}, {.General = 1, .Vector = 2}, {.General = 1, .Vector = 3}}, // X64_F_Add
			{{.General = 3, .Vector = 2}, {.General = 1, .Vector = 2}, {.General = 1, .Vector = 2}, {.General = 1, .Vector = 3}}, // X64_F_Sub
			{{.General = 3, .Vector = 2}, {.General = 1, .Vector = 2}, {.General = 1, .Vector = 2}, {.General = 1, .Vector = 3}}, // X64_F_Mul
			{{.General = 3, .Vector = 2}, {.General = 1, .Vector = 2}, {.General = 1, .Vector = 2}, {.General = 1, .Vector = 3}}, // X64_F_Div
			{{.General = 1, .Vector = 2}, {.General = 1, .Vector = 2}, {.General = 1, .Vector = 2}, {.General = 1, .Vector = 2}}, // X64_F_Eq
			{{.General = 1, .Vector = 2}, {.General = 1, .Vector = 2}, {.General = 1, .Vector = 2}, {.General = 1, .Vector = 2}}, // X64_F_Ne
			{{.General = 1, .Vector = 2}, {.General = 1, .Vector = 2}, {.General = 1, .Vector = 2}, {.General = 1, .Vector = 2}}, // X64_F_Le
			{{.General = 1, .Vector = 2}, {.General = 1, .Vector = 2}, {.General = 1, .Vector = 2}, {.General = 1, .Vector = 2}}, // X64_F_Lt
			{{.General = 1, .Vector = 2}, {.General = 1, .Vector = 2}, {.General = 1, .Vector = 2}, {.General = 1, .Vector = 2}}, // X64_F_Gt
			{{.General = 1, .Vector = 2}, {.General = 1, .Vector = 2}, {.General = 1, .Vector = 2}, {.General = 1, .Vector = 2}}, // X64_F_Ge
			{{.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}, {.General = 4, .Vector = 0}}, // X64_Shl
			{{.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}, {.General = 4, .Vector = 0}}, // X64_Shr
			{{.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}, {.General = 4, .Vector = 0}}, // X64_U_Shr
			{{.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}}, // X64_Mul
			{{.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}, {.General = 1, .Vector = 0}}, // X64_Lea
			{{.General = 1, .Vector = 2}, {.General = 1, .Vector = 2}, {.General = 1, .Vector = 2}}, // X64_Load
			{{.General = 3, .Vector = 3}, {.General = 1, .Vector = 2}, {.General = 1, .Vector = 2}, {.General = 1, .Vector = 2}}, // X64_Store
			{{.General = 1, .Vector = 2}}, // X64_CLoad
			{{.General = 1, .Vector = 2}, {.General = 1, .Vector = 2}}, // X64_Neg
			{{.General = 1, .Vector = 2}, {.General = 1, .Vector = 2}}, // X64_Not
			{{.General = 5, .Vector = 0}, {.General = 1, .Vector = 0}, {.General = 5, .Vector = 0}}, // X64_Mul8
			{{.General = 1, .Vector = 2}, {.General = 1, .Vector = 2}, {.General = 1, .Vector = 2}, {.General = 1, .Vector = 2}}, // X64_Fma_213
		},
		inplace_slot_idxs = {
			-16, //Start
			-16, //Entry
			-16, //Poison
			-16, //Arg
			-16, //CInt
			0, //Add
			0, //Sub
			0, //And
			0, //Or
			0, //Xor
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
			0, //F_Add
			0, //F_Sub
			0, //F_Mul
			0, //F_Div
			-16, //F_Eq
			-16, //F_Ne
			-16, //F_Lt
			-16, //F_Le
			-16, //F_Gt
			-16, //F_Ge
			0, //Shl
			0, //Shr
			0, //U_Shr
			0, //Mul
			0, //Div
			0, //U_Div
			-16, //Rem
			-16, //U_Rem
			1, //And_Not
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
			0, //Neg
			0, //Not
			-16, //Sext
			-16, //Uext
			0, //Cast
			-16, //F_To_I
			-16, //F_From_I
			-16, //F_Ext
			-16, //F_Demote
			0, //X64_Add
			0, //X64_Sub
			0, //X64_And
			0, //X64_Or
			0, //X64_Xor
			-16, //X64_Eq
			-16, //X64_Ne
			-16, //X64_Le
			-16, //X64_Lt
			-16, //X64_Gt
			-16, //X64_Ge
			-16, //X64_U_Lt
			-16, //X64_U_Gt
			-16, //X64_U_Le
			-16, //X64_U_Ge
			0, //X64_F_Add
			0, //X64_F_Sub
			0, //X64_F_Mul
			0, //X64_F_Div
			-16, //X64_F_Eq
			-16, //X64_F_Ne
			-16, //X64_F_Le
			-16, //X64_F_Lt
			-16, //X64_F_Gt
			-16, //X64_F_Ge
			0, //X64_Shl
			0, //X64_Shr
			0, //X64_U_Shr
			-16, //X64_Mul
			-16, //X64_Lea
			-16, //X64_Load
			-16, //X64_Store
			-16, //X64_CLoad
			0, //X64_Neg
			0, //X64_Not
			-16, //X64_Mul8
			0, //X64_Fma_213
		},
		reg_mask_of = x64_reg_mask_of,
		emit_function = x64_emit_function,
		peep = x64_peep_inst,
		post_schedule_peep = x64_post_schedule_peep_inst,
		first_input_idxs = {
			0, //Start
			0, //Entry
			0, //Poison
			1, //Arg
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
			1, //Phi
			1, //Mem
			1, //Sym
			1, //Local
			1, //Local_Addr
			0, //Global
			1, //Global_Addr
			0, //Proc_Addr
			2, //Copy
			2, //Set
			2, //Store
			2, //Load
			2, //Load_S
			1, //If
			0, //Then
			0, //Else
			1, //Jump
			0, //Region
			0, //Loop
			1, //Always
			3, //Call
			0, //Call_End
			1, //Ret
			2, //Return
			0, //Neg
			0, //Not
			0, //Sext
			0, //Uext
			0, //Cast
			0, //F_To_I
			0, //F_From_I
			0, //F_Ext
			0, //F_Demote
			0, //X64_Add
			0, //X64_Sub
			0, //X64_And
			0, //X64_Or
			0, //X64_Xor
			0, //X64_Eq
			0, //X64_Ne
			0, //X64_Le
			0, //X64_Lt
			0, //X64_Gt
			0, //X64_Ge
			0, //X64_U_Lt
			0, //X64_U_Gt
			0, //X64_U_Le
			0, //X64_U_Ge
			0, //X64_F_Add
			0, //X64_F_Sub
			0, //X64_F_Mul
			0, //X64_F_Div
			0, //X64_F_Eq
			0, //X64_F_Ne
			0, //X64_F_Le
			0, //X64_F_Lt
			0, //X64_F_Gt
			0, //X64_F_Ge
			0, //X64_Shl
			0, //X64_Shr
			0, //X64_U_Shr
			0, //X64_Mul
			0, //X64_Lea
			2, //X64_Load
			2, //X64_Store
			1, //X64_CLoad
			0, //X64_Neg
			0, //X64_Not
			0, //X64_Mul8
			0, //X64_Fma_213
		},
		inheritance_table = {
			0b1, // Start
			0b1, // Entry
			0b10, // Poison
			0b100, // Arg
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
			0b1000000, // X64_Add
			0b1000000, // X64_Sub
			0b1000000, // X64_And
			0b1000000, // X64_Or
			0b1000000, // X64_Xor
			0b1000000, // X64_Eq
			0b1000000, // X64_Ne
			0b1000000, // X64_Le
			0b1000000, // X64_Lt
			0b1000000, // X64_Gt
			0b1000000, // X64_Ge
			0b1000000, // X64_U_Lt
			0b1000000, // X64_U_Gt
			0b1000000, // X64_U_Le
			0b1000000, // X64_U_Ge
			0b1000000, // X64_F_Add
			0b1000000, // X64_F_Sub
			0b1000000, // X64_F_Mul
			0b1000000, // X64_F_Div
			0b1000000, // X64_F_Eq
			0b1000000, // X64_F_Ne
			0b1000000, // X64_F_Le
			0b1000000, // X64_F_Lt
			0b1000000, // X64_F_Gt
			0b1000000, // X64_F_Ge
			0b1000000, // X64_Shl
			0b1000000, // X64_Shr
			0b1000000, // X64_U_Shr
			0b1000000, // X64_Mul
			0b1000000, // X64_Lea
			0b1000000, // X64_Load
			0b1000000, // X64_Store
			0b10, // X64_CLoad
			0b1000000, // X64_Neg
			0b1000000, // X64_Not
			0b10, // X64_Mul8
			0b1000000, // X64_Fma_213
		},
		node_extra_sizes = {
			1, // Start -> Cfg
			1, // Entry -> Cfg
			0, // Poison -> No_Extra
			1, // Arg -> Tup
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
			1, // Local -> Local
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
		},
		node_flags = {
			{}, // Start
			{Class_Flag.Is_Basic_Block_Start}, // Entry
			{Class_Flag.Interned}, // Poison
			{}, // Arg
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
		},
		node_extra_types = {
			Cfg,
			Cfg,
			No_Extra,
			Tup,
			CInt,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			Local,
			No_Extra,
			Tup,
			No_Extra,
			Tup,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			Cfg,
			Cfg,
			Cfg,
			Cfg,
			Cfg,
			Cfg,
			Cfg,
			Call,
			Cfg,
			Tup,
			Cfg,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
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
			No_Extra,
			X64_Mem_Op,
			X64_Mem_Op,
			No_Extra,
			X64_Mem_Op,
		},
		node_kind_name = {
			`Start`,
			`Entry`,
			`Poison`,
			`Arg`,
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
		},
	},
}

Un_Op :: enum u16 {
	F_To_I = u16(Ideal_Node_Type.F_To_I),
	Cast = u16(Ideal_Node_Type.Cast),
	F_Ext = u16(Ideal_Node_Type.F_Ext),
	F_From_I = u16(Ideal_Node_Type.F_From_I),
	Not = u16(Ideal_Node_Type.Not),
	Neg = u16(Ideal_Node_Type.Neg),
	Uext = u16(Ideal_Node_Type.Uext),
	Sext = u16(Ideal_Node_Type.Sext),
	F_Demote = u16(Ideal_Node_Type.F_Demote),
}
Bin_Op :: enum u16 {
	Add = u16(Ideal_Node_Type.Add),
	Rem = u16(Ideal_Node_Type.Rem),
	And = u16(Ideal_Node_Type.And),
	And_Not = u16(Ideal_Node_Type.And_Not),
	U_Shr = u16(Ideal_Node_Type.U_Shr),
	Div = u16(Ideal_Node_Type.Div),
	Lt = u16(Ideal_Node_Type.Lt),
	Ge = u16(Ideal_Node_Type.Ge),
	Xor = u16(Ideal_Node_Type.Xor),
	Ne = u16(Ideal_Node_Type.Ne),
	F_Sub = u16(Ideal_Node_Type.F_Sub),
	F_Div = u16(Ideal_Node_Type.F_Div),
	U_Gt = u16(Ideal_Node_Type.U_Gt),
	U_Ge = u16(Ideal_Node_Type.U_Ge),
	F_Ge = u16(Ideal_Node_Type.F_Ge),
	Shr = u16(Ideal_Node_Type.Shr),
	F_Ne = u16(Ideal_Node_Type.F_Ne),
	F_Le = u16(Ideal_Node_Type.F_Le),
	U_Rem = u16(Ideal_Node_Type.U_Rem),
	Sub = u16(Ideal_Node_Type.Sub),
	Mul = u16(Ideal_Node_Type.Mul),
	U_Div = u16(Ideal_Node_Type.U_Div),
	Le = u16(Ideal_Node_Type.Le),
	Gt = u16(Ideal_Node_Type.Gt),
	Or = u16(Ideal_Node_Type.Or),
	Eq = u16(Ideal_Node_Type.Eq),
	F_Add = u16(Ideal_Node_Type.F_Add),
	F_Mul = u16(Ideal_Node_Type.F_Mul),
	U_Lt = u16(Ideal_Node_Type.U_Lt),
	U_Le = u16(Ideal_Node_Type.U_Le),
	F_Gt = u16(Ideal_Node_Type.F_Gt),
	Shl = u16(Ideal_Node_Type.Shl),
	F_Eq = u16(Ideal_Node_Type.F_Eq),
	F_Lt = u16(Ideal_Node_Type.F_Lt),
}
Builder_Node_Type :: enum u16 {
	Start,
	Entry,
	Poison,
	Arg,
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

		builder_peep_inst :: proc(ctx: Peep_Ctx, node: Expanded_Node) -> Node_ID {
			return builder_peep(ctx, node, struct{}{})
		}
		builder_post_schedule_peep_inst :: proc(
			ctx: PS_Peep_Ctx, node: Expanded_Node) -> Node_ID {
			return builder_post_schedule_peep(ctx, node, struct{}{})
		}
		
#assert(size_of(Cfg) % 4 == 0)
graph_add_start :: #force_inline proc(graph: ^Graph, name: string) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^Cfg)(graph_get_next_extra_slot(graph, u16(Ideal_Node_Type.Start)))^ = {}
	return graph_add_raw(graph, u16(Ideal_Node_Type.Start), .Void, {})
}
#assert(size_of(Cfg) % 4 == 0)
graph_add_entry :: #force_inline proc(graph: ^Graph, name: string, start: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^Cfg)(graph_get_next_extra_slot(graph, u16(Ideal_Node_Type.Entry)))^ = {}
	return graph_add_raw(graph, u16(Ideal_Node_Type.Entry), .Void, {start})
}
#assert(size_of(No_Extra) % 4 == 0)
graph_add_poison :: #force_inline proc(graph: ^Graph, name: string) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Ideal_Node_Type.Poison), .Void, {})
}
#assert(size_of(Tup) % 4 == 0)
graph_add_arg :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype, entry: Node_ID, idx: u32) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^Tup)(graph_get_next_extra_slot(graph, u16(Ideal_Node_Type.Arg)))^ = {
		idx = idx
	}
	return graph_add_raw(graph, u16(Ideal_Node_Type.Arg), dt, {entry})
}
#assert(size_of(CInt) % 4 == 0)
graph_add_c_int :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype, value: i64) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^CInt)(graph_get_next_extra_slot(graph, u16(Ideal_Node_Type.CInt)))^ = {
		value = value
	}
	return graph_add_raw(graph, u16(Ideal_Node_Type.CInt), dt, {})
}
#assert(size_of(No_Extra) % 4 == 0)
graph_add_bin_op :: #force_inline proc(graph: ^Graph, name: string, type: Bin_Op, dt: Node_Datatype, lhs: Node_ID, rhs: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(type), dt, {lhs, rhs})
}
#assert(size_of(No_Extra) % 4 == 0)
#assert(size_of(No_Extra) % 4 == 0)
#assert(size_of(No_Extra) % 4 == 0)
#assert(size_of(No_Extra) % 4 == 0)
#assert(size_of(No_Extra) % 4 == 0)
#assert(size_of(No_Extra) % 4 == 0)
#assert(size_of(No_Extra) % 4 == 0)
#assert(size_of(No_Extra) % 4 == 0)
#assert(size_of(No_Extra) % 4 == 0)
#assert(size_of(No_Extra) % 4 == 0)
#assert(size_of(No_Extra) % 4 == 0)
#assert(size_of(No_Extra) % 4 == 0)
#assert(size_of(No_Extra) % 4 == 0)
#assert(size_of(No_Extra) % 4 == 0)
#assert(size_of(No_Extra) % 4 == 0)
#assert(size_of(No_Extra) % 4 == 0)
#assert(size_of(No_Extra) % 4 == 0)
#assert(size_of(No_Extra) % 4 == 0)
#assert(size_of(No_Extra) % 4 == 0)
#assert(size_of(No_Extra) % 4 == 0)
#assert(size_of(No_Extra) % 4 == 0)
#assert(size_of(No_Extra) % 4 == 0)
#assert(size_of(No_Extra) % 4 == 0)
#assert(size_of(No_Extra) % 4 == 0)
#assert(size_of(No_Extra) % 4 == 0)
#assert(size_of(No_Extra) % 4 == 0)
#assert(size_of(No_Extra) % 4 == 0)
#assert(size_of(No_Extra) % 4 == 0)
#assert(size_of(No_Extra) % 4 == 0)
#assert(size_of(No_Extra) % 4 == 0)
#assert(size_of(No_Extra) % 4 == 0)
#assert(size_of(No_Extra) % 4 == 0)
#assert(size_of(No_Extra) % 4 == 0)
#assert(size_of(No_Extra) % 4 == 0)
graph_add_split :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype, dest: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Ideal_Node_Type.Split), dt, {dest})
}
#assert(size_of(No_Extra) % 4 == 0)
graph_add_phi :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype, reg: Node_ID, lhs: Node_ID, rhs: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Ideal_Node_Type.Phi), dt, {reg, lhs, rhs})
}
#assert(size_of(No_Extra) % 4 == 0)
graph_add_mem :: #force_inline proc(graph: ^Graph, name: string, ctrl: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Ideal_Node_Type.Mem), .Void, {ctrl})
}
#assert(size_of(No_Extra) % 4 == 0)
graph_add_sym :: #force_inline proc(graph: ^Graph, name: string, entry: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Ideal_Node_Type.Sym), .Void, {entry})
}
#assert(size_of(Local) % 4 == 0)
graph_add_local :: #force_inline proc(graph: ^Graph, name: string, mem: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^Local)(graph_get_next_extra_slot(graph, u16(Ideal_Node_Type.Local)))^ = {}
	return graph_add_raw(graph, u16(Ideal_Node_Type.Local), .Void, {mem})
}
#assert(size_of(No_Extra) % 4 == 0)
graph_add_local_addr :: #force_inline proc(graph: ^Graph, name: string, local: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Ideal_Node_Type.Local_Addr), .I64, {local})
}
#assert(size_of(Tup) % 4 == 0)
graph_add_global :: #force_inline proc(graph: ^Graph, name: string) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^Tup)(graph_get_next_extra_slot(graph, u16(Ideal_Node_Type.Global)))^ = {}
	return graph_add_raw(graph, u16(Ideal_Node_Type.Global), .Void, {})
}
#assert(size_of(No_Extra) % 4 == 0)
graph_add_global_addr :: #force_inline proc(graph: ^Graph, name: string, global: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Ideal_Node_Type.Global_Addr), .I64, {global})
}
#assert(size_of(Tup) % 4 == 0)
graph_add_proc_addr :: #force_inline proc(graph: ^Graph, name: string) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^Tup)(graph_get_next_extra_slot(graph, u16(Ideal_Node_Type.Proc_Addr)))^ = {}
	return graph_add_raw(graph, u16(Ideal_Node_Type.Proc_Addr), .I64, {})
}
#assert(size_of(No_Extra) % 4 == 0)
graph_add_copy :: #force_inline proc(graph: ^Graph, name: string, ctrl: Node_ID, mem: Node_ID, dst: Node_ID, src: Node_ID, size: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Ideal_Node_Type.Copy), .Void, {ctrl, mem, dst, src, size})
}
#assert(size_of(No_Extra) % 4 == 0)
graph_add_set :: #force_inline proc(graph: ^Graph, name: string, ctrl: Node_ID, mem: Node_ID, dst: Node_ID, value: Node_ID, size: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Ideal_Node_Type.Set), .Void, {ctrl, mem, dst, value, size})
}
#assert(size_of(No_Extra) % 4 == 0)
graph_add_store :: #force_inline proc(graph: ^Graph, name: string, ctrl: Node_ID, mem: Node_ID, addr: Node_ID, value: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Ideal_Node_Type.Store), .Void, {ctrl, mem, addr, value})
}
#assert(size_of(No_Extra) % 4 == 0)
graph_add_load :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype, ctrl: Node_ID, mem: Node_ID, addr: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Ideal_Node_Type.Load), dt, {ctrl, mem, addr})
}
#assert(size_of(No_Extra) % 4 == 0)
graph_add_load_s :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype, ctrl: Node_ID, mem: Node_ID, addr: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Ideal_Node_Type.Load_S), dt, {ctrl, mem, addr})
}
#assert(size_of(Cfg) % 4 == 0)
graph_add_if :: #force_inline proc(graph: ^Graph, name: string, ctrl: Node_ID, cond: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^Cfg)(graph_get_next_extra_slot(graph, u16(Ideal_Node_Type.If)))^ = {}
	return graph_add_raw(graph, u16(Ideal_Node_Type.If), .Void, {ctrl, cond})
}
#assert(size_of(Cfg) % 4 == 0)
graph_add_then :: #force_inline proc(graph: ^Graph, name: string, ctrl: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^Cfg)(graph_get_next_extra_slot(graph, u16(Ideal_Node_Type.Then)))^ = {}
	return graph_add_raw(graph, u16(Ideal_Node_Type.Then), .Void, {ctrl})
}
#assert(size_of(Cfg) % 4 == 0)
graph_add_else :: #force_inline proc(graph: ^Graph, name: string, ctrl: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^Cfg)(graph_get_next_extra_slot(graph, u16(Ideal_Node_Type.Else)))^ = {}
	return graph_add_raw(graph, u16(Ideal_Node_Type.Else), .Void, {ctrl})
}
#assert(size_of(Cfg) % 4 == 0)
graph_add_jump :: #force_inline proc(graph: ^Graph, name: string, ctrl: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^Cfg)(graph_get_next_extra_slot(graph, u16(Ideal_Node_Type.Jump)))^ = {}
	return graph_add_raw(graph, u16(Ideal_Node_Type.Jump), .Void, {ctrl})
}
#assert(size_of(Cfg) % 4 == 0)
graph_add_region :: #force_inline proc(graph: ^Graph, name: string, inputs: []Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^Cfg)(graph_get_next_extra_slot(graph, u16(Ideal_Node_Type.Region)))^ = {}
	return graph_add_raw(graph, u16(Ideal_Node_Type.Region), .Void, inputs)
}
#assert(size_of(Cfg) % 4 == 0)
graph_add_loop :: #force_inline proc(graph: ^Graph, name: string, ctrl: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^Cfg)(graph_get_next_extra_slot(graph, u16(Ideal_Node_Type.Loop)))^ = {}
	return graph_add_raw(graph, u16(Ideal_Node_Type.Loop), .Void, {ctrl}, extra_capacity = 1)
}
#assert(size_of(Cfg) % 4 == 0)
graph_add_always :: #force_inline proc(graph: ^Graph, name: string, ctrl: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^Cfg)(graph_get_next_extra_slot(graph, u16(Ideal_Node_Type.Always)))^ = {}
	return graph_add_raw(graph, u16(Ideal_Node_Type.Always), .Void, {ctrl})
}
#assert(size_of(Call) % 4 == 0)
graph_add_call :: #force_inline proc(graph: ^Graph, name: string, inputs: []Node_ID, cid: u32) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^Call)(graph_get_next_extra_slot(graph, u16(Ideal_Node_Type.Call)))^ = {
		cid = cid
	}
	return graph_add_raw(graph, u16(Ideal_Node_Type.Call), .Void, inputs)
}
#assert(size_of(Cfg) % 4 == 0)
graph_add_call_end :: #force_inline proc(graph: ^Graph, name: string, call: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^Cfg)(graph_get_next_extra_slot(graph, u16(Ideal_Node_Type.Call_End)))^ = {}
	return graph_add_raw(graph, u16(Ideal_Node_Type.Call_End), .Void, {call})
}
#assert(size_of(Tup) % 4 == 0)
graph_add_ret :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype, call_end: Node_ID, idx: u32) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^Tup)(graph_get_next_extra_slot(graph, u16(Ideal_Node_Type.Ret)))^ = {
		idx = idx
	}
	return graph_add_raw(graph, u16(Ideal_Node_Type.Ret), dt, {call_end})
}
#assert(size_of(Cfg) % 4 == 0)
graph_add_return :: #force_inline proc(graph: ^Graph, name: string, inputs: []Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^Cfg)(graph_get_next_extra_slot(graph, u16(Ideal_Node_Type.Return)))^ = {}
	return graph_add_raw(graph, u16(Ideal_Node_Type.Return), .Void, inputs)
}
#assert(size_of(No_Extra) % 4 == 0)
graph_add_un_op :: #force_inline proc(graph: ^Graph, name: string, type: Un_Op, dt: Node_Datatype, oprnd: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(type), dt, {oprnd})
}
#assert(size_of(No_Extra) % 4 == 0)
#assert(size_of(No_Extra) % 4 == 0)
#assert(size_of(No_Extra) % 4 == 0)
#assert(size_of(No_Extra) % 4 == 0)
#assert(size_of(No_Extra) % 4 == 0)
#assert(size_of(No_Extra) % 4 == 0)
#assert(size_of(No_Extra) % 4 == 0)
#assert(size_of(No_Extra) % 4 == 0)
#assert(size_of(Scope) % 4 == 0)
graph_add_scope :: #force_inline proc(graph: ^Graph, name: string, cfg: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^Scope)(graph_get_next_extra_slot(graph, u16(Builder_Node_Type.Scope)))^ = {}
	return graph_add_raw(graph, u16(Builder_Node_Type.Scope), .Void, {cfg})
}
#assert(size_of(No_Extra) % 4 == 0)
graph_add_lazy_phi :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype, reg: Node_ID, lhs: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Builder_Node_Type.Lazy_Phi), dt, {reg, lhs}, extra_capacity = 1)
}
#assert(size_of(No_Extra) % 4 == 0)
graph_add_dead :: #force_inline proc(graph: ^Graph, name: string) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Builder_Node_Type.Dead), .Void, {})
}
X64_Node_Type :: enum u16 {
	Start,
	Entry,
	Poison,
	Arg,
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
}

		x64_peep_inst :: proc(ctx: Peep_Ctx, node: Expanded_Node) -> Node_ID {
			return x64_peep(ctx, node, struct{}{})
		}
		x64_post_schedule_peep_inst :: proc(
			ctx: PS_Peep_Ctx, node: Expanded_Node) -> Node_ID {
			return x64_post_schedule_peep(ctx, node, struct{}{})
		}
		
#assert(size_of(X64_Mem_Op) % 4 == 0)
#assert(size_of(X64_Mem_Op) % 4 == 0)
#assert(size_of(X64_Mem_Op) % 4 == 0)
#assert(size_of(X64_Mem_Op) % 4 == 0)
#assert(size_of(X64_Mem_Op) % 4 == 0)
#assert(size_of(X64_Mem_Op) % 4 == 0)
#assert(size_of(X64_Mem_Op) % 4 == 0)
#assert(size_of(X64_Mem_Op) % 4 == 0)
#assert(size_of(X64_Mem_Op) % 4 == 0)
#assert(size_of(X64_Mem_Op) % 4 == 0)
#assert(size_of(X64_Mem_Op) % 4 == 0)
#assert(size_of(X64_Mem_Op) % 4 == 0)
#assert(size_of(X64_Mem_Op) % 4 == 0)
#assert(size_of(X64_Mem_Op) % 4 == 0)
#assert(size_of(X64_Mem_Op) % 4 == 0)
#assert(size_of(X64_Mem_Op) % 4 == 0)
#assert(size_of(X64_Mem_Op) % 4 == 0)
#assert(size_of(X64_Mem_Op) % 4 == 0)
#assert(size_of(X64_Mem_Op) % 4 == 0)
#assert(size_of(X64_Mem_Op) % 4 == 0)
#assert(size_of(X64_Mem_Op) % 4 == 0)
#assert(size_of(X64_Mem_Op) % 4 == 0)
#assert(size_of(X64_Mem_Op) % 4 == 0)
#assert(size_of(X64_Mem_Op) % 4 == 0)
#assert(size_of(X64_Mem_Op) % 4 == 0)
#assert(size_of(X64_Mem_Op) % 4 == 0)
#assert(size_of(X64_Mem_Op) % 4 == 0)
#assert(size_of(X64_Mem_Op) % 4 == 0)
#assert(size_of(X64_Mem_Op) % 4 == 0)
#assert(size_of(X64_Mem_Op) % 4 == 0)
#assert(size_of(X64_Mem_Op) % 4 == 0)
#assert(size_of(X64_Mem_Op) % 4 == 0)
#assert(size_of(No_Extra) % 4 == 0)
#assert(size_of(X64_Mem_Op) % 4 == 0)
#assert(size_of(X64_Mem_Op) % 4 == 0)
#assert(size_of(No_Extra) % 4 == 0)
#assert(size_of(X64_Mem_Op) % 4 == 0)

inherit_idx_of :: #force_inline proc($T: typeid) -> u8 {
	when false {}
	else when T == CInt {return 3}
	else when T == Local {return 4}
	else when T == Tup {return 2}
	else when T == X64_Mem_Op {return 6}
	else when T == Scope {return 6}
	else when T == No_Extra {return 1}
	else when T == Call {return 5}
	else when T == Cfg {return 0}
	else {#panic(`the passed type is not subclass of anything`)}
}
}
