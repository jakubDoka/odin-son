package main

import "core:fmt"
import "core:mem"
import "core:slice"
import "core:strings"
import "typecheck"
import "utils/arna"
import os "platform"

foreign _ {
    trueos_cabi_ui4_scene_frame_open_visual :: proc "c" (x, y: i32, width, height, hz: u32) -> u32 ---
    trueos_cabi_ui4_scene_visual_frame_begin :: proc "c" (window: u32) -> i32 ---
    trueos_cabi_ui4_scene_native_compute_upload_v1 :: proc "c" (window, offset, total: u32, bytes: [^]u8, size: uintptr) -> i32 ---
    trueos_cabi_ui4_scene_native_compute_render_v1 :: proc "c" (window: u32, x, y, dx, dy: f32) -> i32 ---
    trueos_cabi_ui4_scene_compute_frame_publish :: proc "c" (window, x, y, width, height: u32) -> i32 ---
    trueos_cabi_ui4_solara_frame_close :: proc "c" (window: u32) -> i32 ---
    trueos_cabi_ui4_scene_keyboard_state :: proc "c" (window: u32, state: ^Mandelbrot_Keyboard) -> i32 ---
    trueos_cabi_ui4_scene_pointer_event_take :: proc "c" (window: u32, event: ^Mandelbrot_Pointer) -> i32 ---
}

Mandelbrot_Keyboard :: struct {
    route: [4]u32,
    metadata: [4]u8,
    keys, ascii: [6]u8,
    down: [8]u32,
}
Mandelbrot_Pointer :: struct {
    route: [6]u32,
    local_x, local_y, dx, dy, wheel: i32,
    buttons, pressed, released, combo, vcursor: u32,
}
#assert(size_of(Mandelbrot_Keyboard) == 64)
#assert(size_of(Mandelbrot_Pointer) == 64)
#assert(offset_of(Mandelbrot_Keyboard, down) == 32)
#assert(offset_of(Mandelbrot_Pointer, local_x) == 24)

compile_mandelbrot_source :: proc(source: string) -> []u8 {
    arna.scratch[0].reserved = #config(TRUEOS_COMPILER_SCRATCH_MIB, 4)*1024*1024
    arna.scratch[1].reserved = #config(TRUEOS_COMPILER_SCRATCH_MIB, 4)*1024*1024
    types: typecheck.Types
    for &arena in mem.slice_data_cast([]arna.Allocator, mem.ptr_to_bytes(&types.mems)) {
        arena.reserved = #config(TRUEOS_COMPILER_ARENA_MIB, 2)*1024*1024
    }
    types.mems.prc.reserved = #config(TRUEOS_COMPILER_GRAPH_MIB, 8)*1024*1024
    types.mems.type.reserved = #config(TRUEOS_COMPILER_TYPES_MIB, 16)*1024*1024
    typecheck.types_init(&types)
    defer typecheck.types_deinit(&types)
    if types.mems.type.ptr == nil { fmt.eprintln("Mandelbrot compiler allocation failed"); return nil }
    global: typecheck.Global_Ctx
    ctx: Gen_Ctx
    ctx.types = &types
    ctx.global = &global
    ctx.target = TARGETS[0]
    ctx.errors = os.to_writer(os.stderr)
    if !load_embedded_source(&ctx, source, "embedded/gpu-mandelbrot/main.odin") do return nil
    typecheck.typecheck_program(&ctx)
    if ctx.error_cnt != 0 do return nil
    for &prc in ctx.procs {
        if !prc.gpu_native do continue
        body := compile_gpu_scalar_body(&ctx, &prc)
        return slice.clone(body, context.allocator)
    }
    fmt.eprintln("no native GPU procedure in embedded source")
    return nil
}

mandelbrot_upload :: proc(window: u32, body: []u8) -> bool {
    for offset := 0; offset < len(body); offset += 2048 {
        size := min(2048, len(body) - offset)
        rc := trueos_cabi_ui4_scene_native_compute_upload_v1(window, u32(offset), u32(len(body)), raw_data(body[offset:]), uintptr(size))
        if rc != 0 { fmt.printfln("[odin-son mandelbrot] FAIL upload status=%d", rc); return false }
    }
    return true
}

mandelbrot_frame :: proc(window: u32, x, y, step: f32) -> bool {
    if trueos_cabi_blueprint_stop_control_v1(1) != 0 do return false
    rc := trueos_cabi_ui4_scene_visual_frame_begin(window)
    if rc != 0 { fmt.printfln("[odin-son mandelbrot] FAIL begin status=%d", rc); return false }
    rc = trueos_cabi_ui4_scene_native_compute_render_v1(window, x, y, step, step)
    if rc != 0 { fmt.printfln("[odin-son mandelbrot] FAIL native compute status=%d", rc); return false }
    rc = trueos_cabi_ui4_scene_compute_frame_publish(window, 0, 0, 320, 240)
    if rc != 0 { fmt.printfln("[odin-son mandelbrot] FAIL publish status=%d", rc); return false }
    return true
}

run_gpu_mandelbrot :: proc(mode: string) -> i32 {
    job: mem.Dynamic_Arena
    mem.dynamic_arena_init(&job)
    defer mem.dynamic_arena_destroy(&job)
    context.allocator = mem.dynamic_arena_allocator(&job)
    context.temp_allocator = context.allocator
    body := compile_mandelbrot_source(EMBEDDED_MANDELBROT)
    if len(body) == 0 do return 1
    first_hash := artifact_fnv1a64(body)
    fmt.printfln("[odin-son mandelbrot] stage=runtime-compiled iterations=25 bytes=%d fnv1a64=0x%016x target=12p1 abi=pixel-f32-simd8-v1", len(body), first_hash)
    if mode == "--gpu-mandelbrot" {
        if os.write_entire_file("mandelbrot.eu.bin", body) != nil do return 1
        fmt.println("[odin-son mandelbrot] stage=stored artifact=mandelbrot.eu.bin envelope=runtime-owned")
        return 0
    }
    window := trueos_cabi_ui4_scene_frame_open_visual(40, 40, 320, 240, 30)
    if window == 0 { fmt.eprintln("Mandelbrot UI4 open failed"); return 1 }
    defer trueos_cabi_ui4_solara_frame_close(window)
    if !mandelbrot_upload(window, body) do return 1
    x, y, step := f32(-2.0), f32(-1.125), f32(3.0/320.0)
    if !mandelbrot_frame(window, x, y, step) do return 1
    fmt.println("[odin-son mandelbrot] stage=published iterations=25")
    if mode == "--verify-gpu-mandelbrot" {
        variant, _ := strings.replace_all(EMBEDDED_MANDELBROT, "i < 25", "i < 16")
        second := compile_mandelbrot_source(variant)
        if len(second) == 0 || artifact_fnv1a64(second) == first_hash { fmt.eprintln("source change did not change native code"); return 1 }
        fmt.printfln("[odin-son mandelbrot] stage=runtime-compiled iterations=16 bytes=%d fnv1a64=0x%016x", len(second), artifact_fnv1a64(second))
        if !mandelbrot_upload(window, second) || !mandelbrot_frame(window, x, y, step) do return 1
        fmt.println("[odin-son mandelbrot] stage=published iterations=16 source-dependent=true")
        return 0
    }
    for trueos_cabi_blueprint_stop_control_v1(1) == 0 {
        keyboard: Mandelbrot_Keyboard
        keyboard_status := trueos_cabi_ui4_scene_keyboard_state(window, &keyboard)
        if keyboard_status == -3 do return 0
        if keyboard_status != 0 && keyboard_status != 1 {
            fmt.printfln("[odin-son mandelbrot] FAIL keyboard status=%d", keyboard_status)
            return 1
        }
        if keyboard_status == 0 && (keyboard.down[0] & (u32(1) << 20) != 0 || keyboard.down[1] & (u32(1) << 9) != 0) do break
        dirty := false
        for {
            event: Mandelbrot_Pointer
            pointer_status := trueos_cabi_ui4_scene_pointer_event_take(window, &event)
            if pointer_status == 1 do break
            if pointer_status == -3 do return 0
            if pointer_status != 0 {
                fmt.printfln("[odin-son mandelbrot] FAIL pointer status=%d", pointer_status)
                return 1
            }
            if event.wheel != 0 {
                factor := f32(0.8) if event.wheel > 0 else f32(1.25)
                next_step := clamp(step * factor, f32(0.0000001), f32(0.1))
                x += f32(event.local_x) * (step - next_step)
                y += f32(event.local_y) * (step - next_step)
                step = next_step
                dirty = true
            }
            if event.buttons & 1 != 0 && (event.dx != 0 || event.dy != 0) {
                x -= f32(event.dx) * step
                y -= f32(event.dy) * step
                dirty = true
            }
        }
        if dirty && !mandelbrot_frame(window, x, y, step) do return 1
        trueos_cabi_sleep_ms(16)
    }
    return 0
}

run_gpu_envelope_smoke :: proc() -> i32 {
    job: mem.Dynamic_Arena
    mem.dynamic_arena_init(&job)
    defer mem.dynamic_arena_destroy(&job)
    context.allocator = mem.dynamic_arena_allocator(&job)
    context.temp_allocator = context.allocator
    source := "package main\n@(tag = \"gpu\")\nprocess :: proc(cx, cy: f32) -> f32 { return 0.5 }\nmain :: proc() -> int { return int(process(0.0, 0.0)) }\n"
    body := compile_mandelbrot_source(source)
    if len(body) == 0 do return 1
    fmt.printfln("[odin-son mandelbrot] stage=smoke-runtime-compiled bytes=%d fnv1a64=0x%016x value=0.5 target=12p1 abi=pixel-f32-simd8-v1", len(body), artifact_fnv1a64(body))
    window := trueos_cabi_ui4_scene_frame_open_visual(40, 40, 64, 64, 30)
    if window == 0 { fmt.eprintln("GPU envelope smoke UI4 open failed"); return 1 }
    defer trueos_cabi_ui4_solara_frame_close(window)
    if !mandelbrot_upload(window, body) do return 1
    if trueos_cabi_blueprint_stop_control_v1(1) != 0 do return 1
    rc := trueos_cabi_ui4_scene_visual_frame_begin(window)
    if rc != 0 { fmt.printfln("[odin-son mandelbrot] FAIL smoke begin status=%d", rc); return 1 }
    rc = trueos_cabi_ui4_scene_native_compute_render_v1(window, f32(-2.0), f32(-1.125), f32(3.0/64.0), f32(3.0/64.0))
    if rc != 0 { fmt.printfln("[odin-son mandelbrot] FAIL smoke native compute status=%d", rc); return 1 }
    rc = trueos_cabi_ui4_scene_compute_frame_publish(window, 0, 0, 64, 64)
    if rc != 0 { fmt.printfln("[odin-son mandelbrot] FAIL smoke publish status=%d", rc); return 1 }
    fmt.println("[odin-son mandelbrot] stage=smoke-published width=64 height=64 value=0.5")
    return 0
}
