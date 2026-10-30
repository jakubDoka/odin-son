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

Uniforms follow source declaration order, with natural 4-/8-byte alignment,
packed into 32-byte parameter registers starting at `r1`. Builtins occupy no
uniform space. This shader uses two registers:

| Byte offset | Uniform |
| --- | --- |
| 0 / 4 / 8 | `width`, `height`, `max_iterations` |
| 12 / 16 / 20 / 24 | `x_min`, `y_min`, `dx`, `dy` |
| 28 | alignment padding |
| 32 | `output` (64-bit GPU virtual address, **not** a CPU pointer) |
| 40 | `pixels_per_thread` (must be a multiple of 8) |

`thread_id` is the walker X workgroup ID; each workgroup has one hardware
thread. `lane_id` is 0–7. Dispatch enough groups to cover
`ceil(width * height / pixels_per_thread)` pixels. Buffers must also be listed
in `gpu.dispatch` so i915 maps their GPU addresses for the submission.

The runner calls `odinc.compile` with a `Compile_Config` selecting the Xe-LP
target and embedded `source`. This is the same compilation pipeline used by the
CLI; it returns `(artifact: []u8, ok: bool)`, with caller-owned artifact bytes
and diagnostics written to stderr. Omit `source` to load `input` from disk.
Start with `odinc.DEFAULT_COMPILE_CONFIG` to use the CLI's default flags.
Only the CLI writes the returned artifact to `Compile_Config.output`.
The standalone compiler can also emit the raw kernel:

```sh
odin run odinc -- examples/mandelbrot/shader/main.odin -target:intel_xelp -o:all -o /tmp/opencode/mandelbrot.bin
```
