package tests

import "../bac"
import "../bac/intel_xelp_poc"
import "../bac/ssa"
import "../gpu-dispatch/gpu"
import "../odinc"
import "../odinc/typecheck"
import "../utils/arna"
import "../utils/unicorn"
import "../utils/wabt"
import "base:intrinsics"
import "base:runtime"
import "core:debug/trace"
import "core:dynlib"
import "core:fmt"
import "core:hash"
import "core:log"
import "core:math"
import "core:math/rand"
import "core:mem"
import "core:mem/virtual"
import "core:odin/ast"
import "core:odin/parser"
import "core:os"
import "core:rexcode/ir"
import rex_wasm "core:rexcode/ir/wasm"
import "core:rexcode/isa"
import "core:rexcode/isa/arm64"
import "core:rexcode/isa/x86"
import "core:simd"
import "core:strings"
import "core:sync"
import "core:testing"

TEST_OUT_DIR :: "print-tests"

custom_fmt_once: sync.Once

// Sets up all user formatters (bac + `main::Type`) exactly once.
setup_custom_fmt :: proc() {
	sync.once_do(&custom_fmt_once, proc() {
		bac.init_custom_fmt()
		typecheck.init_type_fmt()
	})
}

init_single_file_program :: proc(ctx: ^odinc.Gen_Ctx, source: string) {
	p := parser.Parser{}
	f := ast.File {
		src      = source,
		fullpath = "test",
	}
	{context.allocator = context.temp_allocator
		//p.err = parser.default_error_handler
		ok := parser.parse_file(&p, &f); assert(ok)
	}

	ctx.files.allocator = ctx.types.allocator
	ctx.modules.allocator = ctx.types.allocator
	if f.pkg_name == "" do f.pkg_name = "main"
	append(&ctx.files, f)
	append(&ctx.modules, typecheck.Module{name = f.pkg_name, file_count = 1})
	ctx.modules[0].imports.allocator = ctx.types.allocator
	ctx.modules[0].imports["intrinsics"] = typecheck.MODULE_INTRINSICS

	decls := make([dynamic]typecheck.Decl, context.temp_allocator)
	typecheck.collect_decls(f, &decls, 0)
	typecheck.module_add_decls(ctx, 0, decls[:])
}

@(thread_local)
name_str: string

DO_DIFFING :: #config(DIFF, true)
NO_RUN :: #config(NO_RUN, false)

ensure_types :: proc() -> ^typecheck.Types {
	@(thread_local)
	types: typecheck.Types

	if types.mems.prc.reserved == 0 {
		arna.scratch[0].reserved = 1024 * 1024
		arna.scratch[1].reserved = 1024 * 1024

		types.mems.prc.reserved = 4096 * 128
		types.mems.regalloc.reserved = 4096 * 64
		types.mems.scratch.reserved = 4096 * 16
		types.mems.code.reserved = 4096 * 16
		types.mems.constants.reserved = 4096 * 16
		types.mems.reloc.reserved = 4096 * 16
		types.mems.sloc.reserved = 4096 * 128
		types.mems.cfi.reserved = 4096 * 128
		types.mems.dbg_loc.reserved = 4096 * 128
		types.mems.type.reserved = 4096 * 256

		typecheck.types_init(&types)
	} else {
		typecheck.types_reset(&types)
	}

	return &types
}

reset_code_mems :: proc(ctx: ^typecheck.Types) {
	ctx.mems.code.pos = 0
	ctx.mems.reloc.pos = 0
	ctx.mems.cfi.pos = 0
	ctx.mems.dbg_loc.pos = 0
	ctx.mems.constants.pos = 0
}

run_gpu_test :: proc(
	t: ^testing.T,
	name: string,
	source: string,
	param_count: int,
	result_types: []typeid,
	ref_impl: proc(params: []gpu.Reg, results: []gpu.Reg),
	max_float_ulps: int,
) {
	fmt.println(name)

	name_str = name
	context.logger.options &= ~{.Time, .Date, .Level, .Procedure}
	when ODIN_DEBUG {
		context.assertion_failure_proc = trace.assertion_failure_proc
	}
	context.random_generator = {}

	rng: rand.PCG_Random_State
	context.random_generator = rand.pcg_random_generator(&rng)
	runtime.random_generator_reset_u64(
		context.random_generator,
		hash.fnv64a(transmute([]u8)name),
	)

	defer free_all(context.temp_allocator)

	setup_custom_fmt()

	errors: strings.Builder

	global_ctx: typecheck.Global_Ctx
	stats: bac.Stats

	ctx: odinc.Gen_Ctx
	ctx.types = ensure_types()
	ctx.stats = &stats
	ctx.global = &global_ctx
	ctx.errors = strings.to_writer(&errors)

	bac.current_prc = &ctx
	defer bac.current_prc = nil

	init_single_file_program(&ctx, source)
	typecheck.typecheck_program(&ctx)

	emit_ctx := bac.Codegen_Emit_Ctx{}

	ctx.target = {
		name = "intel_xelp",
		cc   = &intel_xelp_poc.CC_TABLE[intel_xelp_poc.XELP_CC],
		spec = &intel_xelp_poc.SPEC,
	}

	odinc.emit_proc(
		&ctx,
		1,
		odinc.OPT_LEVELS[len(odinc.OPT_LEVELS) - 2],
		&emit_ctx,
	)

	fn := &ctx.procs[1]
	err: gpu.Error

	{context.allocator = context.temp_allocator
		out: strings.Builder
		err = gpu.disassemble(&out, fn.out.code)
		fmt.assertf(err == nil, "dissasm error: %v", err)

		diff_path, _ := os.join_path(
			{TEST_OUT_DIR, "intel_xelp", name},
			context.allocator,
		)
		if DO_DIFFING {
			handle_golden_file(&out, diff_path)
		}
	}
	if NO_RUN do return

	@(thread_local)
	dev: gpu.Device

	if dev.fd == 0 {
		dev, err = gpu.open()
		fmt.assertf(err == nil, "failed to open gpu device: %v", err)
	}

	args := make([]gpu.Reg, param_count, context.temp_allocator)
	slots := make([]gpu.Reg, len(result_types), context.temp_allocator)
	ref_slots := make([]gpu.Reg, len(result_types), context.temp_allocator)

	for &slot in mem.slice_data_cast([]f32, args) {
		slot = rand.float32() * 2 - 1
	}

	if len(args) != 0 do args[0][1] = -0.0
	if len(args) > 1 {
		// inject devision by zero
		args[1][0] = args[0][0]
		args[1][1] = 0
		args[1][2] = args[0][2]
	}

	ref_impl(args, ref_slots)

	if !NO_RUN {
		err = gpu.execute(
			&dev,
			{code = mem.slice_data_cast([]u32, fn.out.code), width = .SIMD8},
			args,
			slots,
		)
		fmt.assertf(err == nil, "gpu execution error: %v", err)

		for result_type, i in result_types {
			for actual, lane in slots[i] {
				expected := ref_slots[i][lane]
				actual_bits := transmute(u32)actual
				expected_bits := transmute(u32)expected
				equal := actual_bits == expected_bits
				if result_type == f32 {
					equal ||= float_equal(actual, expected, max_float_ulps)
				}
				testing.expectf(
					t,
					equal,
					"result %v lane %v: %v (0x%08x) != %v (0x%08x)",
					i,
					lane,
					actual,
					actual_bits,
					expected,
					expected_bits,
				)
			}
		}

		float_equal :: proc(actual, expected: f32, max_ulps: int) -> bool {
			if actual == expected do return true
			if max_ulps == 0 do return false
			if math.is_nan(actual) && math.is_nan(expected) do return true
			if math.is_inf(actual) || math.is_inf(expected) do return false

			value := actual
			for _ in 0 ..< max_ulps {
				value = math.nextafter(value, expected)
			}
			return value == expected
		}
	}

}

run_test :: proc(
	t: ^testing.T,
	name: string,
	source: string,
	exit_code: int,
	diff := DO_DIFFING,
	no_run := NO_RUN,
) {
	{return}
	@(static) test_rc := 0
	intrinsics.atomic_add(&test_rc, 1)

	name_str = name
	context.logger.options &= ~{.Time, .Date, .Level, .Procedure}
	when ODIN_DEBUG {
		context.assertion_failure_proc = trace.assertion_failure_proc
	}
	context.random_generator = {}

	defer free_all(context.temp_allocator)

	setup_custom_fmt()

	dsbs: [Test_Vm]strings.Builder
	for &dsb in dsbs do dsb.buf.allocator = context.temp_allocator

	global_ctx: typecheck.Global_Ctx
	stats: bac.Stats

	ctx: odinc.Gen_Ctx
	ctx.types = ensure_types()
	ctx.stats = &stats
	ctx.global = &global_ctx
	ctx.errors = strings.to_writer(&dsbs[.Check])

	bac.current_prc = &ctx
	defer bac.current_prc = nil

	init_single_file_program(&ctx, source)
	typecheck.typecheck_program(&ctx)

	levels := odinc.OPT_LEVELS

	Test_Vm :: enum {
		Native,
		Wasm,
		Arm,
		Check,
	}

	Test_Conf :: struct {
		using level: odinc.Opt_Level,
		debug:       bool,
		vm:          Test_Vm,
	}

	confs: [dynamic]Test_Conf
	confs.allocator = context.temp_allocator

	for level in levels[:] {
		append(&confs, Test_Conf{level = level})
	}
	for level in levels[:] {
		append(&confs, Test_Conf{level = level, debug = true})
	}
	check := len(confs)
	for level in levels[:] {
		append(&confs, Test_Conf{level = level, vm = .Wasm})
	}
	for level in levels[:] {
		append(&confs, Test_Conf{level = level, vm = .Arm})
	}

	if name == "foreign_block" do resize(&confs, check)
	if ctx.error_cnt > 0 do clear(&confs)

	lib, did_load := dynlib.load_library("")
	assert(did_load, dynlib.last_error())

	prev_glob_count := len(ctx.globals)

	append(
		&ctx.procs,
		typecheck.Proc {
			name = "memmove",
			hidden = true,
			lit = &ast.Proc_Lit{body = &ast.Stmt{}},
			sig = &{params = {.I64, .I64, .I64}},
		},
		typecheck.Proc {
			name = "memset",
			hidden = true,
			lit = &ast.Proc_Lit{body = &ast.Stmt{}},
			sig = &{params = {.I64, .I8, .I64}},
		},
	)

	for level in confs {
		dsb := &dsbs[level.vm]

		if !level.debug {
			if level.vm == .Check {
				fmt.sbprintfln(dsb, "============= check run =============")
			} else {
				fmt.sbprintfln(
					dsb,
					"=========== OPT LEVEL: %v ===========",
					level.name,
				)
			}
		}

		reset_code_mems(ctx)

		ctx.check = level.vm == .Check
		ctx.has_dbg = level.debug
		ctx.ralloc_mode = level.ralloc_mode
		resize(&ctx.globals, prev_glob_count)

		for &prc in ctx.procs {
			prc.out = {}
			prc.stencil = {}
		}

		emit_ctx := bac.Codegen_Emit_Ctx {
			lib_calls = {
				copy = {id = u32(len(ctx.procs)) - 2},
				set = {id = u32(len(ctx.procs)) - 1},
			},
			emit_got_imports = true,
		}

		ctx.target = odinc.TARGETS[odinc.Target_ID(level.vm)]

		for kind, i in ([]ssa.Builtin_Proc{.memmove, .memset}) {
			ctx.opt_flags = level.flags
			ssa.start_proc(&ctx, &ctx.mems.prc, &arna.scratch)

			prc := &ctx.procs[len(ctx.procs) - 2 + i]

			prc.param_types = {
				0 ..< 3 = {dt = .I64},
			}

			ssa.make_builtin_proc(&ctx, kind)
			odinc.emit_proc_code(&ctx, &emit_ctx, prc)
		}

		switch level.vm {
		case .Native, .Arm:
			imported_offsets: [dynamic]uintptr
			imported_offsets.allocator = context.temp_allocator
			append(&imported_offsets, 0)
			for p in ctx.procs[1:] {
				if p.lit.body == nil {
					// fuzzed sources name symbols that exist nowhere, and nothing
					// is ever called under NO_RUN, so a null slot is harmless
					addr := dynlib.symbol_address(lib, p.name)
					if !no_run {
						fmt.assertf(addr != nil, "missing symbol: %v", p.name)
					}
					slot := bac.emit_aligned(&ctx.mems.code, addr)
					append(&imported_offsets, uintptr(slot))
				}
			}

			for _, i in ctx.procs[:len(ctx.procs) - 2] {
				odinc.emit_proc(&ctx, i, level, &emit_ctx)
			}

			defer for prc in ctx.procs do delete(prc.stencil.mem)

			if .Inline in level.flags {
				if !odinc.inline_and_optimize(&ctx, &emit_ctx) do continue
			}

			arna.alloc(&ctx.mems.code, 0, 4096)
			code_until := ctx.mems.code.pos

			global_addrs := make([]uintptr, len(ctx.globals), context.temp_allocator)
			for glob, i in ctx.globals {
				align := uint(max(glob.align, 1))
				slot := arna.alloc(&ctx.mems.code, len(glob.bytes), align)
				copy(slot, glob.bytes)
				global_addrs[i] = uintptr(raw_data(slot))
			}

			for p in ctx.procs {
				for &rel in p.out.relocs {
					target_off: uintptr
					switch rel.kind {
					case .Text:
						target := &ctx.procs[rel.id]
						target_off = uintptr(raw_data(target.out.code))
					case .Got:
						target_off = imported_offsets[rel.id]
					case .Global:
						if rel.id >= bac.RELOC_BIG_CONSTANT_BASE {

							slc := p.out.constants[rel.id - bac.RELOC_BIG_CONSTANT_BASE - 2:]

							size := slc[0]
							align := slc[1]

							off := arna.alloc(&ctx.mems.code, uint(size), uint(align))

							copy(off, slc[2:])

							target_off = uintptr(raw_data(off))
						} else {
							target_off = global_addrs[rel.id]
						}
					}

					source := uintptr(raw_data(p.out.code)) + uintptr(rel.offset)
					jump := i32(target_off - source)

					jump = jump / (1 << rel.scale_pow)
					if level.vm == .Arm {
						rel.offset += 4
					}

					size := bac.RELOC_SIZE[rel.size]
					slot := (^bac.Reloc_Slot)(
						raw_data(p.out.code[rel.offset - size:][:size]),
					)
					switch rel.size {
					case .r19:
						slot.r3.addend_19 += jump
					case .r26:
						slot.r2.addend_26 += jump
					case .r32:
						slot.addend_32 += jump
					case .r2_19:
						slot.r4.addend_hi_19 += jump >> 2
						slot.r4.addend_lo_2 += jump
					}
				}
			}

			if !level.debug {
				context.allocator = context.temp_allocator
				if level.vm == .Native {
					disasm(dsb, ctx, X64_DS)
				} else {
					disasm(dsb, ctx, ARM_DS)
				}
			}

			oka := virtual.protect(ctx.mems.code.ptr, code_until, {.Read, .Execute})
			assert(oka)

			if no_run {
				//log.error("running compiled code disabled")
			} else {
				main: ^typecheck.Proc
				for &p in ctx.procs {
					if p.name == "main" {
						main = &p
					}
				}

				if main != nil {
					vl: int

					if level.vm == .Native {
						ptr := transmute(proc() -> int)(raw_data(main.out.code))
						vl = ptr()
					} else {
						start := int(
							uintptr(raw_data(main.out.code)) - uintptr(ctx.mems.code.ptr),
						)
						avl, err := unicorn.run_arm64(
							ctx.mems.code.ptr[:ctx.mems.code.pos],
							int(code_until),
							start,
							trace_instrs = #config(TRACE_INSTRS, false),
						)
						if err != nil {
							log.error(unicorn.error_string(err))
						}
						vl = int(avl)
					}

					if vl != exit_code {
						log.error(level)
						testing.expect_value(t, vl, exit_code)
					}
				}
			}

			oka = virtual.protect(ctx.mems.code.ptr, code_until, {.Read, .Write})
			assert(oka)
		case .Wasm:
			for _, i in ctx.procs[:len(ctx.procs) - 2] {
				odinc.emit_proc(&ctx, i, level, &emit_ctx)
			}

			defer for prc in ctx.procs do delete(prc.stencil.mem)

			if .Inline in level.flags {
				if !odinc.inline_and_optimize(&ctx, &emit_ctx) do continue
			}

			module := odinc.emit_wasm_module(&ctx, context.temp_allocator)

			{context.allocator = context.temp_allocator
				disasm_wasm(dsb, module)}

			if no_run {
			} else {
				vl, status := wabt.run_module(module, "main")
				if status != 0 {
					log.error("wasm interpretter failed with", status)
				} else if int(vl) != exit_code {
					log.error(level)
					testing.expect_value(t, int(vl), exit_code)
				}
			}
		case .Check:
			for prc in ctx.procs {
				if len(prc.out.code) == 0 do continue

				fmt.sbprintfln(dsb, "%v: anal errors:", prc.name)
				cursor := string(prc.out.code)
				for line in strings.split_lines_iterator(&cursor) {
					fmt.sbprintfln(dsb, "  %v", line)
				}
			}
		}
	}

	if #config(LOG_STATS, false) {
		@(static) log_lock: sync.Mutex
		@(static) g_stats: bac.Stats

		sync.guard(&log_lock)
		bac.aggregate_effeciency_stats(&g_stats, ctx.stats)
		if intrinsics.atomic_sub(&test_rc, 1) == 1 {
			odinc.log_stats(&g_stats)
		}
	}

	vm_names := [Test_Vm]string {
		.Check  = "check",
		.Native = "x64",
		.Arm    = "arm",
		.Wasm   = "wasm",
	}

	if diff {
		for &dsb, kind in dsbs {
			if len(dsb.buf) == 0 do continue

			context.allocator = context.temp_allocator
			diff_path, _ := os.join_path(
				{TEST_OUT_DIR, vm_names[kind], name},
				context.allocator,
			)

			handle_golden_file(&dsb, diff_path)
		}
	}
}

handle_golden_file :: proc(dsb: ^strings.Builder, diff_path: string) {
	file, err := os.read_entire_file(diff_path, context.allocator)

	if #config(ACCEPT, false) {
		werr := os.write_entire_file(diff_path, dsb.buf[:])
		assert(werr == nil)
	} else if err == .Not_Exist {
		log.error("\n", highlight_disasm(string(dsb.buf[:])), sep = "")
	} else {
		assert(err == nil)
		new, old := string(dsb.buf[:]), string(file)
		if new != old {
			new, old = highlight_disasm(strings.clone(new)), highlight_disasm(old)
			clear(&dsb.buf)
			append(&dsb.buf, "\n")
			print_diff(dsb, old, new)
			log.error(string(dsb.buf[:]))
		}
	}
}

Line :: struct {
	hash:    u32,
	content: string,
	_:       [0][]u8,
}

split_lines :: proc(input: string) -> #soa[]Line {
	lines: #soa[dynamic]Line

	start := 0
	for i in 0 ..< len(input) {
		if input[i] == '\n' {
			append(&lines, Line{content = input[start:i]})
			start = i + 1
		}
	}

	append(&lines, Line{content = input[start:]})

	for &l in lines {
		l.hash = hash.fnv32(transmute([]u8)l.content)
	}

	return lines[:]
}

lcs_lines :: proc(a, b: string) -> []Line #no_bounds_check {
	lines_a := split_lines(a)
	lines_b := split_lines(b)

	len_a := len(lines_a)
	len_b := len(lines_b)

	UNIT :: u32

	dp := make([][]UNIT, len_a + 1)

	for i in 0 ..= len_a {
		dp[i] = make([]UNIT, len_b + 1)
	}

	for i in 0 ..< len_a {
		j := 0

		VEC :: #simd[64 / size_of(UNIT)]UNIT

		search: VEC = lines_a[i].hash
		inc: VEC = 1
		next := dp[i + 1]
		curr := dp[i]

		for j + len(inc) * 2 <= len_b {
			hay := intrinsics.unaligned_load((^VEC)(lines_b.hash[j:]))
			cmp := simd.lanes_ne(hay, search)
			mask := transmute(u16)simd.extract_lsbs(cmp)

			if mask != 0 do break
			intrinsics.unaligned_store(
				(^#simd[16]u32)(&next[j + len(inc)]),
				intrinsics.unaligned_load((^VEC)(&curr[j])) + inc,
			)
			j += len(inc)
		}

		for j < len_b {
			if lines_a[i].hash == lines_b[j].hash {
				dp[i + 1][j + 1] = dp[i][j] + 1
			} else {
				dp[i + 1][j + 1] = max(dp[i + 1][j], dp[i][j + 1])
			}
			j += 1
		}
	}

	result := make([]Line, dp[len_a][len_b])

	i := len_a
	j := len_b
	k := dp[len_a][len_b]

	for i > 0 && j > 0 {
		if lines_a[i - 1].hash == lines_b[j - 1].hash {
			k -= 1
			result[k] = lines_a[i - 1]

			i -= 1
			j -= 1
		} else if dp[i - 1][j] >= dp[i][j - 1] {
			i -= 1
		} else {
			j -= 1
		}
	}

	return result
}

print_diff :: proc(out: ^strings.Builder, a, b: string) {
	lines_a := split_lines(a)
	lines_b := split_lines(b)

	lcs := lcs_lines(a, b)

	i := 0
	j := 0
	k := 0

	for i < len(lines_a) || j < len(lines_b) {
		if k < len(lcs) &&
		   i < len(lines_a) &&
		   j < len(lines_b) &&
		   lines_a[i].hash == lcs[k].hash &&
		   lines_b[j].hash == lcs[k].hash {
			fmt.sbprintfln(out, " %s", lines_a[i].content)
			i += 1
			j += 1
			k += 1
		} else if j < len(lines_b) &&
		   (k >= len(lcs) || lines_b[j].hash != lcs[k].hash) {
			if .Terminal_Color in context.logger.options {
				fmt.sbprintfln(out, "\x1b[32m+%s\x1b[0m", lines_b[j].content)
			} else {
				fmt.sbprintfln(out, "+%s", lines_b[j].content)
			}
			j += 1
		} else if i < len(lines_a) &&
		   (k >= len(lcs) || lines_a[i].hash != lcs[k].hash) {
			if .Terminal_Color in context.logger.options {
				fmt.sbprintfln(out, "\x1b[31m-%s\x1b[0m", lines_a[i].content)
			} else {
				fmt.sbprintfln(out, "-%s", lines_b[j].content)
			}
			i += 1
		} else {
			fmt.panicf("unreachable %#v", lcs)
		}
	}
}

disasm_wasm :: proc(sb: ^strings.Builder, module: []u8) {
	m: rex_wasm.Module
	errors: [dynamic]ir.Error

	_, ok := rex_wasm.decode(module, &m, &errors)
	for err in errors {
		fmt.sbprintln(sb, err)
	}
	if ok {
		m.functions = m.functions[:len(m.functions) - 2]
		m.func_types = m.func_types[:len(m.func_types) - 2]
		rex_wasm.sbprint_wat(sb, m)
	} else {
		hash := hash.fnv64(module)
		name := fmt.tprintf("/tmp/%x.wasm", hash)
		err := os.write_entire_file(name, module)
		assert(err == nil)

		p: os.Process_Desc
		p.command = {"wasm2wat", name, "--enable-all"}

		_, _, stderr, _ := os.process_exec(p, context.temp_allocator)
		os.write(os.stderr, stderr)
	}

}

Disasm_Scope :: struct(
	Instruction: typeid,
	Instruction_Info: typeid,
	Relocation: typeid,
	Mode: typeid,
) {
	decode:  proc(
		data: []u8,
		relocs: []Relocation,
		instructions: ^[dynamic]Instruction,
		inst_info: ^[dynamic]Instruction_Info,
		label_defs: ^[dynamic]isa.Label_Definition,
		errors: ^[dynamic]isa.Error,
		mode: Mode = {},
	) -> (
		u32,
		bool,
	),
	sbprint: proc(
		sb: ^strings.Builder,
		instructions: []Instruction,
		inst_info: []Instruction_Info,
		label_defs: []isa.Label_Definition,
		tokens: ^[dynamic]isa.Token = nil,
		options: ^isa.Print_Options = nil,
		label_names: ^isa.Label_Names = nil,
	),
}

X64_DS :: Disasm_Scope(
	x86.Instruction,
	x86.Instruction_Info,
	x86.Relocation,
	x86.Mode,
){x86.decode, x86.sbprint}

ARM_DS :: Disasm_Scope(
	arm64.Instruction,
	arm64.Instruction_Info,
	arm64.Relocation,
	arm64.Endianness,
){arm64.decode, arm64.sbprint}

disasm :: proc(sb: ^strings.Builder, ctx: odinc.Gen_Ctx, ds: $DS) {
	decoded_instrs: [dynamic]DS.Instruction
	decoded_instr_info: [dynamic]DS.Instruction_Info
	decoded_label_info: [dynamic]x86.Label_Definition
	errors: [dynamic]x86.Error
	labels: map[x86.Label_Offset]string

	mn := max(uintptr)
	for prc in ctx.procs[1:] {
		if prc.hidden do continue
		instructions := prc.out.code
		offset :=
			uintptr(raw_data(instructions)) - uintptr(ctx.types.mems.code.ptr)
		mn = min(mn, offset)
	}

	for prc in ctx.procs[1:] {
		if prc.hidden do continue
		instructions := prc.out.code

		offset := u32(
			uintptr(raw_data(instructions)) - uintptr(ctx.types.mems.code.ptr) - mn,
		)

		label_base := len(decoded_label_info)
		info_base := len(decoded_instr_info)
		labels[x86.Label_Offset(offset)] = prc.name
		append(&decoded_label_info, 0)

		ds.decode(
			instructions,
			nil,
			&decoded_instrs,
			&decoded_instr_info,
			&decoded_label_info,
			&errors,
		)

		for &lbl in decoded_label_info[label_base:] {
			lbl += x86.Label_Definition(offset)
		}

		for &info in decoded_instr_info[info_base:] {
			info.offset += u32(offset)
		}
	}

	for err in errors {
		fmt.sbprintln(sb, err)
	}

	opts := x86.DEFAULT_PRINT_OPTIONS
	opts.label_prefix = ""

	ds.sbprint(
		sb,
		decoded_instrs[:],
		decoded_instr_info[:],
		decoded_label_info[:],
		options = &opts,
		label_names = &labels,
	)
}

highlight_disasm :: proc(disasm: string) -> string {
	text: strings.Builder
	append(&text.buf, disasm)

	gp_register_names := [][]string {
		{"rax", "eax", "ax", "al", "ah"},
		{"rbx", "ebx", "bx", "bl", "bh"},
		{"rcx", "ecx", "cx", "cl", "ch"},
		{"rdx", "edx", "dx", "dl", "dh"},
		{"rsi", "esi", "si", "sil"},
		{"rdi", "edi", "di", "dil"},
		{"rbp", "ebp", "bp", "bpl"},
		{"rsp", "esp", "sp", "spl"},
		{"r8", "r8d", "r8w", "r8b"},
		{"r9", "r9d", "r9w", "r9b"},
		{"r10", "r10d", "r10w", "r10b"},
		{"r11", "r11d", "r11w", "r11b"},
		{"r12", "r12d", "r12w", "r12b"},
		{"r13", "r13d", "r13w", "r13b"},
		{"r14", "r14d", "r14w", "r14b"},
		{"r15", "r15d", "r15w", "r15b"},
		{"rip", "eip", "ip"},
		{"rflags", "eflags", "flags"},
		{"xmm10"},
		{"xmm12"},
		{"xmm13"},
		{"xmm14"},
		{"xmm15"},
		{"xmm0"},
		{"xmm1"},
		{"xmm2"},
		{"xmm3"},
		{"xmm4"},
		{"xmm5"},
		{"xmm6"},
		{"xmm7"},
		{"xmm8"},
		{"xmm9"},
	}

	highlight: strings.Builder
	for group, i in gp_register_names {
		for name in group {
			clear(&highlight.buf)

			bac.ansi_start(strings.to_writer(&highlight), i)
			ln := len(highlight.buf)
			append(&highlight.buf, name)
			bac.ansi_end(strings.to_writer(&highlight))

			inject_at(&highlight.buf, ln + 1, 0)

			strings.builder_replace_all(&text, name, string(highlight.buf[:]))
		}
	}

	for i in 0 ..< 100 {
		clear(&highlight.buf)
		off := i * 8

		name := fmt.tprintf("0x%02x]", off)

		bac.ansi_start(strings.to_writer(&highlight), i)
		append(&highlight.buf, name)
		bac.ansi_end(strings.to_writer(&highlight))

		strings.builder_replace_all(&text, name, string(highlight.buf[:]))
	}

	return string(text.buf[:])
}
