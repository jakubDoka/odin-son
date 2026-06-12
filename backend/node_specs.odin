package backend
// NOTE: this file is generated: odin run backend -define:GEN_SPEC=true

SPECS := [Node_Spec_Name]Node_Spec{
	.Ideal = {
		class_lengths = {.General = 0},
		datatype_to_reg_kind = {.Void = Reg_Kind.General, .I8 = Reg_Kind.General, .I16 = Reg_Kind.General, .I32 = Reg_Kind.General, .I64 = Reg_Kind.General},
		interned_reg_masks = {
			raw_data([]int{}),
		},
		reg_masks = {
			{{.General = 0}}, // Start
			{{.General = 0}}, // Entry
			{{.General = 0}}, // CInt
			{{.General = 0}}, // Return
		},
		inplace_slot_idxs = {
			-1, //Start
			-1, //Entry
			-1, //CInt
			-1, //Return
		},
		first_input_idxs = {
			0, //Start
			0, //Entry
			0, //CInt
			0, //Return
		},
		inheritance_table = {
			0b1, // Start
			0b1, // Entry
			0b10, // CInt
			0b1, // Return
		},
		node_extra_sizes = {
			1, // Start -> Cfg_Extra
			1, // Entry -> Cfg_Extra
			2, // CInt -> CInt
			1, // Return -> Cfg_Extra
		},
		node_flags = {
			transmute(Class_Flags)u8(0), // Start
			transmute(Class_Flags)u8(1), // Entry
			transmute(Class_Flags)u8(0), // CInt
			transmute(Class_Flags)u8(0), // Return
		},
		node_extra_types = {
			Cfg_Extra,
			Cfg_Extra,
			CInt,
			Cfg_Extra,
		},
		node_kind_name = {
			`Start`,
			`Entry`,
			`CInt`,
			`Return`,
		},
	},
	.X64 = {
		class_lengths = {.General = 1},
		datatype_to_reg_kind = {.Void = Reg_Kind.General, .I8 = Reg_Kind.General, .I16 = Reg_Kind.General, .I32 = Reg_Kind.General, .I64 = Reg_Kind.General},
		interned_reg_masks = {
			raw_data([]int{}),
			raw_data([]int{0xffef}),
		},
		reg_masks = {
			{{.General = 0}}, // Start
			{{.General = 0}}, // Entry
			{{.General = 1}}, // CInt
			{{.General = 0}}, // Return
		},
		inplace_slot_idxs = {
			-1, //Start
			-1, //Entry
			-1, //CInt
			-1, //Return
		},
		reg_mask_of = x64_reg_mask_of,
		first_input_idxs = {
			0, //Start
			0, //Entry
			0, //CInt
			1, //Return
		},
		inheritance_table = {
			0b1, // Start
			0b1, // Entry
			0b10, // CInt
			0b1, // Return
		},
		node_extra_sizes = {
			1, // Start -> Cfg_Extra
			1, // Entry -> Cfg_Extra
			2, // CInt -> CInt
			1, // Return -> Cfg_Extra
		},
		node_flags = {
			transmute(Class_Flags)u8(0), // Start
			transmute(Class_Flags)u8(1), // Entry
			transmute(Class_Flags)u8(0), // CInt
			transmute(Class_Flags)u8(0), // Return
		},
		node_extra_types = {
			Cfg_Extra,
			Cfg_Extra,
			CInt,
			Cfg_Extra,
		},
		node_kind_name = {
			`Start`,
			`Entry`,
			`CInt`,
			`Return`,
		},
	},
}

#assert(size_of(Cfg_Extra) % 4 == 0)
graph_add_start :: #force_inline proc(graph: ^Graph) -> (id: Node_ID) {
	return graph_add_raw(graph, u16(I_Node_Type.Start), .Void, {})
}
#assert(size_of(Cfg_Extra) % 4 == 0)
graph_add_entry :: #force_inline proc(graph: ^Graph, start: Node_ID) -> (id: Node_ID) {
	return graph_add_raw(graph, u16(I_Node_Type.Entry), .Void, {start})
}
#assert(size_of(CInt) % 4 == 0)
graph_add_cint :: #force_inline proc(graph: ^Graph, dt: Node_Datatype, value: i64) -> (id: Node_ID) {
	defer {
		extra := graph_get_extra(graph, id, CInt)
		extra.value = value
	}
	return graph_add_raw(graph, u16(I_Node_Type.CInt), dt, {})
}
#assert(size_of(Cfg_Extra) % 4 == 0)
graph_add_return :: #force_inline proc(graph: ^Graph, inputs: []Node_ID) -> (id: Node_ID) {
	return graph_add_raw(graph, u16(I_Node_Type.Return), .Void, inputs)
}

inherit_idx_of :: #force_inline proc($T: typeid) -> u8 {
	when false {}
	else when T == CInt {return 1}
	else when T == Cfg_Extra {return 0}
	else {#panic(`the passed type is not subclass of anything`)}
}

