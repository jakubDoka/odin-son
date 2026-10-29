#!/usr/bin/env python3
import os
from pathlib import Path
import struct
import subprocess
import tempfile

NATIVE = Path(__file__).resolve().parent

def run(args, **kwargs):
    result = subprocess.run([str(a) for a in args], capture_output=True, timeout=12, **kwargs)
    assert result.returncode == 0, (args, result.returncode, result.stdout[-4000:], result.stderr)
    return result


def main():
    with tempfile.TemporaryDirectory() as directory:
        work = Path(directory)
        exe = work / 'compiler'
        run(['gcc', '-std=c11', NATIVE / 'test_host.c', NATIVE / 'build/odin-son.o', '-lm', '-o', exe])
        def tui(keys, **env):
            return run([exe], cwd=work, env=dict(os.environ, TRUEOS_TEST_TUI_KEYS=keys, **env)).stdout
        seeded = tui('\r\rrq', TRUEOS_TEST_STABLE_HEAP='1', TRUEOS_TEST_REENTRY='1')
        assert b'stage=discovery demos=2' in seeded
        assert seeded.count(b'[odin-son tui] stage=compile demo=cpu-boids status=0\n') == 2
        assert b'stage=launch demo=cpu-boids status=0\n' in seeded
        assert b'\x1b[48;2;16;16;16m' in seeded and b'\x1b[?1049l' in seeded
        bp = (work / 'demo-cpu-boids.bp').read_bytes()
        assert struct.unpack('<4sHHQII', bp[:24])[:4] == (b'TRBP', 1, 0x601, 0)
        assert bp[24:] == (work / 'demo-cpu-boids.o').read_bytes()
        hello_ok = tui('k\rq', TRUEOS_TEST_STABLE_HEAP='1')
        assert b'stage=compile demo=hello status=0\n' in hello_ok
        run(['objcopy', '--redefine-sym', 'main=hello_entry', work / 'demo-hello.o', work / 'hello-host.o'])
        (work / 'hello-host.c').write_text('#include <stdint.h>\n#include <stdio.h>\nint32_t hello_entry(void);\nvoid trueos_cabi_write(uint32_t s, const void *p, uintptr_t n) { fwrite(p, 1, n, stdout); }\nint main(void) { return hello_entry(); }\n')
        run(['gcc', work / 'hello-host.o', work / 'hello-host.c', '-o', work / 'hello-host'])
        assert b'sum(0..<10) = 45' in run([work / 'hello-host']).stdout
        # Seeding must preserve edited sources, and one failed job must not kill the VM.
        hello = work / 'hello/main.odin'
        hello.write_text('package main\nmain :: proc() -> i32 { return missing }\n')
        failing = tui('k\rj\rq')  # hello fails, then cpu-boids succeeds
        assert b'stage=compile demo=hello status=1\n' in failing
        assert b'stage=compile demo=cpu-boids status=0\n' in failing
        assert 'missing' in hello.read_text()
        hello.write_text('package main\nmain :: proc( {\n')
        malformed = tui('k\rj\rq')
        assert b'stage=compile demo=hello status=1\n' in malformed
        assert b'stage=compile demo=cpu-boids status=0\n' in malformed
        discovered = tui('fq', TRUEOS_TEST_ADD_DEMO='1')
        assert b'stage=discovery demos=3' in discovered and b' extra' in discovered
        hello.write_bytes((NATIVE / 'hello.odin.source').read_bytes())
        repeated = tui('\r'*8 + 'rq', TRUEOS_TEST_STABLE_HEAP='1')
        assert repeated.count(b'[odin-son tui] stage=compile demo=cpu-boids status=0\n') == 8
        assert b'stage=launch demo=cpu-boids status=0\n' in repeated
        automatic = tui('q', TRUEOS_TEST_AUTO_DISCOVER='1')
        assert b'stage=discovery demos=4' in automatic and b' auto' in automatic
    print('PASS: native TUI seeds/preserves demos; discovers new directories; repeated compilation has stable live heap allocations; semantic/parse failures recover; queued launch, terminal resize/reentry, short writes and quit release are exercised by ABI mocks.')

if __name__ == '__main__':
    main()
