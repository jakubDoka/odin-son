# Minimal native Intel Xe-LP encoder

This is the first instruction-encoding layer for odin-son's native GPU backend,
fixed to IGA platform `12p1` (Xe-LP/Gen12). It emits real, uncompacted 16-byte EU
instructions in Odin, with no IGA, IGC, OpenCL, or SPIR-V dependency at emission
time. It also contains a BAC graph/register-allocation target for the bounded
scalar-call ABI described below.

Implemented:

- `encode_alu`: `mov`, `add`, `mul`, `cmp`, `sel`, `and`, `or`, `xor`, `shl`, `shr`.
- SIMD8/M0, F32 and U32, GRFs r0..r127, dword subregister zero.
- Packed `<8;8,1>` or scalar broadcast `<0;1,0>` sources and 32-bit immediates.
- Immediate source zero for `mov`; immediate source one for binary operations.
- Comparisons eq/ne/gt/ge/lt/le, flag f0.0, optional inverted predication,
  null comparison destinations, and write-enable execution.
- Explicit ALU instruction distance @1..@7; zero means no distance annotation.
- `encode_send`: immediate descriptors, explicit SBID allocation $0..$15,
  single/split payloads, DC0/DC1/sampler/gateway/thread-spawner SFIDs, and EOT
  for thread-spawner sends with a high-GRF payload.
- `encode_sync`: `sync.nop` for @distance, $id.src and $id.dst waits;
  `sync.allrd` and `sync.allwr` with implicit SBID masks.
- `write_instruction`: explicit little-endian serialization into caller storage.

Unsupported operands return an error and a zero instruction. Serialization checks
capacity before writing. The API does not allocate, acquire temporary registers,
or schedule instructions. The caller must assign registers and dependencies
before encoding. SEND validates generic lengths and register bounds, but its raw
message descriptors remain the caller's responsibility: it does not construct or
validate function-specific memory messages, addresses, or cache/fence policies.
`sync` dependency waits do not replace memory fences or workgroup barriers.

## Native scalar procedures

The compiler now accepts the ordinary Odin expression in
[`examples/gpu-scalar-trueos/main.odin`](../../examples/gpu-scalar-trueos/main.odin):

```odin
@(tag = "gpu")
process :: proc(a, b: f32) -> f32 {
    return a + b * b / a
}
```

There is no interpreter or shader compiler in this path. The frontend checks a
bounded expression and builds an ordinary BAC graph. `SPEC` uses the shared
register allocator with 128-bit masks, reserves the dispatch/message registers,
and assigns complete 32-byte GRFs to values. `Div` lowers before allocation to
integer restoring division with round-to-nearest-even, subnormal, zero,
infinity, and NaN handling. NaNs are canonicalized; CPU floating-point exception
flags are not transferred. The expansion trades code size for a small primitive
instruction foundation and avoids silently substituting approximate reciprocal
arithmetic.

The initial source subset is exactly two `f32` parameters, one `f32` return
expression, parameter references, numeric literals, parentheses, `+`, `*`, and
`/`. It accepts at most 64 source operations and two divisions. Other source
constructs receive diagnostics. Other ideal nodes, datatypes, general control
flow, GPU calls, and register spilling remain unimplemented in the target.

Regenerate the target's own spec with:

```sh
odin run bac/intel_xelp/gen
```

No shared `Node_Spec` API or allocator changes are required. GPU code generation
ends with a bounded result store, dataport fence, and EOT. CPU marshaling,
runtime calls, and ELF sections are implemented outside `bac/`, in
`gpu_native.odin`, `typecheck/gpu_native.odin`, and `elf.odin`.

The CPU stub references read-only, 64-byte-aligned native bytes in `.gpu.xelp`
and calls `trueos_cabi_vgpu_call_f32_v1`. It returns only after the runtime has
stored the result into its Odin-owned CPU result slot. A runtime error traps
instead of returning an uninitialized value. The existing boids body-emission
option below remains a separate legacy path.

### ABI v1

| Resource | Contract |
|---|---|
| Execution | SIMD8, one hardware thread, one active lane, one workgroup |
| r0 | Hardware thread header |
| r1, r2 | `a`, `b`, each replicated across eight dwords |
| r3 | Zero output-byte offsets, supplied by the trusted runtime |
| r4 | Return value; may also be allocated during arithmetic |
| r5..r111 | Allocator-owned arithmetic values |
| r126, r127 | Fence response and EOT header |
| Cross-thread data | 96 bytes; indirect storage padded to 128 bytes |
| Per-thread data / SLM / scratch | None |
| Native code | At most 24 KiB; entry at byte zero in the supplied code |

TRUEOS stages the code at batch offset `0x1000`, the IDD at `0x800`, binding
table at `0x840`, output surface state at `0x880`, and payload at `0x900`.
Binding zero exposes only four result bytes at result-page offset `0x100`.
The ordered completion cookie occupies the separate qword at result offset
zero. A CPU pointer is not a GPU virtual address.

The vGPU broker validates every instruction and initialized register, then
the driver copies the admitted code into its own carrier storage. Scalar calls
serialize on the existing system-compute lane. The tenant code buffer cannot
be modified or destroyed during the call; the GPU references only the driver's
staged copy. Completion requires the existing HDC/L3 drain, ordered post-sync
cookie, and context retirement proof. Ambiguous completion quarantines that
carrier and retains its backing. This path is currently gated to ADL-S
`4680:0c` and TGL `9a49:01`.

There is no implicit 100 MB pool or GPU heap allocator in this implementation.
Odin owns the CPU arguments/result storage. Existing vVideoMem registration is
the mechanism for mapping an Odin-owned arena when pointer/buffer kernels are
added; Odin can suballocate such an arena, while vGPU must retain mappings and
in-flight backing. Scalar v1 exposes no arena pointers or arbitrary memory
messages. Its internal code/result staging is driver-owned submission storage.

The input mechanism already used by TRUEOS Shadertoy is directly applicable to
future kernels: snapshot time and mouse into a uniform buffer before each
dispatch. In `src/intel/gpgpu/rcs/shadertoy.rs`, the uniform pointer is at
cross-thread byte 56; resolution is at uniform bytes 0/4/8, time at 12, mouse
at 16/20, and click position at 24/28. Those offsets belong to that kernel ABI,
not to the hardware or all Odin procedures. Continuous live input would need a
separate synchronized producer/consumer protocol.

Hardware references: Intel's [thread/EOT terminology](https://www.intel.com/content/www/us/en/docs/oneapi/optimization-guide-gpu/2025-0/terminology-002.html)
and [Gen12LP descriptor, walker, and PIPE_CONTROL definitions](https://github.com/intel/compute-runtime/blob/master/shared/source/generated/gen12lp/hw_cmds_generated_gen12lp.inl).
EOT terminates a thread; it does not carry a CPU return value or replace the
runtime's result buffer and completion fence.

### Scalar verification

```sh
ODIN=/path/to/odin python3 trueos/test_gpu_scalar.py
python3 ../TRUEOS/tools/testpy/test_odin_native_scalar.py
```

The scalar tests exercise six kernels and 601,734 arithmetic cases, including
subnormals, infinities, NaNs, and signed zero. They check actual CPU stubs against
a native-instruction interpreter, kernel admission, IGA roundtrip equality,
runtime error traps, and unsupported-source diagnostics. If a freestanding
compiler object is present, its output is also compared with the host compiler.
The driver harness checks production payload/command construction, concurrent
callers, and timeout quarantine with hardware calls mocked. **These are offline
checks, not proof of physical GPU execution.**

```odin
import xelp "bac/intel_xelp"

instruction, err := xelp.encode_alu({
    op = .Mul, type = .F32,
    dst = 20, src0 = xelp.reg(18), src1 = xelp.imm_f32(0.016666667),
    distance = 1,
})
assert(err == .None)
bytes: [16]u8
assert(xelp.write_instruction(bytes[:], instruction) == .None)
```

## Compiler foothold

Both the host and TRUEOS compiler accept:

```
-emit-xelp-body body.bin
```

For exactly one existing `@(tag = "gpu")` arithmetic procedure, this additionally
lowers its checked `gpu_add_scaled` operations to native `mul`/`add` instructions.
The current internal arithmetic words serve as compiler input here; native output
contains EU instructions, with no interpreter loop. The CPU object still uses
the existing interpreter dispatch path. Choosing this option does not change
that runtime path.

The body contract is deliberately fixed: SIMD8, r16=x, r17=y, r18=vx, r19=vy,
and r20 as a previously assigned temporary. Each register represents eight boids
in structure-of-arrays form. Every arithmetic instruction uses conservative @1
dependency control. Each scaled addition emits 32 bytes. The bounded existing
frontend accepts up to 16 operations, so a body is at most 512 bytes.

These are **body fragments**, not dispatchable standalone kernels: there is no
thread-input setup, lane/invocation index calculation, bounds masking, memory
load/store envelope, EOT, or kernel descriptor/dispatch metadata around them.
These legacy boids fragments do not use the scalar target described above.
A native boids memory envelope and its submission adapter remain future work.
The fragment-emission option adds no Blueprint VMCALLs or C ABI imports.

Example on the host, after building odin-son:

```sh
ODIN_ROOT=/path/to/odin ./odin-son examples/gpu-boids-trueos/main.odin \
  -o /tmp/boids.o -emit-xelp-body /tmp/boids-body.bin
iga64 -p=12p1 -d /tmp/boids-body.bin
```

On TRUEOS, with a compiler built from these sources:

```sh
odin-son --gpu-boids -emit-xelp-body boids-body.bin
```

The diagnostic explicitly states the boundary:

```
[odin-son xelp] stage=body-emitted target=12p1 bytes=64 complete_kernel=false artifact=boids-body.bin
```

## Verification

From the repository root:

```sh
ODIN=/path/to/odin python3 trueos/test_xelp.py
ODIN=/path/to/odin bash trueos/build.sh
ODIN=/path/to/odin python3 trueos/test_xelp_compiler.py
ODIN=/path/to/odin python3 trueos/test_gpu.py
```

`test_xelp.py` compares 718 instruction encodings byte-for-byte with installed
Intel IGA, exercises invalid operands/messages/dependencies and short buffers,
and checks the encoder for the freestanding target. Coverage includes register
boundaries, types, immediates, broadcasts, predicates, distance and SBID values,
SEND descriptor bit positions, split payloads, and EOT.

`test_xelp_compiler.py` checks real tagged source using both host and TRUEOS-ABI
compiler builds. It compares emitted bodies with IGA for coefficients
0.016666667, 0.0, and -0.5, proves the bytes change, checks embedded-source emission
without source filesystem access, and rejects missing/multiple GPU procedures,
missing flag values, and identical output names. The TRUEOS compiler runs under
its C host ABI harness for this test. No physical GPU dispatch is claimed.

Reference: Intel IGA's native model, not the separate vISA virtual instruction set:
https://github.com/intel/intel-graphics-compiler/blob/master/visa/iga/IGALibrary/Models/bxml/ModelXe.hpp
