# Eight-lane Intel Xe-LP kernel API in Odin

```sh
odin run gpu-dispatch
odin run gpu-dispatch -- 123 456
odin run gpu-dispatch -- 0xffffffff 1 /dev/dri/renderD128
```

Run these commands from the repository root. Only Odin and the Linux `i915`
kernel driver are required; there are no external library dependencies and no
root requirement if you have read/write access to the render node.

The reusable package is `gpu-dispatch/gpu`; the program above is an addition
example using that API. Dispatch is generic over kernels, but still targets
**this machine's Alder Lake-P Iris Xe, PCI ID `8086:46a6`** (Gen12 / Xe-LP).
Other PCI IDs and the `xe` kernel driver are deliberately rejected.
“Xe” also names newer, incompatible instruction sets.

## API

Import `gpu-dispatch/gpu` using a path relative to your package. The example
in this directory uses `import "gpu"`. Given the native code in `ADD_CODE`
from `kernels.odin`:

```odin
run :: proc() -> gpu.Error {
	device := gpu.open() or_return
	defer gpu.close(&device)

	code := ADD_CODE
	kernel := gpu.Kernel {
		code            = mem.slice_data_cast([]u32, code[:]),
		parameter_count = 2,
		result_count    = 1,
	}
	parameters := [?][8]u32 {
		{37, 38, 39, 40, 41, 42, 43, 44},
		{5, 5, 5, 5, 5, 5, 5, 5},
	}
	results: [1][8]u32
	gpu.execute(&device, kernel, parameters[:], results[:]) or_return
	fmt.println(results[0])
	return nil
}
```

Here `mem` is `core:mem`; the cast views the example's `[4]u32` instruction
groups as the flat `[]u32` accepted by `Kernel.code`, without allocating.

- `open(path := "/dev/dri/renderD128") -> (Device, Error)` creates a context.
- `close(^Device) -> Error` releases it; repeated close is harmless.
- `validate(Kernel) -> Error` checks metadata, lengths, and supported limits.
  It does **not** decode or validate ISA instructions.
- `execute(^Device, Kernel, [][8]u32, [][8]u32, timeout_ns := 2_000_000_000)`
  synchronously executes the kernel and copies its results into the caller's
  slice. It returns `Error`, with `nil` meaning success. Results are unchanged
  on failure. The library never prints diagnostics or uses a CPU fallback.

Keep one `Device` open for repeated calls. Treat it as an owning handle: do not
copy it, modify its fields, or concurrently execute/close it. Different devices
can be used independently. Kernel code is borrowed for the duration of each
call; there is no persistent uploaded-kernel object or code cache yet.

Execution errors are either an `Error_Code` or a `System_Error` containing the
syscall operation, Linux errno, and (for ioctls) the complete request number. Host
validation failures do not invalidate the device. A completion, readback, or
output-overrun failure marks the device failed; close it and open a fresh one
before submitting again. A timeout/interruption does not cancel the old job.

## Disassembly

`disassemble(code: []u8, allocator := context.allocator, library_path := "")`
returns `(assembly: string, error: Error)` using Intel Graphics Assembler's
shared-library C API. It decodes Xe-LP (`12p1`) instructions, including compacted
instructions, without opening a GPU device or starting a subprocess.

```odin
code := ADD_CODE
assembly, err := gpu.disassemble(mem.slice_to_bytes(code[:]))
if err != nil {
	fmt.eprintln(err)
	return
}
defer delete(assembly)
fmt.print(assembly)
```

The caller owns the returned string and must free it with the supplied
allocator. The library and decoder context are released before returning;
the string remains valid independently of them. Empty input returns an empty
string successfully. Nonempty input must be a multiple of eight bytes and
no larger than `MAX_KERNEL_BYTES`. Invalid encodings return an error and no
assembly string.

Install Intel's IGA library (usually distributed with Intel Graphics Compiler)
to use this optional function. By default it searches the dynamic loader's
library paths for `libiga64.so.2`, `libiga64.so.1`, then `libiga64.so`. Supply
`library_path` to select a particular library. GPU execution does not require
IGA, and importing this package does not load it.

Errors include `Error_Code.Disassembler_Unavailable` when loading fails,
`Error_Code.Invalid_Disassembler` when required C API symbols are missing,
`Disassembler_Error` with the failing IGA operation and its numeric
`iga_status_t` status, or an allocator error when copying the returned string.

## Kernel ABI

The API accepts a complete native Xe-LP EU program, not source code, SPIR-V,
OpenCL binaries, or arbitrary Odin functions. The program must follow this ABI:

| Item | Convention |
| --- | --- |
| Dispatch | One workgroup containing one hardware thread |
| SIMD | `Kernel.simd`: `.SIMD8` (default), `.SIMD16`, or `.SIMD32`; all lanes enabled |
| `r0` | Hardware dispatch payload; preserve what is needed for thread termination |
| Arguments | One `[8]u32` per GRF starting at `r1`; argument `i`, lane `j` is in `r(1+i).j` |
| Results | Write consecutive eight-dword vectors into binding-table entry 0, starting at byte offset 0 |
| Output surface | Linear, one-row `R8_UNORM` 2D surface for DC1 media-block writes, 4096-byte pitch |
| Termination | The supplied code must issue its own end-of-thread message |

Arguments are loaded through CURBE, with all eight lanes of each argument
contiguous in its register. Result `i`, lane `j` is at byte offset `32*i + 4*j`.
For results, use DC1 media-block writes at X byte offset `32*i`, Y=0. This
output binding is not a raw/untyped buffer surface. The example copies `r0`
into its message header, stores a 32-byte block (`r4.2 = 31`), and sends a
thread-spawner EOT.
**Returning a value in a GRF alone is not sufficient.**

Each `[8]u32` represents eight independent 32-bit lane values; counts refer to
whole vectors, not individual words. `.SIMD16`/`.SIMD32` do not change this
layout: a wider instruction spans two/four consecutive registers, so its
operands must be arranged accordingly.

Lanes carry raw bits, without numeric conversion or hidden packing. `u32`,
`i32`, and `f32` each use one word per lane; for floats/signed values use Odin's
`transmute`. Hardware support for arithmetic on a particular type is the
kernel author's concern.

For example, set `parameters[0][0] = transmute(u32)f32(1.5)` and interpret a
returned float with `transmute(f32)results[0][0]`. The dispatcher itself does
not know the lane types or what computation the kernel performs.

`parameter_count` and `result_count` must exactly match the slice lengths.
The kernel must write its declared results and must not write beyond them.
The output page is initialized with a canary and the undeclared tail is checked
after execution. This can detect accidental over-stores, not prove that every
result was written or that the computation was correct. Unwritten words retain
the initialization pattern; semantic verification belongs to the caller.

Current limits:

- Up to eight argument vectors (eight GRFs) and 128 result vectors (one page).
  Zero arguments and zero results are supported.
- Up to 16 MiB of code, a nonempty multiple of eight bytes. Compacted and
  uncompressed instructions can be mixed. The entry point is the first byte.
- Positive completion timeout up to ten seconds; default two seconds.
- No scratch/spill allocation, SLM, barriers, samplers, extra surfaces, or
  external-buffer/pointer arguments. Temporary values must fit in GRFs.

## Addition example

`kernels.odin` contains seven hardcoded instructions, with matching assembly
comments. Its register-to-register arithmetic is:

```asm
add (8|M0) r5.0<1>:ud r1.0<8;8,1>:ud r2.0<8;8,1>:ud
```

It adds two `[8]u32` arguments lane by lane and returns one `[8]u32`, with
addition modulo 2^32. The command-line operands `a` and `b` initialize lane `i`
to `a+i` and `b`, respectively, also modulo 2^32. `main.odin` only uses the
public API and performs CPU addition solely to verify all eight GPU results.
The encodings were checked with Intel Graphics Assembler (`iga64 -p=12p1`).
No addition-specific instructions or expected results exist in the library.

## Driver interface and runtime packaging

There is **no Vulkan, OpenGL, OpenCL, Level Zero, shader compiler, assembler,
or libdrm dependency at runtime**. The program talks to `/dev/dri/renderD128`
with Linux DRM ioctls directly:

1. Check the driver, PCI ID, softpin support, and per-process GPU address space.
2. Reuse the open i915 context and create per-call GEM objects for output,
   state, and commands.
3. Assign page-aligned GPU virtual addresses in that context's address space.
4. Pack the constant data, surface state, binding table, padded instruction
   heap, and interface descriptor at runtime. Code size and argument count
   determine the offsets, allocation sizes, and constant-register read length.
5. Build `PIPELINE_SELECT`, `STATE_BASE_ADDRESS`, `MEDIA_VFE_STATE`, constant
   and descriptor loads, a single-group `GPGPU_WALKER`, cache flushes, and
   `MI_BATCH_BUFFER_END` at runtime.
6. Upload through write-combined `GEM_MMAP_OFFSET` mappings, submit with
   `GEM_EXECBUFFER2`, wait with `GEM_WAIT`, and read back through a mapping.
   `GEM_SET_DOMAIN`, a CPU memory fence, and GPU cache flushes synchronize
   access. The older `GEM_PREAD/PWRITE` ioctls are not supported on Alder Lake.

No ELF/Zebin or other shader-file container is needed for this direct driver
path. Only the EU kernel is a pre-encoded blob; the dispatch packaging is not.

Per-call GEM objects and mappings are released on success and failure.
The caller owns the open device/context until `close`.

**Raw GPU programming is hardware-specific:** changing instructions or state
incorrectly can hang/reset the GPU and disrupt the desktop. A userspace wait
timeout does not cancel a submitted GPU job.

## References

- [Intel Xe-LP programmer's reference manual: preface](https://cdrdv2-public.intel.com/703034/intel-gfx-prm-osrc-tgl-vol-01-preface-2.pdf)
- [Linux i915 UAPI](https://github.com/torvalds/linux/blob/master/include/uapi/drm/i915_drm.h)
- IGT's [Gen12 kernel](https://github.com/sudo-su-f/igt-gpu-tools/blob/master/lib/i915/shaders/gpgpu/gen12_gpgpu_kernel.asm)
  and [command/state definitions](https://github.com/sudo-su-f/igt-gpu-tools/blob/master/lib/gpu_cmds.c)
- [Intel's Gen12-LP command layouts](https://github.com/intel/compute-runtime/blob/master/shared/source/generated/gen12lp/hw_cmds_generated_gen12lp.inl)
