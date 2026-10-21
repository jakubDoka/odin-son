# Native scalar GPU call

`main.odin` is the original two-argument `f32` example. Its expected result is
`1010`. The compiler emits native Xe-LP instructions, a CPU dispatch stub, and
the read-only `.gpu.xelp` ELF section without invoking IGC or IGA.

From the odin-son repository:

```sh
odin build . -out:/tmp/odin-son-native
ODIN_ROOT="$(odin root)" /tmp/odin-son-native examples/gpu-scalar-trueos/main.odin -o /tmp/gpu-scalar.o
objcopy --redefine-sym main=trueos_main /tmp/gpu-scalar.o
python3 trueos/package.py /tmp/gpu-scalar.o /tmp/gpu-scalar.bp
```

Running the package requires a TRUEOS kernel with the new v1 scalar C ABI,
an admitted ADL-S/TGL device, and working RCS submission. The function waits
for ordered GPU completion before reading its result. A device/runtime failure
traps. This example has been verified offline; physical GPU dispatch remains
to be validated.

See [the target contract](../../bac/intel_xelp/README.md#native-scalar-procedures)
for the payload layout, ownership rules, current limits, and tests.
