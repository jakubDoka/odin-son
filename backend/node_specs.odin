package backend
// NOTE: this file is generated: odin run backend -define:GEN_SPEC=true

when !GEN_SPEC {
SPECS := [Node_Spec_Name]Node_Spec{
	.Builder = {
		class_lengths = {.General = 0},
		datatype_to_reg_kind = {.Void = Reg_Kind.General, .I8 = Reg_Kind.General, .I16 = Reg_Kind.General, .I32 = Reg_Kind.General, .I64 = Reg_Kind.General},
		reg_bias = 0,
		clobbers = {
			{.General = 0}, // Start
			{.General = 0}, // Entry
			{.General = 0}, // Poison
			{.General = 0}, // Arg
			{.General = 0}, // CInt
			{.General = 0}, // Add
			{.General = 0}, // Sub
			{.General = 0}, // And
			{.General = 0}, // Or
			{.General = 0}, // Xor
			{.General = 0}, // Eq
			{.General = 0}, // Ne
			{.General = 0}, // Le
			{.General = 0}, // Lt
			{.General = 0}, // Gt
			{.General = 0}, // Ge
			{.General = 0}, // U_Lt
			{.General = 0}, // U_Gt
			{.General = 0}, // U_Le
			{.General = 0}, // U_Ge
			{.General = 0}, // Shl
			{.General = 0}, // Shr
			{.General = 0}, // U_Shr
			{.General = 0}, // Mul
			{.General = 0}, // Div
			{.General = 0}, // U_Div
			{.General = 0}, // Rem
			{.General = 0}, // U_Rem
			{.General = 0}, // And_Not
			{.General = 0}, // Split
			{.General = 0}, // Phi
			{.General = 0}, // Mem
			{.General = 0}, // Local
			{.General = 0}, // Local_Addr
			{.General = 0}, // Global
			{.General = 0}, // Global_Addr
			{.General = 0}, // Copy
			{.General = 0}, // Set
			{.General = 0}, // Store
			{.General = 0}, // Load
			{.General = 0}, // Load_S
			{.General = 0}, // If
			{.General = 0}, // Then
			{.General = 0}, // Else
			{.General = 0}, // Jump
			{.General = 0}, // Region
			{.General = 0}, // Loop
			{.General = 0}, // Always
			{.General = 0}, // Call
			{.General = 0}, // Call_End
			{.General = 0}, // Ret
			{.General = 0}, // Return
			{.General = 0}, // Neg
			{.General = 0}, // Not
			{.General = 0}, // Sext
			{.General = 0}, // Uext
			{.General = 0}, // Cast
			{.General = 0}, // Scope
			{.General = 0}, // Lazy_Phi
			{.General = 0}, // Dead
		},
		interned_reg_masks = {
			raw_data([]int{}),
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
			{}, // Local
			{}, // Local_Addr
			{}, // Global
			{}, // Global_Addr
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
			{}, // Scope
			{}, // Lazy_Phi
			{}, // Dead
		},
		inplace_slot_idxs = {
			-1, //Start
			-1, //Entry
			-1, //Poison
			-1, //Arg
			-1, //CInt
			-1, //Add
			-1, //Sub
			-1, //And
			-1, //Or
			-1, //Xor
			-1, //Eq
			-1, //Ne
			-1, //Le
			-1, //Lt
			-1, //Gt
			-1, //Ge
			-1, //U_Lt
			-1, //U_Gt
			-1, //U_Le
			-1, //U_Ge
			-1, //Shl
			-1, //Shr
			-1, //U_Shr
			-1, //Mul
			-1, //Div
			-1, //U_Div
			-1, //Rem
			-1, //U_Rem
			-1, //And_Not
			-1, //Split
			-1, //Phi
			-1, //Mem
			-1, //Local
			-1, //Local_Addr
			-1, //Global
			-1, //Global_Addr
			-1, //Copy
			-1, //Set
			-1, //Store
			-1, //Load
			-1, //Load_S
			-1, //If
			-1, //Then
			-1, //Else
			-1, //Jump
			-1, //Region
			-1, //Loop
			-1, //Always
			-1, //Call
			-1, //Call_End
			-1, //Ret
			-1, //Return
			-1, //Neg
			-1, //Not
			-1, //Sext
			-1, //Uext
			-1, //Cast
			-1, //Scope
			-1, //Lazy_Phi
			-1, //Dead
		},
		peep = builder_peep,
		post_schedule_peep = builder_post_schedule_peep,
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
			0, //Local
			0, //Local_Addr
			0, //Global
			0, //Global_Addr
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
			0b10000, // Local
			0b10, // Local_Addr
			0b100, // Global
			0b10, // Global_Addr
			0b100000, // Copy
			0b100000, // Set
			0b100000, // Store
			0b100000, // Load
			0b100000, // Load_S
			0b1, // If
			0b1, // Then
			0b1, // Else
			0b1, // Jump
			0b1000001, // Region
			0b1, // Loop
			0b1, // Always
			0b10000001, // Call
			0b1, // Call_End
			0b100, // Ret
			0b1, // Return
			0b10, // Neg
			0b10, // Not
			0b10, // Sext
			0b10, // Uext
			0b10, // Cast
			0b100000000, // Scope
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
			1, // Local -> Local
			0, // Local_Addr -> No_Extra
			1, // Global -> Tup
			0, // Global_Addr -> No_Extra
			0, // Copy -> Mem_Op
			0, // Set -> Mem_Op
			0, // Store -> Mem_Op
			0, // Load -> Mem_Op
			0, // Load_S -> Mem_Op
			1, // If -> Cfg
			1, // Then -> Cfg
			1, // Else -> Cfg
			1, // Jump -> Cfg
			1, // Region -> Region
			1, // Loop -> Cfg
			1, // Always -> Cfg
			2, // Call -> Call
			1, // Call_End -> Cfg
			1, // Ret -> Tup
			1, // Return -> Cfg
			0, // Neg -> No_Extra
			0, // Not -> No_Extra
			0, // Sext -> No_Extra
			0, // Uext -> No_Extra
			0, // Cast -> No_Extra
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
			{}, // Local
			{Class_Flag.Clonable}, // Local_Addr
			{}, // Global
			{Class_Flag.Interned, Class_Flag.Clonable}, // Global_Addr
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
			Local,
			No_Extra,
			Tup,
			No_Extra,
			Mem_Op,
			Mem_Op,
			Mem_Op,
			Mem_Op,
			Mem_Op,
			Cfg,
			Cfg,
			Cfg,
			Cfg,
			Region,
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
			`Local`,
			`Local_Addr`,
			`Global`,
			`Global_Addr`,
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
			`Scope`,
			`Lazy_Phi`,
			`Dead`,
		},
	},
	.X64 = {
		class_lengths = {.General = 1},
		datatype_to_reg_kind = {.Void = Reg_Kind.General, .I8 = Reg_Kind.General, .I16 = Reg_Kind.General, .I32 = Reg_Kind.General, .I64 = Reg_Kind.General},
		reg_bias = 4039,
		clobbers = {
			{.General = 0}, // Start
			{.General = 0}, // Entry
			{.General = 0}, // Poison
			{.General = 0}, // Arg
			{.General = 0}, // CInt
			{.General = 0}, // Add
			{.General = 0}, // Sub
			{.General = 0}, // And
			{.General = 0}, // Or
			{.General = 0}, // Xor
			{.General = 0}, // Eq
			{.General = 0}, // Ne
			{.General = 0}, // Le
			{.General = 0}, // Lt
			{.General = 0}, // Gt
			{.General = 0}, // Ge
			{.General = 0}, // U_Lt
			{.General = 0}, // U_Gt
			{.General = 0}, // U_Le
			{.General = 0}, // U_Ge
			{.General = 0}, // Shl
			{.General = 0}, // Shr
			{.General = 0}, // U_Shr
			{.General = 0}, // Mul
			{.General = 4}, // Div
			{.General = 4}, // U_Div
			{.General = 1}, // Rem
			{.General = 1}, // U_Rem
			{.General = 0}, // And_Not
			{.General = 0}, // Split
			{.General = 0}, // Phi
			{.General = 0}, // Mem
			{.General = 0}, // Local
			{.General = 0}, // Local_Addr
			{.General = 0}, // Global
			{.General = 0}, // Global_Addr
			{.General = 4039}, // Copy
			{.General = 4039}, // Set
			{.General = 0}, // Store
			{.General = 0}, // Load
			{.General = 0}, // Load_S
			{.General = 0}, // If
			{.General = 0}, // Then
			{.General = 0}, // Else
			{.General = 0}, // Jump
			{.General = 0}, // Region
			{.General = 0}, // Loop
			{.General = 0}, // Always
			{.General = 4039}, // Call
			{.General = 0}, // Call_End
			{.General = 0}, // Ret
			{.General = 0}, // Return
			{.General = 0}, // Neg
			{.General = 0}, // Not
			{.General = 0}, // Sext
			{.General = 0}, // Uext
			{.General = 0}, // Cast
			{.General = 0}, // X64_Add
			{.General = 0}, // X64_Sub
			{.General = 0}, // X64_And
			{.General = 0}, // X64_Or
			{.General = 0}, // X64_Xor
			{.General = 0}, // X64_Eq
			{.General = 0}, // X64_Ne
			{.General = 0}, // X64_Le
			{.General = 0}, // X64_Lt
			{.General = 0}, // X64_Gt
			{.General = 0}, // X64_Ge
			{.General = 0}, // X64_U_Lt
			{.General = 0}, // X64_U_Gt
			{.General = 0}, // X64_U_Le
			{.General = 0}, // X64_U_Ge
			{.General = 0}, // X64_Shl
			{.General = 0}, // X64_Shr
			{.General = 0}, // X64_U_Shr
			{.General = 0}, // X64_Mul
			{.General = 0}, // X64_Lea
			{.General = 0}, // X64_Load
			{.General = 0}, // X64_Store
			{.General = 0}, // X64_Neg
			{.General = 0}, // X64_Not
			{.General = 0}, // X64_Mul8
		},
		interned_reg_masks = {
			raw_data([]int{}),
			raw_data([]int{0xffef}),
			raw_data([]int{0x2}),
			raw_data([]int{0x1}),
			raw_data([]int{0xffea}),
			raw_data([]int{0x4}),
			raw_data([]int{0xffffffffffffffef}),
			raw_data([]int{0x0}),
			raw_data([]int{0x80}),
			raw_data([]int{0x40}),
		},
		reg_masks = {
			{}, // Start
			{}, // Entry
			{}, // Poison
			{}, // Arg
			{{.General = 1}}, // CInt
			{{.General = 1}, {.General = 1}, {.General = 1}}, // Add
			{{.General = 1}, {.General = 1}, {.General = 1}}, // Sub
			{{.General = 1}, {.General = 1}, {.General = 1}}, // And
			{{.General = 1}, {.General = 1}, {.General = 1}}, // Or
			{{.General = 1}, {.General = 1}, {.General = 1}}, // Xor
			{{.General = 1}, {.General = 1}, {.General = 1}}, // Eq
			{{.General = 1}, {.General = 1}, {.General = 1}}, // Ne
			{{.General = 1}, {.General = 1}, {.General = 1}}, // Le
			{{.General = 1}, {.General = 1}, {.General = 1}}, // Lt
			{{.General = 1}, {.General = 1}, {.General = 1}}, // Gt
			{{.General = 1}, {.General = 1}, {.General = 1}}, // Ge
			{{.General = 1}, {.General = 1}, {.General = 1}}, // U_Lt
			{{.General = 1}, {.General = 1}, {.General = 1}}, // U_Gt
			{{.General = 1}, {.General = 1}, {.General = 1}}, // U_Le
			{{.General = 1}, {.General = 1}, {.General = 1}}, // U_Ge
			{{.General = 1}, {.General = 1}, {.General = 2}}, // Shl
			{{.General = 1}, {.General = 1}, {.General = 2}}, // Shr
			{{.General = 1}, {.General = 1}, {.General = 2}}, // U_Shr
			{{.General = 1}, {.General = 1}, {.General = 1}}, // Mul
			{{.General = 3}, {.General = 3}, {.General = 4}}, // Div
			{{.General = 3}, {.General = 3}, {.General = 4}}, // U_Div
			{{.General = 5}, {.General = 3}, {.General = 4}}, // Rem
			{{.General = 5}, {.General = 3}, {.General = 4}}, // U_Rem
			{{.General = 1}, {.General = 1}, {.General = 1}}, // And_Not
			{{.General = 6}, {.General = 6}}, // Split
			{{.General = 6}, {.General = 6}, {.General = 6}}, // Phi
			{}, // Mem
			{}, // Local
			{{.General = 1}}, // Local_Addr
			{}, // Global
			{{.General = 1}}, // Global_Addr
			{{.General = 7}, {.General = 8}, {.General = 9}, {.General = 5}}, // Copy
			{{.General = 7}, {.General = 8}, {.General = 9}, {.General = 5}}, // Set
			{{.General = 7}, {.General = 1}, {.General = 1}}, // Store
			{{.General = 1}, {.General = 1}}, // Load
			{{.General = 1}, {.General = 1}}, // Load_S
			{{.General = 7}, {.General = 1}}, // If
			{}, // Then
			{}, // Else
			{}, // Jump
			{}, // Region
			{}, // Loop
			{}, // Always
			{}, // Call
			{}, // Call_End
			{{.General = 3}}, // Ret
			{{.General = 7}, {.General = 3}, {.General = 5}}, // Return
			{{.General = 1}, {.General = 1}}, // Neg
			{{.General = 1}, {.General = 1}}, // Not
			{{.General = 1}, {.General = 1}}, // Sext
			{{.General = 1}, {.General = 1}}, // Uext
			{{.General = 1}, {.General = 1}}, // Cast
			{{.General = 1}, {.General = 1}, {.General = 1}, {.General = 1}}, // X64_Add
			{{.General = 1}, {.General = 1}, {.General = 1}, {.General = 1}}, // X64_Sub
			{{.General = 1}, {.General = 1}, {.General = 1}, {.General = 1}}, // X64_And
			{{.General = 1}, {.General = 1}, {.General = 1}, {.General = 1}}, // X64_Or
			{{.General = 1}, {.General = 1}, {.General = 1}, {.General = 1}}, // X64_Xor
			{{.General = 1}, {.General = 1}, {.General = 1}, {.General = 1}}, // X64_Eq
			{{.General = 1}, {.General = 1}, {.General = 1}, {.General = 1}}, // X64_Ne
			{{.General = 1}, {.General = 1}, {.General = 1}, {.General = 1}}, // X64_Le
			{{.General = 1}, {.General = 1}, {.General = 1}, {.General = 1}}, // X64_Lt
			{{.General = 1}, {.General = 1}, {.General = 1}, {.General = 1}}, // X64_Gt
			{{.General = 1}, {.General = 1}, {.General = 1}, {.General = 1}}, // X64_Ge
			{{.General = 1}, {.General = 1}, {.General = 1}, {.General = 1}}, // X64_U_Lt
			{{.General = 1}, {.General = 1}, {.General = 1}, {.General = 1}}, // X64_U_Gt
			{{.General = 1}, {.General = 1}, {.General = 1}, {.General = 1}}, // X64_U_Le
			{{.General = 1}, {.General = 1}, {.General = 1}, {.General = 1}}, // X64_U_Ge
			{{.General = 1}, {.General = 1}, {.General = 2}}, // X64_Shl
			{{.General = 1}, {.General = 1}, {.General = 2}}, // X64_Shr
			{{.General = 1}, {.General = 1}, {.General = 2}}, // X64_U_Shr
			{{.General = 1}, {.General = 1}, {.General = 1}, {.General = 1}}, // X64_Mul
			{{.General = 1}, {.General = 1}, {.General = 1}}, // X64_Lea
			{{.General = 1}, {.General = 1}, {.General = 1}}, // X64_Load
			{{.General = 7}, {.General = 1}, {.General = 1}, {.General = 1}}, // X64_Store
			{{.General = 1}, {.General = 1}}, // X64_Neg
			{{.General = 1}, {.General = 1}}, // X64_Not
			{{.General = 3}, {.General = 1}, {.General = 3}}, // X64_Mul8
		},
		inplace_slot_idxs = {
			-1, //Start
			-1, //Entry
			-1, //Poison
			-1, //Arg
			-1, //CInt
			0, //Add
			0, //Sub
			0, //And
			0, //Or
			0, //Xor
			-1, //Eq
			-1, //Ne
			-1, //Le
			-1, //Lt
			-1, //Gt
			-1, //Ge
			-1, //U_Lt
			-1, //U_Gt
			-1, //U_Le
			-1, //U_Ge
			0, //Shl
			0, //Shr
			0, //U_Shr
			0, //Mul
			0, //Div
			0, //U_Div
			-1, //Rem
			-1, //U_Rem
			1, //And_Not
			-1, //Split
			-1, //Phi
			-1, //Mem
			-1, //Local
			-1, //Local_Addr
			-1, //Global
			-1, //Global_Addr
			-1, //Copy
			-1, //Set
			-1, //Store
			-1, //Load
			-1, //Load_S
			-1, //If
			-1, //Then
			-1, //Else
			-1, //Jump
			-1, //Region
			-1, //Loop
			-1, //Always
			-1, //Call
			-1, //Call_End
			-1, //Ret
			-1, //Return
			0, //Neg
			0, //Not
			-1, //Sext
			-1, //Uext
			0, //Cast
			0, //X64_Add
			0, //X64_Sub
			0, //X64_And
			0, //X64_Or
			0, //X64_Xor
			-1, //X64_Eq
			-1, //X64_Ne
			-1, //X64_Le
			-1, //X64_Lt
			-1, //X64_Gt
			-1, //X64_Ge
			-1, //X64_U_Lt
			-1, //X64_U_Gt
			-1, //X64_U_Le
			-1, //X64_U_Ge
			0, //X64_Shl
			0, //X64_Shr
			0, //X64_U_Shr
			-1, //X64_Mul
			-1, //X64_Lea
			-1, //X64_Load
			-1, //X64_Store
			0, //X64_Neg
			0, //X64_Not
			-1, //X64_Mul8
		},
		reg_mask_of = x64_reg_mask_of,
		emit_function = x64_emit_function,
		peep = x64_peep,
		post_schedule_peep = x64_post_schedule_peep,
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
			1, //Local
			1, //Local_Addr
			0, //Global
			1, //Global_Addr
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
			2, //Call
			0, //Call_End
			1, //Ret
			2, //Return
			0, //Neg
			0, //Not
			0, //Sext
			0, //Uext
			0, //Cast
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
			0, //X64_Shl
			0, //X64_Shr
			0, //X64_U_Shr
			0, //X64_Mul
			0, //X64_Lea
			2, //X64_Load
			2, //X64_Store
			0, //X64_Neg
			0, //X64_Not
			0, //X64_Mul8
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
			0b10000, // Local
			0b10, // Local_Addr
			0b100, // Global
			0b10, // Global_Addr
			0b100000, // Copy
			0b100000, // Set
			0b100000, // Store
			0b100000, // Load
			0b100000, // Load_S
			0b1, // If
			0b1, // Then
			0b1, // Else
			0b1, // Jump
			0b1000001, // Region
			0b1, // Loop
			0b1, // Always
			0b10000001, // Call
			0b1, // Call_End
			0b100, // Ret
			0b1, // Return
			0b10, // Neg
			0b10, // Not
			0b10, // Sext
			0b10, // Uext
			0b10, // Cast
			0b100000000, // X64_Add
			0b100000000, // X64_Sub
			0b100000000, // X64_And
			0b100000000, // X64_Or
			0b100000000, // X64_Xor
			0b100000000, // X64_Eq
			0b100000000, // X64_Ne
			0b100000000, // X64_Le
			0b100000000, // X64_Lt
			0b100000000, // X64_Gt
			0b100000000, // X64_Ge
			0b100000000, // X64_U_Lt
			0b100000000, // X64_U_Gt
			0b100000000, // X64_U_Le
			0b100000000, // X64_U_Ge
			0b100000000, // X64_Shl
			0b100000000, // X64_Shr
			0b100000000, // X64_U_Shr
			0b100000000, // X64_Mul
			0b100000000, // X64_Lea
			0b100000000, // X64_Load
			0b100000000, // X64_Store
			0b100000000, // X64_Neg
			0b100000000, // X64_Not
			0b10, // X64_Mul8
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
			1, // Local -> Local
			0, // Local_Addr -> No_Extra
			1, // Global -> Tup
			0, // Global_Addr -> No_Extra
			0, // Copy -> Mem_Op
			0, // Set -> Mem_Op
			0, // Store -> Mem_Op
			0, // Load -> Mem_Op
			0, // Load_S -> Mem_Op
			1, // If -> Cfg
			1, // Then -> Cfg
			1, // Else -> Cfg
			1, // Jump -> Cfg
			1, // Region -> Region
			1, // Loop -> Cfg
			1, // Always -> Cfg
			2, // Call -> Call
			1, // Call_End -> Cfg
			1, // Ret -> Tup
			1, // Return -> Cfg
			0, // Neg -> No_Extra
			0, // Not -> No_Extra
			0, // Sext -> No_Extra
			0, // Uext -> No_Extra
			0, // Cast -> No_Extra
			4, // X64_Add -> X64_Mem_Op
			4, // X64_Sub -> X64_Mem_Op
			4, // X64_And -> X64_Mem_Op
			4, // X64_Or -> X64_Mem_Op
			4, // X64_Xor -> X64_Mem_Op
			4, // X64_Eq -> X64_Mem_Op
			4, // X64_Ne -> X64_Mem_Op
			4, // X64_Le -> X64_Mem_Op
			4, // X64_Lt -> X64_Mem_Op
			4, // X64_Gt -> X64_Mem_Op
			4, // X64_Ge -> X64_Mem_Op
			4, // X64_U_Lt -> X64_Mem_Op
			4, // X64_U_Gt -> X64_Mem_Op
			4, // X64_U_Le -> X64_Mem_Op
			4, // X64_U_Ge -> X64_Mem_Op
			4, // X64_Shl -> X64_Mem_Op
			4, // X64_Shr -> X64_Mem_Op
			4, // X64_U_Shr -> X64_Mem_Op
			4, // X64_Mul -> X64_Mem_Op
			4, // X64_Lea -> X64_Mem_Op
			4, // X64_Load -> X64_Mem_Op
			4, // X64_Store -> X64_Mem_Op
			4, // X64_Neg -> X64_Mem_Op
			4, // X64_Not -> X64_Mem_Op
			0, // X64_Mul8 -> No_Extra
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
			{}, // Local
			{Class_Flag.Clonable}, // Local_Addr
			{}, // Global
			{Class_Flag.Interned, Class_Flag.Clonable}, // Global_Addr
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
			{}, // X64_Lea
			{Class_Flag.Load}, // X64_Load
			{Class_Flag.Store}, // X64_Store
			{}, // X64_Neg
			{}, // X64_Not
			{}, // X64_Mul8
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
			Local,
			No_Extra,
			Tup,
			No_Extra,
			Mem_Op,
			Mem_Op,
			Mem_Op,
			Mem_Op,
			Mem_Op,
			Cfg,
			Cfg,
			Cfg,
			Cfg,
			Region,
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
			`Local`,
			`Local_Addr`,
			`Global`,
			`Global_Addr`,
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
			`X64_Shl`,
			`X64_Shr`,
			`X64_U_Shr`,
			`X64_Mul`,
			`X64_Lea`,
			`X64_Load`,
			`X64_Store`,
			`X64_Neg`,
			`X64_Not`,
			`X64_Mul8`,
		},
	},
}

Un_Op :: enum u16 {
	Not = u16(Ideal_Node_Type.Not),
	Neg = u16(Ideal_Node_Type.Neg),
	Uext = u16(Ideal_Node_Type.Uext),
	Sext = u16(Ideal_Node_Type.Sext),
	Cast = u16(Ideal_Node_Type.Cast),
}
Bin_Op :: enum u16 {
	Add = u16(Ideal_Node_Type.Add),
	And = u16(Ideal_Node_Type.And),
	Sub = u16(Ideal_Node_Type.Sub),
	Lt = u16(Ideal_Node_Type.Lt),
	Le = u16(Ideal_Node_Type.Le),
	Ge = u16(Ideal_Node_Type.Ge),
	Gt = u16(Ideal_Node_Type.Gt),
	Xor = u16(Ideal_Node_Type.Xor),
	Or = u16(Ideal_Node_Type.Or),
	Ne = u16(Ideal_Node_Type.Ne),
	Eq = u16(Ideal_Node_Type.Eq),
	Shr = u16(Ideal_Node_Type.Shr),
	Shl = u16(Ideal_Node_Type.Shl),
	Mul = u16(Ideal_Node_Type.Mul),
	U_Shr = u16(Ideal_Node_Type.U_Shr),
	U_Gt = u16(Ideal_Node_Type.U_Gt),
	U_Lt = u16(Ideal_Node_Type.U_Lt),
	U_Ge = u16(Ideal_Node_Type.U_Ge),
	U_Le = u16(Ideal_Node_Type.U_Le),
	And_Not = u16(Ideal_Node_Type.And_Not),
	U_Div = u16(Ideal_Node_Type.U_Div),
	Div = u16(Ideal_Node_Type.Div),
	U_Rem = u16(Ideal_Node_Type.U_Rem),
	Rem = u16(Ideal_Node_Type.Rem),
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
	Local,
	Local_Addr,
	Global,
	Global_Addr,
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
	Scope,
	Lazy_Phi,
	Dead,
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
#assert(size_of(Mem_Op) % 4 == 0)
graph_add_copy :: #force_inline proc(graph: ^Graph, name: string, ctrl: Node_ID, mem: Node_ID, dst: Node_ID, src: Node_ID, size: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Ideal_Node_Type.Copy), .Void, {ctrl, mem, dst, src, size})
}
#assert(size_of(Mem_Op) % 4 == 0)
graph_add_set :: #force_inline proc(graph: ^Graph, name: string, ctrl: Node_ID, mem: Node_ID, dst: Node_ID, value: Node_ID, size: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Ideal_Node_Type.Set), .Void, {ctrl, mem, dst, value, size})
}
#assert(size_of(Mem_Op) % 4 == 0)
graph_add_store :: #force_inline proc(graph: ^Graph, name: string, ctrl: Node_ID, mem: Node_ID, addr: Node_ID, value: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Ideal_Node_Type.Store), .Void, {ctrl, mem, addr, value})
}
#assert(size_of(Mem_Op) % 4 == 0)
graph_add_load :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype, ctrl: Node_ID, mem: Node_ID, addr: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Ideal_Node_Type.Load), dt, {ctrl, mem, addr})
}
#assert(size_of(Mem_Op) % 4 == 0)
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
#assert(size_of(Region) % 4 == 0)
graph_add_region :: #force_inline proc(graph: ^Graph, name: string, inputs: []Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^Region)(graph_get_next_extra_slot(graph, u16(Ideal_Node_Type.Region)))^ = {}
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
	Local,
	Local_Addr,
	Global,
	Global_Addr,
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
	X64_Lea,
	X64_Load,
	X64_Store,
	X64_Neg,
	X64_Not,
	X64_Mul8,
}
#assert(size_of(X64_Mem_Op) % 4 == 0)
graph_add_x64_add :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^X64_Mem_Op)(graph_get_next_extra_slot(graph, u16(X64_Node_Type.X64_Add)))^ = {}
	return graph_add_raw(graph, u16(X64_Node_Type.X64_Add), dt, {})
}
#assert(size_of(X64_Mem_Op) % 4 == 0)
graph_add_x64_sub :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^X64_Mem_Op)(graph_get_next_extra_slot(graph, u16(X64_Node_Type.X64_Sub)))^ = {}
	return graph_add_raw(graph, u16(X64_Node_Type.X64_Sub), dt, {})
}
#assert(size_of(X64_Mem_Op) % 4 == 0)
graph_add_x64_and :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^X64_Mem_Op)(graph_get_next_extra_slot(graph, u16(X64_Node_Type.X64_And)))^ = {}
	return graph_add_raw(graph, u16(X64_Node_Type.X64_And), dt, {})
}
#assert(size_of(X64_Mem_Op) % 4 == 0)
graph_add_x64_or :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^X64_Mem_Op)(graph_get_next_extra_slot(graph, u16(X64_Node_Type.X64_Or)))^ = {}
	return graph_add_raw(graph, u16(X64_Node_Type.X64_Or), dt, {})
}
#assert(size_of(X64_Mem_Op) % 4 == 0)
graph_add_x64_xor :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^X64_Mem_Op)(graph_get_next_extra_slot(graph, u16(X64_Node_Type.X64_Xor)))^ = {}
	return graph_add_raw(graph, u16(X64_Node_Type.X64_Xor), dt, {})
}
#assert(size_of(X64_Mem_Op) % 4 == 0)
graph_add_x64_eq :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^X64_Mem_Op)(graph_get_next_extra_slot(graph, u16(X64_Node_Type.X64_Eq)))^ = {}
	return graph_add_raw(graph, u16(X64_Node_Type.X64_Eq), dt, {})
}
#assert(size_of(X64_Mem_Op) % 4 == 0)
graph_add_x64_ne :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^X64_Mem_Op)(graph_get_next_extra_slot(graph, u16(X64_Node_Type.X64_Ne)))^ = {}
	return graph_add_raw(graph, u16(X64_Node_Type.X64_Ne), dt, {})
}
#assert(size_of(X64_Mem_Op) % 4 == 0)
graph_add_x64_le :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^X64_Mem_Op)(graph_get_next_extra_slot(graph, u16(X64_Node_Type.X64_Le)))^ = {}
	return graph_add_raw(graph, u16(X64_Node_Type.X64_Le), dt, {})
}
#assert(size_of(X64_Mem_Op) % 4 == 0)
graph_add_x64_lt :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^X64_Mem_Op)(graph_get_next_extra_slot(graph, u16(X64_Node_Type.X64_Lt)))^ = {}
	return graph_add_raw(graph, u16(X64_Node_Type.X64_Lt), dt, {})
}
#assert(size_of(X64_Mem_Op) % 4 == 0)
graph_add_x64_gt :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^X64_Mem_Op)(graph_get_next_extra_slot(graph, u16(X64_Node_Type.X64_Gt)))^ = {}
	return graph_add_raw(graph, u16(X64_Node_Type.X64_Gt), dt, {})
}
#assert(size_of(X64_Mem_Op) % 4 == 0)
graph_add_x64_ge :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^X64_Mem_Op)(graph_get_next_extra_slot(graph, u16(X64_Node_Type.X64_Ge)))^ = {}
	return graph_add_raw(graph, u16(X64_Node_Type.X64_Ge), dt, {})
}
#assert(size_of(X64_Mem_Op) % 4 == 0)
graph_add_x64_u_lt :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^X64_Mem_Op)(graph_get_next_extra_slot(graph, u16(X64_Node_Type.X64_U_Lt)))^ = {}
	return graph_add_raw(graph, u16(X64_Node_Type.X64_U_Lt), dt, {})
}
#assert(size_of(X64_Mem_Op) % 4 == 0)
graph_add_x64_u_gt :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^X64_Mem_Op)(graph_get_next_extra_slot(graph, u16(X64_Node_Type.X64_U_Gt)))^ = {}
	return graph_add_raw(graph, u16(X64_Node_Type.X64_U_Gt), dt, {})
}
#assert(size_of(X64_Mem_Op) % 4 == 0)
graph_add_x64_u_le :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^X64_Mem_Op)(graph_get_next_extra_slot(graph, u16(X64_Node_Type.X64_U_Le)))^ = {}
	return graph_add_raw(graph, u16(X64_Node_Type.X64_U_Le), dt, {})
}
#assert(size_of(X64_Mem_Op) % 4 == 0)
graph_add_x64_u_ge :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^X64_Mem_Op)(graph_get_next_extra_slot(graph, u16(X64_Node_Type.X64_U_Ge)))^ = {}
	return graph_add_raw(graph, u16(X64_Node_Type.X64_U_Ge), dt, {})
}
#assert(size_of(X64_Mem_Op) % 4 == 0)
graph_add_x64_shl :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^X64_Mem_Op)(graph_get_next_extra_slot(graph, u16(X64_Node_Type.X64_Shl)))^ = {}
	return graph_add_raw(graph, u16(X64_Node_Type.X64_Shl), dt, {})
}
#assert(size_of(X64_Mem_Op) % 4 == 0)
graph_add_x64_shr :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^X64_Mem_Op)(graph_get_next_extra_slot(graph, u16(X64_Node_Type.X64_Shr)))^ = {}
	return graph_add_raw(graph, u16(X64_Node_Type.X64_Shr), dt, {})
}
#assert(size_of(X64_Mem_Op) % 4 == 0)
graph_add_x64_u_shr :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^X64_Mem_Op)(graph_get_next_extra_slot(graph, u16(X64_Node_Type.X64_U_Shr)))^ = {}
	return graph_add_raw(graph, u16(X64_Node_Type.X64_U_Shr), dt, {})
}
#assert(size_of(X64_Mem_Op) % 4 == 0)
graph_add_x64_mul :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^X64_Mem_Op)(graph_get_next_extra_slot(graph, u16(X64_Node_Type.X64_Mul)))^ = {}
	return graph_add_raw(graph, u16(X64_Node_Type.X64_Mul), dt, {})
}
#assert(size_of(X64_Mem_Op) % 4 == 0)
graph_add_x64_lea :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^X64_Mem_Op)(graph_get_next_extra_slot(graph, u16(X64_Node_Type.X64_Lea)))^ = {}
	return graph_add_raw(graph, u16(X64_Node_Type.X64_Lea), dt, {})
}
#assert(size_of(X64_Mem_Op) % 4 == 0)
graph_add_x64_load :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^X64_Mem_Op)(graph_get_next_extra_slot(graph, u16(X64_Node_Type.X64_Load)))^ = {}
	return graph_add_raw(graph, u16(X64_Node_Type.X64_Load), dt, {})
}
#assert(size_of(X64_Mem_Op) % 4 == 0)
graph_add_x64_store :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^X64_Mem_Op)(graph_get_next_extra_slot(graph, u16(X64_Node_Type.X64_Store)))^ = {}
	return graph_add_raw(graph, u16(X64_Node_Type.X64_Store), dt, {})
}
#assert(size_of(X64_Mem_Op) % 4 == 0)
graph_add_x64_neg :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^X64_Mem_Op)(graph_get_next_extra_slot(graph, u16(X64_Node_Type.X64_Neg)))^ = {}
	return graph_add_raw(graph, u16(X64_Node_Type.X64_Neg), dt, {})
}
#assert(size_of(X64_Mem_Op) % 4 == 0)
graph_add_x64_not :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^X64_Mem_Op)(graph_get_next_extra_slot(graph, u16(X64_Node_Type.X64_Not)))^ = {}
	return graph_add_raw(graph, u16(X64_Node_Type.X64_Not), dt, {})
}
#assert(size_of(No_Extra) % 4 == 0)
graph_add_x64_mul8 :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(X64_Node_Type.X64_Mul8), dt, {})
}

inherit_idx_of :: #force_inline proc($T: typeid) -> u8 {
	when false {}
	else when T == CInt {return 3}
	else when T == Tup {return 2}
	else when T == Local {return 4}
	else when T == X64_Mem_Op {return 8}
	else when T == Region {return 6}
	else when T == No_Extra {return 1}
	else when T == Call {return 7}
	else when T == Scope {return 8}
	else when T == Cfg {return 0}
	else when T == Mem_Op {return 5}
	else {#panic(`the passed type is not subclass of anything`)}
}
}
