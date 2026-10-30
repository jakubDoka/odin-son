# Water and light on a coarse lattice

Launch `odin-son`, choose `water_light [D2Q9 + caustics]`, and press Enter.
The new entry is separate from both Mandelbrot examples. The batch command is
`--water_light`. No kernel change, SDK bundle, precompiled shader, or downloaded
texture is required. Native Odin SON compiles the three source files on the node.

- Left click/drag displaces the water without adding net mass or momentum.
- Space pauses/resumes; R resets the two initial disturbances.
- V cycles shaded water, height, and bottom photon-flux views.
- Wheel changes optical depth (4..20 cell widths), a visualization parameter.
- A toggles automatic disturbances; P writes a profile/field-balance record.
- Q/Escape closes. Resize preserves the pool aspect ratio and simulation state.

## What runs where

The CPU solves a **64x48 D2Q9 shallow-water lattice**, traces **128x96 light
packets**, and shades a **192x144 image**. One retained sprite ID is replaced
and displayed by the existing GPU sprite renderer, with letterboxing when
needed. The GPU does not execute the fluid solver or optical shader in this
first version. The model and image arrays occupy about 408 KiB, independent
of window size; output rendering/composition still costs more at larger sizes.

The 60 Hz simulation uses a fixed step. At most six steps catch up in an input
turn; excess wall-clock time is counted as dropped ticks rather than changing
the physical step. The image is scheduled at up to 30 Hz and actual presentation
can run slower. A paused view renders only for changes. Field work is bounded
by the coarse grids, not the display resolution, but is not free.

The picker selects `-o:all`, retaining the simulation and shading stages as
ordinary calls. The current compiler's aggressive inlining/register allocation
can fail on this larger program. This profile retains local, memory and loop
optimizations without that inlining pass.

## Water model

`field.odin` implements BGK collision and streaming for the D2Q9 shallow-water
equilibrium, with lattice gravity 0.06 and relaxation time tau=0.7. Height is
the zeroth moment; depth-averaged momentum is the first. Closed edges use
halfway bounce-back. The flat bed has no external force. Disturbances displace
the rest population and subtract their discrete mean, preserving total mass
and cell momentum. Unstable/non-finite states terminate with a diagnostic;
there is no hidden height/velocity clamp.

This is a depth-averaged, viscous, long-wave model, not a 3D free-surface fluid
simulation. It does not resolve overturning waves, spray, capillary ripples,
or detail below its grid. The optical vertical scale is an independent viewing
parameter; changing it does not recalibrate the hydrodynamic lattice to SI units.

The equilibrium and moment definitions follow equations 7-10 in
[Jian Guo Zhou, MacLABSWE (2019)](https://arxiv.org/html/1902.02999).
This demo uses the conventional BGK update described there, not the paper's
alternative macroscopic streaming-only algorithm.

## Light model

`optics.odin` evaluates a geometric-optics approximation. Uniform vertical
incident rays refract at normals derived from the reconstructed height field,
using air/water index ratio 1/1.333. Schlick approximates Fresnel reflection;
a bounded [2/2] Pade approximation of Beer-Lambert transmission accounts for
absorption. Its absolute transmittance error is below 0.003 for optical depths
0..1.5. This is ray/flux transport, not a Maxwell or quantum-photon solver.

Each transmitted packet hits a flat bottom and deposits energy with a
four-cell cloud-in-cell splat. The solver separately accumulates incident,
reflected, absorbed, escaped and deposited energy. Rays leaving the finite
bottom are accounted for as escaped, not wrapped back into the pool. Thus
caustics arise from concentrated ray deposits rather than a painted noise map.
Height interpolation cannot restore unresolved wave frequencies, and the
finite photon grid smooths narrow caustic peaks.

A refracted viewing ray samples the tiled bottom and its light field. The
shaded view adds approximate sky reflection and a directional highlight.
Caustic contrast is increased by 3 for visibility; those display values do
not enter the conserved light field. The height view uses a fixed gain of 5;
the photon view shows the bottom field directly, tone mapped as E/(0.5+E).
Multiple scattering, diffraction, polarization and occlusion by objects are
outside this model. The physical refraction/forward-deposition construction is
also described in [GPU Gems, Water Caustics, sections 2.1-2.2](https://developer.nvidia.com/gpugems/gpugems/part-i-natural-effects/chapter-2-rendering-water-caustics);
this demo does not use that chapter's aesthetic backward-ray shortcut.

## Validation

Temporary checks compile these same sources through native Odin SON, then
exercise the generated machine code with host ABI mocks. They check flat-water
stationarity, 1,200 stable tank steps, mass balance, flat illumination,
nontrivial caustics, and light-energy accounting. The native window loop is
also exercised through 120 frames with input, resizing, and Busy injection at
upload, frame acquisition, drawing and publication.

A small-amplitude long-wave benchmark compares propagation with sqrt(g*h).
It uses transverse periodic boundaries to isolate the bulk wave from viscous
side walls; the interactive tank has closed walls. A 128x96 reference halves
space/time steps and adjusts tau from 0.7 to 0.9 to retain physical viscosity.
The measured coarse wave-speed error was 0.0042%; the coarse/fine height RMS
difference at coarse step 120 was 0.052% of the initial wave amplitude. This
is evidence for that resolved long-wave case, not an accuracy guarantee for
all disturbances. The closed-wall refinement case is recorded separately.

Local test programs, metrics and captures live in the sibling TRUEOS checkout
under `tgt/water-light/`; they are not installed with the demo.

## Bare-metal validation, 30 October 2026

The new menu entry compiled and ran on the node with the existing kernel.
The final native Blueprint is 451,152 bytes. The water, height and photon-flux
views were captured through the actual GPU sprite presentation path at
640x480. Every RGBA byte of the water capture matched the deterministic
25-step native reference after nearest-neighbor display scaling (307,200
pixels, zero differing bytes). The temporary capture main was restored and
the interactive source hashes were checked against the published sources.

The initial 25-step capture measured 0.96 ms per water step, 5 ms for the light
field, and 11 ms for water shading. Warm interactive profile samples measured
about 0.33..0.5 ms per water step, 5 ms for light, and 10 ms for water shading.
Height/flux shading took 1/2 ms in their captures. Presentation measured
31..38 ms in the controlled captures and was more variable under concurrent
user VMs. These are wall-clock CABI measurements, including scheduling and
transfer/retirement, not isolated GPU timestamps or an FPS guarantee. The
latest fixed-step samples had zero dropped ticks; the counter also exposed
contention in an earlier run rather than silently hiding elapsed time.

The updated compiler package was installed in AppDB. No reboot was needed,
and the task did not stop the user's Edit, Codex or SQLite VMs or write project
sources. Temporary capture data on the node was removed. The final interactive
water demo remained running. Captures, the native checks and hashes, profile
records and `validation.json` are under `tgt/water-light/` in TRUEOS.
