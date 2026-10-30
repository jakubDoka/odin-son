#+build linux, amd64
package mandelbrot_runner

import "../../gpu-dispatch/gpu"
import "../../odinc"
import "core:fmt"
import "core:math"
import "core:mem"
import "core:os"
import "core:time"
import rl "vendor:raylib"

Uniforms :: struct {
	width, height, max_iterations: u32,
	x_min, y_min, dx, dy:          f32,
	output:                        u64,
	pixels_per_thread:             u32,
}

#assert(offset_of(Uniforms, output) == 32)
#assert(offset_of(Uniforms, pixels_per_thread) == 40)

main :: proc() {
	if len(os.args) > 1 && os.args[1] == "--help" {
		fmt.println("Usage: mandelbrot [render-node]")
		fmt.println(
			"Wheel: zoom at cursor; drag or arrows/WASD: move; R: reset; [/]: iterations; Esc: exit.",
		)
		return
	}
	if len(os.args) > 2 {
		fmt.eprintln("Usage: mandelbrot [render-node]")
		os.exit(1)
	}
	path := len(os.args) == 2 ? os.args[1] : "/dev/dri/renderD128"
	if !run(path) do os.exit(1)
}

run :: proc(path: string) -> bool {
	code, ok := odinc.compile(
		{
			input = "mandelbrot.odin",
			source = #load("shader/main.odin", string),
			target = .Intel_Xelp,
			level = odinc.OPT_LEVELS[4],
		},
	)
	if !ok do return false
	defer delete(code)
	device, err := gpu.open(path)
	if err != nil {
		fmt.eprintf("Cannot open GPU: %v\n", err)
		return false
	}
	defer gpu.close(&device)
	program, program_error := gpu.program_create(
		&device,
		{code = mem.slice_data_cast([]u32, code)},
		2,
	)
	if program_error != nil {
		fmt.eprintf("Cannot upload shader: %v\n", program_error)
		return false
	}
	defer gpu.program_destroy(&program)

	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	rl.InitWindow(960, 640, "Mandelbrot - Xe-LP JIT")
	defer rl.CloseWindow()
	rl.SetWindowMinSize(160, 120)
	rl.SetTargetFPS(60)
	texture: rl.Texture2D
	defer if texture.id != 0 do rl.UnloadTexture(texture)
	buffer: gpu.Buffer
	defer gpu.buffer_destroy(&buffer)
	iterations: []u32
	colors: []rl.Color
	defer delete(iterations)
	defer delete(colors)
	palette: [4097]rl.Color
	for &color, i in palette do color = rl.ColorFromHSV(f32(i) * 4.5, 0.85, 1)

	width, height: i32
	center_x, center_y, span := f64(-0.5), f64(0), f64(2.5)
	max_iterations := u32(256)
	dirty := true
	elapsed: time.Duration
	for !rl.WindowShouldClose() {
		if rl.IsWindowMinimized() do continue
		w, h := rl.GetScreenWidth(), rl.GetScreenHeight()
		if w <= 0 || h <= 0 do continue
		if w != width || h != height {
			if texture.id != 0 do rl.UnloadTexture(texture)
			texture = {}
			gpu.buffer_destroy(&buffer)
			delete(iterations)
			delete(colors)
			iterations, colors = nil, nil
			buffer, err = gpu.buffer_create(&device, int(w) * int(h) * size_of(u32))
			if err != nil {
				fmt.eprintf("Cannot allocate viewport: %v\n", err)
				return false
			}
			iterations = make([]u32, int(w) * int(h))
			colors = make([]rl.Color, len(iterations))
			image := rl.Image {
				data    = raw_data(colors),
				width   = w,
				height  = h,
				mipmaps = 1,
				format  = .UNCOMPRESSED_R8G8B8A8,
			}
			texture = rl.LoadTextureFromImage(image)
			if texture.id == 0 do return false
			width, height = w, h
			dirty = true
		}

		step := span / f64(height)
		wheel := rl.GetMouseWheelMove()
		if wheel != 0 {
			mouse := rl.GetMousePosition()
			next_span := clamp(span * math.pow(f64(0.8), f64(wheel)), 0.00001, 8.0)
			next_step := next_span / f64(height)
			center_x += (f64(mouse.x) - f64(width) * 0.5) * (step - next_step)
			center_y += (f64(mouse.y) - f64(height) * 0.5) * (step - next_step)
			span = next_span
			dirty = true
		}
		if rl.IsMouseButtonDown(.LEFT) {
			delta := rl.GetMouseDelta()
			center_x -= f64(delta.x) * step
			center_y -= f64(delta.y) * step
			dirty ||= delta.x != 0 || delta.y != 0
		}
		move_x :=
			int(rl.IsKeyDown(.RIGHT) || rl.IsKeyDown(.D)) -
			int(rl.IsKeyDown(.LEFT) || rl.IsKeyDown(.A))
		move_y :=
			int(rl.IsKeyDown(.DOWN) || rl.IsKeyDown(.S)) -
			int(rl.IsKeyDown(.UP) || rl.IsKeyDown(.W))
		if move_x != 0 || move_y != 0 {
			center_x += f64(move_x) * span * f64(rl.GetFrameTime()) * 0.6
			center_y += f64(move_y) * span * f64(rl.GetFrameTime()) * 0.6
			dirty = true
		}
		if rl.IsKeyPressed(.R) {
			center_x, center_y, span = -0.5, 0, 2.5
			dirty = true
		}
		if rl.IsKeyPressed(.RIGHT_BRACKET) {
			max_iterations = min(max_iterations * 2, 4096)
			dirty = true
		}
		if rl.IsKeyPressed(.LEFT_BRACKET) {
			max_iterations = max(max_iterations / 2, 16)
			dirty = true
		}

		if dirty {
			start := time.tick_now()
			step = span / f64(height)
			uniforms := Uniforms {
				width             = u32(width),
				height            = u32(height),
				max_iterations    = max_iterations,
				x_min             = f32(center_x - step * f64(width) * 0.5),
				y_min             = f32(center_y - span * 0.5),
				dx                = f32(step),
				dy                = f32(step),
				output            = buffer.address,
				pixels_per_thread = 64,
			}
			parameters: [2]gpu.Reg
			copy(mem.slice_to_bytes(parameters[:]), mem.ptr_to_bytes(&uniforms))
			groups :=
				(u32(len(iterations)) + uniforms.pixels_per_thread - 1) /
				uniforms.pixels_per_thread
			err = gpu.dispatch(&program, parameters[:], groups, {&buffer})
			if err != nil {
				fmt.eprintf("Shader execution failed: %v\n", err)
				return false
			}
			copy(iterations, buffer.words)
			for iteration, i in iterations {
				colors[i] = iteration >= max_iterations ? rl.BLACK : palette[iteration]
			}
			rl.UpdateTexture(texture, raw_data(colors))
			elapsed = time.tick_since(start)
			dirty = false
		}

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)
		rl.DrawTexture(texture, 0, 0, rl.WHITE)
		rl.DrawRectangle(0, 0, width, 52, {0, 0, 0, 180})
		text := fmt.ctprintf(
			"%dx%d | %d iterations | %.1f ms | %.0fx",
			width,
			height,
			max_iterations,
			time.duration_milliseconds(elapsed),
			2.5 / span,
		)
		rl.DrawText(text, 10, 6, 18, rl.WHITE)
		rl.DrawText(
			"Wheel: zoom | Drag/WASD: pan | [/]: iterations | R: reset",
			10,
			30,
			16,
			rl.LIGHTGRAY,
		)
		rl.EndDrawing()
		free_all(context.temp_allocator)
	}
	return true
}
