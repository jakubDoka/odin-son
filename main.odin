package main

import zydis "./zydis"
import "backend"
import "core:fmt"
import "core:io"
import "core:log"
import "core:mem/virtual"
import "core:odin/ast"
import "core:odin/parser"
import "core:strconv"
import "core:strings"
import "core:sync"
import "core:testing"
import "meta"
import "vendored/gam/util/arna"
import "vendored/gam/util/hot"

disasm :: proc(sb: ^strings.Builder, instructions: []u8) {
	runtime_address: zydis.U64 = 0x0040_0000

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
			fmt.sbprintfln(
				sb,
				"0x%08x  <decode failed: %#x>",
				runtime_address + zydis.U64(offset),
				status,
			)
			break
		}

		// Raw bytes of just this instruction.
		length := int(instr.info.length)
		fmt.sbprintf(sb, "0x%08x  ", instr.runtime_address)
		for b in instructions[offset:offset + length] {
			fmt.sbprintf(sb, "%02x ", b)
		}
		for _ in length ..< 12 {
			fmt.sbprint(sb, "   ")
		}

		mnemonic := zydis.MnemonicGetString(instr.info.mnemonic)
		fmt.sbprintfln(sb, "%s", cstring(&instr.text[0]))

		offset += length
	}
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

run_test :: proc(t: ^testing.T, source: string) {
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

	spec := &backend.SPECS[.X64]

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
	graph.node_spec = spec
	graph.mem = &graph_mem
	graph.mem.pos += backend.PRECISION
	graph.file = &f

	current_graph = &graph

	start := backend.graph_add_start(&graph, "start")
	assert(start == backend.NODE_START)
	entry := backend.graph_add_entry(&graph, "entry", start)
	assert(entry == backend.NODE_ENTRY)

	graph.cfg = entry

	emit_nodes(&graph, {}, main.body)

	schedule: backend.Graph_Schedule
	backend.graph_schedule(&graph, &schedule)

	ra: backend.Regalloc
	ra.spec = spec
	ra.alloc = &regalloc_mem

	regs := backend.regalloc(&ra, &graph, &schedule)

	sb: strings.Builder
	append(&sb.buf, "\n")
	backend.graph_display(&sb, &graph, &schedule, regs)
	log.info(string(sb.buf[:]))

	ctx := backend.Codegen_Emit_Ctx {
		graph = &graph,
		schedule = &schedule,
		buf = {scratch = &scratch_mem, code = &code_mem},
		allocs = regs,
	}
	output := spec.emit_function(ctx)

	clear(&sb.buf)
	append(&sb.buf, "\n")
	disasm(&sb, output.code)
	log.info(string(sb.buf[:]))

	oka := virtual.protect(raw_data(output.code), 4096, {.Read, .Execute})
	assert(oka)

	ptr := transmute(proc() -> int)(raw_data(output.code))
	testing.expect_value(t, ptr(), expected_return)
}

Variable :: struct {
	name:  string,
	value: backend.Node_ID,
}

Ctx :: struct {
	using graph: backend.Graph,
	cfg:         backend.Node_ID,
	scope:       [dynamic]Variable,
	file:        ^ast.File,
}

Propagation :: struct {}

emit_nodes :: proc(
	ctx: ^Ctx,
	prop: Propagation,
	node: ^ast.Node,
) -> backend.Node_ID {
	#partial switch d in node.derived {
	case ^ast.Block_Stmt:
		for stmt in d.stmts {
			emit_nodes(ctx, {}, stmt)
		}
	case ^ast.Binary_Expr:
		lhs, rhs := emit_nodes(ctx, {}, d.left), emit_nodes(ctx, {}, d.right)
		#partial switch d.op.kind {
		case .Add:
			return backend.graph_add_add(ctx, "add", .I64, lhs, rhs)
		case .Mul:
			return backend.graph_add_mul(ctx, "mul", .I64, lhs, rhs)
		case:
			fmt.panicf("TODO: %#v", node.derived)
		}
	case ^ast.Return_Stmt:
		values := make([]backend.Node_ID, 1 + len(d.results))
		values[0] = ctx.cfg
		for r, i in d.results {
			values[1 + i] = emit_nodes(ctx, {}, r)
		}
		ctx.cfg = 0

		ctx.end = backend.graph_add_return(ctx, "ret", values)
	case ^ast.Basic_Lit:
		#partial switch d.tok.kind {
		case .Integer:
			value, ok := strconv.parse_i64(d.tok.text)
			assert(ok)
			return backend.graph_add_cint(ctx, "const", .I64, value)
		case:
			fmt.panicf("TODO: %#v", node.derived)
		}
	case ^ast.Value_Decl:
		assert(len(d.names) == len(d.values))
		for i in 0 ..< len(d.names) {
			name := meta.src_of(ctx.file^, d.names[i])
			value := emit_nodes(ctx, {}, d.values[i])

			backend.graph_set_name(ctx, value, name)
			append(&ctx.scope, Variable{name, value})
		}
	case ^ast.Ident:
		name := meta.src_of(ctx.file^, node)

		for var in ctx.scope {
			if var.name == name {
				return var.value
			}
		}

		panic("TODO: undefined variable")
	case ^ast.Paren_Expr:
		return emit_nodes(ctx, prop, d.expr)
	case:
		fmt.panicf("TODO: %#v", node.derived)
	}

	return 0
}
