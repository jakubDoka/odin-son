package main

foreign _ {
    trueos_time_monotonic_nanos :: proc() -> u64 ---
    trueos_cabi_ui4_scene_window_title_set_v1 :: proc(window: u32, text: [^]u8, bytes: uintptr) -> i32 ---
    trueos_cabi_ui4_scene_native_compute_upload_v1 :: proc(window, offset, total: u32, bytes: ^u8, size: uintptr) -> i32 ---
    trueos_cabi_ui4_scene_native_compute_fields_upload_v1 :: proc(window, offset, total: u32, bytes: ^f32, size: uintptr) -> i32 ---
    trueos_cabi_ui4_scene_native_compute_fields_render_v1 :: proc(window: u32) -> i32 ---
    trueos_cabi_ui4_scene_compute_frame_publish :: proc(window, x, y, width, height: u32) -> i32 ---
    trueos_cabi_write :: proc(stream: u32, bytes: [^]u8, size: uintptr) ---
    trueos_cabi_blueprint_stop_control_v1 :: proc(op: u32) -> i32 ---
    trueos_cabi_blueprint_shutdown :: proc(data: [^]u8, size: uintptr) -> i32 ---
    trueos_cabi_sleep_ms :: proc(ms: u64) ---
    trueos_cabi_ui4_scene_frame_open_visual :: proc(x, y: i32, width, height, hz: u32) -> u32 ---
    trueos_cabi_ui4_scene_frame_set_opacity :: proc(window, opacity: u32) -> i32 ---
    trueos_cabi_ui4_scene_visual_frame_begin :: proc(window: u32) -> i32 ---
    trueos_cabi_ui4_scene_resize_event_take :: proc(window: u32, event: ^Resize) -> i32 ---
    trueos_cabi_ui4_scene_frame_resize :: proc(window, width, height: u32) -> i32 ---
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

water: Water
optics: Optics
log_buffer: [512]u8
log_length: int

message :: proc(text: string) {
    trueos_cabi_write(1, raw_data(text), uintptr(len(text)))
}

log_text :: proc(text: string) {
    for i := 0; i < len(text); i += 1 {
        if log_length < 511 {log_buffer[log_length] = text[i]; log_length += 1}
    }
}

log_integer :: proc(value: i64) {
    n := value
    if n < 0 {log_text("-"); n = -n}
    digits: [20]u8
    count := 0
    for {
        digits[count] = u8(n%10)+48
        count += 1
        n /= 10
        if n == 0 do break
    }
    for count > 0 {
        count -= 1
        log_buffer[log_length] = digits[count]
        log_length += 1
    }
}

log_flush :: proc() {
    log_text("\n")
    trueos_cabi_write(1, raw_data(log_buffer[:]), uintptr(log_length))
    log_length = 0
}

failure :: proc(stage: string, status: i32) -> i32 {
    log_length = 0
    log_text("water_light: stage="); log_text(stage)
    log_text(" status="); log_integer(i64(status)); log_flush()
    return status
}

statistics :: proc(tick_us, optics_us, field_prepare_us, present_us, dropped: u64) {
    mass := f64(0.0)
    for i := 0; i < CELLS; i += 1 do mass += f64(water.height[i])
    residual := optics.incident-optics.reflected-optics.absorbed-optics.escaped-optics.deposited
    log_length = 0
    log_text("water_light: steps="); log_integer(i64(water.steps))
    log_text(" mass_error_ppm="); log_integer(i64((mass-water.initial_mass)*1000000.0/water.initial_mass))
    log_text(" solve_us="); log_integer(i64(tick_us))
    log_text(" optics_us="); log_integer(i64(optics_us))
    log_text(" field_prepare_us="); log_integer(i64(field_prepare_us))
    log_text(" present_us="); log_integer(i64(present_us))
    log_text(" energy_error_ppm="); log_integer(i64(residual*1000000.0/optics.incident))
    log_text(" dropped_ticks="); log_integer(i64(dropped)); log_flush()
}

set_title :: proc(window: u32, mode: int) {
    title := "Water light | drag ripples | Space pause | V field | wheel depth | R reset"
    if mode == 1 do title = "Water height | V next field | Space pause | R reset"
    if mode == 2 do title = "Photon flux / caustics | V next field | Space pause | R reset"
    trueos_cabi_ui4_scene_window_title_set_v1(window, raw_data(title), uintptr(len(title)))
}

seed_water :: proc() {
    water_reset(&water)
    water_drop(&water, 22.0, 23.0, 0.12)
    water_drop(&water, 42.0, 18.0, 0.08)
}

present :: proc(window, width, height: u32) -> i32 {
    for offset := u32(0); offset < 663552; offset += 2048 {
        count := u32(663552)-offset
        if count > 2048 do count = 2048
        status := trueos_cabi_ui4_scene_native_compute_fields_upload_v1(window, offset, 663552, &optics.fields[offset/4], uintptr(count))
        for status == -7 {
            if trueos_cabi_blueprint_stop_control_v1(1) != 0 do return -3
            trueos_cabi_sleep_ms(4)
            status = trueos_cabi_ui4_scene_native_compute_fields_upload_v1(window, offset, 663552, &optics.fields[offset/4], uintptr(count))
        }
        if status != 0 do return failure("field-upload", status)
    }
    for trueos_cabi_blueprint_stop_control_v1(1) == 0 {
        status := trueos_cabi_ui4_scene_visual_frame_begin(window)
        if status == -7 {trueos_cabi_sleep_ms(4); continue}
        if status != 0 do return failure("begin", status)
        status = trueos_cabi_ui4_scene_native_compute_fields_render_v1(window)
        for status == -7 {
            if trueos_cabi_blueprint_stop_control_v1(1) != 0 do return -3
            trueos_cabi_sleep_ms(4)
            status = trueos_cabi_ui4_scene_native_compute_fields_render_v1(window)
        }
        if status != 0 do return failure("gpu-shade", status)
        for trueos_cabi_blueprint_stop_control_v1(1) == 0 {
            status = trueos_cabi_ui4_scene_compute_frame_publish(window, 0, 0, width, height)
            if status != -7 do return status
            trueos_cabi_sleep_ms(4)
        }
    }
    return -3
}

run :: proc(window: u32) -> i32 {
    code := transmute([]u8)native_pixel_code
    for offset := 0; offset < len(code); offset += 2048 {
        count := len(code)-offset
        if count > 2048 do count = 2048
        status := trueos_cabi_ui4_scene_native_compute_upload_v1(window, u32(offset), u32(len(code)), &code[offset], uintptr(count))
        if status != 0 do return failure("gpu-upload", status)
    }
    seed_water()
    set_title(window, 0)
    status := trueos_cabi_ui4_scene_frame_set_opacity(window, 255)
    if status != 0 do return failure("opacity", status)
    width, height := u32(640), u32(480)
    depth := f32(12.0)
    mode := 0
    paused, automatic := false, true
    was_space, was_v, was_r, was_a, was_p := false, false, false, false, false
    pending: Resize
    resizing := false
    last := trueos_time_monotonic_nanos()
    next_frame := last
    accumulator, dropped, frames := u64(0), u64(0), u64(0)
    last_drop := u64(0)
    tick_us := u64(0)
    dirty := true
    profile_pending := false
    message("water_light: ready; D2Q9 water=64x48 light=128x96 fields=192x144x6; native CPU fields + runtime-generated SIMD8 GPU water shading\n")
    message("water_light: drag ripples; Space pause; V water/height/caustics; wheel optical depth; A rain; R reset; P profile; Q/Escape quit\n")
    for trueos_cabi_blueprint_stop_control_v1(1) == 0 {
        keyboard: Keyboard
        status = trueos_cabi_ui4_scene_keyboard_state(window, &keyboard)
        if status == -3 do return 0
        if status != 0 && status != 1 do return failure("keyboard", status)
        if keyboard.down[0] & (u32(1) << 20) != 0 || keyboard.down[1] & (u32(1) << 9) != 0 do return 0
        space := keyboard.down[1] & (u32(1) << 12) != 0
        v := keyboard.down[0] & (u32(1) << 25) != 0
        r := keyboard.down[0] & (u32(1) << 21) != 0
        a := keyboard.down[0] & (u32(1) << 4) != 0
        p := keyboard.down[0] & (u32(1) << 19) != 0
        if space && !was_space {paused = !paused; accumulator = 0}
        if v && !was_v {mode = (mode+1)%3; set_title(window, mode); dirty = true}
        if r && !was_r {seed_water(); last_drop = 0; accumulator = 0; dirty = true}
        if a && !was_a do automatic = !automatic
        if p && !was_p {profile_pending = true; dirty = true}
        was_space, was_v, was_r, was_a = space, v, r, a
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
            if status == -7 {trueos_cabi_sleep_ms(4); continue}
            if status == -3 do return 0
            if status != 0 do return failure("resize", status)
            width, height = pending.width, pending.height
            resizing = false
            dirty = true
        }
        for {
            event: Pointer
            status = trueos_cabi_ui4_scene_pointer_event_take(window, &event)
            if status == 1 do break
            if status == -3 do return 0
            if status != 0 do return failure("pointer", status)
            if event.wheel != 0 {
                if event.wheel > 0 {depth *= 1.1} else {depth /= 1.1}
                if depth < 4.0 do depth = 4.0
                if depth > 20.0 do depth = 20.0
                dirty = true
            }
            if event.pressed & 1 != 0 || (event.buttons & 1 != 0 && water.steps >= last_drop+6) {
                view_w, view_h := f32(width), f32(height)
                if view_w*3.0 > view_h*4.0 {view_w = view_h*4.0/3.0} else {view_h = view_w*3.0/4.0}
                u := (f32(event.local_x)-(f32(width)-view_w)*0.5)/view_w
                t := (f32(event.local_y)-(f32(height)-view_h)*0.5)/view_h
                px, py := u*f32(GRID_W+4)-2.5, t*f32(GRID_H+3)-2.0
                if px >= 0.0 && px < f32(GRID_W) && py >= 0.0 && py < f32(GRID_H) {
                    water_drop(&water, px, py, 0.06)
                    last_drop = water.steps
                    dirty = true
                }
            }
        }
        now := trueos_time_monotonic_nanos()
        elapsed := now-last
        last = now
        if !paused {
            accumulator += elapsed
            solved := 0
            started := trueos_time_monotonic_nanos()
            for accumulator >= 16666667 && solved < 6 {
                if !water_step(&water) do return failure("unstable-field", -22)
                accumulator -= 16666667
                solved += 1
                if automatic && water.steps%120 == 0 {
                    cx := f32(12)+f32((water.steps/120*17)%40)
                    cy := f32(10)+f32((water.steps/120*11)%28)
                    water_drop(&water, cx, cy, 0.08)
                }
            }
            if accumulator >= 16666667 {dropped += accumulator/16666667; accumulator %= 16666667}
            if solved > 0 {tick_us = (trueos_time_monotonic_nanos()-started)/u64(solved)/1000; dirty = true}
        }
        if now >= next_frame && dirty {
            started := trueos_time_monotonic_nanos()
            light_solve(&water, &optics, depth)
            optics_us := (trueos_time_monotonic_nanos()-started)/1000
            started = trueos_time_monotonic_nanos()
            prepare_water_fields(&water, &optics, depth, mode)
            field_prepare_us := (trueos_time_monotonic_nanos()-started)/1000
            started = trueos_time_monotonic_nanos()
            status = present(window, width, height)
            if status == -3 do return 0
            if status != 0 do return failure("present", status)
            present_us := (trueos_time_monotonic_nanos()-started)/1000
            if frames%120 == 0 || profile_pending do statistics(tick_us, optics_us, field_prepare_us, present_us, dropped)
            profile_pending = false
            frames += 1
            dirty = false
            next_frame = now+33333333
        }
        was_p = p
        trueos_cabi_sleep_ms(4)
    }
    return 0
}

main :: proc() -> i32 {
    if trueos_cabi_blueprint_stop_control_v1(0) != 0 do return 1
    window := trueos_cabi_ui4_scene_frame_open_visual(60, 60, 640, 480, 30)
    status := i32(1)
    if window != 0 {
        status = run(window)
        if trueos_cabi_ui4_solara_frame_close(window) != 0 do status = 1
    }
    reason := "Water light demo finished"
    trueos_cabi_blueprint_shutdown(raw_data(reason), uintptr(len(reason)))
    return status
}
