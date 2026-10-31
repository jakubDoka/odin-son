package main

foreign _ {
    trueos_cabi_ui4_scene_native_compute_render_v2 :: proc(window: u32, params: ^f32, bytes: uintptr) -> i32 ---
}

sine :: proc(angle: f32) -> f32 {
    x := angle
    for x > 3.14159265 do x -= 6.2831853
    for x < -3.14159265 do x += 6.2831853
    if x > 1.57079633 do x = 3.14159265-x
    if x < -1.57079633 do x = -3.14159265-x
    xx := x*x
    return x*(1.0 + xx*(-0.166666667 + xx*(0.0083333333 + xx*(-0.0001984127 + xx*0.00000275573))))
}

render_poc :: proc(window, width, height: u32, yaw, pitch, distance: f32) -> i32 {
    step := 2.0/f32(height)
    params := [10]f32{
        (0.5-f32(width)*0.5)*step, (0.5-f32(height)*0.5)*step, step, step,
        sine(yaw+1.57079633), sine(yaw), sine(pitch+1.57079633), sine(pitch), distance, 0.0,
    }
    status := trueos_cabi_ui4_scene_native_compute_render_v2(window, &params[0], 40)
    for status == -7 {
        if trueos_cabi_blueprint_stop_control_v1(1) != 0 do return -3
        trueos_cabi_sleep_ms(16)
        status = trueos_cabi_ui4_scene_native_compute_render_v2(window, &params[0], 40)
    }
    return report("gpu-grid-render", status)
}
