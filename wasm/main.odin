package wasm

import piler ".."
import "../backend"
import "../vendored/gam/util/arna"

@(export)
compile :: proc(opts: backend.Graph_Opt_Flags) -> []u8 {
	arna.scratch[0].reserved = 64 * 1024 * 1024
	arna.scratch[1].reserved = 64 * 1024 * 1024

	types: piler.Types
	types.mems.graph.reserved = 4096 * 16384
	types.mems.regalloc.reserved = 4096 * 8192
	types.mems.scratch.reserved = 4096 * 2048
	types.mems.code.reserved = 4096 * 4096
	types.mems.reloc.reserved = 4096 * 2048
	types.mems.type.reserved = 4096 * 8192

	piler.types_init(&types)
	defer piler.types_deinit(&types)

	global_ctx: piler.Global_Ctx

	ctx: piler.Gen_Ctx
	ctx.types = &types
	ctx.global = &global_ctx
	ctx.cc = &backend.X64_SYSTEMV_CC
	ctx.target_spec = &backend.SPECS[.X64]

	piler.typecheck_program(&ctx)

	emit_ctx := backend.Codegen_Emit_Ctx {
		lib_calls = {
			copy = {id = piler.MEMCPY_ID},
			set = {id = piler.MEMSET_ID},
		},
	}

	clear(&ctx.globals)
	piler.emit_module_globals(&ctx)

	level := piler.Opt_Level {
		flags = opts,
	}

	for prc, i in ctx.procs {
		if len(prc.poly_names) != len(prc.poly_values) do continue
		piler.emit_proc(&ctx, i, level, &emit_ctx)
	}

	if .Inline in level.flags {
		piler.inline_and_optimize(&ctx, &emit_ctx)
	}

	elf := piler.emit_elf(&ctx)

	return elf
}
