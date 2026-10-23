#!/usr/bin/env python3
"""Execute the freestanding compiler with embedded sources and a native-code/UI4 oracle."""
from pathlib import Path
import os
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]

def run(args, expected=0, **kwargs):
    result = subprocess.run([str(a) for a in args], capture_output=True, timeout=12, **kwargs)
    assert result.returncode == expected, (args, result.returncode, result.stdout.decode(), result.stderr.decode())
    return result

def main():
    with tempfile.TemporaryDirectory(prefix='odin-mandelbrot-') as temporary:
        work = Path(temporary)
        executable = work/'compiler'
        run([os.environ.get('CC','clang'), '-std=c11', '-O2', '-ffp-contract=off',
             ROOT/'trueos/test_host.c', ROOT/'trueos/test_mandelbrot_host.c',
             ROOT/'trueos/build/odin-son.o', '-lm', '-o', executable])
        result = run([executable, '--verify-gpu-mandelbrot'], cwd=work,
                     env=dict(os.environ, TRUEOS_TEST_NO_SOURCE_IO='1'))
        text = result.stdout.decode()
        assert 'source-dependent=true' in text and 'hardware mocked' in text, text
        assert list(work.iterdir()) == [executable], list(work.iterdir())
        print(text)
        for mode, status, marker in (
            ('keys', 0, 'keyboard ABI'), ('closed', 0, 'closed-window cleanup'),
            ('keyboard-error', 1, 'FAIL keyboard status=-6'),
            ('pointer-error', 1, 'FAIL pointer status=-6'),
        ):
            result = run([executable, '--run-gpu-mandelbrot'], expected=status, cwd=work,
                         env=dict(os.environ, TRUEOS_TEST_NO_SOURCE_IO='1',
                                  TRUEOS_TEST_MANDELBROT_RETAINED=mode))
            assert marker in result.stdout.decode(), (mode, result.stdout.decode())
        print('PASS retained UI4 no-focus idle, ABI input, zoom/pan redraw, quit, closed window and input errors; hardware mocked')

if __name__ == '__main__':
    main()
