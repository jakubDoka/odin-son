#+build !wasm32
package arm

import backend ".."

when GEN_SPEC {
	main :: proc() {
		backend.generate_spec(
			backend.Spec_Gen_Input {
				package_name = "arm",
				gen_command = COMMAND,
				header_import = "import backend \"..\"\n" +
				"Reg_Kind :: backend.Reg_Kind\n" +
				"Class_Flag :: backend.Class_Flag\n",
				qual = "backend.",
				name = "ARM",
				classes = {
					backend.class_array(
						&backend.IDEAL_CLASSES,
						gen_ctors = false,
					),
				},
				datatype_to_reg_kind = #partial{.I8 ..= .V512 = RK_GENERAL},
				spill_boundary = {32, 32},
				cc_table = {ARM_SYSTEMV_CC},
			},
			"backend/arm/node_specs.odin",
		)
	}
}
