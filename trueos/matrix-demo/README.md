# Odin matrix CPU + GPU demo

Build one Blueprint from the odin-son repository:

```sh
python3 trueos/build-matrix-demo.py
```

Output: `trueos/build/matrix-demo/odin-matrix.bp`. Upstream Odin bootstraps the
compiler tools; Odin SON's frontend, SSA and backends emit both application CPU
code and the embedded Xe-LP SIMD8 integer multiply-accumulate kernel. The built
application contains no runtime compiler or SDK. `ODIN` selects the bootstrap
compiler; `ODIN_SON` optionally selects an existing CPU compiler executable.

The TRUEOS kernel must contain `trueos_cabi_matrix_compute_v1` and
`trueos_cabi_matrix_compute_capacity_v1`, with `odin-native-gpgpu` enabled.
The driver currently admits the same device/revision pairs as native scalar
compute: `4680:0c` and `9a49:01`. Install/launch the generated Blueprint through
the usual app workflow. Build does not publish it or restart a machine.

Application arguments:

```text
odin-matrix --n 64 --split 50 --mode both --rounds 4
odin-matrix --n 128 --split 25 --mode wrap --seconds 60
odin-matrix --n 64 --split 75 --mode sat --seconds 60
```

Defaults are N=64, split=50, both modes, four dependent squares per batch,
and continuous execution. `--help` prints the options. N is bounded to 1..128;
rounds is 1..4. Each producer creates a fresh full-range u32 matrix using its
own nonzero xorshift32 state. A batch computes A², A⁴, A⁸, A¹⁶, according to
the requested round count, and then starts a new random chain.

Modes have identical semantics on both devices:

- `wrap`: each multiply-accumulate keeps its low 32 bits.
- `sat`: each unsigned multiply-accumulate clamps to `0xffffffff` on overflow.
- `both`: each device alternates complete batches between wrap and saturation.

These are ordinary u32 matrices, not packed VNNI input formats. The CPU kernel
currently uses scalar wide integer arithmetic; the GPU uses SIMD8 word-source
products and dword arithmetic. There is no claim of AVX/VNNI acceleration or
SIMD16 execution. Saturation does not skip later dot-product operations.

`--split 50` activates ceil(eligible CPU carriers / 2) workers, each continuously
computing, and requests a 50% GPU dispatch duty cycle. Zero requests GPU only;
100 requests CPU only. The GPU controller waits in proportion to measured batch
time. These are resource requests, not a guarantee of hardware occupancy or an
equal number of mathematical operations. CPU admission uses the ordinary
round-robin general AP carriers; BSP, UI and reserved service carriers are not
included. Other applications and the shared RCS engine can affect throughput.

While running, `+`/`-` changes CPU share by five percentage points, `w` selects
wrap, `s` selects saturation, `b` alternates both, and `q` stops. Changes apply
at batch boundaries. Shell input must be attached for these keys; timed runs
also work without input. Cooperative Blueprint stop is checked between batches,
and CPU workers yield after each row.

Each CPU worker and the GPU producer retain four completed batch matrices in
private rings. Publishing a fifth batch overwrites the oldest completed matrix;
there is no consumer queue, retained output growth, or per-matrix printing.
The ring never aliases an in-flight input or output. Memory is bounded to about
384 KiB per producer, plus thread stacks, independent of run duration.

ShellIO receives startup status, a once-per-second heartbeat, and a final
heartbeat: completed squares per device/mode, squares per second, overwritten
history and checksums. Throughput includes RNG, copying and synchronization.
There is no cockpit or UI4 window. The GPU call moves whole matrices and runs
N*N SIMD lanes across the grid; it does not submit each matrix element separately.
The driver holds two pinned, guarded buffers through fence retirement and swaps
them for dependent squares. Errors stop the run; there is no CPU fallback for
GPU work.

Startup compares CPU/GPU results for `[[1,2],[3,4]]`, full-width overflow, and a
random N=7 matrix, in both modes, including two dependent squares through the
GPU buffers. Failure prevents the stress loop. Host validation
can check emitted instructions and buffer addressing from the sibling TRUEOS repo:

```sh
python3 tools/testpy/test_native_matrix.py
```

`build.json` records compiler, source and artifact hashes and explicitly marks
hardware execution as unverified. The instruction model and host mocks cannot
establish GPU instruction legality, cache visibility, EU occupancy, throttling,
or simultaneous device utilization; those require a run on TRUEOS hardware.
