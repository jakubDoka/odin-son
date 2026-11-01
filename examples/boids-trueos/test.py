#!/usr/bin/env python3
import importlib.util
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile


APP = Path(__file__).resolve().parent
ROOT = APP.parents[1]
HARNESS = r'''
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
extern int32_t boids_entry(size_t, char **);
static const char *mode;
static unsigned registered, polls, sleeps, reads, claims, releases, shutdowns, snapshots;
static size_t bytes;
static int is(const char *s) { return strcmp(mode, s) == 0; }
size_t trueos_cabi_shell_attached_write(const void *p, size_t n) {
    if (is("write-fail")) return 0;
    if (is("partial") && n > 17) n = 17;
    bytes += n;
    return fwrite(p, 1, n, stdout);
}
int32_t trueos_cabi_shell_attached_read_byte(void) {
    ++reads;
    if (sleeps >= 2) {
        if (is("quit") || is("resize")) return 'q';
        if (is("escape")) return 27;
        if (is("interrupt")) return 3;
    }
    return -1;
}
void trueos_cabi_sleep_ms(uint64_t ms) { assert(ms == 60); ++sleeps; }
int32_t trueos_cabi_blueprint_stop_control_v1(uint32_t op) {
    if (op == 0) { ++registered; return 0; }
    assert(op == 1 && registered == 1);
    ++polls;
    return is("stop") && sleeps >= 2;
}
int32_t trueos_cabi_blueprint_shutdown(const void *p, size_t n) {
    assert(registered == 1 && p && n);
    if (claims && !is("fallback")) assert(releases == 1);
    ++shutdowns;
    return 0;
}
int32_t trueos_cabi_blueprint_terminal_lease_current_v1(uint64_t ready, uint64_t *epoch) {
    assert(ready == 0);
    ++claims;
    if (is("fallback")) return -1;
    *epoch = 7;
    return 0;
}
int32_t trueos_cabi_blueprint_terminal_lease_release_v1(uint64_t epoch, uint64_t *ticket) {
    assert(epoch == 7);
    ++releases;
    *ticket = 9;
    return 0;
}
int32_t trueos_cabi_blueprint_terminal_surface_snapshot_v1(uint64_t *gen, uint32_t *cols, uint32_t *rows) {
    ++snapshots;
    *gen = 1;
    *cols = is("resize") && sleeps ? 40 : 80;
    *rows = is("small") ? 3 : (is("resize") && sleeps ? 14 : 34);
    return 0;
}
int main(int argc, char **argv) {
    mode = getenv("BOIDS_MODE");
    assert(mode);
    int32_t status = boids_entry((size_t)argc, argv);
    fprintf(stderr, "{\"registered\":%u,\"sleeps\":%u,\"claims\":%u,"
            "\"releases\":%u,\"shutdowns\":%u,\"bytes\":%zu}\n",
            registered, sleeps, claims, releases, shutdowns, bytes);
    return status;
}
'''


def run(args, **kwargs):
    return subprocess.run([str(a) for a in args], timeout=12, capture_output=True, **kwargs)


def checked(args, **kwargs):
    result = run(args, **kwargs)
    if result.returncode:
        raise RuntimeError(result.stderr.decode(errors="replace"))
    return result


def main():
    odin = os.environ.get("ODIN", "odin")
    compiler = Path(os.environ.get("JIT", APP / "build/odin-son")).resolve()
    env = dict(os.environ)
    env.setdefault("ODIN_ROOT", str(Path(shutil.which(odin)).resolve().parent))
    spec = importlib.util.spec_from_file_location("boids_package", APP / "package.py")
    packer = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(packer)

    with tempfile.TemporaryDirectory() as directory:
        work = Path(directory)
        obj = work / "boids.o"
        checked([compiler, APP / "main.odin", "-o", obj], env=env)
        bp = work / "boids.bp"
        packer.package(obj, bp)
        header = struct.unpack("<4sHHQII", bp.read_bytes()[:24])
        assert header[:3] == (b"TRBP", 1, 0x601)
        assert header[3] >> 32 == 1
        assert header[4] == header[5] == obj.stat().st_size
        assert bp.read_bytes()[24:] == obj.read_bytes()

        host_obj = work / "host.o"
        checked(["objcopy", "--redefine-sym", "main=boids_entry", obj, host_obj])
        harness = work / "harness.c"
        harness.write_text(HARNESS)
        exe = work / "boids"
        checked(["gcc", "-pie", host_obj, harness, "-o", exe])

        def scenario(mode, *args, status=0):
            result = run([exe, *args], env=dict(env, BOIDS_MODE=mode))
            assert result.returncode == status, (mode, result.returncode, result.stderr)
            stats = json.loads(result.stderr)
            if mode != "invalid":
                assert stats["registered"] == stats["shutdowns"] == 1, (mode, stats)
            return result.stdout, stats

        batch, stats = scenario("batch", "--batch")
        assert batch.count(b"frame ") == 100 and b"\x1b" not in batch
        assert batch.endswith(b"boids checksum: 127\n")
        assert stats["sleeps"] == stats["claims"] == stats["releases"] == 0
        partial, _ = scenario("partial", "--batch")
        assert partial == batch
        fallback, stats = scenario("fallback")
        assert fallback == batch and stats["sleeps"] == stats["releases"] == 0

        for mode in ("quit", "escape", "interrupt", "stop", "resize"):
            output, stats = scenario(mode)
            assert stats["sleeps"] == 2 and stats["releases"] == 1, (mode, stats)
            assert b"\x1b[?25h" in output and b"boids checksum:" in output
            if mode == "resize":
                assert b"+" + b"-" * 38 + b"+\n" in output
        _, stats = scenario("write-fail", "--batch", status=1)
        assert stats["bytes"] == stats["sleeps"] == 0
        output, stats = scenario("small", status=1)
        assert b"too small" in output and stats["sleeps"] == 0
        _, stats = scenario("invalid", "--invalid", status=1)
        assert stats["registered"] == 0

        ref_dir = work / "reference"
        ref_dir.mkdir()
        reference = (ROOT / "test-programs/boids/main.odin").read_text()
        reference = reference.replace("package main", 'package main\nimport __os "core:os"', 1)
        reference = reference.replace("main :: proc() -> int", "_main :: proc() -> int")
        reference += "\nmain :: proc() { __os.exit(_main()) }\n"
        (ref_dir / "main.odin").write_text(reference)
        checked([odin, "build", ref_dir, f"-out:{work / 'reference-bin'}", "-o:none"])
        expected = run([work / "reference-bin"])
        assert expected.returncode == 127 and not expected.stderr
        assert batch == expected.stdout + b"boids checksum: 127\n"
        print("PASS: packaging, native ABI, batch parity, partial writes, input, stop, resize, cleanup, errors")


if __name__ == "__main__":
    main()
