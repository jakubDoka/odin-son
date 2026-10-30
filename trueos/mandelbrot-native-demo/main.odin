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
    trueos_cabi_ui4_scene_native_compute_render_v2 :: proc(window: u32, params: ^f32, bytes: uintptr) -> i32 ---
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

failure :: proc(stage: string, status: i32) -> i32 {
    if status == -3 do return status
    line: [160]u8
    count := 0
    prefix := "mandelbrot_gpu_native: stage="
    for i := 0; i < len(prefix); i += 1 { line[count] = prefix[i]; count += 1 }
    for i := 0; i < len(stage); i += 1 { line[count] = stage[i]; count += 1 }
    separator := " status="
    for i := 0; i < len(separator); i += 1 { line[count] = separator[i]; count += 1 }
    value := i64(status)
    if value < 0 { line[count] = 45; count += 1; value = -value }
    digits: [20]u8
    length := 0
    for {
        digits[length] = u8(value%10) + 48
        length += 1
        value /= 10
        if value == 0 do break
    }
    for length > 0 { length -= 1; line[count] = digits[length]; count += 1 }
    line[count] = 10
    trueos_cabi_write(1, raw_data(line[:]), uintptr(count+1))
    if status == -95 do message("mandelbrot_gpu_native: kernel requires odin-native-gpgpu support\n")
    return status
}

frame :: proc(window, width, height: u32, x, y, step: f32, max_iterations: u32) -> i32 {
    params := [10]f32{x, y, step, step, f32(max_iterations), 0.0, 0.0, 0.0, 0.0, 0.0}
    for trueos_cabi_blueprint_stop_control_v1(1) == 0 {
        status := trueos_cabi_ui4_scene_visual_frame_begin(window)
        if status == -7 { trueos_cabi_sleep_ms(16); continue }
        if status != 0 do return failure("frame-begin", status)
        for {
            if trueos_cabi_blueprint_stop_control_v1(1) != 0 do return -3
            status = trueos_cabi_ui4_scene_native_compute_render_v2(window, &params[0], 40)
            if status != -7 do break
            trueos_cabi_sleep_ms(16)
        }
        if status != 0 do return failure("gpu-render", status)
        for trueos_cabi_blueprint_stop_control_v1(1) == 0 {
            status = trueos_cabi_ui4_scene_compute_frame_publish(window, 0, 0, width, height)
            if status != -7 {
                if status != 0 do return failure("frame-publish", status)
                return 0
            }
            trueos_cabi_sleep_ms(16)
        }
        break
    }
    return -3
}

run :: proc(window: u32) -> i32 {
    status := trueos_cabi_ui4_scene_frame_set_opacity(window, 255)
    if status != 0 do return failure("opacity", status)
    code := transmute([]u8)native_pixel_code
    for offset := 0; offset < len(code); offset += 2048 {
        count := len(code)-offset
        if count > 2048 do count = 2048
        status = trueos_cabi_ui4_scene_native_compute_upload_v1(window, u32(offset), u32(len(code)), &code[offset], uintptr(count))
        if status != 0 do return failure("gpu-upload", status)
    }
    width, height := u32(320), u32(240)
    x, y, step := f32(-2.0), f32(-1.125), f32(3.0/320.0)
    max_iterations := u32(128)
    reset_down, increase_down, decrease_down := false, false, false
    status = frame(window, width, height, x, y, step, max_iterations)
    if status == -3 do return 0
    if status != 0 do return 1
    message("mandelbrot_gpu_native: ready; SIMD8 Mandelbrot; wheel zoom, left drag pan, +/- iterations (32..512), R reset, Q/Escape quit\n")
    pending: Resize
    resizing := false
    dirty := false
    for trueos_cabi_blueprint_stop_control_v1(1) == 0 {
        keyboard: Keyboard
        status = trueos_cabi_ui4_scene_keyboard_state(window, &keyboard)
        if status == -3 do return 0
        if status != 0 && status != 1 do return failure("keyboard", status)
        if status == 0 && (keyboard.down[0] & (u32(1) << 20) != 0 || keyboard.down[1] & (u32(1) << 9) != 0) do return 0
        reset := status == 0 && keyboard.down[0] & (u32(1) << 21) != 0
        increase := status == 0 && (keyboard.down[1] & (u32(1) << 14) != 0 || keyboard.down[2] & (u32(1) << 23) != 0)
        decrease := status == 0 && (keyboard.down[1] & (u32(1) << 13) != 0 || keyboard.down[2] & (u32(1) << 22) != 0)
        if reset && !reset_down {
            x, step = -2.0, 3.0/f32(width)
            y = -f32(height)*0.5*step
            max_iterations = 128
            dirty = true
        }
        if increase && !increase_down && max_iterations < 512 {
            max_iterations += 32
            dirty = true
        }
        if decrease && !decrease_down && max_iterations > 32 {
            max_iterations -= 32
            dirty = true
        }
        reset_down, increase_down, decrease_down = reset, increase, decrease
        for {
            event: Resize
            status = trueos_cabi_ui4_scene_resize_event_take(window, &event)
            if status == 1 do break
            if status == -3 do return 0
            if status != 0 do return failure("resize-event", status)
            pending = event
            resizing = true
        }
        if resizing {
            status = trueos_cabi_ui4_scene_frame_resize(window, pending.width, pending.height)
            if status == -7 { trueos_cabi_sleep_ms(16); continue }
            if status == -3 do return 0
            if status != 0 do return failure("resize", status)
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
            if status != 0 do return failure("pointer-event", status)
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
            status = frame(window, width, height, x, y, step, max_iterations)
            if status == -3 do return 0
            if status != 0 do return 1
            dirty = false
        }
        trueos_cabi_sleep_ms(16)
    }
    return 0
}

main :: proc() -> i32 {
    status := trueos_cabi_blueprint_stop_control_v1(0)
    if status != 0 { failure("stop-control", status); return 1 }
    window := trueos_cabi_ui4_scene_frame_open_visual(40, 40, 320, 240, 30)
    status = 1
    if window != 0 {
        status = run(window)
        if status == -3 do status = 0
        closed := trueos_cabi_ui4_solara_frame_close(window)
        if closed != 0 && closed != -3 { failure("frame-close", closed); status = 1 }
    } else {
        message("mandelbrot_gpu_native: cannot open UI4 frame\n")
    }
    if status != 0 do message("mandelbrot_gpu_native: demo failed\n")
    reason := "Native Mandelbrot demo finished"
    trueos_cabi_blueprint_shutdown(raw_data(reason), uintptr(len(reason)))
    return status
}
