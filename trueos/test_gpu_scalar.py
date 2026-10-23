#!/usr/bin/env python3
"""Check native scalar kernels, CPU stubs, ELF placement and TRUEOS admission; no GPU dispatch."""
from pathlib import Path
import os
import re
import signal
import struct
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
TRUEOS = ROOT.parent / 'TRUEOS'


def run(args, **kwargs):
    result = subprocess.run([str(a) for a in args], capture_output=True, timeout=12, **kwargs)
    assert result.returncode == 0, (args, result.returncode, result.stdout.decode(), result.stderr.decode())
    return result


def sections(path):
    data = path.read_bytes()
    start = struct.unpack_from('<Q', data, 40)[0]
    count, names_index = struct.unpack_from('<HH', data, 60)
    headers = [struct.unpack_from('<IIQQQQIIQQ', data, start + i*64) for i in range(count)]
    names = headers[names_index]
    names = data[names[4]:names[4]+names[5]]
    return {names[h[0]:].split(b'\0')[0].decode(): (h, data[h[4]:h[4]+h[5]]) for h in headers}


HARNESS = r'''
#include <assert.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
extern float process(float, float);
extern long odin_entry(void);
static uint32_t bits(float f) { uint32_t u; memcpy(&u,&f,4); return u; }
static float value(uint32_t u) { float f; memcpy(&f,&u,4); return f; }
static uint32_t random_bits(void) {
    static uint32_t x=0x913746a5; x^=x<<13; x^=x>>17; x^=x<<5; return x;
}
int32_t trueos_cabi_vgpu_call_f32_v1(const uint8_t *code, size_t size, float a, float b, float *out) {
    if (getenv("FAIL_DISPATCH")) return -5;
    assert(size>=176 && size<=24576 && !(size%16));
    uint32_t r[128]={0}; r[1]=bits(a); r[2]=bits(b);
    for (size_t at=0; at<size; at+=16) {
        uint32_t w[4]; memcpy(w,code+at,16);
        unsigned op=w[0]&127, dst=w[1]>>24;
        if (!at) { assert(w[0]==0x80000166); continue; }
        if (op==0x31) { *out=value(r[4]); return 0; }
        if (op==1) continue;
        unsigned src0=(w[2]>>8)&255;
        assert(src0<128 && dst<128);
        uint32_t x=r[src0];
        if (op==0x61) { r[dst]=(w[1]&0x4000)?w[3]:x; continue; }
        unsigned src1=(w[3]>>8)&255;
        assert((w[1]&0x8000)||src1<128);
        uint32_t y=(w[1]&0x8000)?w[3]:r[src1];
        switch (op) {
        case 0x40: r[dst]=((w[1]>>4)&15)==10?bits(value(x)+value(y)):x+y; break;
        case 0x41: r[dst]=((w[1]>>4)&15)==10?bits(value(x)*value(y)):x*y; break;
        case 0x65: r[dst]=x&y; break;
        case 0x66: r[dst]=x|y; break;
        case 0x67: r[dst]=x^y; break;
        case 0x68: r[dst]=x>>(y&31); break;
        case 0x69: r[dst]=x<<(y&31); break;
        default: assert(0);
        }
    }
    assert(0); return -1;
}
static void check(uint32_t x, uint32_t y) {
    float a=value(x), b=value(y), actual=process(a,b), expected=EXPRESSION;
    if (bits(actual)!=bits(expected) && !(isnan(actual)&&isnan(expected))) {
        fprintf(stderr,"%08x %08x: actual=%08x expected=%08x\n",x,y,bits(actual),bits(expected));
        abort();
    }
}
int main(void) {
    const uint32_t edge[]={0,0x80000000,1,0x80000001,0x007fffff,0x00800000,0x7f7fffff,
        0xff7fffff,0x7f800000,0xff800000,0x7fc00000,0x7f800001,0x3f800000,
        0x3f000000,0x3f800001,0x41200000,0x42c80000};
    for (size_t i=0;i<sizeof(edge)/4;i++) for(size_t j=0;j<sizeof(edge)/4;j++) check(edge[i],edge[j]);
    for (unsigned i=0;i<100000;i++) check(random_bits(),random_bits());
    assert(odin_entry()==EXPECTED_MAIN);
    puts("PASS CPU marshaling and 100289 native instruction evaluations");
}
'''


def main():
    odin = os.environ.get('ODIN', 'odin')
    # The GCC-built oracle also failed intermittently with a pure C wrapper on
    # this host. Use an independent Clang build; CC permits reproducing either.
    cc = os.environ.get('CC', 'clang')
    with tempfile.TemporaryDirectory(prefix='odin-native-scalar-') as directory:
        work = Path(directory)
        compiler = work/'compiler'
        run([odin, 'build', ROOT, '-out:'+str(compiler)])
        unchecked_compiler = work/'unchecked-compiler'
        run([odin, 'build', ROOT, '-disable-assert', '-out:'+str(unchecked_compiler)])
        sdk = run([odin, 'root']).stdout.decode().strip()
        env = dict(os.environ, ODIN_ROOT=sdk)
        native = work/'native-compiler'
        native_object = ROOT/'trueos/build/odin-son.o'
        if native_object.exists():
            run([cc, '-std=c11', ROOT/'trueos/test_host.c', native_object, '-lm', '-o', native])
        validator = work/'validate.rs'
        validator.write_text(f'#[path="{TRUEOS}/src/gpu/native_xelp.rs"] mod native;\n'
                             'fn main(){ assert!(native::validate(&std::fs::read(std::env::args().nth(1).unwrap()).unwrap())); }\n')
        run(['rustc', '--edition=2024', validator, '-o', work/'validate'])
        for index, (expression, expected_main) in enumerate([
            ('a + b * b / a', 1010), ('a / b', 0), ('a + b', 110),
            ('a * b', 1000), ('a / (b / a)', 1), ('a + 2.5 * b', 260),
        ]):
            case = work/f'case{index}'
            case.mkdir()
            source = case/'main.odin'
            source.write_text('package main\nmain :: proc() -> int { return int(process(10, 100)) }\n'
                              '@(tag="gpu")\nprocess :: proc(a, b: f32) -> f32 { return '+expression+' }\n')
            obj = case/'program.o'
            run([compiler, source, '-o', obj, '-o:all'], env=env)
            header, code = sections(obj)['.gpu.xelp']
            assert header[2] == 2 and header[8] == 64
            if index == 0 and native.exists():
                run([native, '--cpu-boids', source, '-o', case/'native.o', '-o:all'], env=env)
                assert sections(case/'native.o')['.gpu.xelp'][1] == code
            if index == 0:
                run([unchecked_compiler, source, '-o', case/'unchecked.o', '-o:all'], env=env)
                unchecked_code = case/'unchecked.bin'
                unchecked_code.write_bytes(sections(case/'unchecked.o')['.gpu.xelp'][1])
                run([work/'validate', unchecked_code])
            binary = case/'kernel.bin'; binary.write_bytes(code)
            run([work/'validate', binary])
            disassembly = run(['iga64', '-p=12p1', '-d', binary]).stdout
            assembly = case/'kernel.asm'; assembly.write_bytes(disassembly)
            run(['iga64', '-p=12p1', '-a', '-Xforce-no-compact', assembly, '-o', case/'roundtrip.bin'])
            assert (case/'roundtrip.bin').read_bytes() == code
            run(['objcopy', '--redefine-sym', 'main=odin_entry', '--globalize-symbol=process', obj])
            harness = case/'harness.c'
            c_expression = re.sub(r'(\d+\.\d+)', r'\1f', expression)
            harness.write_text('#define EXPRESSION ('+c_expression+')\n#define EXPECTED_MAIN '+str(expected_main)+'\n'+HARNESS)
            executable = case/'test'
            run([cc, '-std=c11', '-O2', '-ffp-contract=off', harness, obj, '-lm', '-o', executable])
            run([executable])
            if index == 0:
                run(['objcopy', '--redefine-sym', 'main=odin_entry', '--globalize-symbol=process', case/'unchecked.o'])
                run([cc, '-std=c11', '-O2', '-ffp-contract=off', harness, case/'unchecked.o', '-lm', '-o', case/'unchecked-test'])
                run([case/'unchecked-test'])
            failed = subprocess.run([str(executable)], capture_output=True, timeout=12,
                                    env=dict(os.environ, FAIL_DISPATCH='1'))
            assert failed.returncode in [-signal.SIGILL, -signal.SIGTRAP], failed.returncode
        bad = work/'bad'; bad.mkdir()
        for body in ['return a % b', 'return unknown(a)', 'x := true; return x', 'return a / b / a / b']:
            (bad/'main.odin').write_text('package main\n@(tag="gpu")\nprocess :: proc(a,b:f32)->f32{'+body+'}\n')
            result = subprocess.run([str(compiler), str(bad/'main.odin'), '-o', str(bad/'bad.o')],
                                    capture_output=True, timeout=12, env=env)
            assert result.returncode == 1, (body, result.returncode, result.stderr)
            assert not (bad/'bad.o').exists()
    print('PASS 6 native scalar kernels plus assertions-disabled emission, 702023 arithmetic cases, IGA roundtrips, admission, CPU ABI, failure traps and diagnostics. No hardware dispatch tested.')


if __name__ == '__main__':
    main()
