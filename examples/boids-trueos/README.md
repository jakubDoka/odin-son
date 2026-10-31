# Boids for TRUEOS

This is the terminal boids simulation compiled by odin-son for the existing
TRUEOS Blueprint/Hull VMX loader. The application uses native TRUEOS C ABI
imports for output, input, sleep, terminal ownership, and cooperative shutdown.

From the repository root:

```bash
bash examples/boids-trueos/build.sh
```

The build produces `examples/boids-trueos/build/boids.bp` and its `boids.o`
payload. Odin must be on PATH; alternatively set `ODIN` to its executable.
To use an already built odin-son, set `JIT` and `ODIN_ROOT`:

```bash
JIT="$PWD/odin-son" ODIN_ROOT=/home/t4ce/Programmme/odin \
  bash examples/boids-trueos/build.sh
```

Make `boids.bp` available to TRUEOS through the usual Blueprint/AppDB delivery
path, then launch it from Shell3. Its regular Blueprint launch selects a
terminal surface. The loader resolves the ELF inside that application's Hull
and VMX context; the application claims its existing Matrix terminal lease.
ANSI drawing stays in the application's surface, separate from Shell3's prompt.

The animation adapts to terminal size, up to 78 by 30 simulation cells, and
sleeps for 60 ms between frames using `trueos_cabi_sleep_ms`. Press `q`, Escape,
or Ctrl-C to exit. A host stop request is checked between frames. The client
restores the cursor, releases its terminal lease, and acknowledges shutdown.

Pass `--batch` for 100 deterministic plain-text frames and a printed checksum
of `127`, with no sleeping or terminal claim. A text-only launch without a
terminal lease also uses this mode. Success returns zero through the existing
Blueprint argv-v1 entry ABI. Unsupported arguments return one.

The package uses the existing TRBP v1 header, a raw ELF payload, argv-v1 entry,
and the filesystem-independent flag. The packager checks the entry symbol,
restricts imports to the native ABI and memory helpers, and rejects raw system
call instructions. No host executable or libc is included.

Local validation after building:

```bash
python3 examples/boids-trueos/test.py
```

This executes the generated machine code against a host C ABI harness and
compares batch output with the reference Odin compiler. It covers packaging,
partial writes, quit keys, host stop requests, resize, terminal fallback,
cleanup, and error paths. It does not launch a VM or deploy to a TRUEOS rig.
