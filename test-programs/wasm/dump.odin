package main

// Pretty printer for a decoded module. Output is plain and fully deterministic
// so it can be diffed byte-for-byte between the reference compiler and the JIT.

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
		v := array_at(&m.valtypes, ft.param_off + i)
		if i > 0 do print(" ")
		print(valtype_name(v^))
		i += 1
	}
	print(") -> (")
	j := 0
	for {
		if j >= ft.result_count do break
		v := array_at(&m.valtypes, ft.result_off + j)
		if j > 0 do print(" ")
		print(valtype_name(v^))
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

	print("types ")
	print_int(i64(m.types.len))
	print("\n")
	ti := 0
	for {
		if ti >= m.types.len do break
		ft := array_at(&m.types, ti)
		print_indent(1)
		print_int(i64(ti))
		print(": ")
		print_functype(a, m, ft)
		print("\n")
		ti += 1
	}

	if m.imports.len > 0 {
		print("imports ")
		print_int(i64(m.imports.len))
		print("\n")
		ii := 0
		for {
			if ii >= m.imports.len do break
			im := array_at(&m.imports, ii)
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
			ii += 1
		}
	}

	print("funcs ")
	print_int(i64(m.funcs.len))
	print("\n")
	fi := 0
	for {
		if fi >= m.funcs.len do break
		fti := array_at(&m.funcs, fi)
		print_indent(1)
		print_int(i64(fi))
		print(": type ")
		print_int(i64(fti^))
		print("\n")
		fi += 1
	}

	if m.mems.len > 0 {
		print("memory ")
		print_int(i64(m.mems.len))
		print("\n")
		mi := 0
		for {
			if mi >= m.mems.len do break
			mem := array_at(&m.mems, mi)
			print_indent(1)
			print_int(i64(mi))
			print(": min ")
			print_int(i64(mem.min))
			if mem.has_max == 1 {
				print(" max ")
				print_int(i64(mem.max))
			}
			print("\n")
			mi += 1
		}
	}

	if m.globals.len > 0 {
		print("globals ")
		print_int(i64(m.globals.len))
		print("\n")
		gi := 0
		for {
			if gi >= m.globals.len do break
			g := array_at(&m.globals, gi)
			print_indent(1)
			print_int(i64(gi))
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
			gi += 1
		}
	}

	print("exports ")
	print_int(i64(m.exports.len))
	print("\n")
	ei := 0
	for {
		if ei >= m.exports.len do break
		e := array_at(&m.exports, ei)
		print_indent(1)
		print("\"")
		print_name_bytes(data, e.nm_off, e.nm_len)
		print("\" ")
		print(ext_kind_name(e.kind))
		print(" ")
		print_int(i64(e.index))
		print("\n")
		ei += 1
	}

	if m.datas.len > 0 {
		print("data ")
		print_int(i64(m.datas.len))
		print("\n")
		di := 0
		for {
			if di >= m.datas.len do break
			ds := array_at(&m.datas, di)
			print_indent(1)
			print_int(i64(di))
			print(": mem ")
			print_int(i64(ds.mem_index))
			print(" offset ")
			print_const_expr(ds.off_op, ds.off_val)
			print(" bytes ")
			print_int(i64(ds.bytes_len))
			print("\n")
			di += 1
		}
	}

	if m.start_func >= 0 {
		print("start func ")
		print_int(i64(m.start_func))
		print("\n")
	}

	print("code ")
	print_int(i64(m.codes.len))
	print("\n")
	ci := 0
	for {
		if ci >= m.codes.len do break
		c := array_at(&m.codes, ci)
		print_indent(1)
		print("func ")
		print_int(i64(ci))
		print(": locals ")
		print_int(i64(c.local_total))
		print(" body ")
		print_int(i64(c.body_size))
		print("\n")
		li := 0
		for {
			if li >= c.local_count do break
			loc := array_at(&m.locals, c.local_off + li)
			print_indent(2)
			print("local x")
			print_int(i64(loc.count))
			print(" ")
			print(valtype_name(loc.valtype))
			print("\n")
			li += 1
		}
		insi := 0
		for {
			if insi >= c.instr_count do break
			ins := array_at(&m.instrs, c.instr_off + insi)
			print_indent(2)
			print_int(i64(insi))
			print(": ")
			print_instr(ins)
			print("\n")
			insi += 1
		}
		ci += 1
	}

	if m.ok {
		print("status ok\n")
	} else {
		print("status error\n")
	}
}
