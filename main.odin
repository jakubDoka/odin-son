#+build !wasm32
package main

import "backend"
import "backend/x64"
import "typecheck"
import "core:fmt"
import "core:log"
import "core:os"
import "core:strings"
import "vendored/gam/util/arna"
import "vendored/gam/util/hot"

main :: proc() {
	context.assertion_failure_proc = hot.init_trace()
	context.logger = log.create_console_logger()

	input: string
	output := "a.o"

	levels := OPT_LEVELS
	level := levels[len(levels) - 1]

	root := os.get_env("ODIN_ROOT", context.temp_allocator)

	args := os.args[1:]
	i := 0
	for i < len(args) {
		arg := args[i]
		switch {
		case arg == "-o":
			i += 1
			if i >= len(args) {
				fmt.eprintln("missing argument to -o")
				os.exit(1)
			}
			output = args[i]
		case strings.has_prefix(arg, "-O:"):
			name := arg[len("-O:"):]
			found := false
			for lvl in levels {
				if lvl.name == name {
					level = lvl
					found = true
					break
				}
			}
			if !found {
				fmt.eprintfln("unknown optimization level: %v", name)
				fmt.eprint("available levels:")
				for lvl in levels {
					fmt.eprintf(" %v", lvl.name)
				}
				fmt.eprintln()
				os.exit(1)
			}
		case len(arg) > 0 && arg[0] == '-':
			fmt.eprintfln("unknown flag: %v", arg)
			os.exit(1)
		case:
			if input != "" {
				fmt.eprintln("multiple input files are not supported")
				os.exit(1)
			}
			input = arg
		}
		i += 1
	}

	if input == "" {
		fmt.eprintln("usage: jit <entry.odin> [-o output.o] [-O:<level>]")
		os.exit(1)
	}

	arna.scratch[0].reserved = 64 * 1024 * 1024
	arna.scratch[1].reserved = 64 * 1024 * 1024

	types: typecheck.Types
	types.mems.graph.reserved = 4096 * 16384
	types.mems.regalloc.reserved = 4096 * 8192
	types.mems.scratch.reserved = 4096 * 2048
	types.mems.code.reserved = 4096 * 4096
	types.mems.reloc.reserved = 4096 * 2048
	types.mems.type.reserved = 4096 * 8192

	typecheck.types_init(&types)
	defer typecheck.types_deinit(&types)

	backend.init_custom_fmt()
	typecheck.init_type_fmt()

	global_ctx: typecheck.Global_Ctx
	global_ctx.root = root

	for col in ([]string{"base", "core", "vendor"}) {
		global_ctx.collections[col], _ = os.join_path(
			{global_ctx.root, col},
			context.temp_allocator,
		)
		_, err := os.stat(global_ctx.collections[col], context.temp_allocator)
		fmt.assertf(err == nil, "%v: %v", global_ctx.collections[col], err)
	}

	ctx: Gen_Ctx
	ctx.types = &types
	ctx.global = &global_ctx
	ctx.cc = &x64.X64_SYSTEMV_CC
	ctx.target_spec = &x64.SPEC

	load_program(&ctx, input)
	typecheck.typecheck_program(&ctx)

	emit_ctx := backend.Codegen_Emit_Ctx {
		lib_calls = {copy = {id = MEMCPY_ID}, set = {id = MEMSET_ID}},
	}

	clear(&ctx.globals)
	emit_module_globals(&ctx)

	for prc, i in ctx.procs {
		if len(prc.poly_names) != len(prc.poly_values) do continue
		emit_proc(&ctx, i, level, &emit_ctx)
	}

	if .Inline in level.flags {
		inline_and_optimize(&ctx, &emit_ctx)
	}

	elf := emit_elf(&ctx)

	if werr := os.write_entire_file(output, elf); werr != nil {
		fmt.eprintfln("failed to write %v: %v", output, werr)
		os.exit(1)
	}
}
