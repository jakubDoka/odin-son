package wasm

import jit ".."
import "../backend"
import "../backend/x64"
import "../typecheck"
import "../vendored/gam/util/arna"
import "base:runtime"
import "core:odin/ast"
import "core:odin/parser"
import "core:strings"

SOURCE_CAPACITY :: 1024 * 1024
OUTPUT_CAPACITY :: 16 * 1024 * 1024

@(export)
source_buffer: [SOURCE_CAPACITY]u8

@(export)
output_buffer: [OUTPUT_CAPACITY]u8

Status :: enum i32 {
	Success,
	Not_Initialized,
	Source_Too_Large,
	Parse_Error,
	Type_Error,
	Out_Of_Memory,
}

Compiler_State :: struct {
	types:       typecheck.Types,
	global:      typecheck.Global_Ctx,
	ctx:         jit.Gen_Ctx,
	source_size: int,
	output_size: int,
	initialized: bool,
}

@(private)
state: Compiler_State

init_arenas :: proc() {
	arna.scratch[0].reserved = 8 * 1024 * 1024
	arna.scratch[1].reserved = 8 * 1024 * 1024

	state.types.mems.graph.reserved = 8 * 1024 * 1024
	state.types.mems.regalloc.reserved = 4 * 1024 * 1024
	state.types.mems.scratch.reserved = 2 * 1024 * 1024
	state.types.mems.code.reserved = 4 * 1024 * 1024
	state.types.mems.reloc.reserved = 2 * 1024 * 1024
	state.types.mems.sloc.reserved = 4 * 1024 * 1024
	state.types.mems.cfi.reserved = 2 * 1024 * 1024
	state.types.mems.type.reserved = 32 * 1024 * 1024

	typecheck.types_init(&state.types)
}

reset_arenas :: proc() {
	arna.reset(&arna.scratch[0], false)
	arna.reset(&arna.scratch[1], false)
	typecheck.types_reset(&state.types)
}

@(export)
compiler_init :: proc "c" (source_size: u32) -> Status {
	context = runtime.default_context()
	context.temp_allocator = context.allocator

	if source_size > SOURCE_CAPACITY {
		return .Source_Too_Large
	}

	if !state.initialized {
		runtime._startup_runtime()
		init_arenas()
		if state.types.mems.type.ptr == nil {
			return .Out_Of_Memory
		}

		allocator := context.allocator
		backend.init_custom_fmt()
		typecheck.init_type_fmt()
		context.allocator = allocator
		state.initialized = true
	} else {
		reset_arenas()
	}

	state.global = {}
	state.ctx = {}
	state.source_size = int(source_size)
	state.output_size = 0
	return .Success
}

init_single_file_program :: proc(ctx: ^jit.Gen_Ctx, file: ^ast.File) {
	ctx.files.allocator = ctx.types.allocator
	ctx.modules.allocator = ctx.types.allocator
	if file.pkg_name == "" do file.pkg_name = "main"
	append(&ctx.files, file^)
	append(
		&ctx.modules,
		typecheck.Module{name = file.pkg_name, file_count = 1},
	)
	ctx.modules[0].imports.allocator = ctx.types.allocator
	ctx.modules[0].imports["intrinsics"] = typecheck.MODULE_INTRINSICS

	decls := make([dynamic]typecheck.Decl, ctx.types.allocator)
	typecheck.collect_decls(file^, &decls, 0)
	typecheck.module_add_decls(ctx, 0, decls[:])
}

set_output :: proc(bytes: []u8) {
	state.output_size = min(len(bytes), OUTPUT_CAPACITY)
	copy(output_buffer[:state.output_size], bytes[:state.output_size])
}

@(export)
compiler_compile :: proc "c" () -> Status {
	context = runtime.default_context()
	context.temp_allocator = context.allocator
	if !state.initialized {
		return .Not_Initialized
	}

	context.allocator = state.types.allocator
	context.temp_allocator = state.types.allocator
	state.output_size = 0

	file := ast.File {
		src      = string(source_buffer[:state.source_size]),
		fullpath = "input.odin",
	}
	parse := parser.Parser{}
	if !parser.parse_file(&parse, &file) {
		return .Parse_Error
	}

	diagnostics: strings.Builder
	diagnostics.buf.allocator = state.types.allocator

	state.ctx.types = &state.types
	state.ctx.global = &state.global
	state.ctx.target.cc = &x64.X64_SYSTEMV_CC
	state.ctx.target.spec = &x64.SPEC
	state.ctx.errors = strings.to_writer(&diagnostics)

	init_single_file_program(&state.ctx, &file)
	typecheck.typecheck_program(&state.ctx)
	if state.ctx.error_cnt > 0 {
		set_output(diagnostics.buf[:])
		return .Type_Error
	}

	emit_ctx := backend.Codegen_Emit_Ctx {
		lib_calls = {copy = {id = jit.MEMCPY_ID}, set = {id = jit.MEMSET_ID}},
	}
	level := jit.OPT_LEVELS[len(jit.OPT_LEVELS) - 1]
	for _, i in state.ctx.procs {
		jit.emit_proc(&state.ctx, i, level, &emit_ctx)
	}
	if .Inline in level.flags {
		jit.inline_and_optimize(&state.ctx, &emit_ctx)
	}

	output_arena := arna.init_from_buffer(output_buffer[:])
	output := jit.emit_elf(&state.ctx, arna.allocator(&output_arena))
	state.output_size = len(output)
	return .Success
}

@(export)
compiler_output_size :: proc "c" () -> u32 {
	return u32(state.output_size)
}
