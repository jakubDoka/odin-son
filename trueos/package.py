#!/usr/bin/env python3
from pathlib import Path
import re
import struct
import subprocess
import sys

IMPORTS = {
    'memcpy', 'memmove', 'memset', 'sys_alloc_aligned',
    'trueos_cabi_alloc', 'trueos_cabi_calloc', 'trueos_cabi_realloc', 'trueos_cabi_free',
    'trueos_cabi_write', 'trueos_cabi_blueprint_stop_control_v1', 'trueos_cabi_blueprint_shutdown',
    'trueos_cabi_async_fs_read_start', 'trueos_cabi_async_fs_stat_start',
    'trueos_cabi_async_fs_typed_list_dir_start', 'trueos_cabi_async_fs_write_begin',
    'trueos_cabi_async_fs_write_chunk', 'trueos_cabi_async_fs_write_commit',
    'trueos_cabi_async_fs_status', 'trueos_cabi_async_fs_result_len',
    'trueos_cabi_async_fs_result_read', 'trueos_cabi_async_fs_discard', 'trueos_cabi_poll_once',
}

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
        package(Path(sys.argv[1]), Path(sys.argv[2]))
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        sys.exit(str(error))
