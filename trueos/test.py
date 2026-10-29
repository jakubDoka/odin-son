#!/usr/bin/env python3
import os
from pathlib import Path
import struct
import shutil
import subprocess
import tempfile
import importlib.util

NATIVE = Path(__file__).resolve().parent
ROOT = NATIVE.parent


def run(args, expected=0, **kwargs):
    result = subprocess.run([str(a) for a in args], capture_output=True, timeout=12, **kwargs)
    if result.returncode != expected:
        raise AssertionError((args, result.returncode, result.stdout, result.stderr))
    return result


def main():
    obj = NATIVE / 'build/odin-son.o'
    bp = (NATIVE / 'build/odin-son.bp').read_bytes()
    header = struct.unpack('<4sHHQII', bp[:24])
    assert header[:3] == (b'TRBP', 1, 0x201)
    assert header[3] >> 32 > 0
    assert header[4] == header[5] == obj.stat().st_size
    assert bp[24:] == obj.read_bytes()
    assert (ROOT / 'examples/boids-trueos/main.odin').read_bytes() in bp[24:]
    with tempfile.TemporaryDirectory() as directory:
        work = Path(directory)
        exe = work / 'compiler'
        run(['gcc', '-std=c11', NATIVE / 'test_host.c', obj, '-lm', '-o', exe])
        imports = set(run(['nm', '-u', obj]).stdout.decode().split()) - {'U'}
        assert not any(name.startswith(('trueos_cabi_fs_', 'trueos_cabi_trueosfs_')) for name in imports)
        assert {'trueos_cabi_async_fs_read_start', 'trueos_cabi_poll_once'} <= imports
        retired = work / 'retired.c'
        retired.write_text('extern void trueos_cabi_fs_read_file(void);\nint trueos_main(void) { trueos_cabi_fs_read_file(); return 0; }\n')
        run(['gcc', '-fPIC', '-c', retired, '-o', work / 'retired.o'])
        rejection = run(['python3', NATIVE / 'package.py', work / 'retired.o', work / 'retired.bp'], expected=1)
        assert b'retired synchronous filesystem imports' in rejection.stderr
        assert not (work / 'retired.bp').exists()
        demo = run([exe, "--cpu-boids"], cwd=work, env=dict(os.environ, TRUEOS_TEST_NO_SOURCE_IO='1'))
        assert b'argc=2' in demo.stdout and b'argv[0]=' in demo.stdout
        assert b'compiling embedded TRUEOS boids' in demo.stdout
        assert b'stored boids.o' in demo.stdout and b'stored boids.bp' in demo.stdout
        assert b'commit complete; boids is ready to load' in demo.stdout
        assert b'source collections root=.' in demo.stdout
        demo_bp = (work / 'boids.bp').read_bytes()
        demo_header = struct.unpack('<4sHHQII', demo_bp[:24])
        assert demo_header[:4] == (b'TRBP', 1, 0x601, 0)
        assert demo_header[4] == demo_header[5] == (work / 'boids.o').stat().st_size
        assert demo_bp[24:] == (work / 'boids.o').read_bytes()
        demo_imports = run(['nm', '-u', work / 'boids.o']).stdout
        assert b'trueos_cabi_shell_attached_write' in demo_imports
        assert b'syscall' not in run(['objdump', '-d', work / 'boids.o']).stdout
        spec = importlib.util.spec_from_file_location('boids_tests', ROOT / 'examples/boids-trueos/test.py')
        boids_tests = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(boids_tests)
        (work / 'boids_host.c').write_text(boids_tests.HARNESS)
        run(['objcopy', '--redefine-sym', 'main=boids_entry', work / 'boids.o', work / 'boids-host.o'])
        run(['gcc', work / 'boids-host.o', work / 'boids_host.c', '-o', work / 'boids'])
        simulated = run([work / 'boids', '--batch'], env=dict(os.environ, BOIDS_MODE='batch'))
        assert simulated.stdout.endswith(b'boids checksum: 127\n')
        assert simulated.stdout.count(b'frame ') == 100
        assert b'usage:' in run([exe, '--help']).stdout
        run([exe, '--unknown'], expected=1)
        for target in ('amd64', 'arm64', 'wasm64'):
            output = work / f'arithmetic-{target}.o'
            run([exe, ROOT / 'test-programs/arithmetic/main.odin', f'-target:{target}', '-o', output])
            data = output.read_bytes()
            if target == 'wasm64':
                assert data[:8] == b'\0asm\x01\0\0\0'
            else:
                assert data[:4] == b'\x7fELF'
                assert struct.unpack_from('<H', data, 18)[0] == (62 if target == 'amd64' else 183)
        binary = work / 'arithmetic'
        run(['gcc', work / 'arithmetic-amd64.o', '-o', binary])
        run([binary], expected=45)
        for failure in ('TRUEOS_TEST_CHUNK_FAIL', 'TRUEOS_TEST_COMMIT_FAIL'):
            failed_output = work / f'{failure}.o'
            result = run([exe, ROOT / 'test-programs/arithmetic/main.odin', '-o', failed_output], expected=1,
                         env=dict(os.environ, **{failure: '1'}))
            assert b'cannot write' in result.stderr
            assert not failed_output.exists()
        modules = ROOT / 'test-programs/module-imports/main.odin'
        run([exe, modules, '-o', work / 'imports.o'])
        run(['gcc', work / 'imports.o', '-o', work / 'imports'])
        # Both compiler builds must produce the same externally visible result.
        desktop = work / 'desktop.o'
        env = dict(os.environ)
        env.setdefault('ODIN_ROOT', str(Path(shutil.which(os.environ.get('ODIN', 'odin'))).resolve().parent))
        run([os.environ.get('ODIN_SON_DESKTOP', ROOT / 'odin-son'), modules, '-o', desktop], env=env)
        run(['gcc', desktop, '-o', work / 'desktop'])
        native_result = subprocess.run([work / 'imports'], capture_output=True, timeout=12)
        desktop_result = subprocess.run([work / 'desktop'], capture_output=True, timeout=12)
        assert (native_result.returncode, native_result.stdout, native_result.stderr) == (desktop_result.returncode, desktop_result.stdout, desktop_result.stderr)
        bad = work / 'bad'
        bad.mkdir()
        (bad / 'main.odin').write_text('package main\nmain :: proc() -> int { return missing }\n')
        assert b'undeclared' in run([exe, bad / 'main.odin', '-o', work / 'bad.o'], expected=1).stderr
        env['JIT'] = str(exe)
        run(['python3', ROOT / 'examples/boids-trueos/test.py'], env=env)
    print('PASS: embedded TRUEOS boids compiles without source I/O, stores ELF and Blueprint, executes with checksum 127; async filesystem with cooperative waits, partial reads and operation cleanup; retired ABI rejection; x64/arm64/wasm, imports, diagnostics and native boids')


if __name__ == '__main__':
    main()
