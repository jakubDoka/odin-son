package builder

import bac ".."

SPEC_NOT_PRESENT :: (#load("node_specs.odin", string) or_else "") == ""

Scope :: struct #align (4) {
	done: bool,
}

when SPEC_NOT_PRESENT {
	@(rodata)
	SPEC := bac.Node_Spec{}

	inherit_idx_of :: proc($T: typeid) -> u8 {return 0}

	Node_Type :: enum u16 {
		Scope,
		Lazy_Phi,
	}

	add_lazy_phi :: proc(
		graph: ^bac.Graph,
		name: string,
		dt: bac.Node_Datatype,
		region: Node_ID,
		lhs: Node_ID,
	) -> Node_ID {return 0}

	add_scope :: proc(
		graph: ^bac.Graph,
		name: string,
		cfg: Node_ID,
	) -> Node_ID {return 0}

	add_dead :: proc(
		graph: ^bac.Graph,
		name: string,
	) -> Node_ID {return 0}
}
