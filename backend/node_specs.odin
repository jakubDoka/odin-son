package backend
// NOTE: this file is generated: odin run backend -define:GEN_SPEC=true

when !GEN_SPEC {
SPECS := [Node_Spec_Name]Node_Spec{
	.Ideal = {
		class_lengths = {.General = 0},
		datatype_to_reg_kind = {.Void = Reg_Kind.General, .I8 = Reg_Kind.General, .I16 = Reg_Kind.General, .I32 = Reg_Kind.General, .I64 = Reg_Kind.General},
		interned_reg_masks = {
			raw_data([]int{}),
		},
		reg_masks = {
			{}, // Start
			{}, // Entry
			{}, // CInt
			{}, // Add
			{}, // Mul
			{}, // Split
			{}, // Return
		},
		inplace_slot_idxs = {
			-1, //Start
			-1, //Entry
			-1, //CInt
			-1, //Add
			-1, //Mul
			-1, //Split
			-1, //Return
		},
		first_input_idxs = {
			0, //Start
			0, //Entry
			0, //CInt
			0, //Add
			0, //Mul
			0, //Split
			0, //Return
		},
		inheritance_table = {
			0b1, // Start
			0b1, // Entry
			0b10, // CInt
			0b100, // Add
			0b100, // Mul
			0b100, // Split
			0b1, // Return
		},
		node_extra_sizes = {
			1, // Start -> Cfg_Extra
			1, // Entry -> Cfg_Extra
			2, // CInt -> CInt
			0, // Add -> No_Extra
			0, // Mul -> No_Extra
			0, // Split -> No_Extra
			1, // Return -> Cfg_Extra
		},
		node_flags = {
			{}, // Start
			{Class_Flag.Is_Basic_Block_Start}, // Entry
			{Class_Flag.Interned}, // CInt
			{Class_Flag.Comutes}, // Add
			{Class_Flag.Comutes}, // Mul
			{}, // Split
			{}, // Return
		},
		node_extra_types = {
			Cfg_Extra,
			Cfg_Extra,
			CInt,
			No_Extra,
			No_Extra,
			No_Extra,
			Cfg_Extra,
		},
		node_kind_name = {
			`Start`,
			`Entry`,
			`CInt`,
			`Add`,
			`Mul`,
			`Split`,
			`Return`,
		},
	},
	.X64 = {
		class_lengths = {.General = 1},
		datatype_to_reg_kind = {.Void = Reg_Kind.General, .I8 = Reg_Kind.General, .I16 = Reg_Kind.General, .I32 = Reg_Kind.General, .I64 = Reg_Kind.General},
		interned_reg_masks = {
			raw_data([]int{}),
			raw_data([]int{0xffef}),
			raw_data([]int{0xffffffffffffffef}),
		},
		reg_masks = {
			{}, // Start
			{}, // Entry
			{{.General = 1}}, // CInt
			{{.General = 1}, {.General = 1}, {.General = 1}}, // Add
			{{.General = 1}, {.General = 1}, {.General = 1}}, // Mul
			{{.General = 2}, {.General = 2}}, // Split
			{}, // Return
		},
		inplace_slot_idxs = {
			-1, //Start
			-1, //Entry
			-1, //CInt
			0, //Add
			0, //Mul
			-1, //Split
			-1, //Return
		},
		reg_mask_of = x64_reg_mask_of,
		emit_function = x64_emit_function,
		first_input_idxs = {
			0, //Start
			0, //Entry
			0, //CInt
			0, //Add
			0, //Mul
			0, //Split
			1, //Return
		},
		inheritance_table = {
			0b1, // Start
			0b1, // Entry
			0b10, // CInt
			0b100, // Add
			0b100, // Mul
			0b100, // Split
			0b1, // Return
		},
		node_extra_sizes = {
			1, // Start -> Cfg_Extra
			1, // Entry -> Cfg_Extra
			2, // CInt -> CInt
			0, // Add -> No_Extra
			0, // Mul -> No_Extra
			0, // Split -> No_Extra
			1, // Return -> Cfg_Extra
		},
		node_flags = {
			{}, // Start
			{Class_Flag.Is_Basic_Block_Start}, // Entry
			{Class_Flag.Interned}, // CInt
			{Class_Flag.Comutes}, // Add
			{Class_Flag.Comutes}, // Mul
			{}, // Split
			{}, // Return
		},
		node_extra_types = {
			Cfg_Extra,
			Cfg_Extra,
			CInt,
			No_Extra,
			No_Extra,
			No_Extra,
			Cfg_Extra,
		},
		node_kind_name = {
			`Start`,
			`Entry`,
			`CInt`,
			`Add`,
			`Mul`,
			`Split`,
			`Return`,
		},
	},
}

Ideal_Node_Type :: enum u16 {

Start,
Entry,
CInt,
Add,
Mul,
Split,
Return,
}
#assert(size_of(Cfg_Extra) % 4 == 0)
graph_add_start :: #force_inline proc(graph: ^Graph, name: string) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Ideal_Node_Type.Start), .Void, {})
}
#assert(size_of(Cfg_Extra) % 4 == 0)
graph_add_entry :: #force_inline proc(graph: ^Graph, name: string, start: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Ideal_Node_Type.Entry), .Void, {start})
}
#assert(size_of(CInt) % 4 == 0)
graph_add_cint :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype, value: i64) -> (id: Node_ID) {
	push_node_name(graph, name)
	extra := (^CInt)(graph_get_next_extra_slot(graph, u16(Ideal_Node_Type.CInt)))
	extra.value = value
	return graph_add_raw(graph, u16(Ideal_Node_Type.CInt), dt, {})
}
#assert(size_of(No_Extra) % 4 == 0)
graph_add_add :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype, lhs: Node_ID, rhs: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Ideal_Node_Type.Add), dt, {lhs, rhs})
}
#assert(size_of(No_Extra) % 4 == 0)
graph_add_mul :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype, lhs: Node_ID, rhs: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Ideal_Node_Type.Mul), dt, {lhs, rhs})
}
#assert(size_of(No_Extra) % 4 == 0)
graph_add_split :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype, dest: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Ideal_Node_Type.Split), dt, {dest})
}
#assert(size_of(Cfg_Extra) % 4 == 0)
graph_add_return :: #force_inline proc(graph: ^Graph, name: string, inputs: []Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Ideal_Node_Type.Return), .Void, inputs)
}
X64_Node_Type :: enum u16 {

Start,
Entry,
CInt,
Add,
Mul,
Split,
Return,
}

inherit_idx_of :: #force_inline proc($T: typeid) -> u8 {
	when false {}
	else when T == No_Extra {return 2}
	else when T == CInt {return 1}
	else when T == Cfg_Extra {return 0}
	else {#panic(`the passed type is not subclass of anything`)}
}
}
