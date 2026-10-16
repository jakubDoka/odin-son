# Native odin-son Blueprint, built by upstream Odin

From the repository root:

```bash
ODIN=/home/t4ce/Programmme/odin/odin bash trueos/build.sh
```

Outputs:

- `trueos/build/odin-son.o`: freestanding x86-64 ELF relocatable compiler.
- `trueos/build/odin-son.bp`: Blueprint with an argv-v1 `trueos_main` entry.

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

Launching with no source argument compiles the byte-embedded native boids source
from `examples/boids-trueos/main.odin`. It needs no source files or collections
on disk. The build copies that source into the compiler staging directory and
upstream Odin embeds it with `#load`. The original Linux parity-test fixture is
not the embedded application.

The compiler prints argc/argv, parse/load progress, type checking, code
generation, and successful filesystem commit messages. The default output is:

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
```

The tests execute the upstream-built object through `test_host.c`, which mocks
the native C ABI on the development machine. They check the Blueprint envelope,
all three output targets, execution of generated x64 code, relative module
imports, diagnostics, and the complete native boids execution tests. Filesystem
requests stay pending until the adapter yields; reads return partial results,
and every request must be discarded, including failed uploads and commits.
A package containing a retired synchronous filesystem import must be rejected.
The no-argument demo runs with source filesystem reads forbidden, verifies both
stored outputs, and executes its generated boids code with checksum `127`.
The C harness is not included in the Blueprint. This validation does not boot
TRUEOS or exercise its real VMX/EPT and filesystem implementations.
