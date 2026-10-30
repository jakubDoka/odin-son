# 3D Mandelbox through intel_xelp

Launch `odin-son`, select `mandelbrot_gpu_poc [3D Mandelbox]`, and press Enter.
The existing POC entry now compiles a volumetric Mandelbox and its CPU window
runner on TRUEOS. `--mandelbrot_gpu_poc` remains the batch command. The separate
`mandelbrot_gpu_cpu` entry still renders the 2D Mandelbrot.

- Left drag: orbit the fractal.
- Wheel: move the camera toward/away from the center, within distance 2..16.
- R: reset the initial camera (yaw 0.55, pitch -0.3, distance 6).
- Resize: preserve the camera and vertical field of view; render at the new
  full resolution with the correct aspect ratio.
- Q or Escape: close the demo.

The frame starts at 320x240 and is opaque. Rendering is event driven; the CPU
updates only camera parameters, window state and input. All ray marching,
fractal evaluation and shading run on the iGPU, with no CPU pixel expansion.

## Fractal math

`shader.poc.odin.source` evaluates an eight-iteration Mandelbox: box folds at
+/-1, sphere folds with squared radii 0.25 and 1, and scale +2.5. The derivative
accumulator follows the same sphere scaling and absolute box scale. A radius
bailout at 16 bounds work for distant points. The distance estimate is
`length(z)/derivative`.

Each SIMD8 lane traces its own perspective ray, using at most 100 distance
evaluations including normal probes. It advances with a 0.75 safety factor
and accepts a surface at distance estimate 0.0025. Three additional distance probes at offset 0.004 estimate its normal.
Directional lighting, step-count occlusion and distance fog produce grayscale
shading. Misses receive a dark background; rays exhausting the budget also
remain dark. The finite iteration/step budgets are an interactive approximation,
so very deep detail or a camera inside the fractal can show unresolved pixels.

This backend currently supplies f32 add, multiply, comparisons, control flow,
and reciprocal math. Bounded Newton iterations provide square roots; camera
sine/cosine are evaluated once per view by the CPU runner. No upstream Odin
core libraries or SDK source assets are needed by this demo.

## Compiler and renderer contract

The ordinary Odin SON frontend, type checker, BAC optimizer and register
allocator compile one `main` with 2..8 f32 arguments and one f32 return value,
without helper procedures. Arguments 1/2 are per-pixel coordinates; arguments
3..8 are optional view uniforms. This shader uses five: yaw cosine/sine,
pitch cosine/sine, and camera distance. The eighth argument is unused.
`--gpu-xelp` selects this pipeline; the old `--gpu-poc` flag and
`shader.poc.odin.source` filename remain compatible.

`trueos_cabi_ui4_scene_native_compute_render_v2(window, params, bytes)` takes
exactly 40 bytes: ten packed f32 values (origin.xy, positive pixel step.xy,
then six uniforms). The original render_v1 API and two-argument shaders remain
supported; their extra uniforms default to zero. Parameters must be finite.

On upload, the driver validates the complete kernel and retains its control-flow body
between its fixed header and store/EOT tail. It rejects accesses to driver
registers. The common allocation mask reserves r112..r119 and r121..r127;
arguments use r1..r8 and the result uses r120. Uniforms are preserved in r126
and restored on every grid-stride iteration. The only admitted out-of-order
math operation is the compiler's exact reciprocal instruction followed by its
matching SBID-2 wait. Arbitrary SENDs and memory access remain excluded.

The driver supplies coordinates, a SIMD8 grid-stride loop, opaque grayscale
conversion and masked framebuffer stores. Each thread owns eight adjacent
pixels and advances through rows by the walker row count. Padding to eight
pixels affects dispatch only; tail stores respect the real width and pitch.
Each batch covers at most 32,768 padded pixels, with the normal bounded
retirement and quarantine handling. Hashes identify code; they do not admit it.

Build and publish with `cargo bp odin-son` in TRUEOS-Blueprints. The package
contains source and compiles its shader on the node. Seed-baseline handling
preserves user edits. The camera ABI and reciprocal admission require the
updated TRUEOS kernel.

## Bare-metal validation, 30 October 2026

The normal menu flow compiled a 4,608-byte GPU kernel and a 15,944-byte native
application Blueprint on the node. Host and node shader bytes were identical.
Actual published GPU captures were compared with an independent f32 CPU
reference over 538,643 pixels:

| View | Pixels | Different grayscale pixels | Mean absolute gray error (0..255) |
| --- | ---: | ---: | ---: |
| Initial 320x240 | 76,800 | 31 | 0.00042 |
| Orbit plus resize to 323x241 | 77,843 | 330 | 0.00725 |
| Dolly at 320x240 | 76,800 | 0 | 0 |
| Resize to 640x480 | 307,200 | 177 | 0.00122 |

Native reciprocal math differs slightly from CPU division. At isolated fractal
boundaries this changes the hit/normal decision: 13 pixels across these views
differed by more than eight gray levels (maximum 77). This is a close numerical
comparison, not a claim of byte-identical CPU and GPU fractals.

The first menu-launched 320x240 render took 153 ms. Other observed 320x240
calls ranged from 28 to 802 ms; a 640x480 call took 866 ms. These are driver
call durations including submission, retirement and the first-frame checksum.
Concurrent UI work affects timing; they are not isolated GPU timestamps or an
FPS guarantee. Rendering remains event driven.

The five existing GPU cases passed all 40 lanes. The previous render_v1 API
and two-argument Mandelbrot shader still matched all 76,800 reference pixels
exactly. The compiled native runner also passed simulated input and Busy-retry
checks for orbit, dolly, R reset, resize, Q, and close/shutdown. The shared
project database was unchanged. Temporary checkers were removed; the main
interactive demo remained running. Evidence, captures and the validation
receipt are under the sibling TRUEOS checkout's `tgt/mandelbox/`.
