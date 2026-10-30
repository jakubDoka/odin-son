#+build !wasm32
package odin_son

import "../bac"
import "../utils/arna"
import "core:debug/trace"
import "core:fmt"
import "core:log"
import "core:os"
import "core:reflect"
import "core:strings"
import "core:time"
import "typecheck"

Compile_Config :: struct {
	input:        string,
	output:       string,
	source:       string,
	root:         string,
	level:        Opt_Level,
	target:       Target_ID,
	show_timings: bool,
	show_stats:   bool,
	check:        bool,
	debug:        bool,
}

DEFAULT_COMPILE_CONFIG :: Compile_Config {
	output = "a.o",
	level  = OPT_LEVELS[len(OPT_LEVELS) - 1],
}

main :: proc() {
	when #config(FUZZ, false) {
		fuzz_main()
		return
	}

	when ODIN_DEBUG {
		context.assertion_failure_proc = trace.assertion_failure_proc
	}
	context.logger = log.create_console_logger()
	context.logger.options &= ~{.Time, .Date, .Level, .Procedure}
	bac.init_custom_fmt()
	typecheck.init_type_fmt()

	config := DEFAULT_COMPILE_CONFIG
	levels := OPT_LEVELS

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
			config.output = args[i]
		case arg == "-show-timings":
			config.show_timings = true
		case arg == "-show-stats":
			config.show_stats = true
		case arg == "-check":
			config.check = true
		case arg == "-debug" || arg == "-g":
			config.debug = true
		case strings.has_prefix(arg, "-target:"):
			name := arg[len("-target:"):]
			found := false
			for tar, id in TARGETS {
				if tar.name == name {
					config.target = id
					found = true
					break
				}
			}
			if !found {
				fmt.eprintfln("unknown target: %v", name)
				fmt.eprint("available targets:")
				for tar in TARGETS {
					fmt.eprintf(" %v", tar.name)
				}
				fmt.eprintln()
				os.exit(1)
			}
		case strings.has_prefix(arg, "-o:"):
			name := arg[len("-o:"):]
			found := false
			for lvl in levels {
				if lvl.name == name {
					config.level = lvl
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
			if config.input != "" {
				fmt.eprintln("multiple input files are not supported")
				os.exit(1)
			}
			config.input = arg
		}
		i += 1
	}

	if config.input == "" {
		fmt.eprintln("usage: jit <entry.odin> [-o output.o] [-O:<level>] [-debug]")
		os.exit(1)
	}

	config.root = os.get_env("ODIN_ROOT", context.temp_allocator)

	artifact, ok := compile(config)
	if !ok do os.exit(1)
	defer delete(artifact)
	if !config.check {
		if err := os.write_entire_file(config.output, artifact); err != nil {
			fmt.eprintfln("failed to write %v: %v", config.output, err)
			os.exit(1)
		}
	}
}

compile :: proc(
	config: Compile_Config,
	allocator := context.allocator,
) -> (
	artifact: []u8,
	ok: bool,
) {

	types: typecheck.Types
	types.mems.prc.reserved = 4096 * 16384
	types.mems.regalloc.reserved = 4096 * 8192
	types.mems.scratch.reserved = 4096 * 2048
	types.mems.code.reserved = 4096 * 4096
	types.mems.constants.reserved = 4096 * 4096
	types.mems.reloc.reserved = 4096 * 2048
	types.mems.sloc.reserved = 4096 * 4096
	types.mems.cfi.reserved = 4096 * 2048
	types.mems.dbg_loc.reserved = 4096 * 2048
	types.mems.type.reserved = 1024 * 1024 * 128

	typecheck.types_init(&types)
	defer typecheck.types_deinit(&types)

	level := config.level
	target := TARGETS[config.target]

	global_ctx: typecheck.Global_Ctx
	global_ctx.root = config.root

	if false {
		for col in ([]string{"base", "core", "vendor"}) {
			global_ctx.collections[col], _ = os.join_path(
				{global_ctx.root, col},
				context.temp_allocator,
			)
			_, err := os.stat(global_ctx.collections[col], context.temp_allocator)
			fmt.assertf(err == nil, "%v: %v", global_ctx.collections[col], err)
		}
	}

	ctx: Gen_Ctx
	if config.show_stats {
		stats: bac.Stats
		ctx.stats = &stats
	}
	ctx.types = &types
	ctx.global = &global_ctx
	ctx.target = target
	ctx.check = config.check
	ctx.prc.has_dbg = config.debug
	ctx.ralloc_mode = level.ralloc_mode
	ctx.errors = os.to_writer(os.stderr)

	previous_prc := bac.current_prc
	bac.current_prc = &ctx
	defer bac.current_prc = previous_prc

	times: struct {
		load:    time.Duration,
		check:   time.Duration,
		emit:    time.Duration,
		inlinet: time.Duration,
		flush:   time.Duration,
	}

	{time.SCOPED_TICK_DURATION(&times.load)
		if config.source != "" {
			init_single_file_program(&ctx, config.source)
		} else {
			load_program(&ctx, config.input)
		}
	}

	{time.SCOPED_TICK_DURATION(&times.check)
		typecheck.typecheck_program(&ctx)}

	if ctx.error_cnt > 0 do return {}, false

	emit_ctx := bac.Codegen_Emit_Ctx {
		lib_calls = {copy = {id = MEMCPY_ID}, set = {id = MEMSET_ID}},
	}

	{time.SCOPED_TICK_DURATION(&times.emit)
		for _, j in ctx.procs {
			emit_proc(&ctx, j, level, &emit_ctx)
		}}

	if .Inline in level.flags {
		{time.SCOPED_TICK_DURATION(&times.inlinet)
			inline_and_optimize(&ctx, &emit_ctx)}
	}

	{time.SCOPED_TICK_DURATION(&times.flush)
		if ctx.check {
			for prc in ctx.procs {
				if len(prc.out.code) == 0 do continue

				fmt.eprintfln("%v: anal errors:", prc.name)
				cursor := string(prc.out.code)
				for line in strings.split_lines_iterator(&cursor) {
					fmt.eprintfln("  %v", line)
				}
			}
		} else {
			artifact = target.emit(&ctx, allocator)
		}
	}

	if config.show_timings {
		sum: time.Duration
		for tf in reflect.struct_fields_zipped(type_of(times)) {
			vl := reflect.struct_field_value(times, tf).(time.Duration)
			sum += vl
		}

		for tf in reflect.struct_fields_zipped(type_of(times)) {
			vl := reflect.struct_field_value(times, tf).(time.Duration)
			fmt.eprintfln(
				"% 10v: - % 6f%% - %v ",
				tf.name,
				(f64(vl) / f64(sum)) * 100,
				vl,
			)
		}
	}

	if config.show_stats {
		log_stats(&ctx)
	}
	return artifact, true
}

log_stats :: proc(ctx: ^bac.Stats) {
	padded :: proc(vl: string, width: int) -> string {
		return strings.concatenate(
			{
				vl,
				strings.repeat(" ", max(width - len(vl), 0), context.temp_allocator),
			},
			context.temp_allocator,
		)
	}

	max_name_len := 0
	for enm in reflect.enum_fields_zipped(bac.Efficiency_Stat_Kind) {
		max_name_len = max(max_name_len, len(enm.name))
	}

	fmt.eprintfln(
		"  %s %s %s %s",
		padded("name", max_name_len),
		padded("total", 8),
		padded("ideal", 8),
		padded("t/i", 8),
	)
	for eff, kind in ctx.efficiency {
		name := reflect.enum_field_names(bac.Efficiency_Stat_Kind)[kind]
		fmt.eprintfln(
			"  %s % -8d % -8d % -8f",
			padded(name, max_name_len),
			eff.total,
			eff.ideal,
			f64(eff.total) / f64(eff.ideal),
		)
	}
}
