#+build !wasm32
package builder

import backend ".."

when GEN_SPEC {
	graph_add_dead :: proc(
		graph: ^backend.Graph,
		name: string,
	) -> Node_ID {return 0}

	main :: proc() {
		backend.generate_spec(
			backend.Spec_Gen_Input {
				package_name      = "builder",
				gen_command       = COMMAND,
				// %w-formatted table values bake in bare Reg_Kind/Class_Flag
				// names, so alias them locally instead of teaching the
				// generator about every %w call site
				header_import     = "import backend \"..\"\n" + "Reg_Kind :: backend.Reg_Kind\n" + "Class_Flag :: backend.Class_Flag\n",
				qual              = "backend.",
				local_extra_types = {Scope},
				name              = "Builder",
				classes           = {
					backend.class_array(
						&backend.IDEAL_CLASSES,
						gen_ctors = false,
					),
					backend.class_array(&BUILDER_CLASSES),
				},
				intern            = true,
			},
			"backend/builder/node_specs.odin",
		)
	}
}
