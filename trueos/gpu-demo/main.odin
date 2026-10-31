package main

foreign _ {
    trueos_cabi_write :: proc(stream: u32, bytes: ^u8, size: uintptr) ---
    trueos_cabi_blueprint_stop_control_v1 :: proc(op: u32) -> i32 ---
    trueos_cabi_blueprint_shutdown :: proc(data: [^]u8, size: uintptr) -> i32 ---
    trueos_cabi_ui4_scene_frame_open_visual :: proc(x: i32, y: i32, width: u32, height: u32, hz: u32) -> u32 ---
    trueos_cabi_ui4_scene_native_compute_upload_v1 :: proc(window: u32, offset: u32, total: u32, bytes: ^u8, size: uintptr) -> i32 ---
    trueos_cabi_ui4_scene_native_compute_dispatch_v1 :: proc(window: u32, inputs: ^u32, registers: u32, out: ^u32) -> i32 ---
    trueos_cabi_ui4_solara_frame_close :: proc(window: u32) -> i32 ---
}

GPU_Case :: struct {
    name: string,
    code: []u8,
    sha256: string,
    boolean: bool,
    inputs: [2][8]u32,
    expected: [8]u32,
}

outbuf: [1024]u8
outlen: int

emit :: proc(text: string) {
    for i := 0; i < len(text); i += 1 {
        outbuf[outlen] = text[i]
        outlen += 1
    }
}

number :: proc(value: u64) {
    digits: [20]u8
    n := value
    used := 0
    for {
        digits[used] = u8(n % 10) + 48
        used += 1
        n /= 10
        if n == 0 do break
    }
    for used > 0 {
        used -= 1
        outbuf[outlen] = digits[used]
        outlen += 1
    }
}

hex :: proc(value: u64) {
    alphabet := "0123456789abcdef"
    shift := 60
    for {
        outbuf[outlen] = alphabet[int((value >> uint(shift)) & 15)]
        outlen += 1
        if shift == 0 do break
        shift -= 4
    }
}

line :: proc() {
    outbuf[outlen] = 10
    outlen += 1
    trueos_cabi_write(1, &outbuf[0], uintptr(outlen))
    outlen = 0
}

arg_is :: proc(arg: [^]u8, expected: string) -> bool {
    for i := 0; i < len(expected); i += 1 { if arg[i] != expected[i] do return false }
    return arg[len(expected)] == 0
}

main :: proc(argc: uintptr, argv: [^][^]u8) -> i32 {
    if argc > 2 do return 1
    if argc == 2 && !arg_is(argv[1], "--gpu-tests") do return 1
    if trueos_cabi_blueprint_stop_control_v1(0) != 0 do return 1
    window := trueos_cabi_ui4_scene_frame_open_visual(32, 32, 32, 32, 1)
    if window == 0 { emit("odin-gpu-tests: cannot open native compute owner"); line(); return finish(1) }
    status := run_tests(window)
    close_status := trueos_cabi_ui4_solara_frame_close(window)
    if close_status != 0 { emit("odin-gpu-tests: owner close failed"); line(); status = 1 }
    return finish(status)
}

finish :: proc(status: i32) -> i32 {
    reason := "Odin SON GPU tests finished"
    trueos_cabi_blueprint_shutdown(raw_data(reason), uintptr(len(reason)))
    return status
}

run_tests :: proc(window: u32) -> i32 {
    emit("ODIN SON GPU TESTS: runner=odin-son shaders=odin-son; one SIMD8 dispatch per case"); line()
    emit("case                            result lanes actual-checksum  expected-checksum"); line()
    passed, failed, skipped := 0, 0, 0
    stopped := false
    for index := 0; index < 5; index += 1 {
        test: GPU_Case
        get_case(index, &test)
        if stopped || trueos_cabi_blueprint_stop_control_v1(1) != 0 {
            skipped += 1
            emit(test.name); emit(" SKIP"); line()
            continue
        }
        emit("odin-gpu-tests: artifact="); emit(test.name); emit(" bytes="); number(u64(len(test.code)))
        emit(" sha256="); emit(test.sha256); line()
        status := i32(0)
        for offset := 0; offset < len(test.code); offset += 2048 {
            count := len(test.code)-offset
            if count > 2048 do count = 2048
            status = trueos_cabi_ui4_scene_native_compute_upload_v1(window, u32(offset), u32(len(test.code)), &test.code[offset], uintptr(count))
            if status != 0 do break
        }
        actual: [8]u32
        if status == 0 {
            status = trueos_cabi_ui4_scene_native_compute_dispatch_v1(window, &test.inputs[0][0], 2, &actual[0])
        }
        if status != 0 {
            emit(test.name); emit(" ERROR errno=")
            if status < 0 { emit("-"); number(u64(-status)) } else { number(u64(status)) }
            line()
            failed += 1
            stopped = true
            continue
        }
        lanes := 0
        for bits, i in actual {
            equal := bits == test.expected[i]
            if !test.boolean do equal = equal || transmute(f32)bits == transmute(f32)test.expected[i]
            if equal do lanes += 1
        }
        emit(test.name)
        for padding := len(test.name); padding < 32; padding += 1 do emit(" ")
        if lanes == 8 { emit("PASS "); passed += 1 } else { emit("FAIL "); failed += 1 }
        number(u64(lanes)); emit("/8 "); hex(checksum(actual)); emit(" "); hex(checksum(test.expected)); line()
    }
    emit("odin-gpu-tests: passed="); number(u64(passed)); emit(" failed="); number(u64(failed))
    emit(" skipped="); number(u64(skipped)); emit(" total=5"); line()
    if failed == 0 && skipped == 0 do return 0
    return 1
}

checksum :: proc(lanes: [8]u32) -> u64 {
    hash := u64(0xcbf29ce484222325)
    for bits in lanes {
        for shift := 0; shift < 4; shift += 1 { hash = (hash ~ u64((bits >> uint(shift*8)) & 255))*0x100000001b3 }
    }
    return hash
}
