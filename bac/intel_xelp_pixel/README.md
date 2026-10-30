# Intel Xe-LP pixel body compiler

This target lowers the bounded scalar pixel IR from
`odinc/typecheck/gpu_pixel.odin` to native SIMD8 arithmetic. It is independent
of the complete-kernel test backend in `bac/intel_xelp_poc`.

The pixel ABI reads two f32 coordinates from r1/r2 and returns one f32 in r4.
TRUEOS owns the surrounding coordinate generation, surface writes, release,
and thread termination. Compiled bodies contain no memory messages or branches.

Frontend support covers f32/bool locals and assignments, arithmetic `+`, `-`,
`*`, comparisons, boolean operators, ternary selection, and constant loops of
the form `for i := 0; i < N; i += 1` with N in 1..64. Numeric literals in this
pixel subset are f32. Functions, pointers, memory access, division, and other
control flow are rejected with source diagnostics. There must be exactly one
`@(tag="gpu")` procedure with signature `(f32, f32) -> f32`; its name is free.

Lowering expands operations and prunes unused values. A separate liveness pass
allocates r5..r111 before encoding; it reports register exhaustion rather than
spilling. Encoding requires no temporary register allocation. Programs are
limited to 4096 frontend values and the driver's 24 KiB body size, so a loop
within the frontend bound can still exceed the body limit.

The resident compiler invokes this target with:

```text
odin-son --gpu-pixel shader.odin.source -o shader.eu
```

The picker performs that step for any example containing `shader.odin.source`,
then generates `kernel.odin` with the `native_pixel_code` string and compiles
the CPU runner. There are no binary snapshots or shader hash allowlists in
this path.
