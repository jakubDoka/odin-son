package main

foreign _ {
	trueos_cabi_shell_attached_write :: proc(data: ^u8, size: uintptr) -> uintptr ---
	trueos_cabi_shell_attached_read_byte :: proc() -> i32 ---
	trueos_cabi_sleep_ms :: proc(ms: u64) ---
	trueos_cabi_blueprint_stop_control_v1 :: proc(operation: u32) -> i32 ---
	trueos_cabi_blueprint_shutdown :: proc(reason: [^]u8, size: uintptr) -> i32 ---
}

@(tag = "gpu")
boids_step :: proc(handle: u64, frame: u64) -> i32 {
	gpu_add_scaled(0, 2, 0.016666667)
	gpu_add_scaled(1, 3, 0.016666667)
	return 0
}

emit :: proc(message: string) {
	count := 0
	data := raw_data(message)
	for {
		if count >= len(message) do break
		n := trueos_cabi_shell_attached_write(&data[count], uintptr(len(message) - count))
		if n == 0 do return
		count += int(n)
	}
}

arg_is :: proc(arg: [^]u8, expected: string) -> bool {
	i := 0
	for {
		if i >= len(expected) do break
		if arg[i] != expected[i] do return false
		i += 1
	}
	return arg[i] == 0
}

main :: proc(argc: uintptr, argv: [^][^]u8) -> i32 {
	if trueos_cabi_blueprint_stop_control_v1(0) != 0 do return 1
	emit("[odin-son gpu-boids] cpu=x86_64 tag=gpu kernel=boids-v1 arena=100000000 format=RGBA8\n")
	handle := phy_create()
	if handle == 0 {
		emit("[odin-son gpu-boids] FAIL create\n")
		return 1
	}
	batch := false
	if argc > 1 {
		if arg_is(argv[1], "--batch") do batch = true
	}
	if !batch do batch = phy_batch_requested()
	frame := u64(0)
	status := i32(0)
	for {
		if trueos_cabi_blueprint_stop_control_v1(1) != 0 do break
		key := trueos_cabi_shell_attached_read_byte()
		if (key == 113) | (key == 27) | (key == 3) do break
		result := boids_step(handle, frame)
		if result == -11 {
			trueos_cabi_sleep_ms(2)
			continue
		}
		if result != 0 {
			emit("[odin-son gpu-boids] FAIL dispatch\n")
			status = 1
			break
		}
		if frame == 0 do emit("[odin-son gpu-boids] PASS first GPU frame published\n")
		frame += 1
		if batch & (frame >= 120) do break
		trueos_cabi_sleep_ms(16)
	}
	if phy_close(handle) != 0 {
		emit("[odin-son gpu-boids] FAIL close\n")
		status = 1
	}
	if status == 0 do emit("[odin-son gpu-boids] PASS lifecycle complete\n")
	reason := "gpu-boids finished"
	trueos_cabi_blueprint_shutdown(raw_data(reason), uintptr(len(reason)))
	return status
}
