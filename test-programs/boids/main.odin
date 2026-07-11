package main

// A tiny boids (flocking) simulation rendered into the terminal with ANSI
// escape codes. It stays inside the subset of Odin the JIT understands:
//
//   * `for { ... if cond do break }` loops only (no for-init/cond/post)
//   * `&` / `|` instead of `&&` / `||`
//   * call-form casts only (`int(x)`, `f64(x)`, ...)
//   * integer "enums" expressed as plain constants
//   * the linux `syscall` intrinsic is the only external code
//   * no two `for` loops nested inside a single procedure -- inner loops are
//     factored into their own procs, the same way test-programs/lua is written
//
// Rendering is deterministic: a fixed PRNG seed drives the initial state and
// every step is pure IEEE-754 arithmetic, so the ASCII frames are bit-identical
// between the reference Odin compiler and the JIT.
//
// When stdout is not a terminal (the parity harness pipes it to a file) the
// simulation runs BATCH_FRAMES steps with plain ASCII and no sleeping. When
// stdout *is* a terminal it loops forever with colours and a small sleep so the
// flocking can be watched live.

import "base:intrinsics"

SYS_WRITE :: 1
SYS_IOCTL :: 16
SYS_NANOSLEEP :: 35

TCGETS :: 0x5401

W :: 78
H :: 30
GRID :: 2340 // W * H, spelled as a literal because the JIT only accepts
// literal array lengths.
N :: 45

BATCH_FRAMES :: 100
SLEEP_MS :: 60

// Neighbourhood radius squared, and the tighter separation radius squared.
RADIUS2 :: 81.0
SEP_RADIUS2 :: 16.0

SEP_W :: 0.06
ALI_W :: 0.05
COH_W :: 0.006

MAX_SPEED :: 1.1
MIN_SPEED :: 0.35

// ---------------------------------------------------------------------------
// low level IO
// ---------------------------------------------------------------------------

write_bytes :: proc(buf: [^]u8, n: int) {
	intrinsics.syscall(
		uintptr(SYS_WRITE),
		uintptr(1),
		uintptr(buf),
		uintptr(n),
	)
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

// is_tty asks the kernel for the terminal attributes of stdout; ioctl returns 0
// only when fd 1 is an actual terminal, otherwise a negative errno.
is_tty :: proc() -> bool {
	termbuf: [64]u8 = {}
	r := intrinsics.syscall(
		uintptr(SYS_IOCTL),
		uintptr(1),
		uintptr(TCGETS),
		uintptr(raw_data(termbuf[:])),
	)
	return i64(r) == 0
}

sleep_ms :: proc(ms: int) {
	ts: [2]i64 = {}
	ts[0] = i64(ms / 1000)
	ts[1] = i64((ms % 1000) * 1000000)
	intrinsics.syscall(
		uintptr(SYS_NANOSLEEP),
		uintptr(raw_data(ts[:])),
		uintptr(0),
	)
}

// ---------------------------------------------------------------------------
// math helpers
// ---------------------------------------------------------------------------

// fsqrt is a fixed-iteration Newton-Raphson square root. A fixed loop count
// keeps it deterministic across both compilers.
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

// ---------------------------------------------------------------------------
// deterministic PRNG (64-bit LCG)
// ---------------------------------------------------------------------------

rng_state: u64 = 0x053c49e6748fea9b

next_rand :: proc() -> u64 {
	rng_state = rng_state * 6364136223846793005 + 1442695040888963407
	return rng_state
}

// rand01 returns a float in [0, 1).
rand01 :: proc() -> f64 {
	return f64(next_rand() >> 11) / 9007199254740992.0
}

// rand_range returns a float in [lo, hi).
rand_range :: proc(lo: f64, hi: f64) -> f64 {
	return lo + rand01() * (hi - lo)
}

// ---------------------------------------------------------------------------
// simulation state
// ---------------------------------------------------------------------------

px: [N]f64
py: [N]f64
vx: [N]f64
vy: [N]f64

init_boids :: proc() {
	i := 0
	for {
		if i >= N do break
		px[i] = rand_range(0.0, f64(W))
		py[i] = rand_range(0.0, f64(H))
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

// The three flocking accumulators for the boid currently being updated. Kept as
// module globals so the neighbour scan can be its own procedure and `step` does
// not have to nest two `for` loops (see the header note).
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

// New velocities for the whole flock, written before any position is touched so
// every boid reacts to the same snapshot.
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

	// clamp speed into [MIN_SPEED, MAX_SPEED]
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
		px[i] = wrap(px[i] + vx[i], f64(W))
		py[i] = wrap(py[i] + vy[i], f64(H))
		i += 1
	}
}

// ---------------------------------------------------------------------------
// rendering
// ---------------------------------------------------------------------------

grid: [GRID]u8
col: [GRID]u8

// dir_char picks a glyph based on the dominant velocity component.
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

// dir_color maps a heading to one of 4 ANSI foreground colours (31..36).
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
		if cx >= W do cx = W - 1
		if cy < 0 do cy = 0
		if cy >= H do cy = H - 1
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
		tmp[n] = u8('0' + (v % 10))
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
		if bx >= W do break
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
		if x >= W do break
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

// render draws the current grid. With colour it repaints in place using cursor
// home; without colour it prints a plain framed grid suitable for diffing.
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
		if y >= H do break
		emit_row(y, use_color)
		y += 1
	}

	emit_border()

	flush()
}

// sum_positions folds a coarse hash of every boid position, used both to make
// the exit code depend on the simulation and to keep the return value stable.
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

main :: proc() -> int {
	color := is_tty()

	init_boids()

	if color {
		// hide cursor + clear screen once
		emit("\x1b[?25l\x1b[2J")
		flush()
		for {
			draw_frame(0, true)
			sleep_ms(SLEEP_MS)
		}
	}

	frame := 0
	checksum := 0
	for {
		if frame >= BATCH_FRAMES do break
		draw_frame(frame, false)
		checksum += sum_positions()
		frame += 1
	}

	return checksum % 251
}
