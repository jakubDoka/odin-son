package backend

import "base:runtime"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:reflect"
import "core:slice"
import "core:strings"

GEN_SPEC :: #config(GEN_SPEC, false)

COMMAND :: "odin run backend -define:GEN_SPEC=true"

@(rodata)
IDEAL_CLASSES := [Ideal_Node_Type]Class_Spec {
	.Start = {id = Cfg_Extra, default_type = .Void},
	.Entry = {
		id = Cfg_Extra,
		args = {"start"},
		flags = {.Is_Basic_Block_Start},
		default_type = .Void,
	},
	.CInt = {
		id = CInt,
		extra_args = {"value"},
		no_ctrl = true,
		flags = {.Interned},
	},
	.Add = {
		id = No_Extra,
		args = {"lhs", "rhs"},
		no_ctrl = true,
		flags = {.Comutes, .Interned},
	},
	.Sub = {id = No_Extra, args = {"lhs", "rhs"}, no_ctrl = true},
	.Mul = {
		id = No_Extra,
		args = {"lhs", "rhs"},
		no_ctrl = true,
		flags = {.Comutes, .Interned},
	},
	.Eq = {
		id = No_Extra,
		args = {"lhs", "rhs"},
		no_ctrl = true,
		flags = {.Comutes, .Interned},
	},
	.Ne = {
		id = No_Extra,
		args = {"lhs", "rhs"},
		no_ctrl = true,
		flags = {.Comutes, .Interned},
	},
	.Split = {id = No_Extra, args = {"dest"}, no_ctrl = true},
	.Phi = {
		id = No_Extra,
		args = {"reg", "lhs", "rhs"},
		no_ctrl = true,
		flags = {.Interned},
	},
	.If = {id = Cfg_Extra, args = {"ctrl", "cond"}, default_type = .Void},
	.Then = {
		id = Cfg_Extra,
		args = {"ctrl"},
		default_type = .Void,
		flags = {.Is_Basic_Block_Start},
	},
	.Else = {
		id = Cfg_Extra,
		args = {"ctrl"},
		default_type = .Void,
		flags = {.Is_Basic_Block_Start},
	},
	.Jump = {id = Cfg_Extra, args = {"ctrl"}, default_type = .Void},
	.Region = {
		id = Region,
		args = {"rcfg", "lcfg"},
		default_type = .Void,
		flags = {.Is_Basic_Block_Start},
	},
	.Loop = {
		id = Cfg_Extra,
		args = {"ctrl"},
		default_type = .Void,
		flags = {.Is_Basic_Block_Start},
		extra_capacity = 1,
	},
	.Return = {
		id = Cfg_Extra,
		varargs = true,
		default_type = .Void,
		flags = {.Immortal},
	},
}

@(rodata)
IDEAL_REG_CLASSES := [Ideal_Node_Type]Reg_Class_Spec{}

@(rodata)
BUILDER_REG_CLASSES := [Builder_Node_Type]Reg_Class_Spec{}

Inherit_Table_Elem :: u8
Mask_Intern_Key :: u8

Class_Array :: struct {
	enm:  typeid,
	ids:  []Class_Spec,
	regs: []Reg_Class_Spec,
}

Class_Spec :: struct {
	id:             typeid,
	args:           []string,
	extra_args:     []string,
	varargs:        bool,
	default_type:   Maybe(Node_Datatype),
	flags:          Class_Flags,
	no_ctrl:        bool,
	extra_capacity: int,
}

Reg_Class_Spec :: struct {
	inplace_slot_idx: Maybe(int),
	input_start_idx:  int,
	reg_masks:        [Reg_Kind][][]int,
}

Ideal_Node_Type :: enum u16 {
	Start,
	Entry,
	CInt,
	Add,
	Sub,
	Mul,
	Eq,
	Ne,
	Split,
	Phi,
	If,
	Then,
	Else,
	Jump,
	Region,
	Loop,
	Return,
}

when (#load("node_specs.odin", string) or_else "") == "" {
	@(rodata)
	SPECS := [Node_Spec_Name]Node_Spec{}

	Builder_Node_Type :: enum u16 {
		Scope,
		Lazy_Phi,
	}

	X64_Node_Type :: enum u16 {}

	@(rodata)
	BUILDER_CLASSES := [Builder_Node_Type]Class_Spec {
		.Scope = {
			id = Scope,
			args = {"cfg"},
			default_type = .Void,
			no_ctrl = true,
		},
		.Lazy_Phi = {
			id = No_Extra,
			args = {"reg", "lhs"},
			no_ctrl = true,
			extra_capacity = 1,
		},
	}

	@(rodata)
	X64_CLASSES := [X64_Node_Type]Class_Spec{}

	inherit_idx_of :: proc($T: typeid) -> u8 {return 0}

	graph_add_split :: proc(
		graph: ^Graph,
		name: string,
		dt: Node_Datatype,
		src: Node_ID,
	) -> Node_ID {return 0}

	graph_add_region :: proc(
		graph: ^Graph,
		name: string,
		lctrl: Node_ID,
		rctrl: Node_ID,
	) -> Node_ID {return 0}

	graph_add_phi :: proc(
		graph: ^Graph,
		name: string,
		dt: Node_Datatype,
		region: Node_ID,
		lhs: Node_ID,
		rhs: Node_ID,
	) -> Node_ID {return 0}

	graph_add_jump :: proc(
		graph: ^Graph,
		name: string,
		ctrl: Node_ID,
	) -> Node_ID {return 0}

	graph_add_lazyPhi :: proc(
		graph: ^Graph,
		name: string,
		dt: Node_Datatype,
		region: Node_ID,
		lhs: Node_ID,
	) -> Node_ID {return 0}

	when !GEN_SPEC {
		#panic("Missing generated files, run `" + COMMAND + "`")
	}
} else {
	@(rodata)
	BUILDER_CLASSES := [Builder_Node_Type]Class_Spec{}
	@(rodata)
	X64_CLASSES := [X64_Node_Type]Class_Spec{}
}

when GEN_SPEC {
	main :: proc() {
		generate_specs()
	}
}

generate_specs :: proc() {
	_ = SPECS

	context.allocator = context.temp_allocator

	Codegen_Spec :: struct {
		name:                 Node_Spec_Name,
		classes:              []Class_Array,
		datatype_to_reg_kind: [Node_Datatype]Reg_Kind,
	}

	ts :: proc(arr: ^[$E]typeid, regalloc: ^[E]Reg_Class_Spec) -> Class_Array {
		return {
			E,
			slice.enumerated_array(arr),
			slice.enumerated_array(regalloc),
		}
	}

	specs := [?]Codegen_Spec {
		{
			name = .Builder,
			classes = {
				ts(&IDEAL_CLASSES, &IDEAL_REG_CLASSES),
				ts(&BUILDER_CLASSES, &BUILDER_REG_CLASSES),
			},
		},
		{
			name = .X64,
			classes = {
				ts(&IDEAL_CLASSES, &X64_IDEAL_REG_CLASSES),
				ts(&X64_CLASSES, &X64_REG_CLASSES),
			},
			datatype_to_reg_kind = {.Void = .General, .I8 ..= .I64 = .General},
		},
	}

	file, err := os.open("backend/node_specs.odin", {.Create, .Trunc, .Write})
	fmt.assertf(err == nil, "%v", err)
	defer os.close(file)

	os.write_string(file, "package backend\n")
	os.write_string(file, "// NOTE: this file is generated: " + COMMAND)
	os.write_string(file, "\n\n")
	os.write_string(file, "when !GEN_SPEC {\n")

	global_inheritable: map[typeid]int
	inherits: map[typeid]Inherit_Table_Elem

	os.write_string(file, "SPECS := [Node_Spec_Name]Node_Spec{\n")
	for spec in specs {
		fmt.fprintf(file, "\t.%v = {{\n", spec.name)

		reg_mask_lengths: [Reg_Kind]int
		// NOTE: the string here is really a view of []int
		interned_reg_masks: map[string]int
		inheritable: map[typeid]int

		interned_reg_masks[""] = 0

		mask_key :: proc(masks: []int) -> string {
			return string(mem.slice_data_cast([]u8, masks))
		}

		key_mask :: proc(masks: string) -> []int {
			return mem.slice_data_cast([]int, transmute([]u8)masks)
		}

		for classes in spec.classes {
			for class, i in classes.ids {
				if class.id not_in inheritable {
					assert(len(inheritable) < 8)
					inheritable[class.id] = len(inheritable)
				}
			}

			for rclass, i in classes.regs {
				for masks, kind in rclass.reg_masks {
					for mask in masks {
						reg_mask_lengths[kind] = max(
							reg_mask_lengths[kind],
							len(mask),
						)
					}
				}
			}
		}

		for classes in spec.classes {
			for rclass, i in classes.regs {
				for masks, kind in rclass.reg_masks {
					for mask in masks {
						full_mask := make([]int, reg_mask_lengths[kind])
						copy(full_mask, mask)

						if mask_key(full_mask) not_in interned_reg_masks {
							interned_reg_masks[mask_key(full_mask)] = len(
								interned_reg_masks,
							)
						}
					}
				}
			}
		}

		assert(len(interned_reg_masks) <= 1 << size_of(Mask_Intern_Key) * 8)

		fmt.assertf(
			len(inheritable) <= size_of(Inherit_Table_Elem) * 8,
			"too many classes to inherit for this table elem %v",
			len(inheritable),
		)

		fmt.fprintf(file, "\t\tclass_lengths = %w,\n", reg_mask_lengths)
		fmt.fprintf(
			file,
			"\t\tdatatype_to_reg_kind = %w,\n",
			spec.datatype_to_reg_kind,
		)

		interned_reg_masks_arr := make([][]int, len(interned_reg_masks))
		for mask, idx in interned_reg_masks {
			interned_reg_masks_arr[idx] = key_mask(mask)
		}

		os.write_string(file, "\t\tinterned_reg_masks = {\n")
		for masks in interned_reg_masks_arr {
			fmt.fprintf(file, "\t\t\traw_data(%T{{", masks)
			for mask, i in masks {
				if i != 0 do os.write_string(file, ", ")
				fmt.fprintf(file, "0x%x", uint(mask))
			}
			os.write_string(file, "}),\n")
		}
		os.write_string(file, "\t\t},\n")

		os.write_string(file, "\t\treg_masks = {\n")
		for classes in spec.classes {
			for class, i in classes.regs {
				mx := 0
				for masks in class.reg_masks {
					mx = max(mx, len(masks))
				}

				final := make([][Reg_Kind]Mask_Intern_Key, mx)

				for masks, kind in class.reg_masks {
					for mask, i in masks {
						full_mask := make([]int, reg_mask_lengths[kind])
						copy(full_mask, mask)

						final[i][kind] = Mask_Intern_Key(
							interned_reg_masks[mask_key(full_mask)] or_else -1,
						)
					}
				}

				fmt.fprintf(
					file,
					"\t\t\t%w, // %v\n",
					final,
					reflect.enum_field_names(classes.enm)[i],
				)
			}
		}
		os.write_string(file, "\t\t},\n")

		os.write_string(file, "\t\tinplace_slot_idxs = {\n")
		for classes in spec.classes {
			for class, i in classes.regs {
				fmt.fprintf(
					file,
					"\t\t\t%v, //%v\n",
					class.inplace_slot_idx.? or_else -1,
					reflect.enum_field_names(classes.enm)[i],
				)
			}
		}
		os.write_string(file, "\t\t},\n")

		if reg_mask_lengths != {} {
			prefix := strings.to_snake_case(
				reflect.enum_name_from_value(spec.name) or_else panic(""),
			)
			fmt.fprintf(file, "\t\treg_mask_of = %v_reg_mask_of,\n", prefix)
			fmt.fprintf(
				file,
				"\t\temit_function = %v_emit_function,\n",
				prefix,
			)
		}

		os.write_string(file, "\t\tfirst_input_idxs = {\n")
		for classes in spec.classes {
			for class, i in classes.regs {
				fmt.fprintf(
					file,
					"\t\t\t%v, //%v\n",
					class.input_start_idx,
					reflect.enum_field_names(classes.enm)[i],
				)
			}
		}
		os.write_string(file, "\t\t},\n")

		os.write_string(file, "\t\tinheritance_table = {\n")
		for classes in spec.classes {
			for class, i in classes.ids {
				inherit_set: Inherit_Table_Elem

				mark_inherits(&inherit_set, class.id, inheritable)

				mark_inherits :: proc(
					slot: ^Inherit_Table_Elem,
					t: typeid,
					inheritable: map[typeid]int,
				) {
					idx := inheritable[t]
					slot^ |= 1 << uint(idx)

					field := reflect.struct_field_by_name(t, "base")
					if field.is_using {
						assert(field.offset == 0)
						mark_inherits(slot, field.type.id, inheritable)
					}
				}

				fmt.fprintf(
					file,
					"\t\t\t0b%b, // %v\n",
					inherit_set,
					reflect.enum_field_names(classes.enm)[i],
				)
				inherits[class.id] = inherit_set
			}
		}
		os.write_string(file, "\t\t},\n")

		os.write_string(file, "\t\tnode_extra_sizes = {\n")
		for classes in spec.classes {
			for class, i in classes.ids {
				fmt.fprintf(
					file,
					"\t\t\t%v, // %v -> %v\n",
					reflect.size_of_typeid(class.id) / 4,
					reflect.enum_field_names(classes.enm)[i],
					class.id,
				)
			}
		}
		os.write_string(file, "\t\t},\n")

		os.write_string(file, "\t\tnode_flags = {\n")
		for classes in spec.classes {
			for class, i in classes.ids {
				fmt.fprintf(
					file,
					"\t\t\t%w, // %v\n",
					class.flags,
					reflect.enum_field_names(classes.enm)[i],
				)
			}
		}
		os.write_string(file, "\t\t},\n")

		os.write_string(file, "\t\tnode_extra_types = {\n")
		for classes in spec.classes {
			for class, i in classes.ids {
				fmt.fprintf(file, "\t\t\t%v,\n", class.id)
			}
		}
		os.write_string(file, "\t\t},\n")

		os.write_string(file, "\t\tnode_kind_name = {\n")
		for classes in spec.classes {
			for class, i in classes.ids {
				fmt.fprintf(
					file,
					"\t\t\t`%v`,\n",
					reflect.enum_field_names(classes.enm)[i],
				)
			}
		}
		os.write_string(file, "\t\t},\n")

		fmt.fprintf(file, "\t}},\n")

		for id, idx in inheritable {
			oidx, ok := global_inheritable[id]
			assert(!ok || oidx == idx)
			global_inheritable[id] = idx
		}
	}
	os.write_string(file, "}\n")

	os.write_string(file, "\n")

	Seen_Key :: struct {
		enm:   typeid,
		value: int,
	}

	seen: map[Seen_Key]struct{}

	for spec in specs {
		prefix := reflect.enum_name_from_value(spec.name) or_else panic("")
		fmt.fprintfln(file, "%v_Node_Type :: enum u16 {{\n", prefix)
		for classes in spec.classes {
			for field in reflect.enum_fields_zipped(classes.enm) {
				fmt.fprintfln(file, "%v,", field.name)
			}
		}
		os.write_string(file, "}\n")

		for classes in spec.classes {
			for class, i in classes.ids {
				if _, seen := seen[{classes.enm, i}]; seen do continue
				seen[{classes.enm, i}] = {}

				fmt.fprintfln(
					file,
					"#assert(size_of(%v) %% %v == 0)",
					class.id,
					PRECISION,
				)

				no_ctrl := class.no_ctrl
				auto_no_ctrl_classes := [?]typeid{Cfg_Extra}
				for cc in auto_no_ctrl_classes {
					no_ctrl |=
						inherits[class.id] &
							(1 << uint(global_inheritable[cc])) !=
						0
				}

				name := reflect.enum_field_names(classes.enm)[i]
				fmt.fprintf(
					file,
					"graph_add_%v :: #force_inline proc(graph: ^Graph, name: string",
					strings.to_camel_case(name),
				)

				if class.default_type == nil {
					os.write_string(file, ", dt: Node_Datatype")
				}

				for arg in class.args {
					fmt.fprintf(file, ", %v: Node_ID", arg)
				}

				if class.varargs {
					os.write_string(file, ", inputs: []Node_ID")
				}

				for earg in class.extra_args {
					field := reflect.struct_field_by_name(class.id, earg)
					fmt.fprintf(file, ", %v: %v", earg, field.type)
				}

				os.write_string(file, ") -> (id: Node_ID) {\n")

				os.write_string(file, "\tpush_node_name(graph, name)\n")

				if len(class.extra_args) != 0 {
					fmt.fprintf(
						file,
						"\textra := (^%v)(graph_get_next_extra_slot(graph," +
						" u16(%v.%v)))\n",
						class.id,
						classes.enm,
						name,
					)
					for earg in class.extra_args {
						field := reflect.struct_field_by_name(class.id, earg)
						fmt.fprintf(file, "\textra.%v = %v\n", earg, earg)
					}
				}

				fmt.fprintf(
					file,
					"\treturn graph_add_raw(graph," + " u16(%v.%v), ",
					classes.enm,
					name,
				)

				if ty, ok := class.default_type.?; ok {
					fmt.fprintf(file, ".%s", ty)
				} else {
					os.write_string(file, "dt")
				}

				if len(class.args) != 0 {
					os.write_string(file, ", {")

					written_one: bool
					if !no_ctrl {
						os.write_string(file, "0")
						written_one = true
					}

					for arg, i in class.args {
						if written_one do os.write_string(file, ", ")
						written_one = true
						fmt.fprintf(file, "%v", arg)
					}
					os.write_string(file, "}")
				} else if class.varargs {
					os.write_string(file, ", inputs")
				} else if !no_ctrl {
					os.write_string(file, ", {0}")
				} else {
					os.write_string(file, ", {}")
				}

				if class.extra_capacity != 0 {
					fmt.fprintf(
						file,
						", extra_capacity = %v",
						class.extra_capacity,
					)
				}

				os.write_string(file, ")\n")

				os.write_string(file, "}\n")
			}
		}
	}
	os.write_string(file, "\n")

	os.write_string(
		file,
		"inherit_idx_of :: #force_inline proc($T: typeid) -> u8 {\n",
	)
	os.write_string(file, "\twhen false {}\n")
	for id, idx in global_inheritable {
		fmt.fprintf(file, "\telse when T == %v {{return %v}}\n", id, idx)
	}
	os.write_string(
		file,
		"\telse {#panic(`the passed type is not subclass of anything`)}\n",
	)
	os.write_string(file, "}\n")

	os.write_string(file, "}\n")
}
