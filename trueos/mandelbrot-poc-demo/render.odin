package main

foreign _ {
    trueos_cabi_alloc :: proc(size: uintptr) -> [^]u32 ---
    trueos_cabi_free :: proc(data: [^]u32) ---
    trueos_cabi_ui4_scene_native_compute_dispatch_v1 :: proc(window: u32, inputs: ^u32, registers: u32, out: ^u32) -> i32 ---
    trueos_cabi_ui4_scene_sprite_upload_rgba8 :: proc(window, sprite, width, height: u32, rgba: [^]u32, size: uintptr) -> i32 ---
    trueos_cabi_ui4_scene_sprite_quads :: proc(window: u32, quads: ^Sprite_Quad, count: uintptr) -> i32 ---
}

Sprite_Quad :: struct {
    sprite_id: u32,
    corners: [4][4]f32,
    color_rgba: u32,
    flags: u32,
}

render_poc :: proc(window, width, height: u32, x, y, step: f32) -> i32 {
    size := uintptr(width)*uintptr(height)*4
    rgba := trueos_cabi_alloc(size)
    if uintptr(rgba) == 0 do return report("rgba-allocate", -6)
    status := fill_poc(window, width, height, x, y, step, rgba)
    trueos_cabi_free(rgba)
    return status
}

fill_poc :: proc(window, width, height: u32, x, y, step: f32, rgba: [^]u32) -> i32 {
    // The existing POC transport retires one SIMD8 dispatch per call; bound that cost on large windows.
    scale := (width+79)/80
    vertical := (height+59)/60
    if vertical > scale do scale = vertical
    if scale == 0 do scale = 1
    for sy := u32(0); sy < height; sy += scale {
        py := sy+scale/2
        if py >= height do py = height-1
        for sx := u32(0); sx < width; sx += 8*scale {
            if trueos_cabi_blueprint_stop_control_v1(1) != 0 do return -3
            inputs: [2][8]u32
            for lane := 0; lane < 8; lane += 1 {
                px := sx+u32(lane)*scale+scale/2
                if px >= width do px = width-1
                inputs[0][lane] = transmute(u32)(x+f32(px)*step)
                inputs[1][lane] = transmute(u32)(y+f32(py)*step)
            }
            actual: [8]u32
            status := trueos_cabi_ui4_scene_native_compute_dispatch_v1(window, &inputs[0][0], 2, &actual[0])
            for status == -7 {
                if trueos_cabi_blueprint_stop_control_v1(1) != 0 do return -3
                trueos_cabi_sleep_ms(16)
                status = trueos_cabi_ui4_scene_native_compute_dispatch_v1(window, &inputs[0][0], 2, &actual[0])
            }
            if status != 0 do return report("gpu-dispatch", status)
            if sx == 0 && sy == 0 do report("gpu-first-dispatch", status)
            for lane := 0; lane < 8; lane += 1 {
                left := sx+u32(lane)*scale
                if left >= width do break
                value := transmute(f32)actual[lane]
                if !(value >= 0.0) do value = 0.0
                if value > 1.0 do value = 1.0
                gray := u32(value*255.0)
                color := u32(0xff000000) | gray*0x010101
                for row := sy; row < sy+scale && row < height; row += 1 {
                    for col := left; col < left+scale && col < width; col += 1 {
                        rgba[uintptr(row)*uintptr(width)+uintptr(col)] = color
                    }
                }
            }
        }
    }
    // Visual frames require a retired GPU producer for their exact scanout allocation.
    status := report("sprite-upload", trueos_cabi_ui4_scene_sprite_upload_rgba8(window, 1, width, height, rgba, uintptr(width)*uintptr(height)*4))
    if status != 0 do return status
    quad: Sprite_Quad
    quad.sprite_id = 1
    quad.corners[1] = {f32(width), 0, 1, 0}
    quad.corners[2] = {f32(width), f32(height), 1, 1}
    quad.corners[3] = {0, f32(height), 0, 1}
    quad.color_rgba = 0xffffffff
    return report("sprite-copy", trueos_cabi_ui4_scene_sprite_quads(window, &quad, 1))
}
