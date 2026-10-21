package main

import meta "../../meta"
import eu ".."

main :: proc() {
	meta.generate_spec({
		package_name = "bac_intel_xelp",
		gen_command = "odin run bac/intel_xelp/gen",
		header_import = "import bac \"..\"\nReg_Kind :: bac.Reg_Kind\nClass_Flag :: bac.Class_Flag\n",
		qual = "bac.",
		classes = {meta.class_array(&meta.IDEAL_CLASSES, gen_ctors = false)},
		does_regalloc = true,
		datatype_to_reg_kind = {},
		spill_boundary = {128},
		cc_table = eu.CC_TABLE[:],
	}, "bac/intel_xelp/node_specs.odin")
}
