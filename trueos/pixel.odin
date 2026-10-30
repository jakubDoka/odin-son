package main

import "core:fmt"
import "core:hash"
import "core:mem"
import "bac"
import poc "bac/intel_xelp"
import "typecheck"
import "utils/arna"
import os "platform"

compile_pixel_file :: proc(input, output: string, complete_kernel := false) -> i32 {
    source, err := os.read_entire_file(input)
    if err != nil {fmt.eprintln("cannot read pixel source", input); return 1}
    defer delete(source)
    arna.scratch[0].reserved = 4*1024*1024
    arna.scratch[1].reserved = 4*1024*1024
    types: typecheck.Types
    for &arena in mem.slice_data_cast([]arna.Allocator, mem.ptr_to_bytes(&types.mems)) do arena.reserved = 2*1024*1024
    types.mems.prc.reserved = 8*1024*1024
    types.mems.type.reserved = 16*1024*1024
    typecheck.types_init(&types)
    defer typecheck.types_deinit(&types)
    if types.mems.type.ptr == nil {fmt.eprintln("pixel compiler allocation failed"); return 1}
    global: typecheck.Global_Ctx
    ctx: Gen_Ctx
    ctx.types = &types
    ctx.global = &global
    ctx.target = TARGETS[.AMD64]
    ctx.errors = os.to_writer(os.stderr)
    stats: bac.Stats
    ctx.stats = &stats
    previous := bac.current_prc
    bac.current_prc = &ctx
    defer bac.current_prc = previous
    if !load_embedded_source(&ctx, string(source), input) do return 1
    if len(ctx.files[0].decls) == 0 {fmt.eprintln("empty pixel source", input); return 1}
    code: []u8
    if complete_kernel {
        typecheck.typecheck_program(&ctx)
        if ctx.error_cnt != 0 do return 1
        if len(ctx.procs) != 2 || ctx.procs[1].name != "main" || len(ctx.procs[1].params) < 2 || len(ctx.procs[1].params) > 8 || len(ctx.procs[1].rets) != 1 || ctx.procs[1].rets[0] != .F32 {
            fmt.eprintln("POC visual kernel requires one main with 2..8 f32 parameters and one f32 result, without helper procedures")
            return 1
        }
        for param in ctx.procs[1].params {
            if param != .F32 {fmt.eprintln("POC visual kernel parameters must be f32"); return 1}
        }
        ctx.target = {name = "intel_xelp_poc", cc = &poc.CC_TABLE[poc.XELP_CC], spec = &poc.SPEC}
        level := OPT_LEVELS[len(OPT_LEVELS)-2]
        ctx.ralloc_mode = level.ralloc_mode
        emit: bac.Codegen_Emit_Ctx
        emit_proc(&ctx, 1, level, &emit)
        code = ctx.procs[1].out.code
        if len(code) == 0 || len(code)%16 != 0 || len(code) > 24*1024 {fmt.eprintln("POC kernel exceeds the native SIMD8 code envelope"); return 1}
    } else {
        code = typecheck.emit_gpu_pixel(&ctx)
    }
    defer {
        if !complete_kernel do delete(code)
    }
    if ctx.error_cnt != 0 || len(code) == 0 do return 1
    if trueos_cabi_blueprint_stop_control_v1(1) != 0 do return 1
    if os.write_entire_file(output, code) != nil {fmt.eprintln("cannot write pixel code", output); return 1}
    backend := complete_kernel ? "intel_xelp_poc complete kernel" : "intel_xelp_pixel body"
    fmt.printfln("odin-son: compiled Intel Xe-LP SIMD8 pixel backend=%s source=%s bytes=%d fnv1a64=0x%016x output=%s", backend, input, len(code), hash.fnv64a(code), output)
    return 0
}
