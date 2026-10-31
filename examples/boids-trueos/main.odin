package main

foreign _ {
	trueos_cabi_shell_attached_write :: proc(data: ^u8, size: uintptr) -> uintptr ---
	trueos_cabi_shell_attached_read_byte :: proc() -> i32 ---
	trueos_cabi_sleep_ms :: proc(ms: u64) ---
	trueos_cabi_blueprint_stop_control_v1 :: proc(operation: u32) -> i32 ---
	trueos_cabi_blueprint_shutdown :: proc(reason: [^]u8, size: uintptr) -> i32 ---
	trueos_cabi_blueprint_terminal_lease_current_v1 :: proc(ready_epoch: u64, epoch: ^u64) -> i32 ---
	trueos_cabi_blueprint_terminal_lease_release_v1 :: proc(epoch: u64, ticket: ^u64) -> i32 ---
	trueos_cabi_blueprint_terminal_surface_snapshot_v1 :: proc(generation: ^u64, cols: ^u32, rows: ^u32) -> i32 ---
}

W :: 78
H :: 30
GRID :: 2340
N :: 45

BATCH_FRAMES :: 100
SLEEP_MS :: 60

RADIUS2 :: 81.0
SEP_RADIUS2 :: 16.0

SEP_W :: 0.06
ALI_W :: 0.05
COH_W :: 0.006

MAX_SPEED :: 1.1
MIN_SPEED :: 0.35

output_failed: bool
view_w: int
view_h: int

write_bytes :: proc(buf: [^]u8, n: int) {
	written := 0
	for {
		if written >= n do break
		count := trueos_cabi_shell_attached_write(&buf[written], uintptr(n - written))
		if (count == 0) | (count > uintptr(n - written)) {
			output_failed = true
			return
		}
		written += int(count)
	}
}

outbuf: [65536]u8
outlen: int

emit :: proc(s: string) {
	i := 0
	for {
		if i >= len(s) do break
		outbuf[outlen] = s[i]
		outlen += 1
		i += 1
	}
}

emit_char :: proc(c: u8) {
	outbuf[outlen] = c
	outlen += 1
}

flush :: proc() {
	if outlen == 0 do return
	write_bytes(raw_data(outbuf[:]), outlen)
	outlen = 0
}

fsqrt :: proc(x: f64) -> f64 {
	if x <= 0.0 do return 0.0
	g := x
	i := 0
	for {
		if i >= 40 do break
		g = 0.5 * (g + x / g)
		i += 1
	}
	return g
}

rng_state: u64 = 0x053c49e6748fea9b

next_rand :: proc() -> u64 {
	rng_state = rng_state * 6364136223846793005 + 1442695040888963407
	return rng_state
}

rand01 :: proc() -> f64 {
	return f64(next_rand() >> 11) / 9007199254740992.0
}

rand_range :: proc(lo: f64, hi: f64) -> f64 {
	return lo + rand01() * (hi - lo)
}

px: [N]f64
py: [N]f64
vx: [N]f64
vy: [N]f64

init_boids :: proc() {
	i := 0
	for {
		if i >= N do break
		px[i] = rand_range(0.0, f64(view_w))
		py[i] = rand_range(0.0, f64(view_h))
		vx[i] = rand_range(-1.0, 1.0)
		vy[i] = rand_range(-1.0, 1.0)
		i += 1
	}
}

wrap :: proc(v: f64, hi: f64) -> f64 {
	r := v
	for {
		if r >= 0.0 do break
		r += hi
	}
	for {
		if r < hi do break
		r -= hi
	}
	return r
}

acc_sepx: f64
acc_sepy: f64
acc_alix: f64
acc_aliy: f64
acc_cohx: f64
acc_cohy: f64
acc_count: int

scan_neighbors :: proc(i: int) {
	sepx := 0.0
	sepy := 0.0
	alix := 0.0
	aliy := 0.0
	cohx := 0.0
	cohy := 0.0
	count := 0

	j := 0
	for {
		if j >= N do break
		if j != i {
			dx := px[j] - px[i]
			dy := py[j] - py[i]
			d2 := dx * dx + dy * dy
			if (d2 < RADIUS2) & (d2 > 0.0) {
				count += 1
				alix += vx[j]
				aliy += vy[j]
				cohx += px[j]
				cohy += py[j]
				if d2 < SEP_RADIUS2 {
					d := fsqrt(d2)
					sepx -= dx / d
					sepy -= dy / d
				}
			}
		}
		j += 1
	}

	acc_sepx = sepx
	acc_sepy = sepy
	acc_alix = alix
	acc_aliy = aliy
	acc_cohx = cohx
	acc_cohy = cohy
	acc_count = count
}

nvx: [N]f64
nvy: [N]f64

update_velocity :: proc(i: int) {
	scan_neighbors(i)

	nx := vx[i]
	ny := vy[i]

	if acc_count > 0 {
		inv := 1.0 / f64(acc_count)
		alix := acc_alix * inv - vx[i]
		aliy := acc_aliy * inv - vy[i]
		cohx := acc_cohx * inv - px[i]
		cohy := acc_cohy * inv - py[i]

		nx += acc_sepx * SEP_W + alix * ALI_W + cohx * COH_W
		ny += acc_sepy * SEP_W + aliy * ALI_W + cohy * COH_W
	}

	sp := fsqrt(nx * nx + ny * ny)
	if sp > MAX_SPEED {
		s := MAX_SPEED / sp
		nx *= s
		ny *= s
	}
	if (sp < MIN_SPEED) & (sp > 0.0) {
		s := MIN_SPEED / sp
		nx *= s
		ny *= s
	}

	nvx[i] = nx
	nvy[i] = ny
}

step :: proc() {
	i := 0
	for {
		if i >= N do break
		update_velocity(i)
		i += 1
	}

	i = 0
	for {
		if i >= N do break
		vx[i] = nvx[i]
		vy[i] = nvy[i]
		px[i] = wrap(px[i] + vx[i], f64(view_w))
		py[i] = wrap(py[i] + vy[i], f64(view_h))
		i += 1
	}
}

grid: [GRID]u8
col: [GRID]u8

dir_char :: proc(dvx: f64, dvy: f64) -> u8 {
	ax := dvx
	if ax < 0.0 do ax = -ax
	ay := dvy
	if ay < 0.0 do ay = -ay
	if ax >= ay {
		if dvx > 0.0 do return '>'
		return '<'
	}
	if dvy > 0.0 do return 'v'
	return '^'
}

dir_color :: proc(dvx: f64, dvy: f64) -> u8 {
	ax := dvx
	if ax < 0.0 do ax = -ax
	ay := dvy
	if ay < 0.0 do ay = -ay
	if ax >= ay {
		if dvx > 0.0 do return 31
		return 32
	}
	if dvy > 0.0 do return 33
	return 36
}

clear_grid :: proc() {
	i := 0
	for {
		if i >= GRID do break
		grid[i] = ' '
		col[i] = 0
		i += 1
	}
}

plot_boids :: proc() {
	i := 0
	for {
		if i >= N do break
		cx := int(px[i])
		cy := int(py[i])
		if cx < 0 do cx = 0
		if cx >= view_w do cx = view_w - 1
		if cy < 0 do cy = 0
		if cy >= view_h do cy = view_h - 1
		idx := cy * W + cx
		grid[idx] = dir_char(vx[i], vy[i])
		col[idx] = dir_color(vx[i], vy[i])
		i += 1
	}
}

emit_uint :: proc(value: int) {
	if value == 0 {
		emit_char('0')
		return
	}
	tmp: [16]u8 = {}
	v := value
	n := 0
	for {
		if v == 0 do break
		tmp[n] = u8('0' + u8(v % 10))
		v /= 10
		n += 1
	}
	k := 0
	for {
		if k >= n do break
		emit_char(tmp[n - 1 - k])
		k += 1
	}
}

emit_border :: proc() {
	emit_char('+')
	bx := 0
	for {
		if bx >= view_w do break
		emit_char('-')
		bx += 1
	}
	emit("+\n")
}

emit_row :: proc(y: int, use_color: bool) {
	emit_char('|')
	x := 0
	cur_col := u8(0)
	for {
		if x >= view_w do break
		idx := y * W + x
		c := grid[idx]
		if use_color {
			cc := col[idx]
			if cc != cur_col {
				if cc == 0 {
					emit("\x1b[0m")
				} else {
					emit("\x1b[1;")
					emit_uint(int(cc))
					emit_char('m')
				}
				cur_col = cc
			}
		}
		emit_char(c)
		x += 1
	}
	if use_color {
		if cur_col != 0 do emit("\x1b[0m")
	}
	emit("|\n")
}

render :: proc(frame: int, use_color: bool) {
	if use_color {
		emit("\x1b[H")
	} else {
		emit("frame ")
		emit_uint(frame)
		emit_char('\n')
	}

	emit_border()

	y := 0
	for {
		if y >= view_h do break
		emit_row(y, use_color)
		y += 1
	}

	emit_border()

	flush()
}

sum_positions :: proc() -> int {
	s := 0
	i := 0
	for {
		if i >= N do break
		s += int(px[i]) + int(py[i]) * 3
		i += 1
	}
	return s
}

draw_frame :: proc(frame: int, use_color: bool) {
	step()
	clear_grid()
	plot_boids()
	render(frame, use_color)
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

update_surface :: proc() -> bool {
	generation: u64
	cols: u32
	rows: u32
	if trueos_cabi_blueprint_terminal_surface_snapshot_v1(&generation, &cols, &rows) != 0 {
		return false
	}
	if (cols < 4) | (rows < 5) do return false
	view_w = int(cols) - 2
	if view_w > W do view_w = W
	view_h = int(rows) - 4
	if view_h > H do view_h = H
	return true
}

should_stop :: proc() -> bool {
	if trueos_cabi_blueprint_stop_control_v1(1) != 0 do return true
	key := trueos_cabi_shell_attached_read_byte()
	return (key == 3) | (key == 27) | (key == 'q') | output_failed
}

main :: proc(argc: uintptr, argv: [^][^]u8) -> i32 {
	view_w = W
	view_h = H
	batch := false
	i := 1
	for {
		if uintptr(i) >= argc do break
		if !arg_is(argv[i], "--batch") do return 1
		batch = true
		i += 1
	}
	if trueos_cabi_blueprint_stop_control_v1(0) != 0 do return 1

	epoch: u64
	leased := false
	color := false
	status := i32(0)
	if !batch {
		leased = trueos_cabi_blueprint_terminal_lease_current_v1(0, &epoch) == 0
		if leased do color = update_surface()
		if leased & !color {
			emit("boids: terminal surface is unavailable or too small\n")
			status = 1
		}
	}
	init_boids()
	frame := 0
	checksum := 0
	for {
		if status != 0 do break
		if should_stop() do break
		if !color {
			if frame >= BATCH_FRAMES do break
		} else {
			if !update_surface() do break
			emit("\x1b[?25l\x1b[2J")
		}
		draw_frame(frame, color)
		checksum += sum_positions()
		frame += 1
		if color do trueos_cabi_sleep_ms(u64(SLEEP_MS))
	}
	if color do emit("\x1b[0m\x1b[?25h\x1b[H\x1b[2J")
	emit("boids checksum: ")
	emit_uint(checksum % 251)
	emit_char('\n')
	flush()
	if leased {
		ticket: u64
		if trueos_cabi_blueprint_terminal_lease_release_v1(epoch, &ticket) != 0 do status = 1
	}
	reason := "boids finished"
	if trueos_cabi_blueprint_shutdown(raw_data(reason), uintptr(len(reason))) != 0 do status = 1
	if output_failed do return 1
	return status
}
