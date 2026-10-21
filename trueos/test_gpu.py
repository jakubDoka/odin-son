#!/usr/bin/env python3
import os
from pathlib import Path
import struct
import subprocess
import tempfile

NATIVE = Path(__file__).resolve().parent
ROOT = NATIVE.parent

HARNESS = r'''
#include <assert.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
extern int32_t boids_entry(size_t, char **);
static uint64_t completed;
static unsigned retries, closes, create_calls;
static float state[4] = {1, 2, 3, 4};
static unsigned live, ready, committed, yields, discarded;
static size_t request_size, request_written;
static uint8_t request[288], reply[24];
int32_t trueos_cabi_async_fs_read_start(const void *path, size_t len) { (void)path; (void)len; return -1; }
static uint64_t create(void) { return 7; }
static int32_t program(uint64_t handle, uint64_t frame,
                                          const uint32_t *words, size_t count) {
    assert(handle == 7 && frame == completed && count == 8);
    float expected = getenv("ZERO_SCALE") ? 0.0f : 0.016666667f;
    for (size_t i = 0; i < count; i += 4) {
        assert(words[i] == 1 && words[i+1] == i/4 && words[i+2] == i/4+2);
        union { float f; uint32_t u; } imm = {.u = words[i+3]};
        assert(imm.f == expected);
    }
    if (frame == 2 && !retries++) return -11;
    for (size_t i = 0; i < count; i += 4) {
        union { float f; uint32_t u; } imm = {.u = words[i+3]};
        state[words[i+1]] += state[words[i+2]] * imm.f;
    }
    ++completed;
    return 0;
}
static int32_t close_island(uint64_t handle) {
    assert(handle == 7 && completed == 120); ++closes; return 0;
}
static uint32_t get32(size_t p) { uint32_t n; memcpy(&n, request+p, 4); return n; }
static uint64_t get64(size_t p) { uint64_t n; memcpy(&n, request+p, 8); return n; }
int32_t trueos_cabi_async_fs_write_begin(const void *path, size_t len, size_t size) {
    assert(!live && len == 19 && !memcmp(path, "vFile:compute-boids", len));
    assert(size >= 32 && size <= sizeof request);
    live = 1; ready = committed = 0; request_size = size; request_written = 0; return 9;
}
int32_t trueos_cabi_async_fs_write_chunk(uint32_t id, size_t offset, const void *p, size_t n) {
    assert(live && id == 9 && !committed && offset == request_written && offset+n <= request_size);
    memcpy(request+offset, p, n); request_written += n; return 0;
}
int32_t trueos_cabi_async_fs_write_commit(uint32_t id) {
    assert(live && id == 9 && !committed && request_written == request_size);
    assert(!memcmp(request, "OBC1", 4) && !get32(28));
    committed = 1;
    uint32_t op = get32(4), count = get32(24);
    uint64_t handle = get64(8), frame = get64(16);
    assert(request_size == 32+count*4);
    int32_t rc = 0;
    if (op == 1) { assert(!handle && !frame && !count); ++create_calls; if (create_calls <= 2) rc = create_calls == 1 ? -16 : -11; else handle = create(); }
    else if (op == 2) { rc = program(handle, frame, (const uint32_t *)(request+32), count); }
    else if (op == 4) { assert(!frame && !count); rc = close_island(handle); }
    else assert(0);
    memcpy(reply, "OBR1", 4); memcpy(reply+4, &rc, 4); memcpy(reply+8, &handle, 8); memcpy(reply+16, &completed, 8);
    return 0;
}
int32_t trueos_cabi_async_fs_status(uint32_t id) { assert(live && id == 9 && committed); return ready ? 1 : 0; }
void trueos_cabi_poll_once(void) { if (live && committed) ready = 1; ++yields; }
intptr_t trueos_cabi_async_fs_result_len(uint32_t id) { assert(live && ready && id == 9); return 24; }
intptr_t trueos_cabi_async_fs_result_read(uint32_t id, size_t offset, void *p, size_t cap) {
    assert(live && ready && id == 9 && offset < 24); size_t n = 24-offset; if (n > cap) n=cap; if(n>5)n=5;
    memcpy(p, reply+offset, n); return n;
}
int32_t trueos_cabi_async_fs_discard(uint32_t id) { assert(live && id == 9); live = 0; ++discarded; return 0; }
size_t trueos_cabi_shell_attached_write(const void *p, size_t n) {
    if (n > 11) n = 11;
    return fwrite(p, 1, n, stdout);
}
int32_t trueos_cabi_shell_attached_read_byte(void) { return -1; }
void trueos_cabi_sleep_ms(uint64_t ms) { assert(ms == 2 || ms == 4 || ms == 16); }
int32_t trueos_cabi_blueprint_stop_control_v1(uint32_t op) { assert(op <= 1); return 0; }
int32_t trueos_cabi_blueprint_shutdown(const void *p, size_t n) { assert(p && n && closes == 1); return 0; }
int main(void) {
    char *args[] = {"gpu-boids", "--batch", 0};
    assert(boids_entry(2, args) == 0);
    assert(completed == 120 && retries && closes == 1 && !live && yields == discarded+2 && discarded == 125 && create_calls == 3);
    if (getenv("ZERO_SCALE")) assert(state[0] == 1 && state[1] == 2);
    else assert(fabsf(state[0] - 7) < 0.001f && fabsf(state[1] - 10) < 0.001f);
    printf("HOST BYTECODE FACTCHECK x=%.3f y=%.3f frames=%llu\n", state[0], state[1], (unsigned long long)completed);
    return 0;
}
'''


def run(args, expected=0, **kwargs):
    result = subprocess.run([str(a) for a in args], capture_output=True, timeout=12, **kwargs)
    if result.returncode != expected:
        raise AssertionError((args, result.returncode, result.stdout, result.stderr))
    return result


def main():
    with tempfile.TemporaryDirectory() as directory:
        work = Path(directory)
        compiler = work / 'compiler'
        run(['gcc', '-std=c11', NATIVE / 'test_host.c', NATIVE / 'build/odin-son.o', '-lm', '-o', compiler])
        run([compiler, '--gpu-boids'], cwd=work, env=dict(os.environ, TRUEOS_TEST_NO_SOURCE_IO='1', TRUEOS_TEST_LINE_WRITES='1'))
        obj = work / 'gpu-boids.o'
        bp = (work / 'gpu-boids.bp').read_bytes()
        assert struct.unpack('<4sHHQII', bp[:24]) == (b'TRBP', 1, 0x601, 0, obj.stat().st_size, obj.stat().st_size)
        assert bp[24:] == obj.read_bytes()
        launched = run([compiler, '--run-gpu-boids'], cwd=work, env=dict(os.environ, TRUEOS_TEST_NO_SOURCE_IO='1'))
        assert b'stage=launch-queued artifact=./gpu-boids.bp destination=headless' in launched.stdout
        imports = run(['nm', '-u', obj]).stdout
        assert b'trueos_cabi_async_fs_write_begin' in imports
        assert b'trueos_cabi_compute_' not in imports
        harness = work / 'harness.c'
        harness.write_text(HARNESS)

        def execute(source, zero=False):
            if source is not None:
                fixture = work / 'source.odin'
                fixture.write_text(source + '\n' + (ROOT / 'examples/gpu-boids-trueos/phy.odin').read_text().removeprefix('package main\n'))
                run([compiler, '--cpu-boids', fixture, '-o', obj], cwd=work)
            run(['objcopy', '--redefine-sym', 'main=boids_entry', obj, work / 'host.o'])
            run(['gcc', work / 'host.o', harness, '-lm', '-o', work / 'boids'])
            result = run([work / 'boids'], env=dict(os.environ, **({'ZERO_SCALE': '1'} if zero else {})))
            assert b'PASS first GPU frame published' in result.stdout
            assert b'PASS lifecycle complete' in result.stdout
            return result.stdout

        moving = execute(None)
        source = (ROOT / 'examples/gpu-boids-trueos/main.odin').read_text()
        still = execute(source.replace('0.016666667', '0.0'), zero=True)
        assert b'x=7.000 y=10.000' in moving and b'x=1.000 y=2.000' in still

        failures = {
            'gpu_add_scaled(4, 2, 1.0)': 'register indices',
            'gpu_multiply(0, 2, 1.0)': 'supports only',
            'value := 1': 'supports gpu_add_scaled',
        }
        for statement, diagnostic in failures.items():
            case_dir = work / ('bad-' + str(len(statement)))
            case_dir.mkdir(exist_ok=True)
            fixture = case_dir / 'main.odin'
            fixture.write_text(source.replace('gpu_add_scaled(0, 2, 0.016666667)', statement) + '\n' + (ROOT / 'examples/gpu-boids-trueos/phy.odin').read_text().removeprefix('package main\n'))
            result = run([compiler, '--cpu-boids', fixture, '-o', work / 'bad.o'], expected=1, cwd=work)
            assert diagnostic.encode() in result.stderr
        (work / 'too-many').mkdir()
        fixture = work / 'too-many/main.odin'
        fixture.write_text(source.replace('gpu_add_scaled(0, 2, 0.016666667)', '\n'.join(['gpu_add_scaled(0, 2, 1.0)'] * 17)) + '\n' + (ROOT / 'examples/gpu-boids-trueos/phy.odin').read_text().removeprefix('package main\n'))
        assert b'at most 16' in run([compiler, '--cpu-boids', fixture, '-o', work / 'bad.o'], expected=1, cwd=work).stderr
    print('PASS: native compiler embeds tagged source, lowers source-dependent GPU arithmetic bytecode, emits local sysapi adapter with no custom imports; host mocks prove coefficient mutation, busy retry, yielding async-fs writes, partial replies, operation cleanup, 120-frame lifecycle and invalid-body rejection. Real GPU/UI4 require TRUEOS deployment.')


if __name__ == '__main__':
    main()
