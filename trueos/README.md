# Native odin-son Blueprint, built by upstream Odin

From the repository root:

```bash
ODIN=/home/t4ce/Programmme/odin/odin bash trueos/build.sh
```

Outputs:

- `trueos/build/odin-son.o`: freestanding x86-64 ELF relocatable compiler.
- `trueos/build/odin-son.bp`: Blueprint with an argv-v1 `trueos_main` entry.

The sibling TRUEOS-Blueprints repository also supports the named native build
and its ordinary single-app publication path:

```bash
ODIN=/home/t4ce/Programmme/odin/odin cargo bp odin-son
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
SDK explicitly. The installed SDK is not modified.
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

On first launch it seeds `gpu-boids/main.odin`, `cpu-boids/main.odin`, and
`hello/main.odin` under its app root, normally `apps/odin-son`. Existing files
are preserved. Each example has its own directory because Odin modules load
all `.odin` files in their directory. Add another `<demo>/main.odin`; the picker
discovers it automatically while visible, or immediately with `f`. Demo folder
names may contain ASCII letters, digits, `_`, and `-` (maximum 64 characters).

The picker also includes `gpu-mandelbrot`, backed directly by the embedded
source. Enter compiles its native EU arithmetic body to `mandelbrot.eu.bin`.
Press `r` to compile and display it through the brokered UI4 compute frame;
mouse dragging pans, the wheel zooms, and Q or Escape in the image returns to
the compiler TUI. Native dispatch requires the kernel's `odin-native-gpgpu`
feature and a supported Xe-LP device. This entry reserves its picker name and
does not read a `gpu-mandelbrot/main.odin` file from disk.

Use arrows or `j/k` to select and `q` to quit. For source directories, Enter
compiles and `r` queues the last successful build in its own headless VM. Outputs are
`demo-<name>.o` and `demo-<name>.bp` in the compiler app root. GPU boids creates
its own UI4 frame and runs continuously. The GPU island admits one owner at a
time. A queued launch is not proof that a child started or completed.
TAB parks the compiler terminal without exiting; select its slot and use `tui`
to return. Resize/reentry redraw the retained selection. Jobs run sequentially;
per-job temporary allocations and compiler arenas are freed before the next job.
Syntax and type errors are displayed in the latest-output panel.

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
source collections; it defaults to `.` inside the app filesystem root. With
the usual compiler identity, those directories are `apps/odin-son/base`,
`apps/odin-son/core`, and `apps/odin-son/vendor`. No runtime `ODIN_ROOT`
environment variable is required. Programs without collection imports need no
installed collections. Relative module imports are supported.

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
python3 trueos/test_gpu.py
python3 trueos/test_tui.py
ODIN=/home/t4ce/Programmme/odin/odin python3 trueos/test_for.py
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

## Tagged GPU boids experiment

Launch the native compiler with `--gpu-boids` to compile the byte-embedded
`examples/gpu-boids-trueos/main.odin` into `gpu-boids.o` and `gpu-boids.bp`.
The generated Blueprint uses x86 code for lifecycle and event handling, and a
small source-dependent GPU program for each boid's motion:

```odin
@(tag = "gpu")
boids_step :: proc(handle: u64, frame: u64) -> i32 {
    gpu_add_scaled(0, 2, 0.016666667)
    gpu_add_scaled(1, 3, 0.016666667)
    return 0
}
```

The initial backend compiles `gpu_add_scaled(dst, src, scale)` into four-word
instructions `[1, dst, src, f32_scale_bits]`. Registers 0 through 3 are `x`, `y`,
`vx`, and `vy`; instructions execute in source order. One to sixteen instructions
are supported. Unsupported statements, calls, signatures, register indices,
and nonfinite scales are compiler errors. `return 0` terminates the kernel;
the emitted x86 shim returns the runtime's submission result to its caller.

The shim calls the guest-local `phy_gpu_dispatch(handle, frame, words,
word_count)` helper in `examples/gpu-boids-trueos/phy.odin`. The helper uses
the existing async-fs write operation on `vFile:compute-boids`, awaits completion
with `trueos_cabi_poll_once`, reads its response before discarding the operation,
and adds no custom C ABI or VMCALL transport. A native GPU interpreter executes
those instructions after the
runtime's GPU flock update, then the GPU renders an RGBA8 UI4 surface. The
runtime owns the 100,000,000-byte island and PPGTT mapping. This is a minimal
bytecode backend, not general Odin-to-EU compilation or SPIR-V generation.
The runtime accepts each frame exactly once; `-11` requests a retry while the
surface is busy. The example retries the same frame and exits on q, escape,
interrupt, or stop. `--batch` on the generated application stops after 120 frames.

After the native build, `python3 trueos/test_gpu.py` checks compiler output,
existing async-fs imports, partial responses, operation cleanup, lifecycle, busy
retries and compiler diagnostics with host
mocks. Changing both scale literals to zero changes the compiled program and
the observed host state from `(7, 10)` to `(1, 2)` after 120 invocations. These
host checks establish source dependence; real GPU completion, PPGTT and UI4
presentation must be checked on TRUEOS separately. Compiler markers include
`[odin-son gpu-backend]` with emitted instruction words. Application markers
include `[odin-son gpu-boids]` for creation, first frame and lifecycle results.


The compiler also supports `--run-gpu-boids`, which commits both artifacts and
then queues `./gpu-boids.bp` through the existing launch-script API with a
headless destination. The child creates its own UI4 surface. Builds with
`-define:TRUEOS_GPU_BOIDS_DEFAULT=true -define:TRUEOS_GPU_BOIDS_AUTORUN=true`
select that experiment for explicit batch compilation; no-argument launch still opens the TUI; `--cpu-boids` selects the original
terminal demo. Artifact markers record exact byte lengths and FNV-1a hashes
only after filesystem commit, so downloaded artifacts can be matched to a run.

## Frontend loop support

The shared frontend accepts `for init; condition; post { ... }` and
`for condition { ... }`, including omitted clauses. The initializer has its
own loop scope; the condition must be bool, and `continue` reaches the post
statement before testing the next iteration. `break` skips the post statement.
Nested loops and labeled control flow use the existing SSA loop machinery.
This support is shared by desktop and TRUEOS builds, without source rewriting.
The hello seed uses `for i := 0; i < 10; i += 1` and prints a sum of 45.

`test_for.py` compares 19 cases against upstream Odin at every optimization
level. Set `ODIN_SON_DESKTOP` to a freshly built desktop compiler to exercise
both builds. The corresponding 23 generated tests in `TESTS.md` cover native,
ARM64, and WebAssembly execution plus rejection cases. Run with `DIFF=false`
when checking semantics without updating disassembly golden files. The tests
also caught an unsafe ARM comparison peephole: a single branch consumer does
not ensure NZCV survives from a hoisted comparison to the branch. Comparisons
now retain their bool register value.

# Native scalar GPU procedures

The compiler also accepts `@(tag = "gpu") proc(a, b: f32) -> f32` with one
bounded arithmetic return expression. It emits native Xe-LP code in `.gpu.xelp`
and CPU stubs using `trueos_cabi_vgpu_call_f32_v1`. The matching TRUEOS kernel
extension is required to execute the result. Backend, payload, completion,
ownership, and verification details are in
[`bac/intel_xelp/README.md`](../bac/intel_xelp/README.md#native-scalar-procedures).

Run `ODIN=/path/to/odin python3 trueos/test_gpu_scalar.py` after `trueos/build.sh`
to compare host/freestanding output and exercise the CPU/native-instruction
contract. This does not submit work to a physical GPU.
