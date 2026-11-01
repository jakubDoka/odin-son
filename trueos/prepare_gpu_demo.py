#!/usr/bin/env python3
"""Verify the GPU demo snapshots and generate its embedded Odin fixtures."""
import argparse
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--from-export', type=Path)
    args = parser.parse_args()
    assets = ROOT / 'gpu-demo/assets'
    source = args.from_export or assets
    manifest = json.loads((source / 'manifest.json').read_text())
    assert len(manifest['tests']) == 5
    codes = []
    for test in manifest['tests']:
        name = test['name']
        assert re.fullmatch(r'gpu_[a-z_]+', name)
        code = (source / (test['kernel'] if args.from_export else name + '.eu')).read_bytes()
        assert len(code) == test['bytes'] and hashlib.sha256(code).hexdigest() == test['sha256'], name
        assert len(test['input_bits']) == 2 and all(len(row) == 8 for row in test['input_bits'])
        assert len(test['expected_bits']) == 8 and test['max_float_ulps'] == 0
        assert test['result_type'] in ('bool', 'f32')
        codes.append(code)
    if args.from_export:
        assets.mkdir(parents=True, exist_ok=True)
        for test, code in zip(manifest['tests'], codes):
            (assets / (test['name'] + '.eu')).write_bytes(code)
        (assets / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    definitions = 'package main\n\n'
    for test, code in zip(manifest['tests'], codes):
        definitions += f"{test['name']}_code :: \"" + ''.join(f"\\x{byte:02x}" for byte in code) + '\"\n'
    definitions += '\nget_case :: proc(index: int, out: ^GPU_Case) {\n    switch index {\n'
    for i, test in enumerate(manifest['tests']):
        rows = ','.join('{' + ','.join(map(str, row)) + '}' for row in test['input_bits'])
        expected = ','.join(map(str, test['expected_bits']))
        name = test['name']
        definitions += (f'    case {i}:\n'
                        f'        out.name = "{name}"\n'
                        f'        out.code = transmute([]u8){name}_code\n'
                        f'        out.sha256 = "{test["sha256"]}"\n'
                        f'        out.boolean = {str(test["result_type"] == "bool").lower()}\n'
                        f'        out.inputs = {{{rows}}}\n'
                        f'        out.expected = {{{expected}}}\n')
    definitions += '    }\n}\n'
    target = ROOT / 'gpu-demo/cases.odin'
    if not target.exists() or target.read_text() != definitions:
        target.write_text(definitions)


if __name__ == '__main__':
    main()
