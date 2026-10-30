#!/usr/bin/env python3
"""Check upload identity, inputs, result reporting and error handling with ABI mocks."""
import json
import argparse
from pathlib import Path
import subprocess
import tempfile

NATIVE = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--object', type=Path, default=NATIVE / 'build/odin-son-gpu.o')
    args = parser.parse_args()
    tests = json.loads((NATIVE / 'gpu-demo/assets/manifest.json').read_text())['tests']
    harness = r'''
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
int32_t trueos_main(size_t argc, char **argv);
void *trueos_cabi_alloc(size_t n) {return malloc(n);}
void *trueos_cabi_calloc(size_t n,size_t s) {return calloc(n,s);}
void *trueos_cabi_realloc(void *p,size_t n) {return realloc(p,n);}
void trueos_cabi_free(void *p) {free(p);}
void trueos_cabi_write(uint32_t s,const void *p,size_t n) {fwrite(p,1,n,s==2?stderr:stdout);}
int32_t trueos_cabi_blueprint_stop_control_v1(uint32_t op) {return 0;}
int32_t trueos_cabi_blueprint_shutdown(const void *p,size_t n) {return 0;}
static unsigned uploads,dispatches,closed;
uint32_t trueos_cabi_ui4_scene_frame_open_visual(int32_t x,int32_t y,uint32_t w,uint32_t h,uint32_t hz) {
    assert(w==32 && h==32 && hz==1);return 7;
}
int32_t trueos_cabi_ui4_solara_frame_close(uint32_t w) {assert(w==7);++closed;return 0;}
// FIXTURES
int32_t trueos_cabi_ui4_scene_native_compute_upload_v1(uint32_t w,uint32_t offset,uint32_t total,const void *p,size_t n) {
    assert(w==7 && offset==0 && total==sizes[uploads] && n==total);
    assert(!memcmp(p,codes[uploads],n));++uploads;return 0;
}
int32_t trueos_cabi_ui4_scene_native_compute_dispatch_v1(uint32_t w,const uint32_t *input,uint32_t registers,uint32_t *out) {
    assert(w==7 && registers==2 && uploads==dispatches+1);
    assert(!memcmp(input,inputs[dispatches],64));
    unsigned index=dispatches++;
    if(getenv("TIMEOUT")) return -32;
    memcpy(out,expected[index],32);
    if(getenv("MISMATCH") && index==2) out[0]^=0x40000000;
    return 0;
}
int main(int argc,char **argv) {
    int rc=trueos_main(argc,argv);
    assert(closed==1);
    assert(dispatches==(getenv("TIMEOUT")?1:5));
    return rc;
}
'''
    fixtures = ''
    for i, test in enumerate(tests):
        code = (NATIVE / ('gpu-demo/assets/' + test['name'] + '.eu')).read_bytes()
        fixtures += f'static const unsigned char code{i}[]={{' + ','.join(map(str, code)) + '};\n'
    fixtures += 'static const unsigned char *codes[]={code0,code1,code2,code3,code4};\n'
    fixtures += 'static const size_t sizes[]={' + ','.join(str(t['bytes']) for t in tests) + '};\n'
    fixtures += 'static const uint32_t inputs[5][2][8]={' + ','.join(
        '{' + ','.join('{' + ','.join(map(str, row)) + '}' for row in t['input_bits']) + '}' for t in tests) + '};\n'
    fixtures += 'static const uint32_t expected[5][8]={' + ','.join(
        '{' + ','.join(map(str, t['expected_bits'])) + '}' for t in tests) + '};\n'
    import os
    with tempfile.TemporaryDirectory() as directory:
        work = Path(directory)
        (work / 'host.c').write_text(harness.replace('// FIXTURES', fixtures))
        subprocess.run(['objcopy', '--redefine-sym', 'main=trueos_main', str(args.object), str(work / 'runner.o')], check=True, timeout=20)
        subprocess.run(['gcc', '-std=c11', str(work / 'host.c'), str(work / 'runner.o'),
                        '-lm', '-o', str(work / 'demo')], check=True, timeout=20)
        for flag, expected_status, message in (
            ('', 0, 'passed=5 failed=0 skipped=0'),
            ('MISMATCH', 1, 'passed=4 failed=1 skipped=0'),
            ('TIMEOUT', 1, 'passed=0 failed=1 skipped=4'),
        ):
            env = dict(os.environ)
            if flag:
                env[flag] = '1'
            result = subprocess.run([str(work / 'demo'), '--gpu-tests'], env=env,
                                    capture_output=True, text=True, timeout=20)
            assert result.returncode == expected_status, (result.stdout, result.stderr)
            assert message in result.stdout, result.stdout
    print('PASS: exact kernel uploads, SIMD8 inputs, lane/checksum reporting, mismatch detection and stop after device failure (host mocks, no GPU execution)')


if __name__ == '__main__':
    main()
