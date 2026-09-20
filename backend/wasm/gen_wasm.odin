#+build !wasm32
package wasm

import backend ".."

_ :: backend

when GEN_SPEC {
	main :: proc() {
		backend.generate_spec(
			backend.Spec_Gen_Input {
				package_name = "wasm",
				gen_command = COMMAND,
				// %w-formatted table values bake in bare Reg_Kind/Class_Flag
				// names, so alias them locally instead of teaching the
				// generator about every %w call site
				header_import = "import backend \"..\"\n" + "Reg_Kind :: backend.Reg_Kind\n" + "Class_Flag :: backend.Class_Flag\n",
				qual = "backend.",
				local_extra_types = {WASM_Lane_Op, WASM_Mem_Op},
				name = "WASM",
				classes = {
					backend.class_array(
						&backend.IDEAL_CLASSES,
						gen_ctors = false,
					),
					backend.class_array(&WASM_CLASSES),
				},
				does_regalloc = true,
				has_regalloc_preprocess_hook = true,
				datatype_to_reg_kind = #partial{
					.I8 ..= .I32 = RK_I32,
					.I64 = RK_I64,
					.F32 = RK_F32,
					.F64 = RK_F64,
					.V128 = RK_V128,
				},
				spill_boundary = {0 ..= RK_COUNT = 64},
				cc_table = {WASM_SYSTEMV_CC},
			},
			"backend/wasm/node_specs.odin",
		)
	}
}
