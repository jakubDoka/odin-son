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
    if argc <= 1 {
        when #config(TRUEOS_MANDELBROT_SMOKE_DEFAULT, false) {
            return run_gpu_envelope_smoke()
        } else when #config(TRUEOS_MANDELBROT_VERIFY_DEFAULT, false) {
            return run_gpu_mandelbrot("--verify-gpu-mandelbrot")
        } else {
            return run_tui()
        }
    }
    if argc == 3 && string(argv[1]) == "--ide-build" do return ide_build(string(argv[2]))
    if argc == 2 && string(argv[1]) == "--tui" do return run_tui()
    if argc == 2 {
        mode := string(argv[1])
        if mode == "--verify-gpu-envelope" do return run_gpu_envelope_smoke()
        if mode == "--gpu-mandelbrot" || mode == "--run-gpu-mandelbrot" || mode == "--verify-gpu-mandelbrot" {
            return run_gpu_mandelbrot(mode)
        }
    }
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
    xelp_body_output := ""
    root := "."
    level := OPT_LEVELS[len(OPT_LEVELS)-1]
    target := TARGETS[0]
    blueprint_output := false
    check := false
    debug := false
    output_explicit := false
    gpu_boids := #config(TRUEOS_GPU_BOIDS_DEFAULT, false)
    gpu_autorun := #config(TRUEOS_GPU_BOIDS_AUTORUN, false)
    for i := uintptr(1); i < argc; i += 1 {
        arg := string(argv[i])
        switch {
        case arg == "-emit-xelp-body":
            i += 1
            if i >= argc { fmt.eprintln("missing flag value"); return 1 }
            xelp_body_output = string(argv[i])
        case arg == "-o", arg == "--odin-root":
            i += 1
            if i >= argc { fmt.eprintln("missing flag value"); return 1 }
            if arg == "-o" { output = string(argv[i]); output_explicit = true } else { root = string(argv[i]) }
        case arg == "--help", arg == "-h":
            fmt.println("usage: odin-son [entry.odin] [-o output.o] [--odin-root odin] [-target:amd64|arm64|wasm64] [-o:level] [-debug] [-check] [-emit-xelp-body body.bin]")
            fmt.println("No source argument opens the persistent demo TUI. --cpu-boids compiles the embedded CPU demo. --blueprint also packages an amd64 input as a .bp.")
            fmt.println("--gpu-boids compiles embedded tagged native GPU boids and stores gpu-boids.o and gpu-boids.bp.")
            fmt.println("--gpu-mandelbrot stores an embedded source's native EU body. --run-gpu-mandelbrot compiles and displays it; --verify-gpu-mandelbrot renders two source variants.")
            return 0
        case arg == "--gpu-boids": gpu_boids = true
        case arg == "--run-gpu-boids": gpu_boids = true; gpu_autorun = true
        case arg == "--cpu-boids": gpu_boids = false; gpu_autorun = false
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
    if blueprint_output && target.name != "amd64" { fmt.eprintln("--blueprint requires -target:amd64"); return 1 }
    if gpu_boids && !embedded { fmt.eprintln("--gpu-boids requires embedded source"); return 1 }
    if embedded {
        if target.name != "amd64" { fmt.eprintln("embedded TRUEOS boids requires -target:amd64"); return 1 }
        if !output_explicit do output = gpu_boids ? "gpu-boids.o" : "boids.o"
        if gpu_boids {
            fmt.printfln("odin-son: compiling embedded tagged TRUEOS GPU boids (%d source bytes)", len(EMBEDDED_GPU_BOIDS))
            fmt.println("[odin-son gpu-boids] tag=gpu backend=arithmetic-v1 native GPU interpreter; x86 orchestration")
            fmt.printfln("[odin-son gpu-backend] source_fnv1a64=0x%016x bytes=%d", artifact_fnv1a64(transmute([]u8)EMBEDDED_GPU_BOIDS), len(EMBEDDED_GPU_BOIDS))
        } else { fmt.printfln("odin-son: compiling embedded TRUEOS boids (%d source bytes)", len(EMBEDDED_BOIDS)) }
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
    for col in ([]string{"base", "core", "vendor"}) {
        global.collections[col], _ = os.join_path({root, col}, context.temp_allocator)
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
        if !load_embedded_boids(&ctx, gpu_boids) { fmt.eprintln("embedded boids parse failed"); return 1 }
    } else { load_program(&ctx, input) }
    if ctx.error_cnt > 0 do return 1
    fmt.printfln("odin-son: source collections root=%s (default: app root apps/odin-son)", root)
    fmt.println("odin-son: type checking")
    typecheck.typecheck_program(&ctx)
    if ctx.error_cnt > 0 do return 1
    if xelp_body_output != "" {
        if xelp_body_output == output { fmt.eprintln("Xe-LP body and CPU object require different output paths"); return 1 }
        body: []u8
        native_index := -1
        gpu_count := 0
        for prc, j in ctx.procs {
            if !prc.gpu_tag do continue
            gpu_count += 1
            if prc.gpu_native do native_index = j
        }
        ok := false
        if gpu_count == 1 && native_index >= 0 {
            body = compile_gpu_scalar_body(&ctx, &ctx.procs[native_index])
            ok = true
        } else {
            body, ok = typecheck.emit_gpu_xelp_body(&ctx)
        }
        if !ok { fmt.eprintln("Xe-LP body emission requires exactly one nonempty tagged gpu arithmetic procedure"); return 1 }
        if os.write_entire_file(xelp_body_output, body) != nil { fmt.eprintln("cannot write Xe-LP body"); return 1 }
        fmt.printfln("[odin-son xelp] stage=body-emitted target=12p1 bytes=%d complete_kernel=false artifact=%s", len(body), xelp_body_output)
    }

    for prc in ctx.procs {
        if !prc.gpu_tag do continue
        if prc.gpu_native {
            fmt.printfln("[odin-son gpu-backend] proc=%s source_ops=%d target=intel_xelp abi=scalar-f32-v1", prc.name, len(prc.gpu_ops))
            continue
        }
        fmt.printfln("[odin-son gpu-backend] proc=%s instructions=%d words=%d target=arithmetic-v1", prc.name, len(prc.gpu_program)/4, len(prc.gpu_program))
        for i := 0; i < len(prc.gpu_program); i += 4 {
            fmt.printfln("[odin-son gpu-backend] op=%d dst=%d src=%d imm=0x%08x", prc.gpu_program[i], prc.gpu_program[i+1], prc.gpu_program[i+2], prc.gpu_program[i+3])
        }
    }
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
    if gpu_boids do fmt.printfln("odin-son: artifact path=%s bytes=%d fnv1a64=0x%016x", output, len(bytes), artifact_fnv1a64(bytes))
    if embedded || blueprint_output {
        output_stem := output
        if strings.has_suffix(output, ".o") do output_stem = output[:len(output)-2]
        blueprint_path := strings.concatenate({output_stem, ".bp"})
        blueprint := package_boids(bytes)
        fmt.printfln("odin-son: storing native Blueprint %s", blueprint_path)
        if os.write_entire_file(blueprint_path, blueprint) != nil { fmt.eprintln("cannot write", blueprint_path); return 1 }
        fmt.printfln("odin-son: stored %s (%d bytes), commit complete; boids is ready to load", blueprint_path, len(blueprint))
        if gpu_boids do fmt.printfln("odin-son: artifact path=%s bytes=%d fnv1a64=0x%016x", blueprint_path, len(blueprint), artifact_fnv1a64(blueprint))
        if gpu_boids && gpu_autorun {
            launch_path := blueprint_path
            if !strings.contains(launch_path, "/") do launch_path = strings.concatenate({"./", launch_path})
            launch_script := #config(TRUEOS_GPU_BOIDS_BATCH, false) ? "batch" : ""
            payload := strings.concatenate({launch_path, "\x00", launch_script, "\x00headless"})
            result := trueos_cabi_blueprint_launch_script_v1(raw_data(payload), uintptr(len(payload)))
            if result != 0 { fmt.printfln("[odin-son gpu-boids] FAIL launch status=%d", result); return 1 }
            fmt.printfln("[odin-son gpu-boids] stage=launch-queued artifact=%s destination=headless", launch_path)
        }
    }
    return 0
}

artifact_fnv1a64 :: proc(bytes: []u8) -> u64 {
    value := u64(14695981039346656037)
    for byte in bytes { value = (value ~ u64(byte)) * 1099511628211 }
    return value
}
