#!/usr/bin/env python3
"""Compile both matrix-demo targets through Odin SON and package one Blueprint."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

from compile_gpu_tests import EXPORTER
from package import package

NATIVE = Path(__file__).resolve().parent
ROOT = NATIVE.parent


def run(args, **kwargs):
    subprocess.run([str(arg) for arg in args], check=True, timeout=20, **kwargs)


def main():
    odin = shutil.which(os.environ.get('ODIN', 'odin'))
    if not odin:
        raise SystemExit('Set ODIN to an upstream Odin compiler for bootstrapping.')
    output = NATIVE / 'build/matrix-demo'
    output.mkdir(parents=True, exist_ok=True)
    for name in ('mac.bin', 'odin-matrix.raw.o', 'odin-matrix.o', 'odin-matrix.bp', 'build.json'):
        (output / name).unlink(missing_ok=True)
    shader = (NATIVE / 'matrix-demo/mac.odin.source').read_text()
    exporter = EXPORTER[:EXPORTER.index('    rng: rand.PCG_Random_State')]
    exporter += '    return Record{}\n}\nmain :: proc() {\n    bac.init_custom_fmt(); typecheck.init_type_fmt()\n'
    exporter += '    compile("mac", ' + '`' + shader + '`' + ', "u32", 4, 0, nil)\n}\n'
    # Keep the small exporter independent of fixture RNG and reference evaluation.
    for unused in ('base:runtime', 'core:encoding/json', 'core:hash', 'core:math/rand'):
        exporter = exporter.replace(f'import "{unused}"\n', '')
    with tempfile.TemporaryDirectory(prefix='odin-matrix-') as temporary:
        stage = Path(temporary)
        for name in ('bac', 'odinc'):
            shutil.copytree(ROOT / name, stage / name)
        (stage / 'utils').symlink_to(ROOT / 'utils', target_is_directory=True)
        compatibility = stage / 'bac/codegen.odin'
        compatibility.write_text(compatibility.read_text().replace('max(node.lane, .I16)', 'max(node.lane, Lane_Type.I16)'))
        (stage / 'exporter').mkdir()
        (stage / 'exporter/main.odin').write_text(exporter)
        obj, executable = stage / 'exporter.o', stage / 'exporter-bin'
        run([odin, 'build', stage / 'exporter', '-build-mode:obj', '-use-single-module', f'-out:{obj}'])
        run([os.environ.get('CC', 'gcc'), obj, '-lm', '-ldl', '-lpthread', '-o', executable])
        run([executable], cwd=output)
    kernel = (output / 'mac.bin').read_bytes()
    if not 112 <= len(kernel) <= 2048 or len(kernel) % 16:
        raise SystemExit('Matrix MAC exceeds the native code limit')
    # Generated files live outside the source package so failed builds cannot leave a stale shader.
    (output / 'main.odin').write_bytes((NATIVE / 'matrix-demo/main.odin').read_bytes())
    (output / 'kernel.odin').write_text('package main\nmac_code :: \"' + ''.join(f'\\x{byte:02x}' for byte in kernel) + '\"\n')
    compiler = os.environ.get('ODIN_SON')
    if not compiler:
        run(['python3', NATIVE / 'build_host_compiler.py'])
        compiler = str(NATIVE / 'build/odin-son-host')
    collections = output / 'collections'
    for name in ('base', 'core', 'vendor'):
        (collections / name).mkdir(parents=True, exist_ok=True)
    cpu = output / 'odin-matrix.raw.o'
    # COMPILER BUG: aggressive inlining recreates the failing three-loop SSA form in square().
    # Keep -o:all instead of the compiler default -o:aggresive until that verifier bug is fixed.
    run([compiler, output / 'main.odin', '-o:all', '-o', cpu], env=dict(os.environ, ODIN_ROOT=str(collections)))
    packaged = output / 'odin-matrix.o'
    run(['objcopy', '--strip-debug', cpu, packaged])
    blueprint = output / 'odin-matrix.bp'
    package(packaged, blueprint, entry_symbol='main', filesystem_independent=True)
    digest = lambda path: hashlib.sha256(Path(path).read_bytes()).hexdigest()
    receipt = dict(cpu_compiler='odin-son', gpu_compiler='odin-son', simd_width=8,
                   source_sha256={name: digest(NATIVE / 'matrix-demo' / name) for name in ('main.odin', 'mac.odin.source')},
                   compiler_sha256=digest(shutil.which(compiler) or compiler), kernel_sha256=digest(output / 'mac.bin'),
                   blueprint_sha256=digest(blueprint), hardware_executed=False)
    (output / 'build.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(blueprint)


if __name__ == '__main__':
    main()
