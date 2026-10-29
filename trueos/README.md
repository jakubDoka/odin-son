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
SDK explicitly; no SDK environment variable is required. This SDK is used only
to build the compiler on the host, and the installed SDK is not modified.
The default Blueprint contains no upstream SDK source assets. Import-free
programs and the embedded demos need no SDK collection files at runtime.

An intentional SDK-bearing package can still be produced separately:

```bash
python3 trueos/package.py trueos/build/odin-son.raw.o trueos/build/odin-son.bp \
    --sdk "$(/home/t4ce/Programmme/odin/odin root)"
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

On first launch it seeds `cpu-boids/main.odin` and
`hello/main.odin` under its app root, normally `apps/odin-son`. Existing files
are preserved. Each example has its own directory because Odin modules load
all `.odin` files in their directory. Add another `<demo>/main.odin`; the picker
discovers it automatically while visible, or immediately with `f`. Demo folder
names may contain ASCII letters, digits, `_`, and `-` (maximum 64 characters).

Use arrows or `j/k` to select and `q` to quit. For source directories, Enter
compiles and `r` queues the last successful build in its own headless VM. Outputs are
`demo-<name>.o` and `demo-<name>.bp` in the compiler app root. A queued launch
is not proof that a child started or completed.
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
