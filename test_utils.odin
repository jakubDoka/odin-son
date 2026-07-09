package main

import zydis "./zydis"
import "backend"
import "base:intrinsics"
import "base:runtime"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:mem/virtual"
import "core:odin/ast"
import "core:odin/parser"
import "core:os"
import "core:reflect"
import "core:strings"
import "core:sync"
import "core:testing"
import "vendored/gam/util/arna"
import "vendored/gam/util/hot"

TEST_OUT_DIR :: "print-tests"

run_test :: proc(t: ^testing.T, name: string, source: string, exit_code: int) {
	context.logger.options &= ~{.Time, .Date, .Level, .Procedure}
	context.assertion_failure_proc = hot.init_trace()

	arna.scratch[0].reserved = 1024 * 1024
	arna.scratch[1].reserved = 1024 * 1024

	types: Types
	types.mems.graph.reserved = 4096 * 128
	types.mems.regalloc.reserved = 4096 * 64
	types.mems.scratch.reserved = 4096 * 16
	types.mems.code.reserved = 4096 * 16
	types.mems.reloc.reserved = 4096 * 16
	types.mems.type.reserved = 4096 * 16

	types_init(&types)
	defer types_deinit(&types)

	// NOTE: this is intensly stupid, but we have to do this or there
	// will be dataraces
	@(static) once: sync.Once
	sync.once_do(&once, proc() {
		context.allocator = context.temp_allocator
		p := parser.Parser{}
		f := ast.File {
			src      = "package main",
			fullpath = "test",
		}
		ok := parser.parse_file(&p, &f); assert(ok)
	})

	@(static) fmts_once: sync.Once
	sync.once_do(&fmts_once, backend.init_custom_fmt)

	global_ctx: Global_Ctx

	p := parser.Parser{}
	f := ast.File {
		src      = source,
		fullpath = "test",
	}
	{context.allocator = context.temp_allocator
		ok := parser.parse_file(&p, &f); assert(ok)
	}

	ctx: Gen_Ctx
	ctx.types = &types
	ctx.global = &global_ctx
	ctx.cc = &backend.X64_ODIN_CC
	ctx.cc_dt_to_reg_kind = &backend.SPECS[.X64].datatype_to_reg_kind

	init_single_file_program(&ctx, &f)
	typecheck_program(&ctx)

	levels := []Opt_Level {
		{"none", {}},
		{"mininal", {.Local_Peeps}},
		{"moderate", {.Iter_Peeps, .Local_Peeps, .Schedule_Peeps}},
		{"all", {.Iter_Peeps, .Local_Peeps, .Schedule_Peeps, .MemOpt}},
	}

	dsb: strings.Builder
	dsb.buf.allocator = context.temp_allocator
	for level in levels {
		fmt.sbprintfln(
			&dsb,
			"=========== OPT LEVEL: %v ===========",
			level.name,
		)
		types.mems.code.pos = 0
		types.mems.reloc.pos = 0
		clear(&ctx.globals)

		for &prc, i in ctx.procs {
			emit_proc(&ctx, &prc, i, level)
		}

		lib_call_offsets: [2]uintptr

		_copy :: proc "contextless" (dst, src: rawptr, len: int) -> rawptr {
			vl: #simd[16]u8
			_ = intrinsics.volatile_load(&vl)
			return mem.copy(dst, src, len)
		}

		lib_call_offsets[0] = auto_cast backend.emit_aligned(
			&types.mems.code,
			_copy,
		)
		lib_call_offsets[1] = auto_cast backend.emit_aligned(
			&types.mems.code,
			mem.set,
		)

		arna.alloc(&types.mems.code, 0, 4096)
		code_until := types.mems.code.pos

		global_addrs := make(
			[]uintptr,
			len(ctx.globals),
			context.temp_allocator,
		)
		for glob, i in ctx.globals {
			align := uint(max(glob.align, 1))
			slot := arna.alloc(&types.mems.code, len(glob.bytes), align)
			copy(slot, glob.bytes)
			global_addrs[i] = uintptr(raw_data(slot))
		}

		for p in ctx.procs {
			for rel in p.out.relocs {
				target_off: uintptr
				switch rel.kind {
				case .Text:
					target := &ctx.procs[rel.id]
					target_off = uintptr(raw_data(target.out.code))
				case .Data:
					target_off = lib_call_offsets[rel.id]
				case .Global:
					target_off = global_addrs[rel.id]
				}

				source := uintptr(raw_data(p.out.code)) + uintptr(rel.offset)
				jump := u32(target_off - source)

				size := backend.RELOC_SIZE[rel.size]
				slot := (^backend.Reloc_Slot)(
					raw_data(p.out.code[rel.offset - size:][:size]),
				)
				switch rel.size {
				case .r4:
					slot.addend_4 += jump
				}
			}
		}

		{context.allocator = context.temp_allocator
			disasm(&dsb, ctx)}

		oka := virtual.protect(
			types.mems.code.ptr,
			code_until,
			{.Read, .Execute},
		)
		assert(oka)

		main: ^Proc
		for &p in ctx.procs {
			if p.name == "main" {
				main = &p
			}
		}

		ptr := transmute(proc() -> int)(raw_data(main.out.code))
		if #config(NO_RUN, false) {
			log.error("running compiled code disabled")
		} else {
			vl := ptr()
			if vl != exit_code {
				log.error(level)
				testing.expect_value(t, vl, exit_code)
			}
		}

		oka = virtual.protect(types.mems.code.ptr, code_until, {.Read, .Write})
		assert(oka)
	}

	@(static) log_lock: sync.Mutex
	if false {sync.guard(&log_lock)
		log.info(name)
		for eff, kind in ctx.stats.efficiency {
			name :=
				reflect.enum_field_names(backend.Efficiency_Stat_Kind)[kind]
			log.infof(
				"  %s %s % -8d % -8d % -8f",
				name,
				strings.repeat(" ", 20 - len(name), context.temp_allocator),
				eff.total,
				eff.ideal,
				f64(eff.total) / f64(eff.ideal),
			)
		}
	}

	context.allocator = context.temp_allocator
	diff_path, _ := os.join_path({TEST_OUT_DIR, name}, context.allocator)
	file, err := os.read_entire_file(diff_path, context.allocator)

	DO_DIFFING :: #config(DIFF, true)

	if #config(ACCEPT, false) {
		werr := os.write_entire_file(diff_path, dsb.buf[:])
		assert(werr == nil)
	} else if err == .Not_Exist {
		if DO_DIFFING {
			log.error("\n", highlight_disasm(string(dsb.buf[:])), sep = "")
		}
	} else {
		if DO_DIFFING {
			assert(err == nil)
			new, old := string(dsb.buf[:]), string(file)
			if new != old {
				new, old =
					highlight_disasm(strings.clone(new)), highlight_disasm(old)
				clear(&dsb.buf)
				append(&dsb.buf, "\n")
				print_diff(&dsb, old, new)
				log.error(string(dsb.buf[:]))
			}
		}
	}
}

split_lines :: proc(input: string) -> []string {
	lines: [dynamic]string

	start := 0
	for i in 0 ..< len(input) {
		if input[i] == '\n' {
			append(&lines, input[start:i])
			start = i + 1
		}
	}

	append(&lines, input[start:])

	return lines[:]
}

lcs_lines :: proc(a, b: string) -> []string {
	lines_a := split_lines(a)
	lines_b := split_lines(b)

	len_a := len(lines_a)
	len_b := len(lines_b)

	dp := make([][]int, len_a + 1)

	for i in 0 ..= len_a {
		dp[i] = make([]int, len_b + 1)
	}

	for i in 0 ..< len_a {
		for j in 0 ..< len_b {
			if lines_a[i] == lines_b[j] {
				dp[i + 1][j + 1] = dp[i][j] + 1
			} else {
				dp[i + 1][j + 1] = max(dp[i + 1][j], dp[i][j + 1])
			}
		}
	}

	result := make([]string, dp[len_a][len_b])

	i := len_a
	j := len_b
	k := dp[len_a][len_b]

	for i > 0 && j > 0 {
		if lines_a[i - 1] == lines_b[j - 1] {
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
		   lines_a[i] == lcs[k] &&
		   lines_b[j] == lcs[k] {
			fmt.sbprintfln(out, " %s", lines_a[i])
			i += 1
			j += 1
			k += 1
		} else if j < len(lines_b) && (k >= len(lcs) || lines_b[j] != lcs[k]) {
			if .Terminal_Color in context.logger.options {
				fmt.sbprintfln(out, "\x1b[32m+%s\x1b[0m", lines_b[j])
			} else {
				fmt.sbprintfln(out, "+%s", lines_b[j])
			}
			j += 1
		} else if i < len(lines_a) && (k >= len(lcs) || lines_a[i] != lcs[k]) {
			if .Terminal_Color in context.logger.options {
				fmt.sbprintfln(out, "\x1b[31m-%s\x1b[0m", lines_a[i])
			} else {
				fmt.sbprintfln(out, "-%s", lines_b[j])
			}
			i += 1
		} else {
			fmt.panicf("unreachable %#v", lcs)
		}
	}
}

disasm :: proc(sb: ^strings.Builder, ctx: Gen_Ctx) {
	runtime_address: zydis.U64 = 0x0040_0000

	jumps: map[int]int

	is_jump :: proc(mne: zydis.Mnemonic) -> bool {
		return(
			mne == .JZ ||
			mne == .JNZ ||
			mne == .JL ||
			mne == .JLE ||
			mne == .JB ||
			mne == .JBE ||
			mne == .JNB ||
			mne == .JMP ||
			mne == .JNLE ||
			mne == .JNL ||
			mne == .JNBE \
		)
	}

	for prc in ctx.procs {
		clear(&jumps)
		fmt.sbprintfln(sb, "%v:", prc.name)

		instructions := prc.out.code

		offset: int
		for offset < len(instructions) {
			instr: zydis.DisassembledInstruction
			status := zydis.DisassembleIntel(
				.LONG_64,
				runtime_address + zydis.U64(offset),
				&instructions[offset],
				zydis.USize(uint(len(instructions)) - uint(offset)),
				&instr,
			)
			if !zydis.SUCCESS(status) {
				break
			}

			length := int(instr.info.length)

			if is_jump(instr.info.mnemonic) {
				off := offset + length + int(instr.operands[0].imm.value.s)
				if off not_in jumps {
					jumps[off] = len(jumps)
				}
			}

			offset += length

			if length == 0 {
				break
			}
		}

		offset = 0
		for offset < len(instructions) {
			instr: zydis.DisassembledInstruction
			status := zydis.DisassembleIntel(
				.LONG_64,
				runtime_address + zydis.U64(offset),
				&instructions[offset],
				zydis.USize(uint(len(instructions)) - uint(offset)),
				&instr,
			)
			if !zydis.SUCCESS(status) {
				fmt.sbprintfln(
					sb,
					"0x%08x  <decode failed: %#x>",
					runtime_address + zydis.U64(offset),
					status,
				)
				break
			}

			if off, ok := jumps[offset]; ok {
				fmt.sbprintf(sb, "%03i: ", off)
			} else {
				fmt.sbprint(sb, "     ")
			}

			length := int(instr.info.length)

			text := string(cstring(&instr.text[0]))
			if is_jump(instr.info.mnemonic) {
				off := offset + length + int(instr.operands[0].imm.value.s)
				text = fmt.tprintf(
					"%v :%v",
					zydis.MnemonicGetString(instr.info.mnemonic),
					jumps[off],
				)
			} else if instr.info.mnemonic == .CALL {
				for reloc in prc.out.relocs {
					if int(reloc.offset) == offset + length {
						switch reloc.kind {
						case .Text:
							text = fmt.tprintf(
								"%v :%v",
								zydis.MnemonicGetString(instr.info.mnemonic),
								ctx.procs[reloc.id].name,
							)
						case .Data:
							names := [2]string{"copy", "set"}

							text = fmt.tprintf(
								"%v :$%v",
								zydis.MnemonicGetString(instr.info.mnemonic),
								names[reloc.id],
							)
						case .Global:
						}
					}
				}
			}

			fmt.sbprintfln(sb, "%s", text)

			if instr.info.mnemonic == .JMP {
				append(&sb.buf, "\n")
			}

			offset += length
		}
	}

}

highlight_disasm :: proc(disasm: string) -> string {
	text: strings.Builder
	append(&text.buf, disasm)

	gp_register_names := []string {
		"rax",
		"rbx",
		"rcx",
		"rdx",
		"rsi",
		"rdi",
		"rbp",
		"rsp",
		"r8",
		"r9",
		"r10",
		"r11",
		"r12",
		"r13",
		"r14",
		"r15",
		"rip",
		"rflags",
	}

	highlight: strings.Builder
	for name, i in gp_register_names {
		clear(&highlight.buf)

		backend.ansi_start(strings.to_writer(&highlight), i)
		append(&highlight.buf, name)
		backend.ansi_end(strings.to_writer(&highlight))

		strings.builder_replace_all(&text, name, string(highlight.buf[:]))
	}

	for i in 0 ..< 100 {
		off := i * 8

		name := fmt.tprintf("0x%02x]", off)

		highlight: strings.Builder

		backend.ansi_start(strings.to_writer(&highlight), i)
		append(&highlight.buf, name)
		backend.ansi_end(strings.to_writer(&highlight))

		strings.builder_replace_all(&text, name, string(highlight.buf[:]))
	}

	return string(text.buf[:])
}
