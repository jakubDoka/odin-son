package main

import zydis "./zydis"
import "backend"
import "core:fmt"
import "core:io"
import "core:log"
import "core:mem/virtual"
import "core:odin/ast"
import "core:odin/parser"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:sync"
import "core:sys/info"
import "core:testing"
import "meta"
import "vendored/gam/util/arna"
import "vendored/gam/util/hot"

TEST_OUT_DIR :: "print-tests"

split_lines :: proc(input: string) -> []string {
	lines := make([dynamic]string)

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
			fmt.sbprintf(out, " %s\n", lines_a[i])
			i += 1
			j += 1
			k += 1
		} else if j < len(lines_b) && (k >= len(lcs) || lines_b[j] != lcs[k]) {
			fmt.sbprintf(out, "\x1b[32m+%s\x1b[0m\n", lines_b[j])
			j += 1
		} else if i < len(lines_a) && (k >= len(lcs) || lines_a[i] != lcs[k]) {
			fmt.sbprintf(out, "\x1b[31m-%s\x1b[0m\n", lines_a[i])
			i += 1
		} else {
			panic("unreachable")
		}
	}
}

disasm :: proc(sb: ^strings.Builder, instructions: []u8) {
	runtime_address: zydis.U64 = 0x0040_0000

	jumps: map[int]int

	is_jump :: proc(mne: zydis.Mnemonic) -> bool {
		return mne == .JZ || mne == .JMP
	}

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
			offset := offset + length + int(instr.operands[0].imm.value.s)
			if offset not_in jumps {
				jumps[offset] = len(jumps)
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
			fmt.sbprintf(sb, "%02i:", off)
		} else if len(jumps) != 0 {
			fmt.sbprint(sb, "   ")
		}

		// Raw bytes of just this instruction.
		length := int(instr.info.length)
		for b in instructions[offset:offset + length] {
			fmt.sbprintf(sb, "%02x ", b)
		}
		for _ in length ..< 12 {
			fmt.sbprint(sb, "   ")
		}

		text := string(cstring(&instr.text[0]))
		if is_jump(instr.info.mnemonic) {
			offset := offset + length + int(instr.operands[0].imm.value.s)
			text = fmt.tprintfln(
				"%v :%v",
				zydis.MnemonicGetString(instr.info.mnemonic),
				jumps[offset],
			)
		}

		fmt.sbprintfln(sb, "%s", text)

		offset += length
	}
}

highlight_disasm :: proc(disasm: string) -> string {
	text := disasm

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

	for name, i in gp_register_names {
		highlight: strings.Builder

		backend.ansi_start(&highlight, i)
		append(&highlight.buf, name)
		backend.ansi_end(&highlight)

		text, _ = strings.replace_all(text, name, string(highlight.buf[:]))
	}

	for i in 0 ..< 100 {
		off := i * 8

		name := fmt.tprintf("0x%02x]", off)

		highlight: strings.Builder

		backend.ansi_start(&highlight, i)
		append(&highlight.buf, name)
		backend.ansi_end(&highlight)

		text, _ = strings.replace_all(text, name, string(highlight.buf[:]))
	}

	return text
}

fmts_once: sync.Once
fmts: map[typeid]fmt.User_Formatter
@(thread_local)
current_graph: ^backend.Graph

init_custom_fmt :: proc() {
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
			return true
		},
	)

	fmt.register_user_formatter(
		backend.Node_ID,
		proc(fi: ^fmt.Info, value: any, r: rune) -> bool {
			value := value.(backend.Node_ID)
			sb: strings.Builder
			if value != 0 {
				backend.graph_display_node_gvn(&sb, current_graph, value)
			} else {
				append(&sb.buf, "nl")
			}
			io.write(fi.writer, sb.buf[:])
			return true
		},
	)
}

once: sync.Once

run_test :: proc(t: ^testing.T, name: string, source: string) {
	context.assertion_failure_proc = hot.init_trace()
	context.allocator = context.temp_allocator

	sync.once_do(
		&once,
		proc() {
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

	p := parser.Parser{}
	f := ast.File {
		src      = source,
		fullpath = "test",
	}
	ok := parser.parse_file(&p, &f); assert(ok)

	main: ^ast.Proc_Lit
	expected_return := 0
	for decl in f.decls {
		if sdecl, ok := decl.derived_stmt.(^ast.Value_Decl); ok {
			if meta.src_of(f, sdecl.names[0]) == "main" {
				main = sdecl.values[0].derived.(^ast.Proc_Lit)
			}

			if meta.src_of(f, sdecl.names[0]) == "return_value" {
				expected_return =
					strconv.parse_int(
						meta.src_of(f, sdecl.values[0]),
					) or_else panic("")
			}
		}
	}

	assert(main != nil)

	graph_mem := arna.Allocator {
		reserved = 4096 * 16,
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

	_ = arna.bulk_init(&graph_mem, &regalloc_mem, &scratch_mem, &code_mem)
	defer arna.bulk_destroy(&graph_mem, &regalloc_mem, &scratch_mem, &code_mem)

	graph: Ctx
	graph.node_spec = &backend.SPECS[.Builder]
	graph.mem = &graph_mem
	graph.mem.pos += backend.PRECISION
	graph.file = &f

	current_graph = &graph

	start := backend.graph_add_start(&graph, "start")
	assert(start == backend.NODE_START)
	entry := backend.graph_add_entry(&graph, "entry", start)
	assert(entry == backend.NODE_ENTRY)

	graph.node_scope = backend.graph_add_scope(&graph, "scope", entry)

	emit_nodes(&graph, {}, main.body)

	spec := &backend.SPECS[.X64]
	graph.node_spec = spec

	schedule: backend.Graph_Schedule
	backend.graph_schedule(&graph, &schedule)

	ra: backend.Regalloc
	ra.spec = spec
	ra.alloc = &regalloc_mem

	regs := backend.regalloc(&ra, &graph, &schedule)

	sb: strings.Builder
	if backend.REGLOGS {
		append(&sb.buf, "\n")
		backend.graph_display(&sb, &graph, &schedule, regs = regs)
		log.info(string(sb.buf[:]))
	}

	ctx := backend.Codegen_Emit_Ctx {
		graph = &graph,
		schedule = &schedule,
		buf = {scratch = &scratch_mem, code = &code_mem},
		allocs = regs,
	}
	output := spec.emit_function(ctx)

	diff_path, _ := os.join_path({TEST_OUT_DIR, name}, context.allocator)
	file, err := os.read_entire_file(diff_path, context.allocator)

	clear(&sb.buf)
	disasm(&sb, output.code)

	if err == .Not_Exist || #config(ACCEPT, false) {
		err := os.write_entire_file(diff_path, sb.buf[:])
		assert(err == nil)
	} else {
		assert(err == nil)
		new, old := string(sb.buf[:]), string(file)
		if new != old {
			new, old = highlight_disasm(new), highlight_disasm(old)
			clear(&sb.buf)
			append(&sb.buf, "\n")
			print_diff(&sb, old, new)
			log.error(string(sb.buf[:]))
		}
	}

	oka := virtual.protect(raw_data(output.code), 4096, {.Read, .Execute})
	assert(oka)

	ptr := transmute(proc() -> int)(raw_data(output.code))
	testing.expect_value(t, ptr(), expected_return)
}

Variable :: struct {
	name: string,
	idx:  int,
}

Ctx :: struct {
	using graph: backend.Graph,
	scope:       [dynamic]Variable,
	node_scope:  backend.Node_ID,
	file:        ^ast.File,
}

Propagation :: struct {}

ctx_ctrl :: proc(ctx: ^Ctx) -> backend.Node_ID {
	return backend.graph_inps(ctx, ctx.node_scope)[0]
}

emit_nodes :: proc(
	ctx: ^Ctx,
	prop: Propagation,
	node: ^ast.Node,
) -> backend.Node_ID {
	if node == nil do return 0

	#partial switch d in node.derived {
	case ^ast.Block_Stmt:
		prev_scope_len :=
			backend.graph_get(ctx, ctx.node_scope).ordered_input_count
		for stmt in d.stmts {
			emit_nodes(ctx, {}, stmt)
		}
		resize(&ctx.scope, prev_scope_len)
		backend.graph_truncate_scope(ctx, ctx.node_scope, prev_scope_len)
	case ^ast.Assign_Stmt:
		assert(len(d.lhs) == len(d.rhs))
		for i in 0 ..< len(d.lhs) {
			lhs := d.lhs[i]
			rhs := d.rhs[i]
			name := meta.src_of(ctx.file^, lhs)
			value := emit_nodes(ctx, {}, rhs)
			for var in ctx.scope {
				if var.name == name {
					backend.graph_set_input(
						ctx,
						ctx.node_scope,
						var.idx,
						value,
					)
				}
			}
		}
		return 0
	case ^ast.Binary_Expr:
		lhs, rhs := emit_nodes(ctx, {}, d.left), emit_nodes(ctx, {}, d.right)
		#partial switch d.op.kind {
		case .Add:
			return backend.graph_add_add(ctx, "add", .I64, lhs, rhs)
		case .Mul:
			return backend.graph_add_mul(ctx, "mul", .I64, lhs, rhs)
		case .Cmp_Eq:
			return backend.graph_add_eq(ctx, "eq", .I64, lhs, rhs)
		case:
			fmt.panicf("TODO: %#v", node.derived)
		}
	case ^ast.Return_Stmt:
		values := make([]backend.Node_ID, 1 + len(d.results))
		values[0] = ctx_ctrl(ctx)
		for r, i in d.results {
			values[1 + i] = emit_nodes(ctx, {}, r)
		}
		ctx.end = backend.graph_add_return(ctx, "ret", values)
		backend.graph_delete(ctx, ctx.node_scope)
		ctx.node_scope = 0
	case ^ast.Basic_Lit:
		#partial switch d.tok.kind {
		case .Integer:
			value, ok := strconv.parse_i64(d.tok.text)
			assert(ok)
			return backend.graph_add_cint(ctx, "cnst", .I64, value)
		case:
			fmt.panicf("TODO: %#v", node.derived)
		}
	case ^ast.Value_Decl:
		assert(len(d.names) == len(d.values))
		for i in 0 ..< len(d.names) {
			name := meta.src_of(ctx.file^, d.names[i])
			value := emit_nodes(ctx, {}, d.values[i])

			backend.graph_set_name(ctx, value, name)
			idx := backend.graph_push_scope_value(ctx, ctx.node_scope, value)
			append(&ctx.scope, Variable{name, idx})
		}
	case ^ast.Ident:
		name := meta.src_of(ctx.file^, node)

		for var in ctx.scope {
			if var.name == name {
				return backend.graph_get_scope_value(
					ctx,
					ctx.node_scope,
					var.idx,
				)
			}
		}

		fmt.panicf("TODO: undefined variable: %v", name)
	case ^ast.Paren_Expr:
		return emit_nodes(ctx, prop, d.expr)
	case ^ast.If_Stmt:
		cond := emit_nodes(ctx, {}, d.cond)
		if_id := backend.graph_add_if(ctx, "if", ctx_ctrl(ctx), cond)

		else_scope := backend.graph_clone(ctx, ctx.node_scope)

		then := backend.graph_add_then(ctx, "then", if_id)
		backend.graph_set_input(ctx, ctx.node_scope, 0, then)
		emit_nodes(ctx, {}, d.body)
		then_scope := ctx.node_scope

		else_ := backend.graph_add_else(ctx, "else", if_id)
		ctx.node_scope = else_scope
		backend.graph_set_input(ctx, ctx.node_scope, 0, else_)
		emit_nodes(ctx, {}, d.else_stmt)
		else_scope = ctx.node_scope

		ctx.node_scope = backend.graph_merge_scopes(
			ctx,
			then_scope,
			else_scope,
		)
	case:
		fmt.panicf("TODO: %#v", node.derived)
	}

	return 0
}
