package main

LIGHT_W :: 128
LIGHT_H :: 96
LIGHT_CELLS :: 12288
IMAGE_W :: 192
IMAGE_H :: 144

Optics :: struct {
    flux: [LIGHT_CELLS]f32,
    fields: [165888]f32,
    incident: f64,
    reflected: f64,
    absorbed: f64,
    escaped: f64,
    deposited: f64,
}

Ray :: struct {
    x: f32,
    y: f32,
    z: f32,
}

positive_root :: proc(value: f32) -> f32 {
    if value <= 0.0 do return 0.0
    root := f32(1.0)
    for i := 0; i < 6; i += 1 do root = 0.5*(root+value/root)
    return root
}

transmission :: proc(optical_depth: f32) -> f32 {
    // The [2/2] Pade error stays below 0.003 over this demo's optical-depth range, 0..1.5.
    square := optical_depth*optical_depth/12.0
    return (1.0-0.5*optical_depth+square)/(1.0+0.5*optical_depth+square)
}

surface_normal :: proc(w: ^Water, x, y, depth: f32, n: ^Ray) {
    gx := 0.5*depth*(field_sample(([^]f32)(&w.height[0]), x+1.0, y)-field_sample(([^]f32)(&w.height[0]), x-1.0, y))
    gy := 0.5*depth*(field_sample(([^]f32)(&w.height[0]), x, y+1.0)-field_sample(([^]f32)(&w.height[0]), x, y-1.0))
    inv := 1.0/positive_root(1.0+gx*gx+gy*gy)
    n.x = -gx*inv
    n.y = -gy*inv
    n.z = inv
}

refract_ray :: proc(n: ^Ray, ix, iy, iz: f32, ray: ^Ray) -> f32 {
    cosine := -(n.x*ix+n.y*iy+n.z*iz)
    if cosine < 0.0 do cosine = 0.0
    if cosine > 1.0 do cosine = 1.0
    eta := f32(0.75018755)
    factor := eta*cosine-positive_root(1.0-eta*eta*(1.0-cosine*cosine))
    ray.x = eta*ix+factor*n.x
    ray.y = eta*iy+factor*n.y
    ray.z = eta*iz+factor*n.z
    m := 1.0-cosine
    return 0.0203732+0.9796268*m*m*m*m*m
}

flux_splat :: proc(o: ^Optics, x, y, energy: f32) {
    ix, iy := int(x+1.0)-1, int(y+1.0)-1
    if x < -1.0 || y < -1.0 || x >= f32(LIGHT_W) || y >= f32(LIGHT_H) {
        o.escaped += f64(energy)
        return
    }
    tx, ty := x-f32(ix), y-f32(iy)
    for dy := 0; dy < 2; dy += 1 {
        wy := 1.0-ty
        if dy == 1 do wy = ty
        for dx := 0; dx < 2; dx += 1 {
            wx := 1.0-tx
            if dx == 1 do wx = tx
            contribution := energy*wx*wy
            if ix+dx >= 0 && ix+dx < LIGHT_W && iy+dy >= 0 && iy+dy < LIGHT_H {
                o.flux[(iy+dy)*LIGHT_W+ix+dx] += contribution
                o.deposited += f64(contribution)
            } else {
                o.escaped += f64(contribution)
            }
        }
    }
}

light_solve :: proc(w: ^Water, o: ^Optics, depth: f32) {
    for i := 0; i < LIGHT_CELLS; i += 1 do o.flux[i] = 0.0
    o.incident, o.reflected, o.absorbed, o.escaped, o.deposited = 0.0, 0.0, 0.0, 0.0, 0.0
    for y := 0; y < LIGHT_H; y += 1 {
        for x := 0; x < LIGHT_W; x += 1 {
            px := (f32(x)+0.5)*f32(GRID_W)/f32(LIGHT_W)-0.5
            py := (f32(y)+0.5)*f32(GRID_H)/f32(LIGHT_H)-0.5
            normal, ray: Ray
            surface_normal(w, px, py, depth, &normal)
            reflected := refract_ray(&normal, 0.0, 0.0, -1.0, &ray)
            path := -depth*field_sample(([^]f32)(&w.height[0]), px, py)/ray.z
            transmitted := (1.0-reflected)*transmission(0.012*path)
            bx, by := px+ray.x*path, py+ray.y*path
            lx := (bx+0.5)*f32(LIGHT_W)/f32(GRID_W)-0.5
            ly := (by+0.5)*f32(LIGHT_H)/f32(GRID_H)-0.5
            o.incident += 1.0
            o.reflected += f64(reflected)
            o.absorbed += f64(1.0-reflected-transmitted)
            flux_splat(o, lx, ly, transmitted)
        }
    }
}

light_sample :: proc(o: ^Optics, x, y: f32) -> f32 {
    px := (x+0.5)*f32(LIGHT_W)/f32(GRID_W)-0.5
    py := (y+0.5)*f32(LIGHT_H)/f32(GRID_H)-0.5
    if px < 0.0 do px = 0.0
    if py < 0.0 do py = 0.0
    if px > f32(LIGHT_W-1) do px = f32(LIGHT_W-1)
    if py > f32(LIGHT_H-1) do py = f32(LIGHT_H-1)
    ix, iy := int(px), int(py)
    jx, jy := ix+1, iy+1
    if jx >= LIGHT_W do jx = ix
    if jy >= LIGHT_H do jy = iy
    tx, ty := px-f32(ix), py-f32(iy)
    a := o.flux[iy*LIGHT_W+ix]*(1.0-tx)+o.flux[iy*LIGHT_W+jx]*tx
    b := o.flux[jy*LIGHT_W+ix]*(1.0-tx)+o.flux[jy*LIGHT_W+jx]*tx
    return a*(1.0-ty)+b*ty
}

prepare_water_fields :: proc(w: ^Water, o: ^Optics, depth: f32, mode: int) {
    for y := 0; y < IMAGE_H; y += 1 {
        for x := 0; x < IMAGE_W; x += 1 {
            px := (f32(x)+0.5)*f32(GRID_W+4)/f32(IMAGE_W)-2.5
            py := (f32(y)+0.5)*f32(GRID_H+3)/f32(IMAGE_H)-2.0
            index := y*IMAGE_W+x
            for field := 0; field < 5; field += 1 do o.fields[field*27648+index] = 0.0
            o.fields[138240+index] = 3.0
            if px < -0.5 || px >= f32(GRID_W)-0.5 || py < -0.5 || py >= f32(GRID_H)-0.5 do continue
            o.fields[138240+index] = f32(mode)
            if mode == 1 {
                o.fields[110592+index] = (field_sample(([^]f32)(&w.height[0]), px, py)-1.0)*5.0
                continue
            }
            if mode == 2 {
                o.fields[110592+index] = light_sample(o, px, py)
                continue
            }
            normal, ray: Ray
            surface_normal(w, px, py, depth, &normal)
            reflection := refract_ray(&normal, 0.12, 0.18, -0.976729, &ray)
            path := -depth*field_sample(([^]f32)(&w.height[0]), px, py)/ray.z
            bx, by := px+ray.x*path, py+ray.y*path
            caustic := light_sample(o, bx, by)
            baseline := 0.9796268*transmission(0.012*depth)
            illumination := 0.75+3.0*(caustic-baseline)
            if illumination < 0.1 do illumination = 0.1
            if illumination > 2.5 do illumination = 2.5
            tile_x, tile_y := int(bx+128.0), int(by+128.0)
            tile := f32(0.86)
            if (tile_x/8+tile_y/8)%2 == 0 do tile = 0.72
            if tile_x%8 == 0 || tile_y%8 == 0 do tile *= 0.6
            o.fields[index] = path
            o.fields[27648+index] = tile*illumination*(1.0-reflection)
            o.fields[55296+index] = reflection
            o.fields[82944+index] = normal.x*0.2-normal.y*0.15+normal.z*0.9682458
        }
    }
}
