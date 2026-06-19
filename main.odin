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
import "core:reflect"
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

disasm :: proc(sb: ^strings.Builder, ctx: Ctx) {
	runtime_address: zydis.U64 = 0x0040_0000

	jumps: map[int]int

	is_jump :: proc(mne: zydis.Mnemonic) -> bool {
		return mne == .JZ || mne == .JMP
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
				fmt.sbprintf(sb, "%03i: ", off)
			} else if len(jumps) != 0 {
				fmt.sbprint(sb, "     ")
			}

			length := int(instr.info.length)

			text := string(cstring(&instr.text[0]))
			if is_jump(instr.info.mnemonic) {
				offset := offset + length + int(instr.operands[0].imm.value.s)
				text = fmt.tprintf(
					"%v :%v",
					zydis.MnemonicGetString(instr.info.mnemonic),
					jumps[offset],
				)
			} else if instr.info.mnemonic == .CALL {
				for reloc in prc.out.relocs {
					if int(reloc.offset) == offset + length {
						text = fmt.tprintf(
							"%v :%v",
							zydis.MnemonicGetString(instr.info.mnemonic),
							ctx.procs[reloc.id].name,
						)
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

		backend.ansi_start(strings.to_writer(&highlight), i)
		append(&highlight.buf, name)
		backend.ansi_end(strings.to_writer(&highlight))

		text, _ = strings.replace_all(text, name, string(highlight.buf[:]))
	}

	for i in 0 ..< 100 {
		off := i * 8

		name := fmt.tprintf("0x%02x]", off)

		highlight: strings.Builder

		backend.ansi_start(strings.to_writer(&highlight), i)
		append(&highlight.buf, name)
		backend.ansi_end(strings.to_writer(&highlight))

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

once: sync.Once

run_test :: proc(t: ^testing.T, name: string, source: string, exit_code: int) {
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

	ctx: Ctx

	for decl in f.decls {
		if sdecl, ok := decl.derived_stmt.(^ast.Value_Decl); ok {
			if prc, ok := sdecl.values[0].derived.(^ast.Proc_Lit); ok {
				plist := prc.type.params.list
				rlist := prc.type.results.list

				params := make([]Param, len(plist))
				rets := make([]Param, len(rlist))

				lists := [][]^ast.Field{plist, rlist}
				tys := [][]Param{params, rets}

				for list, j in lists {
					tys := tys[j]

					for param, i in list {
						assert(len(param.names) <= 1)
						name := ""
						if len(param.names) == 1 {
							name = meta.src_of(f, param.names[0])
						}
						#partial switch d in param.type.derived {
						case ^ast.Ident:
							switch d.name {
							case "int":
								tys[i] = {name, .Int}
							case:
								fmt.panicf("TODO: %#v", param.type.derived)
							}
						case:
							fmt.panicf("TODO: %#v", param.type.derived)
						}
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
	reloc_mem := arna.Allocator {
		reserved = 4096 * 16,
	}

	_ = arna.bulk_init(
		&graph_mem,
		&regalloc_mem,
		&scratch_mem,
		&code_mem,
		&reloc_mem,
	)
	defer arna.bulk_destroy(
		&graph_mem,
		&regalloc_mem,
		&scratch_mem,
		&code_mem,
		&reloc_mem,
	)

	for &prc, i in ctx.procs {

		ctx.graph = {}
		ctx.node_spec = &backend.SPECS[.Builder]
		ctx.mem = &graph_mem
		ctx.mem.pos = backend.PRECISION
		ctx.file = &f

		current_graph = &ctx

		start := backend.graph_add_start(&ctx, "start")
		assert(start == backend.NODE_START)
		entry := backend.graph_add_entry(&ctx, "entry", start)
		assert(entry == backend.NODE_ENTRY)

		ctx.node_scope = backend.graph_add_scope(&ctx, "scope", entry)

		for par, i in prc.params {
			assert(par.type == .Int)
			value := backend.graph_add_arg(&ctx, "arg", .I64, entry, u32(i))
			idx := backend.graph_push_scope_value(&ctx, ctx.node_scope, value)
			append(&ctx.scope, Variable{par.name, idx})
		}

		emit_nodes(&ctx, {}, prc.ast.body)

		spec := &backend.SPECS[.X64]
		ctx.node_spec = spec

		schedule: backend.Graph_Schedule
		backend.graph_schedule(&ctx, &schedule)

		ra: backend.Regalloc
		ra.spec = spec
		ra.alloc = &regalloc_mem

		regs := backend.regalloc(&ra, &ctx, &schedule)

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
			buf = {
				scratch = &scratch_mem,
				code = &code_mem,
				relocs = &reloc_mem,
			},
			allocs = regs,
		}
		prc.out = spec.emit_function(ctx)

	}

	for p in ctx.procs {
		for rel in p.out.relocs {
			target := &ctx.procs[rel.id]
			target_off := uintptr(raw_data(target.out.code))
			source := uintptr(raw_data(p.out.code)) + uintptr(rel.offset)
			jump := u32(target_off - source)
			assert(rel.size == .r4)
			slot := p.out.code[rel.offset - 4:][:4]
			copy(slot, reflect.as_bytes(jump))
		}
	}

	dsb: strings.Builder
	disasm(&dsb, ctx)

	diff_path, _ := os.join_path({TEST_OUT_DIR, name}, context.allocator)
	file, err := os.read_entire_file(diff_path, context.allocator)

	DO_DIFFING :: #config(DIFF, true)

	if #config(ACCEPT, false) {
		err := os.write_entire_file(diff_path, dsb.buf[:])
		assert(err == nil)
	} else if err == .Not_Exist {
		if DO_DIFFING {
			log.error("\n", highlight_disasm(string(dsb.buf[:])), sep = "")
		}
	} else {
		if DO_DIFFING {
			assert(err == nil)
			new, old := string(dsb.buf[:]), string(file)
			if new != old {
				new, old = highlight_disasm(new), highlight_disasm(old)
				clear(&dsb.buf)
				append(&dsb.buf, "\n")
				print_diff(&dsb, old, new)
				log.error(string(dsb.buf[:]))
			}
		}
	}

	oka := virtual.protect(code_mem.ptr, code_mem.commited, {.Read, .Execute})
	assert(oka)

	ptr := transmute(proc() -> int)(code_mem.ptr)
	testing.expect_value(t, ptr(), exit_code)
}

Type :: enum u32 {
	Int,
}

Proc :: struct {
	name:   string,
	params: []Param,
	rets:   []Param,
	ast:    ^ast.Proc_Lit,
	out:    backend.Codegen_Output,
}

Param :: struct {
	name: string,
	type: Type,
}

Variable :: struct {
	name: string,
	idx:  int,
}

Ctx :: struct {
	using graph: backend.Graph,
	procs:       [dynamic]Proc,
	scope:       [dynamic]Variable,
	node_scope:  backend.Node_ID,
	loop:        ^Loop_State,
	file:        ^ast.File,
}

Loop_Control :: enum int {
	Break,
	Continue,
}

Loop_State :: struct {
	parent: ^Loop_State,
	label:  string,
	scope:  backend.Node_ID,
	scopes: [Loop_Control]backend.Node_ID,
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
			if ctx.node_scope == 0 do break
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
					#partial switch d.op.kind {
					case .Eq:
					case .Add_Eq:
						value = backend.graph_add_add(
							ctx,
							"adde",
							.I64,
							backend.graph_get_scope_value(
								ctx,
								ctx.node_scope,
								var.idx,
							),
							value,
						)
					case .Sub_Eq:
						value = backend.graph_add_sub(
							ctx,
							"sube",
							.I64,
							backend.graph_get_scope_value(
								ctx,
								ctx.node_scope,
								var.idx,
							),
							value,
						)
					case:
						fmt.panicf("TODO: %#v", node.derived)
					}

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
		case .Sub:
			return backend.graph_add_sub(ctx, "sub", .I64, lhs, rhs)
		case .Mul:
			return backend.graph_add_mul(ctx, "mul", .I64, lhs, rhs)
		case .Cmp_Eq:
			return backend.graph_add_eq(ctx, "eq", .I64, lhs, rhs)
		case .Not_Eq:
			return backend.graph_add_ne(ctx, "ne", .I64, lhs, rhs)
		case .Lt_Eq:
			return backend.graph_add_le(ctx, "le", .I64, lhs, rhs)
		case:
			fmt.panicf("TODO: %#v", node.derived)
		}
	case ^ast.Return_Stmt:
		values := make([]backend.Node_ID, 1 + len(d.results))
		for r, i in d.results {
			values[1 + i] = emit_nodes(ctx, {}, r)
		}
		values[0] = ctx_ctrl(ctx)
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
		name := d.name

		for var in ctx.scope {
			if var.name == name {
				val := backend.graph_get_scope_value(
					ctx,
					ctx.node_scope,
					var.idx,
				)
				assert(backend.graph_get(ctx, val).btype != .Scope)
				return val
			}
		}

		switch name {
		case "false":
			return backend.graph_add_cint(ctx, "false", .I64, 0)
		}

		fmt.panicf("TODO: undefined variable: %v %#v", name, d)
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
	case ^ast.For_Stmt:
		assert(d.init == nil)
		assert(d.cond == nil)
		assert(d.post == nil)

		loop := backend.graph_add_loop(ctx, "loop", ctx_ctrl(ctx))
		backend.graph_set_input(ctx, ctx.node_scope, 0, loop)

		loop_state: Loop_State
		loop_state.label = meta.src_of(ctx.file^, d.label)
		loop_state.parent = ctx.loop
		loop_state.scope = backend.graph_clone(ctx, ctx.node_scope)
		ctx.loop = &loop_state

		backend.graph_add_output(ctx, loop_state.scope, 0, 0)

		scope := backend.graph_get(ctx, ctx.node_scope)
		for i in 1 ..< scope.ordered_input_count {
			backend.graph_set_input(ctx, ctx.node_scope, i, loop_state.scope)
		}

		emit_nodes(ctx, {}, d.body)

		ctx.node_scope = backend.graph_merge_scopes(
			ctx,
			ctx.node_scope,
			loop_state.scopes[.Continue],
		)

		init := backend.graph_expand(ctx, loop_state.scope)
		bscope := ctx.node_scope
		if bscope != 0 {
			backedge := backend.graph_expand(ctx, ctx.node_scope)
			assert(init.ordered_input_count == backedge.ordered_input_count)
			for i in 1 ..< init.ordered_input_count {
				init := init.inps[i]
				inode := backend.graph_expand(ctx, init)
				bnode := backend.graph_expand(ctx, backedge.inps[i])
				if inode.btype == .Lazy_Phi {
					for {
						scp := backend.graph_extra(ctx, bnode, backend.Scope)
						if scp == nil || !scp.done || bnode.inps[0] == loop {
							break
						}
						bnode = backend.graph_expand(ctx, bnode.inps[i])
					}

					if bnode.btype == .Scope || inode.node == bnode.node {
						backend.graph_subsume(ctx, inode.inps[1], init)
					} else {
						backend.graph_add_extra_input(
							ctx,
							inode,
							backend.graph_id(ctx, bnode),
						)
						inode.itype = .Phi
						backend.graph_intern(ctx, init)
					}
				}
			}

			assert(backend.graph_get(ctx, init.inps[0]).itype == .Loop)
			backend.graph_add_extra_input(ctx, init.inps[0], backedge.inps[0])
		}

		ctx.node_scope = loop_state.scopes[.Break]

		if ctx.node_scope != 0 {
			exit := backend.graph_expand(ctx, ctx.node_scope)
			for i in 1 ..< exit.ordered_input_count {
				enode := backend.graph_get(ctx, exit.inps[i])
				if enode.btype == .Scope {
					backend.graph_set_input(
						ctx,
						ctx.node_scope,
						i,
						init.inps[i],
					)
				}
			}
		}

		backend.graph_extra(ctx, loop_state.scope, backend.Scope).done = true
		backend.graph_remove_output(ctx, loop_state.scope, {id = 0, idx = 0})

		if bscope != 0 {
			backend.graph_delete(ctx, bscope)
		} else {
			for out in backend.graph_outs(ctx, loop) {
				onode := backend.graph_expand(ctx, out.id)
				if onode.btype == .Lazy_Phi {
					backend.graph_subsume(ctx, onode.inps[1], out.id)
				}
			}

			backend.graph_subsume(ctx, backend.graph_inps(ctx, loop)[0], loop)
		}

		ctx.loop = ctx.loop.parent
	case ^ast.Call_Expr:
		args := make([]backend.Node_ID, 1 + len(d.args))

		name := meta.src_of(ctx.file^, d.expr)

		prc: ^Proc
		idx: u32
		for &p, i in ctx.procs {
			if p.name == name {
				prc = &p
				idx = u32(i)
			}
		}
		assert(prc != nil)

		for arg, i in d.args {
			args[1 + i] = emit_nodes(ctx, {}, arg)
		}
		args[0] = ctx_ctrl(ctx)

		call := backend.graph_add_call(ctx, "call", args, idx)
		call_end := backend.graph_add_callEnd(ctx, "calle", call)

		backend.graph_set_input(ctx, ctx.node_scope, 0, call_end)

		assert(len(prc.rets) == 1)

		return backend.graph_add_ret(ctx, "ret", .I64, call_end, 0)
	case ^ast.Branch_Stmt:
		label := meta.src_of(ctx.file^, d.label)

		loop := ctx.loop
		for ; loop != nil; loop = loop.parent {
			if loop.label == label || label == "" {
				break
			}
		}

		assert(loop != nil)

		backend.graph_truncate_scope(
			ctx,
			ctx.node_scope,
			backend.graph_get(ctx, loop.scope).ordered_input_count,
		)
		variant := Loop_Control(-1)
		#partial switch d.tok.kind {
		case .Break:
			variant = .Break
		case .Continue:
			variant = .Continue
		case:
			fmt.panicf("TODO: %#v", node.derived)
		}
		loop.scopes[variant] = backend.graph_merge_scopes(
			ctx,
			ctx.node_scope,
			loop.scopes[variant],
		)
		ctx.node_scope = 0
	case:
		fmt.panicf("TODO: %#v", node.derived)
	}

	return 0
}
