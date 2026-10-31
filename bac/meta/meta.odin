package bac_meta

import ".."
import "core:fmt"
import "core:odin/ast"
import "core:odin/parser"
import "core:odin/tokenizer"
import "core:os"
import "core:reflect"
import "core:slice"
import "core:strings"
import "core:unicode"

Mask_Intern_Key :: u8

Class_Array :: struct {
	enm:       typeid,
	ids:       []Class_Spec,
	gen_ctors: bool,
}

Common_Reg_Spec :: struct {
	name:  string,
	kind:  bac.Reg_Kind,
	masks: []i64,
}

Spec_Gen_Input :: struct {
	gen_command:          string,
	header_import:        []string,
	classes:              []Class_Array,
	datatype_to_reg_kind: [bac.Node_Datatype]bac.Reg_Kind,
	spill_boundary:       []int,
	cc_table:             []bac.Call_Conv,
	no_spec_tables:       bool,
	common_reg_specs:     []Common_Reg_Spec,
}

class_array :: proc(
	arr: ^[$E]Class_Spec,
	gen_ctors: bool = true,
) -> Class_Array {
	return {E, slice.clone(slice.enumerated_array(arr)), gen_ctors}
}

qualify_type :: proc(qual: string, pack: string, id: typeid) -> string {
	if qual == "" do return fmt.tprintf("%v", id)
	if pack == type_info_of(id).variant.(reflect.Type_Info_Named).pkg {
		return fmt.tprintf("%v", id)
	}
	return fmt.tprintf("%v%v", qual, id)
}

qualify_enm :: proc(qual: string, enm: typeid) -> string {
	if enm == bac.Node_Type do return fmt.tprintf("%v%v", qual, enm)
	return fmt.tprintf("%v", enm)
}

generate_spec :: proc(
	spec: Spec_Gen_Input,
	package_path: string,
	loc := #caller_location,
) {
	@(static) m: map[typeid]fmt.User_Formatter
	@(static) once := false
	if !once {
		fmt.set_user_formatters(&m)
		once = true
	}

	context.allocator = context.temp_allocator

	pack, ok := parser.collect_package(package_path)
	assert(ok)
	ok = parser.parse_package(pack)
	assert(ok)

	spec := spec
	qual := pack.name == "bac" ? "" : "bac."
	packname := pack.name

	for classes in spec.classes {
		for &class in classes.ids {
			if class.id == nil do class.id = bac.No_Extra
		}
	}

	pckg, _ := os.join_path({package_path, "node_specs.odin"}, context.allocator)

	file, err := os.open(
		pckg,
		{.Create, .Trunc, .Write},
		os.Permissions_Default - os.Permissions_Execute_All,
	)
	fmt.assertf(err == nil, "%v", err)
	defer os.close(file)

	fmt.fprintf(file, "package %s\n", pack.name)
	for h in spec.header_import {
		fmt.fprintfln(file, h)
	}
	if !spec.no_spec_tables {
		os.write_string(file, `import "base:intrinsics"`)
	}
	fmt.fprintf(file, "// NOTE: this file is generated, see: %v", loc)
	os.write_string(file, "\n\n")

	Group_Member :: struct {
		class_group: int,
		class:       int,
	}

	groups: map[string]map[Group_Member]struct{}

	inheritable: map[typeid]int

	Opt_Fn :: enum i64 {
		collect_meta,
		sccp_compute,
		pre_regalloc_hook,
	}

	OPT_FN_TRIGGERS := [len(Opt_Fn)]string {
		"meta_of",
		"sccp_compute",
		"pre_regalloc_hook",
	}

	active_opt_fns: bit_set[Opt_Fn;i64]

	for fn, i in reflect.enum_fields_zipped(Opt_Fn) {
		for name, ofile in pack.files {
			for decl in ofile.decls {
				dcl := decl.derived.(^ast.Value_Decl) or_continue
				for name in dcl.names {
					if name.derived.(^ast.Ident).name == OPT_FN_TRIGGERS[i] {
						(^i64)(&active_opt_fns)^ |= 1 << uint(i)
					}
				}
			}
		}
	}

	for classes, j in spec.classes {
		for class, i in classes.ids {
			collect_inheritable(class.id, &inheritable)

			collect_inheritable :: proc(id: typeid, inheritable: ^map[typeid]int) {
				if id not_in inheritable {
					assert(len(inheritable) < size_of(bac.Inherit_Table_Elem) * 8)
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

		fmt.fprintf(
			file,
			"@(tag = \"api\", rodata, export, link_name = \"%v_SPEC\")",
			pack.name,
		)
		fmt.fprintf(file, "SPEC := %vNode_Spec{{\n", qual)

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

		for fn in active_opt_fns {
			vl := reflect.enum_name_from_value(fn) or_else panic("")
			fmt.fprintfln(file, "\t%v = %v,", vl, vl)
		}

		fmt.fprintf(file, "\temit_function = emit_function,\n")
		fmt.fprintf(file, "\tpeep = peep_inst,\n")
		fmt.fprintf(file, "\tpost_schedule_peep = post_schedule_peep_inst,\n")
	}

	start := int(!spec.no_spec_tables)

	if spec.no_spec_tables {
		os.write_string(file, "INHERITANCE_TABLE :: []u16{")
	} else {
		os.write_string(
			file,
			"\tinheritance_table =" +
			" intrinsics.concatenate(bac.INHERITANCE_TABLE, []u16{\n",
		)
	}

	for classes in spec.classes[start:] {
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

	if spec.no_spec_tables {
		os.write_string(file, "}\n")
	} else {
		os.write_string(file, "\t}),\n")
	}

	if spec.no_spec_tables {
		os.write_string(file, "NODE_EXTRA_SIZES :: []u8{")
	} else {
		os.write_string(
			file,
			"\tnode_extra_sizes =" +
			" intrinsics.concatenate(bac.NODE_EXTRA_SIZES, []u8{\n",
		)
	}

	idx := 0
	last_idx := 0
	for classes in spec.classes[start:] {
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

	if spec.no_spec_tables {
		os.write_string(file, "}\n")
	} else {
		os.write_string(file, "\t}),\n")
	}

	if spec.no_spec_tables {
		os.write_string(file, "\tNODE_FLAGS :: []Class_Flags{\n")
	} else {
		os.write_string(
			file,
			"\tnode_flags =" +
			" intrinsics.concatenate(bac.NODE_FLAGS, []bac.Class_Flags{\n",
		)
	}

	for classes in spec.classes[start:] {
		for class, i in classes.ids {
			fmt.fprintf(
				file,
				"\t\t%w, // %v\n",
				class.flags,
				reflect.enum_field_names(classes.enm)[i],
			)
		}
	}

	if spec.no_spec_tables {
		os.write_string(file, "}\n")
	} else {
		os.write_string(file, "\t}),\n")
	}

	if spec.no_spec_tables {
		os.write_string(file, "\tNODE_EXTRA_TYPES :: []typeid{\n")
	} else {
		os.write_string(
			file,
			"\tnode_extra_types = ({}) when #config(NO_FMT, false) else (" +
			"intrinsics.concatenate(bac.NODE_EXTRA_TYPES, []typeid{\n",
		)
	}

	for classes in spec.classes[start:] {
		for class in classes.ids {
			fmt.fprintf(file, "\t\t%v,\n", qualify_type(qual, packname, class.id))
		}
	}

	if spec.no_spec_tables {
		os.write_string(file, "}\n")
	} else {
		os.write_string(file, "\t})),\n")
	}

	if !spec.no_spec_tables {
		os.write_string(
			file,
			"\tnode_kind = nil when #config(NO_FMT, false) else Node_Type,\n",
		)

		os.write_string(file, "}\n\n")
	} else {
		Group :: struct {
			name:    string,
			members: [dynamic]Group_Member,
		}

		sorted_groups: [dynamic]Group

		for name, members in groups {
			group_members: [dynamic]Group_Member
			for member in members {
				append(&group_members, member)
			}
			slice.sort_by_key(
				group_members[:],
				proc(m: Group_Member) -> i128 {return transmute(i128)m},
			)
			append(&sorted_groups, Group{name, group_members})
		}

		slice.sort_by_key(
			sorted_groups[:][:],
			proc(m: Group) -> string {return m.name},
		)

		for group in sorted_groups {
			fmt.fprintfln(file, "%v :: enum u16 {{", group.name)
			for member in group.members {
				classes := spec.classes[member.class_group]
				class := reflect.enum_fields_zipped(classes.enm)[member.class]
				fmt.fprintfln(
					file,
					"\t%v = u16(%v.%v),",
					class.name,
					qualify_enm(qual, classes.enm),
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
peep_inst :: proc(ctx: %vPeep_Ctx, node: %vExpanded_Node) -> Maybe(%vNode_ID) {{
	res := peep(ctx, node, struct{{}}{{}})
	#assert(type_of(res) == Maybe(%vNode_ID))
	return res
}}
post_schedule_peep_inst :: proc(
	ctx: %vPS_Peep_Ctx, node: %vExpanded_Node) -> %vNode_ID {{
	return post_schedule_peep(ctx, node, struct{{}}{{}})
}}
`,
			qual,
			qual,
			qual,
			qual,
			qual,
			qual,
			qual,
		)
	}

	if .collect_meta in active_opt_fns {
		fmt.fprintfln(
			file,
			`
collect_meta :: proc(ctx: ^%vProc,
	ra: ^%vRegalloc, sched: ^%vSchedule) -> ([]%vRegalloc_Node_Meta, int) {{

	meta_of_ :: proc(ctx: ^%vProc, ra: ^%vRegalloc,
		node: %vExpanded_Node) -> %vRegalloc_Node_Meta {{
		return meta_of(ctx, ra, node, struct{{}}{{}})
	}}
	return %vregalloc_collect_meta(ctx, ra, sched, meta_of_)
}}
`,
			qual,
			qual,
			qual,
			qual,
			qual,
			qual,
			qual,
			qual,
			qual,
		)
	}

	for classes in spec.classes {
		for class, i in classes.ids {
			if class.no_ctor do continue
			if !classes.gen_ctors do continue

			name := reflect.enum_field_names(classes.enm)[i]

			k, members := delete_key(&groups, class.group)
			if k != class.group do continue

			api := class.api
			for member in members {
				api |= spec.classes[member.class_group].ids[member.class].api
			}
			if api do os.write_string(file, "@(tag = \"api\")\n")

			pass_lane := k == "Bin_Op" || k == "Un_Op" || class.pass_lane

			fname := name
			if k != "" do fname = k

			fmt.fprintf(
				file,
				"add_%v :: #force_inline proc(prc: ^%vProc, name: string",
				strings.to_snake_case(fname),
				qual,
			)

			if k != "" {
				fmt.fprintf(file, ", type: %v", k)
			}

			if class.default_type == nil {
				fmt.fprintf(file, ", dt: %vNode_Datatype", qual)
			}

			for arg in class.args {
				fmt.fprintf(file, ", %v: %vNode_ID", arg, qual)
			}

			if class.varargs {
				fmt.fprintf(file, ", inputs: []%vNode_ID", qual)
			}

			for earg in class.extra_args {
				if earg == "*" {
					fmt.fprintf(file, ", extra: %v", class.id)
				} else {
					field := reflect.struct_field_by_name(class.id, earg)
					if field.type == nil do field.type = type_info_of(u32)
					fmt.fprintf(file, ", %v: %v", earg, field.type)
				}
			}

			if pass_lane {
				fmt.fprintf(file, ", lane: %vLane_Type = {{}}", qual)
			}

			fmt.fprintf(file, ") -> (_id: %vNode_ID) {{\n", qual)

			if len(class.extra_args) == 1 && class.extra_args[0] == "*" {
				os.write_string(file, "\textra := extra\n")
			}

			extra_type := qualify_type(qual, packname, class.id)
			has_extra :=
				len(class.extra_args) != 0 || reflect.size_of_typeid(class.id) > 0

			if k == "" {
				fmt.fprintf(
					file,
					"\treturn %vadd_raw(prc, name, u16(%v.%v), ",
					qual,
					qualify_enm(qual, classes.enm),
					name,
				)
			} else {
				fmt.fprintf(file, "\treturn %vadd_raw(prc, name, u16(type), ", qual)
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

			if len(class.extra_args) == 1 && class.extra_args[0] == "*" {
				os.write_string(file, ", extra = &extra")
			} else if has_extra {
				fmt.fprintfln(file, ", extra = &%v{{", class.id)
				for earg in class.extra_args {
					fmt.fprintf(file, "\t\t%v = %v,\n", earg, earg)
				}
				os.write_string(file, "\t}")
			}

			if pass_meta {
				os.write_string(file, ", meta = {")

				if class.extra_capacity != 0 {
					fmt.fprintf(file, "extra_capacity = %v,", class.extra_capacity)
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

	Inher :: struct {
		type: typeid,
		idx:  int,
	}

	inhers: [dynamic]Inher
	for id, idx in inheritable {
		append(&inhers, Inher{id, idx})
	}

	slice.sort_by_key(
		inhers[:],
		proc(i: Inher) -> string {return fmt.tprint(i.type)},
	)

	os.write_string(
		file,
		"inherit_idx_of :: #force_inline proc($T: typeid) -> u8 {\n",
	)
	os.write_string(file, "\twhen false {}\n")
	for inh in inhers {
		fmt.fprintf(
			file,
			"\telse when T == %v {{return %v}}\n",
			qualify_type(qual, packname, inh.type),
			inh.idx,
		)
	}

	os.write_string(
		file,
		"\telse {#panic(`the passed type is not subclass of anything`)}\n",
	)
	os.write_string(file, "}\n")

	for inh in inhers {
		fmt.fprintfln(
			file,
			"#assert(size_of(%v) %% %vPRECISION == 0)",
			qualify_type(qual, packname, inh.type),
			qual,
		)
	}

	MASK_BUFFER_SIZE :: 6

	intern_idxs: [16]int
	for crs in spec.common_reg_specs {
		fmt.fprintf(file, "\n@(rodata) %v_MASK := [?]i64{{", crs.name)
		for m, i in crs.masks {
			if i != 0 do fmt.fprintf(file, ", ")
			fmt.fprintf(file, "transmute(i64)u64(0x%016x)", uint(m))
		}
		fmt.fprintfln(file, "}}")

		fmt.fprintfln(
			file,
			"%v_MASK_IDX :: bac.%w",
			crs.name,
			bac.RM_Intern_Idx{kind = crs.kind, index = intern_idxs[crs.kind]},
		)
		intern_idxs[crs.kind] += 1

		fmt.fprintfln(
			file,
			"@(rodata) %v_MASKS := [%v]bac.RM_Intern_Idx{{0 ..< %v = %v_MASK_IDX}}",
			crs.name,
			MASK_BUFFER_SIZE,
			MASK_BUFFER_SIZE,
			crs.name,
		)
	}

	if spec.common_reg_specs != nil {
		fmt.fprintfln(file, "\nseed_rm_interner :: proc(ra: ^bac.Regalloc) {{")
		fmt.fprintfln(file, "\tra.mask_len = MASK_SIZE")
		for crs in spec.common_reg_specs {
			fmt.fprintfln(
				file,
				"\tbac.rm_intern_slice(ra, %v, %v_MASK[:])",
				crs.kind,
				crs.name,
			)
		}
		fmt.fprintfln(file, "}}")
	}

	if pack.name != "bac" {
		splits := strings.split(pack.name, "_")
		prefix := splits[len(splits) - 1][:1]

		fmt.fprintf(
			file,
			`
%vtype :: #force_inline proc(node: bac.Expanded_Node) -> Node_Type {{
	return Node_Type(node.rtype)
}}

%vextra :: #force_inline proc(
	prc: ^bac.Proc,
	node: ^bac.Node,
	$T: typeid,
) -> ^T {{
	if prc.inheritance_table[node.rtype] & (1 << inherit_idx_of(T)) == 0 {{
		return nil
	}}
	return (^T)(&node.extra)
}}
`,
			prefix,
			prefix,
		)
	}

	rewrites_path, _ := os.join_path(
		{package_path, "rewrites.rs"},
		context.allocator,
	)

	if file, err := os.read_entire_file(rewrites_path, context.allocator);
	   err == nil {

		Parser :: struct {
			using tok: tokenizer.Tokenizer,
		}

		Stmt :: struct {
			pat:   Node,
			value: Node,
		}

		Set_Range :: struct {
			start, end: string,
		}

		Node :: struct {
			name:      string,
			children:  []Node,
			code:      string,
			enum_name: string,
			set:       []Set_Range,
			comments:  []string,
			at:        bool,
			eof:       bool,
		}

		fmt.register_user_formatter(Set_Range, proc(fi: ^fmt.Info, arg: any, verb: rune) -> bool {
				value := arg.(Set_Range)
				fmt.wprint(fi.writer, value.start)
				if value.start != value.end do fmt.wprint(fi.writer, " to", value.end)
				return true
			})

		fmt.register_user_formatter(Node, proc(fi: ^fmt.Info, arg: any, verb: rune) -> bool {
			fmt.wprint(fi.writer, "{")
			written := false
			for field in reflect.struct_fields_zipped(Node) {
				value := reflect.struct_field_value(arg, field)
				if !reflect.is_nil(value) {
					if written do fmt.wprint(fi.writer, ", ")
					written = true
					fmt.wprintf(fi.writer, "%v = %v", field.name, value)
				}
			}
			fmt.wprint(fi.writer, "}")
			return true
		})

		parser := Parser{}
		tokenizer.init(&parser, string(file), rewrites_path, error_handler)

		stmts: [dynamic]Stmt

		for {
			pat := expr(&parser)
			if pat.eof do break
			expect(&parser, .Colon)
			expect(&parser, .Colon)
			value := expr(&parser)

			fmt.eprintln(pat, "::", value)

			append(&stmts, Stmt{pat, value})
		}

		expr :: proc(parser: ^Parser) -> (res: Node) {
			comments: [dynamic]string

			for peek(parser^).kind == .Comment {
				append(&comments, tokenizer.scan(parser).text)
			}

			at := scan_if(parser, .At)

			tok := tokenizer.scan(parser)

			#partial switch tok.kind {
			case .Ident:
				if unicode.is_upper(rune(tok.text[0])) {
					res.enum_name = tok.text
				} else {
					if scan_if(parser, .Colon) {
						res = expr(parser)
					}
					res.name = tok.text
				}
			case .Open_Paren:
				children: [dynamic]Node
				for {
					append(&children, expr(parser))

					if scan_if(parser, .Close_Paren) do break
					if scan_if(parser, .EOF) do break
				}
				res.children = children[:]
			case .Open_Brace:
				depth := 1
				last_tok: tokenizer.Token
				for depth > 0 {
					last_tok = tokenizer.scan(parser)
					if last_tok.kind == .Open_Brace do depth += 1
					if last_tok.kind == .Close_Brace do depth -= 1
					if last_tok.kind == .EOF do break
				}
				res.code = parser.src[tok.pos.offset + 1:last_tok.pos.offset]
			case .Open_Bracket:
				set: [dynamic]Set_Range
				for {
					start := expect(parser, .Ident)
					end := start
					if scan_if(parser, .Range_Full) do end = expect(parser, .Ident)

					append(&set, Set_Range{start.text, end.text})

					if scan_if(parser, .Close_Bracket) do break
					if scan_if(parser, .EOF) do break
					expect(parser, .Comma)
				}
				res.set = set[:]
			case .EOF:
				res.eof = true
			}

			res.comments = comments[:]
			res.at = at

			return
		}

		expect :: proc(
			parser: ^Parser,
			kind: tokenizer.Token_Kind,
		) -> tokenizer.Token {
			tok := tokenizer.scan(parser)
			if tok.kind != kind {
				error_handler(tok.pos, "expected %v, but got %v", kind, tok.kind)
				parser.error_count += 1
			}
			return tok
		}

		peek :: proc(parser: Parser) -> tokenizer.Token {
			cpy := parser
			return tokenizer.scan(&cpy)
		}

		scan_if :: proc(parser: ^Parser, kind: tokenizer.Token_Kind) -> bool {
			tok := peek(parser^)
			if tok.kind != kind {
				return false
			}

			tokenizer.scan(parser)
			return true
		}

		error_handler :: proc(pos: tokenizer.Pos, msg: string, args: ..any) {
			fmt.eprintf("%s(%d:%d) ", pos.file, pos.line, pos.column)
			fmt.eprintf(msg, ..args)
			fmt.eprintf("\n")
		}
	}
}

SIMPLE_BINOP_CLASS :: Class_Spec {
	args  = {"lhs", "rhs"},
	group = "Bin_Op",
	flags = {.Comutes, .Interned},
	api   = true,
}

Cfg :: bac.Cfg
Tup :: bac.Tup

@(rodata)
IDEAL_CLASSES := [bac.Node_Type]Class_Spec {
	.Nil = {id = Cfg, no_ctor = true},
	.Entry = {id = Cfg, flags = {.Is_Basic_Block_Start}, default_type = .Void},
	.End = {default_type = .Void, varargs = true},
	.Poison = {default_type = .Void, flags = {.Interned}},
	// TODO: maybe its better to introduce a flag: Schedule_Early
	.Param = {id = Tup, args = {"entry"}, extra_args = {"idx"}},
	.Thread_Id = {no_ctor = true, flags = {.Interned}},
	.Lane_Id = {no_ctor = true, flags = {.Interned}},
	.Uniform_Addr = {id = Tup, no_ctor = true, flags = {.Interned}},
	.CInt = {
		id = bac.CInt,
		extra_args = {"value"},
		flags = {.Interned, .Clonable},
		api = true,
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
	.Neg = {args = {"oprnd"}, group = "Un_Op", flags = {.Interned}, api = true},
	.Not = {args = {"oprnd"}, group = "Un_Op", flags = {.Interned}},
	.Cast = {args = {"oprnd"}, group = "Un_Op", flags = {.Interned}},
	.Conv = {args = {"oprnd"}, group = "Un_Op", flags = {.Interned}},
	.U_Conv = {args = {"oprnd"}, group = "Un_Op", flags = {.Interned}},
	.Splat = {args = {"oprnd"}, group = "Un_Op", flags = {.Interned}},
	.Ctz = {args = {"oprnd"}, group = "Un_Op", flags = {.Interned}},
	.Simd_Extract_Lsbs = {
		args = {"oprnd"},
		group = "Un_Op",
		flags = {.Interned},
	},
	.Simd_Extract_Msbs = {
		args = {"oprnd"},
		group = "Un_Op",
		flags = {.Interned},
	},
	.Simd_Reduce_Add_Bisect = {
		args = {"oprnd"},
		group = "Un_Op",
		flags = {.Interned},
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
	.Sym = {args = {"entry"}, default_type = .Void},
	.Mem = {args = {"ctrl"}, default_type = .Mem, flags = {.Store}, api = true},
	.Split_Mem = {args = {"mem"}, default_type = .Mem, flags = {.Store}},
	.Merge_Mem = {default_type = .Mem, varargs = true, flags = {.Store}},
	.Local = {id = bac.Local, args = {"mem"}, default_type = .Void, api = true},
	.Local_Addr = {
		args = {"local"},
		default_type = .I64,
		flags = {.Clonable},
		api = true,
	},
	.Global = {id = Tup, default_type = .Void, api = true, extra_args = {"idx"}},
	.Global_Addr = {
		args = {"global"},
		default_type = .I64,
		flags = {.Clonable, .Interned},
		api = true,
	},
	.Proc_Addr = {
		id = Tup,
		default_type = .I64,
		flags = {.Clonable, .Interned},
		extra_args = {"idx"},
		api = true,
	},
	.Load = {args = {"ctrl", "mem", "addr"}, flags = {.Interned, .Load}},
	.Store = {
		args = {"ctrl", "mem", "addr", "value"},
		default_type = .Mem,
		flags = {.Store},
	},
	.Copy = {
		args = {"ctrl", "mem", "dst", "src", "size"},
		default_type = .Mem,
		flags = {.Store},
		api = true,
	},
	.Set = {
		args = {"ctrl", "mem", "dst", "value", "size"},
		default_type = .Mem,
		flags = {.Store},
		api = true,
	},
	.Split = {args = {"dest"}},
	.Phi = {args = {"reg", "lhs", "rhs"}, flags = {.Interned}},
	.Select = {
		args = {"on_true", "on_false", "condition"},
		flags = {.Interned},
		api = true,
	},
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
	.Loop = {
		id = Cfg,
		args = {"ctrl"},
		default_type = .Void,
		flags = {.Is_Basic_Block_Start},
		extra_capacity = 1,
	},
	.Always = {id = Cfg, default_type = .Void, varargs = true},
	.Trap = {id = Cfg, default_type = .Void, varargs = true, api = true},
	.Call = {
		id = bac.Call,
		varargs = true,
		default_type = .Void,
		extra_args = {"*"},
		api = true,
	},
	.Call_End = {
		id = Cfg,
		args = {"call"},
		flags = {.Is_Basic_Block_Start},
		default_type = .Void,
		api = true,
	},
	.Ret = {id = Tup, args = {"call_end"}, extra_args = {"idx"}, api = true},
	.Return = {id = Cfg, varargs = true, default_type = .Void},
	.Dbg_Sym_Decl = {id = bac.Dbg_Sym, default_type = .Void},
	.Dbg_Sym_Update = {
		default_type = .Void,
		args = {"new_value", "prev_update"},
	},
	.Dbg_Scope = {default_type = .Void, varargs = true},
}

main :: proc() {
	generate_spec(
		Spec_Gen_Input {
			classes = {class_array(&IDEAL_CLASSES)},
			no_spec_tables = true,
		},
		"bac",
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
	api:            bool,
	comment:        string,
}
