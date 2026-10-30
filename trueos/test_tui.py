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
        assert b'stage=discovery demos=5' in seeded
        assert seeded.count(b'[odin-son tui] stage=compile demo=cpu-boids status=0\n') == 2
        assert b'stage=launch demo=cpu-boids status=0\n' in seeded
        assert b'\x1b[48;2;16;16;16m' in seeded and b'\x1b[?1049l' in seeded
        bp = (work / 'demo-cpu-boids.bp').read_bytes()
        assert struct.unpack('<4sHHQII', bp[:24])[:4] == (b'TRBP', 1, 0x601, 0)
        assert bp[24:] == (work / 'demo-cpu-boids.o').read_bytes()
        gpu_ok = tui('j\r\rrq', TRUEOS_TEST_STABLE_HEAP='1')
        assert gpu_ok.count(b'stage=compile demo=gpu-tests status=0\n') == 2
        assert b'stage=launch demo=gpu-tests status=0\n' in gpu_ok
        assert (work / 'gpu-tests/cases.odin').read_bytes() == (NATIVE / 'gpu-demo/cases.odin').read_bytes()
        run(['python3', NATIVE / 'test_gpu_demo.py', '--object', work / 'demo-gpu-tests.o'])
        hello_ok = tui('jj\rq', TRUEOS_TEST_STABLE_HEAP='1')
        assert b'stage=compile demo=hello status=0\n' in hello_ok
        run(['objcopy', '--redefine-sym', 'main=hello_entry', work / 'demo-hello.o', work / 'hello-host.o'])
        (work / 'hello-host.c').write_text('#include <stdint.h>\n#include <stdio.h>\nint32_t hello_entry(void);\nvoid trueos_cabi_write(uint32_t s, const void *p, uintptr_t n) { fwrite(p, 1, n, stdout); }\nint main(void) { return hello_entry(); }\n')
        run(['gcc', work / 'hello-host.o', work / 'hello-host.c', '-o', work / 'hello-host'])
        assert b'sum(0..<10) = 45' in run([work / 'hello-host']).stdout
        mandelbrot = tui('kk\r\rq', TRUEOS_TEST_STABLE_HEAP='1')
        assert mandelbrot.count(b'stage=compile demo=mandelbrot_gpu_cpu status=0\n') == 2
        assert mandelbrot.count(b'stage=launch demo=mandelbrot_gpu_cpu status=0\n') == 2
        shader = work / 'mandelbrot_gpu_cpu/shader.odin.source'
        assert shader.read_bytes() == (NATIVE / 'mandelbrot-demo/assets/shader.odin.source').read_bytes()
        first_code = (work / 'mandelbrot_gpu_cpu/shader.eu').read_bytes()
        assert b'compiled Intel Xe-LP SIMD8 pixel' in mandelbrot
        assert ''.join(f'\\x{byte:02x}' for byte in first_code) in (work / 'mandelbrot_gpu_cpu/kernel.odin').read_text()
        assert (work / 'common/odin-son/demo-mandelbrot_gpu_cpu.bp').read_bytes() == (work / 'demo-mandelbrot_gpu_cpu.bp').read_bytes()
        shader.write_text('package main\n@(tag="gpu")\nshade :: proc(a,b:f32)->f32 { return a*0.125+b }\n')
        changed = tui('kk\rq', TRUEOS_TEST_STABLE_HEAP='1')
        assert b'stage=launch demo=mandelbrot_gpu_cpu status=0\n' in changed
        assert (work / 'mandelbrot_gpu_cpu/shader.eu').read_bytes() != first_code
        shader.write_text('package main\n@(tag="gpu")\nshade :: proc(a,b:f32)->f32 { return missing }\n')
        bad_shader = tui('kk\rq')
        assert b'stage=compile demo=mandelbrot_gpu_cpu status=1\n' in bad_shader
        assert b'stage=launch demo=mandelbrot_gpu_cpu' not in bad_shader
        shader.write_bytes((NATIVE / 'mandelbrot-demo/assets/shader.odin.source').read_bytes())
        poc = tui('k\r\rq', TRUEOS_TEST_STABLE_HEAP='1')
        assert poc.count(b'stage=compile demo=mandelbrot_gpu_poc status=0\n') == 2
        assert poc.count(b'stage=launch demo=mandelbrot_gpu_poc status=0\n') == 2
        assert b'backend=intel_xelp_poc complete kernel' in poc
        poc_shader = work / 'mandelbrot_gpu_poc/shader.poc.odin.source'
        assert poc_shader.read_bytes() == (NATIVE / 'mandelbrot-poc-demo/shader.poc.odin.source').read_bytes()
        poc_code = (work / 'mandelbrot_gpu_poc/shader.eu').read_bytes()
        assert (work / 'common/odin-son/demo-mandelbrot_gpu_poc.bp').read_bytes() == (work / 'demo-mandelbrot_gpu_poc.bp').read_bytes()
        poc_shader.write_text('package main\nmain :: proc(a:f32,b:f32)->f32 { return a*b }\n')
        assert b'stage=launch demo=mandelbrot_gpu_poc status=0\n' in tui('k\rq', TRUEOS_TEST_STABLE_HEAP='1')
        assert (work / 'mandelbrot_gpu_poc/shader.eu').read_bytes() != poc_code
        poc_shader.write_text('package main\nmain :: proc(a:f32,b:f32)->f32 { return missing }\n')
        bad_poc = tui('k\rq')
        assert b'stage=compile demo=mandelbrot_gpu_poc status=1\n' in bad_poc
        assert b'stage=launch demo=mandelbrot_gpu_poc' not in bad_poc
        poc_shader.write_bytes((NATIVE / 'mandelbrot-poc-demo/shader.poc.odin.source').read_bytes())
        run([exe, '--mandelbrot_gpu_poc'], cwd=work)
        run([exe, '--mandelbrot_gpu_cpu'], cwd=work)
        mandelbrot_source = work / 'mandelbrot_gpu_cpu/main.odin'
        mandelbrot_source.write_text('package main\nmain :: proc() -> i32 { return missing }\n')
        failed_mandelbrot = tui('kk\rq')
        assert b'stage=compile demo=mandelbrot_gpu_cpu status=1\n' in failed_mandelbrot
        assert b'stage=launch demo=mandelbrot_gpu_cpu' not in failed_mandelbrot
        # Seeding must preserve edited sources, and one failed job must not kill the VM.
        hello = work / 'hello/main.odin'
        hello.write_text('package main\nmain :: proc() -> i32 { return missing }\n')
        failing = tui('jj\rjjj\rq')  # hello fails, then cpu-boids succeeds
        assert b'stage=compile demo=hello status=1\n' in failing
        assert b'stage=compile demo=cpu-boids status=0\n' in failing
        assert 'missing' in hello.read_text()
        hello.write_text('package main\nmain :: proc( {\n')
        malformed = tui('jj\rjjj\rq')
        assert b'stage=compile demo=hello status=1\n' in malformed
        assert b'stage=compile demo=cpu-boids status=0\n' in malformed
        discovered = tui('fq', TRUEOS_TEST_ADD_DEMO='1')
        assert b'stage=discovery demos=6' in discovered and b' extra' in discovered
        hello.write_bytes((NATIVE / 'hello.odin.source').read_bytes())
        repeated = tui('\r'*8 + 'rq', TRUEOS_TEST_STABLE_HEAP='1')
        assert repeated.count(b'[odin-son tui] stage=compile demo=cpu-boids status=0\n') == 8
        assert b'stage=launch demo=cpu-boids status=0\n' in repeated
        automatic = tui('q', TRUEOS_TEST_AUTO_DISCOVER='1')
        assert b'stage=discovery demos=7' in automatic and b' auto' in automatic
    print('PASS: native TUI seeds/preserves demos; discovers new directories; repeated compilation has stable live heap allocations; semantic/parse failures recover; queued launch, terminal resize/reentry, short writes and quit release are exercised by ABI mocks.')

if __name__ == '__main__':
    main()
