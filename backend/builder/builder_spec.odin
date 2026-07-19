package builder

import backend ".."

GEN_SPEC :: #config(BUILDER_GEN_SPEC, false)

COMMAND :: "odin run backend/builder -define:BUILDER_GEN_SPEC=true"

SPEC_NOT_PRESENT :: (#load("node_specs.odin", string) or_else "") == ""

Scope :: struct #align (4) {
	done: bool,
}

when SPEC_NOT_PRESENT {
	@(rodata)
	SPEC := backend.Node_Spec{}

	inherit_idx_of :: proc($T: typeid) -> u8 {return 0}

	Builder_Node_Type :: enum u16 {
		Scope,
		Lazy_Phi,
		Dead,
	}

	@(rodata)
	BUILDER_CLASSES := [Builder_Node_Type]backend.Class_Spec {
		.Scope = {id = Scope, args = {"cfg"}, default_type = .Void},
		.Lazy_Phi = {args = {"reg", "lhs"}, extra_capacity = 1},
		.Dead = {default_type = .Void},
	}

	graph_add_lazy_phi :: proc(
		graph: ^backend.Graph,
		name: string,
		dt: backend.Node_Datatype,
		region: backend.Node_ID,
		lhs: backend.Node_ID,
	) -> backend.Node_ID {return 0}

	graph_add_scope :: proc(
		graph: ^backend.Graph,
		name: string,
		cfg: backend.Node_ID,
	) -> backend.Node_ID {return 0}

	when !GEN_SPEC {
		#panic("Missing generated files, run `" + COMMAND + "`")
	}
} else {
	@(rodata)
	BUILDER_CLASSES := [Builder_Node_Type]backend.Class_Spec{}
}

@(rodata)
BUILDER_REG_CLASSES := [Builder_Node_Type]backend.Reg_Class_Spec{}

@(rodata)
IDEAL_REG_CLASSES := [backend.Ideal_Node_Type]backend.Reg_Class_Spec{}
