package main

foreign _ {
    trueos_cabi_write :: proc(stream: u32, data: ^u8, size: uintptr) ---
    trueos_cabi_sleep_ms :: proc(ms: u64) ---
    trueos_cabi_poll_once :: proc() ---
    trueos_time_monotonic_nanos :: proc() -> u64 ---
    trueos_cabi_blueprint_stop_control_v1 :: proc(op: u32) -> i32 ---
    trueos_cabi_blueprint_shutdown :: proc(data: [^]u8, size: uintptr) -> i32 ---
    trueos_cabi_shell_attached_read_byte :: proc() -> i32 ---
    trueos_cabi_matrix_compute_capacity_v1 :: proc() -> u32 ---
    trueos_cabi_matrix_compute_v1 :: proc(code: [^]u8, code_len: uintptr, input: ^u32, n: u32, saturate: u32, rounds: u32, output: ^u32) -> i32 ---
    trueos_cabi_calloc :: proc(count, size: uintptr) -> uintptr ---
    trueos_cabi_free :: proc(data: uintptr) ---
    trueos_cabi_thread_spawn :: proc(stack: uintptr, start: proc(data: uintptr) -> uintptr, data: uintptr, handle: ^uintptr) -> i32 ---
    trueos_cabi_thread_join :: proc(handle: uintptr) -> i32 ---
    pthread_mutex_init :: proc(mutex: ^u64, attr: uintptr) -> i32 ---
    pthread_mutex_lock :: proc(mutex: ^u64) -> i32 ---
    pthread_mutex_unlock :: proc(mutex: ^u64) -> i32 ---
    pthread_mutex_destroy :: proc(mutex: ^u64) -> i32 ---
}

Worker :: struct {
    index: int,
    seed: u32,
    batches: u64,
    input: [16384]u32,
    scratch: [16384]u32,
    history: [4][16384]u32,
}

mutex: [8]u64
workers: [64]^Worker
handles: [64]uintptr
capacity: int
split := 50
mode := 2
dimension := 64
rounds := 4
duration: u64
stopping: bool
cpu_squares: [2]u64
gpu_squares: [2]u64
cpu_hash: u32
gpu_hash: u32
overwritten: u64
last_cpu: u64
last_gpu: u64
last_report: u64
outbuf: [1024]u8
outlen: int

emit :: proc(text: string) {
    for i := 0; i < len(text); i += 1 { outbuf[outlen] = text[i]; outlen += 1 }
}

number :: proc(value: u64) {
    digits: [20]u8
    n, used := value, 0
    for {
        digits[used] = u8(n % 10) + 48
        used += 1
        n /= 10
        if n == 0 do break
    }
    for used > 0 { used -= 1; outbuf[outlen] = digits[used]; outlen += 1 }
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

parse_number :: proc(arg: [^]u8) -> int {
    value := 0
    for i := 0; i < 10; i += 1 {
        c := arg[i]
        if c == 0 { if i == 0 do return -1; return value }
        if c < 48 || c > 57 do return -1
        value = value * 10 + int(c - 48)
        if value > 86400 do return -1
    }
    return -1
}

fill :: proc(pointer: ^u32, count: int, seed: ^u32) {
    data := ([^]u32)(pointer)
    state := seed^
    for i := 0; i < count; i += 1 {
        state = state ~ (state << 13)
        state = state ~ (state >> 17)
        state = state ~ (state << 5)
        data[i] = state
    }
    seed^ = state
}

square :: proc(input_pointer, output_pointer: ^u32, n, saturate: int) {
    output := ([^]u32)(output_pointer)
    for row := 0; row < n; row += 1 {
        for col := 0; col < n; col += 1 {
            output[row*n+col] = dot(input_pointer, row, col, n, saturate)
        }
        // Native CPU continuations must yield so stop and unrelated executor work can progress.
        trueos_cabi_poll_once()
    }
}

digest :: proc(pointer: ^u32, count: int) -> u32 {
    data := ([^]u32)(pointer)
    hash := u32(2166136261)
    for i := 0; i < count; i += 1 { hash = (hash ~ data[i]) * 16777619 }
    return hash
}

worker :: proc(data: uintptr) -> uintptr {
    work := (^Worker)(data)
    for {
        pthread_mutex_lock(&mutex[0])
        stop := stopping
        active := (capacity * split + 99) / 100
        selected_mode := mode
        pthread_mutex_unlock(&mutex[0])
        if stop do break
        if work.index >= active { trueos_cabi_sleep_ms(20); continue }
        arithmetic := selected_mode
        if arithmetic == 2 do arithmetic = int(work.batches & 1)
        fill(&work.input[0], dimension*dimension, &work.seed)
        source: ^u32 = &work.input[0]
        destination: ^u32 = &work.scratch[0]
        for iteration := 0; iteration < rounds; iteration += 1 {
            square(source, destination, dimension, arithmetic)
            previous := source
            source = destination
            destination = previous
        }
        slot := int(work.batches & 3)
        for i := 0; i < dimension*dimension; i += 1 do work.history[slot][i] = ([^]u32)(source)[i]
        hash := digest(&work.history[slot][0], dimension*dimension)
        pthread_mutex_lock(&mutex[0])
        cpu_squares[arithmetic] += u64(rounds)
        cpu_hash = cpu_hash ~ hash
        if work.batches >= 4 do overwritten += 1
        pthread_mutex_unlock(&mutex[0])
        work.batches += 1
    }
    return 0
}

check :: proc() -> bool {
    input: [64]u32
    expected: [64]u32
    expected_chain: [64]u32
    actual: [64]u32
    input[0] = 1; input[1] = 2; input[2] = 3; input[3] = 4
    square(&input[0], &expected[0], 2, 0)
    if expected[0] != 7 || expected[1] != 10 || expected[2] != 15 || expected[3] != 22 do return false
    seed := u32(0x9e3779b9)
    for fixture := 0; fixture < 3; fixture += 1 {
        n := 2
        if fixture == 1 { for i := 0; i < 4; i += 1 do input[i] = 0xffffffff }
        if fixture == 2 { n = 7; fill(&input[0], n*n, &seed) }
        for arithmetic := 0; arithmetic < 2; arithmetic += 1 {
            square(&input[0], &expected[0], n, arithmetic)
            rc := trueos_cabi_matrix_compute_v1(raw_data(mac_code), uintptr(len(mac_code)), &input[0], u32(n), u32(arithmetic), 1, &actual[0])
            if rc != 0 {
                emit("matrix: GPU check failed errno=")
                if rc < 0 { emit("-"); number(u64(-rc)) } else { number(u64(rc)) }
                line()
                return false
            }
            for i := 0; i < n*n; i += 1 { if actual[i] != expected[i] do return false }
            square(&expected[0], &expected_chain[0], n, arithmetic)
            rc = trueos_cabi_matrix_compute_v1(raw_data(mac_code), uintptr(len(mac_code)), &input[0], u32(n), u32(arithmetic), 2, &actual[0])
            if rc != 0 do return false
            for i := 0; i < n*n; i += 1 { if actual[i] != expected_chain[i] do return false }
        }
    }
    return true
}

heartbeat :: proc() {
    pthread_mutex_lock(&mutex[0])
    cw, cs := cpu_squares[0], cpu_squares[1]
    gw, gs := gpu_squares[0], gpu_squares[1]
    lost := overwritten
    ch, gh := cpu_hash, gpu_hash
    share, arithmetic := split, mode
    pthread_mutex_unlock(&mutex[0])
    now := trueos_time_monotonic_nanos()
    elapsed_ms := (now-last_report)/1000000
    if elapsed_ms == 0 do elapsed_ms = 1
    cpu_rate := (cw+cs-last_cpu)*1000/elapsed_ms
    gpu_rate := (gw+gs-last_gpu)*1000/elapsed_ms
    last_cpu = cw+cs
    last_gpu = gw+gs
    last_report = now
    emit("matrix: n="); number(u64(dimension)); emit(" split="); number(u64(share))
    emit(" mode="); if arithmetic == 0 { emit("wrap") } else if arithmetic == 1 { emit("sat") } else { emit("both") }
    emit(" cpu[w,s]="); number(cw); emit(","); number(cs)
    emit(" gpu[w,s]="); number(gw); emit(","); number(gs)
    emit(" squares/s[c,g]="); number(cpu_rate); emit(","); number(gpu_rate)
    emit(" history-overwritten="); number(lost)
    emit(" checksum[c,g]="); number(u64(ch)); emit(","); number(u64(gh)); line()
}

main :: proc(argc: uintptr, argv: [^][^]u8) -> i32 {
    for i := uintptr(1); i < argc; i += 1 {
        if arg_is(argv[i], "--help") {
            emit("odin-matrix [--n 1..128] [--split 0..100] [--mode wrap|sat|both] [--rounds 1..4] [--seconds 1..86400]"); line()
            emit("Keys: +/- CPU share, w wrap, s saturation, b alternate both, q stop. Default: n=64 split=50 mode=both rounds=4, continuous."); line()
            return 0
        }
        if i+1 >= argc do return 2
        option := argv[i]
        i += 1
        if arg_is(option, "--mode") {
            if arg_is(argv[i], "wrap") { mode = 0 } else if arg_is(argv[i], "sat") { mode = 1 } else if arg_is(argv[i], "both") { mode = 2 } else { return 2 }
            continue
        }
        value := parse_number(argv[i])
        if value < 0 do return 2
        if arg_is(option, "--n") { if value < 1 || value > 128 do return 2; dimension = value; continue }
        if arg_is(option, "--split") { if value > 100 do return 2; split = value; continue }
        if arg_is(option, "--rounds") { if value < 1 || value > 4 do return 2; rounds = value; continue }
        if arg_is(option, "--seconds") { if value < 1 do return 2; duration = u64(value); continue }
        return 2
    }
    if trueos_cabi_blueprint_stop_control_v1(0) != 0 do return 1
    if pthread_mutex_init(&mutex[0], 0) != 0 do return 1
    if !check() { emit("matrix: correctness check failed; stress not started"); line(); pthread_mutex_destroy(&mutex[0]); return finish(1) }
    emit("matrix: CPU/GPU checks passed, including [[1,2],[3,4]] squared = [[7,10],[15,22]], overflow, and N=7 tails"); line()
    capacity = int(trueos_cabi_matrix_compute_capacity_v1())
    if capacity > 64 do capacity = 64
    if capacity == 0 && split > 0 {
        emit("matrix: no eligible CPU carriers; CPU share cannot be admitted"); line()
        pthread_mutex_destroy(&mutex[0])
        return finish(1)
    }
    emit("matrix: CPU carriers="); number(u64(capacity)); emit(" gpu=SIMD8; +/- split, w/s/b mode, q stop"); line()
    launched := 0
    status := i32(0)
    for i := 0; i < capacity; i += 1 {
        workers[i] = (^Worker)(trueos_cabi_calloc(1, size_of(Worker)))
        if uintptr(workers[i]) == 0 { status = 1; break }
        workers[i].index = i
        workers[i].seed = u32(i+1) * 0x9e3779b9
        rc := trueos_cabi_thread_spawn(131072, worker, uintptr(workers[i]), &handles[i])
        if rc != 0 { trueos_cabi_free(uintptr(workers[i])); workers[i] = (^Worker)(uintptr(0)); status = 1; break }
        launched += 1
    }
    gpu := (^Worker)(trueos_cabi_calloc(1, size_of(Worker)))
    if uintptr(gpu) == 0 do status = 1
    if uintptr(gpu) != 0 do gpu.seed = 0x12345678
    start := trueos_time_monotonic_nanos()
    last_report = start
    last_beat := start
    next_gpu := start
    for status == 0 {
        now := trueos_time_monotonic_nanos()
        if trueos_cabi_blueprint_stop_control_v1(1) != 0 do break
        if duration != 0 && now-start >= duration*1000000000 do break
        key := trueos_cabi_shell_attached_read_byte()
        if key == 113 do break
        pthread_mutex_lock(&mutex[0])
        if key == 43 || key == 61 { split += 5; if split > 100 do split = 100 }
        if key == 45 { split -= 5; if split < 0 do split = 0 }
        if key == 119 do mode = 0
        if key == 115 do mode = 1
        if key == 98 do mode = 2
        if capacity == 0 do split = 0
        share := 100-split
        arithmetic := mode
        pthread_mutex_unlock(&mutex[0])
        if now-last_beat >= 1000000000 { heartbeat(); last_beat = now }
        if share == 0 || now < next_gpu { trueos_cabi_sleep_ms(1); continue }
        if arithmetic == 2 do arithmetic = int(gpu.batches & 1)
        fill(&gpu.input[0], dimension*dimension, &gpu.seed)
        slot := int(gpu.batches & 3)
        began := trueos_time_monotonic_nanos()
        rc := trueos_cabi_matrix_compute_v1(raw_data(mac_code), uintptr(len(mac_code)), &gpu.input[0], u32(dimension), u32(arithmetic), u32(rounds), &gpu.history[slot][0])
        ended := trueos_time_monotonic_nanos()
        if rc != 0 { emit("matrix: GPU dispatch error "); if rc < 0 do emit("-"); if rc < 0 { number(u64(-rc)) } else { number(u64(rc)) }; line(); status = 1; break }
        hash := digest(&gpu.history[slot][0], dimension*dimension)
        pthread_mutex_lock(&mutex[0])
        gpu_squares[arithmetic] += u64(rounds)
        gpu_hash = gpu_hash ~ hash
        if gpu.batches >= 4 do overwritten += 1
        pthread_mutex_unlock(&mutex[0])
        gpu.batches += 1
        next_gpu = ended + (ended-began)*u64(100-share)/u64(share)
        trueos_cabi_poll_once()
    }
    pthread_mutex_lock(&mutex[0])
    stopping = true
    pthread_mutex_unlock(&mutex[0])
    joined := true
    for i := 0; i < launched; i += 1 {
        if trueos_cabi_thread_join(handles[i]) != 0 { status = 1; joined = false } else { trueos_cabi_free(uintptr(workers[i])) }
    }
    if uintptr(gpu) != 0 do trueos_cabi_free(uintptr(gpu))
    heartbeat()
    if joined do pthread_mutex_destroy(&mutex[0])
    return finish(status)
}

finish :: proc(status: i32) -> i32 {
    reason := "Odin matrix demo finished"
    trueos_cabi_blueprint_shutdown(raw_data(reason), uintptr(len(reason)))
    return status
}

mac_cpu :: proc(a, b, accumulator: u32, saturate: int) -> u32 {
    wide := u64(a)*u64(b)+u64(accumulator)
    if saturate != 0 { if wide > 0xffffffff do return 0xffffffff }
    return u32(wide)
}

// COMPILER BUG: three nested loops make bac/graph's peephole verifier return its own If node.
// for row := 0; row < n; row += 1 { for col := 0; col < n; col += 1 { for k := 0; k < n; k += 1 { accumulator = mac_cpu(input[row*n+k], input[k*n+col], accumulator, saturate) } } }
dot :: proc(pointer: ^u32, row, col, n, saturate: int) -> u32 {
    input := ([^]u32)(pointer)
    accumulator := u32(0)
    for k := 0; k < n; k += 1 {
        accumulator = mac_cpu(input[row*n+k], input[k*n+col], accumulator, saturate)
    }
    return accumulator
}
