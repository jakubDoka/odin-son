package main

GRID_W :: 64
GRID_H :: 48
CELLS :: 3072
GRAVITY :: 0.06
OMEGA :: 1.4285714286

Water :: struct {
    populations: [CELLS][9]f32,
    streamed: [CELLS][9]f32,
    height: [CELLS]f32,
    velocity_x: [CELLS]f32,
    velocity_y: [CELLS]f32,
    steps: u64,
    initial_mass: f64,
}

DIRECTION_X: [9]int
DIRECTION_Y: [9]int
OPPOSITE: [9]int

equilibrium :: proc(direction: int, h, ux, uy: f32) -> f32 {
    speed2 := ux*ux + uy*uy
    if direction == 0 do return h*(1.0 - 5.0*GRAVITY*h/6.0 - 2.0*speed2/3.0)
    cu := f32(DIRECTION_X[direction])*ux + f32(DIRECTION_Y[direction])*uy
    lambda := f32(1.0)
    if direction >= 5 do lambda = 0.25
    return lambda*h*(GRAVITY*h/6.0 + cu/3.0 + cu*cu/2.0 - speed2/6.0)
}

water_measure :: proc(w: ^Water) -> bool {
    for cell := 0; cell < CELLS; cell += 1 {
        h, mx, my := f32(0.0), f32(0.0), f32(0.0)
        for direction := 0; direction < 9; direction += 1 {
            f := w.populations[cell][direction]
            h += f
            mx += f32(DIRECTION_X[direction])*f
            my += f32(DIRECTION_Y[direction])*f
        }
        // Reject unstable/non-finite states instead of silently clipping conserved fields.
        if !(h > 0.5 && h < 1.5) do return false
        ux, uy := mx/h, my/h
        if !(ux*ux + uy*uy < 0.04) do return false
        w.height[cell] = h
        w.velocity_x[cell] = ux
        w.velocity_y[cell] = uy
    }
    return true
}

water_reset :: proc(w: ^Water) {
    DIRECTION_X = {0, 1, 0, -1, 0, 1, -1, -1, 1}
    DIRECTION_Y = {0, 0, 1, 0, -1, 1, 1, -1, -1}
    OPPOSITE = {0, 3, 4, 1, 2, 7, 8, 5, 6}
    w.steps = 0
    w.initial_mass = f64(CELLS)
    for cell := 0; cell < CELLS; cell += 1 {
        for direction := 0; direction < 9; direction += 1 {
            w.populations[cell][direction] = equilibrium(direction, 1.0, 0.0, 0.0)
        }
        w.height[cell] = 1.0
        w.velocity_x[cell] = 0.0
        w.velocity_y[cell] = 0.0
    }
}

water_step :: proc(w: ^Water) -> bool {
    if !water_measure(w) do return false
    for y := 0; y < GRID_H; y += 1 {
        for x := 0; x < GRID_W; x += 1 {
            cell := y*GRID_W+x
            h, ux, uy := w.height[cell], w.velocity_x[cell], w.velocity_y[cell]
            for direction := 0; direction < 9; direction += 1 {
                f := w.populations[cell][direction]
                post := f + OMEGA*(equilibrium(direction, h, ux, uy)-f)
                nx, ny := x+DIRECTION_X[direction], y+DIRECTION_Y[direction]
                if nx < 0 || nx >= GRID_W || ny < 0 || ny >= GRID_H {
                    w.streamed[cell][OPPOSITE[direction]] = post
                } else {
                    w.streamed[ny*GRID_W+nx][direction] = post
                }
            }
        }
    }
    // Every population has exactly one source, including halfway wall bounce-back.
    for cell := 0; cell < CELLS; cell += 1 {
        for direction := 0; direction < 9; direction += 1 {
            w.populations[cell][direction] = w.streamed[cell][direction]
        }
    }
    w.steps += 1
    return water_measure(w)
}

water_drop :: proc(w: ^Water, center_x, center_y, amplitude: f32) {
    total := f32(0.0)
    for y := 0; y < GRID_H; y += 1 {
        for x := 0; x < GRID_W; x += 1 {
            dx, dy := f32(x)-center_x, f32(y)-center_y
            q := 1.0-(dx*dx+dy*dy)/36.0
            if q > 0.0 do total += amplitude*q*q*q
        }
    }
    compensation := total/f32(CELLS)
    for y := 0; y < GRID_H; y += 1 {
        for x := 0; x < GRID_W; x += 1 {
            dx, dy := f32(x)-center_x, f32(y)-center_y
            q := 1.0-(dx*dx+dy*dy)/36.0
            delta := -compensation
            if q > 0.0 do delta += amplitude*q*q*q
            // Rest-population displacement preserves cell momentum; the mean keeps total mass.
            w.populations[y*GRID_W+x][0] += delta
        }
    }
    water_measure(w)
}

field_sample :: proc(values: [^]f32, x, y: f32) -> f32 {
    px, py := x, y
    if px < 0.0 do px = 0.0
    if py < 0.0 do py = 0.0
    if px > f32(GRID_W-1) do px = f32(GRID_W-1)
    if py > f32(GRID_H-1) do py = f32(GRID_H-1)
    ix, iy := int(px), int(py)
    jx, jy := ix+1, iy+1
    if jx >= GRID_W do jx = ix
    if jy >= GRID_H do jy = iy
    tx, ty := px-f32(ix), py-f32(iy)
    a := values[iy*GRID_W+ix]*(1.0-tx) + values[iy*GRID_W+jx]*tx
    b := values[jy*GRID_W+ix]*(1.0-tx) + values[jy*GRID_W+jx]*tx
    return a*(1.0-ty)+b*ty
}
