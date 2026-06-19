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
			{.General = 0}, // Split
			{.General = 0}, // Phi
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
			{}, // Split
			{}, // Phi
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
			-1, //Split
			-1, //Phi
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
			0, //Split
			0, //Phi
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
			0b10, // Split
			0b10, // Phi
			0b1, // If
			0b1, // Then
			0b1, // Else
			0b1, // Jump
			0b10001, // Region
			0b1, // Loop
			0b1, // Always
			0b100001, // Call
			0b1, // Call_End
			0b100, // Ret
			0b1, // Return
			0b1000000, // Scope
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
			0, // Split -> No_Extra
			0, // Phi -> No_Extra
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
			{}, // Split
			{Class_Flag.Interned}, // Phi
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
			`Split`,
			`Phi`,
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
			{.General = 0}, // Split
			{.General = 0}, // Phi
			{.General = 0}, // If
			{.General = 0}, // Then
			{.General = 0}, // Else
			{.General = 0}, // Jump
			{.General = 0}, // Region
			{.General = 0}, // Loop
			{.General = 0}, // Always
			{.General = 4045}, // Call
			{.General = 0}, // Call_End
			{.General = 0}, // Ret
			{.General = 0}, // Return
		},
		interned_reg_masks = {
			raw_data([]int{}),
			raw_data([]int{0xffef}),
			raw_data([]int{0xffffffffffffffef}),
			raw_data([]int{0x0}),
			raw_data([]int{0x1}),
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
			{{.General = 2}, {.General = 2}}, // Split
			{{.General = 2}, {.General = 2}, {.General = 2}}, // Phi
			{{.General = 3}, {.General = 1}}, // If
			{}, // Then
			{}, // Else
			{}, // Jump
			{}, // Region
			{}, // Loop
			{}, // Always
			{}, // Call
			{}, // Call_End
			{{.General = 4}}, // Ret
			{{.General = 3}, {.General = 4}}, // Return
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
			-1, //Split
			-1, //Phi
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
			0, //Split
			0, //Phi
			1, //If
			0, //Then
			0, //Else
			1, //Jump
			0, //Region
			0, //Loop
			1, //Always
			1, //Call
			0, //Call_End
			1, //Ret
			1, //Return
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
			0b10, // Split
			0b10, // Phi
			0b1, // If
			0b1, // Then
			0b1, // Else
			0b1, // Jump
			0b10001, // Region
			0b1, // Loop
			0b1, // Always
			0b100001, // Call
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
			0, // Split -> No_Extra
			0, // Phi -> No_Extra
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
			{}, // Split
			{Class_Flag.Interned}, // Phi
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
			`Split`,
			`Phi`,
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
Split,
Phi,
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
graph_add_le :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype, lhs: Node_ID, rhs: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Ideal_Node_Type.Le), dt, {lhs, rhs})
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
graph_add_callEnd :: #force_inline proc(graph: ^Graph, name: string, call: Node_ID) -> (id: Node_ID) {
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
graph_add_lazyPhi :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype, reg: Node_ID, lhs: Node_ID) -> (id: Node_ID) {
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
Split,
Phi,
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
	else when T == Region {return 4}
	else when T == Scope {return 6}
	else when T == No_Extra {return 1}
	else when T == Call {return 5}
	else when T == Cfg {return 0}
	else {#panic(`the passed type is not subclass of anything`)}
}
}
