package main

// The binary decoder. It walks the module byte slice section by section,
// building the flat AST in `ast.odin`. Sections it understands are parsed in
// full; everything else is skipped using the section's declared byte length.
// After each section the cursor is snapped back to the section's declared end so
// a quirk in one section can never desync the ones that follow.
//
// The arena and the module are passed to every decode step as direct pointer
// parameters (rather than stashed inside `Decoder`): the JIT frontend loses
// alias tracking when a pointer to a local is stored in a struct field and then
// mutated through it, so a write through such a field would not be observed by a
// later read of the original local.

Decoder :: struct {
	data: string,
	pos:  int,
	ok:   bool,
}

module_init :: proc(m: ^typecheck.Module) {
	m.ok = false
	m.version = 0
	m.section_count = 0
	m.start_func = -1
	// The Array(T) fields are already zero-valued (data=nil, len=cap=0) by the
	// caller's `typecheck.Module = {}`, so there is nothing else to set up: no strides.
}

decode_module :: proc(d: ^Decoder, a: ^Arena, m: ^typecheck.Module) {
	// magic: \0asm
	b0 := read_byte(d)
	b1 := read_byte(d)
	b2 := read_byte(d)
	b3 := read_byte(d)
	ok_magic := (b0 == 0x00) & (b1 == 0x61) & (b2 == 0x73) & (b3 == 0x6d)
	if !ok_magic {
		d.ok = false
		return
	}

	m.version = read_version(d)
	if m.version != 1 {
		d.ok = false
		return
	}

	for {
		if d.pos >= len(d.data) do break
		if !d.ok do break
		id := int(read_byte(d))
		size := int(read_uleb32(d))
		content_start := d.pos
		if content_start + size > len(d.data) {
			d.ok = false
			break
		}
		m.section_count += 1

		if id == SEC_TYPE {
			decode_type_section(d, a, m)
		} else if id == SEC_FUNCTION {
			decode_function_section(d, a, m)
		} else if id == SEC_MEMORY {
			decode_memory_section(d, a, m)
		} else if id == SEC_GLOBAL {
			decode_global_section(d, a, m)
		} else if id == SEC_EXPORT {
			decode_export_section(d, a, m)
		} else if id == SEC_START {
			m.start_func = int(read_uleb32(d))
		} else if id == SEC_CODE {
			decode_code_section(d, a, m)
		} else if id == SEC_DATA {
			decode_data_section(d, a, m)
		} else if id == SEC_IMPORT {
			decode_import_section(d, a, m)
		}
		// else: table/element/custom -> skipped via declared size below.

		d.pos = content_start + size
	}

	if d.ok do m.ok = true
}

// The version field is a fixed 4-byte little-endian word, not a LEB.
read_version :: proc(d: ^Decoder) -> u32 {
	v0 := u32(read_byte(d))
	v1 := u32(read_byte(d))
	v2 := u32(read_byte(d))
	v3 := u32(read_byte(d))
	return v0 | (v1 << 8) | (v2 << 16) | (v3 << 24)
}

decode_type_section :: proc(d: ^Decoder, a: ^Arena, m: ^typecheck.Module) {
	count := int(read_uleb32(d))
	i := 0
	for {
		if i >= count do break
		if !d.ok do break
		form := read_byte(d)
		ft: FuncType = {}
		ft.param_off = m.valtypes.len
		if form == 0x60 {
			np := int(read_uleb32(d))
			j := 0
			for {
				if j >= np do break
				v := int(read_byte(d))
				array_push(a, &m.valtypes, &v)
				j += 1
			}
			ft.param_count = np
			ft.result_off = m.valtypes.len
			nr := int(read_uleb32(d))
			k := 0
			for {
				if k >= nr do break
				v := int(read_byte(d))
				array_push(a, &m.valtypes, &v)
				k += 1
			}
			ft.result_count = nr
		} else {
			d.ok = false
			ft.result_off = m.valtypes.len
		}
		array_push(a, &m.types, &ft)
		i += 1
	}
}

decode_function_section :: proc(d: ^Decoder, a: ^Arena, m: ^typecheck.Module) {
	count := int(read_uleb32(d))
	i := 0
	for {
		if i >= count do break
		if !d.ok do break
		ti := int(read_uleb32(d))
		array_push(a, &m.funcs, &ti)
		i += 1
	}
}

decode_memory_section :: proc(d: ^Decoder, a: ^Arena, m: ^typecheck.Module) {
	count := int(read_uleb32(d))
	i := 0
	for {
		if i >= count do break
		if !d.ok do break
		mem: Memory = {}
		flag := read_byte(d)
		mem.min = int(read_uleb32(d))
		if flag == 0x01 {
			mem.has_max = 1
			mem.max = int(read_uleb32(d))
		} else {
			mem.has_max = 0
			mem.max = 0
		}
		array_push(a, &m.mems, &mem)
		i += 1
	}
}

decode_global_section :: proc(d: ^Decoder, a: ^Arena, m: ^typecheck.Module) {
	count := int(read_uleb32(d))
	i := 0
	for {
		if i >= count do break
		if !d.ok do break
		g: Global = {}
		g.valtype = int(read_byte(d))
		g.mutable = int(read_byte(d))
		decode_const_expr(d, &g.init_op, &g.init_val)
		array_push(a, &m.globals, &g)
		i += 1
	}
}

decode_export_section :: proc(d: ^Decoder, a: ^Arena, m: ^typecheck.Module) {
	count := int(read_uleb32(d))
	i := 0
	for {
		if i >= count do break
		if !d.ok do break
		e: Export = {}
		nlen := int(read_uleb32(d))
		e.nm_off = d.pos
		e.nm_len = nlen
		d.pos += nlen
		e.kind = int(read_byte(d))
		e.index = int(read_uleb32(d))
		array_push(a, &m.exports, &e)
		i += 1
	}
}

decode_import_section :: proc(d: ^Decoder, a: ^Arena, m: ^typecheck.Module) {
	count := int(read_uleb32(d))
	i := 0
	for {
		if i >= count do break
		if !d.ok do break
		im: Import = {}
		ml := int(read_uleb32(d))
		im.mod_off = d.pos
		im.mod_len = ml
		d.pos += ml
		nl := int(read_uleb32(d))
		im.nm_off = d.pos
		im.nm_len = nl
		d.pos += nl
		im.kind = int(read_byte(d))
		im.index = int(read_uleb32(d))
		array_push(a, &m.imports, &im)
		i += 1
	}
}

decode_data_section :: proc(d: ^Decoder, a: ^Arena, m: ^typecheck.Module) {
	count := int(read_uleb32(d))
	i := 0
	for {
		if i >= count do break
		if !d.ok do break
		ds: Data = {}
		flag := int(read_uleb32(d))
		ds.mem_index = 0
		if flag == 0x02 {
			ds.mem_index = int(read_uleb32(d))
		}
		if (flag == 0x00) | (flag == 0x02) {
			decode_const_expr(d, &ds.off_op, &ds.off_val)
		} else {
			ds.off_op = 0
			ds.off_val = 0
		}
		blen := int(read_uleb32(d))
		ds.bytes_off = d.pos
		ds.bytes_len = blen
		d.pos += blen
		array_push(a, &m.datas, &ds)
		i += 1
	}
}

decode_code_section :: proc(d: ^Decoder, a: ^Arena, m: ^typecheck.Module) {
	count := int(read_uleb32(d))
	i := 0
	for {
		if i >= count do break
		if !d.ok do break
		c: Code = {}
		c.body_size = int(read_uleb32(d))
		body_end := d.pos + c.body_size

		c.local_off = m.locals.len
		ngroups := int(read_uleb32(d))
		total := 0
		g := 0
		for {
			if g >= ngroups do break
			if !d.ok do break
			loc: Local = {}
			loc.count = int(read_uleb32(d))
			loc.valtype = int(read_byte(d))
			total += loc.count
			array_push(a, &m.locals, &loc)
			g += 1
		}
		c.local_count = ngroups
		c.local_total = total

		c.instr_off = m.instrs.len
		decode_expr(d, a, &m.instrs)
		c.instr_count = m.instrs.len - c.instr_off

		array_push(a, &m.codes, &c)
		// Snap to the entry's declared end so a decode quirk stays local.
		d.pos = body_end
		i += 1
	}
}

// decode_const_expr decodes a single constant instruction followed by `end`,
// as used by global initializers and active data-segment offsets.
decode_const_expr :: proc(d: ^Decoder, op_out: ^int, val_out: ^i64) {
	op := int(read_byte(d))
	op_out^ = op
	val_out^ = 0
	if op == OP_I32_CONST {
		val_out^ = read_sleb64(d)
	} else if op == OP_I64_CONST {
		val_out^ = read_sleb64(d)
	} else if op == OP_GLOBAL_GET {
		val_out^ = i64(read_uleb32(d))
	}
	// consume the terminating end (0x0b)
	e := read_byte(d)
	if e != OP_END do d.ok = false
}

// decode_expr decodes a flat instruction stream up to and including the `end`
// that closes the function body (depth 0). Nested block/loop/if push a new
// nesting level. Unknown opcodes flip the error flag and stop the stream.
decode_expr :: proc(d: ^Decoder, a: ^Arena, instrs: ^Array(Instr)) {
	depth := 0
	for {
		if d.pos >= len(d.data) do break
		if !d.ok do break
		op := int(read_byte(d))
		ins: Instr = {}
		ins.op = op
		ins.x = 0
		ins.y = 0

		if (op == OP_BLOCK) | (op == OP_LOOP) | (op == OP_IF) {
			// block type: a single byte for the simple MVP forms (0x40 = void,
			// or a value type); stored raw so the printer can name it.
			ins.x = i64(read_byte(d))
		} else if (op == OP_BR) | (op == OP_BR_IF) {
			ins.x = i64(read_uleb32(d))
		} else if op == OP_CALL {
			ins.x = i64(read_uleb32(d))
		} else if (op >= OP_LOCAL_GET) & (op <= OP_GLOBAL_SET) {
			ins.x = i64(read_uleb32(d))
		} else if op == OP_I32_CONST {
			ins.x = read_sleb64(d)
		} else if op == OP_I64_CONST {
			ins.x = read_sleb64(d)
		} else if (op >= OP_LOAD_LO) & (op <= OP_STORE_HI) {
			ins.x = i64(read_uleb32(d)) // align
			ins.y = i64(read_uleb32(d)) // offset
		} else if (op == OP_MEMORY_SIZE) | (op == OP_MEMORY_GROW) {
			ins.x = i64(read_byte(d)) // reserved zero byte
		} else if op_no_immediate(op) {
			// no operands
		} else {
			d.ok = false
			array_push(a, instrs, &ins)
			break
		}

		array_push(a, instrs, &ins)

		if op == OP_END {
			if depth == 0 do break
			depth -= 1
			continue
		}
		if (op == OP_BLOCK) | (op == OP_LOOP) | (op == OP_IF) {
			depth += 1
		}
	}
}

// op_no_immediate reports whether `op` is a known opcode that carries no
// immediate operand: the simple control ops plus the numeric range.
op_no_immediate :: proc(op: int) -> bool {
	if op == OP_UNREACHABLE do return true
	if op == OP_NOP do return true
	if op == OP_ELSE do return true
	if op == OP_END do return true
	if op == OP_RETURN do return true
	if op == OP_DROP do return true
	if op == OP_SELECT do return true
	if (op >= OP_NUM_LO) & (op <= OP_NUM_HI) do return true
	return false
}
