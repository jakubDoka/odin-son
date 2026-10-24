#!/usr/bin/env python3
"""Compile source loops to native SIMD8 math and compare all lanes to a C oracle."""
from pathlib import Path
import os
import struct
import subprocess
import tempfile

from test_gpu_scalar import ROOT, run


SOURCE = '''package main
main :: proc() -> int { return int(process(0.0, 0.0)) }
@(tag = "gpu")
process :: proc(cx, cy: f32) -> f32 {
    zx := 0.0
    zy := 0.0
    depth := 0.0
    active := true
    for i := 0; i < ITERATIONS; i += 1 {
        xx := zx * zx
        yy := zy * zy
        nx := xx - yy + cx
        ny := 2.0 * zx * zy + cy
        zx = active ? nx : zx
        zy = active ? ny : zy
        depth = active ? depth + 1.0 : depth
        active = active ? ((zx * zx + zy * zy) <= 4.0) : false
    }
    return depth * 0.04
}
'''


HARNESS = r'''
#include <assert.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
static uint32_t bits(float f) { uint32_t u; memcpy(&u,&f,4); return u; }
static float value(uint32_t u) { float f; memcpy(&f,&u,4); return f; }
static void execute(const uint32_t *code, size_t words, const float *cx, const float *cy, float *out) {
    uint32_t r[128][8] = {{0}};
    for (unsigned lane=0; lane<8; ++lane) {r[1][lane]=bits(cx[lane]); r[2][lane]=bits(cy[lane]);}
    for (size_t at=0; at<words; at+=4) {
        const uint32_t *w=code+at;
        unsigned op=w[0]&127, dst=w[1]>>24;
        for (unsigned lane=0; lane<8; ++lane) {
            uint32_t x=r[(w[2]>>8)&255][lane], y=0;
            if (op!=0x61) y=(w[1]&0x8000)?w[3]:r[(w[3]>>8)&255][lane];
            switch (op) {
            case 0x61: r[dst][lane]=(w[1]&0x4000)?w[3]:x; break;
            case 0x40: r[dst][lane]=((w[1]>>4)&15)==10?bits(value(x)+value(y)):x+y; break;
            case 0x41: r[dst][lane]=((w[1]>>4)&15)==10?bits(value(x)*value(y)):x*y; break;
            case 0x65: r[dst][lane]=x&y; break;
            case 0x66: r[dst][lane]=x|y; break;
            case 0x67: r[dst][lane]=x^y; break;
            case 0x68: r[dst][lane]=x>>(y&31); break;
            case 0x69: r[dst][lane]=x<<(y&31); break;
            case 0x70: {
                unsigned c=(w[2]>>28)&15;
                int result;
                if (((w[1]>>8)&15)==10) {
                    float a=value(x), b=value(y);
                    result=c==1?a==b:c==2?a!=b:c==3?a>b:c==4?a>=b:c==5?a<b:a<=b;
                } else { result=c==1?x==y:c==2?x!=y:c==3?x>y:c==4?x>=y:c==5?x<y:x<=y; }
                r[dst][lane]=result?UINT32_MAX:0;
                break;
            }
            default: abort();
            }
        }
    }
    for (unsigned lane=0; lane<8; ++lane) out[lane]=value(r[4][lane]);
}
static float reference(float cx, float cy, unsigned iterations) {
    float zx=0, zy=0, depth=0;
    for (unsigned i=0; i<iterations; ++i) {
        float nx=zx*zx-zy*zy+cx, ny=2.0f*zx*zy+cy;
        zx=nx; zy=ny; depth+=1.0f;
        if (!(zx*zx+zy*zy<=4.0f)) break;
    }
    return depth*0.04f;
}
int main(int argc, char **argv) {
    assert(argc==3);
    FILE *f=fopen(argv[1],"rb"); assert(f);
    uint32_t code[6144]; size_t words=fread(code,4,6144,f); assert(feof(f)); fclose(f);
    unsigned iterations=(unsigned)atoi(argv[2]);
    for (int row=0; row<33; ++row) for (int block=0; block<9; ++block) {
        float cx[8],cy[8],actual[8];
        for (int lane=0; lane<8; ++lane) {cx[lane]=-2.5f+(block*8+lane)*(3.5f/71); cy[lane]=-1.25f+row*(2.5f/32);}
        execute(code,words,cx,cy,actual);
        for (int lane=0; lane<8; ++lane) {
            float expected=reference(cx[lane],cy[lane],iterations);
            if (bits(actual[lane])!=bits(expected)) {
                fprintf(stderr,"at (%g,%g) actual=%g expected=%g\n",cx[lane],cy[lane],actual[lane],expected);
                abort();
            }
        }
    }
    puts("PASS 2376 source-dependent Mandelbrot pixels in all eight SIMD lanes");
}
'''


def validate_body(code):
    assert code and len(code) % 16 == 0 and len(code) <= 24576
    initialized = {1, 2}
    for w in struct.iter_unpack('<4I', code):
        op, dst = w[0] & 127, w[1] >> 24
        assert op in {0x61, 0x40, 0x41, 0x65, 0x66, 0x67, 0x68, 0x69, 0x70}
        assert 4 <= dst < 112 and w[0] & 0xFFFF0000 == 0x00030000
        if op != 0x61 or not (w[1] & 0x4000):
            assert (w[2] >> 8) & 255 in initialized
        if op != 0x61 and not (w[1] & 0x8000):
            assert (w[3] >> 8) & 255 in initialized
        initialized.add(dst)
    assert 4 in initialized


def main():
    odin = os.environ.get('ODIN', '/home/t4ce/Programmme/odin/odin')
    with tempfile.TemporaryDirectory(prefix='odin-mandelbrot-') as directory:
        work = Path(directory)
        compiler = os.environ.get('ODIN_SON_DESKTOP')
        if not compiler:
            compiler = work/'compiler'
            run([odin, 'build', ROOT / 'odinc', '-out:'+str(compiler)])
        sdk = run([odin, 'root']).stdout.decode().strip()
        env = dict(os.environ, ODIN_ROOT=sdk)
        native_object = ROOT/'trueos/build/odin-son.o'
        native = work/'native-compiler'
        if native_object.exists():
            run([os.environ.get('CC', 'clang'), '-std=c11', ROOT/'trueos/test_host.c', native_object, '-lm', '-o', native])
        harness = work/'oracle.c'
        harness.write_text(HARNESS)
        run([os.environ.get('CC', 'clang'), '-std=c11', '-O2', '-ffp-contract=off', harness, '-lm', '-o', work/'oracle'])
        bodies = []
        for iterations in (8, 25):
            case = work/f'case{iterations}'
            case.mkdir()
            source = case/'main.odin'
            source.write_text(SOURCE.replace('ITERATIONS', str(iterations)))
            body = case/'body.bin'
            run([compiler, source, '-o', case/'program.o', '-emit-xelp-body', body], env=env)
            code = body.read_bytes()
            validate_body(code)
            if native.exists():
                run([native, '--cpu-boids', source, '-o', case/'native.o', '-emit-xelp-body', case/'native-body.bin'], env=env)
                assert (case/'native-body.bin').read_bytes() == code
            bodies.append(code)
            assembly = case/'body.asm'
            run(['iga64', '-p=12p1', '-d', body, '-o', assembly])
            run(['iga64', '-p=12p1', '-a', '-Xforce-no-compact', assembly, '-o', case/'roundtrip.bin'])
            assert (case/'roundtrip.bin').read_bytes() == code
            run([work/'oracle', body, str(iterations)])
        assert bodies[0] != bodies[1] and len(bodies[1]) > len(bodies[0])
        bad = work/'bad'
        bad.mkdir()
        for body in ('for {}', 'for i := 0; i < 0; i += 1 { unknown() }',
                     'for i := 0; i < 65; i += 1 {}', 'for i := 0; i < 2; i += 1 { i = 1 }',
                     'x := true; x = 1.0', 'return unknown', 'return true'):
            source = bad/'main.odin'
            source.write_text('package main\n@(tag="gpu")\nprocess :: proc(a,b:f32)->f32 {\n'+body+'\nreturn a\n}\n')
            result = subprocess.run([str(compiler), str(source), '-o', str(bad/'program.o')], capture_output=True, timeout=12, env=env)
            assert result.returncode == 1, (body, result.stderr)
        print('PASS bounded native GPU loops, locals, comparisons, selects, source dependence, SIMD8 oracle and IGA roundtrips. No hardware dispatch tested.')


if __name__ == '__main__':
    main()
