#!/usr/bin/env python3
from pathlib import Path
import shutil
import sys

ROOT = Path(__file__).resolve().parent.parent
NATIVE = ROOT / 'trueos'
BUILD = NATIVE / 'build'
SDK = Path(sys.argv[1]).resolve()

def overlay(source, dest, replace=()):
    dest.mkdir(parents=True, exist_ok=True)
    for item in source.iterdir():
        target = dest / item.name
        if item.name in replace:
            shutil.copytree(item, target, dirs_exist_ok=True)
        elif not target.exists():
            target.symlink_to(item, target_is_directory=item.is_dir())

stage = BUILD / 'src'
stage.mkdir(parents=True, exist_ok=True)
for name in ('gen.odin', 'elf.odin', 'wasm_object.odin', 'gpu_native.odin'):
    shutil.copy2(ROOT / name, stage / name)
for name in ('bac', 'typecheck', 'utils'):
    shutil.copytree(ROOT / name, stage / name, dirs_exist_ok=True)
shutil.copytree(ROOT / 'vendored/gam/util', stage / 'vendored/gam/util', dirs_exist_ok=True)
for test in stage.rglob('*_test.odin'):
    test.unlink()
shutil.copytree(NATIVE / 'platform', stage / 'platform', dirs_exist_ok=True)
shutil.copy2(NATIVE / 'main.odin', stage / 'main.odin')
shutil.copy2(NATIVE / 'embedded.odin', stage / 'embedded.odin')
shutil.copy2(NATIVE / 'tui.odin', stage / 'tui.odin')
shutil.copy2(NATIVE / 'mandelbrot.odin', stage / 'mandelbrot.odin')
shutil.copy2(ROOT / 'examples/gpu-mandelbrot-trueos/main.odin', stage / 'mandelbrot.source')
shutil.copy2(NATIVE / 'hello.odin.source', stage / 'hello.source')
arena = stage / 'utils/arna/arna.odin'
arena.write_text(arena.read_text().replace('ODIN_OS == .Freestanding', 'false'))
virtual_aliases = stage / 'utils/arna/virtual.odin'
virtual_aliases.write_text(virtual_aliases.read_text().replace('#+build !freestanding\n', ''))
local_fmt = stage / 'utils/fmt/fmt.odin'
local_fmt.write_text(local_fmt.read_text().replace('ODIN_OS != .Freestanding', 'true'))
boids = (ROOT / 'examples/boids-trueos/main.odin').read_bytes()
if b'intrinsics.syscall' in boids or b'trueos_cabi_shell_attached_write' not in boids:
    raise SystemExit('embedded boids must use the native TRUEOS ABI')
(stage / 'boids.source').write_bytes(boids)
gpu_boids = (ROOT / 'examples/gpu-boids-trueos/main.odin').read_text()
gpu_phy = (ROOT / 'examples/gpu-boids-trueos/phy.odin').read_text().removeprefix('package main\n')
(stage / 'gpu-boids.source').write_text(gpu_boids + '\n' + gpu_phy)
loader = (ROOT / 'loader.odin').read_text().replace('#+build !wasm32\n', '')
loader = loader.replace('import "core:os"', 'import os "platform"').replace('import "core:path/filepath"', '').replace('filepath.', 'os.')
loader = loader.replace('fmt.assertf(oerr == nil, "cannot open module directory %q", dir)', 'if oerr != nil { fmt.eprintln("cannot open module directory", dir); ctx.error_cnt += 1; return mid }')
loader = loader.replace('fmt.assertf(rerr == nil, "cannot read module directory %q", dir)', 'if rerr != nil { fmt.eprintln("cannot read module directory", dir); ctx.error_cnt += 1; return mid }')
loader = loader.replace('fmt.assertf(serr == nil, "cannot read %q", entry.fullpath)', 'if serr != nil { fmt.eprintln("cannot read", entry.fullpath); ctx.error_cnt += 1; return mid }')
loader = loader.replace('fmt.assertf(pok, "failed to parse %q", entry.fullpath)', 'if !pok { fmt.eprintln("failed to parse", entry.fullpath); ctx.error_cnt += 1; return mid }')
(stage / 'loader.odin').write_text(loader)
p = stage / 'bac/gcm.odin'
p.write_text(p.read_text().replace('import "core:os"', 'import os "../platform"'))

sdk = BUILD / 'sdk'
overlay(SDK, sdk, ('base',))
# Keep platform adapters in this disposable SDK; the installed Odin SDK stays shared.
if (sdk / 'core').is_symlink(): (sdk / 'core').unlink()
overlay(SDK / 'core', sdk / 'core', ('fmt',))
if (sdk / 'core/odin').is_symlink(): (sdk / 'core/odin').unlink()
overlay(SDK / 'core/odin', sdk / 'core/odin', ('parser',))
(sdk / 'core/odin/parser/parse_files.odin').unlink(missing_ok=True)
shutil.copy2(NATIVE / 'runtime.odin', sdk / 'base/runtime/os_specific_freestanding.odin')
shutil.copy2(NATIVE / 'heap.odin', sdk / 'base/runtime/heap_allocator_other.odin')
shutil.copy2(NATIVE / 'fmt.odin', sdk / 'core/fmt/fmt_trueos.odin')
# Virtual reservations use bounded guest backing for this first native build.
virtual = sdk / 'core/mem/virtual'
if (sdk / 'core/mem').is_symlink(): (sdk / 'core/mem').unlink()
overlay(SDK / 'core/mem', sdk / 'core/mem', ('virtual',))
shutil.copy2(NATIVE / 'virtual.odin', virtual / 'virtual_other.odin')
print(stage)

if (sdk / 'core/sync').is_symlink(): (sdk / 'core/sync').unlink()
overlay(SDK / 'core/sync', sdk / 'core/sync')
shutil.copy2(NATIVE / 'sync.odin', sdk / 'core/sync/thread_trueos.odin')
