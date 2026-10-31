#!/usr/bin/env python3
"""Compare native and desktop frontend loops with upstream Odin execution."""
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
ODIN = os.environ.get('ODIN', 'odin')
CASES = {
    'sum': 'total := 0; for i := 0; i < 10; i += 1 { total += i }; return total',
    'empty': 'total := 7; for i := 8; i < 3; i += 1 { total += i }; return total',
    'continue': 'total := 0; for i := 0; i < 8; i += 1 { if i % 2 == 0 do continue; total += i }; return total',
    'all-continue': 'i := 0; for ; i < 5; i += 1 { continue }; return i',
    'break': 'post := 0; for i := 0; i < 10; post += 1 { if i == 3 do break; i += 1 }; return post',
    'while': 'i := 0; for i < 9 { i += 1 }; return i',
    'no-condition': 'total := 0; for i := 0; ; i += 1 { if i == 5 do break; total += i }; return total',
    'post-call': 'i := 0; total := 0; for ; i < 5; i = tick(&i) { total += i }; return total',
    'init-once': 'i := 9; total := 0; for i = 0; i < 4; i += 1 { total += i }; return total + i',
    'no-init': 'i := 1; total := 0; for ; i < 5; i += 1 { total += i }; return total',
    'shadow': 'i := 70; total := 0; for i := 0; i < 4; i += 1 { total += i }; return i + total',
    # COMPILER BUG: start_if(cond); start_else(); loop_control(.Break) crashes loop scheduling here.
    'nested': 'total := 0; for i := 0; i < 4; i += 1 { for j := 0; j < 5; j += 1 { if j == 1 do continue; if j == 4 do break; total += i + j } }; return total',
    'outer-continue': 'total := 0; outer: for i := 0; i < 4; i += 1 { for j := 0; j < 5; j += 1 { if j == 2 do continue outer; total += i + j } }; return total',
    'outer-break': 'total := 0; outer: for i := 0; i < 4; i += 1 { for j := 0; j < 5; j += 1 { if i == 2 do break outer; total += j } }; return total',
    'body-shadow': 'total := 0; for i := 0; i < 4; i += 1 { i := 2; total += i }; return total',
    'return': 'for i := 0; i < 5; i += 1 { if i == 2 do return 22 }; return 3',
    'side-effects': 'init := 0; cond := 0; post := 0; body := 0; for i := tick(&init); tick(&cond) < 4; post += 1 { body += i }; return init * 100 + cond * 10 + post + body',
    'constant-true': 'for true { return 17 }; return 99',
    'constant-false': 'for false { return 3 }; return 9',
}
HELPER = 'tick :: proc(v: ^int) -> int { v^ += 1; return v^ }\n'
LEVELS = ('none', 'none-quick', 'moderate-quick', 'moderate', 'all', 'aggresive')


def run(args, expected=0, **kwargs):
    result = subprocess.run([str(a) for a in args], capture_output=True, timeout=12, **kwargs)
    assert result.returncode == expected, (args, result.returncode, result.stdout, result.stderr)
    return result


def main():
    with tempfile.TemporaryDirectory() as directory:
        work = Path(directory)
        native = work / 'native-compiler'
        run(['gcc', '-std=c11', ROOT / 'trueos/test_host.c', ROOT / 'trueos/build/odin-son.o', '-lm', '-o', native])
        desktop = Path(os.environ.get('ODIN_SON_DESKTOP', ROOT / 'odin-son'))
        compilers = [native]
        if os.environ.get('ODIN_SON_DESKTOP'):
            compilers.append(desktop)
        count = 0
        for name, body in CASES.items():
            source_dir = work / name
            source_dir.mkdir()
            source = source_dir / 'main.odin'
            source.write_text('package main\n' + HELPER + 'main :: proc() -> int {\n' + body + '\n}\n')
            reference = work / (name + '-ref')
            reference.mkdir()
            (reference / 'main.odin').write_text('package main\nimport "core:os"\n' + HELPER + 'calculate :: proc() -> int {\n' + body + '\n}\nmain :: proc() { os.exit(calculate()) }\n')
            ref_bin = work / 'reference'
            run([ODIN, 'build', reference, '-out:' + str(ref_bin)])
            expected = subprocess.run([ref_bin], capture_output=True, timeout=12)
            for compiler in compilers:
                for level in LEVELS:
                    obj = work / 'loop.o'
                    run([compiler, '--cpu-boids', source, '-o:' + level, '-o', obj] if compiler == native else [compiler, source, '-o:' + level, '-o', obj])
                    binary = work / 'loop'
                    run(['gcc', obj, '-o', binary])
                    actual = subprocess.run([binary], capture_output=True, timeout=12)
                    assert (actual.returncode, actual.stdout, actual.stderr) == (expected.returncode, expected.stdout, expected.stderr), (name, compiler, level, actual, expected)
                    count += 1
        for name, body, diagnostic in (
            ('scope', 'for i := 0; i < 2; i += 1 {}; return i', b'undeclared'),
            ('condition', 'for i := 0; i; i += 1 { break }; return 0', b'expected bool'),
            ('missing-return', 'for true { return 17 }', b'expected return'),
            ('post-scope', 'for i := 0; i < 2; i += step { step := 1 }; return 0', b'undeclared'),
        ):
            source_dir = work / name
            source_dir.mkdir()
            source = source_dir / 'main.odin'
            source.write_text('package main\nmain :: proc() -> int {\n' + body + '\n}\n')
            for compiler in compilers:
                result = run([compiler, '--cpu-boids', source, '-o', work / 'bad.o'] if compiler == native else [compiler, source, '-o', work / 'bad.o'], expected=1)
                assert diagnostic in result.stderr, (name, result.stderr)
        print(f'PASS: {len(CASES)} loop cases x {len(LEVELS)} optimization levels x {len(compilers)} compiler builds = {count} upstream execution comparisons; scope and condition errors rejected.')

if __name__ == '__main__':
    main()
