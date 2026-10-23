# Runtime-compiled native Mandelbrot

The freestanding odin-son Blueprint embeds `main.odin` as source, parses and
compiles it while running on TRUEOS, and uploads the resulting native Xe-LP
arithmetic body to an owned UI4 frame. The kernel supplies coordinates, RGBA
packing, a bounded output store, fence and EOT. The recurrence and escape tests
come from the Odin source and use the existing BAC register allocator.

Build the compiler from the odin-son repository:

```sh
ODIN=/home/t4ce/Programmme/odin/odin bash trueos/build.sh
python3 trueos/test_mandelbrot.py
```

Output: `trueos/build/odin-son.bp`. It uses the native compiler's normal
Blueprint heap profile and needs no source files or SDK collections at runtime.

For normal deployment, run `cargo bp odin-son` from TRUEOS-Blueprints, then
`§§odin-son` and Enter in Shell3. Select `gpu-mandelbrot`; Enter emits the EU
body, and `r` compiles and displays it through the native compute bridge.

For AppDB launchers that supply only an application name, build the dedicated
verification Blueprint:

```sh
ODIN=/home/t4ce/Programmme/odin/odin bash trueos/build-mandelbrot.sh
```

This creates `trueos/build/odin-mandelbrot.o` and `odin-mandelbrot.bp` with
`TRUEOS_MANDELBROT_VERIFY_DEFAULT=true`. Launching that Blueprint without
arguments runs the 25/16-iteration verification. The helper then rebuilds the
normal `odin-son.o`/`.bp`, whose no-argument entry opens the compiler TUI.

The matching TRUEOS kernel must be built with `--features odin-native-gpgpu`.
The two versioned native-compute imports return `-95` when that feature is off.
This explicit experiment admits bounded generated arithmetic instructions
without requiring a preinstalled executable SHA. It retains the existing
compute submission, completion and exact UI4 surface-release machinery.

Application arguments:

- `--gpu-mandelbrot`: compile the embedded source and commit
  `mandelbrot.eu.bin` in the application root. The file is the SEND-free body;
  the runtime supplies its fixed launch envelope.
- `--run-gpu-mandelbrot`: compile, upload and display a 320x240 image. Drag
  with the primary button to pan, scroll to zoom, and use q or Escape to exit.
- `--verify-gpu-mandelbrot`: compile and render 25- and 16-iteration source
  variants sequentially in the same process, then close the test window.

The verification command prints different body hashes. The kernel logs an
unfiltered completion marker, body SHA and actual visible framebuffer FNV
for each registered program. Both retirements and differing framebuffer hashes
are needed to establish the physical source-dependent execution result.

The target is Xe-LP SIMD8 with inputs in r1/r2, a grayscale f32 result in r4,
and compiler temporaries r4..r111. The driver's header/offset/high registers
are reserved. The current hardware admission is ADL-S `4680:0c` and TGL
`9a49:01`. GPU source loops require a literal positive bound of at most 64
and are unrolled; this is a bounded Odin subset rather than a GLSL frontend.

Host validation executes the actual freestanding compiler with source reads
forbidden, interprets its emitted native arithmetic and compares 25/16 variants
against an independent C implementation. Separate driver and ownership tests
live in TRUEOS's `tools/testpy/test_odin_generated_pixel.py` and
`test_odin_native_bridge.py`. These checks mock hardware; they do not establish
physical GPU execution.

Physical execution passed on ADL-S `4680:0c` on 2026-10-22. The runtime-compiled
25- and 16-iteration bodies produced GPU framebuffer FNV-1a64 values
`cfa5852b3c69e7a6` and `8a797794491ba3af`, exactly matching the independent C
reference for all 320×240 visible pixels. The ordinary published Odin menu also
emitted and executed the 25-iteration body. TRUEOS preserves the kernel identity
and completion records in `docs/experiments/odin-runtime-mandelbrot-20261022.json`.
