package backend_meta2

import ".."
import "../anal"
import "../arm"
import "../builder"
import "../meta"
import "../wasm"
import "../x64"

main :: proc() {
	when x64.SPEC_NOT_PRESENT {
		X64_SIMPLE_BIN_OP_SPEC :: meta.Class_Spec {
			id      = x64.Mem_Op,
			no_ctor = true,
		}

		X64_SIMPLE_SHIFT_OP_SPEC :: meta.Class_Spec {
			id      = x64.Mem_Op,
			no_ctor = true,
		}

		X64_SIMPLE_UN_OP_SPEC :: meta.Class_Spec {
			id      = x64.Mem_Op,
			no_ctor = true,
		}

		X64_CLASSES := [x64.Node_Type]meta.Class_Spec {
			.X64_Add ..= .X64_U_Ge = X64_SIMPLE_BIN_OP_SPEC,
			.X64_Shl ..= .X64_U_Shr = X64_SIMPLE_SHIFT_OP_SPEC,
			.X64_Neg ..= .X64_Not = X64_SIMPLE_UN_OP_SPEC,
			.X64_F_Eq ..= .X64_F_Ge = X64_SIMPLE_BIN_OP_SPEC,
			.X64_Pcmpeq = {no_ctor = true},
			.X64_Psadbw = {args = {"lhs", "rhs"}},
			.X64_Pshufd = {id = x64.Mem_Op, no_ctor = true},
			.X64_Pshufb = {id = x64.Mem_Op, no_ctor = true},
			.X64_Pextr = {id = x64.Mem_Op, no_ctor = true},
			.X64_Mul = X64_SIMPLE_BIN_OP_SPEC,
			.X64_Lea = {id = x64.Mem_Op, no_ctor = true},
			.X64_Load = {id = x64.Mem_Op, flags = {.Load}, no_ctor = true},
			.X64_CLoad = {flags = {.Clonable}, no_ctor = true},
			.X64_Store = {id = x64.Mem_Op, flags = {.Store}, no_ctor = true},
			.X64_Mul8 = {no_ctor = true},
			.X64_F_Add ..= .X64_F_Div = {id = x64.Mem_Op, no_ctor = true},
			.X64_Fma_213 = {id = x64.Mem_Op, no_ctor = true},
		}

		meta.generate_spec(
			meta.Spec_Gen_Input {
				package_name = "x64",
				// %w-formatted table values bake in bare Reg_Kind/Class_Flag
				// names, so alias them locally instead of teaching the
				// generator about every %w call site
				header_import = "import backend \"..\"\n" + "Reg_Kind :: backend.Reg_Kind\n" + "Class_Flag :: backend.Class_Flag\n",
				qual = "backend.",
				local_extra_types = {x64.Mem_Op},
				classes = {
					meta.class_array(&meta.IDEAL_CLASSES, gen_ctors = false),
					meta.class_array(&X64_CLASSES),
				},
				does_regalloc = true,
				datatype_to_reg_kind = #partial{
					.I8 ..= .I64 = x64.RK_GENERAL,
					.F32 ..= .V512 = x64.RK_VECTOR,
				},
				spill_boundary = {16, 16},
				cc_table = {x64.X64_SYSTEMV_CC, x64.X64_LINUX_SYSCALL_CC},
			},
			"backend/x64/node_specs.odin",
		)
	}

	when builder.SPEC_NOT_PRESENT {
		BUILDER_CLASSES := [builder.Node_Type]meta.Class_Spec {
			.Scope = {
				id = builder.Scope,
				args = {"cfg"},
				default_type = .Void,
			},
			.Lazy_Phi = {args = {"reg", "lhs"}, extra_capacity = 1},
		}

		meta.generate_spec(
			meta.Spec_Gen_Input {
				package_name      = "builder",
				// %w-formatted table values bake in bare Reg_Kind/Class_Flag
				// names, so alias them locally instead of teaching the
				// generator about every %w call site
				header_import     = "import backend \"..\"\n" + "Reg_Kind :: backend.Reg_Kind\n" + "Class_Flag :: backend.Class_Flag\n",
				qual              = "backend.",
				local_extra_types = {builder.Scope},
				classes           = {
					meta.class_array(&meta.IDEAL_CLASSES, gen_ctors = false),
					meta.class_array(&BUILDER_CLASSES),
				},
				intern            = true,
			},
			"backend/builder/node_specs.odin",
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
		}

		meta.generate_spec(
			meta.Spec_Gen_Input {
				package_name = "wasm",
				// %w-formatted table values bake in bare Reg_Kind/Class_Flag
				// names, so alias them locally instead of teaching the
				// generator about every %w call site
				header_import = "import backend \"..\"\n" + "Reg_Kind :: backend.Reg_Kind\n" + "Class_Flag :: backend.Class_Flag\n",
				qual = "backend.",
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
				cc_table = {wasm.WASM_SYSTEMV_CC},
			},
			"backend/wasm/node_specs.odin",
		)
	}

	when arm.SPEC_NOT_PRESENT {
		meta.generate_spec(
			meta.Spec_Gen_Input {
				package_name = "arm",
				header_import = "import backend \"..\"\n" +
				"Reg_Kind :: backend.Reg_Kind\n" +
				"Class_Flag :: backend.Class_Flag\n",
				qual = "backend.",
				classes = {
					meta.class_array(&meta.IDEAL_CLASSES, gen_ctors = false),
				},
				datatype_to_reg_kind = #partial{
					.I8 ..= .V512 = arm.RK_GENERAL,
				},
				spill_boundary = {32, 32},
				cc_table = {arm.ARM_SYSTEMV_CC},
			},
			"backend/arm/node_specs.odin",
		)
	}

	when anal.SPEC_NOT_PRESENT {
		meta.generate_spec(
			meta.Spec_Gen_Input {
				package_name = "anal",
				header_import = "import backend \"..\"\n" +
				"Reg_Kind :: backend.Reg_Kind\n" +
				"Class_Flag :: backend.Class_Flag\n",
				qual = "backend.",
				classes = {
					meta.class_array(&meta.IDEAL_CLASSES, gen_ctors = false),
				},
			},
			"backend/anal/node_specs.odin",
		)
	}
}
