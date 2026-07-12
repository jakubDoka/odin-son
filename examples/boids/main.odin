package main

// Boids (flocking) rendered with raylib. raylib is bound by hand through a
// foreign block below and linked against the system installed shared library
// (see run.sh). This exercises the JIT's C calling convention: i32/f32 scalar
// arguments and raylib's 4-byte `Color` struct, which the SystemV ABI passes in
// a single integer register -- so we spell it as a packed `u32` (r | g<<8 |
// b<<16 | a<<24) on our side and it lands in the right register for raylib.
//
// It stays inside the subset of Odin the JIT understands:
//   * `for { ... if cond do break }` loops only (no for-init/cond/post)
//   * call-form casts only (`i32(x)`, `f32(x)`, ...)
//   * integer "enums" / colours expressed as plain constants
//   * literal array lengths
//   * no two `for` loops nested inside a single procedure -- inner loops are
//     factored into their own procs

foreign {
	InitWindow :: proc(width: i32, height: i32, title: ^u8) ---
	CloseWindow :: proc() ---
	WindowShouldClose :: proc() -> bool ---
	SetTargetFPS :: proc(fps: i32) ---
	BeginDrawing :: proc() ---
	EndDrawing :: proc() ---
	ClearBackground :: proc(color: u32) ---
	DrawCircle :: proc(centerX: i32, centerY: i32, radius: f32, color: u32) ---
	DrawText :: proc(text: ^u8, posX: i32, posY: i32, fontSize: i32, color: u32) ---
	sqrtf :: proc(x: f32) -> f32 ---
}

W :: 900
H :: 640
N :: 140

// squared neighbourhood radius and the tighter separation radius squared
RADIUS2 :: 1600.0 // 40px
SEP_RADIUS2 :: 400.0 // 20px

COH_W :: 0.0012
ALI_W :: 0.055
SEP_W :: 0.05

MAX_SPEED :: 3.2
MIN_SPEED :: 1.2

// raylib Color is {r, g, b, a} in memory, so a little-endian u32 packs as
// r | g<<8 | b<<16 | a<<24.
BG_COLOR :: 0xFF14100C // dark slate
BOID_COLOR :: 0xFFF0C85A // warm cyan-ish
HINT_COLOR :: 0xFF5A5048

px: [N]f32
py: [N]f32
vx: [N]f32
vy: [N]f32
nvx: [N]f32
nvy: [N]f32

title: [8]u8
hint: [40]u8

rng_state: u32

rand_u32 :: proc() -> u32 {
	rng_state = rng_state * 1664525 + 1013904223
	return rng_state
}

// uniform in [0, 1)
rand_f32 :: proc() -> f32 {
	return f32(rand_u32() >> 8) / 16777216.0
}

init_boids :: proc() {
	rng_state = 0x9e3779b9
	i := 0
	for {
		if i >= N do break
		px[i] = rand_f32() * f32(W)
		py[i] = rand_f32() * f32(H)
		vx[i] = (rand_f32() - 0.5) * 4.0
		vy[i] = (rand_f32() - 0.5) * 4.0
		i += 1
	}
}

// Compute boid i's next velocity by scanning every other boid once. Kept in its
// own proc so the neighbour scan is the only loop here (the JIT cannot nest two
// `for` loops in one procedure).
update_boid :: proc(i: int) {
	cx := f32(0) // cohesion: average neighbour position
	cy := f32(0)
	ax := f32(0) // alignment: average neighbour velocity
	ay := f32(0)
	sx := f32(0) // separation: push away from close neighbours
	sy := f32(0)
	count := 0

	j := 0
	for {
		if j >= N do break
		if j != i {
			dx := px[j] - px[i]
			dy := py[j] - py[i]
			d2 := dx * dx + dy * dy
			if d2 < RADIUS2 {
				cx += px[j]
				cy += py[j]
				ax += vx[j]
				ay += vy[j]
				count += 1
				if d2 < SEP_RADIUS2 {
					sx -= dx
					sy -= dy
				}
			}
		}
		j += 1
	}

	nx := vx[i]
	ny := vy[i]
	if count > 0 {
		fc := f32(count)
		cx = cx / fc - px[i]
		cy = cy / fc - py[i]
		ax = ax / fc - vx[i]
		ay = ay / fc - vy[i]
		nx += cx * COH_W + ax * ALI_W + sx * SEP_W
		ny += cy * COH_W + ay * ALI_W + sy * SEP_W
	}

	speed := sqrtf(nx * nx + ny * ny)
	if speed > MAX_SPEED {
		nx = nx / speed * MAX_SPEED
		ny = ny / speed * MAX_SPEED
	}
	if speed < MIN_SPEED {
		if speed > 0.0001 {
			nx = nx / speed * MIN_SPEED
			ny = ny / speed * MIN_SPEED
		}
	}

	nvx[i] = nx
	nvy[i] = ny
}

flock :: proc() {
	i := 0
	for {
		if i >= N do break
		update_boid(i)
		i += 1
	}
}

integrate :: proc() {
	i := 0
	for {
		if i >= N do break
		vx[i] = nvx[i]
		vy[i] = nvy[i]
		px[i] += vx[i]
		py[i] += vy[i]
		if px[i] < 0.0 do px[i] += f32(W)
		if px[i] >= f32(W) do px[i] -= f32(W)
		if py[i] < 0.0 do py[i] += f32(H)
		if py[i] >= f32(H) do py[i] -= f32(H)
		i += 1
	}
}

draw_boids :: proc() {
	i := 0
	for {
		if i >= N do break
		DrawCircle(i32(px[i]), i32(py[i]), 3.5, BOID_COLOR)
		i += 1
	}
}

setup_text :: proc() {
	title[0] = 'B'
	title[1] = 'o'
	title[2] = 'i'
	title[3] = 'd'
	title[4] = 's'
	title[5] = 0

	msg := "close the window to quit"
	i := 0
	for {
		if i >= len(msg) do break
		hint[i] = msg[i]
		i += 1
	}
	hint[i] = 0
}

main :: proc() -> int {
	setup_text()
	InitWindow(W, H, &title[0])
	SetTargetFPS(60)
	init_boids()

	for {
		if WindowShouldClose() do break
		flock()
		integrate()

		BeginDrawing()
		ClearBackground(BG_COLOR)
		draw_boids()
		DrawText(&hint[0], 12, 12, 20, HINT_COLOR)
		EndDrawing()
	}

	CloseWindow()
	return 0
}
