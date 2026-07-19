#+build !wasm32
package main

import "backend"
import "backend/x64"
import "core:fmt"
import "core:log"
import "core:os"
import "core:reflect"
import "core:strings"
import "core:time"
import "typecheck"
import "vendored/gam/util/arna"
import "vendored/gam/util/hot"

main :: proc() {
	context.assertion_failure_proc = hot.init_trace()
	context.logger = log.create_console_logger()
	context.logger.options &= ~{.Time, .Date, .Level, .Procedure}

	input: string
	output := "a.o"

	levels := OPT_LEVELS
	level := levels[len(levels) - 1]
	show_timings := false
	show_stats := false

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
		case arg == "-show-timings":
			show_timings = true
		case arg == "-show-stats":
			show_stats = true
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

	times: struct {
		load:    time.Duration,
		check:   time.Duration,
		emit:    time.Duration,
		inlinet: time.Duration,
		flush:   time.Duration,
	}

	{time.SCOPED_TICK_DURATION(&times.load)
		load_program(&ctx, input)}

	{time.SCOPED_TICK_DURATION(&times.check)
		typecheck.typecheck_program(&ctx)}

	emit_ctx := backend.Codegen_Emit_Ctx {
		lib_calls = {copy = {id = MEMCPY_ID}, set = {id = MEMSET_ID}},
	}

	clear(&ctx.globals)
	emit_module_globals(&ctx)

	{time.SCOPED_TICK_DURATION(&times.emit)
		for prc, i in ctx.procs {
			if len(prc.poly_names) != len(prc.poly_values) do continue
			emit_proc(&ctx, i, level, &emit_ctx)
		}}

	if .Inline in level.flags {
		{time.SCOPED_TICK_DURATION(&times.inlinet)
			inline_and_optimize(&ctx, &emit_ctx)}
	}

	{time.SCOPED_TICK_DURATION(&times.flush)
		elf := emit_elf(&ctx)

		if werr := os.write_entire_file(output, elf); werr != nil {
			fmt.eprintfln("failed to write %v: %v", output, werr)
			os.exit(1)
		}
	}

	if show_timings {
		for tf in reflect.struct_fields_zipped(type_of(times)) {
			vl := reflect.struct_field_value(times, tf).(time.Duration)
			fmt.eprintfln("% 10v: %v", tf.name, vl)
		}
	}

	if show_stats {
		log_stats(&ctx)
	}
}
