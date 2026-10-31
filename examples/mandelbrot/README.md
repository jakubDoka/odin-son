# Mandelbrot on Xe-LP

From the repository root:

```sh
odin run examples/mandelbrot -o:speed
# Optional render node:
odin run examples/mandelbrot -o:speed -- /dev/dri/renderD128
```

Requires Linux/amd64, access to the i915 render node, and the supported Intel
`8086:46a6` GPU. Raylib comes from Odin's `vendor:raylib` collection. The shader
is embedded from `shader/main.odin` and compiled by this repository's compiler
at startup; it is not a raylib/GLSL compute shader and has no CPU fallback.

- Mouse wheel: zoom around the cursor.
- Left-drag, arrows, or WASD: pan.
- Resize the window: recreate the output buffer and texture at viewport resolution.
- `[` / `]`: decrease/increase the iteration limit (16–4096).
- `R`: reset the view; Escape: quit.

Zoom is limited by the shader's `f32` coordinates. The viewport keeps its aspect
ratio. GPU work runs only when the view, size, or iteration limit changes.

The program uploads the kernel once, reuses its command/state allocations, and
dispatches one SIMD8 hardware thread per 64 pixels. Each thread handles eight
pixels per loop iteration. The final partial group is masked by the shader.
After synchronous GPU completion, the CPU copies the iteration buffer, maps
escape counts through a cached palette (interior pixels are black), and uploads
RGBA pixels to a raylib texture. The displayed time includes dispatch, readback,
color conversion, and texture upload.

## Packed uniforms

`shader.Uniforms` is shared by the runner and the shader's `render` entrypoint.
Its fields use their normal struct offsets, packed into 32-byte parameter
registers starting at `r1`. The struct can have any parameter name except
`thread_id` or `lane_id`, and may be passed only once. Fields must be 32-bit
integers, `f32`, or 64-bit integers/pointers; aggregate fields and custom layouts
are not supported. Only field accesses are allowed, not copies or addresses of
the uniform struct or its fields. These restrictions apply only to GPU
entrypoints; ordinary CPU calls use the normal Odin calling convention.

The `thread_id: u32` and `lane_id: u32` parameters are builtins and occupy no
parameter registers. This shader uses two registers:

| Byte offset | Uniform |
| --- | --- |
| 0 / 4 / 8 | `width`, `height`, `max_iterations` |
| 12 | `pixels_per_thread` (must be a multiple of 8) |
| 16 / 20 / 24 / 28 | `x_min`, `y_min`, `dx`, `dy` |
| 32 | `output` (64-bit GPU virtual address, **not** a CPU pointer) |

The same shader can be called on the CPU with
`shader.render(uniforms, thread_id, lane_id)` and a CPU pointer in
`uniforms.output`. The interactive runner only dispatches it on the GPU.

`thread_id` is the walker X workgroup ID; each workgroup has one hardware
thread. `lane_id` is 0–7. Dispatch enough groups to cover
`ceil(width * height / pixels_per_thread)` pixels. Buffers must also be listed
in `gpu.dispatch` so i915 maps their GPU addresses for the submission.

The runner calls `odinc.compile` with a `Compile_Config` selecting the Xe-LP
target, embedded `source`, and `entry_point = "render"` (the default is `main`).
This is the same compilation pipeline used by the
CLI; it returns `(artifact: []u8, ok: bool)`, with caller-owned artifact bytes
and diagnostics written to stderr. Omit `source` to load `input` from disk.
Start with `odinc.DEFAULT_COMPILE_CONFIG` to use the CLI's default flags.
Only the CLI writes the returned artifact to `Compile_Config.output`.
The standalone compiler can also emit the raw kernel:

```sh
odin run odinc -- examples/mandelbrot/shader/main.odin -target:intel_xelp -entry-point:render -o:all -o /tmp/opencode/mandelbrot.bin
```
