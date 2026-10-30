package main
import "base:runtime"
import "core:fmt"
import "core:mem"
import "core:strings"
import "bac"
import "typecheck"
import "utils/arna"
import os "platform"
foreign _ {
    trueos_cabi_blueprint_stop_control_v1 :: proc "c" (op: u32) -> i32 ---
    trueos_cabi_blueprint_shutdown :: proc "c" (data: rawptr, size: uintptr) -> i32 ---
    trueos_cabi_blueprint_launch_script_v1 :: proc "c" (data: rawptr, size: uintptr) -> i32 ---
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
    bac.init_custom_fmt()
    typecheck.init_type_fmt()
    if argc <= 1 do return run_tui()
    if argc == 3 && string(argv[1]) == "--ide-build" do return ide_build(string(argv[2]))
    if argc == 2 && string(argv[1]) == "--tui" do return run_tui()
    if argc == 2 && string(argv[1]) == "--mandelbrot_gpu_cpu" do return run_mandelbrot_demo()
    if argc == 2 && string(argv[1]) == "--mandelbrot_gpu_poc" do return run_mandelbrot_demo("mandelbrot_gpu_poc")
    if argc == 2 && string(argv[1]) == "--water_light" do return run_mandelbrot_demo("water_light")
    return run_compiler(argc, argv)
}
run_compiler :: proc(argc: uintptr, argv: [^]cstring) -> i32 {
    job: mem.Dynamic_Arena
    mem.dynamic_arena_init(&job)
    defer mem.dynamic_arena_destroy(&job)
    context.allocator = mem.dynamic_arena_allocator(&job)
    context.temp_allocator = context.allocator
    fmt.printfln("odin-son: argc=%d", argc)
    for i in 0..<argc { fmt.printfln("odin-son: argv[%d]=%q", i, string(argv[i])) }
    input := ""
    output := "a.o"
    root := "."
    collections_enabled := false
    level := OPT_LEVELS[len(OPT_LEVELS)-1]
    target := TARGETS[.AMD64]
    blueprint_output := false
    check := false
    debug := false
    output_explicit := false
    gpu_pixel := false
    gpu_poc := false
    for i := uintptr(1); i < argc; i += 1 {
        arg := string(argv[i])
        switch {
        case arg == "-o", arg == "--odin-root":
            i += 1
            if i >= argc { fmt.eprintln("missing flag value"); return 1 }
            if arg == "-o" { output = string(argv[i]); output_explicit = true } else { root = string(argv[i]); collections_enabled = true }
        case arg == "--help", arg == "-h":
            fmt.println("usage: odin-son [entry.odin] [-o output.o] [--odin-root odin] [-target:amd64|arm64|wasm64] [-o:level] [-debug] [-check] [--blueprint]")
            fmt.println("No arguments opens the compiler TUI. --cpu-boids compiles the embedded CPU demo. --ide-build request.json handles an IDE build.")
            fmt.println("--mandelbrot_gpu_cpu compiles and queues the Mandelbrot demo once.")
            fmt.println("--mandelbrot_gpu_poc compiles and queues the proof-of-concept backend Mandelbrot demo once.")
            fmt.println("--gpu-pixel shader.odin.source -o shader.eu compiles a tagged f32 pixel procedure to Intel Xe-LP SIMD8.")
            fmt.println("--gpu-poc shader.poc.odin.source -o shader.eu compiles a complete SIMD8 kernel through intel_xelp_poc.")
            return 0
        case arg == "--cpu-boids":
        case arg == "--gpu-pixel": gpu_pixel = true
        case arg == "--gpu-poc": gpu_poc = true
        case arg == "--blueprint": blueprint_output = true
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
    if gpu_pixel || gpu_poc {
        if embedded || blueprint_output || (gpu_pixel && gpu_poc) {fmt.eprintln("choose --gpu-pixel or --gpu-poc with one source path and raw code output"); return 1}
        return compile_pixel_file(input, output, gpu_poc)
    }
    if blueprint_output && target.name != "amd64" { fmt.eprintln("--blueprint requires -target:amd64"); return 1 }
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
    types.mems.prc.reserved = #config(TRUEOS_COMPILER_GRAPH_MIB, 8)*1024*1024
    types.mems.type.reserved = #config(TRUEOS_COMPILER_TYPES_MIB, 16)*1024*1024
    typecheck.types_init(&types)
    if types.mems.type.ptr == nil { fmt.eprintln("compiler arena allocation failed"); return 1 }
    defer typecheck.types_deinit(&types)
    global: typecheck.Global_Ctx
    global.root = root
    // Old SDK assets can outlive the package that installed them. Loading them
    // implicitly exceeds the bounded native compiler's source arena.
    if collections_enabled {
        for col in ([]string{"base", "core", "vendor"}) {
            global.collections[col], _ = os.join_path({root, col}, context.temp_allocator)
        }
    }
    ctx: Gen_Ctx
    ctx.types = &types
    ctx.global = &global
    ctx.target = target
    ctx.check = check
    ctx.errors = os.to_writer(os.stderr)
    ctx.prc.has_dbg = debug
    ctx.ralloc_mode = level.ralloc_mode
    if embedded {
        if !load_embedded_boids(&ctx) { fmt.eprintln("embedded boids parse failed"); return 1 }
    } else { load_program(&ctx, input) }
    if ctx.error_cnt > 0 do return 1
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
    if embedded || blueprint_output {
        output_stem := output
        if strings.has_suffix(output, ".o") do output_stem = output[:len(output)-2]
        blueprint_path := strings.concatenate({output_stem, ".bp"})
        blueprint := package_boids(bytes)
        fmt.printfln("odin-son: storing native Blueprint %s", blueprint_path)
        if os.write_entire_file(blueprint_path, blueprint) != nil { fmt.eprintln("cannot write", blueprint_path); return 1 }
        fmt.printfln("odin-son: stored %s (%d bytes), commit complete; Blueprint is ready to load", blueprint_path, len(blueprint))
    }
    return 0
}
