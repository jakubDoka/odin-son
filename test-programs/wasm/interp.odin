package main

// A small stack-based interpreter for the decoded module. It executes the flat
// instruction stream produced by the decoder directly, resolving block/loop/if
// nesting with a per-call control stack and a one-shot forward scan that pairs
// each structured opcode with its matching `else`/`end`.
//
// Interpreter state that needs an array (the operand stack, the mutable globals
// and the single linear memory) lives in package-level globals rather than a
// struct: modules run one at a time, and this keeps every array a plain
// top-level buffer (the shape the JIT frontend is exercised with elsewhere, see
// boids' `outbuf`) instead of a struct field. The arena and module are still
// threaded through as direct pointer parameters, exactly like the decoder, so
// no pointer-to-local is ever parked in a field and mutated through it.

WASM_PAGE :: 65536

// --- operand stack ----------------------------------------------------------

wstack: [512]i64
wsp: int

// --- mutable globals --------------------------------------------------------

wglobals: [64]i64

// --- single linear memory ---------------------------------------------------

wmem_off: int // arena offset of the memory reservation
wmem_size: int // committed (accessible) bytes
wmem_pages: int // committed pages
wmem_cap: int // reserved pages (grow ceiling)

// --- misc -------------------------------------------------------------------

wtrap: int // set on any out-of-bounds / stack fault
wifuncs: int // number of imported functions (index space offset)

wpush :: proc(v: i64) {
	if wsp >= 512 {
		wtrap = 1
		return
	}
	wstack[wsp] = v
	wsp += 1
}

wpop :: proc() -> i64 {
	if wsp <= 0 {
		wtrap = 1
		return 0
	}
	wsp -= 1
	return wstack[wsp]
}

// w_se32 reinterprets the low 32 bits of `x` as a signed i32, sign-extended back
// into an i64 so subsequent i32 ops see the canonical wrapped value.
w_se32 :: proc(x: i64) -> i64 {
	v := x & 0xffffffff
	if v >= 0x80000000 {
		v = v - 0x100000000
	}
	return v
}

w_mem_read :: proc(a: ^Arena, addr: int, n: int) -> i64 {
	if addr < 0 {
		wtrap = 1
		return 0
	}
	if addr + n > wmem_size {
		wtrap = 1
		return 0
	}
	p := Byte_Ptr(a.base + uintptr(wmem_off))
	r := u64(0)
	i := 0
	for {
		if i >= n do break
		r = r | (u64(p[addr + i]) << uint(i * 8))
		i += 1
	}
	return i64(r)
}

w_mem_write :: proc(a: ^Arena, addr: int, n: int, val: i64) {
	if addr < 0 {
		wtrap = 1
		return
	}
	if addr + n > wmem_size {
		wtrap = 1
		return
	}
	p := Byte_Ptr(a.base + uintptr(wmem_off))
	u := u64(val)
	i := 0
	for {
		if i >= n do break
		p[addr + i] = u8(u >> uint(i * 8))
		i += 1
	}
}

// w_str_eq compares two strings byte by byte.
//
// COMPILER BUG: `string == string` crashes the JIT (gen.odin `assert(dt !=
// .Void)` in to_rvalue_ty) because a string operand has no scalar data type.
// The module dispatch in w_run would otherwise read `if name == "add"`.
w_str_eq :: proc(x: string, y: string) -> bool {
	if len(x) != len(y) do return false
	i := 0
	for {
		if i >= len(x) do break
		if x[i] != y[i] do return false
		i += 1
	}
	return true
}

w_name_eq :: proc(data: string, off: int, length: int, s: string) -> bool {
	if length != len(s) do return false
	i := 0
	for {
		if i >= length do break
		if data[off + i] != s[i] do return false
		i += 1
	}
	return true
}

// w_find_func maps an exported function name to its function index, or -1.
w_find_func :: proc(a: ^Arena, m: ^Module, data: string, name: string) -> int {
	ei := 0
	for {
		if ei >= m.exports.len do break
		e: Export = {}
		array_get(a, &m.exports, ei, &e)
		if e.kind == EXT_FUNC {
			if w_name_eq(data, e.nm_off, e.nm_len, name) do return e.index
		}
		ei += 1
	}
	return -1
}

// w_init installs the module's globals, reserves and zeroes linear memory and
// copies every active data segment into place. Called once per module.
w_init :: proc(a: ^Arena, m: ^Module, data: string) {
	wsp = 0
	wtrap = 0

	gi := 0
	for {
		if gi >= m.globals.len do break
		g: Global = {}
		array_get(a, &m.globals, gi, &g)
		wglobals[gi] = g.init_val
		gi += 1
	}

	wmem_off = 0
	wmem_size = 0
	wmem_pages = 0
	wmem_cap = 0
	if m.mems.len > 0 {
		mem: Memory = {}
		array_get(a, &m.mems, 0, &mem)
		cap_pages := mem.min
		if mem.has_max == 1 do cap_pages = mem.max
		if cap_pages < mem.min do cap_pages = mem.min
		wmem_cap = cap_pages
		wmem_pages = mem.min
		wmem_size = mem.min * WASM_PAGE
		wmem_off = arena_alloc(a, cap_pages * WASM_PAGE, 8)

		p := Byte_Ptr(a.base + uintptr(wmem_off))
		n := cap_pages * WASM_PAGE
		z := 0
		for {
			if z >= n do break
			p[z] = 0
			z += 1
		}

		di := 0
		for {
			if di >= m.datas.len do break
			ds: Data = {}
			array_get(a, &m.datas, di, &ds)
			base := int(ds.off_val)
			pp := Byte_Ptr(a.base + uintptr(wmem_off))
			k := 0
			for {
				if k >= ds.bytes_len do break
				if base + k < wmem_size {
					pp[base + k] = data[ds.bytes_off + k]
				}
				k += 1
			}
			di += 1
		}
	}

	wifuncs = 0
	ii := 0
	for {
		if ii >= m.imports.len do break
		im: Import = {}
		array_get(a, &m.imports, ii, &im)
		if im.kind == EXT_FUNC do wifuncs += 1
		ii += 1
	}
}

// w_exec runs the body of function `func_index`. Parameters are consumed from
// the top of the operand stack (last parameter on top); the result, if any, is
// left on the stack.
w_exec :: proc(a: ^Arena, m: ^Module, func_index: int) {
	if wtrap != 0 do return
	defined := func_index - wifuncs
	if defined < 0 {
		wtrap = 1
		return
	}
	if defined >= m.codes.len {
		wtrap = 1
		return
	}

	type_index := 0
	array_get(a, &m.funcs, defined, &type_index)
	ft: FuncType = {}
	array_get(a, &m.types, type_index, &ft)
	c: Code = {}
	array_get(a, &m.codes, defined, &c)

	locals: [128]i64 = {}
	nparams := ft.param_count
	pi := nparams - 1
	for {
		if pi < 0 do break
		locals[pi] = wpop()
		pi -= 1
	}

	// Pair each block/loop/if with its matching else/end in one forward scan.
	match_end: [256]int = {}
	match_else: [256]int = {}
	zi := 0
	for {
		if zi >= c.instr_count do break
		match_else[zi] = -1
		zi += 1
	}
	scan: [256]int = {}
	ssp := 0
	si := 0
	for {
		if si >= c.instr_count do break
		ins: Instr = {}
		array_get(a, &m.instrs, c.instr_off + si, &ins)
		op := ins.op
		if (op == OP_BLOCK) | (op == OP_LOOP) | (op == OP_IF) {
			scan[ssp] = si
			ssp += 1
		} else if op == OP_ELSE {
			if ssp > 0 do match_else[scan[ssp - 1]] = si
		} else if op == OP_END {
			if ssp > 0 {
				ssp -= 1
				match_end[scan[ssp]] = si
			}
		}
		si += 1
	}

	// Control stack: one entry per currently-open structured region.
	ctl_kind: [128]int = {}
	ctl_head: [128]int = {}
	ctl_end: [128]int = {}
	depth := 0

	pc := 0
	for {
		if wtrap != 0 do break
		if pc >= c.instr_count do break
		ins: Instr = {}
		array_get(a, &m.instrs, c.instr_off + pc, &ins)
		op := ins.op

		if (op == OP_BLOCK) | (op == OP_LOOP) {
			ctl_kind[depth] = op
			ctl_head[depth] = pc
			ctl_end[depth] = match_end[pc]
			depth += 1
			pc += 1
			continue
		}
		if op == OP_IF {
			ctl_kind[depth] = op
			ctl_head[depth] = pc
			ctl_end[depth] = match_end[pc]
			depth += 1
			cnd := wpop()
			if cnd != 0 {
				pc += 1
			} else {
				el := match_else[pc]
				if el >= 0 {
					pc = el + 1
				} else {
					pc = match_end[pc]
				}
			}
			continue
		}
		if op == OP_ELSE {
			// reached only by falling out of a taken then-branch: skip the else
			if depth > 0 {
				pc = ctl_end[depth - 1]
			} else {
				pc += 1
			}
			continue
		}
		if op == OP_END {
			if depth == 0 do break // closes the function body
			depth -= 1
			pc += 1
			continue
		}
		if op == OP_BR {
			l := int(ins.x)
			tgt := depth - 1 - l
			if tgt < 0 {
				wtrap = 1
				break
			}
			if ctl_kind[tgt] == OP_LOOP {
				depth = tgt + 1
				pc = ctl_head[tgt] + 1
			} else {
				depth = tgt
				pc = ctl_end[tgt] + 1
			}
			continue
		}
		if op == OP_BR_IF {
			cnd := wpop()
			if cnd != 0 {
				l := int(ins.x)
				tgt := depth - 1 - l
				if tgt < 0 {
					wtrap = 1
					break
				}
				if ctl_kind[tgt] == OP_LOOP {
					depth = tgt + 1
					pc = ctl_head[tgt] + 1
				} else {
					depth = tgt
					pc = ctl_end[tgt] + 1
				}
				continue
			}
			pc += 1
			continue
		}
		if op == OP_RETURN do break
		if op == OP_CALL {
			w_exec(a, m, int(ins.x))
			pc += 1
			continue
		}
		if op == OP_UNREACHABLE {
			wtrap = 1
			break
		}

		// local.* ops read the per-call locals array, so they stay here.
		if op == OP_LOCAL_GET {
			wpush(locals[int(ins.x)])
			pc += 1
			continue
		}
		if op == OP_LOCAL_SET {
			locals[int(ins.x)] = wpop()
			pc += 1
			continue
		}
		if op == OP_LOCAL_TEE {
			v := wpop()
			locals[int(ins.x)] = v
			wpush(v)
			pc += 1
			continue
		}

		// Everything else is a pure operand-stack / memory / global op, handled
		// by w_simple; only the control-flow and local.* ops need to live here.
		if w_simple(a, op, ins.x, ins.y) == 1 {
			pc += 1
			continue
		}

		// Unknown / unsupported opcode: stop rather than silently skip.
		wtrap = 1
		break
	}
}

// w_simple executes an opcode that only touches the operand stack, the mutable
// globals and linear memory (no control flow, no per-call locals). It returns 1
// if `op` was handled and 0 otherwise.
w_simple :: proc(a: ^Arena, op: int, x: i64, y: i64) -> int {
	if op == OP_NOP do return 1
	if op == OP_DROP {
		_ = wpop()
		return 1
	}
	if op == OP_SELECT {
		cc := wpop()
		b := wpop()
		av := wpop()
		if cc != 0 {
			wpush(av)
		} else {
			wpush(b)
		}
		return 1
	}

	if op == OP_GLOBAL_GET {
		wpush(wglobals[int(x)])
		return 1
	}
	if op == OP_GLOBAL_SET {
		wglobals[int(x)] = wpop()
		return 1
	}

	if (op == OP_I32_CONST) | (op == OP_I64_CONST) {
		wpush(x)
		return 1
	}

	if op == 0x28 { // i32.load
		addr := int(wpop()) + int(y)
		wpush(w_se32(w_mem_read(a, addr, 4)))
		return 1
	}
	if op == 0x29 { // i64.load
		addr := int(wpop()) + int(y)
		wpush(w_mem_read(a, addr, 8))
		return 1
	}
	if op == 0x36 { // i32.store
		v := wpop()
		addr := int(wpop()) + int(y)
		w_mem_write(a, addr, 4, v)
		return 1
	}
	if op == 0x37 { // i64.store
		v := wpop()
		addr := int(wpop()) + int(y)
		w_mem_write(a, addr, 8, v)
		return 1
	}
	if op == OP_MEMORY_SIZE {
		wpush(i64(wmem_pages))
		return 1
	}
	if op == OP_MEMORY_GROW {
		n := int(wpop())
		old := wmem_pages
		newp := wmem_pages + n
		if (n >= 0) & (newp <= wmem_cap) {
			wmem_pages = newp
			wmem_size = newp * WASM_PAGE
			wpush(i64(old))
		} else {
			wpush(i64(-1))
		}
		return 1
	}

	if op == OP_I32_EQZ {
		av := w_se32(wpop())
		r: i64 = 0
		if av == 0 do r = 1
		wpush(r)
		return 1
	}
	if op == OP_I32_EQ {
		b := w_se32(wpop())
		av := w_se32(wpop())
		r: i64 = 0
		if av == b do r = 1
		wpush(r)
		return 1
	}
	if op == OP_I32_LT_S {
		b := w_se32(wpop())
		av := w_se32(wpop())
		r: i64 = 0
		if av < b do r = 1
		wpush(r)
		return 1
	}
	if op == OP_I64_EQZ {
		av := wpop()
		r: i64 = 0
		if av == 0 do r = 1
		wpush(r)
		return 1
	}
	if op == OP_I64_LE_S {
		b := wpop()
		av := wpop()
		r: i64 = 0
		if av <= b do r = 1
		wpush(r)
		return 1
	}

	if op == OP_I32_ADD {
		b := wpop()
		av := wpop()
		wpush(w_se32(av + b))
		return 1
	}
	if op == OP_I32_SUB {
		b := wpop()
		av := wpop()
		wpush(w_se32(av - b))
		return 1
	}
	if op == OP_I32_MUL {
		b := wpop()
		av := wpop()
		wpush(w_se32(av * b))
		return 1
	}
	if op == OP_I64_ADD {
		b := wpop()
		av := wpop()
		wpush(av + b)
		return 1
	}
	if op == OP_I64_SUB {
		b := wpop()
		av := wpop()
		wpush(av - b)
		return 1
	}
	if op == OP_I64_MUL {
		b := wpop()
		av := wpop()
		wpush(av * b)
		return 1
	}

	return 0
}

// w_finish runs the located function (params already pushed), prints the result
// or a trap marker, and returns the numeric result for the checksum fold.
w_finish :: proc(a: ^Arena, m: ^Module, fidx: int) -> i64 {
	if fidx < 0 {
		print("<no export>\n")
		return 0
	}
	w_exec(a, m, fidx)
	if wtrap != 0 {
		print("trap\n")
		return 0
	}
	r: i64 = 0
	if wsp > 0 do r = wpop()
	print_int(r)
	print("\n")
	return r
}

// w_invoke pushes `nargs` of {a0, a1}, runs the function at `fidx` and prints its
// result (via w_finish). The export lookup and the "  name(args) = " prefix are
// done by the caller so this driver stays at six integer parameters.
//
// COMPILER BUG: at -O:aggresive a seventh, stack-passed integer parameter is
// read incorrectly. The natural single driver
//   w_call(a, m, data, name, a0, a1, nargs)
// consumes all six SysV integer registers on a/m/data/name (each string is two
// words), spilling a0/a1/nargs to the stack; `nargs` then came back as 2 instead
// of 1, so fact/load ran with a bogus extra argument. Keeping the hot driver at
// six register words sidesteps it.
w_invoke :: proc(a: ^Arena, m: ^Module, fidx: int, a0: i64, a1: i64, nargs: int) -> i64 {
	if fidx < 0 {
		print("<no export>\n")
		return 0
	}
	wsp = 0
	wtrap = 0
	if nargs >= 1 do wpush(a0)
	if nargs >= 2 do wpush(a1)
	return w_finish(a, m, fidx)
}

// w_run sets up the runtime and drives the module's exported functions with a
// fixed, deterministic set of arguments so the results feed the parity check.
w_run :: proc(name: string, a: ^Arena, m: ^Module, data: string) -> i64 {
	if !m.ok do return 0
	print("run:\n")
	w_init(a, m, data)
	acc: i64 = 0
	if w_str_eq(name, "add") {
		print("  add(20, 22) = ")
		acc += w_invoke(a, m, w_find_func(a, m, data, "add"), 20, 22, 2)
	} else if w_str_eq(name, "fact") {
		print("  fact(6) = ")
		acc += w_invoke(a, m, w_find_func(a, m, data, "fact"), 6, 0, 1)
	} else if w_str_eq(name, "mem") {
		// two invocations exercise the persisted mutable global
		print("  load(1) = ")
		acc += w_invoke(a, m, w_find_func(a, m, data, "load"), 1, 0, 1)
		print("  load(1) = ")
		acc += w_invoke(a, m, w_find_func(a, m, data, "load"), 1, 0, 1)
	}
	return acc
}
