#!/usr/bin/env python3
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
NATIVE = ROOT / 'trueos'
COMPILER = ROOT / 'odinc'
BUILD = NATIVE / 'build'
SDK = Path(sys.argv[1]).resolve()

def overlay(source, dest, replace=()):
    dest.mkdir(parents=True, exist_ok=True)
    for item in source.iterdir():
        target = dest / item.name
        if target.is_symlink():
            target.unlink()
        if item.name in replace:
            shutil.copytree(item, target, dirs_exist_ok=True)
        elif not target.exists():
            target.symlink_to(item, target_is_directory=item.is_dir())

stage = BUILD / 'src'
if stage.exists():
    shutil.rmtree(stage)
stage.mkdir(parents=True)
for name in ('gen.odin', 'elf.odin', 'wasm_object.odin'):
    (stage / name).write_text((COMPILER / name).read_text().replace('package odin_son', 'package main').replace('"../', '"'))
for name in ('bac', 'typecheck', 'utils'):
    shutil.copytree((COMPILER if name == 'typecheck' else ROOT) / name, stage / name, dirs_exist_ok=True)
for source in (stage / 'typecheck').glob('*.odin'):
    source.write_text(source.read_text().replace('"../../', '"../'))
scratch_defaults = stage / 'typecheck/typecheck.odin'
scratch_defaults.write_text(scratch_defaults.read_text().replace('4096 * 1024', '#config(TRUEOS_COMPILER_SCRATCH_MIB, 4)*1024*1024'))
for test in stage.rglob('*_test.odin'):
    test.unlink()
shutil.copytree(NATIVE / 'platform', stage / 'platform', dirs_exist_ok=True)
shutil.copy2(NATIVE / 'main.odin', stage / 'main.odin')
shutil.copy2(NATIVE / 'ide_build.odin', stage / 'ide_build.odin')
shutil.copy2(NATIVE / 'embedded.odin', stage / 'embedded.odin')
shutil.copy2(NATIVE / 'tui.odin', stage / 'tui.odin')
shutil.copy2(NATIVE / 'pixel.odin', stage / 'pixel.odin')
shutil.copy2(NATIVE / 'mandelbrot-demo/main.odin', stage / 'mandelbrot-main.source')
shutil.copy2(NATIVE / 'mandelbrot-demo/assets/shader.odin.source', stage / 'mandelbrot-shader.source')
shutil.copy2(NATIVE / 'mandelbrot-native-demo/main.odin', stage / 'mandelbrot-native-main.source')
shutil.copy2(NATIVE / 'mandelbrot-native-demo/shader.poc.odin.source', stage / 'mandelbrot-native-shader.source')
for name in ('main', 'render'):
    shutil.copy2(NATIVE / f'mandelbrot-poc-demo/{name}.odin', stage / f'mandelbrot-poc-{name}.source')
shutil.copy2(NATIVE / 'mandelbrot-poc-demo/shader.poc.odin.source', stage / 'mandelbrot-poc-shader.source')
shutil.copy2(NATIVE / 'water-light-demo/shader.poc.odin.source', stage / 'water-light-shader.source')
for name in ('main', 'field', 'optics'):
    shutil.copy2(NATIVE / f'water-light-demo/{name}.odin', stage / f'water-light-{name}.source')
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
loader = (COMPILER / 'loader.odin').read_text().replace('#+build !wasm32\n', '')
loader = loader.replace('package odin_son', 'package main').replace('"../', '"')
loader = loader.replace('import "core:os"', 'import os "platform"').replace('import "core:path/filepath"', '').replace('filepath.', 'os.')
loader = loader.replace('fmt.assertf(oerr == nil, "cannot open module directory %q", dir)', 'if oerr != nil { fmt.eprintln("cannot open module directory", dir); ctx.error_cnt += 1; return mid }')
loader = loader.replace('fmt.assertf(rerr == nil, "cannot read module directory %q", dir)', 'if rerr != nil { fmt.eprintln("cannot read module directory", dir); ctx.error_cnt += 1; return mid }')
loader = loader.replace('fmt.assertf(serr == nil, "cannot read %q", entry.fullpath)', 'if serr != nil { fmt.eprintln("cannot read", entry.fullpath); ctx.error_cnt += 1; return mid }')
loader = loader.replace('fmt.assertf(pok, "failed to parse %q", entry.fullpath)', 'if !pok { fmt.eprintln("failed to parse", entry.fullpath); ctx.error_cnt += 1; return mid }')
collection_assert = '''fmt.assertf(
\t\t\t\t\tok,
\t\t\t\t\t"unknown collection: %v, available: %v",
\t\t\t\t\tcol,
\t\t\t\t\tctx.collections,
\t\t\t\t)'''
if collection_assert not in loader:
    raise SystemExit('native loader collection diagnostic adapter no longer matches upstream')
loader = loader.replace(collection_assert, '''if !ok {
                    fmt.eprintfln("%s: collection import %s is unavailable in the native Odin SON profile; use import-free code, project-local modules, or base:intrinsics. External SDK collections require --odin-root explicitly.", ctx.files[ctx.modules[mid].file_start + i].fullpath, imp.relpath.text)
                    ctx.error_cnt += 1
                    continue
                }''')
(stage / 'loader.odin').write_text(loader)
p = stage / 'bac/codegen.odin'
p.write_text(p.read_text().replace('max(node.lane, .I16)', 'max(node.lane, Lane_Type.I16)'))
p = stage / 'bac/gcm.odin'
p.write_text(p.read_text().replace('import "core:os"', 'import os "../platform"'))

sdk = BUILD / 'sdk'
overlay(SDK, sdk, ('base',))
# Keep platform adapters in this disposable SDK; the installed Odin SDK stays shared.
if (sdk / 'core').is_symlink(): (sdk / 'core').unlink()
overlay(SDK / 'core', sdk / 'core', ('fmt',))
if (sdk / 'core/crypto').is_symlink(): (sdk / 'core/crypto').unlink()
overlay(SDK / 'core/crypto', sdk / 'core/crypto', ('sha2',))
sha2 = sdk / 'core/crypto/sha2'
(sha2 / 'sha256_impl_hw_intel.odin').unlink(missing_ok=True)
p = sha2 / 'sha256_impl_hw_gen.odin'
p.write_text(p.read_text().replace('#+build !amd64\n', ''))
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
