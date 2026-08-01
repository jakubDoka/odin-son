#+build !wasm32
package main

import "core:odin/ast"
import "core:odin/parser"
import "core:os"

// Entry point of the AFL++ target (`-define:FUZZ=true`). One process per input,
// the fork server does the rest. Build with `-define:NO_RUN=true` so the
// compiled machine code is never executed and only the compiler is under test.
fuzz_main :: proc() {
	if len(os.args) != 2 {
		os.write_string(os.stderr, "usage: jit <input.odin> (fuzz build)\n")
		os.exit(2)
	}

	source, rerr := os.read_entire_file(os.args[1], context.allocator)
	if rerr != nil do os.exit(2)

	// run_test asserts the source parses, so inputs the odin parser rejects
	// have to be dropped here instead of being reported as compiler crashes
	p := parser.Parser{}
	f := ast.File {
		src      = string(source),
		fullpath = "fuzz",
	}
	if !parser.parse_file(&p, &f) do os.exit(0)

	run_test(nil, "fuzz", string(source), 0)
}
