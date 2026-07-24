package main

import "backend"
import "core:mem"
import "core:slice"
import "vendored/gam/util/arna"

LIBCALL_BASE :: backend.RELOC_BIG_CONSTANT_BASE - 32
MEMCPY_ID :: LIBCALL_BASE
MEMSET_ID :: LIBCALL_BASE + 1

// Minimal writer for x86-64 ELF relocatable object files (ET_REL). The output
// is a `.o` that can be handed to `zig cc` / `ld` to produce an executable.
//
// The frontend emits position independent machine code with three relocation
// kinds (see backend.Reloc_Kind):
//   - Text:   a call to another procedure (by procedure index)
//   - Data:   a call to a libc helper (0 = memcpy, 1 = memset)
//   - Global: a RIP relative reference to a global datum (by global index)
//
// The backend already writes the required addend into the 4 byte slot that
// precedes each relocation's recorded offset, so we emit SHT_REL sections and
// only need to bias each slot by -4 (the distance from the slot to the end of
// the instruction the recorded offset points at).

// emit_elf lays out the compiled procedures and globals into a relocatable
// object and returns its bytes.
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
				st_info = (STB_LOCAL << 4) | STT_FUNC,
				st_shndx = SEC_TEXT,
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
				st_info = (STB_LOCAL << 4) | STT_OBJECT,
				st_shndx = SEC_DATA,
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
	for shndx in ([]u16{SEC_TEXT, SEC_DEBUG_ABBREV, SEC_DEBUG_LINE}) {
		append(
			&locals,
			Elf64_Sym {
				st_info = (STB_LOCAL << 4) | STT_SECTION,
				st_shndx = shndx,
			},
		)
	}
	next_local += 3

	// globals come after every local symbol
	next_global := next_local
	if main_index >= 0 {
		append(
			&globals,
			Elf64_Sym {
				st_name = strtab_add(&str, "main"),
				st_info = (STB_GLOBAL << 4) | STT_FUNC,
				st_shndx = SEC_TEXT,
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
				st_info = (STB_GLOBAL << 4) | STT_NOTYPE,
				st_shndx = SHN_UNDEF,
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
				LIBCALL_BASE <= rel.id &&
				rel.id < backend.RELOC_BIG_CONSTANT_BASE
			if !is_libcall do continue
			id := rel.id - LIBCALL_BASE
			if have_lib[id] do continue
			have_lib[id] = true
			append(
				&globals,
				Elf64_Sym {
					st_name = strtab_add(&str, lib_names[id]),
					st_info = (STB_GLOBAL << 4) | STT_NOTYPE,
					st_shndx = SHN_UNDEF,
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
				LIBCALL_BASE <= rel.id &&
				rel.id < backend.RELOC_BIG_CONSTANT_BASE

			// TODO: this is horrible
			// Big-constant relocs point into this proc's own constant pool in
			// .text, so resolve them in place (RIP relative) with no ELF entry.
			if rel.kind == .Global &&
			   rel.id >= backend.RELOC_BIG_CONSTANT_BASE {
				target :=
					const_off[i] +
					int(rel.id - backend.RELOC_BIG_CONSTANT_BASE)
				source := proc_off[i] + int(rel.offset)
				cur := u32(0)
				mem.copy(&cur, &text[slot], 4)
				cur += u32(target - source)
				mem.copy(&text[slot], &cur, 4)
				continue
			}

			sym: u32
			type: u32
			switch rel.kind {
			case .Text:
				if is_libcall {
					sym = lib_sym[rel.id - LIBCALL_BASE]
				} else {
					sym = proc_sym[rel.id]
				}
				type = R_X86_64_PC32
			case .Global:
				sym = data_sym[rel.id]
				type = R_X86_64_PC32
			case .Got:
				sym = lib_sym[rel.id]
				type = R_X86_64_GOTPCREL
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
					r_info = (u64(sym) << 32) | u64(type),
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

	// -- .debug_abbrev : a single compile-unit abbreviation ---------------
	uleb(&dbg_abbrev, 1) // abbrev code 1
	uleb(&dbg_abbrev, DW_TAG_compile_unit)
	append(&dbg_abbrev, DW_CHILDREN_no)
	dw_attr :: proc(b: ^[dynamic]u8, at, form: u64) {uleb(b, at); uleb(
			b,
			form,
		)}
	dw_attr(&dbg_abbrev, DW_AT_producer, DW_FORM_string)
	dw_attr(&dbg_abbrev, DW_AT_language, DW_FORM_data2)
	dw_attr(&dbg_abbrev, DW_AT_name, DW_FORM_string)
	dw_attr(&dbg_abbrev, DW_AT_comp_dir, DW_FORM_string)
	dw_attr(&dbg_abbrev, DW_AT_low_pc, DW_FORM_addr)
	dw_attr(&dbg_abbrev, DW_AT_high_pc, DW_FORM_data8)
	dw_attr(&dbg_abbrev, DW_AT_stmt_list, DW_FORM_sec_offset)
	uleb(&dbg_abbrev, 0) // end of attribute list
	uleb(&dbg_abbrev, 0) // end of abbrev list
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
		append(&dbg_line, 0, 9, DW_LNE_set_address)
		append(
			&line_rels,
			Elf64_Rel {
				r_offset = u64(len(dbg_line)),
				r_info = (u64(proc_sym[i]) << 32) | R_X86_64_64,
			},
		)
		put_u64(&dbg_line, 0)

		file := u64(prc.file_id) + 1
		append(&dbg_line, DW_LNS_set_file)
		uleb(&dbg_line, file)

		prev_off := u32(0)
		prev_line := i64(1)
		cur_off := u32(0)
		for sloc in prc.out.slocs {
			if u64(sloc.file) + 1 != file {
				file = u64(sloc.file) + 1
				append(&dbg_line, DW_LNS_set_file)
				uleb(&dbg_line, file)
			}
			if cur_off != prev_off {
				append(&dbg_line, DW_LNS_advance_pc)
				uleb(&dbg_line, u64(cur_off - prev_off))
				prev_off = cur_off
			}
			if i64(sloc.line) != prev_line {
				append(&dbg_line, DW_LNS_advance_line)
				sleb(&dbg_line, i64(sloc.line) - prev_line)
				prev_line = i64(sloc.line)
			}
			append(&dbg_line, DW_LNS_copy)
			cur_off += sloc.range
		}

		// advance to the end of the proc and close the sequence
		if cur_off != prev_off {
			append(&dbg_line, DW_LNS_advance_pc)
			uleb(&dbg_line, u64(cur_off - prev_off))
		}
		append(&dbg_line, 0, 1, DW_LNE_end_sequence)
	}
	patch_u32(
		&dbg_line,
		line_unit_len_pos,
		u32(len(dbg_line) - line_prog_base),
	)

	// -- .debug_info : one compile unit -----------------------------------
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
			r_info = (u64(sec_abbrev_sym) << 32) | R_X86_64_32,
		},
	)
	put_u32(&dbg_info, 0)
	append(&dbg_info, 8) // address_size

	uleb(&dbg_info, 1) // abbrev code 1 (compile_unit)
	append(&dbg_info, "odin-jit")
	append(&dbg_info, 0)
	put_u16(&dbg_info, DW_LANG_C)
	append(&dbg_info, cu_name)
	append(&dbg_info, 0)
	append(&dbg_info, ctx.root)
	append(&dbg_info, 0)
	// low_pc, relocated against .text (base of the code)
	append(
		&info_rels,
		Elf64_Rel {
			r_offset = u64(len(dbg_info)),
			r_info = (u64(sec_text_sym) << 32) | R_X86_64_64,
		},
	)
	put_u64(&dbg_info, 0)
	put_u64(&dbg_info, u64(len(text))) // high_pc (offset form)
	// stmt_list, relocated against .debug_line
	append(
		&info_rels,
		Elf64_Rel {
			r_offset = u64(len(dbg_info)),
			r_info = (u64(sec_line_sym) << 32) | R_X86_64_32,
		},
	)
	put_u32(&dbg_info, 0)
	patch_u32(&dbg_info, info_unit_len_pos, u32(len(dbg_info) - info_base))

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

	eb_align(&b, 8)
	sym_off := len(b.buf)
	for s in symtab do eb_struct(&b, s)

	strtab_off := eb_bytes(&b, str.buf[:])
	shstrtab_off := eb_bytes(&b, shstr.buf[:])

	eb_align(&b, 8)
	sh_off := len(b.buf)

	shdrs := [?]Elf64_Shdr {
		// 0: null
		{},
		// 1: .text
		{
			sh_name = name_text,
			sh_type = SHT_PROGBITS,
			sh_flags = SHF_ALLOC | SHF_EXECINSTR,
			sh_offset = u64(text_off),
			sh_size = u64(len(text)),
			sh_addralign = 16,
		},
		// 2: .rel.text
		{
			sh_name = name_reltext,
			sh_type = SHT_REL,
			sh_offset = u64(rel_off),
			sh_size = u64(len(rels) * size_of(Elf64_Rel)),
			sh_link = SEC_SYMTAB,
			sh_info = SEC_TEXT,
			sh_addralign = 8,
			sh_entsize = size_of(Elf64_Rel),
		},
		// 3: .data
		{
			sh_name = name_data,
			sh_type = SHT_PROGBITS,
			sh_flags = SHF_ALLOC | SHF_WRITE,
			sh_offset = u64(data_off),
			sh_size = u64(len(data)),
			sh_addralign = 8,
		},
		// 4: .debug_abbrev
		{
			sh_name = name_dbg_abbrev,
			sh_type = SHT_PROGBITS,
			sh_offset = u64(dbg_abbrev_off),
			sh_size = u64(len(dbg_abbrev)),
			sh_addralign = 1,
		},
		// 5: .debug_info
		{
			sh_name = name_dbg_info,
			sh_type = SHT_PROGBITS,
			sh_offset = u64(dbg_info_off),
			sh_size = u64(len(dbg_info)),
			sh_addralign = 1,
		},
		// 6: .rel.debug_info
		{
			sh_name = name_rel_dbg_info,
			sh_type = SHT_REL,
			sh_offset = u64(rel_dbg_info_off),
			sh_size = u64(len(info_rels) * size_of(Elf64_Rel)),
			sh_link = SEC_SYMTAB,
			sh_info = SEC_DEBUG_INFO,
			sh_addralign = 8,
			sh_entsize = size_of(Elf64_Rel),
		},
		// 7: .debug_line
		{
			sh_name = name_dbg_line,
			sh_type = SHT_PROGBITS,
			sh_offset = u64(dbg_line_off),
			sh_size = u64(len(dbg_line)),
			sh_addralign = 1,
		},
		// 8: .rel.debug_line
		{
			sh_name = name_rel_dbg_line,
			sh_type = SHT_REL,
			sh_offset = u64(rel_dbg_line_off),
			sh_size = u64(len(line_rels) * size_of(Elf64_Rel)),
			sh_link = SEC_SYMTAB,
			sh_info = SEC_DEBUG_LINE,
			sh_addralign = 8,
			sh_entsize = size_of(Elf64_Rel),
		},
		// 9: .symtab
		{
			sh_name = name_symtab,
			sh_type = SHT_SYMTAB,
			sh_offset = u64(sym_off),
			sh_size = u64(len(symtab) * size_of(Elf64_Sym)),
			sh_link = SEC_STRTAB,
			sh_info = first_global,
			sh_addralign = 8,
			sh_entsize = size_of(Elf64_Sym),
		},
		// 10: .strtab
		{
			sh_name = name_strtab,
			sh_type = SHT_STRTAB,
			sh_offset = u64(strtab_off),
			sh_size = u64(len(str.buf)),
			sh_addralign = 1,
		},
		// 11: .shstrtab
		{
			sh_name = name_shstrtab,
			sh_type = SHT_STRTAB,
			sh_offset = u64(shstrtab_off),
			sh_size = u64(len(shstr.buf)),
			sh_addralign = 1,
		},
	}
	for sh in shdrs do eb_struct(&b, sh)

	// patch the header now that section offsets are known
	ehdr := Elf64_Ehdr {
		e_type      = ET_REL,
		e_machine   = EM_X86_64,
		e_version   = EV_CURRENT,
		e_shoff     = u64(sh_off),
		e_ehsize    = size_of(Elf64_Ehdr),
		e_shentsize = size_of(Elf64_Shdr),
		e_shnum     = len(shdrs),
		e_shstrndx  = SEC_SHSTRTAB,
	}
	ehdr.e_ident = {
		0x7f,
		'E',
		'L',
		'F',
		ELFCLASS64,
		ELFDATA2LSB,
		EV_CURRENT,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
	}
	ident := ehdr
	mem.copy(&b.buf[0], &ident, size_of(Elf64_Ehdr))

	return slice.clone(b.buf[:], allocator)

	Elf64_Ehdr :: struct {
		e_ident:     [16]u8,
		e_type:      u16,
		e_machine:   u16,
		e_version:   u32,
		e_entry:     u64,
		e_phoff:     u64,
		e_shoff:     u64,
		e_flags:     u32,
		e_ehsize:    u16,
		e_phentsize: u16,
		e_phnum:     u16,
		e_shentsize: u16,
		e_shnum:     u16,
		e_shstrndx:  u16,
	}

	Elf64_Shdr :: struct {
		sh_name:      u32,
		sh_type:      u32,
		sh_flags:     u64,
		sh_addr:      u64,
		sh_offset:    u64,
		sh_size:      u64,
		sh_link:      u32,
		sh_info:      u32,
		sh_addralign: u64,
		sh_entsize:   u64,
	}

	Elf64_Sym :: struct {
		st_name:  u32,
		st_info:  u8,
		st_other: u8,
		st_shndx: u16,
		st_value: u64,
		st_size:  u64,
	}

	Elf64_Rel :: struct {
		r_offset: u64,
		r_info:   u64,
	}

	ELFCLASS64 :: 2
	ELFDATA2LSB :: 1
	EV_CURRENT :: 1

	ET_REL :: 1
	EM_X86_64 :: 62

	SHT_PROGBITS :: 1
	SHT_SYMTAB :: 2
	SHT_STRTAB :: 3
	SHT_REL :: 9

	SHF_WRITE :: 0x1
	SHF_ALLOC :: 0x2
	SHF_EXECINSTR :: 0x4

	STB_LOCAL :: 0
	STB_GLOBAL :: 1

	STT_NOTYPE :: 0
	STT_OBJECT :: 1
	STT_FUNC :: 2
	STT_SECTION :: 3

	SHN_UNDEF :: 0

	R_X86_64_64 :: 1
	R_X86_64_PC32 :: 2
	R_X86_64_32 :: 10
	R_X86_64_GOTPCREL :: 9

	// section indices in the section header table
	SEC_TEXT :: 1
	SEC_DATA :: 3
	SEC_DEBUG_ABBREV :: 4
	SEC_DEBUG_INFO :: 5
	SEC_DEBUG_LINE :: 7
	SEC_SYMTAB :: 9
	SEC_STRTAB :: 10
	SEC_SHSTRTAB :: 11

	// DWARF v4 constants used by the debug sections
	DW_TAG_compile_unit :: 0x11
	DW_CHILDREN_no :: 0x00
	DW_AT_name :: 0x03
	DW_AT_stmt_list :: 0x10
	DW_AT_low_pc :: 0x11
	DW_AT_high_pc :: 0x12
	DW_AT_language :: 0x13
	DW_AT_comp_dir :: 0x1b
	DW_AT_producer :: 0x25
	DW_FORM_addr :: 0x01
	DW_FORM_data2 :: 0x05
	DW_FORM_data8 :: 0x07
	DW_FORM_string :: 0x08
	DW_FORM_sec_offset :: 0x17
	DW_LANG_C :: 0x0002
	// line program opcodes
	DW_LNS_copy :: 1
	DW_LNS_advance_pc :: 2
	DW_LNS_advance_line :: 3
	DW_LNS_set_file :: 4
	DW_LNE_end_sequence :: 1
	DW_LNE_set_address :: 2
	DW_LINE_BASE :: 0xfb // -5 as u8
	DW_LINE_RANGE :: 14
	DW_OPCODE_BASE :: 13

	uleb :: proc(b: ^[dynamic]u8, value: u64) {
		v := value
		for {
			byte := u8(v & 0x7f)
			v >>= 7
			if v != 0 do byte |= 0x80
			append(b, byte)
			if v == 0 do break
		}
	}

	sleb :: proc(b: ^[dynamic]u8, value: i64) {
		v := value
		for {
			byte := u8(v & 0x7f)
			v >>= 7
			sign := (byte & 0x40) != 0
			done := (v == 0 && !sign) || (v == -1 && sign)
			if !done do byte |= 0x80
			append(b, byte)
			if done do break
		}
	}

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
