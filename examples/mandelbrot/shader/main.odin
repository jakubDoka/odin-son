package mandelbrot

Uniforms :: struct {
	width:             u32,
	height:            u32,
	max_iterations:    u32,
	pixels_per_thread: u32,
	x_min:             f32,
	y_min:             f32,
	dx:                f32,
	dy:                f32,
	output:            [^]u32,
}

render :: proc(uniforms: Uniforms, thread_id: u32, lane_id: u32) {
	coff := 0xffffffff / uniforms.max_iterations
	base := thread_id * uniforms.pixels_per_thread
	i: u32
	for {
		if i >= uniforms.pixels_per_thread do break
		pixel := base + i + lane_id
		if pixel < uniforms.width * uniforms.height {
			col := pixel % uniforms.width
			row := pixel / uniforms.width
			cx := uniforms.x_min + f32(col) * uniforms.dx
			cy := uniforms.y_min + f32(row) * uniforms.dy
			x: f32
			y: f32
			iteration: u32
			for {
				if iteration >= uniforms.max_iterations do break
				xx := x * x
				yy := y * y
				if xx + yy > 4.0 do break
				xy := x * y
				y = 2.0 * xy + cy
				x = xx - yy + cx
				iteration += 1
			}
			uniforms.output[pixel] = (iteration * coff | 0x000000ff)
		}
		i += 8
	}
}
