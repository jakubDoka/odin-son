#!/usr/bin/env python3
"""Package the odin-son-emitted runner and record its build provenance."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

from package import package

NATIVE = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--compiler', type=Path, required=True)
    args = parser.parse_args()
    source = NATIVE / 'build/odin-son-gpu.o'
    blueprint = NATIVE / 'build/odin-son-gpu.bp'
    package(source, blueprint, entry_symbol='main', filesystem_independent=True)
    digest = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
    fixture = NATIVE / 'gpu-demo/assets/manifest.json'
    manifest = json.loads(fixture.read_text())
    for test in manifest['tests']:
        assert digest(NATIVE / ('gpu-demo/assets/' + test['name'] + '.eu')) == test['sha256']
    imports = subprocess.check_output(['nm', '-u', str(source)], text=True).split()
    imports = sorted(set(imports) - {'U'})
    assert not any('alloc' in name or 'runtime' in name for name in imports), imports
    receipt = dict(runner_compiler='odin-son', shader_compiler='odin-son',
                   compiler_binary_sha256=digest(args.compiler),
                   source_sha256={name: digest(NATIVE / name) for name in ('gpu-demo/main.odin', 'gpu-demo/cases.odin')},
                   fixture_manifest_sha256=digest(fixture),
                   raw_cpu_object_sha256=digest(NATIVE / 'build/odin-son-gpu.raw.o'),
                   cpu_object_sha256=digest(source), packaging_transforms=['strip-debug'], blueprint_sha256=digest(blueprint),
                   imports=imports, sdk_collections_used=False, hardware_executed=False,
                   kernels=[dict(name=test['name'], sha256=test['sha256']) for test in manifest['tests']])
    (NATIVE / 'build/odin-son-gpu-build.json').write_text(json.dumps(receipt, indent=2) + '\n')


if __name__ == '__main__':
    main()
