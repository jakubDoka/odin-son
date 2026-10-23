#!/usr/bin/env python3
import os
from pathlib import Path
import struct
import subprocess
import tempfile

NATIVE = Path(__file__).resolve().parent

def run(args, **kwargs):
    result = subprocess.run([str(a) for a in args], capture_output=True, timeout=12, **kwargs)
    assert result.returncode == 0, (args, result.returncode, result.stdout[-4000:], result.stderr)
    return result


def main():
    with tempfile.TemporaryDirectory() as directory:
        work = Path(directory)
        exe = work / 'compiler'
        run(['gcc', '-std=c11', NATIVE / 'test_host.c', NATIVE / 'build/odin-son.o', '-lm', '-o', exe])
        def tui(keys, **env):
            return run([exe], cwd=work, env=dict(os.environ, TRUEOS_TEST_TUI_KEYS=keys, **env)).stdout
        seeded = tui('j\r\rrq', TRUEOS_TEST_STABLE_HEAP='1', TRUEOS_TEST_REENTRY='1')
        assert b'stage=discovery demos=4' in seeded
        assert seeded.count(b'[odin-son tui] stage=compile demo=gpu-boids status=0\n') == 2
        assert b'stage=launch demo=gpu-boids status=0\n' in seeded
        assert b'\x1b[48;2;16;16;16m' in seeded and b'\x1b[?1049l' in seeded
        bp = (work / 'demo-gpu-boids.bp').read_bytes()
        assert struct.unpack('<4sHHQII', bp[:24])[:4] == (b'TRBP', 1, 0x601, 0)
        assert bp[24:] == (work / 'demo-gpu-boids.o').read_bytes()
        native = tui('jj\rq', TRUEOS_TEST_STABLE_HEAP='1')
        assert b'gpu-mandelbrot  [embedded native EU]' in native
        assert b'Enter emit EU  r Mandelbrot' in native
        assert b'stage=compile demo=gpu-mandelbrot status=0' in native
        assert b'stage=stored artifact=mandelbrot.eu.bin' in native
        assert (work / 'mandelbrot.eu.bin').stat().st_size > 1000
        hello_ok = tui('k\rq', TRUEOS_TEST_STABLE_HEAP='1')
        assert b'stage=compile demo=hello status=0\n' in hello_ok
        run(['objcopy', '--redefine-sym', 'main=hello_entry', work / 'demo-hello.o', work / 'hello-host.o'])
        (work / 'hello-host.c').write_text('#include <stdint.h>\n#include <stdio.h>\nint32_t hello_entry(void);\nvoid trueos_cabi_write(uint32_t s, const void *p, uintptr_t n) { fwrite(p, 1, n, stdout); }\nint main(void) { return hello_entry(); }\n')
        run(['gcc', work / 'hello-host.o', work / 'hello-host.c', '-o', work / 'hello-host'])
        assert b'sum(0..<10) = 45' in run([work / 'hello-host']).stdout
        # Seeding must preserve edited sources, and one failed job must not kill the VM.
        hello = work / 'hello/main.odin'
        hello.write_text('package main\nmain :: proc() -> i32 { return missing }\n')
        failing = tui('k\rj\rq')  # hello fails, then cpu-boids succeeds
        assert b'stage=compile demo=hello status=1\n' in failing
        assert b'stage=compile demo=cpu-boids status=0\n' in failing
        assert 'missing' in hello.read_text()
        hello.write_text('package main\nmain :: proc( {\n')
        malformed = tui('k\rj\rq')
        assert b'stage=compile demo=hello status=1\n' in malformed
        assert b'stage=compile demo=cpu-boids status=0\n' in malformed
        discovered = tui('fq', TRUEOS_TEST_ADD_DEMO='1')
        assert b'stage=discovery demos=5' in discovered and b' extra' in discovered
        hello.write_bytes((NATIVE / 'hello.odin.source').read_bytes())
        repeated = tui('kkk' + '\r'*8 + 'rq', TRUEOS_TEST_STABLE_HEAP='1')
        assert repeated.count(b'[odin-son tui] stage=compile demo=gpu-boids status=0\n') == 8
        assert b'stage=launch demo=gpu-boids status=0\n' in repeated
        automatic = tui('q', TRUEOS_TEST_AUTO_DISCOVER='1')
        assert b'stage=discovery demos=6' in automatic and b' auto' in automatic
        native_ui = work / 'native-ui'
        native_ui.mkdir()
        driver = work / 'native-ui.c'
        driver.write_text(r'''
#include <assert.h>
#include <stdint.h>
#include <stddef.h>
#include <string.h>
static size_t uploaded;
static unsigned renders, publishes, closes, keyboard_polls;
uint32_t trueos_cabi_ui4_scene_frame_open_visual(int32_t x,int32_t y,uint32_t w,uint32_t h,uint32_t hz) {
    assert(w==320 && h==240 && hz==30); return 7;
}
int32_t trueos_cabi_ui4_scene_native_compute_upload_v1(uint32_t w,uint32_t offset,uint32_t total,const void *p,size_t n) {
    assert(w==7 && offset==uploaded && total>1000 && n<=2048 && p); uploaded+=n; return 0;
}
int32_t trueos_cabi_ui4_scene_visual_frame_begin(uint32_t w) {assert(w==7);return 0;}
int32_t trueos_cabi_ui4_scene_native_compute_render_v1(uint32_t w,float x,float y,float dx,float dy) {
    assert(w==7 && uploaded>1000 && dx>0 && dy>0);++renders;return 0;
}
int32_t trueos_cabi_ui4_scene_compute_frame_publish(uint32_t w,uint32_t x,uint32_t y,uint32_t width,uint32_t height) {
    assert(w==7 && renders==1 && width==320 && height==240);++publishes;return 0;
}
int32_t trueos_cabi_ui4_scene_keyboard_state(uint32_t w,void *out) {
    assert(w==7 && publishes==1 && !closes && keyboard_polls<3);
    memset(out,0,64);
    if (++keyboard_polls==1) return 1;
    if (keyboard_polls==3) {uint32_t q=1u<<20;memcpy((unsigned char *)out+32,&q,4);}
    return 0;
}
int32_t trueos_cabi_ui4_scene_pointer_event_take(uint32_t w,void *out) {assert(w==7);return 1;}
int32_t trueos_cabi_ui4_solara_frame_close(uint32_t w) {assert(w==7 && keyboard_polls==3);++closes;return 0;}
__attribute__((destructor)) static void verify(void) {assert(renders==1 && publishes==1 && closes==1);}
''')
        native_exe = work / 'native-compiler'
        run(['gcc', '-std=c11', NATIVE / 'test_host.c', driver,
             NATIVE / 'build/odin-son.o', '-lm', '-o', native_exe])
        rendered = run([native_exe], cwd=native_ui, env=dict(
            os.environ, TRUEOS_TEST_TUI_KEYS='jj\rrq', TRUEOS_TEST_STABLE_HEAP='1')).stdout
        assert b'stage=launch demo=gpu-mandelbrot status=0' in rendered
        assert b'stage=runtime-compiled iterations=25' in rendered
        assert b'Mandelbrot finished. Compiler stays ready.' in rendered
    print('PASS: native TUI seeds/preserves demos; discovers new directories; repeated compilation has stable live heap allocations; semantic/parse failures recover; queued launch, terminal resize/reentry, short writes and quit release are exercised by ABI mocks.')

if __name__ == '__main__':
    main()
