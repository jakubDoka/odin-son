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
import "core:strconv"
import "core:strings"
import "core:sync"
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

disasm :: proc(sb: ^strings.Builder, ctx: Ctx) {
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
	ctx.file = &f

	for decl in f.decls {
		if sdecl, sok := decl.derived_stmt.(^ast.Value_Decl); sok {
			if prc, pok := sdecl.values[0].derived.(^ast.Proc_Lit); pok {
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

	Opt_Level :: enum int {
		None,
		Full,
	}

	levels := [Opt_Level]struct{}{}

	for &prc in ctx.procs {
		clear(&ctx.scope)

		for par in prc.params {
			append(&ctx.scope, Variable{name = par.name, type = par.type})
		}

		typecheck(&ctx, {}, prc.ast.body)
	}

	dsb: strings.Builder
	for _, level in levels {
		fmt.sbprintfln(&dsb, "=========== OPT LEVEL: %v ===========", level)
		code_mem.pos = 0
		reloc_mem.pos = 0

		for &prc, i in ctx.procs {
			ctx.prc = auto_cast i
			ctx.graph = {}
			ctx.node_spec = &backend.SPECS[.Builder]
			ctx.mem = &graph_mem
			ctx.mem.pos = backend.PRECISION

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

			for par, j in prc.params {
				value := backend.graph_add_arg(
					&ctx,
					"arg",
					type_to_dt(par.type),
					entry,
					u32(j),
				)
				idx := backend.graph_push_scope_value(
					&ctx,
					ctx.node_scope,
					value,
				)
				append(&ctx.scope, Variable{par.name, idx, par.type, nil, {}})
			}

			emit_nodes(&ctx, {}, prc.ast.body)

			if level == .Full {
				backend.graph_iter_peeps(&ctx)
			}

			//backend.redundancy_add(&waste_redc, 1, ctx.waste)

			//backend.redundancy_log(&waste_redc)

			spec := &backend.SPECS[.X64]
			ctx.node_spec = spec

			if level == .Full {
				backend.graph_iter_peeps(&ctx)
			}

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

		disasm(&dsb, ctx)

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
		//log.error()
		vl := ptr()
		if vl != exit_code {
			log.error(level)
			testing.expect_value(t, vl, exit_code)
		}

		oka = virtual.protect(code_mem.ptr, code_mem.commited, {.Read, .Write})
		assert(oka)
	}

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

Lit :: union {
	Proc_ID,
}

Proc_ID :: distinct int

Type :: enum uintptr {
	Void,
	Bool,
	Int,
	I64,
	I32,
	I16,
	I8,
	Uint,
	U64,
	U32,
	U16,
	U8,
}

@(rodata)
TYPE_SIZES := [Type]int {
	.Void = 0,
	.Bool = 1,
	.Int  = 8,
	.I64  = 8,
	.I32  = 4,
	.I16  = 2,
	.I8   = 1,
	.Uint = 8,
	.U64  = 8,
	.U32  = 4,
	.U16  = 2,
	.U8   = 1,
}

type_align :: proc(ty: Type) -> int {
	switch t in unpack_type(ty) {
	case Builtin:
		return TYPE_SIZES[ty]
	case Pointer:
		return 8
	case ^Struct:
		return t.align
	case ^Lit:
		panic("we should not be type type")
	case:
		panic("wuwut")
	}
}

type_size :: proc(ty: Type) -> int {
	switch t in unpack_type(ty) {
	case Builtin:
		return TYPE_SIZES[ty]
	case Pointer:
		return 8
	case ^Struct:
		return t.size
	case ^Lit:
		panic("we should not be type type")
	case:
		panic("wuwut")
	}
}

@(rodata)
TYPE_NAMES := [Type]string {
	.Void = "void",
	.Bool = "bool",
	.Int  = "int",
	.I64  = "i64",
	.I32  = "i32",
	.I16  = "i16",
	.I8   = "i8",
	.Uint = "uint",
	.U64  = "u64",
	.U32  = "u32",
	.U16  = "u16",
	.U8   = "u8",
}

type_to_dt :: proc(ty: Type) -> backend.Node_Datatype {
	@(static)
	@(rodata)
	TYPE_TO_DT := [Type]backend.Node_Datatype {
		.Void = .Void,
		.Bool = .I8,
		.Int  = .I64,
		.I64  = .I64,
		.I32  = .I32,
		.I16  = .I16,
		.I8   = .I8,
		.Uint = .I64,
		.U64  = .I64,
		.U32  = .I32,
		.U16  = .I16,
		.U8   = .I8,
	}

	switch t in unpack_type(ty) {
	case Builtin:
		return TYPE_TO_DT[ty]
	case Pointer:
		return .I64
	case ^Lit, ^Struct:
		return .Void
	case:
		panic("wuwut")
	}
}

UNSIGNED_TYPES :: bit_set[Type]{.Uint, .U64, .U32, .U16, .U8, .Bool}
SIGNED_TYPES :: bit_set[Type]{.Int, .I64, .I32, .I16, .I8}
INTEGER_TYPES :: UNSIGNED_TYPES | SIGNED_TYPES

Type_Kind :: enum uintptr {
	Builtin,
	Pointer,
	Struct,
	Lit,
}

Raw_Type :: bit_field uintptr {
	data: uintptr   | 48,
	tag:  Type_Kind | 16,
}

Pointer :: distinct ^Type
Builtin :: distinct Type

Type_Data :: union #no_nil {
	Builtin,
	Pointer,
	^Struct,
	^Lit,
}

Raw_Type_Data :: struct {
	data: uintptr,
	tag:  Type_Kind,
}

pack_type :: proc(typ: Type_Data) -> Type {
	raw := transmute(Raw_Type_Data)typ
	return Type(Raw_Type{tag = raw.tag, data = raw.data})
}

unpack_type :: proc(typ: Type) -> Type_Data {
	raw := Raw_Type(typ)
	return transmute(Type_Data)Raw_Type_Data{data = raw.data, tag = raw.tag}
}

intern_pointer :: proc(ctx: ^Ctx, ty: Type) -> Type {
	existing := ctx.pointers[ty] or_else Pointer(new_clone(ty))
	ctx.pointers[ty] = existing
	return pack_type(existing)
}

intern_lit :: proc(ctx: ^Ctx, lit: Lit) -> ^Lit {
	existing := ctx.lits[lit] or_else new_clone(lit)
	ctx.lits[lit] = existing
	return existing
}

emit_type :: proc(ctx: ^Ctx, expr: ^ast.Node) -> Type {
	if expr == nil do return .Void

	#partial switch d in expr.derived {
	case ^ast.Ident:
		for decl in ctx.file.decls {
			sdecl := decl.derived_stmt.(^ast.Value_Decl) or_continue
			if meta.src_of(ctx.file^, sdecl.names[0]) != d.name do continue

			#partial switch d in sdecl.values[0].derived {
			case ^ast.Struct_Type:
				key := Struct_Key{ctx.file_id, u32(decl.pos.offset)}
				structa, ok := ctx.structs[key]
				if ok do return pack_type(structa)

				structa = new(Struct)
				ctx.structs[key] = structa

				structa.fields = make([]Struct_Field, len(d.fields.list))
				for &field, i in structa.fields {
					ast_field := d.fields.list[i]
					assert(len(ast_field.names) == 1)
					field.name = ast_field.names[0].derived.(^ast.Ident).name
					field.ty = emit_type(ctx, ast_field.type)
					field.offset = mem.align_forward_int(
						structa.size,
						type_align(field.ty),
					)
					structa.size = field.offset + type_size(field.ty)
					structa.align = max(structa.align, type_align(field.ty))
				}
				structa.size = mem.align_forward_int(
					structa.size,
					structa.align,
				)
				return pack_type(structa)
			case:
				fmt.panicf("TODO: %#v", d)
			}
		}

		for name, kind in TYPE_NAMES {
			if name == d.name do return kind
		}

		fmt.panicf("TODO: %#v", expr.derived)
	case ^ast.Pointer_Type:
		return intern_pointer(ctx, emit_type(ctx, d.elem))
	case:
		fmt.panicf("TODO: %#v", expr.derived)
	}
}

Proc :: struct {
	name:      string,
	using sig: Signature,
	ast:       ^ast.Proc_Lit,
	out:       backend.Codegen_Output,
}

Signature :: struct {
	params: []Param,
	rets:   []Param,
}

Param :: struct {
	name: string,
	type: Type,
}

Variable :: struct {
	name:  string,
	idx:   union #no_nil {
		int,
		backend.Node_ID,
	},
	type:  Type,
	ident: ^ast.Expr,
	flags: Var_Flags,
}

Ctx :: struct {
	using graph: backend.Graph,
	procs:       [dynamic]Proc,
	scope:       [dynamic]Variable,
	pointers:    map[Type]Pointer,
	structs:     map[Struct_Key]^Struct,
	lits:        map[Lit]^Lit,
	node_scope:  backend.Node_ID,
	root_mem:    backend.Node_ID,
	mem_slot:    int,
	loop:        ^Loop_State,
	file:        ^ast.File,
	file_id:     File_ID,
	prc:         Proc_ID,
}

File_ID :: distinct u32

Struct_Key :: struct {
	file:   File_ID,
	offset: u32,
}

Struct :: struct {
	fields: []Struct_Field,
	size:   int,
	align:  int,
}

Struct_Field :: struct {
	name:   string,
	ty:     Type,
	offset: int,
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

Var_Flag :: enum uintptr {
	Referenced,
}

Var_Flags :: bit_set[Var_Flag;uintptr]

ctx_ctrl :: proc(ctx: ^Ctx) -> backend.Node_ID {
	return backend.graph_inps(ctx, ctx.node_scope)[0]
}

ctx_mem :: proc(ctx: ^Ctx) -> backend.Node_ID {
	return backend.graph_get_scope_value(ctx, ctx.node_scope, ctx.mem_slot)
}

ctx_set_mem :: proc(ctx: ^Ctx, mem: backend.Node_ID) {
	backend.graph_set_input(ctx, ctx.node_scope, ctx.mem_slot, mem)
}

get_node_type :: proc(node: ^ast.Node) -> Type {
	return get_node_data(node, Type)
}

get_node_vflags :: proc(node: ^ast.Node) -> Var_Flags {
	_ = node.derived.(^ast.Ident)
	return get_node_data(node, Var_Flags)
}

get_node_data :: proc(node: ^ast.Node, $T: typeid) -> T {
	return transmute(T)raw_data(node.end.file)
}

set_node_data :: proc(node: ^ast.Node, value: $T) {
	raw := (^runtime.Raw_Slice)(&node.end.file)
	raw.data = transmute(rawptr)value
	raw.len = 0
}

typecheck :: proc(
	ctx: ^Ctx,
	prop: Ty_Propagation,
	node: ^ast.Node,
) -> (
	ty: Type,
) {
	if node == nil do return .Void

	defer {
		set_node_data(node, ty)
	}

	#partial switch d in node.derived {
	case ^ast.Block_Stmt:
		prev_scope_len := len(ctx.scope)
		for stmt in d.stmts {
			typecheck(ctx, {}, stmt)
		}
		for var in ctx.scope[prev_scope_len:] {
			set_node_data(var.ident, var.flags)
		}
		resize(&ctx.scope, prev_scope_len)
	case ^ast.Value_Decl:
		assert(len(d.names) == len(d.values))

		inferred_ty := emit_type(ctx, d.type)

		for i in 0 ..< len(d.names) {
			name := meta.src_of(ctx.file^, d.names[i])
			value_ty := typecheck(
				ctx,
				{inferred_ty = inferred_ty},
				d.values[i],
			)
			if inferred_ty != .Void {
				assert(value_ty == inferred_ty)
			}
			set_node_data(d.names[i], Var_Flags{})
			append(
				&ctx.scope,
				Variable{name = name, type = value_ty, ident = d.names[i]},
			)
		}
	case ^ast.Basic_Lit:
		assert(d.tok.kind == .Integer)
		assert(prop.inferred_ty == .Void || prop.inferred_ty in INTEGER_TYPES)

		return prop.inferred_ty != .Void ? prop.inferred_ty : .Int
	case ^ast.Comp_Lit:
		inferred_ty := emit_type(ctx, d.type)
		if inferred_ty == .Void do inferred_ty = prop.inferred_ty

		#partial switch t in unpack_type(inferred_ty) {
		case ^Struct:
			for elem, i in d.elems {
				#partial switch e in elem.derived {
				case ^ast.Field_Value:
					name := meta.src_of(ctx.file^, e.field)
					for &field in t.fields {
						if field.name == name {
							set_node_data(e.field, field.offset)
							fty := typecheck(
								ctx,
								{inferred_ty = field.ty},
								e.value,
							)
							assert(fty == field.ty)
						}
					}
				case:
					field := t.fields[i]
					fty := typecheck(ctx, {inferred_ty = field.ty}, elem)
					assert(fty == field.ty)
				}
			}

			return inferred_ty
		case:
			fmt.panicf("TODO: %#v", d)
		}
	case ^ast.Selector_Expr:
		base := typecheck(ctx, {}, d.expr)

		#partial switch f in d.field.derived {
		case ^ast.Ident:
			if p, ok := unpack_type(base).(Pointer); ok do base = p^

			#partial switch t in unpack_type(base) {
			case ^Struct:
				for &field in t.fields {
					if field.name == f.name {
						set_node_data(d.field, field.offset)
						return field.ty
					}
				}
			case:
				fmt.panicf("TODO: %#v", t)
			}
		case:
			fmt.panicf("TODO: %#v", d.field.derived)
		}
	case ^ast.Binary_Expr:
		lhs_ty := typecheck(ctx, prop, d.left)
		inferred_ty := lhs_ty
		if d.op.kind == .Shl || d.op.kind == .Shr {
			inferred_ty = .Uint
		}
		rhs_ty := typecheck(ctx, {inferred_ty = inferred_ty}, d.right)
		assert(inferred_ty == rhs_ty)

		if .B_Comparison_Begin < d.op.kind && d.op.kind < .B_Comparison_End {
			return .Bool
		}

		return lhs_ty
	case ^ast.Unary_Expr:
		#partial switch d.op.kind {
		case .And:
			inferred_ty := Type.Void
			if ptr, ok := unpack_type(prop.inferred_ty).(Pointer); ok {
				inferred_ty = ptr^
			}

			inner_ty := typecheck(
				ctx,
				{inferred_ty = inferred_ty, referencing = true},
				d.expr,
			)
			if inferred_ty != .Void {
				assert(inferred_ty == inner_ty)
			}
			return intern_pointer(ctx, inner_ty)
		case:
			fmt.panicf("TODO: %#v", node.derived)
		}
	case ^ast.Deref_Expr:
		inferred_ty := Type.Void
		if prop.inferred_ty != .Void {
			inferred_ty = intern_pointer(ctx, prop.inferred_ty)
		}

		ty = typecheck(ctx, {inferred_ty = inferred_ty}, d.expr)
		return unpack_type(ty).(Pointer)^
	case ^ast.Expr_Stmt:
		return typecheck(ctx, {}, d.expr)
	case ^ast.If_Stmt:
		cond_ty := typecheck(ctx, {}, d.cond)
		assert(cond_ty == .Bool)
		typecheck(ctx, {}, d.body)
		typecheck(ctx, {}, d.else_stmt)
		return {}
	case ^ast.For_Stmt:
		assert(d.init == nil)
		assert(d.cond == nil)
		assert(d.post == nil)

		typecheck(ctx, {}, d.body)
	case ^ast.Branch_Stmt:
		return {}
	case ^ast.Paren_Expr:
		return typecheck(ctx, prop, d.expr)
	case ^ast.Ident:
		name := d.name
		#reverse for &var in ctx.scope {
			if var.name == name {
				if prop.referencing {
					var.flags |= {.Referenced}
				}
				return var.type
			}
		}

		for p, i in ctx.procs {
			if p.name == name {
				return pack_type(intern_lit(ctx, Proc_ID(i)))
			}
		}

		if name == "false" || name == "true" {
			return .Bool
		}

		return emit_type(ctx, node)
	case ^ast.Call_Expr:
		callee := typecheck(ctx, {}, d.expr)

		sig: Signature
		#partial switch v in unpack_type(callee) {
		case ^Lit:
			prc_id := v.(Proc_ID)
			prc := &ctx.procs[prc_id]
			sig = prc.sig
		case Builtin:
			assert(v != .Void)
			assert(len(d.args) == 1)
			typecheck(ctx, {}, d.args[0])
			return callee
		case:
			fmt.panicf("TODO: %v %#v", v, d)
		}

		assert(len(sig.params) == len(d.args))
		for param, i in sig.params {
			pty := typecheck(ctx, {inferred_ty = param.type}, d.args[i])
			assert(pty == param.type)
		}

		assert(len(sig.rets) == 1)
		return sig.rets[0].type
	case ^ast.Return_Stmt:
		prc := &ctx.procs[ctx.prc]
		assert(len(d.results) == len(prc.rets))
		for i in 0 ..< len(d.results) {
			typecheck(ctx, {inferred_ty = prc.rets[i].type}, d.results[i])
		}
	case ^ast.Assign_Stmt:
		assert(len(d.lhs) == len(d.rhs))
		for i in 0 ..< len(d.lhs) {
			lhs_ty := typecheck(ctx, {}, d.lhs[i])
			typecheck(ctx, {inferred_ty = lhs_ty}, d.rhs[i])
		}
	case:
		fmt.panicf("TODO: %#v", node.derived)
	}

	return .Void
}

Value :: bit_field u32 {
	id:        backend.Node_ID | 31,
	is_lvalue: bool            | 1,
}

is_of :: proc(vl: Type, $K: typeid) -> bool {
	_, ok := unpack_type(vl).(K)
	return ok
}

to_rvalue_ty :: proc(ctx: ^Ctx, value: Value, ty: Type) -> backend.Node_ID {
	if !value.is_lvalue do return value.id
	dt := type_to_dt(ty)
	assert(dt != .Void)
	// signed sub-word values must be sign extended on load since we always
	// do arithmetic in the biggest register size
	if is_signed_subword(ty) {
		return backend.graph_add_load_s(
			ctx,
			"ltr",
			dt,
			ctx_ctrl(ctx),
			ctx_mem(ctx),
			value.id,
		)
	}
	return backend.graph_add_load(
		ctx,
		"ltr",
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
	ctx: ^Ctx,
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

ctx_lookup_lvalue :: proc(ctx: ^Ctx, expr: ^ast.Node) -> Sym {
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
	ctx: ^Ctx,
	name: string,
	ptr: backend.Node_ID,
	value: Value,
	node: ^ast.Node,
) {
	store_value(ctx, name, ptr, value, get_node_type(node))
}

store_value_ty :: proc(
	ctx: ^Ctx,
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
	ctx: ^Ctx,
	name: string,
	ty: Type,
	zeroed := true,
) -> backend.Node_ID {
	alloca := backend.graph_add_local(ctx, name, ctx.root_mem)
	size := u32(type_size(ty))
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
	ctx: ^Ctx,
	base: backend.Node_ID,
	offset: int,
) -> backend.Node_ID {
	off := backend.graph_add_c_int(ctx, "foff", .I64, i64(offset))
	return backend.graph_add_bin_op(ctx, "fld", .Add, .I64, base, off)
}

emit_nodes :: proc(ctx: ^Ctx, prop: Propagation, node: ^ast.Node) -> Value {
	if node == nil do return {}

	ty := get_node_type(node)
	dt := type_to_dt(ty)

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
				backend.graph_remove_output(ctx, n, {})
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
		for i in 0 ..< len(d.lhs) {
			lhs := d.lhs[i]
			rhs := d.rhs[i]
			sym := ctx_lookup_lvalue(ctx, lhs)
			switch sym in sym {
			case int:
				value := emit_nodes(ctx, {}, rhs)
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
						to_rvalue(ctx, value, ty),
					)
				} else {
					assert(!value.is_lvalue)
				}

				backend.graph_set_input(ctx, ctx.node_scope, sym, value.id)
			case Value:
				assert(d.op.kind == .Eq)
				dest := emit_nodes(ctx, {}, lhs)
				assert(dest.is_lvalue)
				value := emit_nodes(ctx, {dest = dest.id}, rhs)
				store_value(ctx, "asss", dest.id, value, lhs)
			}
		}
	case ^ast.Binary_Expr:
		lhsv, rhsv := emit_nodes(ctx, {}, d.left), emit_nodes(ctx, {}, d.right)
		lhs, rhs := to_rvalue(ctx, lhsv, d.left), to_rvalue(ctx, rhsv, d.right)
		kind, name := tok_to_binop(get_node_type(d.left), d.op.kind)
		nd := backend.graph_add_bin_op(ctx, name, kind, dt, lhs, rhs)
		return auto_cast nd
	case ^ast.Unary_Expr:
		node := emit_nodes(ctx, {}, d.expr)
		assert(node.is_lvalue)
		return auto_cast node.id
	case ^ast.Deref_Expr:
		node := to_rvalue(ctx, emit_nodes(ctx, {}, d.expr), d.expr)
		return {id = node, is_lvalue = true}
	case ^ast.Return_Stmt:
		values := make([]backend.Node_ID, 2 + len(d.results))
		for r, i in d.results {
			values[2 + i] = to_rvalue(ctx, emit_nodes(ctx, {}, r), r)
		}
		values[0] = ctx_ctrl(ctx)
		values[1] = ctx_mem(ctx)
		backend.graph_merge_returns(ctx, values)
		backend.graph_delete(ctx, ctx.node_scope)
		ctx.node_scope = 0
	case ^ast.Basic_Lit:
		#partial switch d.tok.kind {
		case .Integer:
			value, ok := strconv.parse_i64(d.tok.text)
			assert(ok)
			return auto_cast backend.graph_add_c_int(ctx, "cnst", dt, value)
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
				backend.graph_add_output(ctx, ptr, 0, 0)

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

			return {id = dest, is_lvalue = true}
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
				return {id = field_ptr, is_lvalue = true}
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
			val := backend.graph_get_scope_value(ctx, ctx.node_scope, sym)
			assert(backend.graph_get(ctx, val).btype != .Scope)
			return Value(val)
		case Value:
			return sym
		}
	case ^ast.Paren_Expr:
		return emit_nodes(ctx, prop, d.expr)
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
		args := make([]backend.Node_ID, 2 + len(d.args))

		base_ty := get_node_type(d.expr)

		idx: u32
		#partial switch t in unpack_type(base_ty) {
		case ^Lit:
			idx = u32(t.(Proc_ID))
		case Builtin:
			dest_dt := type_to_dt(base_ty)
			arg := to_rvalue(ctx, emit_nodes(ctx, {}, d.args[0]), d.args[0])
			return auto_cast arg
		case:
			fmt.panicf("TODO: %v %v", t, node)
		}

		prc := &ctx.procs[idx]

		for arg, i in d.args {
			args[2 + i] = to_rvalue(ctx, emit_nodes(ctx, {}, arg), arg)
		}
		args[0] = ctx_ctrl(ctx)
		args[1] = ctx_mem(ctx)

		call := backend.graph_add_call(ctx, "call", args, idx)
		call_end := backend.graph_add_call_end(ctx, "calle", call)

		backend.graph_set_input(ctx, ctx.node_scope, 0, call_end)
		ctx_set_mem(ctx, backend.graph_add_mem(ctx, "cmem", call_end))

		assert(len(prc.rets) == 1)
		dt = type_to_dt(prc.rets[0].type)
		return auto_cast backend.graph_add_ret(ctx, "cret", dt, call_end, 0)
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

	return {}
}
