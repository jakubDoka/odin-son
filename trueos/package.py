#!/usr/bin/env python3
from pathlib import Path
import re
import hashlib
import io
import os
import tarfile
import tempfile
import struct
import subprocess
import sys

IMPORTS = {
    'trueos_cabi_shell_attached_write', 'trueos_cabi_shell_attached_read_byte', 'trueos_cabi_sleep_ms',
    'trueos_cabi_blueprint_terminal_lease_current_v1', 'trueos_cabi_blueprint_terminal_lease_release_v1',
    'trueos_cabi_blueprint_terminal_surface_snapshot_v1', 'trueos_cabi_async_fs_create_dir_all_start',
    'memcpy', 'memmove', 'memset', 'sys_alloc_aligned',
    'trueos_cabi_alloc', 'trueos_cabi_calloc', 'trueos_cabi_realloc', 'trueos_cabi_free',
    'trueos_cabi_write', 'trueos_cabi_blueprint_stop_control_v1', 'trueos_cabi_blueprint_shutdown',
    'trueos_cabi_blueprint_launch_script_v1',
    'trueos_cabi_async_fs_read_start', 'trueos_cabi_async_fs_stat_start',
    'trueos_cabi_async_fs_typed_list_dir_start', 'trueos_cabi_async_fs_write_begin',
    'trueos_cabi_async_fs_write_chunk', 'trueos_cabi_async_fs_write_commit',
    'trueos_cabi_async_fs_status', 'trueos_cabi_async_fs_result_len',
    'trueos_cabi_async_fs_result_read', 'trueos_cabi_async_fs_discard', 'trueos_cabi_poll_once',
}

EXCLUDED_SUFFIXES = {'.a', '.so', '.dll', '.dylib', '.o', '.obj', '.lib', '.exe', '.pdb'}

def attach_sdk(source, destination, sdk):
    entries = []
    sdk = sdk.resolve(strict=True)
    for collection in ('base', 'core', 'vendor'):
        root = sdk / collection
        if not root.is_dir():
            raise ValueError(f'missing SDK collection: {root}')
        for path in sorted(root.rglob('*')):
            if path.is_symlink() and path.is_dir():
                raise ValueError(f'SDK directory symlink cannot be bundled safely: {path}')
            if not path.is_file() or path.suffix.lower() in EXCLUDED_SUFFIXES:
                continue
            resolved = path.resolve(strict=True)
            if not resolved.is_relative_to(sdk):
                raise ValueError(f'SDK asset escapes root: {path}')
            data = path.read_bytes()
            if data.startswith((b'\x7fELF', b'!<arch>\n', b'MZ')):
                continue
            name = path.relative_to(sdk).as_posix()
            if any(part in ('', '.', '..') or len(part.encode()) > 255 for part in name.split('/')) or len(name.encode()) > 4096:
                raise ValueError(f'invalid SDK asset path: {name}')
            entries.append((name.encode(), data))
    license_path = sdk / 'LICENSE'
    if not license_path.is_file():
        raise ValueError(f'missing SDK license: {license_path}')
    entries.append((b'odin-sdk-LICENSE', license_path.read_bytes()))
    entries.sort(key=lambda item: item[0])
    if len(entries) > 65536:
        raise ValueError('SDK asset count exceeds kernel cap')
    bundle = bytearray(struct.pack('<4sHHI', b'TRAS', 1, 0, len(entries)))
    for name, data in entries:
        if len(data) > 512 * 1024 * 1024:
            raise ValueError('SDK asset exceeds kernel file cap')
        bundle += struct.pack('<IQ', len(name), len(data)) + hashlib.sha256(data).digest() + name + data
    if len(bundle) > 2 * 1024 * 1024 * 1024:
        raise ValueError('SDK bundle exceeds kernel decode cap')
    with tempfile.TemporaryDirectory(prefix='odin-assets-', dir=destination.parent) as temp:
        temp = Path(temp)
        tar_path, archive = temp / 'assets.tar', temp / 'assets.tar.lz4'
        with tarfile.open(tar_path, 'w', format=tarfile.USTAR_FORMAT) as tar:
            info = tarfile.TarInfo('assets.bundle')
            info.size = len(bundle)
            info.mode = 0o644
            info.uid = info.gid = info.mtime = 0
            tar.addfile(info, io.BytesIO(bundle))
        subprocess.check_call(['lz4', '-12', '-BI', '--content-size', '-f', str(tar_path), str(archive)])
        if archive.stat().st_size > 1024 * 1024 * 1024:
            raise ValueError('SDK archive exceeds kernel archive cap')
        subprocess.check_call(['objcopy', '--add-section', f'.trueos.assets={archive}',
                               '--set-section-flags', '.trueos.assets=readonly,contents',
                               str(source), str(destination)])
    print(f'embedded SDK collections: {len(entries)} files, {len(bundle)} bytes')

def package(source, destination):
    payload = source.read_bytes()
    if payload[:6] != b'\x7fELF\x02\x01' or struct.unpack_from('<HH', payload, 16) != (1, 62):
        raise ValueError('expected an x86-64 ELF64 relocatable object')
    imports = set(subprocess.check_output(['nm', '-u', source], text=True).split()) - {'U'}
    retired = {name for name in imports if name.startswith(('trueos_cabi_fs_', 'trueos_cabi_trueosfs_'))}
    if retired:
        raise ValueError(f'retired synchronous filesystem imports: {sorted(retired)}')
    if imports - IMPORTS:
        raise ValueError(f'unsupported imports: {sorted(imports - IMPORTS)}')
    disassembly = subprocess.check_output(['objdump', '-d', source], text=True)
    if re.search(r'\b(syscall|sysenter)\b', disassembly):
        raise ValueError('native compiler contains a raw system call instruction')
    relocations = subprocess.check_output(['readelf', '-rW', source], text=True)
    allowed = {'R_X86_64_64', 'R_X86_64_PC32', 'R_X86_64_PLT32', 'R_X86_64_GOTPCREL', 'R_X86_64_GOTPCRELX', 'R_X86_64_REX_GOTPCRELX', 'R_X86_64_32S'}
    unsupported = set(re.findall(r'R_X86_64_\w+', relocations)) - allowed
    if unsupported:
        raise ValueError(f'unsupported relocations: {sorted(unsupported)}')
    symbols = subprocess.check_output(['readelf', '-sW', source], text=True)
    for line in symbols.splitlines():
        parts = line.split()
        if len(parts) == 8 and parts[3:5] == ['FUNC', 'GLOBAL'] and parts[7] == 'trueos_main':
            entry = (int(parts[6]) << 32) | int(parts[1], 16)
            break
    else:
        raise ValueError('native compiler entry not found')
    destination.write_bytes(struct.pack('<4sHHQII', b'TRBP', 1, 0x201, entry, len(payload), len(payload)) + payload)
    print(f'{destination}: {len(payload)} ELF bytes, {len(imports)} native imports, no Linux runtime')

if __name__ == '__main__':
    try:
        if len(sys.argv) == 5 and sys.argv[3] == '--sdk':
            raw = Path(sys.argv[1])
            packed = raw.with_name('odin-son.o')
            attach_sdk(raw, packed, Path(sys.argv[4]))
            package(packed, Path(sys.argv[2]))
        elif len(sys.argv) == 3:
            package(Path(sys.argv[1]), Path(sys.argv[2]))
        else:
            raise ValueError('usage: package.py object output.bp [--sdk sdk-root]')
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        sys.exit(str(error))
