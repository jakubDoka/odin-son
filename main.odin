package main

import zydis "./zydis"
import "backend"
import "core:fmt"
import "core:io"
import "core:log"
import "core:odin/ast"
import "core:odin/parser"
import "core:strconv"
import "core:strings"
import "core:testing"
import "meta"
import "vendored/gam/util/arna"
import "vendored/gam/util/hot"

// A small hardcoded blob of x86-64 machine code to disassemble.
//
//   51                      push   rcx
//   8d 45 fa                lea    eax, [rbp-0x6]
//   48 8b 05 39 00 00 00    mov    rax, [rip+0x39]
//   e8 00 00 00 00          call   <rel32>
//   c3                      ret
INSTRUCTIONS := [?]u8 {
	0x51,
	0x8d,
	0x45,
	0xfa,
	0x48,
	0x8b,
	0x05,
	0x39,
	0x00,
	0x00,
	0x00,
	0xe8,
	0x00,
	0x00,
	0x00,
	0x00,
	0xc3,
}

main :: proc() {
	major := (zydis.GetVersion() >> 48) & 0xffff
	minor := (zydis.GetVersion() >> 32) & 0xffff
	fmt.printfln(
		"Zydis v%d.%d — disassembling %d bytes\n",
		major,
		minor,
		len(INSTRUCTIONS),
	)

	// Pretend the code lives here so RIP-relative operands resolve nicely.
	runtime_address: zydis.U64 = 0x0040_0000

	offset: int
	for offset < len(INSTRUCTIONS) {
		instr: zydis.DisassembledInstruction
		status := zydis.DisassembleIntel(
			.LONG_64,
			runtime_address + zydis.U64(offset),
			&INSTRUCTIONS[offset],
			zydis.USize(len(INSTRUCTIONS) - offset),
			&instr,
		)
		if !zydis.SUCCESS(status) {
			fmt.printfln(
				"0x%08x  <decode failed: %#x>",
				runtime_address + zydis.U64(offset),
				status,
			)
			break
		}

		// Raw bytes of just this instruction.
		length := int(instr.info.length)
		fmt.printf("0x%08x  ", instr.runtime_address)
		for b in INSTRUCTIONS[offset:offset + length] {
			fmt.printf("%02x ", b)
		}
		for _ in length ..< 12 {
			fmt.print("   ")
		}

		mnemonic := zydis.MnemonicGetString(instr.info.mnemonic)
		fmt.printfln(
			"%s    (%d operands, %s)",
			cstring(&instr.text[0]),
			instr.info.operand_count_visible,
			mnemonic,
		)

		offset += length
	}
}

fmts: map[typeid]fmt.User_Formatter

@(test)
build_simplest_function :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	fmt.set_user_formatters(&fmts)

	fmt.register_user_formatter(
		backend.Reg_Mask,
		proc(fi: ^fmt.Info, value: any, r: rune) -> bool {
			value := value.(backend.Reg_Mask)
			io.write_rune(fi.writer, backend.reg_kind_char(value.kind))
			for m in 0 ..< value.bit_length / backend.MASK_SIZE {
				fmt.wprintf(fi.writer, "%08x", value.masks[m])
			}
			return true
		},
	)

	context.assertion_failure_proc = hot.init_trace()

	source :: `
		package main

		main :: proc() -> int {
			return 69
		}
	`

	p := parser.Parser{}
	f := ast.File {
		src      = source,
		fullpath = "test",
	}
	ok := parser.parse_file(&p, &f); assert(ok)

	main: ^ast.Proc_Lit
	for decl in f.decls {
		sdecl := decl.derived_stmt.(^ast.Value_Decl) or_continue
		if meta.src_of(f, sdecl.names[0]) == "main" {
			main = sdecl.values[0].derived.(^ast.Proc_Lit)
		}
	}

	assert(main != nil)

	slots: [4096 * 4]u8

	graph: Ctx
	graph.node_spec = &backend.SPECS[.X64]
	graph.mem = arna.init_from_buffer(slots[:])
	graph.mem.pos += backend.PRECISION

	start := backend.graph_add_start(&graph)
	assert(start == backend.NODE_START)
	entry := backend.graph_add_entry(&graph, start)
	assert(entry == backend.NODE_ENTRY)

	graph.cfg = entry

	emit_nodes(&graph, main.body)

	schedule: backend.Graph_Schedule
	backend.graph_schedule(&graph, &schedule)

	reg_slots: [4096]u8

	ra: backend.Regalloc
	ra.spec = &backend.SPECS[.X64]
	ra.alloc = arna.init_from_buffer(reg_slots[:])

	regs := backend.regalloc(&ra, &graph, &schedule)

	sb: strings.Builder
	append(&sb.buf, "\n")
	backend.graph_display(&sb, &graph, &schedule, regs)

	log.info(string(sb.buf[:]))

}

Ctx :: struct {
	using graph: backend.Graph,
	cfg:         backend.Node_ID,
}

emit_nodes :: proc(ctx: ^Ctx, node: ^ast.Node) -> backend.Node_ID {
	#partial switch d in node.derived {
	case ^ast.Block_Stmt:
		for stmt in d.stmts {
			emit_nodes(ctx, stmt)
		}
	case ^ast.Return_Stmt:
		values := make([]backend.Node_ID, 1 + len(d.results))
		values[0] = ctx.cfg
		for r, i in d.results {
			values[1 + i] = emit_nodes(ctx, r)
		}
		ctx.cfg = 0

		ctx.end = backend.graph_add_return(ctx, values)
	case ^ast.Basic_Lit:
		#partial switch d.tok.kind {
		case .Integer:
			value, ok := strconv.parse_i64(d.tok.text)
			assert(ok)
			return backend.graph_add_cint(ctx, .I64, value)
		case:
			fmt.panicf("TODO: %#v", node.derived)
		}
	case:
		fmt.panicf("TODO: %#v", node.derived)
	}

	return 0
}
