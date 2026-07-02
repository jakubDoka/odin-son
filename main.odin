package main

import zydis "./zydis"
import "backend"
import "base:runtime"
import "core:fmt"
import "core:io"
import "core:log"
import "core:mem"
import "core:mem/virtual"
import "core:odin/ast"
import "core:odin/parser"
import "core:odin/tokenizer"
import "core:os"
import "core:reflect"
import "core:slice"
import "core:strconv"
import "core:strings"
import "core:sync"
import "core:testing"
import "meta"
import "vendored/gam/util/arna"
import "vendored/gam/util/hot"

TEST_OUT_DIR :: "print-tests"

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
			break
			//fmt.panicf("unreachable %#v", lcs)
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

fmts_once: sync.Once
fmts: map[typeid]fmt.User_Formatter
@(thread_local)
current_graph: ^backend.Graph

init_custom_fmt :: proc() {
	context.allocator = context.temp_allocator

	fmt.set_user_formatters(&fmts)

	fmt.register_user_formatter(
		backend.Reg_Mask,
		proc(fi: ^fmt.Info, value: any, r: rune) -> bool {
			value := value.(backend.Reg_Mask)
			io.write_rune(fi.writer, backend.reg_kind_char(value.kind))
			for m in 0 ..< value.bit_length / backend.MASK_SIZE {
				fmt.wprintf(fi.writer, "%016x", uint(value.masks[m]))
			}
			return true
		},
	)

	fmt.register_user_formatter(
		backend.Lrg,
		proc(fi: ^fmt.Info, value: any, r: rune) -> bool {
			value := value.(backend.Lrg)
			fmt.wprintf(fi.writer, "%v%v", value.mask, value.node)
			if value.reg != -1 {
				fmt.wprintf(fi.writer, "%03i", value.reg)
			}
			backend.ansi_start(fi.writer, value.index)
			fmt.wprintf(fi.writer, "%3i", value.index)
			backend.ansi_end(fi.writer)
			return true
		},
	)

	fmt.register_user_formatter(
		backend.Node_Output,
		proc(fi: ^fmt.Info, value: any, r: rune) -> bool {
			value := value.(backend.Node_Output)
			fmt.wprintf(fi.writer, "%v:%v", value.id, value.idx)
			return true
		},
	)

	fmt.register_user_formatter(
		backend.Node_ID,
		proc(fi: ^fmt.Info, value: any, r: rune) -> bool {
			value := value.(backend.Node_ID)
			if value != 0 {
				backend.graph_display_node_gvn(fi.writer, current_graph, value)
			} else {
				fmt.wprint(fi.writer, "nl")
			}
			return true
		},
	)

	fmt.register_user_formatter(
		backend.Node,
		proc(fi: ^fmt.Info, value: any, r: rune) -> bool {
			value := &value.(backend.Node)
			id := backend.graph_id(current_graph, value)
			backend.graph_display_node(fi.writer, current_graph, id)
			return true
		},
	)

	fmt.register_user_formatter(
		backend.Graph,
		proc(fi: ^fmt.Info, value: any, r: rune) -> bool {
			value := &value.(backend.Graph)
			backend.graph_display(fi.writer, value)
			return true
		},
	)
}

waste_redc: backend.Redundancy_Counter
once: sync.Once

run_test :: proc(t: ^testing.T, name: string, source: string, exit_code: int) {
	context.logger.options &= ~{.Time, .Date, .Level, .Procedure}
	context.assertion_failure_proc = hot.init_trace()

	arna.scratch[0].reserved = 1024 * 1024
	arna.scratch[1].reserved = 1024 * 1024
	graph_mem := arna.Allocator {
		reserved = 4096 * 128,
	}
	regalloc_mem := arna.Allocator {
		reserved = 4096 * 64,
	}
	scratch_mem := arna.Allocator {
		reserved = 4096 * 16,
	}
	code_mem := arna.Allocator {
		reserved = 4096 * 16,
	}
	reloc_mem := arna.Allocator {
		reserved = 4096 * 16,
	}
	type_mem := arna.Allocator {
		reserved = 4096 * 16,
	}

	_ = arna.bulk_init(
		&arna.scratch[0],
		&arna.scratch[1],
		&graph_mem,
		&regalloc_mem,
		&scratch_mem,
		&code_mem,
		&reloc_mem,
		&type_mem,
	)
	defer arna.bulk_destroy(
		&arna.scratch[0],
		&arna.scratch[1],
		&graph_mem,
		&regalloc_mem,
		&scratch_mem,
		&code_mem,
		&reloc_mem,
		&type_mem,
	)

	sync.once_do(
		&once,
		proc() {
			context.allocator = context.temp_allocator
			// NOTE: this is intensly stupid, but we have to do this or there
			// will be dataraces
			p := parser.Parser{}
			f := ast.File {
				src      = "package main",
				fullpath = "test",
			}
			ok := parser.parse_file(&p, &f); assert(ok)
		},
	)

	sync.once_do(&fmts_once, init_custom_fmt)

	global_ctx: Global_Ctx

	p := parser.Parser{}
	f := ast.File {
		src      = source,
		fullpath = "test",
	}
	{context.allocator = context.temp_allocator
		ok := parser.parse_file(&p, &f); assert(ok)
	}

	types: Types
	types.allocator = arna.allocator(&type_mem)
	types.procs.allocator = types.allocator
	types.pointers.allocator = types.allocator
	types.structs.allocator = types.allocator
	types.lits.allocator = types.allocator

	ctx: Gen_Ctx
	ctx.file = &f
	ctx.types = &types

	for decl in f.decls {
		if sdecl, sok := decl.derived_stmt.(^ast.Value_Decl); sok {
			if prc, pok := sdecl.values[0].derived.(^ast.Proc_Lit); pok {
				plist := prc.type.params.list
				rlist := prc.type.results.list

				params := make([]Param, len(plist), context.temp_allocator)
				rets := make([]Param, len(rlist), context.temp_allocator)

				lists := [][]^ast.Field{plist, rlist}
				tys := [][]Param{params, rets}

				for list, j in lists {
					tys := tys[j]

					for param, i in list {
						assert(len(param.names) <= 1)
						pname := ""
						if len(param.names) == 1 {
							pname = meta.src_of(f, param.names[0])
						}

						tys[i] = {pname, emit_type(&ctx, param.type)}
					}
				}

				append(
					&ctx.procs,
					Proc {
						name = meta.src_of(f, sdecl.names[0]),
						ast = prc,
						params = params,
						rets = rets,
					},
				)
			}
		}
	}

	levels := []struct {
		name:  string,
		flags: backend.Graph_Opt_Flags,
	} {
		{"none", {}},
		{"mininal", {.Local_Peeps}},
		{"all", {.Iter_Peeps, .Local_Peeps, .Schedule_Peeps}},
	}

	for &prc, i in ctx.procs {
		ctx.prc = auto_cast i
		scratch_mem.pos = 0
		ctx.scope = make([dynamic]Variable, arna.allocator(&scratch_mem))

		for par in prc.params {
			append(&ctx.scope, Variable{name = par.name, type = par.type})
		}

		typecheck(&ctx, {}, prc.ast.body)
	}

	dsb: strings.Builder
	dsb.buf.allocator = context.temp_allocator
	for level in levels {
		fmt.sbprintfln(
			&dsb,
			"=========== OPT LEVEL: %v ===========",
			level.name,
		)
		code_mem.pos = 0
		reloc_mem.pos = 0

		for &prc, i in ctx.procs {
			ctx.prc = auto_cast i
			ctx.graph = {}
			ctx.node_spec = &backend.SPECS[.Builder]
			ctx.mem = &graph_mem
			ctx.mem.pos = backend.PRECISION
			ctx.opt_flags = level.flags

			current_graph = &ctx

			clear(&ctx.scope)

			start := backend.graph_add_start(&ctx, "start")
			assert(start == backend.NODE_START)
			entry := backend.graph_add_entry(&ctx, "entry", start)
			assert(entry == backend.NODE_ENTRY)
			ctx.root_mem = backend.graph_add_mem(&ctx, "emem", entry)

			ctx.node_scope = backend.graph_add_scope(&ctx, "scope", entry)
			ctx.mem_slot = backend.graph_push_scope_value(
				&ctx,
				ctx.node_scope,
				ctx.root_mem,
			)

			gpa_fuel := 6
			i := 0
			for par in prc.params {
				dt := type_to_dt(par.type)

				if dt == .Void {
					value: backend.Node_ID
					size := type_size(par.type)
					switch size {
					case 0:
						continue
					case 1 ..= 16:
						if gpa_fuel < 2 && size > 8 {
							value = alloca(
								&ctx,
								"sparg",
								par.type,
								zeroed = false,
								is_arg = true,
							)
							break
						}

						slot := alloca(&ctx, "sarg", par.type, zeroed = false)

						value = backend.graph_add_arg(
							&ctx,
							"arg",
							.I64,
							entry,
							u32(i),
						)
						emit_arbitrary_store(&ctx, slot, value, size)

						if size > 8 {
							i += 1
							gpa_fuel -= 1
							second := backend.graph_add_arg(
								&ctx,
								"af",
								.I64,
								entry,
								u32(i),
							)
							emit_arbitrary_store(&ctx, slot, second, size, 8)
						}

						value = slot
					case 17 ..= int(~uint(0) >> 1):
						value = backend.graph_add_arg(
							&ctx,
							"arg",
							.I64,
							entry,
							u32(i),
						)
					case:
						fmt.panicf("unsupported type: %v", par.type)
					}

					append(
						&ctx.scope,
						Variable{par.name, value, par.type, nil, {}},
					)
					i += 1
					gpa_fuel -= 1
				} else {
					value := backend.graph_add_arg(
						&ctx,
						"arg",
						dt,
						entry,
						u32(i),
					)
					idx := backend.graph_push_scope_value(
						&ctx,
						ctx.node_scope,
						value,
					)
					append(
						&ctx.scope,
						Variable{par.name, idx, par.type, nil, {}},
					)
					i += 1
					gpa_fuel -= 1
				}
			}

			emit_nodes(&ctx, {}, prc.ast.body)

			backend.graph_iter_peeps(&ctx)

			spec := &backend.SPECS[.X64]
			ctx.node_spec = spec

			backend.graph_iter_peeps(&ctx)

			scratch_mem.pos = 0

			schedule: backend.Graph_Schedule
			backend.graph_schedule(
				&ctx,
				&schedule,
				arna.allocator(&scratch_mem),
			)

			backend.graph_schedule_peeps(&ctx, &schedule)

			ra: backend.Regalloc
			ra.spec = spec

			regs := backend.regalloc(
				&ra,
				&ctx,
				&schedule,
				arna.allocator(&scratch_mem),
			)

			if backend.REGLOGS {
				sb: strings.Builder
				append(&sb.buf, "\n")
				backend.graph_display(
					strings.to_writer(&sb),
					&ctx,
					&schedule,
					regs = regs,
				)
				log.info(string(sb.buf[:]))
			}

			ctx := backend.Codegen_Emit_Ctx {
				graph = &ctx,
				schedule = &schedule,
				buf = {code = &code_mem, relocs = &reloc_mem},
				allocs = regs,
				lib_calls = {
					copy = {id = 0, absolute = true},
					set = {id = 1, absolute = true},
				},
			}
			prc.out = spec.emit_function(ctx)
		}

		lib_call_offsets: [2]uintptr

		lib_call_offsets[0] = auto_cast backend.emit_aligned(
			&code_mem,
			mem.copy,
		)
		lib_call_offsets[1] = auto_cast backend.emit_aligned(
			&code_mem,
			mem.set,
		)

		for p in ctx.procs {
			for rel in p.out.relocs {
				target_off: uintptr
				switch rel.kind {
				case .Text:
					target := &ctx.procs[rel.id]
					target_off = uintptr(raw_data(target.out.code))
				case .Data:
					target_off = lib_call_offsets[rel.id]
				}
				source := uintptr(raw_data(p.out.code)) + uintptr(rel.offset)
				jump := u32(target_off - source)
				assert(rel.size == .r4)
				slot := p.out.code[rel.offset - 4:][:4]
				copy(slot, reflect.as_bytes(jump))
			}
		}

		{context.allocator = context.temp_allocator
			disasm(&dsb, ctx)}

		oka := virtual.protect(
			code_mem.ptr,
			code_mem.commited,
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

		oka = virtual.protect(code_mem.ptr, code_mem.commited, {.Read, .Write})
		assert(oka)
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

Gen_Ctx :: struct {
	using global: ^Global_Ctx,
	using types:  ^Types,
	using graph:  backend.Graph,
	node_scope:   backend.Node_ID,
	root_mem:     backend.Node_ID,
	mem_slot:     int,
	loop:         ^Loop_State,
	file:         ^ast.File,
	file_id:      File_ID,
	prc:          Proc_ID,
}

Loop_Control :: enum int {
	Break,
	Continue,
}

Loop_State :: struct {
	parent:       ^Loop_State,
	label:        string,
	using bstate: backend.Loop_State,
}

Propagation :: struct {
	dest: backend.Node_ID,
}

Ty_Propagation :: struct {
	inferred_ty: Type,
	referencing: bool,
}

ctx_ctrl :: proc(ctx: ^Gen_Ctx) -> backend.Node_ID {
	return backend.graph_inps(ctx, ctx.node_scope)[0]
}

ctx_mem :: proc(ctx: ^Gen_Ctx) -> backend.Node_ID {
	return backend.graph_get_scope_value(ctx, ctx.node_scope, ctx.mem_slot)
}

ctx_set_mem :: proc(ctx: ^Gen_Ctx, mem: backend.Node_ID) {
	backend.graph_set_input(ctx, ctx.node_scope, ctx.mem_slot, mem)
}

Value :: bit_field u32 {
	id:        backend.Node_ID | 31,
	is_lvalue: bool            | 1,
}

to_rvalue_ty :: proc(
	ctx: ^Gen_Ctx,
	value: Value,
	ty: Type,
) -> backend.Node_ID {
	if !value.is_lvalue do return value.id
	dt := type_to_dt(ty)
	assert(dt != .Void)
	// signed sub-word values must be sign extended on load since we always
	// do arithmetic in the biggest register size
	if is_signed_subword(ty) {
		return backend.graph_add_load_s(
			ctx,
			"sltr",
			dt,
			ctx_ctrl(ctx),
			ctx_mem(ctx),
			value.id,
		)
	}
	return backend.graph_add_load(
		ctx,
		"ultr",
		dt,
		ctx_ctrl(ctx),
		ctx_mem(ctx),
		value.id,
	)
}

to_rvalue :: proc {
	to_rvalue_ty,
	to_rvalue_expr,
}

to_rvalue_expr :: proc(
	ctx: ^Gen_Ctx,
	value: Value,
	node: ^ast.Node,
) -> backend.Node_ID {
	return to_rvalue(ctx, value, get_node_type(node))
}

is_signed_subword :: proc(ty: Type) -> bool {
	bt := unpack_type(ty).(Builtin) or_return
	return Type(bt) in SIGNED_TYPES && backend.DT_SIZE[type_to_dt(ty)] < 8
}

tok_to_binop :: proc(
	ty: Type,
	tok: tokenizer.Token_Kind,
) -> (
	kind: backend.Bin_Op,
	name: string,
) {
	Op_Info :: struct {
		kind: backend.Bin_Op,
		name: string,
	}

	@(static)
	@(rodata)
	SIGNED_TABLE := #partial [tokenizer.Token_Kind]Op_Info {
		.Add        = {.Add, "add"},
		.Add_Eq     = {.Add, "adde"},
		.Sub        = {.Sub, "sub"},
		.Sub_Eq     = {.Sub, "sube"},
		.Mul        = {.Mul, "mul"},
		.Mul_Eq     = {.Mul, "mule"},
		.Cmp_Eq     = {.Eq, "eq"},
		.Not_Eq     = {.Ne, "ne"},
		.Lt         = {.Lt, "lt"},
		.Lt_Eq      = {.Le, "le"},
		.Gt         = {.Gt, "gt"},
		.Gt_Eq      = {.Ge, "ge"},
		.Quo        = {.Div, "div"},
		.Quo_Eq     = {.Div, "dive"},
		.Mod        = {.Rem, "rem"},
		.Mod_Eq     = {.Rem, "reme"},
		.And        = {.And, "and"},
		.And_Eq     = {.And, "ande"},
		.Or         = {.Or, "or"},
		.Or_Eq      = {.Or, "ore"},
		.Xor        = {.Xor, "xor"},
		.Xor_Eq     = {.Xor, "xore"},
		.And_Not    = {.And_Not, "andn"},
		.And_Not_Eq = {.And_Not, "andne"},
		.Shl        = {.Shl, "shl"},
		.Shl_Eq     = {.Shl, "shle"},
		.Shr        = {.Shr, "shr"},
		.Shr_Eq     = {.Shr, "shre"},
	}

	@(static)
	@(rodata)
	UNSIGNED_TABLE := #partial [tokenizer.Token_Kind]Op_Info {
		.Lt     = {.U_Lt, "ltu"},
		.Lt_Eq  = {.U_Le, "leu"},
		.Gt     = {.U_Gt, "gtu"},
		.Gt_Eq  = {.U_Ge, "geu"},
		.Quo    = {.U_Div, "divu"},
		.Quo_Eq = {.U_Div, "diveu"},
		.Mod    = {.U_Rem, "remu"},
		.Mod_Eq = {.U_Rem, "remeu"},
		.Shr    = {.U_Shr, "shru"},
		.Shr_Eq = {.U_Shr, "shreu"},
	}

	info := SIGNED_TABLE[tok]
	uinfo := UNSIGNED_TABLE[tok]
	if ty in UNSIGNED_TYPES && uinfo.kind != {} do info = uinfo
	return info.kind, info.name
}

Sym :: union #no_nil {
	Value,
	int,
}

ctx_lookup_lvalue :: proc(ctx: ^Gen_Ctx, expr: ^ast.Node) -> Sym {
	if id, ok := expr.derived.(^ast.Ident); ok {
		#reverse for var in ctx.scope {
			if var.name == id.name {
				switch idx in var.idx {
				case int:
					return idx
				case backend.Node_ID:
					return Value{id = idx, is_lvalue = true}
				}
			}
		}

		switch id.name {
		case "false":
			return Value(backend.graph_add_c_int(ctx, "false", .I8, 0))
		case "true":
			return Value(backend.graph_add_c_int(ctx, "true", .I8, 1))
		}

		fmt.panicf("TODO: undefined variable: %v %#v", id.name, expr)
	} else {
		return emit_nodes(ctx, {}, expr)
	}
}

store_value :: proc {
	store_value_ty,
	store_value_expr,
}

store_value_expr :: proc(
	ctx: ^Gen_Ctx,
	name: string,
	ptr: backend.Node_ID,
	value: Value,
	node: ^ast.Node,
) {
	store_value(ctx, name, ptr, value, get_node_type(node))
}

store_value_ty :: proc(
	ctx: ^Gen_Ctx,
	name: string,
	ptr: backend.Node_ID,
	value: Value,
	ty: Type,
) {
	if ptr == value.id && value.is_lvalue do return

	if type_to_dt(ty) == .Void {
		fmt.assertf(value.is_lvalue, "%v %v", value, ty)
		ctx_set_mem(
			ctx,
			backend.graph_add_copy(
				ctx,
				name,
				ctx_ctrl(ctx),
				ctx_mem(ctx),
				ptr,
				value.id,
				backend.graph_add_c_int(
					ctx,
					"msize",
					.I32,
					i64(type_size(ty)),
				),
			),
		)
	} else {
		ctx_set_mem(
			ctx,
			backend.graph_add_store(
				ctx,
				name,
				ctx_ctrl(ctx),
				ctx_mem(ctx),
				ptr,
				to_rvalue(ctx, value, ty),
			),
		)
	}
}

alloca :: proc(
	ctx: ^Gen_Ctx,
	name: string,
	ty: Type,
	zeroed := true,
	is_arg := false,
	align_size_to := 1,
) -> backend.Node_ID {
	root := is_arg ? backend.NODE_ENTRY : ctx.root_mem
	alloca := backend.graph_add_local(ctx, name, root)
	size := u32(mem.align_forward_int(type_size(ty), align_size_to))
	backend.graph_extra(ctx, alloca, backend.Local).size = size
	ptr := backend.graph_add_local_addr(ctx, name, alloca)

	if zeroed {
		zero := backend.graph_add_c_int(ctx, "zero", .I8, 0)
		size := backend.graph_add_c_int(ctx, "size", .I32, i64(type_size(ty)))
		ctx_set_mem(
			ctx,
			backend.graph_add_set(
				ctx,
				"zinit",
				ctx_ctrl(ctx),
				ctx_mem(ctx),
				ptr,
				zero,
				size,
			),
		)
	}

	return ptr
}

field_offset :: proc(
	ctx: ^Gen_Ctx,
	base: backend.Node_ID,
	offset: int,
) -> backend.Node_ID {
	off := backend.graph_add_c_int(ctx, "foff", .I64, i64(offset))
	return backend.graph_add_bin_op(ctx, "fld", .Add, .I64, base, off)
}

emit_nodes :: proc(
	ctx: ^Gen_Ctx,
	prop: Propagation,
	node: ^ast.Node,
) -> Value {
	if node == nil do return {}

	ty := get_node_type(node)
	dt := type_to_dt(ty)

	res: backend.Node_ID
	lvalue: bool

	unpack :: proc(vl: Value) -> (backend.Node_ID, bool) {
		return vl.id, vl.is_lvalue
	}

	tmp, _ := arna.scrath(context.temp_allocator)

	#partial switch d in node.derived {
	case ^ast.Block_Stmt:
		prev_local_scope_len := len(ctx.scope)
		prev_scope_len :=
			backend.graph_get(ctx, ctx.node_scope).ordered_input_count
		for stmt in d.stmts {
			emit_nodes(ctx, {}, stmt)
			if ctx.node_scope == 0 do break
		}
		for v in ctx.scope[prev_local_scope_len:] {
			switch n in v.idx {
			case backend.Node_ID:
				backend.graph_unpin(ctx, n)
			case int:
			}
		}
		resize(&ctx.scope, prev_local_scope_len)
		backend.graph_truncate_scope(ctx, ctx.node_scope, prev_scope_len)
	case ^ast.Expr_Stmt:
		node := emit_nodes(ctx, {}, d.expr)
		backend.graph_delete(ctx, node.id)
	case ^ast.Assign_Stmt:
		assert(len(d.lhs) == len(d.rhs))
		Value_Slot :: struct {
			idx: int,
			vl:  backend.Node_ID,
		}
		values := make([dynamic]Value_Slot, 0, len(d.lhs), tmp)

		for i in 0 ..< len(d.lhs) {
			lhs := d.lhs[i]
			rhs := d.rhs[i]
			sym := ctx_lookup_lvalue(ctx, lhs)
			switch sym in sym {
			case int:
				value := to_rvalue(
					ctx,
					emit_nodes(ctx, {}, rhs),
					get_node_type(rhs),
				)
				if d.op.kind != .Eq {
					op, name := tok_to_binop(get_node_type(rhs), d.op.kind)
					value = auto_cast backend.graph_add_bin_op(
						ctx,
						name,
						op,
						type_to_dt(get_node_type(lhs)),
						backend.graph_get_scope_value(
							ctx,
							ctx.node_scope,
							sym,
						),
						value,
					)
				}

				backend.graph_pin(ctx, value)

				append(&values, Value_Slot{sym, value})
			case Value:
				assert(d.op.kind == .Eq)
				dest := emit_nodes(ctx, {}, lhs)
				assert(dest.is_lvalue)
				value := emit_nodes(ctx, {dest = dest.id}, rhs)
				store_value(ctx, "asss", dest.id, value, lhs)
			}
		}

		for s in values {
			backend.graph_set_input(ctx, ctx.node_scope, s.idx, s.vl)
			backend.graph_unpin(ctx, s.vl)
		}
	case ^ast.Binary_Expr:
		lhsv := emit_nodes(ctx, {}, d.left)
		backend.graph_pin(ctx, lhsv.id)
		rhsv := emit_nodes(ctx, {}, d.right)
		lhs, rhs := to_rvalue(ctx, lhsv, d.left), to_rvalue(ctx, rhsv, d.right)
		kind, name := tok_to_binop(get_node_type(d.left), d.op.kind)
		res = backend.graph_add_bin_op(ctx, name, kind, dt, lhs, rhs)
		backend.graph_unpin(ctx, lhsv.id)
	case ^ast.Unary_Expr:
		#partial switch d.op.kind {
		case .And:
			node := emit_nodes(ctx, {}, d.expr)
			assert(node.is_lvalue)
			res = node.id
		case .Not:
			operand := to_rvalue(ctx, emit_nodes(ctx, {}, d.expr), d.expr)
			zero := backend.graph_add_c_int(ctx, "zero", dt, 0)
			res = backend.graph_add_bin_op(ctx, "lnot", .Eq, dt, operand, zero)
		case .Sub, .Xor:
			oty := get_node_type(d.expr)
			operand := to_rvalue(ctx, emit_nodes(ctx, {}, d.expr), d.expr)

			op: backend.Un_Op = d.op.kind == .Sub ? .Neg : .Not
			name := d.op.kind == .Sub ? "neg" : "not"
			res = backend.graph_add_un_op(ctx, name, op, dt, operand)
		case:
			fmt.panicf("TODO: %#v", node.derived)
		}
	case ^ast.Deref_Expr:
		res = to_rvalue(ctx, emit_nodes(ctx, {}, d.expr), d.expr)
		lvalue = true
	case ^ast.Return_Stmt:
		values := make([]backend.Node_ID, 2 + len(d.results) * 2, tmp)
		assert(len(d.results) == 1)
		i := 2
		for r in d.results {
			ty := get_node_type(r)
			dt = type_to_dt(ty)
			vl := emit_nodes(ctx, {}, r)

			if dt == .Void {
				assert(vl.is_lvalue)
				size := type_size(ty)
				switch size {
				case 1 ..= 16:
					values[i] = emit_arbitrary_load(ctx, vl.id, size)
					i += 1

					if size > 8 {
						values[i] = emit_arbitrary_load(ctx, vl.id, size, 8)
						i += 1
					}
				}
			} else {
				values[i] = to_rvalue(ctx, vl, r)
				i += 1
			}
		}
		values[0] = ctx_ctrl(ctx)
		values[1] = ctx_mem(ctx)
		backend.graph_merge_returns(ctx, values[:i])
		backend.graph_delete(ctx, ctx.node_scope)
		ctx.node_scope = 0
	case ^ast.Basic_Lit:
		#partial switch d.tok.kind {
		case .Integer:
			value, ok := strconv.parse_i64(d.tok.text)
			assert(ok)
			res = backend.graph_add_c_int(ctx, "cnst", dt, value)
		case:
			fmt.panicf("TODO: %#v", node.derived)
		}
	case ^ast.Value_Decl:
		assert(len(d.names) == len(d.values))
		for i in 0 ..< len(d.names) {
			name := meta.src_of(ctx.file^, d.names[i])
			vty := get_node_type(d.values[i])
			flags := get_node_vflags(d.names[i])

			if .Referenced in flags || type_to_dt(vty) == .Void {
				ptr := alloca(
					ctx,
					name,
					vty,
					zeroed = type_to_dt(vty) == .Void,
				)
				backend.graph_pin(ctx, ptr)

				value := emit_nodes(ctx, {dest = ptr}, d.values[i])
				store_value(ctx, "init", ptr, value, vty)

				append(&ctx.scope, Variable{name, ptr, vty, d.names[i], flags})
			} else {
				value := to_rvalue(
					ctx,
					emit_nodes(ctx, {}, d.values[i]),
					d.values[i],
				)
				backend.graph_set_name(ctx, value, name)
				idx := backend.graph_push_scope_value(
					ctx,
					ctx.node_scope,
					value,
				)
				append(&ctx.scope, Variable{name, idx, vty, d.names[i], flags})
			}
		}
	case ^ast.Comp_Lit:
		dest := prop.dest != 0 ? prop.dest : alloca(ctx, "comp", ty)

		#partial switch t in unpack_type(ty) {
		case ^Struct:
			for elem, i in d.elems {
				offset: int
				ast_value: ^ast.Node
				#partial switch e in elem.derived {
				case ^ast.Field_Value:
					offset = get_node_data(e.field, int)
					ast_value = e.value
				case:
					offset = t.fields[i].offset
					ast_value = elem
				}

				field_ptr := field_offset(ctx, dest, offset)
				value := emit_nodes(ctx, {dest = field_ptr}, ast_value)
				store_value(ctx, "finit", field_ptr, value, ast_value)
			}
			res, lvalue = dest, true
		case:
			fmt.panicf("TODO: %#v", d)
		}
	case ^ast.Selector_Expr:
		base := emit_nodes(ctx, {}, d.expr)
		base_ty := unpack_type(get_node_type(d.expr))
		#partial switch f in d.field.derived {
		case ^ast.Ident:
			if pty, ok := base_ty.(Pointer); ok {
				base_ty = unpack_type(pty^)
				base.is_lvalue = true
			}

			#partial switch t in base_ty {
			case ^Struct:
				assert(base.is_lvalue)
				offset := get_node_data(d.field, int)
				field_ptr := field_offset(ctx, base.id, offset)
				res, lvalue = field_ptr, true
			case:
				fmt.panicf("TODO: %#v", t)
			}
		case:
			fmt.panicf("TODO: %#v", d.field.derived)
		}
	case ^ast.Ident:
		sym := ctx_lookup_lvalue(ctx, d)
		switch sym in sym {
		case int:
			res = backend.graph_get_scope_value(ctx, ctx.node_scope, sym)
			assert(backend.graph_get(ctx, res).btype != .Scope)
		case Value:
			res, lvalue = unpack(sym)
		}
	case ^ast.Paren_Expr:
		res, lvalue = unpack(emit_nodes(ctx, prop, d.expr))
	case ^ast.If_Stmt:
		cond := to_rvalue(ctx, emit_nodes(ctx, {}, d.cond), d.cond)

		if_state: backend.If_State
		backend.graph_start_if(ctx, ctx.node_scope, &if_state, cond)
		emit_nodes(ctx, {}, d.body)
		backend.graph_start_else(ctx, &ctx.node_scope, &if_state)
		emit_nodes(ctx, {}, d.else_stmt)
		backend.graph_end_else(ctx, &ctx.node_scope, &if_state)
	case ^ast.For_Stmt:
		assert(d.init == nil)
		assert(d.cond == nil)
		assert(d.post == nil)

		loop_state: Loop_State
		loop_state.label = meta.src_of(ctx.file^, d.label)
		loop_state.parent = ctx.loop
		ctx.loop = &loop_state

		backend.graph_start_loop(ctx, ctx.node_scope, &loop_state)
		emit_nodes(ctx, {}, d.body)
		backend.graph_end_loop(ctx, &ctx.node_scope, &loop_state)

		ctx.loop = ctx.loop.parent
	case ^ast.Call_Expr:
		CALL_PREFIX :: 2

		args := make([]backend.Node_ID, CALL_PREFIX + len(d.args) * 2, tmp)

		base_ty := get_node_type(d.expr)

		#partial switch t in unpack_type(base_ty) {
		case ^Lit:
			idx := u32(t.(Proc_ID))

			prc := &ctx.procs[idx]

			gpa_fuel := 6
			i := CALL_PREFIX
			ri := len(args)
			for arg in d.args {
				ty := get_node_type(arg)
				vl := emit_nodes(ctx, {}, arg)

				is_stack := false
				if type_to_dt(ty) == .Void {
					assert(vl.is_lvalue)

					size := type_size(ty)
					switch size {
					case 0:
						continue
					case 1 ..= 8:
						args[i] = emit_arbitrary_load(ctx, vl.id, size)
						backend.graph_pin(ctx, args[i])
						i += 1
						gpa_fuel -= 1
						continue
					case 9 ..= 16:
						if gpa_fuel < 2 {
							slot := alloca(ctx, "sarg", ty, is_arg = true)
							store_value(ctx, "ast", slot, vl, ty)
							local := backend.graph_inps(ctx, slot)[0]
							ri -= 1
							args[ri] = local
							backend.graph_pin(ctx, local)
							continue
						}

						args[i] = backend.graph_add_load(
							ctx,
							"afld",
							.I64,
							ctx_ctrl(ctx),
							ctx_mem(ctx),
							vl.id,
						)
						backend.graph_pin(ctx, args[i])
						i += 1

						args[i] = emit_arbitrary_load(ctx, vl.id, size, 8)
						backend.graph_pin(ctx, args[i])
						i += 1
						gpa_fuel -= 2
						continue
					case 17 ..= int(~uint(0) >> 1):
						is_stack = true
					case:
						fmt.panicf("unsupported type: %v", ty)
					}
				}

				if is_stack {
					args[i] = vl.id
				} else {
					args[i] = to_rvalue(ctx, vl, ty)
				}
				gpa_fuel -= 1
				if gpa_fuel < 0 {
					ty := get_node_type(arg)
					slot := alloca(
						ctx,
						"aspl",
						ty,
						zeroed = false,
						is_arg = true,
					)
					store_value(ctx, "ast", slot, Value(args[i]), ty)
					local := backend.graph_inps(ctx, slot)[0]
					ri -= 1
					args[ri] = local
					backend.graph_pin(ctx, args[ri])
				} else {
					backend.graph_pin(ctx, args[i])
					i += 1
				}
			}
			args[0] = ctx_ctrl(ctx)
			args[1] = ctx_mem(ctx)

			slice.reverse(args[ri:])
			copy(args[i:], args[ri:])
			ln := i + len(args) - ri

			call := backend.graph_add_call(ctx, "call", args[:ln], idx)
			cnode := backend.graph_get(ctx, call)
			cnode.ordered_input_count = u16(i)
			for arg in args[CALL_PREFIX:ln] {
				backend.graph_unpin(ctx, arg)
			}
			call_end := backend.graph_add_call_end(ctx, "calle", call)

			backend.graph_set_input(ctx, ctx.node_scope, 0, call_end)
			ctx_set_mem(ctx, backend.graph_add_mem(ctx, "cmem", call_end))

			assert(len(prc.rets) == 1)
			ty := prc.rets[0].type
			dt = type_to_dt(ty)

			if dt == .Void {
				size := type_size(ty)
				switch size {
				case 1 ..= 16:
					dest := prop.dest
					if dest == 0 do dest = alloca(ctx, "sret", ty)

					vl := backend.graph_add_ret(ctx, "cret", .I64, call_end, 0)
					emit_arbitrary_store(ctx, dest, vl, size)

					if size > 8 {
						svl := backend.graph_add_ret(
							ctx,
							"cret",
							.I64,
							call_end,
							1,
						)
						emit_arbitrary_store(ctx, dest, svl, size, 8)
					}

					res = dest
					lvalue = true
				}
			} else {
				res = backend.graph_add_ret(ctx, "cret", dt, call_end, 0)
			}
		case Builtin:
			dest_dt := type_to_dt(base_ty)
			arg := to_rvalue(ctx, emit_nodes(ctx, {}, d.args[0]), d.args[0])

			op: backend.Un_Op = .Uext
			if get_node_type(d.args[0]) in SIGNED_TYPES {
				op = .Sext
			}
			if type_size(get_node_type(d.args[0])) > type_size(base_ty) {
				op = .Cast
			}

			res = backend.graph_add_un_op(ctx, "cst", op, dest_dt, arg)
		case:
			fmt.panicf("TODO: %v %v", t, node)
		}
	case ^ast.Branch_Stmt:
		label := meta.src_of(ctx.file^, d.label)

		loop := ctx.loop
		for ; loop != nil; loop = loop.parent {
			if loop.label == label || label == "" {
				break
			}
		}
		assert(loop != nil)

		variant := backend.Loop_Control(-1)
		#partial switch d.tok.kind {
		case .Break:
			variant = .Break
		case .Continue:
			variant = .Continue
		case:
			fmt.panicf("TODO: %#v", node.derived)
		}

		backend.graph_loop_control(variant, ctx, ctx.node_scope, loop)
		ctx.node_scope = 0
	case:
		fmt.panicf("TODO: %#v", node.derived)
	}

	res = backend.graph_peep(ctx, res)

	return {id = res, is_lvalue = lvalue}
}

emit_arbitrary_store :: proc(
	ctx: ^Gen_Ctx,
	addr: backend.Node_ID,
	value: backend.Node_ID,
	size: int,
	extra_offset := 0,
) {
	store_unit := backend.Node_Datatype.I64
	size := min(size - extra_offset, 8)
	offset: int

	for offset < size {
		for backend.DT_SIZE[store_unit] + offset > size {
			store_unit = backend.Node_Datatype(u8(store_unit) - 1)
			assert(store_unit != .Void)
		}

		value := backend.graph_add_un_op(
			ctx,
			"rvl",
			.Cast,
			store_unit,
			backend.graph_add_bin_op(
				ctx,
				"stsh",
				.U_Shr,
				.I64,
				value,
				backend.graph_add_c_int(ctx, "stshoff", .I64, i64(offset * 8)),
			),
		)

		ctx_set_mem(
			ctx,
			backend.graph_add_store(
				ctx,
				"asld",
				ctx_ctrl(ctx),
				ctx_mem(ctx),
				backend.graph_add_bin_op(
					ctx,
					"asstof",
					.Add,
					.I64,
					addr,
					backend.graph_add_c_int(
						ctx,
						"asstofc",
						.I64,
						i64(offset + extra_offset),
					),
				),
				value,
			),
		)

		offset += backend.DT_SIZE[store_unit]
	}
}

emit_arbitrary_load :: proc(
	ctx: ^Gen_Ctx,
	addr: backend.Node_ID,
	size: int,
	extra_offset := 0,
) -> backend.Node_ID {
	load_unit := backend.Node_Datatype.I64
	size := min(size - extra_offset, 8)
	offset: int
	value: backend.Node_ID

	for offset < size {
		for backend.DT_SIZE[load_unit] + offset > size {
			load_unit = backend.Node_Datatype(u8(load_unit) - 1)
			assert(load_unit != .Void)
		}

		load := backend.graph_add_load(
			ctx,
			"asld",
			load_unit,
			ctx_ctrl(ctx),
			ctx_mem(ctx),
			backend.graph_add_bin_op(
				ctx,
				"asldof",
				.Add,
				.I64,
				addr,
				backend.graph_add_c_int(
					ctx,
					"asldofc",
					.I64,
					i64(offset + extra_offset),
				),
			),
		)

		if value == 0 {
			value = load
			assert(offset == 0)
		} else {
			value = backend.graph_add_bin_op(
				ctx,
				"aor",
				.Or,
				.I64,
				value,
				backend.graph_add_bin_op(
					ctx,
					"ash",
					.Shl,
					.I64,
					load,
					backend.graph_add_c_int(
						ctx,
						"ssham",
						.I64,
						i64(offset * 8),
					),
				),
			)
		}

		offset += backend.DT_SIZE[load_unit]
	}

	return value
}
