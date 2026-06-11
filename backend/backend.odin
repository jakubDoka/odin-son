package backend

import "core:fmt"
import "core:mem"
import "core:os"

MAX_NODE_TYPES :: 128

CODEGEN :: #config(CODEGEN, false)

when (#load("node_specs.odin", string) or_else "") == "" {
	@(rodata)
	SPECS := [Node_Spec_Name]Node_Spec{}

	main :: proc() {
		generate_specs()
	}
}

generate_specs :: proc() {
	_ = SPECS

	context.allocator = context.temp_allocator

	specs := [?]Codegen_Spec{{name = .Ideal, classes = {IDEAL_CLASSES}}}

	file, err := os.open("backend/node_specs.odin", {.Create, .Trunc, .Write})
	fmt.assertf(err == nil, "%v", err)
	defer os.close(file)

	for spec in specs {
		os.write_string(file, "package backend")
		os.write_string(file, "// NOTE: this file is generated")
		os.write_string(file, "\n")
	}
}

Codegen_Spec :: struct {
	name:    Node_Spec_Name,
	classes: []any,
}

Node_Spec_Name :: enum {
	Ideal,
	X64,
}

Node_Spec :: struct {
	node_extra_sizes: []u8,
}

Base_Extra :: struct {}

Cfg_Extra :: struct {
	using base: Base_Extra,
}

@(rodata)
IDEAL_CLASSES := [I_Node_Type]typeid {
	.Start  = Cfg_Extra,
	.Entry  = Cfg_Extra,
	.Return = Cfg_Extra,
}

I_Node_Type :: enum u16 {
	Start,
	Entry,
	Return,
}

X64_Node_Type :: enum u16 {}

Node_Datatype :: enum u8 {
	Void,
}

Node_ID :: distinct u32

Node_Output :: bit_field u32 {
	id:  Node_ID | 24,
	idx: u8      | 8,
}

Node :: struct {
	using _:             struct #raw_union {
		itype: I_Node_Type,
		xtype: X64_Node_Type,
		rtype: u16,
	},
	using _:             bit_field u8 {
		dt: Node_Datatype | 8,
	},
	user_idx:            u8,
	gvn:                 u32,
	inputs:              u32,
	ordered_input_count: u16,
	input_count:         u16,
	outputs:             u32,
	output_count:        u16,
	output_cap:          u16,
	extra:               [0]u32,
}

#assert(size_of(Node) == 24)

Graph :: struct {
	using node_spec: ^Node_Spec,
	mem:             [dynamic]u32,
	gvn:             u32,
}

graph_add :: proc(
	graph: ^Graph,
	type: I_Node_Type,
	dt: Node_Datatype,
	inputs: []Node_ID,
) -> Node_ID {
	return graph_add_raw(graph, u16(type), dt, inputs)
}

graph_add_raw :: proc(
	graph: ^Graph,
	type: u16,
	dt: Node_Datatype,
	inputs: []Node_ID,
) -> (
	id: Node_ID,
) {
	id = Node_ID(len(graph.mem))

	resize(
		&graph.mem,
		len(graph.mem) +
		size_of(Node) / size_of(u32) +
		int(graph.node_extra_sizes[type]),
	)

	(^Node)(&graph.mem[id])^ = {
		rtype               = type,
		dt                  = dt,
		gvn                 = graph.gvn,
		inputs              = u32(len(graph.mem)),
		ordered_input_count = u16(len(inputs)),
		input_count         = u16(len(inputs)),
	}

	append(&graph.mem, ..mem.slice_data_cast([]u32, inputs))

	graph.gvn += 1

	return
}
