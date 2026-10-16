#!/usr/bin/env python3
import re
import struct
import subprocess
import sys
from pathlib import Path


IMPORTS = {
    "trueos_cabi_shell_attached_write",
    "trueos_cabi_shell_attached_read_byte",
    "trueos_cabi_sleep_ms",
    "trueos_cabi_blueprint_stop_control_v1",
    "trueos_cabi_blueprint_shutdown",
    "trueos_cabi_blueprint_terminal_lease_current_v1",
    "trueos_cabi_blueprint_terminal_lease_release_v1",
    "trueos_cabi_blueprint_terminal_surface_snapshot_v1",
    "memcpy", "memset",
}


def package(source, destination):
    payload = source.read_bytes()
    if len(payload) < 64 or payload[:6] != b"\x7fELF\x02\x01":
        raise ValueError("expected little-endian ELF64")
    if struct.unpack_from("<HH", payload, 16) != (1, 62):
        raise ValueError("expected an x86-64 relocatable object")

    symbols = subprocess.check_output(
        ["readelf", "--symbols", "--wide", str(source)], text=True,
    )
    imports = set()
    entry = None
    for line in symbols.splitlines():
        fields = line.split()
        if len(fields) < 7 or not fields[0].endswith(":"):
            continue
        if fields[6] == "UND" and fields[4] in {"GLOBAL", "WEAK"}:
            if len(fields) != 8 or fields[7] not in IMPORTS:
                raise ValueError(f"unsupported import: {line.strip()}")
            imports.add(fields[7])
        if len(fields) == 8 and fields[7] == "main" and fields[3:5] == ["FUNC", "GLOBAL"]:
            section, offset = int(fields[6]), int(fields[1], 16)
            if not 0 < section < 0x10000 or not 0 <= offset <= 0xffffffff or int(fields[2]) == 0:
                raise ValueError("invalid Blueprint entry")
            entry = (section << 32) | offset
    if entry is None:
        raise ValueError("main entry not found")

    disassembly = subprocess.check_output(["objdump", "-d", str(source)], text=True)
    if re.search(r"\b(?:syscall|sysenter)\b", disassembly):
        raise ValueError("raw system call instruction in native TRUEOS app")

    # RAW payload, argv-v1 entry, and no application filesystem requirement.
    flags = 1 | (1 << 9) | (1 << 10)
    header = struct.pack("<4sHHQII", b"TRBP", 1, flags, entry, len(payload), len(payload))
    destination.write_bytes(header + payload)
    print(f"{destination}: {len(payload)} ELF bytes; native imports: {', '.join(sorted(imports))}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(f"usage: {sys.argv[0]} input.o output.bp")
    try:
        package(Path(sys.argv[1]), Path(sys.argv[2]))
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        sys.exit(str(error))
