package main

// A WebAssembly (MVP) binary-format decoder and interpreter exercised end to
// end. `main` feeds a handful of hand-crafted, well-formed `.wasm` modules
// through the decoder, dumps the resulting AST (types, functions, memory,
// globals, exports, data and per-function code with a flat, immediate-carrying
// instruction listing), then runs each module's exported functions through the
// stack interpreter (see interp.odin) with fixed arguments. Both the printed
// results and the numeric returns are folded into a checksum returned as the
// exit code, so stdout and the exit value participate in the parity check.
//
// The AST is laid out for the interpreter: signatures resolve by index, code
// bodies are flat instruction streams, and everything lives in an arena
// referenced by integer offset. The whole program stays within the subset of
// Odin the JIT frontend accepts (see sibling files and the lua test program).

// The modules are stored as byte strings (the JIT frontend has no constant
// array literals, but byte-indexable string constants work exactly like the lua
// test program's source strings).

// add: (i32, i32) -> i32 { local.get 0; local.get 1; i32.add }
WASM_ADD :: "\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x07\x01\x60\x02\x7f\x7f\x01\x7f\x03\x02\x01\x00\x07\x07\x01\x03\x61\x64\x64\x00\x00\x0a\x09\x01\x07\x00\x20\x00\x20\x01\x6a\x0b"

// fact: iterative factorial (i64)->i64 with two i64 locals; block/loop/br/br_if.
WASM_FACT :: "\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x06\x01\x60\x01\x7e\x01\x7e\x03\x02\x01\x00\x07\x08\x01\x04\x66\x61\x63\x74\x00\x00\x0a\x2d\x01\x2b\x01\x02\x7e\x42\x01\x21\x01\x20\x00\x21\x02\x02\x40\x03\x40\x20\x02\x42\x00\x53\x0d\x01\x20\x01\x20\x02\x7e\x21\x01\x20\x02\x42\x01\x7d\x21\x02\x0c\x00\x0b\x0b\x20\x01\x0b"

// mem: memory + mutable global + active data segment + load/store/global ops.
WASM_MEM :: "\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x06\x01\x60\x01\x7f\x01\x7f\x03\x02\x01\x00\x05\x04\x01\x01\x01\x04\x06\x06\x01\x7f\x01\x41\x2a\x0b\x07\x0e\x02\x03\x6d\x65\x6d\x02\x00\x04\x6c\x6f\x61\x64\x00\x00\x0b\x08\x01\x00\x41\x00\x0b\x02\x48\x69\x0a\x10\x01\x0e\x00\x20\x00\x28\x02\x00\x23\x00\x6a\x24\x00\x23\x00\x0b"

// run_module_impl decodes, dumps and executes one module. When `auto` is set the
// generic all-exports driver is used (for the compiler-generated blobs whose
// export names are not known ahead of time); otherwise the named driver picks
// the fixed arguments for the hand-crafted add/fact/mem modules.
run_module_impl :: proc(name: string, data: string, auto: bool) -> int {
	print("=== ")
	print(name)
	print(" ===\n")

	a: Arena = {}
	arena_init(&a, ARENA_RESERVE)
	m: Module = {}
	module_init(&m)

	d: Decoder = {}
	d.data = data
	d.pos = 0
	d.ok = true

	decode_module(&d, &a, &m)
	dump_module(&a, &m, data)
	print("\n")

	racc: i64 = 0
	if auto {
		racc = w_run_auto(&a, &m, data)
	} else {
		racc = w_run(name, &a, &m, data)
	}
	print("\n")

	acc := int(racc)
	acc += m.section_count * 3
	acc += m.types.len * 5
	acc += m.funcs.len * 7
	acc += m.exports.len * 11
	acc += m.globals.len * 13
	acc += m.mems.len * 17
	acc += m.datas.len * 19
	acc += m.imports.len * 23

	i := 0
	for {
		if i >= m.codes.len do break
		c := array_at(&m.codes, i)
		acc += c.instr_count * 2
		acc += c.local_total
		acc += c.body_size
		i += 1
	}

	ok_v := 0
	if m.ok do ok_v = 1
	acc += ok_v * 29
	return acc
}

run_module :: proc(name: string, data: string) -> int {
	return run_module_impl(name, data, false)
}

// run_module_auto drives a compiler-generated blob through the generic
// all-exports interpreter path. Used by the generated.odin runner.
run_module_auto :: proc(name: string, data: string) -> int {
	return run_module_impl(name, data, true)
}

main :: proc() -> int {
	acc := 0

	acc += run_module("add", WASM_ADD)
	acc += run_module("fact", WASM_FACT)
	acc += run_module("mem", WASM_MEM)

	// The remaining modules are Odin programs compiled to wasm by generate.sh and
	// embedded into generated.odin; run_generated drives every export of each.
	acc += run_generated()

	print("checksum = ")
	print_int(i64(acc))
	print("\n")

	return acc % 256
}
