#+build !wasm32
package main

import "base:runtime"
import "core:odin/ast"
import "core:odin/parser"
import "core:os"

foreign import "system:c"

foreign c {
	afl_fuzz_run :: proc() ---
}

fuzz_main :: proc() {
	if len(os.args) == 2 {
		source, rerr := os.read_entire_file(os.args[1], context.allocator)
		if rerr != nil do os.exit(2)
		fuzz_one(raw_data(source), uint(len(source)))
		return
	}

	// Run all one-time init (parser warmup, fmt registration, first dlopen)
	// before the persistent loop forks, or the first testcase calibrated in
	// every fresh persistent process inherits the extra coverage and afl-fuzz
	// reports calibration instability.
	warmup := "package main\nmain :: proc() -> int { return 0 }\n"
	fuzz_one(raw_data(warmup), len(warmup))

	afl_fuzz_run()
}

@(export)
fuzz_one :: proc "c" (data: [^]u8, size: uint) {
	context = runtime.default_context()
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)

	source := string(data[:size])

	p := parser.Parser{}
	f := ast.File {
		src      = source,
		fullpath = "fuzz",
	}
	if !parser.parse_file(&p, &f) {
		return
	}

	run_test(nil, "fuzz", source, 0)
}
