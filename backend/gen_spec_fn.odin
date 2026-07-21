#+build !wasm32
package backend

import "core:fmt"
import "core:mem"
import "core:os"
import "core:reflect"
import "core:slice"
import "core:strings"

Spec_Gen_Input :: struct {
	package_name:         string,
	gen_command:          string,
	header_import:        string,
	qual:                 string,
	local_extra_types:    []typeid,
	name:                 string,
	classes:              []Class_Array,
	datatype_to_reg_kind: [Node_Datatype]Reg_Kind,
	cc_table:             []Call_Conv,
	intern:               bool,
	no_spec_tables:       bool,
}

class_array :: proc(
	arr: ^[$E]Class_Spec,
	regalloc: ^[E]Reg_Class_Spec,
	gen_ctors: bool = true,
) -> Class_Array {
	return {
		E,
		slice.clone(slice.enumerated_array(arr)),
		slice.enumerated_array(regalloc),
		gen_ctors,
	}
}

qualify_type :: proc(qual: string, locals: []typeid, id: typeid) -> string {
	if qual == "" do return fmt.tprintf("%v", id)
	for l in locals {
		if l == id do return fmt.tprintf("%v", id)
	}
	return fmt.tprintf("%v%v", qual, id)
}

qualify_enm :: proc(qual: string, enm: typeid) -> string {
	if enm == Ideal_Node_Type do return fmt.tprintf("%v%v", qual, enm)
	return fmt.tprintf("%v", enm)
}

generate_spec :: proc(spec_in: Spec_Gen_Input, out_path: string) {
	context.allocator = context.temp_allocator

	spec := spec_in
	q := spec.qual
	locals := spec.local_extra_types

	for classes in spec.classes {
		for &class in classes.ids {
			if class.id == nil do class.id = No_Extra
		}
	}

	file, err := os.open(out_path, {.Create, .Trunc, .Write})
	fmt.assertf(err == nil, "%v", err)
	defer os.close(file)

	fmt.fprintf(file, "package %s\n", spec.package_name)
	os.write_string(file, spec.header_import)
	fmt.fprintf(file, "// NOTE: this file is generated: %s", spec.gen_command)
	os.write_string(file, "\n\n")
	os.write_string(file, "when !GEN_SPEC {\n")

	Group_Member :: struct {
		class_group: int,
		class:       int,
	}

	groups: map[string]map[Group_Member]struct{}

	reg_mask_lengths: [Reg_Kind]int
	// NOTE: the string here is really a view of []int
	interned_reg_masks: map[string]int
	inheritable: map[typeid]int

	interned_reg_masks[""] = 0

	mask_key :: proc(masks: []i64) -> string {
		return string(mem.slice_data_cast([]u8, masks))
	}

	key_mask :: proc(masks: string) -> []i64 {
		return mem.slice_data_cast([]i64, transmute([]u8)masks)
	}

	prefix := strings.to_snake_case(spec.name)

	for classes, j in spec.classes {
		for class, i in classes.ids {
			collect_inheritable(class.id, &inheritable)

			collect_inheritable :: proc(
				id: typeid,
				inheritable: ^map[typeid]int,
			) {
				if id not_in inheritable {
					assert(len(inheritable) < size_of(Inherit_Table_Elem) * 8)
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
					full_mask := make([]i64, reg_mask_lengths[kind])
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

	if !spec.no_spec_tables {
		fmt.fprintf(file, "SPEC := %vNode_Spec{{\n", q)

		os.write_string(file, "\tcc_table = {\n")
		for c in spec.cc_table {
			fmt.fprintf(file, "\t\t%s,\n", c.name)
		}
		os.write_string(file, "\t},\n")

		os.write_string(file, "\tcall_clobbers = {\n")
		for cc in spec.cc_table {
			clobbers: [Reg_Kind]int

			for &slot, kind in clobbers {
				for reg in cc.caller_saved[kind] {
					slot |= 1 << reg.index
				}
			}

			fmt.fprintf(file, "\t\t%w,\n", clobbers)
		}
		os.write_string(file, "\t},\n")

		fmt.fprintf(file, "\tclass_lengths = %w,\n", reg_mask_lengths)
		fmt.fprintf(
			file,
			"\tdatatype_to_reg_kind = %w,\n",
			spec.datatype_to_reg_kind,
		)

		os.write_string(file, "\tclobbers = {\n")
		for classes in spec.classes {
			for class, i in classes.regs {
				fmt.fprintfln(
					file,
					"\t\t%w, // %v",
					class.clobbers,
					reflect.enum_field_names(classes.enm)[i],
				)
			}
		}
		os.write_string(file, "\t},\n")

		interned_reg_masks_arr := make([][]i64, len(interned_reg_masks))
		for mask, idx in interned_reg_masks {
			interned_reg_masks_arr[idx] = key_mask(mask)
		}

		os.write_string(file, "\tinterned_reg_masks = {\n")
		for masks in interned_reg_masks_arr {
			fmt.fprintf(file, "\t\traw_data(%T{{", masks)
			for mask, i in masks {
				if i != 0 do os.write_string(file, ", ")
				fmt.fprintf(file, "0x%x", uint(mask))
			}
			os.write_string(file, "}),\n")
		}
		os.write_string(file, "\t},\n")

		os.write_string(file, "\treg_masks = {\n")
		for classes in spec.classes {
			for class, i in classes.regs {
				mx := 0
				for masks in class.reg_masks {
					mx = max(mx, len(masks))
				}

				final := make([][Reg_Kind]Mask_Intern_Key, mx)

				for masks, kind in class.reg_masks {
					for mask, j in masks {
						full_mask := make([]i64, reg_mask_lengths[kind])
						copy(full_mask, mask)

						final[j][kind] = Mask_Intern_Key(
							interned_reg_masks[mask_key(full_mask)] or_else -1,
						)
					}
				}

				fmt.fprintf(
					file,
					"\t\t%w, // %v\n",
					final,
					reflect.enum_field_names(classes.enm)[i],
				)
			}
		}
		os.write_string(file, "\t},\n")

		os.write_string(file, "\tinplace_slot_idxs = {\n")
		for classes in spec.classes {
			for class, i in classes.regs {
				fmt.fprintf(
					file,
					"\t\t%v, //%v\n",
					class.inplace_slot_idx.? or_else -16,
					reflect.enum_field_names(classes.enm)[i],
				)
			}
		}
		os.write_string(file, "\t},\n")

		if reg_mask_lengths != {} {
			fmt.fprintf(file, "\treg_mask_of = %v_reg_mask_of,\n", prefix)
			fmt.fprintf(file, "\temit_function = %v_emit_function,\n", prefix)
		}
		fmt.fprintf(file, "\tpeep = %v_peep_inst,\n", prefix)
		fmt.fprintf(
			file,
			"\tpost_schedule_peep = %v_post_schedule_peep_inst,\n",
			prefix,
		)
		fmt.fprintf(file, "\tintern = %v,\n", spec.intern)

		os.write_string(file, "\tfirst_input_idxs = {\n")
		for classes in spec.classes {
			for class, i in classes.regs {
				fmt.fprintf(
					file,
					"\t\t%v, //%v\n",
					class.input_start_idx,
					reflect.enum_field_names(classes.enm)[i],
				)
			}
		}
		os.write_string(file, "\t},\n")

		os.write_string(file, "\tinheritance_table = {\n")
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

	fmt.fprintfln(file, "%v_Node_Type :: enum u16 {{", spec.name)
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
%v_peep_inst :: proc(ctx: %vPeep_Ctx, node: %vExpanded_Node) -> %vNode_ID {{
	return %v_peep(ctx, node, struct{{}}{{}})
}}
%v_post_schedule_peep_inst :: proc(
	ctx: %vPS_Peep_Ctx, node: %vExpanded_Node) -> %vNode_ID {{
	return %v_post_schedule_peep(ctx, node, struct{{}}{{}})
}}
`,
			prefix,
			q,
			q,
			q,
			prefix,
			prefix,
			q,
			q,
			q,
			prefix,
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

			fname := name
			if k != "" do fname = k

			fmt.fprintf(
				file,
				"graph_add_%v :: #force_inline proc(graph: ^%vGraph, name: string",
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

			fmt.fprintf(file, ") -> (id: %vNode_ID) {{\n", q)

			fmt.fprintf(file, "\t%vpush_node_name(graph, name)\n", q)

			extra_type := qualify_type(q, locals, class.id)

			if len(class.extra_args) != 0 {
				fmt.fprintf(
					file,
					"\t(^%v)(%vgraph_get_next_extra_slot(graph," +
					" u16(%v.%v)))^ = {{\n",
					extra_type,
					q,
					qualify_enm(q, classes.enm),
					name,
				)
				for earg in class.extra_args {
					fmt.fprintf(file, "\t\t%v = %v\n", earg, earg)
				}
				os.write_string(file, "\t}\n")
			} else if reflect.size_of_typeid(class.id) > 0 {
				fmt.fprintf(
					file,
					"\t(^%v)(%vgraph_get_next_extra_slot(graph," +
					" u16(%v.%v)))^ = {{}}\n",
					extra_type,
					q,
					qualify_enm(q, classes.enm),
					name,
				)
			}

			if k == "" {
				fmt.fprintf(
					file,
					"\treturn %vgraph_add_raw(graph, u16(%v.%v), ",
					q,
					qualify_enm(q, classes.enm),
					name,
				)
			} else {
				fmt.fprintf(
					file,
					"\treturn %vgraph_add_raw(graph, u16(type), ",
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

	os.write_string(file, "}\n")
}
