package backend
// NOTE: this file is generated: odin run backend -define:GEN_SPEC=true

when !GEN_SPEC {
SPECS := [Node_Spec_Name]Node_Spec{
	.Builder = {
		class_lengths = {.General = 0},
		datatype_to_reg_kind = {.Void = Reg_Kind.General, .I8 = Reg_Kind.General, .I16 = Reg_Kind.General, .I32 = Reg_Kind.General, .I64 = Reg_Kind.General},
		clobbers = {
			{.General = 0}, // Start
			{.General = 0}, // Entry
			{.General = 0}, // Poison
			{.General = 0}, // Arg
			{.General = 0}, // CInt
			{.General = 0}, // Add
			{.General = 0}, // Sub
			{.General = 0}, // Mul
			{.General = 0}, // Eq
			{.General = 0}, // Ne
			{.General = 0}, // Le
			{.General = 0}, // Lt
			{.General = 0}, // Gt
			{.General = 0}, // Ge
			{.General = 0}, // Div
			{.General = 0}, // Rem
			{.General = 0}, // And
			{.General = 0}, // Or
			{.General = 0}, // Xor
			{.General = 0}, // And_Not
			{.General = 0}, // Shl
			{.General = 0}, // Shr
			{.General = 0}, // Split
			{.General = 0}, // Phi
			{.General = 0}, // Mem
			{.General = 0}, // Local
			{.General = 0}, // Local_Addr
			{.General = 0}, // Store
			{.General = 0}, // Load
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
			{.General = 0}, // Scope
			{.General = 0}, // Lazy_Phi
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
			{}, // Mul
			{}, // Eq
			{}, // Ne
			{}, // Le
			{}, // Lt
			{}, // Gt
			{}, // Ge
			{}, // Div
			{}, // Rem
			{}, // And
			{}, // Or
			{}, // Xor
			{}, // And_Not
			{}, // Shl
			{}, // Shr
			{}, // Split
			{}, // Phi
			{}, // Mem
			{}, // Local
			{}, // Local_Addr
			{}, // Store
			{}, // Load
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
			{}, // Scope
			{}, // Lazy_Phi
		},
		inplace_slot_idxs = {
			-1, //Start
			-1, //Entry
			-1, //Poison
			-1, //Arg
			-1, //CInt
			-1, //Add
			-1, //Sub
			-1, //Mul
			-1, //Eq
			-1, //Ne
			-1, //Le
			-1, //Lt
			-1, //Gt
			-1, //Ge
			-1, //Div
			-1, //Rem
			-1, //And
			-1, //Or
			-1, //Xor
			-1, //And_Not
			-1, //Shl
			-1, //Shr
			-1, //Split
			-1, //Phi
			-1, //Mem
			-1, //Local
			-1, //Local_Addr
			-1, //Store
			-1, //Load
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
			-1, //Scope
			-1, //Lazy_Phi
		},
		first_input_idxs = {
			0, //Start
			0, //Entry
			0, //Poison
			0, //Arg
			0, //CInt
			0, //Add
			0, //Sub
			0, //Mul
			0, //Eq
			0, //Ne
			0, //Le
			0, //Lt
			0, //Gt
			0, //Ge
			0, //Div
			0, //Rem
			0, //And
			0, //Or
			0, //Xor
			0, //And_Not
			0, //Shl
			0, //Shr
			0, //Split
			0, //Phi
			0, //Mem
			0, //Local
			0, //Local_Addr
			0, //Store
			0, //Load
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
			0, //Scope
			0, //Lazy_Phi
		},
		inheritance_table = {
			0b1, // Start
			0b1, // Entry
			0b10, // Poison
			0b100, // Arg
			0b1000, // CInt
			0b10, // Add
			0b10, // Sub
			0b10, // Mul
			0b10, // Eq
			0b10, // Ne
			0b10, // Le
			0b10, // Lt
			0b10, // Gt
			0b10, // Ge
			0b10, // Div
			0b10, // Rem
			0b10, // And
			0b10, // Or
			0b10, // Xor
			0b10, // And_Not
			0b10, // Shl
			0b10, // Shr
			0b10, // Split
			0b10, // Phi
			0b10, // Mem
			0b10000, // Local
			0b10, // Local_Addr
			0b100000, // Store
			0b100000, // Load
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
			0b100000000, // Scope
			0b10, // Lazy_Phi
		},
		node_extra_sizes = {
			1, // Start -> Cfg
			1, // Entry -> Cfg
			0, // Poison -> No_Extra
			1, // Arg -> Tup
			2, // CInt -> CInt
			0, // Add -> No_Extra
			0, // Sub -> No_Extra
			0, // Mul -> No_Extra
			0, // Eq -> No_Extra
			0, // Ne -> No_Extra
			0, // Le -> No_Extra
			0, // Lt -> No_Extra
			0, // Gt -> No_Extra
			0, // Ge -> No_Extra
			0, // Div -> No_Extra
			0, // Rem -> No_Extra
			0, // And -> No_Extra
			0, // Or -> No_Extra
			0, // Xor -> No_Extra
			0, // And_Not -> No_Extra
			0, // Shl -> No_Extra
			0, // Shr -> No_Extra
			0, // Split -> No_Extra
			0, // Phi -> No_Extra
			0, // Mem -> No_Extra
			1, // Local -> Local
			0, // Local_Addr -> No_Extra
			0, // Store -> Mem_Op
			0, // Load -> Mem_Op
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
			1, // Scope -> Scope
			0, // Lazy_Phi -> No_Extra
		},
		node_flags = {
			{}, // Start
			{Class_Flag.Is_Basic_Block_Start}, // Entry
			{Class_Flag.Interned}, // Poison
			{}, // Arg
			{Class_Flag.Interned}, // CInt
			{Class_Flag.Interned, Class_Flag.Comutes}, // Add
			{Class_Flag.Interned}, // Sub
			{Class_Flag.Interned, Class_Flag.Comutes}, // Mul
			{Class_Flag.Interned, Class_Flag.Comutes}, // Eq
			{Class_Flag.Interned, Class_Flag.Comutes}, // Ne
			{Class_Flag.Interned}, // Le
			{Class_Flag.Interned}, // Lt
			{Class_Flag.Interned}, // Gt
			{Class_Flag.Interned}, // Ge
			{Class_Flag.Interned}, // Div
			{Class_Flag.Interned}, // Rem
			{Class_Flag.Interned, Class_Flag.Comutes}, // And
			{Class_Flag.Interned, Class_Flag.Comutes}, // Or
			{Class_Flag.Interned, Class_Flag.Comutes}, // Xor
			{Class_Flag.Interned}, // And_Not
			{Class_Flag.Interned}, // Shl
			{Class_Flag.Interned}, // Shr
			{}, // Split
			{Class_Flag.Interned}, // Phi
			{}, // Mem
			{}, // Local
			{}, // Local_Addr
			{Class_Flag.Interned}, // Store
			{Class_Flag.Interned}, // Load
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
			{}, // Scope
			{}, // Lazy_Phi
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
			Local,
			No_Extra,
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
			Scope,
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
			`Mul`,
			`Eq`,
			`Ne`,
			`Le`,
			`Lt`,
			`Gt`,
			`Ge`,
			`Div`,
			`Rem`,
			`And`,
			`Or`,
			`Xor`,
			`And_Not`,
			`Shl`,
			`Shr`,
			`Split`,
			`Phi`,
			`Mem`,
			`Local`,
			`Local_Addr`,
			`Store`,
			`Load`,
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
			`Scope`,
			`Lazy_Phi`,
		},
	},
	.X64 = {
		class_lengths = {.General = 1},
		datatype_to_reg_kind = {.Void = Reg_Kind.General, .I8 = Reg_Kind.General, .I16 = Reg_Kind.General, .I32 = Reg_Kind.General, .I64 = Reg_Kind.General},
		clobbers = {
			{.General = 0}, // Start
			{.General = 0}, // Entry
			{.General = 0}, // Poison
			{.General = 0}, // Arg
			{.General = 0}, // CInt
			{.General = 0}, // Add
			{.General = 0}, // Sub
			{.General = 0}, // Mul
			{.General = 0}, // Eq
			{.General = 0}, // Ne
			{.General = 0}, // Le
			{.General = 0}, // Lt
			{.General = 0}, // Gt
			{.General = 0}, // Ge
			{.General = 4}, // Div
			{.General = 1}, // Rem
			{.General = 0}, // And
			{.General = 0}, // Or
			{.General = 0}, // Xor
			{.General = 0}, // And_Not
			{.General = 0}, // Shl
			{.General = 0}, // Shr
			{.General = 0}, // Split
			{.General = 0}, // Phi
			{.General = 0}, // Mem
			{.General = 0}, // Local
			{.General = 0}, // Local_Addr
			{.General = 0}, // Store
			{.General = 0}, // Load
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
		},
		interned_reg_masks = {
			raw_data([]int{}),
			raw_data([]int{0xffef}),
			raw_data([]int{0x1}),
			raw_data([]int{0xffea}),
			raw_data([]int{0x4}),
			raw_data([]int{0x2}),
			raw_data([]int{0xffffffffffffffef}),
			raw_data([]int{0x0}),
		},
		reg_masks = {
			{}, // Start
			{}, // Entry
			{}, // Poison
			{}, // Arg
			{{.General = 1}}, // CInt
			{{.General = 1}, {.General = 1}, {.General = 1}}, // Add
			{{.General = 1}, {.General = 1}, {.General = 1}}, // Sub
			{{.General = 1}, {.General = 1}, {.General = 1}}, // Mul
			{{.General = 1}, {.General = 1}, {.General = 1}}, // Eq
			{{.General = 1}, {.General = 1}, {.General = 1}}, // Ne
			{{.General = 1}, {.General = 1}, {.General = 1}}, // Le
			{{.General = 1}, {.General = 1}, {.General = 1}}, // Lt
			{{.General = 1}, {.General = 1}, {.General = 1}}, // Gt
			{{.General = 1}, {.General = 1}, {.General = 1}}, // Ge
			{{.General = 2}, {.General = 2}, {.General = 3}}, // Div
			{{.General = 4}, {.General = 2}, {.General = 3}}, // Rem
			{{.General = 1}, {.General = 1}, {.General = 1}}, // And
			{{.General = 1}, {.General = 1}, {.General = 1}}, // Or
			{{.General = 1}, {.General = 1}, {.General = 1}}, // Xor
			{{.General = 1}, {.General = 1}, {.General = 1}}, // And_Not
			{{.General = 1}, {.General = 1}, {.General = 5}}, // Shl
			{{.General = 1}, {.General = 1}, {.General = 5}}, // Shr
			{{.General = 6}, {.General = 6}}, // Split
			{{.General = 6}, {.General = 6}, {.General = 6}}, // Phi
			{}, // Mem
			{}, // Local
			{{.General = 1}}, // Local_Addr
			{{.General = 7}, {.General = 1}, {.General = 1}}, // Store
			{{.General = 1}, {.General = 1}}, // Load
			{{.General = 7}, {.General = 1}}, // If
			{}, // Then
			{}, // Else
			{}, // Jump
			{}, // Region
			{}, // Loop
			{}, // Always
			{}, // Call
			{}, // Call_End
			{{.General = 2}}, // Ret
			{{.General = 7}, {.General = 2}}, // Return
		},
		inplace_slot_idxs = {
			-1, //Start
			-1, //Entry
			-1, //Poison
			-1, //Arg
			-1, //CInt
			0, //Add
			0, //Sub
			0, //Mul
			0, //Eq
			0, //Ne
			0, //Le
			0, //Lt
			0, //Gt
			0, //Ge
			0, //Div
			-1, //Rem
			0, //And
			0, //Or
			0, //Xor
			1, //And_Not
			0, //Shl
			0, //Shr
			-1, //Split
			-1, //Phi
			-1, //Mem
			-1, //Local
			-1, //Local_Addr
			-1, //Store
			-1, //Load
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
		},
		reg_mask_of = x64_reg_mask_of,
		emit_function = x64_emit_function,
		first_input_idxs = {
			0, //Start
			0, //Entry
			0, //Poison
			1, //Arg
			0, //CInt
			0, //Add
			0, //Sub
			0, //Mul
			0, //Eq
			0, //Ne
			0, //Le
			0, //Lt
			0, //Gt
			0, //Ge
			0, //Div
			0, //Rem
			0, //And
			0, //Or
			0, //Xor
			0, //And_Not
			0, //Shl
			0, //Shr
			0, //Split
			1, //Phi
			1, //Mem
			1, //Local
			1, //Local_Addr
			2, //Store
			2, //Load
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
		},
		inheritance_table = {
			0b1, // Start
			0b1, // Entry
			0b10, // Poison
			0b100, // Arg
			0b1000, // CInt
			0b10, // Add
			0b10, // Sub
			0b10, // Mul
			0b10, // Eq
			0b10, // Ne
			0b10, // Le
			0b10, // Lt
			0b10, // Gt
			0b10, // Ge
			0b10, // Div
			0b10, // Rem
			0b10, // And
			0b10, // Or
			0b10, // Xor
			0b10, // And_Not
			0b10, // Shl
			0b10, // Shr
			0b10, // Split
			0b10, // Phi
			0b10, // Mem
			0b10000, // Local
			0b10, // Local_Addr
			0b100000, // Store
			0b100000, // Load
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
		},
		node_extra_sizes = {
			1, // Start -> Cfg
			1, // Entry -> Cfg
			0, // Poison -> No_Extra
			1, // Arg -> Tup
			2, // CInt -> CInt
			0, // Add -> No_Extra
			0, // Sub -> No_Extra
			0, // Mul -> No_Extra
			0, // Eq -> No_Extra
			0, // Ne -> No_Extra
			0, // Le -> No_Extra
			0, // Lt -> No_Extra
			0, // Gt -> No_Extra
			0, // Ge -> No_Extra
			0, // Div -> No_Extra
			0, // Rem -> No_Extra
			0, // And -> No_Extra
			0, // Or -> No_Extra
			0, // Xor -> No_Extra
			0, // And_Not -> No_Extra
			0, // Shl -> No_Extra
			0, // Shr -> No_Extra
			0, // Split -> No_Extra
			0, // Phi -> No_Extra
			0, // Mem -> No_Extra
			1, // Local -> Local
			0, // Local_Addr -> No_Extra
			0, // Store -> Mem_Op
			0, // Load -> Mem_Op
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
		},
		node_flags = {
			{}, // Start
			{Class_Flag.Is_Basic_Block_Start}, // Entry
			{Class_Flag.Interned}, // Poison
			{}, // Arg
			{Class_Flag.Interned}, // CInt
			{Class_Flag.Interned, Class_Flag.Comutes}, // Add
			{Class_Flag.Interned}, // Sub
			{Class_Flag.Interned, Class_Flag.Comutes}, // Mul
			{Class_Flag.Interned, Class_Flag.Comutes}, // Eq
			{Class_Flag.Interned, Class_Flag.Comutes}, // Ne
			{Class_Flag.Interned}, // Le
			{Class_Flag.Interned}, // Lt
			{Class_Flag.Interned}, // Gt
			{Class_Flag.Interned}, // Ge
			{Class_Flag.Interned}, // Div
			{Class_Flag.Interned}, // Rem
			{Class_Flag.Interned, Class_Flag.Comutes}, // And
			{Class_Flag.Interned, Class_Flag.Comutes}, // Or
			{Class_Flag.Interned, Class_Flag.Comutes}, // Xor
			{Class_Flag.Interned}, // And_Not
			{Class_Flag.Interned}, // Shl
			{Class_Flag.Interned}, // Shr
			{}, // Split
			{Class_Flag.Interned}, // Phi
			{}, // Mem
			{}, // Local
			{}, // Local_Addr
			{Class_Flag.Interned}, // Store
			{Class_Flag.Interned}, // Load
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
			Local,
			No_Extra,
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
		},
		node_kind_name = {
			`Start`,
			`Entry`,
			`Poison`,
			`Arg`,
			`CInt`,
			`Add`,
			`Sub`,
			`Mul`,
			`Eq`,
			`Ne`,
			`Le`,
			`Lt`,
			`Gt`,
			`Ge`,
			`Div`,
			`Rem`,
			`And`,
			`Or`,
			`Xor`,
			`And_Not`,
			`Shl`,
			`Shr`,
			`Split`,
			`Phi`,
			`Mem`,
			`Local`,
			`Local_Addr`,
			`Store`,
			`Load`,
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
		},
	},
}

Bin_Op :: enum u16 {
	Add = u16(Ideal_Node_Type.Add),
	Mul = u16(Ideal_Node_Type.Mul),
	Sub = u16(Ideal_Node_Type.Sub),
	Ge = u16(Ideal_Node_Type.Ge),
	Gt = u16(Ideal_Node_Type.Gt),
	Rem = u16(Ideal_Node_Type.Rem),
	Div = u16(Ideal_Node_Type.Div),
	Ne = u16(Ideal_Node_Type.Ne),
	Eq = u16(Ideal_Node_Type.Eq),
	Lt = u16(Ideal_Node_Type.Lt),
	Le = u16(Ideal_Node_Type.Le),
	Shr = u16(Ideal_Node_Type.Shr),
	Shl = u16(Ideal_Node_Type.Shl),
	Or = u16(Ideal_Node_Type.Or),
	And = u16(Ideal_Node_Type.And),
	And_Not = u16(Ideal_Node_Type.And_Not),
	Xor = u16(Ideal_Node_Type.Xor),
}
Builder_Node_Type :: enum u16 {
	Start,
	Entry,
	Poison,
	Arg,
	CInt,
	Add,
	Sub,
	Mul,
	Eq,
	Ne,
	Le,
	Lt,
	Gt,
	Ge,
	Div,
	Rem,
	And,
	Or,
	Xor,
	And_Not,
	Shl,
	Shr,
	Split,
	Phi,
	Mem,
	Local,
	Local_Addr,
	Store,
	Load,
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
	Scope,
	Lazy_Phi,
}
#assert(size_of(Cfg) % 4 == 0)
graph_add_start :: #force_inline proc(graph: ^Graph, name: string) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Ideal_Node_Type.Start), .Void, {})
}
#assert(size_of(Cfg) % 4 == 0)
graph_add_entry :: #force_inline proc(graph: ^Graph, name: string, start: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
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
	extra := (^Tup)(graph_get_next_extra_slot(graph, u16(Ideal_Node_Type.Arg)))
	extra.idx = idx
	return graph_add_raw(graph, u16(Ideal_Node_Type.Arg), dt, {entry})
}
#assert(size_of(CInt) % 4 == 0)
graph_add_c_int :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype, value: i64) -> (id: Node_ID) {
	push_node_name(graph, name)
	extra := (^CInt)(graph_get_next_extra_slot(graph, u16(Ideal_Node_Type.CInt)))
	extra.value = value
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
	return graph_add_raw(graph, u16(Ideal_Node_Type.Local), .Void, {mem})
}
#assert(size_of(No_Extra) % 4 == 0)
graph_add_local_addr :: #force_inline proc(graph: ^Graph, name: string, local: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Ideal_Node_Type.Local_Addr), .I64, {local})
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
#assert(size_of(Cfg) % 4 == 0)
graph_add_if :: #force_inline proc(graph: ^Graph, name: string, ctrl: Node_ID, cond: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Ideal_Node_Type.If), .Void, {ctrl, cond})
}
#assert(size_of(Cfg) % 4 == 0)
graph_add_then :: #force_inline proc(graph: ^Graph, name: string, ctrl: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Ideal_Node_Type.Then), .Void, {ctrl})
}
#assert(size_of(Cfg) % 4 == 0)
graph_add_else :: #force_inline proc(graph: ^Graph, name: string, ctrl: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Ideal_Node_Type.Else), .Void, {ctrl})
}
#assert(size_of(Cfg) % 4 == 0)
graph_add_jump :: #force_inline proc(graph: ^Graph, name: string, ctrl: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Ideal_Node_Type.Jump), .Void, {ctrl})
}
#assert(size_of(Region) % 4 == 0)
graph_add_region :: #force_inline proc(graph: ^Graph, name: string, rcfg: Node_ID, lcfg: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Ideal_Node_Type.Region), .Void, {rcfg, lcfg})
}
#assert(size_of(Cfg) % 4 == 0)
graph_add_loop :: #force_inline proc(graph: ^Graph, name: string, ctrl: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Ideal_Node_Type.Loop), .Void, {ctrl}, extra_capacity = 1)
}
#assert(size_of(Cfg) % 4 == 0)
graph_add_always :: #force_inline proc(graph: ^Graph, name: string, ctrl: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Ideal_Node_Type.Always), .Void, {ctrl})
}
#assert(size_of(Call) % 4 == 0)
graph_add_call :: #force_inline proc(graph: ^Graph, name: string, inputs: []Node_ID, cid: u32) -> (id: Node_ID) {
	push_node_name(graph, name)
	extra := (^Call)(graph_get_next_extra_slot(graph, u16(Ideal_Node_Type.Call)))
	extra.cid = cid
	return graph_add_raw(graph, u16(Ideal_Node_Type.Call), .Void, inputs)
}
#assert(size_of(Cfg) % 4 == 0)
graph_add_call_end :: #force_inline proc(graph: ^Graph, name: string, call: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Ideal_Node_Type.Call_End), .Void, {call})
}
#assert(size_of(Tup) % 4 == 0)
graph_add_ret :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype, call_end: Node_ID, idx: u32) -> (id: Node_ID) {
	push_node_name(graph, name)
	extra := (^Tup)(graph_get_next_extra_slot(graph, u16(Ideal_Node_Type.Ret)))
	extra.idx = idx
	return graph_add_raw(graph, u16(Ideal_Node_Type.Ret), dt, {call_end})
}
#assert(size_of(Cfg) % 4 == 0)
graph_add_return :: #force_inline proc(graph: ^Graph, name: string, inputs: []Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Ideal_Node_Type.Return), .Void, inputs)
}
#assert(size_of(Scope) % 4 == 0)
graph_add_scope :: #force_inline proc(graph: ^Graph, name: string, cfg: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Builder_Node_Type.Scope), .Void, {cfg})
}
#assert(size_of(No_Extra) % 4 == 0)
graph_add_lazy_phi :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype, reg: Node_ID, lhs: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Builder_Node_Type.Lazy_Phi), dt, {reg, lhs}, extra_capacity = 1)
}
X64_Node_Type :: enum u16 {
	Start,
	Entry,
	Poison,
	Arg,
	CInt,
	Add,
	Sub,
	Mul,
	Eq,
	Ne,
	Le,
	Lt,
	Gt,
	Ge,
	Div,
	Rem,
	And,
	Or,
	Xor,
	And_Not,
	Shl,
	Shr,
	Split,
	Phi,
	Mem,
	Local,
	Local_Addr,
	Store,
	Load,
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
}

inherit_idx_of :: #force_inline proc($T: typeid) -> u8 {
	when false {}
	else when T == CInt {return 3}
	else when T == Tup {return 2}
	else when T == Local {return 4}
	else when T == Region {return 6}
	else when T == No_Extra {return 1}
	else when T == Call {return 7}
	else when T == Scope {return 8}
	else when T == Cfg {return 0}
	else when T == Mem_Op {return 5}
	else {#panic(`the passed type is not subclass of anything`)}
}
}
