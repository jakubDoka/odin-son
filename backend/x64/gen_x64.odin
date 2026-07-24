#+build !wasm32
package x64

import backend ".."

when GEN_SPEC {
	main :: proc() {
		backend.generate_spec(
			backend.Spec_Gen_Input {
				package_name = "x64",
				gen_command = COMMAND,
				// %w-formatted table values bake in bare Reg_Kind/Class_Flag
				// names, so alias them locally instead of teaching the
				// generator about every %w call site
				header_import = "import backend \"..\"\n" + "Reg_Kind :: backend.Reg_Kind\n" + "Class_Flag :: backend.Class_Flag\n",
				qual = "backend.",
				local_extra_types = {X64_Mem_Op},
				name = "X64",
				classes = {
					backend.class_array(
						&backend.IDEAL_CLASSES,
						&X64_IDEAL_REG_CLASSES,
						gen_ctors = false,
					),
					backend.class_array(&X64_CLASSES, &X64_REG_CLASSES),
				},
				datatype_to_reg_kind = #partial{
					.I8 ..= .I64 = .General,
					.F32 ..= .V512 = .Vector,
				},
				cc_table = {X64_SYSTEMV_CC, X64_LINUX_SYSCALL_CC},
			},
			"backend/x64/node_specs.odin",
		)
	}
}
