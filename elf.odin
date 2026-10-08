package main

import "bac"
import "core:mem"
import "core:slice"
import "typecheck"
import "vendored/gam/util/arna"

LIBCALL_BASE :: bac.RELOC_BIG_CONSTANT_BASE - 32
MEMCPY_ID :: LIBCALL_BASE
MEMSET_ID :: LIBCALL_BASE + 1

emit_elf :: proc(ctx: ^Gen_Ctx, allocator := context.allocator) -> []u8 {
	context.allocator, _ = arna.scrath(allocator)

	// --- .text : concatenate procedure code, 16 byte aligned ------------
	text: [dynamic]u8
	proc_off := make([]int, len(ctx.procs))
	// Each procedure's constant pool (e.g. materialised float immediates) is
	// laid out right after its code; big-constant relocs are resolved against it.
	const_off := make([]int, len(ctx.procs))
	for &prc, i in ctx.procs {
		for len(text) % 16 != 0 do append(&text, 0)
		proc_off[i] = len(text)
		append(&text, ..prc.out.code)
		for len(text) % 8 != 0 do append(&text, 0)
		const_off[i] = len(text)
		append(&text, ..prc.out.constants)
	}

	// --- .data : concatenate globals honouring their alignment ----------
	data: [dynamic]u8
	global_off := make([]int, len(ctx.globals))
	for glob, i in ctx.globals {
		align := max(glob.align, 1)
		for len(data) % align != 0 do append(&data, 0)
		global_off[i] = len(data)
		append(&data, ..glob.bytes)
	}

	// --- symbol + string tables -----------------------------------------
	str: Str_Tab
	append(&str.buf, 0) // index 0 is the empty string

	locals: [dynamic]Elf64_Sym
	globals: [dynamic]Elf64_Sym

	proc_sym := make([]u32, len(ctx.procs))
	data_sym := make([]u32, len(ctx.globals))
	lib_sym: [2]u32
	have_lib: [2]bool

	// helper closures are not available, so track the running symbol index
	// manually: null symbol occupies index 0.
	next_local := u32(1)

	main_index := -1
	for &prc, i in ctx.procs {
		if prc.name == "main" {
			main_index = i
			continue // main is emitted as a global symbol below
		}
		// foreign procedures have no body; they become undefined global
		// symbols the linker resolves against the linked libraries.
		if prc.lit.body == nil do continue
		append(
			&locals,
			Elf64_Sym {
				st_name = strtab_add(&str, prc.name),
				st_info = {bind = .Local, type = .Func},
				st_shndx = .Text,
				st_value = u64(proc_off[i]),
				st_size = u64(len(prc.out.code)),
			},
		)
		proc_sym[i] = next_local
		next_local += 1
	}

	for glob, i in ctx.globals {
		append(
			&locals,
			Elf64_Sym {
				st_name = 0,
				st_info = {bind = .Local, type = .Object},
				st_shndx = .Data,
				st_value = u64(global_off[i]),
				st_size = u64(len(glob.bytes)),
			},
		)
		data_sym[i] = next_local
		next_local += 1
	}

	// section symbols used as relocation targets by the DWARF debug sections
	// (.debug_info references .text/.debug_abbrev/.debug_line by section).
	sec_text_sym := next_local
	sec_abbrev_sym := next_local + 1
	sec_line_sym := next_local + 2
	sec_loc_sym := next_local + 3
	for shndx in ([]Section{.Text, .Debug_Abbrev, .Debug_Line, .Debug_Loc}) {
		append(
			&locals,
			Elf64_Sym {
				st_info = {bind = .Local, type = .Section},
				st_shndx = shndx,
			},
		)
	}
	next_local += 4

	// globals come after every local symbol
	next_global := next_local
	if main_index >= 0 {
		append(
			&globals,
			Elf64_Sym {
				st_name = strtab_add(&str, "main"),
				st_info = {bind = .Global, type = .Func},
				st_shndx = .Text,
				st_value = u64(proc_off[main_index]),
				st_size = u64(len(ctx.procs[main_index].out.code)),
			},
		)
		proc_sym[main_index] = next_global
		next_global += 1
	}

	// foreign procedures: undefined globals resolved at link time
	for &prc, i in ctx.procs {
		if prc.lit.body != nil do continue
		append(
			&globals,
			Elf64_Sym {
				st_name = strtab_add(&str, prc.name),
				st_info = {bind = .Global, type = .Notype},
				st_shndx = .Null,
			},
		)
		proc_sym[i] = next_global
		next_global += 1
	}

	// undefined libc helpers, added lazily if referenced
	lib_names := [2]string{"memcpy", "memset"}
	for &prc in ctx.procs {
		for rel in prc.out.relocs {
			is_libcall :=
				LIBCALL_BASE <= rel.id && rel.id < bac.RELOC_BIG_CONSTANT_BASE
			if !is_libcall do continue
			id := rel.id - LIBCALL_BASE
			if have_lib[id] do continue
			have_lib[id] = true
			append(
				&globals,
				Elf64_Sym {
					st_name = strtab_add(&str, lib_names[id]),
					st_info = {bind = .Global, type = .Notype},
					st_shndx = .Null,
				},
			)
			lib_sym[id] = next_global
			next_global += 1
		}
	}

	// --- relocations + slot fixups --------------------------------------
	rels: [dynamic]Elf64_Rel
	for &prc, i in ctx.procs {
		for rel in prc.out.relocs {
			slot := proc_off[i] + int(rel.offset) - 4

			is_libcall :=
				LIBCALL_BASE <= rel.id && rel.id < bac.RELOC_BIG_CONSTANT_BASE

			// TODO: this is horrible
			// Big-constant relocs point into this proc's own constant pool in
			// .text, so resolve them in place (RIP relative) with no ELF entry.
			if rel.kind == .Global && rel.id >= bac.RELOC_BIG_CONSTANT_BASE {
				target :=
					const_off[i] + int(rel.id - bac.RELOC_BIG_CONSTANT_BASE)
				source := proc_off[i] + int(rel.offset)
				cur := u32(0)
				mem.copy(&cur, &text[slot], 4)
				cur += u32(target - source)
				mem.copy(&text[slot], &cur, 4)
				continue
			}

			sym: u32
			type: Reloc_Type
			switch rel.kind {
			case .Text:
				if is_libcall {
					sym = lib_sym[rel.id - LIBCALL_BASE]
				} else {
					sym = proc_sym[rel.id]
				}
				type = .Pc32
			case .Global:
				sym = data_sym[rel.id]
				type = .Pc32
			case .Got:
				sym = lib_sym[rel.id]
				type = .Gotpcrel
			}

			// bias the in-place addend by the slot->instruction-end delta
			cur := u32(0)
			mem.copy(&cur, &text[slot], 4)
			cur -= 4
			mem.copy(&text[slot], &cur, 4)

			append(
				&rels,
				Elf64_Rel {
					r_offset = u64(slot),
					r_info = {sym = sym, type = type},
				},
			)
		}
	}

	// --- DWARF debug info ------------------------------------------------
	// The simplest possible line info: one compile unit DIE pointing at a
	// .debug_line program that maps each instruction's start address to its
	// (file, line). We use plain advance_pc/advance_line/copy opcodes rather
	// than the packed special opcodes -- larger but trivially correct.
	dbg_abbrev: [dynamic]u8
	dbg_info: [dynamic]u8
	dbg_line: [dynamic]u8
	info_rels: [dynamic]Elf64_Rel
	line_rels: [dynamic]Elf64_Rel

	// -- .debug_abbrev -----------------------------------------------------
	dw_attr :: proc(b: ^[dynamic]u8, at: Dw_At, form: Dw_Form) {
		uleb(b, u64(at))
		uleb(b, u64(form))
	}
	dw_abbrev :: proc(
		b: ^[dynamic]u8,
		code: Dw_Abbrev,
		tag: Dw_Tag,
		children: Dw_Children,
		attrs: [][2]u64,
	) {
		uleb(b, u64(code))
		uleb(b, u64(tag))
		append(b, u8(children))
		for attr in attrs {
			dw_attr(b, Dw_At(attr[0]), Dw_Form(attr[1]))
		}
		uleb(b, 0)
		uleb(b, 0)
	}
	dw_abbrev(
		&dbg_abbrev,
		.Compile_Unit,
		.Compile_Unit,
		.Yes,
		{
			{u64(Dw_At.Producer), u64(Dw_Form.String)},
			{u64(Dw_At.Language), u64(Dw_Form.Data2)},
			{u64(Dw_At.Name), u64(Dw_Form.String)},
			{u64(Dw_At.Comp_Dir), u64(Dw_Form.String)},
			{u64(Dw_At.Low_Pc), u64(Dw_Form.Addr)},
			{u64(Dw_At.High_Pc), u64(Dw_Form.Data8)},
			{u64(Dw_At.Stmt_List), u64(Dw_Form.Sec_Offset)},
		},
	)
	dw_abbrev(
		&dbg_abbrev,
		.Subprogram,
		.Subprogram,
		.Yes,
		{
			{u64(Dw_At.Name), u64(Dw_Form.String)},
			{u64(Dw_At.Low_Pc), u64(Dw_Form.Addr)},
			{u64(Dw_At.High_Pc), u64(Dw_Form.Data8)},
			{u64(Dw_At.Decl_File), u64(Dw_Form.Data4)},
			{u64(Dw_At.Decl_Line), u64(Dw_Form.Data4)},
			{u64(Dw_At.Frame_Base), u64(Dw_Form.Exprloc)},
		},
	)
	for pair in ([][2]u64{
		{u64(Dw_Abbrev.Variable), u64(Dw_Tag.Variable)},
		{u64(Dw_Abbrev.Formal_Parameter), u64(Dw_Tag.Formal_Parameter)},
	}) {
		dw_abbrev(
			&dbg_abbrev,
			Dw_Abbrev(pair[0]),
			Dw_Tag(pair[1]),
			.No,
			{
				{u64(Dw_At.Name), u64(Dw_Form.String)},
				{u64(Dw_At.Type), u64(Dw_Form.Ref4)},
				{u64(Dw_At.Location), u64(Dw_Form.Sec_Offset)},
				{u64(Dw_At.Decl_File), u64(Dw_Form.Data4)},
				{u64(Dw_At.Decl_Line), u64(Dw_Form.Data4)},
			},
		)
	}
	dw_abbrev(
		&dbg_abbrev,
		.Global_Variable,
		.Variable,
		.No,
		{
			{u64(Dw_At.Name), u64(Dw_Form.String)},
			{u64(Dw_At.Type), u64(Dw_Form.Ref4)},
			{u64(Dw_At.Location), u64(Dw_Form.Exprloc)},
			{u64(Dw_At.Decl_File), u64(Dw_Form.Data4)},
			{u64(Dw_At.Decl_Line), u64(Dw_Form.Data4)},
		},
	)
	dw_abbrev(
		&dbg_abbrev,
		.Base_Type,
		.Base_Type,
		.No,
		{
			{u64(Dw_At.Name), u64(Dw_Form.String)},
			{u64(Dw_At.Encoding), u64(Dw_Form.Data1)},
			{u64(Dw_At.Byte_Size), u64(Dw_Form.Data4)},
		},
	)
	dw_abbrev(
		&dbg_abbrev,
		.Pointer_Type,
		.Pointer_Type,
		.No,
		{
			{u64(Dw_At.Type), u64(Dw_Form.Ref4)},
			{u64(Dw_At.Byte_Size), u64(Dw_Form.Data1)},
		},
	)
	for pair in ([][2]u64{
		{u64(Dw_Abbrev.Structure_Type), u64(Dw_Tag.Structure_Type)},
		{u64(Dw_Abbrev.Union_Type), u64(Dw_Tag.Union_Type)},
	}) {
		dw_abbrev(
			&dbg_abbrev,
			Dw_Abbrev(pair[0]),
			Dw_Tag(pair[1]),
			.Yes,
			{
				{u64(Dw_At.Name), u64(Dw_Form.String)},
				{u64(Dw_At.Byte_Size), u64(Dw_Form.Data4)},
			},
		)
	}
	dw_abbrev(
		&dbg_abbrev,
		.Member,
		.Member,
		.No,
		{
			{u64(Dw_At.Name), u64(Dw_Form.String)},
			{u64(Dw_At.Type), u64(Dw_Form.Ref4)},
			{u64(Dw_At.Data_Member_Location), u64(Dw_Form.Udata)},
		},
	)
	dw_abbrev(
		&dbg_abbrev,
		.Array_Type,
		.Array_Type,
		.Yes,
		{{u64(Dw_At.Type), u64(Dw_Form.Ref4)}},
	)
	dw_abbrev(
		&dbg_abbrev,
		.Subrange_Type,
		.Subrange_Type,
		.No,
		{{u64(Dw_At.Count), u64(Dw_Form.Udata)}},
	)
	dw_abbrev(
		&dbg_abbrev,
		.Enumeration_Type,
		.Enumeration_Type,
		.Yes,
		{
			{u64(Dw_At.Name), u64(Dw_Form.String)},
			{u64(Dw_At.Byte_Size), u64(Dw_Form.Data4)},
		},
	)
	dw_abbrev(
		&dbg_abbrev,
		.Enumerator,
		.Enumerator,
		.No,
		{
			{u64(Dw_At.Name), u64(Dw_Form.String)},
			{u64(Dw_At.Const_Value), u64(Dw_Form.Sdata)},
		},
	)
	dw_abbrev(
		&dbg_abbrev,
		.Unspecified_Type,
		.Unspecified_Type,
		.No,
		{{u64(Dw_At.Name), u64(Dw_Form.String)}},
	)
	dw_abbrev(
		&dbg_abbrev,
		.Subroutine_Type,
		.Subroutine_Type,
		.No,
		nil,
	)
	append(&dbg_abbrev, 0)

	// -- .debug_line : header (DWARF v4) ----------------------------------
	line_unit_len_pos := len(dbg_line)
	put_u32(&dbg_line, 0) // unit_length, patched below
	line_prog_base := len(dbg_line)
	put_u16(&dbg_line, 4) // version
	line_hdr_len_pos := len(dbg_line)
	put_u32(&dbg_line, 0) // header_length, patched below
	line_hdr_base := len(dbg_line)
	append(&dbg_line, 1) // minimum_instruction_length
	append(&dbg_line, 1) // maximum_operations_per_instruction
	append(&dbg_line, 1) // default_is_stmt
	append(&dbg_line, DW_LINE_BASE) // line_base (-5 as u8)
	append(&dbg_line, DW_LINE_RANGE) // line_range
	append(&dbg_line, DW_OPCODE_BASE) // opcode_base
	// standard_opcode_lengths for opcodes 1..12
	append(&dbg_line, ..[]u8{0, 1, 1, 1, 1, 0, 0, 0, 1, 0, 0, 1})
	append(&dbg_line, 0) // include_directories: empty list terminator
	// file_names: every loaded file, absolute path, dir_index 0. File_ID i
	// maps to DWARF file index i+1.
	for f in ctx.files {
		append(&dbg_line, f.fullpath)
		append(&dbg_line, 0) // NUL
		uleb(&dbg_line, 0) // dir_index (0 == comp_dir, ignored for abs path)
		uleb(&dbg_line, 0) // mtime
		uleb(&dbg_line, 0) // length
	}
	append(&dbg_line, 0) // file_names list terminator
	patch_u32(&dbg_line, line_hdr_len_pos, u32(len(dbg_line) - line_hdr_base))

	// -- .debug_line : one line-number program per procedure --------------
	for &prc, i in ctx.procs {
		if prc.lit.body == nil do continue
		if len(prc.out.slocs) == 0 do continue

		// DW_LNE_set_address <proc start>, relocated against the proc symbol.
		append(&dbg_line, 0, 9, u8(Dw_Lne.Set_Address))
		append(
			&line_rels,
			Elf64_Rel {
				r_offset = u64(len(dbg_line)),
				r_info = {sym = proc_sym[i], type = .Abs64},
			},
		)
		put_u64(&dbg_line, 0)

		file := u64(prc.file_id) + 1
		append(&dbg_line, u8(Dw_Lns.Set_File))
		uleb(&dbg_line, file)

		prev_off := u32(0)
		prev_line := i64(1)
		cur_off := u32(0)
		for sloc in prc.out.slocs {
			if u64(sloc.file) + 1 != file {
				file = u64(sloc.file) + 1
				append(&dbg_line, u8(Dw_Lns.Set_File))
				uleb(&dbg_line, file)
			}
			if cur_off != prev_off {
				append(&dbg_line, u8(Dw_Lns.Advance_Pc))
				uleb(&dbg_line, u64(cur_off - prev_off))
				prev_off = cur_off
			}
			if i64(sloc.line) != prev_line {
				append(&dbg_line, u8(Dw_Lns.Advance_Line))
				sleb(&dbg_line, i64(sloc.line) - prev_line)
				prev_line = i64(sloc.line)
			}
			append(&dbg_line, u8(Dw_Lns.Copy))
			cur_off += sloc.range
		}

		// advance to the end of the proc and close the sequence
		if cur_off != prev_off {
			append(&dbg_line, u8(Dw_Lns.Advance_Pc))
			uleb(&dbg_line, u64(cur_off - prev_off))
		}
		append(&dbg_line, 0, 1, u8(Dw_Lne.End_Sequence))
	}
	patch_u32(
		&dbg_line,
		line_unit_len_pos,
		u32(len(dbg_line) - line_prog_base),
	)

	// -- .debug_loc --------------------------------------------------------
	Dwarf_Variable :: struct {
		using loc: bac.Var_Loc,
		ranges: [dynamic]bac.Var_Loc,
		loc_offset: u32,
	}
	Proc_Debug :: struct {
		vars: [dynamic]Dwarf_Variable,
	}
	dbg_loc: [dynamic]u8
	loc_rels: [dynamic]Elf64_Rel
	proc_debug := make([]Proc_Debug, len(ctx.procs))

	for &prc, i in ctx.procs {
		indices := make(map[u32]int)
		for loc in prc.out.var_locs {
			if loc.range == 0 do continue
			idx := indices[loc.id] - 1
			if idx < 0 {
				idx = len(proc_debug[i].vars)
				append(&proc_debug[i].vars, Dwarf_Variable{loc = loc})
				indices[loc.id] = idx + 1
			}

			variable := &proc_debug[i].vars[idx]
			if len(variable.ranges) != 0 {
				prev := &variable.ranges[len(variable.ranges) - 1]
				if prev.start + prev.range == loc.start &&
				   prev.kind == loc.kind &&
				   prev.offset == loc.offset &&
				   prev.index == loc.index {
					prev.range += loc.range
					continue
				}
			}
			append(&variable.ranges, loc)
		}

		for &variable in proc_debug[i].vars {
			variable.loc_offset = u32(len(dbg_loc))
			for loc in variable.ranges {
				put_u64(&dbg_loc, u64(proc_off[i]) + u64(loc.start))
				put_u64(
					&dbg_loc,
					u64(proc_off[i]) + u64(loc.start + loc.range),
				)

				#partial switch loc.kind {
				case .Frame:
					expr: [dynamic]u8
					putb(&expr, Dw_Op.Fbreg)
					sleb(&expr, i64(loc.offset))
					put_u16(&dbg_loc, u16(len(expr)))
					append(&dbg_loc, ..expr[:])
				case .Global:
					put_u16(&dbg_loc, 9)
					putb(&dbg_loc, Dw_Op.Addr)
					append(
						&loc_rels,
						Elf64_Rel {
							r_offset = u64(len(dbg_loc)),
							r_info = {sym = data_sym[loc.index], type = .Abs64},
						},
					)
					put_u64(&dbg_loc, u64(i64(loc.offset)))
				}
			}
			put_u64(&dbg_loc, 0)
			put_u64(&dbg_loc, 0)
		}
	}

	// -- .debug_info -------------------------------------------------------
	cu_name := ctx.files[0].fullpath if len(ctx.files) > 0 else ""
	if main_index >= 0 do cu_name = ctx.procs[main_index].file.fullpath

	info_unit_len_pos := len(dbg_info)
	put_u32(&dbg_info, 0) // unit_length, patched below
	info_base := len(dbg_info)
	put_u16(&dbg_info, 4) // version
	// debug_abbrev_offset, relocated against .debug_abbrev
	append(
		&info_rels,
		Elf64_Rel {
			r_offset = u64(len(dbg_info)),
			r_info = {sym = sec_abbrev_sym, type = .Abs32},
		},
	)
	put_u32(&dbg_info, 0)
	append(&dbg_info, 8) // address_size

	uleb(&dbg_info, 1) // abbrev code 1 (compile_unit)
	append(&dbg_info, "odin-jit")
	append(&dbg_info, 0)
	put_u16(&dbg_info, u16(Dw_Lang.C))
	append(&dbg_info, cu_name)
	append(&dbg_info, 0)
	append(&dbg_info, ctx.root)
	append(&dbg_info, 0)
	// low_pc, relocated against .text (base of the code)
	append(
		&info_rels,
		Elf64_Rel {
			r_offset = u64(len(dbg_info)),
			r_info = {sym = sec_text_sym, type = .Abs64},
		},
	)
	put_u64(&dbg_info, 0)
	put_u64(&dbg_info, u64(len(text))) // high_pc (offset form)
	// stmt_list, relocated against .debug_line
	append(
		&info_rels,
		Elf64_Rel {
			r_offset = u64(len(dbg_info)),
			r_info = {sym = sec_line_sym, type = .Abs32},
		},
	)
	put_u32(&dbg_info, 0)

	Dwarf_Type_Fixup :: struct {
		at: int,
		type: Type,
	}
	Dwarf_Type_State :: struct {
		offsets: map[Type]u32,
		fixups: [dynamic]Dwarf_Type_Fixup,
	}
	dw_type_ref :: proc(
		b: ^[dynamic]u8,
		state: ^Dwarf_Type_State,
		type: Type,
	) {
		if offset, ok := state.offsets[type]; ok {
			put_u32(b, offset)
			return
		}
		append(&state.fixups, Dwarf_Type_Fixup{len(b), type})
		put_u32(b, 0)
	}
	dw_member :: proc(
		b: ^[dynamic]u8,
		state: ^Dwarf_Type_State,
		name: string,
		type: Type,
		offset: int,
	) {
		uleb(b, u64(Dw_Abbrev.Member))
		append(b, name)
		append(b, 0)
		dw_type_ref(b, state, type)
		uleb(b, u64(offset))
	}
	emit_dwarf_type :: proc(
		b: ^[dynamic]u8,
		state: ^Dwarf_Type_State,
		type: Type,
	) {
		if _, ok := state.offsets[type]; ok do return
		state.offsets[type] = u32(len(b))

		#partial switch t in unpack_type(type) {
		case typecheck.Void_Type, typecheck.Invalid_Type:
			uleb(b, u64(Dw_Abbrev.Unspecified_Type))
			append(b, "void")
			append(b, 0)
		case typecheck.Pointer:
			uleb(b, u64(Dw_Abbrev.Pointer_Type))
			dw_type_ref(b, state, (^Type)(t)^)
			append(b, 8)
		case typecheck.Multi_Pointer:
			uleb(b, u64(Dw_Abbrev.Pointer_Type))
			dw_type_ref(b, state, (^Type)(t)^)
			append(b, 8)
		case ^typecheck.Proc_Type:
			uleb(b, u64(Dw_Abbrev.Pointer_Type))
			dw_type_ref(b, state, .Void)
			append(b, 8)
		case ^typecheck.Struct:
			uleb(b, u64(Dw_Abbrev.Structure_Type))
			append(b, "struct")
			append(b, 0)
			put_u32(b, u32(t.size))
			for field in t.fields {
				dw_member(b, state, field.name, field.ty, field.offset)
			}
			append(b, 0)
		case ^typecheck.Array:
			uleb(b, u64(Dw_Abbrev.Array_Type))
			dw_type_ref(b, state, t.elem)
			uleb(b, u64(Dw_Abbrev.Subrange_Type))
			uleb(b, u64(t.len))
			append(b, 0)
		case ^typecheck.Slice:
			uleb(b, u64(Dw_Abbrev.Structure_Type))
			append(b, "slice")
			append(b, 0)
			put_u32(b, 16)
			dw_member(b, state, "data", .Rawptr, 0)
			dw_member(b, state, "len", .Int, 8)
			append(b, 0)
		case ^typecheck.Enum:
			uleb(b, u64(Dw_Abbrev.Enumeration_Type))
			append(b, "enum")
			append(b, 0)
			put_u32(b, u32(type_size(type)))
			for variant in t.variants {
				uleb(b, u64(Dw_Abbrev.Enumerator))
				append(b, variant.name)
				append(b, 0)
				sleb(b, variant.value)
			}
			append(b, 0)
		case ^typecheck.Union:
			uleb(b, u64(Dw_Abbrev.Union_Type))
			append(b, "union")
			append(b, 0)
			put_u32(b, u32(t.size))
			for variant in t.variants {
				dw_member(b, state, "value", variant, 0)
			}
			dw_member(b, state, "tag", t.tag_ty, t.tag_offset)
			append(b, 0)
		case ^typecheck.Simd:
			uleb(b, u64(Dw_Abbrev.Array_Type))
			dw_type_ref(b, state, t.elem)
			uleb(b, u64(Dw_Abbrev.Subrange_Type))
			uleb(b, u64(t.len))
			append(b, 0)
		case typecheck.String_Type:
			uleb(b, u64(Dw_Abbrev.Structure_Type))
			append(b, "string")
			append(b, 0)
			put_u32(b, 16)
			dw_member(b, state, "data", .Rawptr, 0)
			dw_member(b, state, "len", .Int, 8)
			append(b, 0)
		case:
			norm := Type(u16(type))
			encoding := Dw_Ate.Unsigned
			if norm == .Bool {
				encoding = .Boolean
			} else if norm in typecheck.SIGNED_TYPES {
				encoding = .Signed
			} else if norm in typecheck.FLOAT_TYPES {
				encoding = .Float
			} else if norm == .Rawptr {
				encoding = .Address
			}
			uleb(b, u64(Dw_Abbrev.Base_Type))
			append(b, typecheck.TYPE_NAMES[norm])
			append(b, 0)
			append(b, u8(encoding))
			put_u32(b, u32(type_size(type)))
		}
	}

	type_state: Dwarf_Type_State
	type_state.offsets = make(map[Type]u32)
	for variable in ctx.global_vars {
		emit_dwarf_type(&dbg_info, &type_state, variable.type)
	}
	for proc_dbg in proc_debug {
		for variable in proc_dbg.vars {
			emit_dwarf_type(
				&dbg_info,
				&type_state,
				transmute(Type)variable.type,
			)
		}
	}
	for cursor := 0; cursor < len(type_state.fixups); cursor += 1 {
		fixup := type_state.fixups[cursor]
		emit_dwarf_type(&dbg_info, &type_state, fixup.type)
		patch_u32(&dbg_info, fixup.at, type_state.offsets[fixup.type])
	}

	for variable in ctx.global_vars {
		uleb(&dbg_info, u64(Dw_Abbrev.Global_Variable))
		append(&dbg_info, variable.name)
		append(&dbg_info, 0)
		put_u32(&dbg_info, type_state.offsets[variable.type])
		uleb(&dbg_info, 9)
		putb(&dbg_info, Dw_Op.Addr)
		append(
			&info_rels,
			Elf64_Rel {
				r_offset = u64(len(dbg_info)),
				r_info = {sym = data_sym[variable.idx], type = .Abs64},
			},
		)
		put_u64(&dbg_info, 0)
		put_u32(&dbg_info, u32(variable.file) + 1)
		put_u32(&dbg_info, u32(variable.init.pos.line))
	}

	for &prc, i in ctx.procs {
		if prc.lit.body == nil do continue
		uleb(&dbg_info, u64(Dw_Abbrev.Subprogram))
		append(&dbg_info, prc.name)
		append(&dbg_info, 0)
		append(
			&info_rels,
			Elf64_Rel {
				r_offset = u64(len(dbg_info)),
				r_info = {sym = proc_sym[i], type = .Abs64},
			},
		)
		put_u64(&dbg_info, 0)
		put_u64(&dbg_info, u64(len(prc.out.code)))
		put_u32(&dbg_info, u32(prc.file_id) + 1)
		put_u32(&dbg_info, u32(prc.lit.pos.line))
		uleb(&dbg_info, 1)
		putb(&dbg_info, Dw_Op.Call_Frame_Cfa)

		for variable in proc_debug[i].vars {
			abbrev := variable.is_param ? Dw_Abbrev.Formal_Parameter :
				Dw_Abbrev.Variable
			uleb(&dbg_info, u64(abbrev))
			append(&dbg_info, variable.name)
			append(&dbg_info, 0)
			put_u32(
				&dbg_info,
				type_state.offsets[transmute(Type)variable.type],
			)
			append(
				&info_rels,
				Elf64_Rel {
					r_offset = u64(len(dbg_info)),
					r_info = {sym = sec_loc_sym, type = .Abs32},
				},
			)
			put_u32(&dbg_info, variable.loc_offset)
			put_u32(&dbg_info, u32(variable.decl.file) + 1)
			put_u32(&dbg_info, variable.decl.line)
		}
		append(&dbg_info, 0)
	}
	append(&dbg_info, 0)
	patch_u32(&dbg_info, info_unit_len_pos, u32(len(dbg_info) - info_base))

	// --- .eh_frame --------------------------------------------------------
	// The generated code keeps no frame pointer (rbp is an allocatable GPR),
	// so an unwinder has nothing to walk without explicit CFI. One CIE plus
	// one FDE per procedure, built from the frame deltas the bac recorded.
	eh_frame: [dynamic]u8
	eh_rels: [dynamic]Elf64_Rel

	if ctx.has_dbg {
		spec := ctx.target.cc.cfi_spec

		cie_len_pos := len(eh_frame)
		put_u32(&eh_frame, 0)
		cie_base := len(eh_frame)
		put_u32(&eh_frame, 0) // CIE_id
		append(&eh_frame, 1) // version
		append(&eh_frame, "zR")
		append(&eh_frame, 0)
		uleb(&eh_frame, u64(spec.code_align))
		sleb(&eh_frame, i64(spec.data_align))
		uleb(&eh_frame, u64(spec.return_addr_reg))
		uleb(&eh_frame, 1) // augmentation data length
		putb(&eh_frame, Dw_Eh_Pe{rel = .Pcrel, format = .Sdata4})
		putb(&eh_frame, Dw_Cfa.Def_Cfa)
		uleb(&eh_frame, u64(spec.cfa_reg))
		uleb(&eh_frame, u64(spec.initial_cfa_offset))
		putb(&eh_frame, Dw_Cfa_Op{op = .Offset, arg = spec.return_addr_reg})
		uleb(&eh_frame, u64(spec.initial_cfa_offset) / u64(-spec.data_align))
		for len(eh_frame) % 8 != 0 do putb(&eh_frame, Dw_Cfa.Nop)
		patch_u32(&eh_frame, cie_len_pos, u32(len(eh_frame) - cie_base))

		for &prc, i in ctx.procs {
			if prc.lit.body == nil do continue

			fde_len_pos := len(eh_frame)
			put_u32(&eh_frame, 0)
			fde_base := len(eh_frame)
			// distance back to the CIE, which starts at offset 0
			put_u32(&eh_frame, u32(len(eh_frame) - cie_len_pos))
			// initial_location: pcrel, so the addend is 0 and S - P is exactly
			// the displacement we want the slot to hold.
			append(
				&eh_rels,
				Elf64_Rel {
					r_offset = u64(len(eh_frame)),
					r_info = {sym = proc_sym[i], type = .Pc32},
				},
			)
			put_u32(&eh_frame, 0)
			put_u32(&eh_frame, u32(len(prc.out.code))) // address_range
			uleb(&eh_frame, 0) // augmentation data length

			cur := u32(0)
			for op in prc.out.cfi {
				// an advance past the end of the procedure would take the row
				// outside the FDE's range
				if op.offset >= u32(len(prc.out.code)) do continue

				if op.offset > cur {
					delta := (op.offset - cur) / spec.code_align
					switch {
					case delta < 64:
						putb(
							&eh_frame,
							Dw_Cfa_Op{op = .Advance_Loc, arg = u8(delta)},
						)
					case delta < 0x100:
						append(&eh_frame, u8(Dw_Cfa.Advance_Loc1), u8(delta))
					case delta < 0x10000:
						putb(&eh_frame, Dw_Cfa.Advance_Loc2)
						put_u16(&eh_frame, u16(delta))
					case:
						putb(&eh_frame, Dw_Cfa.Advance_Loc4)
						put_u32(&eh_frame, delta)
					}
					cur = op.offset
				}

				switch op.kind {
				case .Def_Cfa_Offset:
					putb(&eh_frame, Dw_Cfa.Def_Cfa_Offset)
					uleb(&eh_frame, u64(op.arg))
				case .Save_Reg:
					putb(&eh_frame, Dw_Cfa_Op{op = .Offset, arg = op.reg})
					uleb(&eh_frame, u64(op.arg) / u64(-spec.data_align))
				case .Restore_Reg:
					putb(&eh_frame, Dw_Cfa_Op{op = .Restore, arg = op.reg})
				case .Remember_State:
					putb(&eh_frame, Dw_Cfa.Remember_State)
				case .Restore_State:
					putb(&eh_frame, Dw_Cfa.Restore_State)
				}
			}

			for len(eh_frame) % 8 != 0 do putb(&eh_frame, Dw_Cfa.Nop)
			patch_u32(&eh_frame, fde_len_pos, u32(len(eh_frame) - fde_base))
		}

		put_u32(&eh_frame, 0) // terminator
	}

	// combine local then global symbols; first global index is sh_info
	symtab: [dynamic]Elf64_Sym
	append(&symtab, Elf64_Sym{}) // null symbol
	append(&symtab, ..locals[:])
	append(&symtab, ..globals[:])
	first_global := u32(1 + len(locals))

	// --- section header string table ------------------------------------
	shstr: Str_Tab
	append(&shstr.buf, 0)
	name_text := strtab_add(&shstr, ".text")
	name_reltext := strtab_add(&shstr, ".rel.text")
	name_data := strtab_add(&shstr, ".data")
	name_dbg_abbrev := strtab_add(&shstr, ".debug_abbrev")
	name_dbg_info := strtab_add(&shstr, ".debug_info")
	name_rel_dbg_info := strtab_add(&shstr, ".rel.debug_info")
	name_dbg_line := strtab_add(&shstr, ".debug_line")
	name_rel_dbg_line := strtab_add(&shstr, ".rel.debug_line")
	name_dbg_loc := strtab_add(&shstr, ".debug_loc")
	name_rel_dbg_loc := strtab_add(&shstr, ".rel.debug_loc")
	name_eh_frame := strtab_add(&shstr, ".eh_frame")
	name_rel_eh_frame := strtab_add(&shstr, ".rel.eh_frame")
	name_symtab := strtab_add(&shstr, ".symtab")
	name_strtab := strtab_add(&shstr, ".strtab")
	name_shstrtab := strtab_add(&shstr, ".shstrtab")

	// --- assemble the file ----------------------------------------------
	b: Elf_Builder

	// header placeholder, patched at the end
	eb_struct(&b, Elf64_Ehdr{})

	eb_align(&b, 16)
	text_off := eb_bytes(&b, text[:])

	eb_align(&b, 8)
	data_off := eb_bytes(&b, data[:])

	eb_align(&b, 8)
	rel_off := len(b.buf)
	for r in rels do eb_struct(&b, r)

	dbg_abbrev_off := eb_bytes(&b, dbg_abbrev[:])
	dbg_info_off := eb_bytes(&b, dbg_info[:])

	eb_align(&b, 8)
	rel_dbg_info_off := len(b.buf)
	for r in info_rels do eb_struct(&b, r)

	dbg_line_off := eb_bytes(&b, dbg_line[:])

	eb_align(&b, 8)
	rel_dbg_line_off := len(b.buf)
	for r in line_rels do eb_struct(&b, r)

	dbg_loc_off := eb_bytes(&b, dbg_loc[:])

	eb_align(&b, 8)
	rel_dbg_loc_off := len(b.buf)
	for r in loc_rels do eb_struct(&b, r)

	eb_align(&b, 8)
	eh_frame_off := eb_bytes(&b, eh_frame[:])

	eb_align(&b, 8)
	rel_eh_frame_off := len(b.buf)
	for r in eh_rels do eb_struct(&b, r)

	eb_align(&b, 8)
	sym_off := len(b.buf)
	for s in symtab do eb_struct(&b, s)

	strtab_off := eb_bytes(&b, str.buf[:])
	shstrtab_off := eb_bytes(&b, shstr.buf[:])

	eb_align(&b, 8)
	sh_off := len(b.buf)

	shdrs := [Section]Elf64_Shdr {
		.Null = {},
		.Text = {
			sh_name = name_text,
			sh_type = .Progbits,
			sh_flags = {.Alloc, .Execinstr},
			sh_offset = u64(text_off),
			sh_size = u64(len(text)),
			sh_addralign = 16,
		},
		.Rel_Text = {
			sh_name = name_reltext,
			sh_type = .Rel,
			sh_offset = u64(rel_off),
			sh_size = u64(len(rels) * size_of(Elf64_Rel)),
			sh_link = .Symtab,
			sh_info_section = .Text,
			sh_addralign = 8,
			sh_entsize = size_of(Elf64_Rel),
		},
		.Data = {
			sh_name = name_data,
			sh_type = .Progbits,
			sh_flags = {.Alloc, .Write},
			sh_offset = u64(data_off),
			sh_size = u64(len(data)),
			sh_addralign = 8,
		},
		.Debug_Abbrev = {
			sh_name = name_dbg_abbrev,
			sh_type = .Progbits,
			sh_offset = u64(dbg_abbrev_off),
			sh_size = u64(len(dbg_abbrev)),
			sh_addralign = 1,
		},
		.Debug_Info = {
			sh_name = name_dbg_info,
			sh_type = .Progbits,
			sh_offset = u64(dbg_info_off),
			sh_size = u64(len(dbg_info)),
			sh_addralign = 1,
		},
		.Rel_Debug_Info = {
			sh_name = name_rel_dbg_info,
			sh_type = .Rel,
			sh_offset = u64(rel_dbg_info_off),
			sh_size = u64(len(info_rels) * size_of(Elf64_Rel)),
			sh_link = .Symtab,
			sh_info_section = .Debug_Info,
			sh_addralign = 8,
			sh_entsize = size_of(Elf64_Rel),
		},
		.Debug_Line = {
			sh_name = name_dbg_line,
			sh_type = .Progbits,
			sh_offset = u64(dbg_line_off),
			sh_size = u64(len(dbg_line)),
			sh_addralign = 1,
		},
		.Rel_Debug_Line = {
			sh_name = name_rel_dbg_line,
			sh_type = .Rel,
			sh_offset = u64(rel_dbg_line_off),
			sh_size = u64(len(line_rels) * size_of(Elf64_Rel)),
			sh_link = .Symtab,
			sh_info_section = .Debug_Line,
			sh_addralign = 8,
			sh_entsize = size_of(Elf64_Rel),
		},
		.Debug_Loc = {
			sh_name = name_dbg_loc,
			sh_type = .Progbits,
			sh_offset = u64(dbg_loc_off),
			sh_size = u64(len(dbg_loc)),
			sh_addralign = 1,
		},
		.Rel_Debug_Loc = {
			sh_name = name_rel_dbg_loc,
			sh_type = .Rel,
			sh_offset = u64(rel_dbg_loc_off),
			sh_size = u64(len(loc_rels) * size_of(Elf64_Rel)),
			sh_link = .Symtab,
			sh_info_section = .Debug_Loc,
			sh_addralign = 8,
			sh_entsize = size_of(Elf64_Rel),
		},
		.Eh_Frame = {
			sh_name = name_eh_frame,
			sh_type = .Progbits,
			sh_flags = {.Alloc},
			sh_offset = u64(eh_frame_off),
			sh_size = u64(len(eh_frame)),
			sh_addralign = 8,
		},
		.Rel_Eh_Frame = {
			sh_name = name_rel_eh_frame,
			sh_type = .Rel,
			sh_offset = u64(rel_eh_frame_off),
			sh_size = u64(len(eh_rels) * size_of(Elf64_Rel)),
			sh_link = .Symtab,
			sh_info_section = .Eh_Frame,
			sh_addralign = 8,
			sh_entsize = size_of(Elf64_Rel),
		},
		.Symtab = {
			sh_name = name_symtab,
			sh_type = .Symtab,
			sh_offset = u64(sym_off),
			sh_size = u64(len(symtab) * size_of(Elf64_Sym)),
			sh_link = .Strtab,
			sh_info = first_global,
			sh_addralign = 8,
			sh_entsize = size_of(Elf64_Sym),
		},
		.Strtab = {
			sh_name = name_strtab,
			sh_type = .Strtab,
			sh_offset = u64(strtab_off),
			sh_size = u64(len(str.buf)),
			sh_addralign = 1,
		},
		.Shstrtab = {
			sh_name = name_shstrtab,
			sh_type = .Strtab,
			sh_offset = u64(shstrtab_off),
			sh_size = u64(len(shstr.buf)),
			sh_addralign = 1,
		},
	}
	for sh in shdrs do eb_struct(&b, sh)

	// patch the header now that section offsets are known
	ehdr := Elf64_Ehdr {
		e_ident = {
			magic = ELF_MAGIC,
			class = .Elf64,
			data = .Lsb,
			version = u8(Elf_Version.Current),
		},
		e_type = .Rel,
		e_machine = .X86_64,
		e_version = .Current,
		e_shoff = u64(sh_off),
		e_ehsize = size_of(Elf64_Ehdr),
		e_shentsize = size_of(Elf64_Shdr),
		e_shnum = len(shdrs),
		e_shstrndx = .Shstrtab,
	}
	ident := ehdr
	mem.copy(&b.buf[0], &ident, size_of(Elf64_Ehdr))

	return slice.clone(b.buf[:], allocator)

	Elf64_Ehdr :: struct {
		e_ident:     Elf_Ident,
		e_type:      Elf_Type,
		e_machine:   Elf_Machine,
		e_version:   Elf_Version,
		e_entry:     u64,
		e_phoff:     u64,
		e_shoff:     u64,
		e_flags:     u32,
		e_ehsize:    u16,
		e_phentsize: u16,
		e_phnum:     u16,
		e_shentsize: u16,
		e_shnum:     u16,
		e_shstrndx:  Section,
	}

	Elf64_Shdr :: struct {
		sh_name:      u32,
		sh_type:      Sh_Type,
		sh_flags:     Sh_Flags,
		sh_addr:      u64,
		sh_offset:    u64,
		sh_size:      u64,
		sh_link:      Section,
		using _:      struct #raw_union {
			sh_info_section: Section,
			sh_info:         u32,
		},
		sh_addralign: u64,
		sh_entsize:   u64,
	}

	Elf64_Sym :: struct {
		st_name:  u32,
		st_info:  Sym_Info,
		st_other: u8,
		st_shndx: Section,
		st_value: u64,
		st_size:  u64,
	}

	Elf64_Rel :: struct {
		r_offset: u64,
		r_info:   Rel_Info,
	}

	// every field is byte sized, so this lays out exactly like the 16 raw
	// e_ident bytes it replaces
	Elf_Ident :: struct {
		magic:      [4]u8,
		class:      Elf_Class,
		data:       Elf_Data,
		version:    u8,
		osabi:      u8,
		abiversion: u8,
		pad:        [7]u8,
	}

	ELF_MAGIC :: [4]u8{0x7f, 'E', 'L', 'F'}

	Elf_Class :: enum u8 {
		None  = 0,
		Elf32 = 1,
		Elf64 = 2,
	}

	Elf_Data :: enum u8 {
		None = 0,
		Lsb  = 1,
		Msb  = 2,
	}

	Elf_Version :: enum u32 {
		None    = 0,
		Current = 1,
	}

	Elf_Type :: enum u16 {
		None = 0,
		Rel  = 1,
		Exec = 2,
		Dyn  = 3,
		Core = 4,
	}

	Elf_Machine :: enum u16 {
		None   = 0,
		X86_64 = 62,
	}

	Sh_Type :: enum u32 {
		Null     = 0,
		Progbits = 1,
		Symtab   = 2,
		Strtab   = 3,
		Rela     = 4,
		Hash     = 5,
		Dynamic  = 6,
		Note     = 7,
		Nobits   = 8,
		Rel      = 9,
	}

	Sh_Flag :: enum u64 {
		Write     = 0,
		Alloc     = 1,
		Execinstr = 2,
	}
	Sh_Flags :: bit_set[Sh_Flag;u64]

	Sym_Bind :: enum u8 {
		Local  = 0,
		Global = 1,
		Weak   = 2,
	}

	Sym_Type :: enum u8 {
		Notype  = 0,
		Object  = 1,
		Func    = 2,
		Section = 3,
	}

	Sym_Info :: bit_field u8 {
		type: Sym_Type | 4,
		bind: Sym_Bind | 4,
	}

	Reloc_Type :: enum u32 {
		None     = 0,
		Abs64    = 1, // R_X86_64_64
		Pc32     = 2, // R_X86_64_PC32
		Gotpcrel = 9, // R_X86_64_GOTPCREL
		Abs32    = 10, // R_X86_64_32
	}

	Rel_Info :: bit_field u64 {
		type: Reloc_Type | 32,
		sym:  u32        | 32,
	}

	// section indices in the section header table; the order must match the
	// `shdrs` array below, which is indexed by this enum. `Null` doubles as
	// SHN_UNDEF for symbols.
	Section :: enum u16 {
		Null,
		Text,
		Rel_Text,
		Data,
		Debug_Abbrev,
		Debug_Info,
		Rel_Debug_Info,
		Debug_Line,
		Rel_Debug_Line,
		Debug_Loc,
		Rel_Debug_Loc,
		Eh_Frame,
		Rel_Eh_Frame,
		Symtab,
		Strtab,
		Shstrtab,
	}

	// DWARF v4 constants used by the debug sections
	Dw_Tag :: enum u64 {
		Array_Type       = 0x01,
		Enumeration_Type = 0x04,
		Formal_Parameter = 0x05,
		Member           = 0x0d,
		Pointer_Type     = 0x0f,
		Compile_Unit     = 0x11,
		Structure_Type   = 0x13,
		Subroutine_Type  = 0x15,
		Union_Type       = 0x17,
		Unspecified_Type = 0x3b,
		Subprogram       = 0x2e,
		Variable         = 0x34,
		Subrange_Type    = 0x21,
		Base_Type        = 0x24,
		Enumerator       = 0x28,
	}

	Dw_Children :: enum u8 {
		No  = 0x00,
		Yes = 0x01,
	}

	Dw_At :: enum u64 {
		Location             = 0x02,
		Name                 = 0x03,
		Byte_Size            = 0x0b,
		Stmt_List            = 0x10,
		Low_Pc               = 0x11,
		High_Pc              = 0x12,
		Language             = 0x13,
		Comp_Dir             = 0x1b,
		Const_Value          = 0x1c,
		Upper_Bound          = 0x2f,
		Producer             = 0x25,
		Data_Member_Location = 0x38,
		Decl_File            = 0x3a,
		Decl_Line            = 0x3b,
		Encoding             = 0x3e,
		Frame_Base           = 0x40,
		Type                 = 0x49,
		Count                = 0x37,
	}

	Dw_Form :: enum u64 {
		Addr       = 0x01,
		Data1      = 0x0b,
		Data2      = 0x05,
		Data4      = 0x06,
		Data8      = 0x07,
		String     = 0x08,
		Sdata      = 0x0d,
		Udata      = 0x0f,
		Ref4       = 0x13,
		Sec_Offset = 0x17,
		Exprloc    = 0x18,
	}

	Dw_Ate :: enum u8 {
		Address  = 0x01,
		Boolean  = 0x02,
		Float    = 0x04,
		Signed   = 0x05,
		Unsigned = 0x07,
	}

	Dw_Op :: enum u8 {
		Addr           = 0x03,
		Fbreg          = 0x91,
		Call_Frame_Cfa = 0x9c,
	}

	Dw_Abbrev :: enum u64 {
		Compile_Unit = 1,
		Subprogram,
		Variable,
		Formal_Parameter,
		Base_Type,
		Pointer_Type,
		Structure_Type,
		Member,
		Array_Type,
		Subrange_Type,
		Enumeration_Type,
		Enumerator,
		Union_Type,
		Unspecified_Type,
		Subroutine_Type,
		Global_Variable,
	}

	Dw_Lang :: enum u16 {
		C = 0x0002,
	}

	// line program opcodes
	Dw_Lns :: enum u8 {
		Copy         = 1,
		Advance_Pc   = 2,
		Advance_Line = 3,
		Set_File     = 4,
	}

	Dw_Lne :: enum u8 {
		End_Sequence = 1,
		Set_Address  = 2,
	}

	// call frame information
	Dw_Eh_Pe :: bit_field u8 {
		format: Dw_Eh_Pe_Format | 4,
		rel:    Dw_Eh_Pe_Rel    | 4,
	}

	Dw_Eh_Pe_Format :: enum u8 {
		Sdata4 = 0xb,
	}

	Dw_Eh_Pe_Rel :: enum u8 {
		Absptr = 0x0,
		Pcrel  = 0x1,
	}

	// the top two bits pick a primary opcode carrying its operand inline;
	// `Extended` means the whole byte is instead a `Dw_Cfa`
	Dw_Cfa_Op :: bit_field u8 {
		arg: u8          | 6,
		op:  Dw_Cfa_Kind | 2,
	}

	Dw_Cfa_Kind :: enum u8 {
		Extended    = 0,
		Advance_Loc = 1,
		Offset      = 2,
		Restore     = 3,
	}

	Dw_Cfa :: enum u8 {
		Nop            = 0x00,
		Advance_Loc1   = 0x02,
		Advance_Loc2   = 0x03,
		Advance_Loc4   = 0x04,
		Remember_State = 0x0a,
		Restore_State  = 0x0b,
		Def_Cfa        = 0x0c,
		Def_Cfa_Offset = 0x0e,
	}

	DW_LINE_BASE :: 0xfb // -5 as u8
	DW_LINE_RANGE :: 14
	DW_OPCODE_BASE :: 13

	Elf_Builder :: struct {
		buf: [dynamic]u8,
	}

	eb_align :: proc(b: ^Elf_Builder, align: int) {
		for len(b.buf) % align != 0 {
			append(&b.buf, 0)
		}
	}

	eb_bytes :: proc(b: ^Elf_Builder, data: []u8) -> int {
		off := len(b.buf)
		append(&b.buf, ..data)
		return off
	}

	eb_struct :: proc(b: ^Elf_Builder, value: $T) -> int {
		v := value
		return eb_bytes(b, mem.ptr_to_bytes(&v))
	}

	// str_tab accumulates NUL terminated strings and hands back their offsets.
	Str_Tab :: struct {
		buf: [dynamic]u8,
	}

	strtab_add :: proc(s: ^Str_Tab, name: string) -> u32 {
		if name == "" do return 0
		off := u32(len(s.buf))
		append(&s.buf, name)
		append(&s.buf, 0)
		return off
	}
}

fixed_uleb :: proc(buf: []u8, value: u64) {
	v := value
	for i in 0 ..< len(buf) {
		buf[i] = u8(v & 0x7f)
		v >>= 7

		if i != len(buf) - 1 {
			buf[i] |= 0x80
		}
	}
}

uleb :: bac.uleb
sleb :: bac.sleb
putb :: bac.putb

put_u16 :: proc(b: ^[dynamic]u8, v: u16) {
	x := v
	append(b, ..mem.ptr_to_bytes(&x))
}
put_u32 :: proc(b: ^[dynamic]u8, v: u32) {
	x := v
	append(b, ..mem.ptr_to_bytes(&x))
}
put_u64 :: proc(b: ^[dynamic]u8, v: u64) {
	x := v
	append(b, ..mem.ptr_to_bytes(&x))
}
patch_u32 :: proc(b: ^[dynamic]u8, at: int, v: u32) {
	x := v
	mem.copy(&b[at], &x, 4)
}
