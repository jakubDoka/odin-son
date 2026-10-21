# BCS0 copies from Odin: architecture review

Status: proposal, checked against the local TRUEOS and odin-son sources on
2026-10-21. No guest copy API or hardware dispatch is implemented by this
document. The requested stop before architecture changes applies to the
runtime/VGPU extension below.

BCS0 is a useful smaller scope than compiling general GPU functions. The first
demo can be an ordinary Odin program submitting explicit asynchronous copies
over its own memory. It needs no new BAC target, Node_Spec, register allocator,
GPU procedure tag, or GPU text section in ELF. Existing CPU code generation
can compile calls to a runtime library. Intel command encoding and submission
stay in TRUEOS's existing copy driver.

## Verified foundation and gaps

Paths in this section are relative to the sibling `TRUEOS` repository.

| Area | Existing implementation | Work needed for an Odin guest |
| --- | --- | --- |
| Fast copy | `src/intel/copy/blt.rs`: `queue_guc_bcs0_rgba_copies` emits `XY_FAST_COPY_BLT` through the service-owned GuC BCS0 lane. | An opaque guest buffer-copy submission, with ownership validation. |
| Completion | The driver requires its ordered post-sync marker, saved context HEAD at published tail, and successful software timeline retirement before normal reuse. | Associate that exact completion with the submitting guest's queue and buffer reservations. |
| Shared consumers | `src/r/services/vcpy_service.rs` fronts the lane; UI4, Gridpaper and screenshots already use it. Admission returns Busy while occupied. | Bounded guest admission and independent guest progress; Busy is not a completed copy or guaranteed scheduling fairness. |
| Guest memory | `src/gpu/vgpu.rs`: `create_vvideo_mem` pins a guest allocation and maps its physical page list into that tenant's GPUVM. | Odin bindings and a copy-driver mapping path for those page lists. |
| Addressing | Tenant buffer GPU VAs start at `0x1_0000_0000` (4 GiB). The current copy helper accepts addresses below 1 GiB in a separate service PPGTT. | Private low-address aliases for copy views, or a new tenant-specific BCS context. Passing the tenant VA directly cannot work with this helper. |
| Backing | `GucBcs0RgbaSurface` describes one contiguous physical extent. Guest backing is a list of physical pages. | Map and validate each page of the requested view. Do not substitute its first page as a contiguous allocation. |
| Heap size | `Quota::GUEST` is 32 MiB; PRESENT guests have a separate 512 MiB quota. | An explicit copy/compute heap quota if 100 MB is required. Requesting PRESENT merely to obtain that quota would be the wrong contract. |
| Public API | `crates/trueos-v/src/vgpu.rs` exposes Copy queues, `vVideoMem`, flush/invalidate and timelines. `submit_control_nop` explicitly does not execute GPU work. | A real copy submission and guest completion contract. Copy capability alone does not provide it. |

`src/intel/gpgpu/rcs/payloads.rs` belongs to shader dispatch on RCS0. A BCS0
copy does not use those kernel argument payloads. The existing odin-son GPU
example's `vFile:compute-boids` transport is also not a general copy interface;
the inspected TRUEOS async-FS virtual-write registry does not expose it.

## Memory layout and ownership

On this integrated GPU, CPU and GPU accesses can name the same system-memory
pages. There is no required upload to a separate GPU memory chip. CPU virtual
addresses, physical pages, tenant GPU VAs and copy-service GPU aliases are
nevertheless different address spaces.

The proposed layout keeps allocations under Odin's control:

```text
one Odin allocation, aligned to 4096 bytes
  CPU guest VA H + offset
        |
        +--> pinned physical pages P[0], P[1], ... (not necessarily contiguous)
                   |                         |
                   v                         v
        tenant GPUVM VA G + offset     service BCS PPGTT aliases
                                      S + source-view offset
                                      D + destination-view offset

Odin: suballocations, typed slices, free list, application access discipline
VGPU: tenant handle, page pins, quota, admitted-job reservations, teardown
BCS:  private command/context/result storage, aliases and exact retirement
```

The proposed service aliases are internal addresses, never guest-supplied
physical addresses. Reserve bounded, disjoint windows outside BCS control
addresses. Each admitted job maps the resolved source and destination page
lists into these windows. The existing exclusive lane and saved-context check
must cover alias mutation, encoding, execution and retirement. This trades
per-job alias/TLB work for reuse of the working copy lane. A per-tenant BCS
context using the existing tenant GPUVM is a larger alternative.

For a requested decimal 100,000,000-byte allocation, page registration covers
100,003,840 bytes (24,415 pages). Expose the requested length to Odin; padding
is not additional application storage. The VGPU quota must cover the rounded
allocation, and the VM heap profile must also leave room for the executable
and other allocations. A 100 MiB heap would instead be 104,857,600 bytes.

Two nonoverlapping suballocations of this one heap must be legal copy views.
The current whole-surface overlap rejection cannot simply be reused on two
descriptors for the whole heap. The new path must validate the actual views
and their physical pages. A small first version can require page-aligned,
page-disjoint views and reject overlapping source/destination storage. That
supports an Odin-managed heap without promising memmove semantics.

Odin must reserve a source for GPU reading and a destination for GPU writing
until the exact job completes. CPU reads may share a source only when no
writer exists. Destination CPU access and conflicting GPU jobs must wait.
Initially the kernel can conservatively reserve the whole registered buffer;
Odin can still suballocate, but simultaneous jobs within that heap would wait.
Range-based concurrent reservations can follow when needed.

Pinning prevents freeing/reusing backing; it does not stop a program writing
through a live CPU pointer. Odin's runtime and the application must enforce
the access discipline. Flush/invalidate handle visibility and are not locks.
The existing `cache_maintain_vvideo` checks `in_flight`; the copy path must
actually maintain that count for it to protect the new jobs.

## Proposed first API

This is an API sketch for review, not a declaration of existing imports:

```odin
heap := gpu_heap_create(device, 100_000_000)
source := gpu_alloc_rgba8(heap, width, height)
destination := gpu_alloc_rgba8(heap, width, height)

// Fill source through its CPU view before submitting it.
job := gpu_copy_rect_async(queue, destination, source, rectangle)
gpu_wait(job)
// A successful wait includes acquisition for destination CPU reads.
```

The async operation reserves views, releases CPU-written source data and
prepares destination caches before GPU submission. `gpu_wait` yields using
the existing runtime facilities and acquires destination caches after proven
completion. Submission and polling remain separate so the CPU can do useful
work while BCS executes. Errors must be explicit in the real API; the sketch
omits result handling only to show the call sequence.

One possible versioned descriptor reuses the existing opaque `BufferSlice`
shape. A C-layout definition would be 80 bytes on the current ABI:

| Offset | Field | Type |
| --- | --- | --- |
| 0 | source: buffer handle, offset, extent | 3 × u64 |
| 24 | destination: buffer handle, offset, extent | 3 × u64 |
| 48 | source pitch in bytes | u32 |
| 52 | destination pitch in bytes | u32 |
| 56 | copied width in bytes | u32 |
| 60 | copied height | u32 |
| 64 | flags, initially zero | u32 |
| 68 | reserved, zero | 3 × u32 |

The source and destination may use the same buffer handle and different
nonoverlapping views. No host pointer, physical page address, Intel opcode or
GPU VA crosses this API. The kernel resolves handles under the caller's
principal, checks generation/epoch, Copy queue, usage bits and slice bounds,
and takes reservations before publishing hardware work.

For the first version, require:

- Page-aligned view offsets and page-disjoint source/destination storage.
- Linear, uncompressed, identical 32-bit storage; no format conversion.
- Positive width divisible by four; pitches divisible by four, at least the
  copied width, and at most 65,532 bytes; height at most 65,535.
- Checked arithmetic for `(height - 1) * pitch + width_bytes` within both view
  extents, and for each view's `offset + extent` within its registered buffer.
- One rectangle per submission. Batching can follow with the required
  inter-copy dependency flushes, rather than treating arbitrary packets as
  independent. Intel specifies extra flushes for some dependent fast blits.
- A pre-submission Busy result that reserves no hardware work. A successful
  submission returns an exact guest timeline/job identity.
- Failure after ambiguous submission or completion retains every involved
  allocation and alias. Dropping a waiter, timing out, closing the device or
  stopping a VM cannot make late DMA safe. Reuse needs actual retirement or
  an established reset/teardown proof.

This first API is sufficient for images, buffers of 32-bit values and CPU/BCS
overlap. Arbitrary byte counts, unaligned byte pointers, overlap, implicit
ordinary `copy`/memcpy lowering, tiled resources and shader execution are
separate extensions. Ordinary synchronous Odin copy cannot silently acquire
asynchronous lifetime semantics.

## Changes requiring agreement

The recommended choice is **an explicit Odin runtime API backed by the
existing service-owned BCS lane**, with page-list aliases for guest views.

That requires a new versioned VGPU copy operation in the public/native ABI
and guest transport, broker job/reservation/completion handling, and a
page-list-aware internal BCS mapping path. The byte quota for copy heaps must
be chosen explicitly; 128 MiB for admitted headless copy clients is the
proposed ceiling for the 100 MB demo. The VM's CPU heap budget remains a
separate constraint. None of these operations belongs in BAC. The frontend
only compiles normal runtime calls and emits their existing ELF relocations.
The runtime/loader must expose the new import; no shader section is needed.

Use generation-tagged job records so status remains queryable after the
shared driver lane is reused. A later job's successful cumulative timeline
must not turn a failed earlier copy into success. Guest exit must leave
admitted-job cleanup with the host, including quarantine when necessary.

Before implementing these changes, agree on this runtime/VGPU boundary and
the heap quota. If compiler-driven automatic offload is desired instead,
its blocking/async semantics and optimizer memory effects need a separate
architecture review under the requested stop rule.

## Demo and validation target

A useful first demo writes a deterministic pattern into a source in an
Odin-owned heap, poisons a destination, submits BCS, does independent CPU work,
then awaits and checks every copied word and surrounding guards. Run two
guest instances alongside an existing vcpy consumer to exercise Busy,
ownership and retirement. Counters must show actual BCS completions.

Compare the same byte counts and geometry against CPU copy after warm-up.
Report preparation, admission, observed completion and total latency
separately, plus useful CPU overlap. Fast Copy is a hardware path name;
speedup, bandwidth saturation and absence of submission overhead need
measurements. Small transfers may lose to CPU copy.

Host checks run during this review, all passing:

```sh
python3 tools/testpy/test_tgl_bcs_packets.py  # 13 tests
python3 tools/testpy/test_vcpy_consumer.py   # 1 test
python3 tools/testpy/test_wd_bcs_snapshot.py # 1 test
```

These compile and exercise existing production Rust helpers under host
harnesses. They establish packet/ownership regressions, not guest BCS
integration, physical execution or a speedup. Previous physical execution is
recorded in TRUEOS's `docs/experiments/tgl-bcs-marker-bringup.md`,
`gridpaper-bcs-copy.md` and `wd-bcs-snapshot.md`; it was not repeated here.

## Fact-check references

- [Intel Tiger Lake PRM, Volume 10: Copy Engine](https://cdrdv2-public.intel.com/705824/intel-gfx-prm-osrc-tgl-vol-10-copy-engine.pdf),
  printed pp. 1–2, 35–39: BCS dispatch, the Fast Copy path, UMA, cache
  visibility and dependent-blit restrictions. BCS operates on command packets;
  an EU EOT message is not its completion mechanism.
- [Intel PRM index, Volume 2a: Command Reference: Instructions](https://www.intel.com/content/www/us/en/docs/graphics-for-linux/developer-reference/1-0/tiger-lake.html):
  the local driver and packet tests cite the detailed `XY_FAST_COPY_BLT`,
  `MI_FLUSH_DW` and pre-parser fields. Volume 2a could not be fetched by the
  browser tool because of its size; exact packet checks above are against the
  existing production encoder and its established test vectors.
- [Linux kernel: buffer sharing and synchronization](https://docs.kernel.org/driver-api/dma-buf.html),
  CPU access and DMA_BUF_IOCTL_SYNC: cache visibility and exclusion are
  separate obligations. This supports the ownership distinction; it does not
  imply that TRUEOS uses Linux dma-buf.

The cited TGL manual supplies the programming reference; TRUEOS's recorded
ADL-S execution supplies evidence for its existing path. Other hardware
revisions still require their own admission and validation.
