#+build !wasm32
package anal

import backend ".."

when GEN_SPEC {
	main :: proc() {
		backend.generate_spec(
			backend.Spec_Gen_Input {
				package_name = "anal",
				gen_command = COMMAND,
				header_import = "import backend \"..\"\n" +
				"Reg_Kind :: backend.Reg_Kind\n" +
				"Class_Flag :: backend.Class_Flag\n",
				qual = "backend.",
				name = "ANAL",
				classes = {
					backend.class_array(
						&backend.IDEAL_CLASSES,
						&ANAL_IDEAL_REG_CLASSES,
						gen_ctors = false,
					),
				},
			},
			"backend/anal/node_specs.odin",
		)
	}
}
