#+build !wasm32
package backend

import "core:fmt"
import "core:mem"
import "core:os"
import "core:reflect"
import "core:slice"
import "core:strings"

generate_specs :: proc() {
	_ = SPECS

	context.allocator = context.temp_allocator

	Codegen_Spec :: struct {
		name:                 Node_Spec_Name,
		classes:              []Class_Array,
		datatype_to_reg_kind: [Node_Datatype]Reg_Kind,
		reg_bias:             int,
	}

	ts :: proc(
		arr: ^[$E]Class_Spec,
		regalloc: ^[E]Reg_Class_Spec,
	) -> Class_Array {
		return {
			E,
			slice.clone(slice.enumerated_array(arr)),
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
			reg_bias = X64_REG_BIAS,
			classes = {
				ts(&IDEAL_CLASSES, &X64_IDEAL_REG_CLASSES),
				ts(&X64_CLASSES, &X64_REG_CLASSES),
			},
			datatype_to_reg_kind = {.Void = .General, .I8 ..= .I64 = .General},
		},
	}

	for spec in specs {
		for classes in spec.classes {
			for &class in classes.ids {
				if class.id == nil do class.id = No_Extra
			}
		}
	}

	file, err := os.open("backend/node_specs.odin", {.Create, .Trunc, .Write})
	fmt.assertf(err == nil, "%v", err)
	defer os.close(file)

	os.write_string(file, "package backend\n")
	os.write_string(file, "// NOTE: this file is generated: " + COMMAND)
	os.write_string(file, "\n\n")
	os.write_string(file, "when !GEN_SPEC {\n")

	Group_Member :: struct {
		class_group: int,
		class:       int,
	}

	Group :: struct {
		spec:    ^Codegen_Spec,
		members: map[Group_Member]struct{},
	}

	global_inheritable: map[typeid]int
	inherits: map[typeid]Inherit_Table_Elem
	groups: map[string]Group

	os.write_string(file, "SPECS := [Node_Spec_Name]Node_Spec{\n")
	for &spec in specs {
		prefix := strings.to_snake_case(
			reflect.enum_name_from_value(spec.name) or_else panic(""),
		)

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

		for classes, j in spec.classes {
			for class, i in classes.ids {
				collect_inheritable(class.id, &inheritable)

				collect_inheritable :: proc(
					id: typeid,
					inheritable: ^map[typeid]int,
				) {
					if id not_in inheritable {
						assert(
							len(inheritable) < size_of(Inherit_Table_Elem) * 8,
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
					g := groups[class.group]
					g.spec = &spec
					g.members[Group_Member{j, i}] = {}
					groups[class.group] = g
				}
			}

			for rclass in classes.regs {
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
			for rclass in classes.regs {
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
		fmt.fprintf(file, "\t\treg_bias = %v,\n", spec.reg_bias)

		os.write_string(file, "\t\tclobbers = {\n")
		for classes in spec.classes {
			for class, i in classes.regs {
				fmt.fprintfln(
					file,
					"\t\t\t%w, // %v",
					class.clobbers,
					reflect.enum_field_names(classes.enm)[i],
				)
			}
		}
		os.write_string(file, "\t\t},\n")

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
					for mask, j in masks {
						full_mask := make([]int, reg_mask_lengths[kind])
						copy(full_mask, mask)

						final[j][kind] = Mask_Intern_Key(
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
					class.inplace_slot_idx.? or_else -16,
					reflect.enum_field_names(classes.enm)[i],
				)
			}
		}
		os.write_string(file, "\t\t},\n")

		if reg_mask_lengths != {} {
			fmt.fprintf(file, "\t\treg_mask_of = %v_reg_mask_of,\n", prefix)
			fmt.fprintf(
				file,
				"\t\temit_function = %v_emit_function,\n",
				prefix,
			)
		}
		fmt.fprintf(file, "\t\tpeep = %v_peep,\n", prefix)
		fmt.fprintf(
			file,
			"\t\tpost_schedule_peep = %v_post_schedule_peep,\n",
			prefix,
		)

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

					field := reflect.struct_field_by_name(t, "_")
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
			for class in classes.ids {
				fmt.fprintf(file, "\t\t\t%v,\n", class.id)
			}
		}
		os.write_string(file, "\t\t},\n")

		os.write_string(file, "\t\tnode_kind_name = {\n")
		for classes in spec.classes {
			for _, i in classes.ids {
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

	for name, group in groups {
		fmt.fprintfln(file, "%v :: enum u16 {{", name)
		for member in group.members {
			classes := group.spec.classes[member.class_group]
			class := reflect.enum_fields_zipped(classes.enm)[member.class]
			fmt.fprintfln(
				file,
				"\t%v = u16(%v.%v),",
				class.name,
				classes.enm,
				class.name,
			)
		}
		os.write_string(file, "}\n")
	}

	for spec in specs {
		prefix := reflect.enum_name_from_value(spec.name) or_else panic("")
		fmt.fprintfln(file, "%v_Node_Type :: enum u16 {{", prefix)
		for classes in spec.classes {
			for field in reflect.enum_fields_zipped(classes.enm) {
				fmt.fprintfln(file, "\t%v,", field.name)
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

				if class.no_ctor do continue

				name := reflect.enum_field_names(classes.enm)[i]

				k, _ := delete_key(&groups, class.group)
				if k != class.group do continue

				fname := name
				if k != "" do fname = k

				fmt.fprintf(
					file,
					"graph_add_%v :: #force_inline proc(graph: ^Graph, name: string",
					strings.to_snake_case(fname),
				)

				if k != "" {
					fmt.fprintf(file, ", type: %v", k)
				}

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
						"\t(^%v)(graph_get_next_extra_slot(graph," +
						" u16(%v.%v)))^ = {{\n",
						class.id,
						classes.enm,
						name,
					)
					for earg in class.extra_args {
						fmt.fprintf(file, "\t\t%v = %v\n", earg, earg)
					}
					os.write_string(file, "\t}\n")
				} else if reflect.size_of_typeid(class.id) > 0 {
					fmt.fprintf(
						file,
						"\t(^%v)(graph_get_next_extra_slot(graph," +
						" u16(%v.%v)))^ = {{}}\n",
						class.id,
						classes.enm,
						name,
					)
				}

				if k == "" {
					fmt.fprintf(
						file,
						"\treturn graph_add_raw(graph, u16(%v.%v), ",
						classes.enm,
						name,
					)
				} else {
					os.write_string(
						file,
						"\treturn graph_add_raw(graph, u16(type), ",
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
