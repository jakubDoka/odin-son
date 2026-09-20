package backend

SPEC_NOT_PRESENT :: (#load("node_specs.odin", string) or_else "") == ""

when SPEC_NOT_PRESENT {
	inherit_idx_of :: proc($T: typeid) -> u8 {return 0}

	graph_add_return :: proc(
		graph: ^Graph,
		name: string,
		inputs: []Node_ID,
	) -> Node_ID {return 0}

	graph_add_region :: proc(
		graph: ^Graph,
		name: string,
		ctrls: []Node_ID,
	) -> Node_ID {return 0}

	graph_add_jump :: proc(
		graph: ^Graph,
		name: string,
		ctrl: Node_ID,
	) -> Node_ID {return 0}
	graph_add_always :: graph_add_jump
	graph_add_then :: graph_add_jump
	graph_add_else :: graph_add_jump
	graph_add_poison :: proc(graph: ^Graph, name: string) -> Node_ID {return 0}
}

root_addr_add_offset :: proc(
	graph: ^Graph,
	node: Expanded_Node,
) -> (
	base: Node_ID,
	off: int,
	ok: bool,
) {
	return
}
