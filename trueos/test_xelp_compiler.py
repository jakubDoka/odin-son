#!/usr/bin/env python3
"""Prove tagged Odin source changes native EU bytes on host and TRUEOS ABI mocks."""
from pathlib import Path
import argparse
import os
import shutil
import struct
import subprocess
import tempfile


def run(args, expected=0, **kwargs):
    p = subprocess.run([str(x) for x in args], capture_output=True, timeout=12, **kwargs)
    assert p.returncode == expected, (args, p.returncode, p.stdout.decode(), p.stderr.decode())
    return p


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--odin', default=os.environ.get('ODIN', 'odin'))
    parser.add_argument('--iga', default='iga64')
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    root = args.root
    with tempfile.TemporaryDirectory(prefix='odin-son-xelp-compiler-') as directory:
        work = Path(directory)
        host, native = work/'host', work/'native'
        run([args.odin, 'build', root / 'odinc', '-out:' + str(host)])
        run(['gcc', '-std=c11', root/'trueos/test_host.c', root/'trueos/build/odin-son.o', '-lm', '-o', native])
        sdk = run([args.odin, 'root']).stdout.decode().strip()
        environment = dict(os.environ, ODIN_ROOT=sdk)
        original = root/'examples/gpu-boids-trueos'
        source = original.joinpath('main.odin').read_text()
        variants = []
        for index, coefficient in enumerate(['0.016666667', '0.0', '-0.5']):
            fixture = work/f'case-{index}'; shutil.copytree(original, fixture)
            (fixture/'main.odin').write_text(source.replace('0.016666667', coefficient))
            bits = struct.unpack('<I', struct.pack('<f', float(coefficient)))[0]
            assembly = '\n'.join([
                f'mul (8|M0) r20.0<1>:f r18.0<8;8,1>:f 0x{bits:08x}:f {{@1}}',
                'add (8|M0) r16.0<1>:f r16.0<8;8,1>:f r20.0<8;8,1>:f {@1}',
                f'mul (8|M0) r20.0<1>:f r19.0<8;8,1>:f 0x{bits:08x}:f {{@1}}',
                'add (8|M0) r17.0<1>:f r17.0<8;8,1>:f r20.0<8;8,1>:f {@1}',
            ]) + '\n'
            (work/'expected.asm').write_text(assembly)
            run([args.iga, '-p=12p1', '-a', work/'expected.asm', '-o', work/'expected.bin'])
            expected = (work/'expected.bin').read_bytes()
            assert len(expected) == 64
            for compiler in [host, native]:
                flags = ['--cpu-boids'] if compiler == native else []
                result = run([compiler, *flags, fixture/'main.odin', '-o', work/'boids.o', '-emit-xelp-body', work/'body.bin'], cwd=work, env=environment)
                assert b'complete_kernel=false' in result.stdout + result.stderr
                assert (work/'body.bin').read_bytes() == expected
            variants.append(expected)
        assert len(set(variants)) == 3
        run([native, '--gpu-boids', '-emit-xelp-body', work/'embedded.bin'], cwd=work,
            env=dict(environment, TRUEOS_TEST_NO_SOURCE_IO='1', TRUEOS_TEST_LINE_WRITES='1'))
        assert (work/'embedded.bin').read_bytes() == variants[0]
        simple = work/'plain'; simple.mkdir()
        (simple/'main.odin').write_text('package main\nmain :: proc() -> i32 { return 0 }\n')
        for compiler in [host, native]:
            flags = ['--cpu-boids'] if compiler == native else []
            p = run([compiler, *flags, simple/'main.odin', '-emit-xelp-body', work/'bad.bin'], expected=1, cwd=work, env=environment)
            assert b'exactly one' in p.stdout + p.stderr
            assert not (work/'bad.bin').exists()
            run([compiler, *flags, simple/'main.odin', '-emit-xelp-body'], expected=1, cwd=work, env=environment)
            fixture = work/'case-0/main.odin'
            p = run([compiler, *flags, fixture, '-o', work/'collision.o', '-emit-xelp-body', work/'collision.o'], expected=1, cwd=work, env=environment)
            assert b'different output paths' in p.stdout + p.stderr
            assert not (work/'collision.o').exists()
        extra = work/'case-0/extra.odin'
        extra.write_text('package main\n@(tag = "gpu")\nextra :: proc(handle: u64, frame: u64) -> i32 { gpu_add_scaled(0, 2, 1.0); return 0 }\n')
        for compiler in [host, native]:
            flags = ['--cpu-boids'] if compiler == native else []
            p = run([compiler, *flags, work/'case-0/main.odin', '-emit-xelp-body', work/'bad.bin'], expected=1, cwd=work, env=environment)
            assert b'exactly one' in p.stdout + p.stderr
    print('PASS host and TRUEOS-ABI compilers emit source-dependent native Xe-LP bodies matching IGA; embedded emission and invalid requests checked. No hardware dispatch tested.')


if __name__ == '__main__':
    main()
