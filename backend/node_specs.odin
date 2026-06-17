package backend
// NOTE: this file is generated: odin run backend -define:GEN_SPEC=true

when !GEN_SPEC {
SPECS := [Node_Spec_Name]Node_Spec{
	.Builder = {
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
			{}, // Sub
			{}, // Mul
			{}, // Eq
			{}, // Ne
			{}, // Split
			{}, // Phi
			{}, // If
			{}, // Then
			{}, // Else
			{}, // Jump
			{}, // Region
			{}, // Loop
			{}, // Return
			{}, // Scope
			{}, // Lazy_Phi
		},
		inplace_slot_idxs = {
			-1, //Start
			-1, //Entry
			-1, //CInt
			-1, //Add
			-1, //Sub
			-1, //Mul
			-1, //Eq
			-1, //Ne
			-1, //Split
			-1, //Phi
			-1, //If
			-1, //Then
			-1, //Else
			-1, //Jump
			-1, //Region
			-1, //Loop
			-1, //Return
			-1, //Scope
			-1, //Lazy_Phi
		},
		first_input_idxs = {
			0, //Start
			0, //Entry
			0, //CInt
			0, //Add
			0, //Sub
			0, //Mul
			0, //Eq
			0, //Ne
			0, //Split
			0, //Phi
			0, //If
			0, //Then
			0, //Else
			0, //Jump
			0, //Region
			0, //Loop
			0, //Return
			0, //Scope
			0, //Lazy_Phi
		},
		inheritance_table = {
			0b1, // Start
			0b1, // Entry
			0b10, // CInt
			0b100, // Add
			0b100, // Sub
			0b100, // Mul
			0b100, // Eq
			0b100, // Ne
			0b100, // Split
			0b100, // Phi
			0b1, // If
			0b1, // Then
			0b1, // Else
			0b1, // Jump
			0b1001, // Region
			0b1, // Loop
			0b1, // Return
			0b10000, // Scope
			0b100, // Lazy_Phi
		},
		node_extra_sizes = {
			1, // Start -> Cfg_Extra
			1, // Entry -> Cfg_Extra
			2, // CInt -> CInt
			0, // Add -> No_Extra
			0, // Sub -> No_Extra
			0, // Mul -> No_Extra
			0, // Eq -> No_Extra
			0, // Ne -> No_Extra
			0, // Split -> No_Extra
			0, // Phi -> No_Extra
			1, // If -> Cfg_Extra
			1, // Then -> Cfg_Extra
			1, // Else -> Cfg_Extra
			1, // Jump -> Cfg_Extra
			1, // Region -> Region
			1, // Loop -> Cfg_Extra
			1, // Return -> Cfg_Extra
			1, // Scope -> Scope
			0, // Lazy_Phi -> No_Extra
		},
		node_flags = {
			{}, // Start
			{Class_Flag.Is_Basic_Block_Start}, // Entry
			{Class_Flag.Interned}, // CInt
			{Class_Flag.Interned, Class_Flag.Comutes}, // Add
			{}, // Sub
			{Class_Flag.Interned, Class_Flag.Comutes}, // Mul
			{Class_Flag.Interned, Class_Flag.Comutes}, // Eq
			{Class_Flag.Interned, Class_Flag.Comutes}, // Ne
			{}, // Split
			{Class_Flag.Interned}, // Phi
			{}, // If
			{Class_Flag.Is_Basic_Block_Start}, // Then
			{Class_Flag.Is_Basic_Block_Start}, // Else
			{}, // Jump
			{Class_Flag.Is_Basic_Block_Start}, // Region
			{Class_Flag.Is_Basic_Block_Start}, // Loop
			{Class_Flag.Immortal}, // Return
			{}, // Scope
			{}, // Lazy_Phi
		},
		node_extra_types = {
			Cfg_Extra,
			Cfg_Extra,
			CInt,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			Cfg_Extra,
			Cfg_Extra,
			Cfg_Extra,
			Cfg_Extra,
			Region,
			Cfg_Extra,
			Cfg_Extra,
			Scope,
			No_Extra,
		},
		node_kind_name = {
			`Start`,
			`Entry`,
			`CInt`,
			`Add`,
			`Sub`,
			`Mul`,
			`Eq`,
			`Ne`,
			`Split`,
			`Phi`,
			`If`,
			`Then`,
			`Else`,
			`Jump`,
			`Region`,
			`Loop`,
			`Return`,
			`Scope`,
			`Lazy_Phi`,
		},
	},
	.X64 = {
		class_lengths = {.General = 1},
		datatype_to_reg_kind = {.Void = Reg_Kind.General, .I8 = Reg_Kind.General, .I16 = Reg_Kind.General, .I32 = Reg_Kind.General, .I64 = Reg_Kind.General},
		interned_reg_masks = {
			raw_data([]int{}),
			raw_data([]int{0xffef}),
			raw_data([]int{0xffffffffffffffef}),
			raw_data([]int{0x0}),
		},
		reg_masks = {
			{}, // Start
			{}, // Entry
			{{.General = 1}}, // CInt
			{{.General = 1}, {.General = 1}, {.General = 1}}, // Add
			{{.General = 1}, {.General = 1}, {.General = 1}}, // Sub
			{{.General = 1}, {.General = 1}, {.General = 1}}, // Mul
			{{.General = 1}, {.General = 1}, {.General = 1}}, // Eq
			{{.General = 1}, {.General = 1}, {.General = 1}}, // Ne
			{{.General = 2}, {.General = 2}}, // Split
			{{.General = 2}, {.General = 2}, {.General = 2}}, // Phi
			{{.General = 3}, {.General = 1}}, // If
			{}, // Then
			{}, // Else
			{}, // Jump
			{}, // Region
			{}, // Loop
			{}, // Return
		},
		inplace_slot_idxs = {
			-1, //Start
			-1, //Entry
			-1, //CInt
			0, //Add
			0, //Sub
			0, //Mul
			0, //Eq
			0, //Ne
			-1, //Split
			-1, //Phi
			-1, //If
			-1, //Then
			-1, //Else
			-1, //Jump
			-1, //Region
			-1, //Loop
			-1, //Return
		},
		reg_mask_of = x64_reg_mask_of,
		emit_function = x64_emit_function,
		first_input_idxs = {
			0, //Start
			0, //Entry
			0, //CInt
			0, //Add
			0, //Sub
			0, //Mul
			0, //Eq
			0, //Ne
			0, //Split
			0, //Phi
			1, //If
			0, //Then
			0, //Else
			1, //Jump
			0, //Region
			0, //Loop
			1, //Return
		},
		inheritance_table = {
			0b1, // Start
			0b1, // Entry
			0b10, // CInt
			0b100, // Add
			0b100, // Sub
			0b100, // Mul
			0b100, // Eq
			0b100, // Ne
			0b100, // Split
			0b100, // Phi
			0b1, // If
			0b1, // Then
			0b1, // Else
			0b1, // Jump
			0b1001, // Region
			0b1, // Loop
			0b1, // Return
		},
		node_extra_sizes = {
			1, // Start -> Cfg_Extra
			1, // Entry -> Cfg_Extra
			2, // CInt -> CInt
			0, // Add -> No_Extra
			0, // Sub -> No_Extra
			0, // Mul -> No_Extra
			0, // Eq -> No_Extra
			0, // Ne -> No_Extra
			0, // Split -> No_Extra
			0, // Phi -> No_Extra
			1, // If -> Cfg_Extra
			1, // Then -> Cfg_Extra
			1, // Else -> Cfg_Extra
			1, // Jump -> Cfg_Extra
			1, // Region -> Region
			1, // Loop -> Cfg_Extra
			1, // Return -> Cfg_Extra
		},
		node_flags = {
			{}, // Start
			{Class_Flag.Is_Basic_Block_Start}, // Entry
			{Class_Flag.Interned}, // CInt
			{Class_Flag.Interned, Class_Flag.Comutes}, // Add
			{}, // Sub
			{Class_Flag.Interned, Class_Flag.Comutes}, // Mul
			{Class_Flag.Interned, Class_Flag.Comutes}, // Eq
			{Class_Flag.Interned, Class_Flag.Comutes}, // Ne
			{}, // Split
			{Class_Flag.Interned}, // Phi
			{}, // If
			{Class_Flag.Is_Basic_Block_Start}, // Then
			{Class_Flag.Is_Basic_Block_Start}, // Else
			{}, // Jump
			{Class_Flag.Is_Basic_Block_Start}, // Region
			{Class_Flag.Is_Basic_Block_Start}, // Loop
			{Class_Flag.Immortal}, // Return
		},
		node_extra_types = {
			Cfg_Extra,
			Cfg_Extra,
			CInt,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			No_Extra,
			Cfg_Extra,
			Cfg_Extra,
			Cfg_Extra,
			Cfg_Extra,
			Region,
			Cfg_Extra,
			Cfg_Extra,
		},
		node_kind_name = {
			`Start`,
			`Entry`,
			`CInt`,
			`Add`,
			`Sub`,
			`Mul`,
			`Eq`,
			`Ne`,
			`Split`,
			`Phi`,
			`If`,
			`Then`,
			`Else`,
			`Jump`,
			`Region`,
			`Loop`,
			`Return`,
		},
	},
}

Builder_Node_Type :: enum u16 {

Start,
Entry,
CInt,
Add,
Sub,
Mul,
Eq,
Ne,
Split,
Phi,
If,
Then,
Else,
Jump,
Region,
Loop,
Return,
Scope,
Lazy_Phi,
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
graph_add_sub :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype, lhs: Node_ID, rhs: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Ideal_Node_Type.Sub), dt, {lhs, rhs})
}
#assert(size_of(No_Extra) % 4 == 0)
graph_add_mul :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype, lhs: Node_ID, rhs: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Ideal_Node_Type.Mul), dt, {lhs, rhs})
}
#assert(size_of(No_Extra) % 4 == 0)
graph_add_eq :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype, lhs: Node_ID, rhs: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Ideal_Node_Type.Eq), dt, {lhs, rhs})
}
#assert(size_of(No_Extra) % 4 == 0)
graph_add_ne :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype, lhs: Node_ID, rhs: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Ideal_Node_Type.Ne), dt, {lhs, rhs})
}
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
#assert(size_of(Cfg_Extra) % 4 == 0)
graph_add_if :: #force_inline proc(graph: ^Graph, name: string, ctrl: Node_ID, cond: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Ideal_Node_Type.If), .Void, {ctrl, cond})
}
#assert(size_of(Cfg_Extra) % 4 == 0)
graph_add_then :: #force_inline proc(graph: ^Graph, name: string, ctrl: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Ideal_Node_Type.Then), .Void, {ctrl})
}
#assert(size_of(Cfg_Extra) % 4 == 0)
graph_add_else :: #force_inline proc(graph: ^Graph, name: string, ctrl: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Ideal_Node_Type.Else), .Void, {ctrl})
}
#assert(size_of(Cfg_Extra) % 4 == 0)
graph_add_jump :: #force_inline proc(graph: ^Graph, name: string, ctrl: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Ideal_Node_Type.Jump), .Void, {ctrl})
}
#assert(size_of(Region) % 4 == 0)
graph_add_region :: #force_inline proc(graph: ^Graph, name: string, rcfg: Node_ID, lcfg: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Ideal_Node_Type.Region), .Void, {rcfg, lcfg})
}
#assert(size_of(Cfg_Extra) % 4 == 0)
graph_add_loop :: #force_inline proc(graph: ^Graph, name: string, ctrl: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Ideal_Node_Type.Loop), .Void, {ctrl}, extra_capacity = 1)
}
#assert(size_of(Cfg_Extra) % 4 == 0)
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
graph_add_lazyPhi :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype, reg: Node_ID, lhs: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Builder_Node_Type.Lazy_Phi), dt, {reg, lhs}, extra_capacity = 1)
}
X64_Node_Type :: enum u16 {

Start,
Entry,
CInt,
Add,
Sub,
Mul,
Eq,
Ne,
Split,
Phi,
If,
Then,
Else,
Jump,
Region,
Loop,
Return,
}

inherit_idx_of :: #force_inline proc($T: typeid) -> u8 {
	when false {}
	else when T == No_Extra {return 2}
	else when T == CInt {return 1}
	else when T == Region {return 3}
	else when T == Scope {return 4}
	else when T == Cfg_Extra {return 0}
	else {#panic(`the passed type is not subclass of anything`)}
}
}
