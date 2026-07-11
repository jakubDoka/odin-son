package main

import "backend"
import "core:mem"
import "core:slice"

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
	scratch := context.temp_allocator

	// --- .text : concatenate procedure code, 16 byte aligned ------------
	text: [dynamic]u8
	text.allocator = scratch
	proc_off := make([]int, len(ctx.procs), scratch)
	// Each procedure's constant pool (e.g. materialised float immediates) is
	// laid out right after its code; big-constant relocs are resolved against it.
	const_off := make([]int, len(ctx.procs), scratch)
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
	data.allocator = scratch
	global_off := make([]int, len(ctx.globals), scratch)
	for glob, i in ctx.globals {
		align := max(glob.align, 1)
		for len(data) % align != 0 do append(&data, 0)
		global_off[i] = len(data)
		append(&data, ..glob.bytes)
	}

	// --- symbol + string tables -----------------------------------------
	str: Str_Tab
	str.buf.allocator = scratch
	append(&str.buf, 0) // index 0 is the empty string

	locals: [dynamic]Elf64_Sym
	globals: [dynamic]Elf64_Sym
	locals.allocator = scratch
	globals.allocator = scratch

	proc_sym := make([]u32, len(ctx.procs), scratch)
	data_sym := make([]u32, len(ctx.globals), scratch)
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

	// undefined libc helpers, added lazily if referenced
	lib_names := [2]string{"memcpy", "memset"}
	for &prc in ctx.procs {
		for rel in prc.out.relocs {
			if rel.kind != .Data do continue
			id := rel.id
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
	rels.allocator = scratch
	for &prc, i in ctx.procs {
		for rel in prc.out.relocs {
			slot := proc_off[i] + int(rel.offset) - 4

			// Big-constant relocs point into this proc's own constant pool in
			// .text, so resolve them in place (RIP relative) with no ELF entry.
			if rel.kind == .Global && rel.id >= backend.RELOC_BIG_CONSTANT_BASE {
				target := const_off[i] + int(rel.id - backend.RELOC_BIG_CONSTANT_BASE)
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
				sym = proc_sym[rel.id]
				type = R_X86_64_PC32
			case .Global:
				sym = data_sym[rel.id]
				type = R_X86_64_PC32
			case .Data:
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

	// combine local then global symbols; first global index is sh_info
	symtab: [dynamic]Elf64_Sym
	symtab.allocator = scratch
	append(&symtab, Elf64_Sym{}) // null symbol
	append(&symtab, ..locals[:])
	append(&symtab, ..globals[:])
	first_global := u32(1 + len(locals))

	// --- section header string table ------------------------------------
	shstr: Str_Tab
	shstr.buf.allocator = scratch
	append(&shstr.buf, 0)
	name_text := strtab_add(&shstr, ".text")
	name_reltext := strtab_add(&shstr, ".rel.text")
	name_data := strtab_add(&shstr, ".data")
	name_symtab := strtab_add(&shstr, ".symtab")
	name_strtab := strtab_add(&shstr, ".strtab")
	name_shstrtab := strtab_add(&shstr, ".shstrtab")

	// --- assemble the file ----------------------------------------------
	b: Elf_Builder
	b.buf.allocator = scratch

	// header placeholder, patched at the end
	eb_struct(&b, Elf64_Ehdr{})

	eb_align(&b, 16)
	text_off := eb_bytes(&b, text[:])

	eb_align(&b, 8)
	data_off := eb_bytes(&b, data[:])

	eb_align(&b, 8)
	rel_off := len(b.buf)
	for r in rels do eb_struct(&b, r)

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
			sh_name      = name_reltext,
			sh_type      = SHT_REL,
			sh_offset    = u64(rel_off),
			sh_size      = u64(len(rels) * size_of(Elf64_Rel)),
			sh_link      = 4, // .symtab
			sh_info      = SEC_TEXT,
			sh_addralign = 8,
			sh_entsize   = size_of(Elf64_Rel),
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
		// 4: .symtab
		{
			sh_name      = name_symtab,
			sh_type      = SHT_SYMTAB,
			sh_offset    = u64(sym_off),
			sh_size      = u64(len(symtab) * size_of(Elf64_Sym)),
			sh_link      = 5, // .strtab
			sh_info      = first_global,
			sh_addralign = 8,
			sh_entsize   = size_of(Elf64_Sym),
		},
		// 5: .strtab
		{
			sh_name = name_strtab,
			sh_type = SHT_STRTAB,
			sh_offset = u64(strtab_off),
			sh_size = u64(len(str.buf)),
			sh_addralign = 1,
		},
		// 6: .shstrtab
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
		e_shstrndx  = 6,
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

	SHN_UNDEF :: 0

	R_X86_64_PC32 :: 2
	R_X86_64_GOTPCREL :: 9

	// section indices in the section header table
	SEC_TEXT :: 1
	SEC_DATA :: 3

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
