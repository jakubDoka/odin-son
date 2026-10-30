# Native odin-son Blueprint, built by upstream Odin

From the repository root:

```bash
bash trueos/build.sh
```

Outputs:

- `trueos/build/odin-son.o`: freestanding x86-64 ELF relocatable compiler.
- `trueos/build/odin-son.bp`: Blueprint with an argv-v1 `trueos_main` entry.

The sibling TRUEOS-Blueprints repository also supports the named native build
and its ordinary single-app publication path:

```bash
cargo bp odin-son
```

Run that command from TRUEOS-Blueprints. It rebuilds this checkout, copies the
package into `dist/odin-son.bp`, and publishes its SHA-256-qualified filename.
`TRUEOS_ODIN_SON_DIR` can select another source checkout.

The upstream Odin compiler compiles the shared parser, type checker, optimizer,
register allocators, and x64, ARM64, and WebAssembly emitters. The native build
uses the actual repository sources at build time. Its entry point and platform
bindings are in this directory. Desktop test helpers, Unicorn, WABT, and the
hot-reload helper are excluded from this compiler build.

The build stages an SDK under `trueos/build/sdk`, adapting runtime allocation,
formatted output, synchronization, and virtual memory for TRUEOS. It shares
unmodified SDK packages through symlinks. `ODIN_SDK_ROOT` can select an installed
SDK explicitly; no SDK environment variable is required. This SDK is used only
to build the compiler on the host, and the installed SDK is not modified.
The default Blueprint contains no upstream SDK source assets. Import-free
programs and the embedded demos need no SDK collection files at runtime.
The default native profile accepts project-local imports and `base:intrinsics`.
Other collection imports produce a diagnostic; SDK files left by an older
package do not silently expand that profile. External SDK collections require
an explicit `--odin-root <directory>` and remain subject to compiler limits.

An intentional SDK-bearing package can still be produced separately:

```bash
python3 trueos/package.py trueos/build/odin-son.raw.o trueos/build/odin-son.bp \
    --sdk "$(odin root)"
```

That explicit option embeds `base`, `core`, and `vendor` source collections
and the SDK license as `.trueos.assets`. The loader writes those files to the
compiler app root on each launch. Native binaries are excluded, and collection
imports remain limited by Odin SON's language and code-generation support.
The target is `freestanding_amd64_sysv`, with PIC, no red zone, one
code-generation module, and no ELF thread-local storage.

The build sets `-define:TRUEOS=true`. The shared type checker uses this setting
to sign-extend its packed 48-bit type pointers when unpacking them, preserving
TRUEOS allocations in the upper canonical address range. Desktop builds leave
the setting disabled by default.

The package contains no Linux interpreter, shared-library dependencies, or raw
system-call instructions. Packaging checks all undefined imports and relocation
types against the existing Blueprint loader's supported native interfaces.
Retired synchronous filesystem imports are explicitly rejected during packaging.

## Running on TRUEOS

Deliver `odin-son.bp` through the usual Blueprint/AppDB path. Source files and
imported source collections must be accessible through the Blueprint's existing
TRUEOSFS scope. The compiler uses the native `trueos_cabi_async_fs_*` operation
API for metadata, directory listings, file reads, and output writes. Its local
adapter follows `trueos::async_fs::block_on`: start an operation, poll status,
and call `trueos_cabi_poll_once()` while pending. This yields the Hull so the
kernel's async filesystem service can progress. Results are copied before the
operation is discarded; writes await commit completion before returning.

The existing sequential `load_program` completes these waits as it loads source
and imports. Type checking and code generation then operate on resident data.
Diagnostics go through regular Blueprint/Matrix output.

Launching without arguments (or with `--tui`) opens a persistent native compiler
screen. It uses the same existing terminal lease/surface/ANSI API as vendored
Crossterm, with the shared three-row `[16,16,16]` control background. There is no
Rust wrapper or new kernel transport. The compiler remains resident and yields
while idle; this is a running VM, not a saved checkpoint.

In the current Shell3, submit `§§odin-son` and Enter to fetch and launch the
published compiler. An AppDB-installed copy launches by exact name `odin-son`
in CMD mode.

On first launch it seeds `cpu-boids/main.odin`, `hello/main.odin`,
`gpu-tests/{main,cases}.odin`, and
`mandelbrot_gpu_cpu/{main.odin,shader.odin.source}` under its app root, normally
`apps/odin-son`. It also seeds `mandelbrot_gpu_poc` with `main.odin`,
`render.odin`, and `shader.poc.odin.source`. Seed baselines under `.odin-son-seeds/` let unchanged bundled
files follow package updates while preserving local edits. Each example has
its own directory because Odin modules load
all `.odin` files in their directory. Add another `<demo>/main.odin`; the picker
discovers it automatically while visible, or immediately with `f`. Demo folder
names may contain ASCII letters, digits, `_`, and `-` (maximum 64 characters).

Use arrows or `j/k` to select and `q` to quit. For source directories, Enter
compiles and `r` queues the last successful build in its own headless VM. Outputs are
`demo-<name>.o` and `demo-<name>.bp` in the compiler app root. Run exports the
Blueprint to `common/odin-son/` for the existing path-based launcher. A queued launch
is not proof that a child started or completed.
TAB parks the compiler terminal without exiting; select its slot and use `tui`
to return. Resize/reentry redraw the retained selection. Jobs run sequentially;
per-job temporary allocations and compiler arenas are freed before the next job.
Syntax and type errors are displayed in the latest-output panel.

Select `gpu-tests`, press Enter, then `r` for the five Odin-native iGPU checks.
The single `odin-son.bp` includes the import-free runner source, fixtures and
five precompiled GPU kernels. The resident odin-son compiles the CPU runner on
TRUEOS and packages `demo-gpu-tests.bp`; no separate GPU-test download or SDK
is needed. The child prints the per-test results and summary to Blueprint logs.
GPU kernels are embedded ahead of time; this entry does not recompile them.

Select `mandelbrot_gpu_cpu` and press Enter to compile its shader and CPU runner
on TRUEOS and queue one launch automatically. The compiler stays open; `r` can launch the compiled
demo again. The direct flag `--mandelbrot_gpu_cpu` seeds the examples, compiles
this entry, and queues one launch without opening the picker. The child opens
the original 320x240 UI4 Mandelbrot view: wheel zooms around the pointer,
left-button dragging pans, and Q/Escape closes it. It stays open until quit or
stopped; compiling it does not repeatedly launch children.
Brokered UI4 resize events replace the backing frame and redraw its full new
extent, preserving the complex-plane center and pixel scale. Pending resize
requests survive Busy responses, and the newest requested size wins. An
unchanged copy of the original bundled Mandelbrot runner upgrades when seeded;
edited source files remain preserved.

The import-free CPU source is `trueos/mandelbrot-demo/main.odin`; the shader
source is `trueos/mandelbrot-demo/assets/shader.odin.source`. Building the
compiler embeds both sources, without compiling the Mandelbrot shader on the
host. There is no shader snapshot, manifest verification, historical compiler
checkout, or shader preparation command. After editing bundled source, run
`cargo bp odin-son` in TRUEOS-Blueprints, relaunch the compiler and select the
example. You can also edit the seeded `shader.odin.source` on TRUEOS and press
Enter directly.

The picker checks every example for `shader.odin.source`. If present, it asks
the resident compiler to produce a fresh native Intel Xe-LP SIMD8 pixel body:

```text
odin-son --gpu-pixel <demo>/shader.odin.source -o <demo>/shader.eu
```

The picker generates `<demo>/kernel.odin` containing `native_pixel_code`, then
compiles the CPU runner and packages the Blueprint. Shader errors stop this
sequence and prevent launching an older build. The generated CPU runner
uploads those newly compiled bytes through the existing native-compute ABI.

The compiler is generic within its scalar pixel subset: exactly one tagged
procedure `(f32, f32) -> f32`, f32/bool locals, arithmetic `+/-/*`, comparisons,
boolean operations, ternary selection, and constant loops bounded to 1..64
iterations. It unrolls loops; the driver limits the resulting body to 24 KiB.
Unsupported syntax, division, register exhaustion, and oversized programs
produce diagnostics. Neither the iteration count nor the shader name/hash is
fixed in the compiler. See `bac/intel_xelp_pixel/README.md` for the backend and
ABI limits. The kernel must enable `odin-native-gpgpu`, as for `gpu-tests`.

Select `mandelbrot_gpu_poc` to compile a second Mandelbrot example through the
unchanged `bac/intel_xelp_poc` backend and ordinary frontend, SSA optimizer and
register allocator. Enter compiles and queues it automatically; the direct
flag is `--mandelbrot_gpu_poc`. Its shader keeps a real GPU loop and escape
branch. The existing eight-result dispatch API feeds CPU grayscale expansion and
a sprite upload followed by a GPU copy into the granted visual frame. It uses
compute publication with the completed GPU producer release. The old direct CPU
write path returned `-6` on a GPU-only visual frame. The demo uses at most
80x60 GPU samples for responsiveness.
See `trueos/mandelbrot-poc-demo/README.md` for sources, the backend comparison,
and why these presentation paths do not support a fair timing comparison.

Verified on the physical rig on 29 October 2026: selecting `gpu-tests`, compiling
and running produced all five passes (40/40 lanes). The generated Blueprint was
13,824 bytes. Evidence: `build/odin-son-picker-gpu-receipt.json` and
`build/odin-son-picker-gpu-hardware.log`. No kernel rebuild was required.

For source-free batch compilation, `--cpu-boids` compiles the byte-embedded
native boids source from `examples/boids-trueos/main.odin`. It needs no source
files or collections on disk. The build embeds this source with `#load`.

The compiler prints argc/argv, parse/load progress, type checking, code
generation, and successful filesystem commit messages. The embedded CPU batch output is:

- `apps/odin-son/boids.o`: generated x86-64 ELF object.
- `apps/odin-son/boids.bp`: loadable Blueprint with the same ELF payload, argv-v1
  entry ABI, and filesystem-independent flag.

Both writes use relative names inside the existing compiler app filesystem
root, confirmed as `apps/odin-son` in the baremetal launch log. They do not
prepend another `apps/odin-son` to the path. Named instances use the root assigned
to that instance. The generated Blueprint uses the loader's `main` symbol
lookup. It is stored for a later launch; the compiler does not execute it.

For a source file on disk, the application arguments are:

```text
program/main.odin -o output.o
```

`--odin-root` selects the directory containing `base`, `core`, and `vendor`
source collections; it defaults to `.` inside the app filesystem root.
Collection imports require separately supplied files or an explicitly
SDK-bearing package. With the usual compiler identity, the default collection
directories are `apps/odin-son/base`, `apps/odin-son/core`, and
`apps/odin-son/vendor`. No runtime `ODIN_ROOT` environment variable is required.
Programs without collection imports need no collection files. Relative module
imports are supported.

Other supported flags are `-target:amd64`, `-target:arm64`, `-target:wasm64`,
`-o:<optimization-level>`, `-debug`, `-check`, and `--help`. Compiler success
returns zero. Explicit source-file builds produce an object/module. The
embedded demo also packages its output as a Blueprint; it requires the amd64
target. `-o demo.o` changes its outputs to `demo.o` and `demo.bp`.

Each compiler invocation runs on its Blueprint Hull thread. Scratch state is
private to the image. The native synchronization adapter rejects contended
waits; this build does not start compiler worker threads. Stop requests are
checked between type checking and code generation, and the entry acknowledges
cleanup when it returns.

Arenas use one contiguous, zeroed, page-aligned guest allocation. Their default
combined backing is 48 MiB; commit/decommit bookkeeping does not change page
backing in this first port. Ordinary Odin allocations use TRUEOS allocation
imports. The existing guest heap profile must accommodate this backing plus the
loaded image, source data, and runtime allocations. An initial arena allocation
failure returns an error. The normal 128 MiB recommended generic Blueprint
profile provides initial headroom; actual VMX behavior still needs rig testing.

Arena sizes can be changed at build time, for example:

```bash
bash trueos/build.sh -define:TRUEOS_COMPILER_TYPES_MIB=32
```

Other settings are `TRUEOS_COMPILER_SCRATCH_MIB` (each of two scratch arenas,
4 by default), `TRUEOS_COMPILER_ARENA_MIB` (ordinary arena, 2), and
`TRUEOS_COMPILER_GRAPH_MIB` (8). The source reader accepts files up to 16 MiB
and rejects truncated directory listings.

## Local validation

After building:

```bash
ODIN=/home/t4ce/Programmme/odin/odin python3 trueos/test.py
python3 trueos/test_tui.py
ODIN=/home/t4ce/Programmme/odin/odin python3 trueos/test_for.py
python3 trueos/test_ide_build.py
```

The tests execute the upstream-built object through `test_host.c`, which mocks
the native C ABI on the development machine. They check the Blueprint envelope,
all three output targets, execution of generated x64 code, relative module
imports, diagnostics, and the complete native boids execution tests. Filesystem
requests stay pending until the adapter yields; reads return partial results,
and every request must be discarded, including failed uploads and commits.
A package containing a retired synchronous filesystem import must be rejected.
The explicit `--cpu-boids` demo runs with source filesystem reads forbidden, verifies both
stored outputs, and executes its generated boids code with checksum `127`.
The C harness is not included in the Blueprint. This validation does not boot
TRUEOS or exercise its real VMX/EPT and filesystem implementations.

## Upstream boundary

The fork merges `jakubDoka/odin-son` main through `f96547e`. All shared backend,
bindings, generators, desktop tooling, generated tests, and disassembly goldens
match that upstream revision. Its `bac/intel_xelp_poc` and `gpu-dispatch` work
are included unchanged. The previous fork-specific GPU backend, GPU frontend
hooks, GPU demos, and native GPU runtime entry paths have been removed.
Upstream GPU work is not connected to TRUEOS GPU submission by this adapter.

Only two shared compiler files differ from upstream:

- `odinc/typecheck/typecheck.odin`: canonical upper-half type pointers for
  TRUEOS, grouped procedure parameters for ABI declarations, and ordinary
  condition/initializer/post loops used by the minimal source subset.
- `odinc/gen.odin`: emission of those ordinary loops through upstream SSA.

The native entry, filesystem/runtime adapters, packaging, terminal UI, IDE
protocol, CPU demo, and host validation live under `trueos` and
`examples/boids-trueos`. The default package embeds no SDK collections.
`prepare.py` recreates the staged source directory on every build so removed
sources cannot survive into later builds. SDK and compiler compatibility
adjustments remain confined to the disposable staging area.

The desktop executable is a local build output rather than a tracked binary.
Build it from `odinc` before running `test.py`, or set `ODIN_SON_DESKTOP` to a
fresh desktop build. The installed Odin compiler must support the current
upstream sources; older compilers may require the explicit `Lane_Type.I16`
qualification already applied by `prepare.py` for native builds.

## IDE build protocol

Invoke `odin-son --ide-build request.json` with a version-1 source snapshot.
The adapter stages project files, compiles the entry and relative imports,
writes the requested Blueprint, and commits `result.json` with the original
workspace/build/revision identity, diagnostics, and artifact SHA-256.
`test_ide_build.py` covers successful compilation, module execution, and a
failed build with source diagnostics, without SDK assets in the compiler.

## Frontend loop support

The retained minimal frontend supports `for init; condition; post { ... }`
and `for condition { ... }`, including omitted clauses. The initializer owns
its loop scope; `continue` reaches the post statement and `break` skips it.
The hello seed prints a sum of 45 using this support.

`test_for.py` compares 19 cases against upstream Odin at all six optimization
levels. Set `ODIN_SON_DESKTOP` to exercise both native and desktop builds.
The upstream test corpus and goldens remain unchanged; this local adapter
suite covers the retained subset separately.

## Ahead-of-time GPU smoke kernels

Compile five representative upstream GPU tests on the host:

```bash
ODIN=/path/to/odin python3 trueos/compile_gpu_tests.py
```

This exports addition (`gpu_simplest`), comparison (`gpu_float_less`),
`gpu_if_else`, `gpu_loop_continue`, and `gpu_nested_loops` into
`trueos/build/gpu-tests`. Each test produces one raw Xe-LP SIMD8 `.bin` kernel.
The shared `manifest.json` records hashes, input registers as raw u32 bits,
eight expected result lanes, result types, and comparison tolerances. Inputs
use the same name-seeded PCG generator as upstream; expected results come from
host Odin executing the test source. Compilation does not open a GPU device.

The binaries include upstream's entry setup, result-store messages and EOT.
They use arguments in r1 onward, the result in r120, and output binding-table
entry 0. They still require compatible Gen12-LP dispatch state, input registers,
an output surface, submission, and completion/readback handling. They are
kernel payloads for a standalone Blueprint runner, not Blueprints themselves.
This step does not validate hardware execution or publish an application.

Use repeated `--test gpu_name` options to select another small set, or `--all`
for the entire corpus. A successful export removes obsolete kernels listed
in the previous output manifest. The host build requires Odin and GCC; its
temporary compiler sources and host executable are discarded after export.

## Standalone Odin-native GPU test Blueprint

```bash
ODIN=/path/to/odin bash trueos/build-gpu-tests.sh
python3 trueos/test_gpu_demo.py
```

The runner's CPU code is compiled by odin-son. The default build first uses
upstream Odin to bootstrap the host odin-son compiler, then invokes that
compiler on the import-free runner. To use an existing compiler directly, set
`ODIN_SON=/path/to/odin-son`. Application compilation uses empty collection
directories and includes no upstream Odin SDK, runtime, allocator or formatter.
Only debug sections are stripped during packaging; CPU instructions and data
come directly from odin-son's ELF emitter. The result has eight native imports:
seven TRUEOS ABI functions and `memset`.

The output is `trueos/build/odin-son-gpu.bp`. Launch `odin-son-gpu`
with no arguments or `--gpu-tests`. It performs five dispatches, one SIMD8
thread each, and prints the eight-lane comparison and actual/expected FNV-1a
checksums. A device error stops submission and reports the remaining cases as
skipped. A returned result is checked against the host-Odin reference values;
the Blueprint returns a failure status if any lane fails or a case is skipped.

This uses the separate `odin-native-gpgpu` route that served the mini-Mandelbrot
demo: an owner-scoped UI4 native-compute upload followed by the new
`trueos_cabi_ui4_scene_native_compute_dispatch_v1` readback operation. It opens
a 32x32 owner frame, runs the checks without a render loop, and closes it.
It has no ShaderToy or IDE integration. The current kernel must include that
new entry point; publishing the Blueprint alone does not update a running kernel.

The five kernels and their fixtures are checked-in snapshots under
`trueos/gpu-demo/assets`. Their SHA-256 values are verified during the host
build and printed for identifying a run. Kernel admission uses the supported
instruction/envelope profile, not these hashes or a five-test allowlist.
Supported complete kernels use direct GRF arithmetic, comparisons and branches,
with one final eight-lane BT0 media-block store and EOT. Dispatch accepts 1..=8
input registers and returns one eight-lane register. The driver supplies the
state and output surface, waits for its release fence, checks output canaries,
and quarantines an incomplete submission before another can reuse its backing.
The earlier arithmetic-body/pixel-render entry points remain available.

To replace the snapshots after another host compilation:

```bash
python3 trueos/prepare_gpu_demo.py --from-export trueos/build/gpu-tests
```

The host-mock test verifies exact binary uploads and input registers, success
reporting, mismatch detection, and stop-on-device-error behavior. It does not
execute the kernels on a GPU. The kernel admission checks can be run from the
sibling TRUEOS checkout with `python3 tools/testpy/test_native_xelp_kernels.py`.

### Baremetal functional run

On 29 October 2026 the published `odin-gpu-tests.bp` ran through the
Odin-native path on the physical rig: all five cases passed, 40/40 lanes,
with matching actual/expected checksums and clean VM teardown. The Blueprint
SHA-256 is `d35c33892652b0c6be7e3158a4788151c053434aa655118ba4b0a59534c6fdd6`.
Reproduce on a kernel with the new native dispatch entry point by submitting
`§§odin-gpu-tests` in Shell3. This is one deterministic input set per kernel.

| Case | Lanes | Actual = expected FNV-1a |
| --- | --- | --- |
| Addition | 8/8 | `d43e4df6e07bd16d` |
| Comparison | 8/8 | `6c87646ff7553914` |
| If/else | 8/8 | `def2042bfd8a6944` |
| Loop/continue | 8/8 | `0ed7f87ee82c810b` |
| Nested loops | 8/8 | `6c52c80c6ae0f5a3` |

The local machine-readable receipt and extracted hardware log are in the
sibling TRUEOS checkout under `tgt/rig-images/odin-native-qtd3_vsv/`:
`odin-native-receipt.json` and `odin-gpu-tests-hardware.log`.

### Runner and GPU kernels both compiled by odin-son

A separate baremetal run on 29 October 2026 exercised the new
`odin-son-gpu.bp`: odin-son emitted the CPU runner and the five GPU kernels.
All five tests passed (40/40 lanes), with the same checksums as the table above
and clean shutdown. This application is ahead-of-time compiled and embeds the
GPU kernels; it does not contain a runtime compiler.

The Blueprint is 12,360 bytes, SHA-256
`0ab1d47234cb93233fc425d1804d96d3ba88052c8d2e1a6ed78e367f23331862`.
Launch it with `§§odin-son-gpu`. Build provenance is in
`trueos/build/odin-son-gpu-build.json`; the hardware receipt and extracted log
are `trueos/build/odin-son-gpu-receipt.json` and
`trueos/build/odin-son-gpu-hardware.log`. The earlier `odin-gpu-tests.bp` run
used upstream Odin to compile the runner and remains a separate historical run.
