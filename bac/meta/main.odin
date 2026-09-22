package bac_meta

import ".."
import "core:fmt"
import "core:os"
import "core:reflect"
import "core:slice"
import "core:strings"

Mask_Intern_Key :: u8

Class_Array :: struct {
	enm:       typeid,
	ids:       []Class_Spec,
	gen_ctors: bool,
}

Spec_Gen_Input :: struct {
	package_name:                 string,
	gen_command:                  string,
	header_import:                string,
	qual:                         string,
	local_extra_types:            []typeid,
	classes:                      []Class_Array,
	datatype_to_reg_kind:         [bac.Node_Datatype]bac.Reg_Kind,
	spill_boundary:               []int,
	cc_table:                     []bac.Call_Conv,
	intern:                       bool,
	no_spec_tables:               bool,
	does_regalloc:                bool,
	has_regalloc_preprocess_hook: bool,
}

class_array :: proc(
	arr: ^[$E]Class_Spec,
	gen_ctors: bool = true,
) -> Class_Array {
	return {E, slice.clone(slice.enumerated_array(arr)), gen_ctors}
}

qualify_type :: proc(qual: string, locals: []typeid, id: typeid) -> string {
	if qual == "" do return fmt.tprintf("%v", id)
	for l in locals {
		if l == id do return fmt.tprintf("%v", id)
	}
	return fmt.tprintf("%v%v", qual, id)
}

qualify_enm :: proc(qual: string, enm: typeid) -> string {
	if enm == bac.Node_Type do return fmt.tprintf("%v%v", qual, enm)
	return fmt.tprintf("%v", enm)
}

generate_spec :: proc(spec_in: Spec_Gen_Input, out_path: string) {
	context.allocator = context.temp_allocator

	spec := spec_in
	q := spec.qual
	locals := spec.local_extra_types

	for classes in spec.classes {
		for &class in classes.ids {
			if class.id == nil do class.id = bac.No_Extra
		}
	}

	file, err := os.open(
		out_path,
		{.Create, .Trunc, .Write},
		os.Permissions_Default - os.Permissions_Execute_All,
	)
	fmt.assertf(err == nil, "%v", err)
	defer os.close(file)

	fmt.fprintf(file, "package %s\n", spec.package_name)
	os.write_string(file, spec.header_import)
	fmt.fprintf(file, "// NOTE: this file is generated: %s", spec.gen_command)
	os.write_string(file, "\n\n")

	Group_Member :: struct {
		class_group: int,
		class:       int,
	}

	groups: map[string]map[Group_Member]struct{}

	inheritable: map[typeid]int

	for classes, j in spec.classes {
		for class, i in classes.ids {
			collect_inheritable(class.id, &inheritable)

			collect_inheritable :: proc(
				id: typeid,
				inheritable: ^map[typeid]int,
			) {
				if id not_in inheritable {
					assert(
						len(inheritable) <
						size_of(bac.Inherit_Table_Elem) * 8,
					)
					inheritable[id] = len(inheritable)
				}

				field := reflect.struct_field_by_name(id, "_")
				if field.is_using {
					assert(field.offset == 0)
					collect_inheritable(field.type.id, inheritable)
				}
			}

			if class.group != "" {
				members := groups[class.group]
				members[Group_Member{j, i}] = {}
				groups[class.group] = members
			}
		}

	}

	fmt.assertf(
		len(inheritable) <= size_of(bac.Inherit_Table_Elem) * 8,
		"too many classes to inherit for this table elem %v",
		len(inheritable),
	)

	if !spec.no_spec_tables {
		fmt.fprintf(file, "SPEC := %vNode_Spec{{\n", q)

		os.write_string(file, "\tcc_table = {\n")
		for c in spec.cc_table {
			fmt.fprintf(file, "\t\t%s,\n", c.name)
		}
		os.write_string(file, "\t},\n")

		os.write_string(file, "\tcall_clobbers = {\n")
		for cc in spec.cc_table {
			clobbers := make([]int, len(cc.caller_saved))

			for &slot, i in clobbers {
				for reg in cc.caller_saved[i] {
					slot |= 1 << reg.index
				}
			}

			fmt.fprintf(file, "\t\t%w,\n", clobbers)
		}
		os.write_string(file, "\t},\n")

		fmt.fprintf(
			file,
			"\tdatatype_to_reg_kind = %w,\n",
			spec.datatype_to_reg_kind,
		)

		fmt.fprintf(file, "\tspill_boundary = %w,\n", spec.spill_boundary)

		if spec.does_regalloc {
			fmt.fprintf(file, "\tcollect_meta = collect_meta,\n")
		}
		if spec.has_regalloc_preprocess_hook {
			fmt.fprintf(file, "\tpre_regalloc_hook = pre_regalloc_hook,\n")
		}
		fmt.fprintf(file, "\temit_function = emit_function,\n")
		fmt.fprintf(file, "\tpeep = peep_inst,\n")
		fmt.fprintf(file, "\tpost_schedule_peep = post_schedule_peep_inst,\n")
		fmt.fprintf(file, "\tintern = %v,\n", spec.intern)

		os.write_string(file, "\tinheritance_table = {\n")
		for classes in spec.classes {
			for class, i in classes.ids {
				inherit_set: bac.Inherit_Table_Elem

				mark_inherits(&inherit_set, class.id, inheritable)

				mark_inherits :: proc(
					slot: ^bac.Inherit_Table_Elem,
					t: typeid,
					inheritable: map[typeid]int,
				) {
					idx := inheritable[t]
					slot^ |= 1 << uint(idx)

					field := reflect.struct_field_by_name(t, "_")
					if field.is_using {
						assert(field.offset == 0)
						mark_inherits(slot, field.type.id, inheritable)
					}
				}

				fmt.fprintf(
					file,
					"\t\t0b%b, // %v\n",
					inherit_set,
					reflect.enum_field_names(classes.enm)[i],
				)
			}
		}
		os.write_string(file, "\t},\n")

		os.write_string(file, "\tnode_extra_sizes = {\n")
		for classes in spec.classes {
			for class, i in classes.ids {
				fmt.fprintf(
					file,
					"\t\t%v, // %v -> %v\n",
					reflect.size_of_typeid(class.id) / 4,
					reflect.enum_field_names(classes.enm)[i],
					class.id,
				)
			}
		}
		os.write_string(file, "\t},\n")

		os.write_string(file, "\tnode_flags = {\n")
		for classes in spec.classes {
			for class, i in classes.ids {
				fmt.fprintf(
					file,
					"\t\t%w, // %v\n",
					class.flags,
					reflect.enum_field_names(classes.enm)[i],
				)
			}
		}
		os.write_string(file, "\t},\n")

		os.write_string(file, "\tnode_extra_types = {\n")
		for classes in spec.classes {
			for class in classes.ids {
				fmt.fprintf(
					file,
					"\t\t%v,\n",
					qualify_type(q, locals, class.id),
				)
			}
		}
		os.write_string(file, "\t},\n")

		os.write_string(file, "\tnode_kind_name = {\n")
		for classes in spec.classes {
			for _, i in classes.ids {
				fmt.fprintf(
					file,
					"\t\t`%v`,\n",
					reflect.enum_field_names(classes.enm)[i],
				)
			}
		}
		os.write_string(file, "\t},\n")

		os.write_string(file, "}\n\n")

	} else {

		for name, members in groups {
			fmt.fprintfln(file, "%v :: enum u16 {{", name)
			for member in members {
				classes := spec.classes[member.class_group]
				class := reflect.enum_fields_zipped(classes.enm)[member.class]
				fmt.fprintfln(
					file,
					"\t%v = u16(%v.%v),",
					class.name,
					qualify_enm(q, classes.enm),
					class.name,
				)
			}
			os.write_string(file, "}\n")
		}
	}

	fmt.fprintfln(file, "Node_Type :: enum u16 {{")
	for classes in spec.classes {
		for field in reflect.enum_fields_zipped(classes.enm) {
			fmt.fprintfln(file, "\t%v,", field.name)
		}
	}
	os.write_string(file, "}\n")

	if !spec.no_spec_tables {
		fmt.fprintfln(
			file,
			`
peep_inst :: proc(ctx: %vPeep_Ctx, node: %vExpanded_Node) -> %vNode_ID {{
	return peep(ctx, node, struct{{}}{{}})
}}
post_schedule_peep_inst :: proc(
	ctx: %vPS_Peep_Ctx, node: %vExpanded_Node) -> %vNode_ID {{
	return post_schedule_peep(ctx, node, struct{{}}{{}})
}}
`,
			q,
			q,
			q,
			q,
			q,
			q,
		)
	}

	if spec.does_regalloc {
		fmt.fprintfln(
			file,
			`
collect_meta :: proc(ctx: ^%vGraph,
	ra: ^%vRegalloc, sched: ^%vGraph_Schedule) -> ([]%vRegalloc_Node_Meta, int) {{

	meta_of_ :: proc(ctx: ^%vGraph, ra: ^%vRegalloc,
		node: %vExpanded_Node) -> %vRegalloc_Node_Meta {{
		return meta_of(ctx, ra, node, struct{{}}{{}})
	}}
	return %vregalloc_collect_meta(ctx, ra, sched, meta_of_)
}}
`,
			q,
			q,
			q,
			q,
			q,
			q,
			q,
			q,
			q,
		)
	}

	for classes in spec.classes {
		for class, i in classes.ids {
			fmt.fprintfln(
				file,
				"#assert(size_of(%v) %% %vPRECISION == 0)",
				qualify_type(q, locals, class.id),
				q,
			)

			if class.no_ctor do continue
			if !classes.gen_ctors do continue

			name := reflect.enum_field_names(classes.enm)[i]

			k, _ := delete_key(&groups, class.group)
			if k != class.group do continue

			pass_lane := k == "Bin_Op" || k == "Un_Op" || class.pass_lane

			fname := name
			if k != "" do fname = k

			fmt.fprintf(
				file,
				"add_%v :: #force_inline proc(graph: ^%vGraph, name: string",
				strings.to_snake_case(fname),
				q,
			)

			if k != "" {
				fmt.fprintf(file, ", type: %v", k)
			}

			if class.default_type == nil {
				fmt.fprintf(file, ", dt: %vNode_Datatype", q)
			}

			for arg in class.args {
				fmt.fprintf(file, ", %v: %vNode_ID", arg, q)
			}

			if class.varargs {
				fmt.fprintf(file, ", inputs: []%vNode_ID", q)
			}

			for earg in class.extra_args {
				field := reflect.struct_field_by_name(class.id, earg)
				if field.type == nil do field.type = type_info_of(u32)
				fmt.fprintf(file, ", %v: %v", earg, field.type)
			}

			if pass_lane {
				fmt.fprintf(file, ", lane: %vLane_Type = {{}}", q)
			}

			fmt.fprintf(file, ") -> (_id: %vNode_ID) {{\n", q)

			extra_type := qualify_type(q, locals, class.id)

			if len(class.extra_args) != 0 {
				fmt.fprintf(
					file,
					"\t(^%v)(%vget_next_extra_slot(graph," +
					" u16(%v.%v), 0))^ = {{\n",
					extra_type,
					q,
					qualify_enm(q, classes.enm),
					name,
				)
				for earg in class.extra_args {
					fmt.fprintf(file, "\t\t%v = %v,\n", earg, earg)
				}
				os.write_string(file, "\t}\n")
			} else if reflect.size_of_typeid(class.id) > 0 {
				fmt.fprintf(
					file,
					"\t(^%v)(%vget_next_extra_slot(graph," +
					" u16(%v.%v), 0))^ = {{}}\n",
					extra_type,
					q,
					qualify_enm(q, classes.enm),
					name,
				)
			}

			if k == "" {
				fmt.fprintf(
					file,
					"\treturn %vadd_raw(graph, name, u16(%v.%v), ",
					q,
					qualify_enm(q, classes.enm),
					name,
				)
			} else {
				fmt.fprintf(
					file,
					"\treturn %vadd_raw(graph, name, u16(type), ",
					q,
				)
			}

			if ty, ok := class.default_type.?; ok {
				fmt.fprintf(file, ".%s", ty)
			} else {
				os.write_string(file, "dt")
			}

			if len(class.args) != 0 {
				os.write_string(file, ", {")

				written_one: bool

				for arg in class.args {
					if written_one do os.write_string(file, ", ")
					written_one = true
					fmt.fprintf(file, "%v", arg)
				}
				os.write_string(file, "}")
			} else if class.varargs {
				os.write_string(file, ", inputs")
			} else {
				os.write_string(file, ", {}")
			}

			pass_meta := class.extra_capacity != 0 || pass_lane

			if pass_meta {
				os.write_string(file, ", {")

				if class.extra_capacity != 0 {
					fmt.fprintf(
						file,
						"extra_capacity = %v,",
						class.extra_capacity,
					)
				}

				if pass_lane {
					os.write_string(file, "lane = lane,")
				}
				os.write_string(file, "}")
			}

			os.write_string(file, ")\n")

			os.write_string(file, "}\n")
		}
	}
	os.write_string(file, "\n")

	os.write_string(
		file,
		"inherit_idx_of :: #force_inline proc($T: typeid) -> u8 {\n",
	)
	os.write_string(file, "\twhen false {}\n")
	for id, idx in inheritable {
		fmt.fprintf(
			file,
			"\telse when T == %v {{return %v}}\n",
			qualify_type(q, locals, id),
			idx,
		)
	}
	os.write_string(
		file,
		"\telse {#panic(`the passed type is not subclass of anything`)}\n",
	)
	os.write_string(file, "}\n")
}

SIMPLE_BINOP_CLASS :: Class_Spec {
	args  = {"lhs", "rhs"},
	group = "Bin_Op",
	flags = {.Comutes, .Interned},
}

Cfg :: bac.Cfg
Tup :: bac.Tup

@(rodata)
IDEAL_CLASSES := [bac.Node_Type]Class_Spec {
	.Start = {id = Cfg, default_type = .Void},
	.Entry = {
		id = Cfg,
		args = {"start"},
		flags = {.Is_Basic_Block_Start},
		default_type = .Void,
	},
	.Poison = {default_type = .Void, flags = {.Interned}},
	// TODO: maybe its better to introduce a flag: Schedule_Early
	.Param = {id = Tup, args = {"entry"}, extra_args = {"idx"}},
	.CInt = {
		id = bac.CInt,
		extra_args = {"value"},
		flags = {.Interned, .Clonable},
	},
	.Add = SIMPLE_BINOP_CLASS,
	.Sub = {args = {"lhs", "rhs"}, group = "Bin_Op", flags = {.Interned}},
	.Mul = SIMPLE_BINOP_CLASS,
	.Eq = SIMPLE_BINOP_CLASS,
	.Ne = SIMPLE_BINOP_CLASS,
	.Le = {args = {"lhs", "rhs"}, group = "Bin_Op", flags = {.Interned}},
	.Lt = {args = {"lhs", "rhs"}, group = "Bin_Op", flags = {.Interned}},
	.Gt = {args = {"lhs", "rhs"}, group = "Bin_Op", flags = {.Interned}},
	.Ge = {args = {"lhs", "rhs"}, group = "Bin_Op", flags = {.Interned}},
	.Div = {args = {"lhs", "rhs"}, group = "Bin_Op", flags = {.Interned}},
	.Rem = {args = {"lhs", "rhs"}, group = "Bin_Op", flags = {.Interned}},
	.And = SIMPLE_BINOP_CLASS,
	.Or = SIMPLE_BINOP_CLASS,
	.Xor = SIMPLE_BINOP_CLASS,
	.And_Not = {args = {"lhs", "rhs"}, group = "Bin_Op", flags = {.Interned}},
	.Neg = {args = {"oprnd"}, group = "Un_Op", flags = {.Interned}},
	.Not = {args = {"oprnd"}, group = "Un_Op", flags = {.Interned}},
	.Sext = {args = {"oprnd"}, group = "Un_Op", flags = {.Interned}},
	.Uext = {args = {"oprnd"}, group = "Un_Op", flags = {.Interned}},
	.Cast = {args = {"oprnd"}, group = "Un_Op", flags = {.Interned}},
	// floating point ops
	.F_Add = {
		args = {"lhs", "rhs"},
		group = "Bin_Op",
		flags = {.Comutes, .Interned},
	},
	.F_Sub = {args = {"lhs", "rhs"}, group = "Bin_Op", flags = {.Interned}},
	.F_Mul = {
		args = {"lhs", "rhs"},
		group = "Bin_Op",
		flags = {.Comutes, .Interned},
	},
	.F_Div = {args = {"lhs", "rhs"}, group = "Bin_Op", flags = {.Interned}},
	.F_Eq = {
		args = {"lhs", "rhs"},
		group = "Bin_Op",
		flags = {.Comutes, .Interned},
	},
	.F_Ne = {
		args = {"lhs", "rhs"},
		group = "Bin_Op",
		flags = {.Comutes, .Interned},
	},
	.F_Lt = {args = {"lhs", "rhs"}, group = "Bin_Op", flags = {.Interned}},
	.F_Le = {args = {"lhs", "rhs"}, group = "Bin_Op", flags = {.Interned}},
	.F_Gt = {args = {"lhs", "rhs"}, group = "Bin_Op", flags = {.Interned}},
	.F_Ge = {args = {"lhs", "rhs"}, group = "Bin_Op", flags = {.Interned}},
	.F_To_I = {args = {"oprnd"}, group = "Un_Op", flags = {.Interned}},
	.F_From_I = {args = {"oprnd"}, group = "Un_Op", flags = {.Interned}},
	.U_F_From_I = {args = {"oprnd"}, group = "Un_Op", flags = {.Interned}},
	.F_Ext = {args = {"oprnd"}, group = "Un_Op", flags = {.Interned}},
	.F_Demote = {args = {"oprnd"}, group = "Un_Op", flags = {.Interned}},
	.Splat = {args = {"oprnd"}, group = "Un_Op", flags = {.Interned}},
	.Ctz = {args = {"oprnd"}, group = "Un_Op", flags = {.Interned}},
	.Simd_Extract_Lsbs = {
		args = {"oprnd"},
		group = "Un_Op",
		flags = {.Interned},
	},
	.Simd_Reduce_Add_Bisect = {
		args = {"oprnd"},
		group = "Un_Op",
		flags = {.Interned},
	},
	.CV128 = {
		id = bac.CV128,
		extra_args = {"lo", "hi"},
		flags = {.Interned, .Clonable},
	},
	.Shl = {args = {"lhs", "rhs"}, group = "Bin_Op", flags = {.Interned}},
	.Shr = {args = {"lhs", "rhs"}, group = "Bin_Op", flags = {.Interned}},
	.U_Lt = {args = {"lhs", "rhs"}, group = "Bin_Op", flags = {.Interned}},
	.U_Gt = {args = {"lhs", "rhs"}, group = "Bin_Op", flags = {.Interned}},
	.U_Le = {args = {"lhs", "rhs"}, group = "Bin_Op", flags = {.Interned}},
	.U_Ge = {args = {"lhs", "rhs"}, group = "Bin_Op", flags = {.Interned}},
	.U_Div = {args = {"lhs", "rhs"}, group = "Bin_Op", flags = {.Interned}},
	.U_Rem = {args = {"lhs", "rhs"}, group = "Bin_Op", flags = {.Interned}},
	.U_Shr = {args = {"lhs", "rhs"}, group = "Bin_Op", flags = {.Interned}},
	.Sym = {args = {"entry"}, default_type = .Void, flags = {.Immortal}},
	.Mem = {args = {"ctrl"}, default_type = .Void, flags = {.Store}},
	.Root_Mem = {
		args = {"ctrl"},
		default_type = .Void,
		flags = {.Store, .Immortal},
	},
	.Local = {id = bac.Local, args = {"mem"}, default_type = .Void},
	.Local_Addr = {args = {"local"}, default_type = .I64, flags = {.Clonable}},
	.Global = {id = Tup, default_type = .Void},
	.Global_Addr = {
		args = {"global"},
		default_type = .I64,
		flags = {.Clonable, .Interned},
	},
	.Proc_Addr = {
		id = Tup,
		default_type = .I64,
		flags = {.Clonable, .Interned},
		extra_args = {"idx"},
	},
	.Load = {args = {"ctrl", "mem", "addr"}, flags = {.Interned, .Load}},
	.Store = {
		args = {"ctrl", "mem", "addr", "value"},
		default_type = .Void,
		flags = {.Store},
	},
	.Copy = {
		args = {"ctrl", "mem", "dst", "src", "size"},
		default_type = .Void,
		flags = {.Store},
	},
	.Set = {
		args = {"ctrl", "mem", "dst", "value", "size"},
		default_type = .Void,
		flags = {.Store},
	},
	.Split = {args = {"dest"}},
	.Phi = {args = {"reg", "lhs", "rhs"}, flags = {.Interned}},
	.If = {id = Cfg, args = {"ctrl", "cond"}, default_type = .Void},
	.Then = {
		id = Cfg,
		args = {"ctrl"},
		default_type = .Void,
		flags = {.Is_Basic_Block_Start},
	},
	.Else = {
		id = Cfg,
		args = {"ctrl"},
		default_type = .Void,
		flags = {.Is_Basic_Block_Start},
	},
	.Jump = {id = Cfg, args = {"ctrl"}, default_type = .Void},
	.Region = {
		id = Cfg,
		varargs = true,
		default_type = .Void,
		flags = {.Is_Basic_Block_Start},
	},
	.Dead = {id = Cfg, default_type = .Void},
	.Loop = {
		id = Cfg,
		args = {"ctrl"},
		default_type = .Void,
		flags = {.Is_Basic_Block_Start},
		extra_capacity = 1,
	},
	.Always = {id = Cfg, args = {"ctrl"}, default_type = .Void},
	.Trap = {id = Cfg, args = {"ctrl"}, default_type = .Void},
	.Call = {
		id = bac.Call,
		varargs = true,
		default_type = .Void,
		extra_args = {"cid"},
	},
	.Call_End = {
		id = Cfg,
		args = {"call"},
		flags = {.Is_Basic_Block_Start},
		default_type = .Void,
	},
	.Ret = {id = Tup, args = {"call_end"}, extra_args = {"idx"}},
	.Return = {
		id = Cfg,
		varargs = true,
		default_type = .Void,
		flags = {.Immortal},
	},
}

main :: proc() {
	generate_spec(
		Spec_Gen_Input {
			package_name = "bac",
			classes = {class_array(&IDEAL_CLASSES)},
			no_spec_tables = true,
		},
		"bac/node_specs.odin",
	)
}

Class_Spec :: struct {
	id:             typeid,
	args:           []string,
	extra_args:     []string,
	group:          string,
	varargs:        bool,
	default_type:   Maybe(bac.Node_Datatype),
	flags:          bac.Class_Flags,
	extra_capacity: int,
	no_ctor:        bool,
	pass_lane:      bool,
}
