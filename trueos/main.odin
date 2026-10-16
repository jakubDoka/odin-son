package main
import "base:runtime"
import "core:fmt"
import "core:mem"
import "core:strings"
import "bac"
import "typecheck"
import "vendored/gam/util/arna"
import os "platform"
foreign _ {
    trueos_cabi_blueprint_stop_control_v1 :: proc "c" (op: u32) -> i32 ---
    trueos_cabi_blueprint_shutdown :: proc "c" (data: rawptr, size: uintptr) -> i32 ---
}

@(export, link_name="trueos_main")
trueos_main :: proc "c" (argc: uintptr, argv: [^]cstring) -> i32 {
    context = runtime.default_context()
    context.allocator = runtime.heap_allocator()
    context.temp_allocator = context.allocator
    runtime._startup_runtime()
    if trueos_cabi_blueprint_stop_control_v1(0) != 0 do return 1
    defer {
        reason := "odin-son finished"
        trueos_cabi_blueprint_shutdown(raw_data(reason), uintptr(len(reason)))
    }
    return run_compiler(argc, argv)
}
run_compiler :: proc(argc: uintptr, argv: [^]cstring) -> i32 {
    fmt.printfln("odin-son: argc=%d", argc)
    for i in 0..<argc { fmt.printfln("odin-son: argv[%d]=%q", i, string(argv[i])) }
    input := ""
    output := "a.o"
    root := "."
    level := OPT_LEVELS[len(OPT_LEVELS)-1]
    target := TARGETS[0]
    check := false
    debug := false
    output_explicit := false
    for i := uintptr(1); i < argc; i += 1 {
        arg := string(argv[i])
        switch {
        case arg == "-o", arg == "--odin-root":
            i += 1
            if i >= argc { fmt.eprintln("missing flag value"); return 1 }
            if arg == "-o" { output = string(argv[i]); output_explicit = true } else { root = string(argv[i]) }
        case arg == "--help", arg == "-h":
            fmt.println("usage: odin-son [entry.odin] [-o output.o] [--odin-root odin] [-target:amd64|arm64|wasm64] [-o:level] [-debug] [-check]")
            fmt.println("No source argument compiles embedded TRUEOS boids and stores boids.o and boids.bp in the app filesystem root (normally apps/odin-son).")
            return 0
        case arg == "-check": check = true
        case arg == "-debug", arg == "-g": debug = true
        case strings.has_prefix(arg, "-target:"):
            name := arg[len("-target:"):]
            found := false
            for t in TARGETS { if t.name == name { target = t; found = true; break } }
            if !found { fmt.eprintln("unknown target:", name); return 1 }
        case strings.has_prefix(arg, "-o:"):
            name := arg[len("-o:"):]
            found := false
            for l in OPT_LEVELS { if l.name == name { level = l; found = true; break } }
            if !found { fmt.eprintln("unknown optimization level:", name); return 1 }
        case strings.has_prefix(arg, "-"):
            fmt.eprintln("unknown flag:", arg); return 1
        case:
            if input != "" { fmt.eprintln("multiple inputs"); return 1 }
            input = arg
        }
    }
    embedded := input == ""
    if embedded {
        if target.name != "amd64" { fmt.eprintln("embedded TRUEOS boids requires -target:amd64"); return 1 }
        if !output_explicit do output = "boids.o"
        fmt.printfln("odin-son: compiling embedded TRUEOS boids (%d source bytes)", len(EMBEDDED_BOIDS))
        fmt.println("odin-son: relative output paths use this app's filesystem root (normally apps/odin-son)")
    } else {
        fmt.printfln("odin-son: loading source %s", input)
    }
    arna.scratch[0].reserved = #config(TRUEOS_COMPILER_SCRATCH_MIB, 4)*1024*1024
    arna.scratch[1].reserved = #config(TRUEOS_COMPILER_SCRATCH_MIB, 4)*1024*1024
    types: typecheck.Types
    for &arena in mem.slice_data_cast([]arna.Allocator, mem.ptr_to_bytes(&types.mems)) { arena.reserved = #config(TRUEOS_COMPILER_ARENA_MIB, 2)*1024*1024 }
    types.mems.graph.reserved = #config(TRUEOS_COMPILER_GRAPH_MIB, 8)*1024*1024
    types.mems.type.reserved = #config(TRUEOS_COMPILER_TYPES_MIB, 16)*1024*1024
    typecheck.types_init(&types)
    if types.mems.type.ptr == nil { fmt.eprintln("compiler arena allocation failed"); return 1 }
    defer typecheck.types_deinit(&types)
    bac.init_custom_fmt()
    typecheck.init_type_fmt()
    global: typecheck.Global_Ctx
    global.root = root
    for col in ([]string{"base", "core", "vendor"}) {
        global.collections[col], _ = os.join_path({root, col}, context.temp_allocator)
    }
    ctx: Gen_Ctx
    ctx.types = &types
    ctx.global = &global
    ctx.target = target
    ctx.check = check
    ctx.errors = os.to_writer(os.stderr)
    ctx.graph.has_dbg = debug
    ctx.ralloc_mode = level.ralloc_mode
    if embedded {
        if !load_embedded_boids(&ctx) { fmt.eprintln("embedded boids parse failed"); return 1 }
    } else { load_program(&ctx, input) }
    fmt.printfln("odin-son: source collections root=%s (default: app root apps/odin-son)", root)
    fmt.println("odin-son: type checking")
    typecheck.typecheck_program(&ctx)
    if ctx.error_cnt > 0 do return 1
    if trueos_cabi_blueprint_stop_control_v1(1) != 0 do return 1
    fmt.printfln("odin-son: generating %s code (%s)", target.name, level.name)
    emit_ctx := bac.Codegen_Emit_Ctx{lib_calls={copy={id=MEMCPY_ID}, set={id=MEMSET_ID}}}
    for _, i in ctx.procs { emit_proc(&ctx, i, level, &emit_ctx) }
    if .Inline in level.flags { inline_and_optimize(&ctx, &emit_ctx) }
    if check { fmt.println("analysis completed"); return 0 }
    bytes := target.emit(&ctx)
    fmt.printfln("odin-son: compilation complete (%d ELF/module bytes); storing %s", len(bytes), output)
    if os.write_entire_file(output, bytes) != nil { fmt.eprintln("cannot write", output); return 1 }
    fmt.printfln("odin-son: stored %s (%d bytes), commit complete", output, len(bytes))
    if embedded {
        output_stem := output
        if strings.has_suffix(output, ".o") do output_stem = output[:len(output)-2]
        blueprint_path := strings.concatenate({output_stem, ".bp"})
        blueprint := package_boids(bytes)
        fmt.printfln("odin-son: storing native Blueprint %s", blueprint_path)
        if os.write_entire_file(blueprint_path, blueprint) != nil { fmt.eprintln("cannot write", blueprint_path); return 1 }
        fmt.printfln("odin-son: stored %s (%d bytes), commit complete; boids is ready to load", blueprint_path, len(blueprint))
    }
    return 0
}
