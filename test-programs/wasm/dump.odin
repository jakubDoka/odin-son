package main

// Pretty printer for a decoded module. Output is plain and fully deterministic
// so it can be diffed byte-for-byte between the reference compiler and the JIT.
//
// Each section is dumped by its own small procedure. This is deliberate: a
// single monolithic dump procedure grows large enough to trip a JIT code
// generation bug, whereas the small per-section helpers compile cleanly.

print_name_bytes :: proc(data: string, off: int, length: int) {
	i := 0
	for {
		if i >= length do break
		if off + i >= len(data) do break
		print_char(data[off + i])
		i += 1
	}
}

print_functype :: proc(a: ^Arena, m: ^Module, ft: ^FuncType) {
	print("(")
	i := 0
	for {
		if i >= ft.param_count do break
		v: int = 0
		array_get(a, &m.valtypes, ft.param_off + i, &v)
		if i > 0 do print(" ")
		print(valtype_name(v))
		i += 1
	}
	print(") -> (")
	j := 0
	for {
		if j >= ft.result_count do break
		v: int = 0
		array_get(a, &m.valtypes, ft.result_off + j, &v)
		if j > 0 do print(" ")
		print(valtype_name(v))
		j += 1
	}
	print(")")
}

print_instr :: proc(ins: ^Instr) {
	op := ins.op
	print(opcode_name(op))
	if (op == OP_BLOCK) | (op == OP_LOOP) | (op == OP_IF) {
		print(" ")
		print(valtype_name(int(ins.x)))
	} else if (op == OP_BR) | (op == OP_BR_IF) {
		print(" ")
		print_int(ins.x)
	} else if op == OP_CALL {
		print(" ")
		print_int(ins.x)
	} else if (op >= OP_LOCAL_GET) & (op <= OP_GLOBAL_SET) {
		print(" ")
		print_int(ins.x)
	} else if (op == OP_I32_CONST) | (op == OP_I64_CONST) {
		print(" ")
		print_int(ins.x)
	} else if (op >= OP_LOAD_LO) & (op <= OP_STORE_HI) {
		print(" align ")
		print_int(ins.x)
		print(" offset ")
		print_int(ins.y)
	} else if op == 0 {
		// keep unknown/error opcode visible
		print(" ?")
	}
}

print_const_expr :: proc(op: int, val: i64) {
	print(opcode_name(op))
	if (op == OP_I32_CONST) | (op == OP_I64_CONST) | (op == OP_GLOBAL_GET) {
		print(" ")
		print_int(val)
	}
}

dump_types :: proc(a: ^Arena, m: ^Module) {
	print("types ")
	print_int(i64(m.types.len))
	print("\n")
	i := 0
	for {
		if i >= m.types.len do break
		ft: FuncType = {}
		array_get(a, &m.types, i, &ft)
		print_indent(1)
		print_int(i64(i))
		print(": ")
		print_functype(a, m, &ft)
		print("\n")
		i += 1
	}
}

dump_imports :: proc(a: ^Arena, m: ^Module, data: string) {
	if m.imports.len == 0 do return
	print("imports ")
	print_int(i64(m.imports.len))
	print("\n")
	i := 0
	for {
		if i >= m.imports.len do break
		im: Import = {}
		array_get(a, &m.imports, i, &im)
		print_indent(1)
		print("\"")
		print_name_bytes(data, im.mod_off, im.mod_len)
		print(".")
		print_name_bytes(data, im.nm_off, im.nm_len)
		print("\" ")
		print(ext_kind_name(im.kind))
		print(" ")
		print_int(i64(im.index))
		print("\n")
		i += 1
	}
}

dump_funcs :: proc(a: ^Arena, m: ^Module) {
	print("funcs ")
	print_int(i64(m.funcs.len))
	print("\n")
	i := 0
	for {
		if i >= m.funcs.len do break
		ti: int = 0
		array_get(a, &m.funcs, i, &ti)
		print_indent(1)
		print_int(i64(i))
		print(": type ")
		print_int(i64(ti))
		print("\n")
		i += 1
	}
}

dump_memory :: proc(a: ^Arena, m: ^Module) {
	if m.mems.len == 0 do return
	print("memory ")
	print_int(i64(m.mems.len))
	print("\n")
	i := 0
	for {
		if i >= m.mems.len do break
		mem: Memory = {}
		array_get(a, &m.mems, i, &mem)
		print_indent(1)
		print_int(i64(i))
		print(": min ")
		print_int(i64(mem.min))
		if mem.has_max == 1 {
			print(" max ")
			print_int(i64(mem.max))
		}
		print("\n")
		i += 1
	}
}

dump_globals :: proc(a: ^Arena, m: ^Module) {
	if m.globals.len == 0 do return
	print("globals ")
	print_int(i64(m.globals.len))
	print("\n")
	i := 0
	for {
		if i >= m.globals.len do break
		g: Global = {}
		array_get(a, &m.globals, i, &g)
		print_indent(1)
		print_int(i64(i))
		print(": ")
		if g.mutable == 1 {
			print("mut ")
		} else {
			print("const ")
		}
		print(valtype_name(g.valtype))
		print(" = ")
		print_const_expr(g.init_op, g.init_val)
		print("\n")
		i += 1
	}
}

dump_exports :: proc(a: ^Arena, m: ^Module, data: string) {
	print("exports ")
	print_int(i64(m.exports.len))
	print("\n")
	i := 0
	for {
		if i >= m.exports.len do break
		e: Export = {}
		array_get(a, &m.exports, i, &e)
		print_indent(1)
		print("\"")
		print_name_bytes(data, e.nm_off, e.nm_len)
		print("\" ")
		print(ext_kind_name(e.kind))
		print(" ")
		print_int(i64(e.index))
		print("\n")
		i += 1
	}
}

dump_data :: proc(a: ^Arena, m: ^Module) {
	if m.datas.len == 0 do return
	print("data ")
	print_int(i64(m.datas.len))
	print("\n")
	i := 0
	for {
		if i >= m.datas.len do break
		ds: Data = {}
		array_get(a, &m.datas, i, &ds)
		print_indent(1)
		print_int(i64(i))
		print(": mem ")
		print_int(i64(ds.mem_index))
		print(" offset ")
		print_const_expr(ds.off_op, ds.off_val)
		print(" bytes ")
		print_int(i64(ds.bytes_len))
		print("\n")
		i += 1
	}
}

dump_code_locals :: proc(a: ^Arena, m: ^Module, c: ^Code) {
	li := 0
	for {
		if li >= c.local_count do break
		loc: Local = {}
		array_get(a, &m.locals, c.local_off + li, &loc)
		print_indent(2)
		print("local x")
		print_int(i64(loc.count))
		print(" ")
		print(valtype_name(loc.valtype))
		print("\n")
		li += 1
	}
}

dump_code_instrs :: proc(a: ^Arena, m: ^Module, c: ^Code) {
	ii := 0
	for {
		if ii >= c.instr_count do break
		ins: Instr = {}
		array_get(a, &m.instrs, c.instr_off + ii, &ins)
		print_indent(2)
		print_int(i64(ii))
		print(": ")
		print_instr(&ins)
		print("\n")
		ii += 1
	}
}

dump_code :: proc(a: ^Arena, m: ^Module) {
	print("code ")
	print_int(i64(m.codes.len))
	print("\n")
	i := 0
	for {
		if i >= m.codes.len do break
		c: Code = {}
		array_get(a, &m.codes, i, &c)
		print_indent(1)
		print("func ")
		print_int(i64(i))
		print(": locals ")
		print_int(i64(c.local_total))
		print(" body ")
		print_int(i64(c.body_size))
		print("\n")
		dump_code_locals(a, m, &c)
		dump_code_instrs(a, m, &c)
		i += 1
	}
}

dump_module :: proc(a: ^Arena, m: ^Module, data: string) {
	if m.ok {
		print("magic ok version ")
	} else {
		print("magic/decode ERROR version ")
	}
	print_uint(u64(m.version))
	print("\n")

	print("sections ")
	print_int(i64(m.section_count))
	print("\n")

	dump_types(a, m)
	dump_imports(a, m, data)
	dump_funcs(a, m)
	dump_memory(a, m)
	dump_globals(a, m)
	dump_exports(a, m, data)
	dump_data(a, m)

	if m.start_func >= 0 {
		print("start func ")
		print_int(i64(m.start_func))
		print("\n")
	}

	dump_code(a, m)

	if m.ok {
		print("status ok\n")
	} else {
		print("status error\n")
	}
}
