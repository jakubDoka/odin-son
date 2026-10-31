package main

foreign _ {
    trueos_cabi_write :: proc(stream: u32, bytes: [^]u8, size: uintptr) ---
    trueos_cabi_blueprint_stop_control_v1 :: proc(op: u32) -> i32 ---
    trueos_cabi_blueprint_shutdown :: proc(data: [^]u8, size: uintptr) -> i32 ---
    trueos_cabi_sleep_ms :: proc(ms: u64) ---
    trueos_cabi_ui4_scene_frame_open_visual :: proc(x, y: i32, width, height, hz: u32) -> u32 ---
    trueos_cabi_ui4_scene_frame_set_opacity :: proc(window, opacity: u32) -> i32 ---
    trueos_cabi_ui4_scene_visual_frame_begin :: proc(window: u32) -> i32 ---
    trueos_cabi_ui4_scene_resize_event_take :: proc(window: u32, event: ^Resize) -> i32 ---
    trueos_cabi_ui4_scene_frame_resize :: proc(window, width, height: u32) -> i32 ---
    trueos_cabi_ui4_scene_native_compute_upload_v1 :: proc(window, offset, total: u32, bytes: ^u8, size: uintptr) -> i32 ---
    trueos_cabi_ui4_scene_native_compute_render_v1 :: proc(window: u32, x, y, dx, dy: f32) -> i32 ---
    trueos_cabi_ui4_scene_compute_frame_publish :: proc(window: u32, x, y, width, height: u32) -> i32 ---
    trueos_cabi_ui4_solara_frame_close :: proc(window: u32) -> i32 ---
    trueos_cabi_ui4_scene_keyboard_state :: proc(window: u32, state: ^Keyboard) -> i32 ---
    trueos_cabi_ui4_scene_pointer_event_take :: proc(window: u32, event: ^Pointer) -> i32 ---
}

Keyboard :: struct {
    route: [4]u32,
    metadata: [4]u8,
    keys: [6]u8,
    ascii: [6]u8,
    down: [8]u32,
}

Pointer :: struct {
    route: [6]u32,
    local_x: i32,
    local_y: i32,
    dx: i32,
    dy: i32,
    wheel: i32,
    buttons: u32,
    pressed: u32,
    released: u32,
    combo: u32,
    vcursor: u32,
}

Resize :: struct {
    old_width: u32,
    old_height: u32,
    width: u32,
    height: u32,
}

message :: proc(text: string) {
    trueos_cabi_write(1, raw_data(text), uintptr(len(text)))
}

frame :: proc(window, width, height: u32, x, y, step: f32) -> i32 {
    for trueos_cabi_blueprint_stop_control_v1(1) == 0 {
        status := trueos_cabi_ui4_scene_visual_frame_begin(window)
        if status == -7 { trueos_cabi_sleep_ms(16); continue }
        if status != 0 do return status
        status = trueos_cabi_ui4_scene_native_compute_render_v1(window, x, y, step, step)
        if status != 0 do return status
        for trueos_cabi_blueprint_stop_control_v1(1) == 0 {
            status = trueos_cabi_ui4_scene_compute_frame_publish(window, 0, 0, width, height)
            if status != -7 do return status
            trueos_cabi_sleep_ms(16)
        }
        break
    }
    return -3
}

run :: proc(window: u32) -> i32 {
    if trueos_cabi_ui4_scene_frame_set_opacity(window, 128) != 0 do return 1
    code := transmute([]u8)native_pixel_code
    for offset := 0; offset < len(code); offset += 2048 {
        count := len(code)-offset
        if count > 2048 do count = 2048
        if trueos_cabi_ui4_scene_native_compute_upload_v1(window, u32(offset), u32(len(code)), &code[offset], uintptr(count)) != 0 {
            message("mandelbrot_gpu_cpu: GPU upload failed\n")
            return 1
        }
    }
    width, height := u32(320), u32(240)
    x, y, step := f32(-2.0), f32(-1.125), f32(3.0/320.0)
    status := frame(window, width, height, x, y, step)
    if status == -3 do return 0
    if status != 0 do return 1
    message("mandelbrot_gpu_cpu: ready; resize frame, wheel zoom, left drag pan, Q/Escape quit\n")
    pending: Resize
    resizing := false
    for trueos_cabi_blueprint_stop_control_v1(1) == 0 {
        keyboard: Keyboard
        status = trueos_cabi_ui4_scene_keyboard_state(window, &keyboard)
        if status == -3 do return 0
        if status != 0 && status != 1 do return 1
        if status == 0 && (keyboard.down[0] & (u32(1) << 20) != 0 || keyboard.down[1] & (u32(1) << 9) != 0) do return 0
        dirty := false
        for {
            event: Resize
            status = trueos_cabi_ui4_scene_resize_event_take(window, &event)
            if status == 1 do break
            if status == -3 do return 0
            if status != 0 do return 1
            pending = event
            resizing = true
        }
        if resizing {
            status = trueos_cabi_ui4_scene_frame_resize(window, pending.width, pending.height)
            if status == -7 { trueos_cabi_sleep_ms(16); continue }
            if status == -3 do return 0
            if status != 0 do return 1
            x += (f32(width)-f32(pending.width)) * 0.5 * step
            y += (f32(height)-f32(pending.height)) * 0.5 * step
            width, height = pending.width, pending.height
            resizing = false
            dirty = true
        }
        for {
            event: Pointer
            status = trueos_cabi_ui4_scene_pointer_event_take(window, &event)
            if status == 1 do break
            if status == -3 do return 0
            if status != 0 do return 1
            if event.wheel != 0 {
                factor := f32(0.8)
                if event.wheel < 0 do factor = 1.25
                next_step := step * factor
                if next_step < 0.0000001 do next_step = 0.0000001
                if next_step > 0.1 do next_step = 0.1
                x += f32(event.local_x) * (step-next_step)
                y += f32(event.local_y) * (step-next_step)
                step = next_step
                dirty = true
            }
            if event.buttons & 1 != 0 && (event.dx != 0 || event.dy != 0) {
                x -= f32(event.dx) * step
                y -= f32(event.dy) * step
                dirty = true
            }
        }
        if dirty {
            status = frame(window, width, height, x, y, step)
            if status == -3 do return 0
            if status != 0 do return 1
        }
        trueos_cabi_sleep_ms(16)
    }
    return 0
}

main :: proc() -> i32 {
    if trueos_cabi_blueprint_stop_control_v1(0) != 0 do return 1
    window := trueos_cabi_ui4_scene_frame_open_visual(40, 40, 320, 240, 30)
    status := i32(1)
    if window != 0 {
        status = run(window)
        if trueos_cabi_ui4_solara_frame_close(window) != 0 do status = 1
    } else {
        message("mandelbrot_gpu_cpu: cannot open UI4 frame\n")
    }
    if status != 0 do message("mandelbrot_gpu_cpu: demo failed\n")
    reason := "Mandelbrot demo finished"
    trueos_cabi_blueprint_shutdown(raw_data(reason), uintptr(len(reason)))
    return status
}
