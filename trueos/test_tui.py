#!/usr/bin/env python3
import os
from pathlib import Path
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
        seeded = tui('q', TRUEOS_TEST_REENTRY='1')
        assert b'stage=discovery demos=4' in seeded
        assert b'\x1b[48;2;16;16;16m' in seeded and b'\x1b[?1049l' in seeded
        for name in ('cpu-boids', 'gpu-boids', 'gpu-tests', 'hello'):
            assert not (work / name).exists()
            legacy = work / name
            legacy.mkdir()
            (legacy / 'main.odin').write_text('package main\nmain :: proc() -> i32 { return 0 }\n')
        upgraded = tui('fq')
        assert b'stage=discovery demos=4' in upgraded
        for name in ('cpu-boids', 'gpu-boids', 'gpu-tests', 'hello'):
            assert (' ' + name).encode() not in upgraded
        mandelbrot = tui('\r\rq', TRUEOS_TEST_STABLE_HEAP='1')
        assert mandelbrot.count(b'stage=compile demo=mandelbrot_gpu_cpu status=0\n') == 2
        assert mandelbrot.count(b'stage=launch demo=mandelbrot_gpu_cpu status=0\n') == 2
        shader = work / 'mandelbrot_gpu_cpu/shader.odin.source'
        assert shader.read_bytes() == (NATIVE / 'mandelbrot-demo/assets/shader.odin.source').read_bytes()
        first_code = (work / 'mandelbrot_gpu_cpu/shader.eu').read_bytes()
        assert b'compiled Intel Xe-LP SIMD8 pixel' in mandelbrot
        assert b'backend=intel_xelp complete kernel' in mandelbrot
        assert ''.join(f'\\x{byte:02x}' for byte in first_code) in (work / 'mandelbrot_gpu_cpu/kernel.odin').read_text()
        assert (work / 'common/odin-son/demo-mandelbrot_gpu_cpu.bp').read_bytes() == (work / 'demo-mandelbrot_gpu_cpu.bp').read_bytes()
        shader.write_text('package main\n@(tag="gpu")\nshade :: proc(a,b:f32)->f32 { return a*0.125+b }\n')
        changed = tui('\rq', TRUEOS_TEST_STABLE_HEAP='1')
        assert b'stage=launch demo=mandelbrot_gpu_cpu status=0\n' in changed
        assert b'backend=intel_xelp complete kernel' in changed
        assert (work / 'mandelbrot_gpu_cpu/shader.eu').read_bytes() != first_code
        shader.write_text('package main\n@(tag="gpu")\nshade :: proc(a,b:f32)->f32 { return missing }\n')
        bad_shader = tui('\rq')
        assert b'stage=compile demo=mandelbrot_gpu_cpu status=1\n' in bad_shader
        assert b'stage=launch demo=mandelbrot_gpu_cpu' not in bad_shader
        shader.write_bytes((NATIVE / 'mandelbrot-demo/assets/shader.odin.source').read_bytes())
        poc = tui('jj\r\rq', TRUEOS_TEST_STABLE_HEAP='1')
        assert poc.count(b'stage=compile demo=mandelbrot_gpu_poc status=0\n') == 2
        assert poc.count(b'stage=launch demo=mandelbrot_gpu_poc status=0\n') == 2
        assert b'backend=intel_xelp complete kernel' in poc
        poc_shader = work / 'mandelbrot_gpu_poc/shader.poc.odin.source'
        assert poc_shader.read_bytes() == (NATIVE / 'mandelbrot-poc-demo/shader.poc.odin.source').read_bytes()
        poc_code = (work / 'mandelbrot_gpu_poc/shader.eu').read_bytes()
        assert (work / 'common/odin-son/demo-mandelbrot_gpu_poc.bp').read_bytes() == (work / 'demo-mandelbrot_gpu_poc.bp').read_bytes()
        poc_shader.write_text('package main\nmain :: proc(a:f32,b:f32)->f32 { return a*b }\n')
        assert b'stage=launch demo=mandelbrot_gpu_poc status=0\n' in tui('jj\rq', TRUEOS_TEST_STABLE_HEAP='1')
        assert (work / 'mandelbrot_gpu_poc/shader.eu').read_bytes() != poc_code
        poc_shader.write_text('package main\nmain :: proc(a:f32,b:f32)->f32 { return missing }\n')
        bad_poc = tui('jj\rq')
        assert b'stage=compile demo=mandelbrot_gpu_poc status=1\n' in bad_poc
        assert b'stage=launch demo=mandelbrot_gpu_poc' not in bad_poc
        poc_shader.write_bytes((NATIVE / 'mandelbrot-poc-demo/shader.poc.odin.source').read_bytes())
        run([exe, '--mandelbrot_gpu_poc'], cwd=work)
        run([exe, '--mandelbrot_gpu_cpu'], cwd=work)
        mandelbrot_source = work / 'mandelbrot_gpu_cpu/main.odin'
        mandelbrot_source.write_text('package main\nmain :: proc() -> i32 { return missing }\n')
        failed_mandelbrot = tui('\rq')
        assert b'stage=compile demo=mandelbrot_gpu_cpu status=1\n' in failed_mandelbrot
        assert b'stage=launch demo=mandelbrot_gpu_cpu' not in failed_mandelbrot
        # Seeding must preserve edited sources, and one failed job must not kill the VM.
        failing = tui('\rjj\rq')
        assert b'stage=compile demo=mandelbrot_gpu_cpu status=1\n' in failing
        assert b'stage=compile demo=mandelbrot_gpu_poc status=0\n' in failing
        assert 'missing' in mandelbrot_source.read_text()
        mandelbrot_source.write_text('package main\nmain :: proc( {\n')
        malformed = tui('\rjj\rq')
        assert b'stage=compile demo=mandelbrot_gpu_cpu status=1\n' in malformed
        assert b'stage=compile demo=mandelbrot_gpu_poc status=0\n' in malformed
        discovered = tui('fq', TRUEOS_TEST_ADD_DEMO='1')
        assert b'stage=discovery demos=5' in discovered and b' extra' in discovered
        mandelbrot_source.write_bytes((NATIVE / 'mandelbrot-demo/main.odin').read_bytes())
        repeated = tui('j' + '\r'*8 + 'rq', TRUEOS_TEST_STABLE_HEAP='1')
        assert repeated.count(b'[odin-son tui] stage=compile demo=mandelbrot_gpu_cpu status=0\n') == 8
        assert b'stage=launch demo=mandelbrot_gpu_cpu status=0\n' in repeated
        automatic = tui('q', TRUEOS_TEST_AUTO_DISCOVER='1')
        assert b'stage=discovery demos=6' in automatic and b' auto' in automatic
    print('PASS: native TUI seeds/preserves demos; discovers new directories; repeated compilation has stable live heap allocations; semantic/parse failures recover; queued launch, terminal resize/reentry, short writes and quit release are exercised by ABI mocks.')

if __name__ == '__main__':
    main()
