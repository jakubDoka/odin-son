package mandelbrot

@(tag = "builtin")
thread_id: u32
@(tag = "uniform")
width: u32
@(tag = "uniform")
height: u32
@(tag = "builtin")
lane_id: u32
@(tag = "uniform")
max_iterations: u32
@(tag = "uniform")
x_min: f32
@(tag = "uniform")
y_min: f32
@(tag = "uniform")
dx: f32
@(tag = "uniform")
dy: f32
@(tag = "uniform")
output: [^]u32
@(tag = "uniform")
pixels_per_thread: u32

main :: proc() {
	base := thread_id * pixels_per_thread
	i: u32
	for {
		if i >= pixels_per_thread do break
		pixel := base + i + lane_id
		if pixel < width * height {
			col := pixel % width
			row := pixel / width
			cx := x_min + f32(col) * dx
			cy := y_min + f32(row) * dy
			x: f32
			y: f32
			iteration: u32
			for {
				if iteration >= max_iterations do break
				xx := x * x
				yy := y * y
				if xx + yy > 4.0 do break
				xy := x * y
				y = 2.0 * xy + cy
				x = xx - yy + cx
				iteration += 1
			}
			output[pixel] = iteration
		}
		i += 8
	}
}
