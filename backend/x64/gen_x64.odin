#+build !wasm32
package x64

import backend ".."

_ :: backend

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
				local_extra_types = {Mem_Op},
				classes = {
					backend.class_array(
						&backend.IDEAL_CLASSES,
						gen_ctors = false,
					),
					backend.class_array(&X64_CLASSES),
				},
				does_regalloc = true,
				datatype_to_reg_kind = #partial{
					.I8 ..= .I64 = RK_GENERAL,
					.F32 ..= .V512 = RK_VECTOR,
				},
				spill_boundary = {16, 16},
				cc_table = {X64_SYSTEMV_CC, X64_LINUX_SYSCALL_CC},
			},
			"backend/x64/node_specs.odin",
		)
	}
}
