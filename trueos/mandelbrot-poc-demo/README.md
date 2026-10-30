# Mandelbrot through intel_xelp_poc

Run `cargo bp odin-son` in TRUEOS-Blueprints, relaunch odin-son, select
`mandelbrot_gpu_poc`, and press Enter. It compiles the shader and CPU runner on
TRUEOS, then queues one child launch. The batch flag is `--mandelbrot_gpu_poc`.
There is no precompiled shader asset. The existing `mandelbrot_gpu_cpu` entry
continues to exercise `intel_xelp_pixel`.

The shader is `shader.poc.odin.source`. It uses explicit f32 locals, a GPU loop,
and an escape branch to evaluate the same `depth * 0.04` Mandelbrot function as
the pixel example. Its default is 25 iterations. The loop counter is f32 because
the POC backend does not implement integer arithmetic. Match the iteration
count and normalization in both sources before comparing; changing one example
does not change the other. In particular, a two-iteration pixel source will
look much flatter than this default.

The compiler integration in `trueos/pixel.odin` calls the ordinary odin-son type
checker and `emit_proc` with the existing `intel_xelp_poc.SPEC` and calling
convention, at optimization level `all`. The backend is unchanged. The picker
recognizes `shader.poc.odin.source` and runs:

```text
odin-son --gpu-poc <demo>/shader.poc.odin.source -o <demo>/shader.eu
```

This visual bridge requires a single `main :: proc(f32, f32) -> f32` without
helper procedures. It generates `kernel.odin` containing the complete kernel,
then compiles the CPU application normally. Shader compilation failure blocks
launching the child. The generated files live under the app's example directory;
local shader edits are preserved across compiler restarts.

The granted UI4 frame owns the uploaded complete kernel. Its existing dispatch
ABI supplies two SIMD8 coordinate registers and reads eight f32 results from
the fixed BT0 result store. `render.odin` converts those GPU results to opaque
grayscale pixels, uploads them as a frame-owned sprite, and submits one full-frame
GPU copy into the visual write lease. Publication uses the exact GPU producer
release. Direct CPU RGBA writes cannot satisfy a GPU-only visual frame's
full-overwrite contract; they returned `-6` on the rig after all 600 dispatches
had succeeded.
The application contains no CPU Mandelbrot implementation or fallback.

The current dispatch ABI submits and retires one SIMD8 group per call. To keep
this demonstration bounded, the adapter samples at most 80x60 points and fills
their corresponding display blocks. A 320x240 window uses 80x60 samples and
600 dispatches. Smaller windows can reach one sample per pixel. The same limit
holds during brokered resize, including odd dimensions. Wheel zoom, left drag
pan, Q/Escape, and the center-preserving resize behavior match the pixel runner.
The POC runner also follows its frame-opacity setting of 128.

| Aspect | intel_xelp_pixel example | intel_xelp_poc example |
| --- | --- | --- |
| Frontend | Dedicated bounded f32/bool pixel lowering | Ordinary Odin SON frontend and type checker |
| Compiler IR | Small pixel operation stream, dead-value pruning | Shared BAC SSA graph and optimization passes |
| Register allocation | Dedicated liveness allocation before encoding | Shared BAC coloring allocator, GRFs and predicate flags |
| Loop handling | Constant loops expanded into straight-line operations | Actual EU branches, loop backedges and SIMD reconvergence |
| Conditional values | Compare/select instructions | Branch control flow and phi transfers |
| GPU inputs/result | r1/r2 coordinates, f32 result in r4 | r1/r2 coordinates, f32 result in r120 |
| Generated code | Arithmetic body; driver supplies the memory messages and EOT | Complete kernel with fixed BT0 store and EOT |
| UI4 presentation | GPU writes every destination pixel directly | CPU expands GPU samples; sprite upload and GPU copy into frame |
| Example at 25 iterations | 10,160-byte body, plus driver envelope | 656-byte complete kernel |

The size difference demonstrates retaining a loop instead of expanding it.
The sizes include different envelopes, and the POC presentation transport has
many more submissions plus CPU copies, so they are not performance measurements.
Pixel-by-pixel equality is meaningful at matching coordinates and iteration
counts; full-window screenshots also differ in sampling resolution.

`intel_xelp_pixel` keeps the driver-facing contract narrow, at the cost of a
separate frontend and compiler path limited to its scalar subset and 24 KiB
body. `intel_xelp_poc` demonstrates the shared compiler pipeline and real GPU
control flow. Its user memory operations, spilling and other arithmetic types
are still unimplemented, and the native upload admission profile covers only
part of the backend's possible output. Direct full-resolution UI4 rendering
from this backend would need a frame-output dispatch ABI and compiler entry
contract; this example deliberately uses the existing, proven readback ABI.

Host validation interprets the emitted POC EU arithmetic and per-lane branch
paths against an independent Mandelbrot reference, checks native-kernel
admission, and runs the generated CPU code against UI4/dispatch mocks to verify
the complete uploaded image and resize/input/lifetime behavior. On the physical rig (30 October 2026), a temporary CPU reference checked all
4,800 samples of the initial 25-iteration view against the actual GPU readback:
zero mismatches within 0.00001. The sprite upload, GPU copy, and publication
returned zero, and the child reached its interactive `ready` loop. This checks
that view and kernel, rather than every control-flow shape the backend can emit.
The reference checker is diagnostic only and is not included in the demo.
