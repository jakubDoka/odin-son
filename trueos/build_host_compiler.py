#!/usr/bin/env python3
"""Bootstrap a desktop odin-son compiler, keeping compatibility edits in staging."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--odin', default=os.environ.get('ODIN', 'odin'))
    parser.add_argument('--cc', default=os.environ.get('CC', 'gcc'))
    parser.add_argument('--output', type=Path, default=ROOT / 'trueos/build/odin-son-host')
    args = parser.parse_args()
    odin = shutil.which(args.odin)
    if not odin:
        parser.error('upstream Odin is needed to bootstrap odin-son; set ODIN')
    env = dict(os.environ)
    env['ODIN_ROOT'] = subprocess.check_output([odin, 'root'], text=True).strip()
    with tempfile.TemporaryDirectory(prefix='odin-son-host-') as directory:
        stage = Path(directory)
        for name in ('bac', 'odinc'):
            shutil.copytree(ROOT / name, stage / name)
        (stage / 'utils').symlink_to(ROOT / 'utils', target_is_directory=True)
        source = stage / 'bac/codegen.odin'
        source.write_text(source.read_text().replace('max(node.lane, .I16)', 'max(node.lane, Lane_Type.I16)'))
        obj, binary = stage / 'compiler.o', stage / 'odin-son'
        subprocess.run([odin, 'build', str(stage / 'odinc'), '-build-mode:obj', '-use-single-module', f'-out:{obj}'],
                       env=env, check=True, timeout=20)
        subprocess.run([args.cc, str(obj), '-lm', '-ldl', '-lpthread', '-o', str(binary)], check=True, timeout=20)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(binary, args.output)
    print(f'Bootstrapped odin-son: {args.output}')


if __name__ == '__main__':
    main()
