package main

import "core:fmt"
import "core:hash"
import "core:mem"
import "core:odin/ast"
import "bac"
import "typecheck"
import "utils/arna"
import os "platform"

compile_pixel_file :: proc(input, output: string) -> i32 {
    source, err := os.read_entire_file(input)
    if err != nil {fmt.eprintln("cannot read shader source", input); return 1}
    defer delete(source)
    types: typecheck.Types
    for &arena in mem.slice_data_cast([]arna.Allocator, mem.ptr_to_bytes(&types.mems)) do arena.reserved = 2*1024*1024
    types.mems.prc.reserved = 8*1024*1024
    types.mems.type.reserved = 16*1024*1024
    typecheck.types_init(&types)
    defer typecheck.types_deinit(&types)
    if types.mems.type.ptr == nil {fmt.eprintln("shader compiler allocation failed"); return 1}
    global: typecheck.Global_Ctx
    ctx: Gen_Ctx
    ctx.types = &types
    ctx.global = &global
    ctx.target = TARGETS[.Intel_Xelp]
    ctx.errors = os.to_writer(os.stderr)
    stats: bac.Stats
    ctx.stats = &stats
    previous := bac.current_prc
    bac.current_prc = &ctx
    defer bac.current_prc = previous
    if !load_embedded_source(&ctx, string(source), input) do return 1
    if len(ctx.files[0].decls) == 0 {fmt.eprintln("empty shader source", input); return 1}
    if !select_pixel_entry(&ctx) do return 1
    typecheck.typecheck_program(&ctx)
    if ctx.error_cnt != 0 do return 1
    if len(ctx.procs) != 2 || len(ctx.procs[1].params) < 2 || len(ctx.procs[1].params) > 8 || len(ctx.procs[1].rets) != 1 || ctx.procs[1].rets[0] != .F32 || ctx.shader_uniform_bytes != 0 {
        fmt.eprintln("framebuffer shader requires one main or tagged GPU procedure with 2..8 f32 parameters and one f32 result, without helper procedures or global uniforms")
        return 1
    }
    for param in ctx.procs[1].params {
        if param != .F32 {fmt.eprintln("framebuffer shader parameters must be f32"); return 1}
    }
    if !pixel_types_supported(&ctx) do return 1
    level := OPT_LEVELS[len(OPT_LEVELS)-2]
    ctx.ralloc_mode = level.ralloc_mode
    emit: bac.Codegen_Emit_Ctx
    emit_proc(&ctx, 1, level, &emit)
    code := ctx.procs[1].out.code
    if len(code) == 0 || len(code)%16 != 0 || len(code) > 24*1024 {fmt.eprintln("shader exceeds the native SIMD8 code envelope"); return 1}
    if ctx.error_cnt != 0 do return 1
    if trueos_cabi_blueprint_stop_control_v1(1) != 0 do return 1
    if os.write_entire_file(output, code) != nil {fmt.eprintln("cannot write shader code", output); return 1}
    fmt.printfln("odin-son: compiled Intel Xe-LP SIMD8 pixel backend=intel_xelp complete kernel source=%s bytes=%d fnv1a64=0x%016x output=%s", input, len(code), hash.fnv64a(code), output)
    return 0
}

select_pixel_entry :: proc(ctx: ^Gen_Ctx) -> bool {
    entries := make([dynamic]typecheck.Decl, ctx.types.allocator)
    defer delete(entries)
    typecheck.collect_decls(ctx.files[0], &entries, 0)
    selected := -1
    main_entry := -1
    for decl, i in entries {
        if decl.name == "main" do main_entry = i
        if decl.shader_tag != "gpu" do continue
        if selected != -1 {fmt.eprintln("shader requires exactly one tagged GPU procedure"); return false}
        selected = i
    }
    if selected == -1 {
        if main_entry == -1 {fmt.eprintln("shader requires main or one @(tag = \"gpu\") procedure"); return false}
        return true
    }
    lit, ok := entries[selected].value.derived.(^ast.Proc_Lit)
    if !ok || lit.body == nil {fmt.eprintln("GPU tag requires a procedure body"); return false}
    // Legacy sources include a CPU main; only the tagged entry belongs to the GPU module.
    ctx.modules[0].decl_idx = nil
    typecheck.module_add_decls(ctx, 0, entries[selected:selected+1])
    return true
}

pixel_types_supported :: proc(ctx: ^Gen_Ctx) -> bool {
    context.user_ptr = ctx
    ast.inspect(ctx.procs[1].lit.body, proc(node: ^ast.Node) -> bool {
        if node == nil do return false
        #partial switch derived in node.derived {
        case ^ast.Basic_Lit, ^ast.Binary_Expr, ^ast.Unary_Expr, ^ast.Paren_Expr, ^ast.Call_Expr, ^ast.Ternary_If_Expr:
            if len(node.end.file) != 0 do return true
            meta := typecheck.get_node_meta(node)
            if meta != nil && meta.type == .F64 {
                ctx := (^Gen_Ctx)(context.user_ptr)
                typecheck.error(ctx, node, "Xe-LP framebuffer arithmetic requires f32; use f32(...) or an explicit f32 local type")
                return false
            }
        }
        return true
    })
    return ctx.error_cnt == 0
}
