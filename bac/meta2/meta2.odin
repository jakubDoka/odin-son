package bac_meta2

import ".."
import "../amd64"
import "../anal"
import "../arm"
import "../intel_xelp"
import "../meta"
import "../ssa"
import "../wasm"

main :: proc() {
	when ssa.SPEC_NOT_PRESENT {
		SSA_CLASSES := [ssa.Node_Type]meta.Class_Spec {
			.Scope = {
				id = ssa.Scope,
				args = {"cfg"},
				default_type = .Void,
				api = true,
			},
			.Lazy_Phi = {args = {"reg", "lhs"}, extra_capacity = 1},
		}

		meta.generate_spec(
			meta.Spec_Gen_Input {
				package_name      = "bac_ssa",
				// %w-formatted table values bake in bare Reg_Kind/Class_Flag
				// names, so alias them locally instead of teaching the
				// generator about every %w call site
				header_import     = "import bac \"..\"\n" + "Reg_Kind :: bac.Reg_Kind\n" + "Class_Flag :: bac.Class_Flag\n",
				qual              = "bac.",
				local_extra_types = {ssa.Scope},
				classes           = {
					meta.class_array(&meta.IDEAL_CLASSES, gen_ctors = false),
					meta.class_array(&SSA_CLASSES),
				},
				has_sccp          = true,
			},
			"bac/ssa/node_specs.odin",
		)
	}

	when anal.SPEC_NOT_PRESENT {
		meta.generate_spec(
			meta.Spec_Gen_Input {
				package_name = "bac_anal",
				header_import = "import bac \"..\"\n" +
				"Reg_Kind :: bac.Reg_Kind\n" +
				"Class_Flag :: bac.Class_Flag\n",
				qual = "bac.",
				classes = {meta.class_array(&meta.IDEAL_CLASSES, gen_ctors = false)},
			},
			"bac/anal/node_specs.odin",
		)
	}

	when intel_xelp.SPEC_NOT_PRESENT {
		XELP_CLASSES := [intel_xelp.Node_Type]meta.Class_Spec {
			.Inv = {no_ctor = true, flags = {.Interned}},
			.Value_Eq ..= .Value_U_Ge = {no_ctor = true, flags = {.Interned}},
			.Extract_Lane = {id = bac.Tup, no_ctor = true, flags = {.Interned}},
			.Address_Payload = {no_ctor = true},
			.Store_A64 = {no_ctor = true, flags = {.Store}},
			.Lane_Sequence = {no_ctor = true, flags = {.Interned}},
			.Mul_Lo16 ..= .Mul_Hi16 = {no_ctor = true, flags = {.Interned}},
		}

		meta.generate_spec(
			meta.Spec_Gen_Input {
				package_name = "bac_intel_xelp",
				header_import = "import bac \"..\"\n" + "Reg_Kind :: bac.Reg_Kind\n" + "Class_Flag :: bac.Class_Flag\n",
				qual = "bac.",
				classes = {
					meta.class_array(&meta.IDEAL_CLASSES, gen_ctors = false),
					meta.class_array(&XELP_CLASSES),
				},
				does_regalloc = true,
				datatype_to_reg_kind = #partial{.I8 ..= .V512 = intel_xelp.RK_GRF},
				spill_boundary = {intel_xelp.GRF_COUNT, intel_xelp.FLAG_COUNT},
				cc_table = intel_xelp.CC_TABLE[:],
				common_reg_specs = {
					// TODO: this is not ideal to reserve so many registers for shit
					// and instead support this in the regalloc but that is a big task
					{"GRF", intel_xelp.RK_GRF, {~i64(1), ~i64(0xf << 52)}},
					{"FLAG", intel_xelp.RK_FLAG, {0xf, 0}},
				},
			},
			"bac/intel_xelp/node_specs.odin",
		)
	}

	when amd64.SPEC_NOT_PRESENT {
		AMD64_SIMPLE_BIN_OP_SPEC :: meta.Class_Spec {
			id      = amd64.Mem_Op,
			no_ctor = true,
		}

		AMD64_SIMPLE_SHIFT_OP_SPEC :: meta.Class_Spec {
			id      = amd64.Mem_Op,
			no_ctor = true,
		}

		AMD64_SIMPLE_UN_OP_SPEC :: meta.Class_Spec {
			id      = amd64.Mem_Op,
			no_ctor = true,
		}

		AMD64_CLASSES := [amd64.Node_Type]meta.Class_Spec {
			.AMD64_Add ..= .AMD64_U_Ge = AMD64_SIMPLE_BIN_OP_SPEC,
			.AMD64_Shl ..= .AMD64_U_Shr = AMD64_SIMPLE_SHIFT_OP_SPEC,
			.AMD64_Neg ..= .AMD64_Not = AMD64_SIMPLE_UN_OP_SPEC,
			.AMD64_Pcmpeq = {no_ctor = true, flags = {.Interned}},
			.AMD64_Padd ..= .AMD64_Psub = AMD64_SIMPLE_BIN_OP_SPEC,
			.AMD64_Psadbw = {args = {"lhs", "rhs"}},
			.AMD64_Pshufd = {id = amd64.Mem_Op, no_ctor = true},
			.AMD64_Pshuflw = {id = amd64.Mem_Op, no_ctor = true},
			.AMD64_Pshufb = {id = amd64.Mem_Op, no_ctor = true},
			.AMD64_Pextr = {id = amd64.Mem_Op, no_ctor = true},
			.AMD64_Mul ..= .AMD64_Div = AMD64_SIMPLE_BIN_OP_SPEC,
			.AMD64_Lea = {id = amd64.Mem_Op, no_ctor = true},
			.AMD64_Load = {id = amd64.Mem_Op, flags = {.Load}, no_ctor = true},
			.AMD64_Store = {id = amd64.Mem_Op, flags = {.Store}, no_ctor = true},
			.AMD64_Mul8 = {no_ctor = true, flags = {.Interned}},
			.AMD64_Fma_213 = {id = amd64.Mem_Op, no_ctor = true},
		}

		meta.generate_spec(
			meta.Spec_Gen_Input {
				package_name = "bac_amd64",
				// %w-formatted table values bake in bare Reg_Kind/Class_Flag
				// names, so alias them locally instead of teaching the
				// generator about every %w call site
				header_import = "import bac \"..\"\n" + "Reg_Kind :: bac.Reg_Kind\n" + "Class_Flag :: bac.Class_Flag\n",
				qual = "bac.",
				local_extra_types = {amd64.Mem_Op},
				classes = {
					meta.class_array(&meta.IDEAL_CLASSES, gen_ctors = false),
					meta.class_array(&AMD64_CLASSES),
				},
				does_regalloc = true,
				datatype_to_reg_kind = #partial{
					.I8 ..= .I64 = amd64.RK_GENERAL,
					.F32 ..= .V512 = amd64.RK_VECTOR,
				},
				spill_boundary = {int(amd64.FLAGS) + 1, 16},
				cc_table = amd64.CC_TABLE[:],
				common_reg_specs = {
					{"GPA", amd64.RK_GENERAL, {0xFFFF & ~i64(1 << uint(amd64.RSP))}},
					{
						"GPA_SPILL",
						amd64.RK_GENERAL,
						{~i64(1 << uint(amd64.RSP) | 1 << uint(amd64.FLAGS))},
					},
					{"GPA_SPLIT", amd64.RK_GENERAL, {~i64(1 << uint(amd64.RSP))}},
					{"XMM", amd64.RK_VECTOR, {0xFFFF}},
					{"XMM_SPILL", amd64.RK_VECTOR, {~i64(0)}},
				},
			},
			"bac/amd64/node_specs.odin",
		)
	}

	when wasm.SPEC_NOT_PRESENT {
		WASM_CLASSES := [wasm.Node_Type]meta.Class_Spec {
			.WASM_Store = {id = wasm.Mem_Op, no_ctor = true, flags = {.Store}},
			.WASM_Load = {id = wasm.Mem_Op, no_ctor = true, flags = {.Load}},
			.Get_Local = {no_ctor = true},
			.Set_Local = {no_ctor = true},
			.Tee_Local = {no_ctor = true},
			.Drop = {no_ctor = true},
			.Stub = {no_ctor = true},
			.Extract_Lane_U = {
				id = wasm.Lane_Op,
				args = {"vec"},
				extra_args = {"laneidx"},
				pass_lane = true,
			},
			.WASM_Shl ..= .WASM_U_Shr = {no_ctor = true},
		}

		meta.generate_spec(
			meta.Spec_Gen_Input {
				package_name = "bac_wasm",
				// %w-formatted table values bake in bare Reg_Kind/Class_Flag
				// names, so alias them locally instead of teaching the
				// generator about every %w call site
				header_import = "import bac \"..\"\n" + "Reg_Kind :: bac.Reg_Kind\n" + "Class_Flag :: bac.Class_Flag\n",
				qual = "bac.",
				local_extra_types = {wasm.Lane_Op, wasm.Mem_Op},
				classes = {
					meta.class_array(&meta.IDEAL_CLASSES, gen_ctors = false),
					meta.class_array(&WASM_CLASSES),
				},
				does_regalloc = true,
				has_regalloc_preprocess_hook = true,
				datatype_to_reg_kind = #partial{
					.I8 ..= .I32 = wasm.RK_I32,
					.I64 = wasm.RK_I64,
					.F32 = wasm.RK_F32,
					.F64 = wasm.RK_F64,
					.V128 = wasm.RK_V128,
				},
				spill_boundary = {0 ..= wasm.RK_COUNT = 64},
				cc_table = wasm.CC_TABLE[:],
			},
			"bac/wasm/node_specs.odin",
		)
	}

	when arm.SPEC_NOT_PRESENT {
		ARM_CLASSES := [arm.Node_Type]meta.Class_Spec {
			.Msub = {args = {"multiplicant", "multiplier", "subtractant"}},
			.Cmlt = {args = {"lhs"}, pass_lane = true, default_type = .V128},
			.Ext = {
				id = arm.Arm_Op,
				default_type = .V128,
				args = {"lhs", "rhs"},
				extra_args = {"aux"},
				pass_lane = true,
			},
			.Zip1 = {default_type = .V128, args = {"lsh", "rhs"}, pass_lane = true},
			.Addv128 = {args = {"vec"}, pass_lane = true},
			.Umov = {id = arm.Arm_Op, args = {"vec"}, extra_args = {"aux"}},
			.Lslv ..= .Lsrv = {no_ctor = true},
		}

		meta.generate_spec(
			meta.Spec_Gen_Input {
				package_name = "bac_arm",
				header_import = "import bac \"..\"\n" +
				"Reg_Kind :: bac.Reg_Kind\n" +
				"Class_Flag :: bac.Class_Flag\n",
				qual = "bac.",
				local_extra_types = {arm.Arm_Op},
				classes = {
					meta.class_array(&meta.IDEAL_CLASSES, gen_ctors = false),
					meta.class_array(&ARM_CLASSES),
				},
				does_regalloc = true,
				datatype_to_reg_kind = #partial{
					.I8 ..= .I64 = arm.RK_GENERAL,
					.F32 ..= .V512 = arm.RK_VECTOR,
				},
				spill_boundary = {int(arm.FLAGS) + 1, 32},
				cc_table = arm.CC_TABLE[:],
				common_reg_specs = {
					{"GPA", arm.RK_GENERAL, {0x3FFFFFFF}},
					{
						"GPA_SPILL",
						arm.RK_GENERAL,
						{~i64(1 << uint(arm.SP) | 1 << 30 | 1 << uint(arm.FLAGS))},
					},
					{"GPA_SPLIT", arm.RK_GENERAL, {~i64(1 << uint(arm.SP) | 1 << 30)}},
					{"VEC", arm.RK_VECTOR, {0xFFFFFFFF}},
					{"VEC_SPILL", arm.RK_VECTOR, {~i64(0)}},
				},
			},
			"bac/arm/node_specs.odin",
		)
	}
}
