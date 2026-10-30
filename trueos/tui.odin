package main

import "core:fmt"
import "core:strings"
import "core:slice"
import "core:hash"
import os "platform"

foreign _ {
    trueos_cabi_shell_attached_write :: proc "c" (data: rawptr, size: uintptr) -> uintptr ---
    trueos_cabi_shell_attached_read_byte :: proc "c" () -> i32 ---
    trueos_cabi_sleep_ms :: proc "c" (ms: u64) ---
    trueos_cabi_blueprint_terminal_lease_current_v1 :: proc "c" (ready_epoch: u64, epoch: ^u64) -> i32 ---
    trueos_cabi_blueprint_terminal_lease_release_v1 :: proc "c" (epoch: u64, ticket: ^u64) -> i32 ---
    trueos_cabi_blueprint_terminal_surface_snapshot_v1 :: proc "c" (generation: ^u64, cols, rows: ^u32) -> i32 ---
}

Tui_Demo :: struct { name: string, built: bool }
tui_messages: [8][160]u8
tui_lengths: [8]int
tui_message_count: int

tui_capture :: proc(stream: u32, text: string) {
    for byte in transmute([]u8)text {
        row := tui_message_count % len(tui_messages)
        if byte == '\n' {
            tui_message_count += 1
            tui_lengths[tui_message_count % len(tui_messages)] = 0
        } else if byte >= 32 && byte != 127 && tui_lengths[row] < len(tui_messages[row]) {
            tui_messages[row][tui_lengths[row]] = byte
            tui_lengths[row] += 1
        }
    }
}

tui_emit :: proc(text: string) -> bool {
    offset := 0
    for offset < len(text) {
        n := trueos_cabi_shell_attached_write(raw_data(text[offset:]), uintptr(len(text)-offset))
        if n == 0 || n > uintptr(len(text)-offset) do return false
        offset += int(n)
    }
    return true
}

tui_seed :: proc() -> bool {
    names := [12]string{"cpu-boids", "hello", "gpu-tests", "gpu-tests", "mandelbrot_gpu_cpu", "mandelbrot_gpu_cpu", "mandelbrot_gpu_poc", "mandelbrot_gpu_poc", "mandelbrot_gpu_poc", "water_light", "water_light", "water_light"}
    files := [12]string{"main.odin", "main.odin", "main.odin", "cases.odin", "main.odin", "shader.odin.source", "main.odin", "render.odin", "shader.poc.odin.source", "main.odin", "field.odin", "optics.odin"}
    sources := [12]string{EMBEDDED_BOIDS, #load("hello.source", string), #load("gpu-main.source", string), #load("gpu-cases.source", string), #load("mandelbrot-main.source", string), #load("mandelbrot-shader.source", string), #load("mandelbrot-poc-main.source", string), #load("mandelbrot-poc-render.source", string), #load("mandelbrot-poc-shader.source", string), #load("water-light-main.source", string), #load("water-light-field.source", string), #load("water-light-optics.source", string)}
    for name, i in names {
        path := strings.concatenate({name, "/", files[i]})
        baseline := strings.concatenate({".odin-son-seeds/", path})
        baseline_dir := strings.concatenate({".odin-son-seeds/", name})
        defer {delete(path); delete(baseline); delete(baseline_dir)}
        replace := true
        if _, err := os.stat(path); err == nil {
            previous, err := os.read_entire_file(path)
            if err != nil do return false
            prior_seed, prior_err := os.read_entire_file(baseline)
            replace = prior_err == nil && string(previous) == string(prior_seed)
            delete(prior_seed)
            if name == "mandelbrot_gpu_cpu" && files[i] == "main.odin" && prior_err != nil {
                // These releases predate seed baselines; only migrate their exact bundled sources.
                fingerprint := hash.fnv64a(previous)
                replace = (len(previous) == 4538 && fingerprint == 0x14879123a510ed80) || (len(previous) == 6206 && fingerprint == 0x3dc328232cfaaf57)
            }
            delete(previous)
        }
        if replace {
            if os.create_dir_all(name) != nil do return false
            if os.write_entire_file(path, transmute([]u8)sources[i]) != nil do return false
        }
        if os.create_dir_all(baseline_dir) != nil do return false
        if os.write_entire_file(baseline, transmute([]u8)sources[i]) != nil do return false
    }
    return true
}

tui_free_demos :: proc(demos: []Tui_Demo) {
    for demo in demos do delete(demo.name)
    delete(demos)
}

tui_discover :: proc(announce := true) -> ([]Tui_Demo, bool) {
    demos := make([dynamic]Tui_Demo)
    entries, err := os.read_dir(".", -1)
    if err != nil do return demos[:], false
    defer {
        for entry in entries { delete(entry.name); delete(entry.fullpath) }
        delete(entries)
    }
    for entry in entries {
        if entry.type != .Directory || strings.has_prefix(entry.name, ".") do continue
        // Output stays a local basename, matching the scoped Blueprint launcher.
        safe := len(entry.name) > 0 && len(entry.name) <= 64
        for ch in entry.name {
            if !((ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || (ch >= '0' && ch <= '9') || ch == '-' || ch == '_') do safe = false
        }
        if !safe do continue
        path := strings.concatenate({entry.name, "/main.odin"})
        defer delete(path)
        info, err := os.stat(path)
        if err == nil && info.kind == 1 do append(&demos, Tui_Demo{name = strings.clone(entry.name)})
    }
    slice.sort_by(demos[:], proc(a, b: Tui_Demo) -> bool { return a.name < b.name })
    if announce do fmt.printfln("[odin-son tui] stage=discovery demos=%d root=apps/odin-son", len(demos))
    return demos[:], true
}

tui_refresh :: proc(demos: ^[]Tui_Demo, selected: ^int, force := false) -> bool {
    fresh, found := tui_discover(false)
    if !found { tui_free_demos(fresh); return false }
    changed := len(fresh) != len(demos^)
    if !changed {
        for demo, i in fresh { if demo.name != demos^[i].name do changed = true }
    }
    if !changed { tui_free_demos(fresh); return force }
    selection := ""
    if len(demos^) > 0 do selection = demos^[selected^].name
    new_selection := 0
    for &demo, i in fresh {
        for old in demos^ { if old.name == demo.name do demo.built = old.built }
        if demo.name == selection do new_selection = i
    }
    tui_free_demos(demos^)
    demos^ = fresh
    selected^ = new_selection
    fmt.printfln("[odin-son tui] stage=discovery demos=%d root=apps/odin-son", len(fresh))
    return true
}

tui_line :: proc(b: ^strings.Builder, row, cols: int, text: string, style := "\x1b[0m") {
    fmt.sbprintf(b, "\x1b[%d;1H%s\x1b[2K", row+1, style)
    for byte, i in transmute([]u8)text {
        if i >= cols-1 do break
        if byte >= 32 && byte < 127 do strings.write_byte(b, byte)
    }
}

tui_draw :: proc(demos: []Tui_Demo, selected, cols, rows: int, status: string) -> bool {
    b: strings.Builder
    strings.builder_init(&b)
    defer strings.builder_destroy(&b)
    strings.write_string(&b, "\x1b[?1049h\x1b[?25l\x1b[0m\x1b[2J")
    tui_line(&b, 0, cols, "ODIN-SON  native compiler", "\x1b[48;2;16;16;16m\x1b[38;2;255;55;255m\x1b[1m")
    help := "Up/Down j/k select  Enter compile  r run  f refresh  q quit"
    tui_line(&b, 1, cols, help, "\x1b[0m\x1b[48;2;16;16;16m")
    tui_line(&b, 2, cols, status, "\x1b[0m\x1b[48;2;16;16;16m\x1b[38;2;180;180;180m")
    visible := max(1, rows-15)
    first := max(0, selected-visible+1)
    for i := first; i < min(len(demos), first+visible); i += 1 {
        visual := demos[i].name == "mandelbrot_gpu_cpu" || demos[i].name == "mandelbrot_gpu_poc" || demos[i].name == "water_light"
        profile := demos[i].name == "mandelbrot_gpu_poc" ? "  [3D Mandelbox]" : demos[i].name == "water_light" ? "  [D2Q9 + caustics]" : ""
        label := fmt.aprintf("%s %s%s%s%s", i == selected ? ">" : " ", demos[i].name, profile, demos[i].built ? "  [compiled]" : "", visual ? "  [Enter: compile + run]" : "")
        tui_line(&b, 4+i-first, cols, label, i == selected ? "\x1b[0m\x1b[38;2;255;55;255m" : "\x1b[0m")
        delete(label)
    }
    log_row := 6+min(len(demos), visible)
    tui_line(&b, log_row, cols, "Latest compiler output", "\x1b[0m\x1b[90m")
    first_message := max(0, tui_message_count-7)
    for i := first_message; i <= tui_message_count; i += 1 {
        row := log_row+1+i-first_message
        if row >= rows-2 do break
        slot := i % len(tui_messages)
        tui_line(&b, row, cols, string(tui_messages[slot][:tui_lengths[slot]]))
    }
    footer := "Auto-discovers apps/odin-son/<demo>/main.odin.  TAB parks; tui returns."
    tui_line(&b, rows-1, cols, footer, "\x1b[0m\x1b[90m")
    strings.write_string(&b, "\x1b[0m")
    return tui_emit(strings.to_string(b))
}

tui_compile :: proc(name: string) -> i32 {
    shader := strings.concatenate({name, "/shader.odin.source"})
    poc_shader := strings.concatenate({name, "/shader.poc.odin.source"})
    defer {delete(shader); delete(poc_shader)}
    has_shader := false
    has_poc := false
    if _, err := os.stat(poc_shader); err == nil do has_poc = true
    if _, err := os.stat(shader); err == nil {
        if has_poc {fmt.eprintln("choose one shader backend per example directory"); return 1}
        has_shader = true
        if result := tui_compile_pixel(name, shader); result != 0 do return result
    } else if has_poc {
        if result := tui_compile_pixel(name, poc_shader, true); result != 0 do return result
    }
    input := strings.concatenate({name, "/main.odin"})
    output := strings.concatenate({"demo-", name, ".o"})
    // Keep field stages as calls instead of duplicating them into the UI loop.
    optimization := name == "water_light" ? cstring("-o:all") : cstring("-o:aggresive")
    args := [7]cstring{cstring("odin-son"), cstring("--cpu-boids"), cstring("--blueprint"), strings.clone_to_cstring(input), cstring("-o"), strings.clone_to_cstring(output), optimization}
    defer { delete(input); delete(output); delete(args[3]); delete(args[5]) }
    result := run_compiler(len(args), raw_data(args[:]))
    if result == 0 && has_shader do fmt.printfln("odin-son: CPU + Intel Xe-LP GPU compiled from source for %s", name)
    if result == 0 && has_poc do fmt.printfln("odin-son: CPU + intel_xelp_poc complete GPU kernel compiled from source for %s", name)
    return result
}

tui_compile_pixel :: proc(name, source: string, poc := false) -> i32 {
    binary := strings.concatenate({name, "/shader.eu"})
    kernel := strings.concatenate({name, "/kernel.odin"})
    flag := cstring("--gpu-pixel")
    if poc do flag = cstring("--gpu-poc")
    args := [5]cstring{cstring("odin-son"), flag, strings.clone_to_cstring(source), cstring("-o"), strings.clone_to_cstring(binary)}
    defer {delete(binary); delete(kernel); delete(args[2]); delete(args[4])}
    result := run_compiler(len(args), raw_data(args[:]))
    if result != 0 do return result
    code, err := os.read_entire_file(binary)
    if err != nil do return 1
    defer delete(code)
    builder: strings.Builder
    strings.builder_init(&builder)
    defer strings.builder_destroy(&builder)
    strings.write_string(&builder, "package main\n\nnative_pixel_code :: \"")
    for byte in code do fmt.sbprintf(&builder, "\\x%02x", byte)
    strings.write_string(&builder, "\"\n")
    if os.write_entire_file(kernel, transmute([]u8)strings.to_string(builder)) != nil do return 1
    return 0
}

tui_run :: proc(name: string) -> i32 {
    source := strings.concatenate({"demo-", name, ".bp"})
    destination := strings.concatenate({"common/odin-son/demo-", name, ".bp"})
    defer { delete(source); delete(destination) }
    bytes, err := os.read_entire_file(source)
    if err != nil do return -1
    defer delete(bytes)
    // Path-based child launches are restricted to the existing shared export.
    if os.create_dir_all("common/odin-son") != nil do return -1
    if os.write_entire_file(destination, bytes) != nil do return -1
    payload := strings.concatenate({"./", destination, "\x00\x00headless"})
    defer delete(payload)
    return trueos_cabi_blueprint_launch_script_v1(raw_data(payload), uintptr(len(payload)))
}

run_mandelbrot_demo :: proc(name := "mandelbrot_gpu_cpu") -> i32 {
    if !tui_seed() do return 1
    result := tui_compile(name)
    if result != 0 do return result
    return tui_run(name)
}

run_tui :: proc() -> i32 {
    epoch: u64
    if trueos_cabi_blueprint_terminal_lease_current_v1(0, &epoch) != 0 {
        fmt.eprintln("odin-son: TUI needs a terminal; pass a source path or --cpu-boids for batch compilation")
        return 1
    }
    defer {
        tui_emit("\x1b[0m\x1b[?25h\x1b[?1049l")
        ticket: u64
        trueos_cabi_blueprint_terminal_lease_release_v1(epoch, &ticket)
    }
    fmt.trueos_sink = tui_capture
    defer { fmt.trueos_sink = nil }
    status := "Ready. Select a demo and press Enter to compile."
    if !tui_seed() do status = "Could not seed demos; existing sources are still available."
    demos, ok := tui_discover()
    defer tui_free_demos(demos)
    if !ok do status = "Cannot list app directory. Press f to retry."
    selected := 0
    dirty := true
    generation: u64
    last_cols, last_rows: u32
    escape := 0
    refresh_ticks := 0
    for trueos_cabi_blueprint_stop_control_v1(1) == 0 {
        observed: u64
        cols, rows: u32
        if trueos_cabi_blueprint_terminal_surface_snapshot_v1(&observed, &cols, &rows) != 0 {
            dirty = true
            trueos_cabi_sleep_ms(25)
            continue
        }
        if trueos_cabi_blueprint_terminal_lease_current_v1(0, &epoch) != 0 do continue
        if observed != generation || cols != last_cols || rows != last_rows {
            generation, last_cols, last_rows = observed, cols, rows
            dirty = true
        }
        if dirty && cols >= 20 && rows >= 8 {
            if !tui_draw(demos, selected, int(cols), int(rows), status) do break
            trueos_cabi_blueprint_terminal_lease_current_v1(epoch, &observed)
            dirty = false
        }
        key := trueos_cabi_shell_attached_read_byte()
        if key < 0 {
            refresh_ticks += 1
            if refresh_ticks >= 100 {
                refresh_ticks = 0
                if tui_refresh(&demos, &selected) do dirty = true
            }
            trueos_cabi_sleep_ms(20)
            continue
        }
        if key == 27 { escape = 1; continue }
        if escape == 1 { escape = key == '[' ? 2 : 0; continue }
        if escape == 2 {
            escape = 0
            if key == 'A' do key = 'k'
            else if key == 'B' do key = 'j'
            else do continue
        }
        switch key {
        case 'q', 'Q', 3: return 0
        case 'j': if len(demos) > 0 do selected = (selected+1)%len(demos)
        case 'k': if len(demos) > 0 do selected = (selected+len(demos)-1)%len(demos)
        case 'f', 'F':
            if tui_refresh(&demos, &selected, true) { status = "Demo list refreshed." }
            else { status = "Cannot list app directory." }
        case 10, 13:
            if len(demos) == 0 do continue
            status = "Compiling selected demo..."
            tui_draw(demos, selected, int(cols), int(rows), status)
            tui_message_count = 0
            tui_lengths = {}
            result := tui_compile(demos[selected].name)
            demos[selected].built = result == 0
            status = result == 0 ? "Compiled. Press r to queue the demo in its own VM." : "Compile failed. Fix the source and try again."
            fmt.printfln("[odin-son tui] stage=compile demo=%s status=%d", demos[selected].name, result)
            if result == 0 && (demos[selected].name == "mandelbrot_gpu_cpu" || demos[selected].name == "mandelbrot_gpu_poc" || demos[selected].name == "water_light") {
                result = tui_run(demos[selected].name)
                hint := demos[selected].name == "mandelbrot_gpu_poc" ? "Mandelbox launch queued. Drag orbit; wheel dolly; R resets; Q/Escape quits demo." : "Mandelbrot launch queued. Wheel zoom; drag pan; Q/Escape quits demo."
                if demos[selected].name == "water_light" do hint = "Water light queued. Drag ripples; Space pause; V field; R reset; Q/Escape quits."
                status = result == 0 ? hint : "Compiled; launch request failed. Press r to retry."
                fmt.printfln("[odin-son tui] stage=launch demo=%s status=%d", demos[selected].name, result)
            }
        case 'r', 'R':
            if len(demos) == 0 do continue
            if !demos[selected].built { status = "Compile this demo first (Enter)."; break }
            result := tui_run(demos[selected].name)
            status = result == 0 ? "Launch queued in its own VM. Compiler stays ready." : "Launch request failed; see system log."
            fmt.printfln("[odin-son tui] stage=launch demo=%s status=%d", demos[selected].name, result)
        }
        dirty = true
    }
    return 0
}
