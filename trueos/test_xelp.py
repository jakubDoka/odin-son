#!/usr/bin/env python3
"""Compare odin-son's native Xe-LP encoder with IGA; never dispatch a GPU."""
from pathlib import Path
import argparse
import os
import shutil
import struct
import subprocess
import tempfile


def run(args, **kwargs):
    return subprocess.run([str(x) for x in args], check=True, timeout=12, **kwargs)


def cases():
    result = []
    def add(assembly, expr):
        result.append((assembly, expr))
    for op in ['And', 'Or', 'Xor', 'Shl', 'Shr']:
        for dst, src0, src1 in [(4, 1, 2), (111, 110, 109), (127, 126, 125)]:
            for immediate in [False, True]:
                source = '0xffffffff:ud' if immediate else f'r{src1}.0<8;8,1>:ud'
                expression = 'eu.imm(0xffffffff)' if immediate else f'eu.reg({src1})'
                add(f'{op.lower()} (8|M0) r{dst}.0<1>:ud r{src0}.0<8;8,1>:ud {source} {{@1}}',
                    f'eu.encode_alu({{op=.{op}, type=.U32, dst={dst}, src0=eu.reg({src0}), src1={expression}, distance=1}})')
    for op in ['Mov', 'Add', 'Mul', 'Cmp', 'Sel']:
        for dtype, suffix in [('F32', 'f'), ('U32', 'ud')]:
            for dst, src0, src1 in [(0, 1, 2), (10, 11, 12), (127, 126, 125)]:
                for broadcast in [False, True]:
                    for immediate in [False, True]:
                        for distance in [0, 1, 7]:
                            region = '0;1,0' if broadcast else '8;8,1'
                            s0 = f'r{src0}.0<{region}>:{suffix}'
                            e0 = f'eu.reg({src0}, {str(broadcast).lower()})'
                            literal = '1.5:f' if dtype == 'F32' else '4294967295:ud'
                            bits = 0x3fc00000 if dtype == 'F32' else 0xffffffff
                            s1 = literal if immediate else f'r{src1}.0<{region}>:{suffix}'
                            e1 = f'eu.imm(0x{bits:x})' if immediate else f'eu.reg({src1}, {str(broadcast).lower()})'
                            if op == 'Mov' and immediate:
                                s0, e0 = literal, f'eu.imm(0x{bits:x})'
                            pred = '(f0.0) ' if op == 'Sel' else ''
                            cond = '(lt)f0.0 ' if op == 'Cmp' else ''
                            asm = f'{pred}{op.lower()} (8|M0) {cond}r{dst}.0<1>:{suffix} {s0}'
                            expr = f'op=.{op}, type=.{dtype}, dst={dst}, src0={e0}, distance={distance}'
                            if op != 'Mov':
                                asm += f' {s1}'
                                expr += f', src1={e1}'
                            if op == 'Cmp': expr += ', condition=.Lt'
                            if op == 'Sel': expr += ', predicate=.F0'
                            if distance: asm += f' {{@{distance}}}'
                            add(asm, f'eu.encode_alu({{{expr}}})')
    for condition in ['Eq', 'Ne', 'Gt', 'Ge', 'Lt', 'Le']:
        for literal in [0, 0x80000000, 0x7fc00000, 0xffffffff]:
            add(f'cmp (8|M0) ({condition.lower()})f0.0 null<1>:ud r0.0<8;8,1>:ud 0x{literal:x}:ud',
                f'eu.encode_alu({{op=.Cmp, type=.U32, dst=eu.NULL, src0=eu.reg(0), src1=eu.imm(0x{literal:x}), condition=.{condition}}})')
    for op in ['Mov', 'Add', 'Mul', 'Cmp', 'Sel']:
        for pred, prefix in [('F0', '(f0.0)'), ('Not_F0', '(~f0.0)')]:
            condition = '(eq)f0.0 ' if op == 'Cmp' else ''
            src1 = ' r3.0<8;8,1>:f' if op != 'Mov' else ''
            expr1 = ', src1=eu.reg(3)' if op != 'Mov' else ''
            cond = ', condition=.Eq' if op == 'Cmp' else ''
            add(f'(W&{prefix[1:-1]}) {op.lower()} (8|M0) {condition}r1.0<1>:f r2.0<8;8,1>:f{src1}',
                f'eu.encode_alu({{op=.{op}, dst=1, src0=eu.reg(2){expr1}{cond}, predicate=.{pred}, write_enable=true}})')
    for kind, syntax in [('Source', 'src'), ('Destination', 'dst')]:
        for value in range(16):
            add(f'sync.nop (1|M0) null {{$' + f'{value}.{syntax}' + '}',
                f'eu.encode_sync({{kind=.{kind}, value={value}}})')
    for value in range(1, 8):
        add(f'sync.nop (1|M0) null {{@{value}}}', f'eu.encode_sync({{kind=.Distance, value={value}}})')
    for kind, mnemonic in [('All_Reads', 'allrd'), ('All_Writes', 'allwr')]:
        for enabled in [False, True]:
            add(f'{"(W) " if enabled else ""}sync.{mnemonic} (1|M0) null',
                f'eu.encode_sync({{kind=.{kind}, write_enable={str(enabled).lower()}}})')
    for sfid, mnemonic in [('DC0', 'dc0'), ('DC1', 'dc1'), ('Gateway', 'gtwy'), ('Sampler', 'smpl')]:
        for sbid in range(16):
            for dst, src0, src1, desc, ex in [(10, 20, -1, 0x02100000, 0), (-1, 127, -1, 0x02000000, 0), (0, 1, 126, 0x02100000, 0x80)]:
                d = 'null' if dst == -1 else f'r{dst}'
                s1 = 'null' if src1 == -1 else f'r{src1}'
                add(f'(W) send.{mnemonic} (8|M0) {d} r{src0} {s1}:ud 0x{ex:x} 0x{desc:x} {{$' + str(sbid) + '}',
                    f'eu.encode_send({{sfid=.{sfid}, dst={dst}, src0={src0}, src1={src1}, descriptor=0x{desc:x}, extended_descriptor=0x{ex:x}, sbid={sbid}, write_enable=true}})')
    for bit in range(32):
        if bit == 29: continue
        desc = 0x02100000 | (1 << bit)
        add(f'send.dc1 (8|M0) r0 r32 null:ud 0x0 0x{desc:x} {{$0}}',
            f'eu.encode_send({{sfid=.DC1, dst=0, src0=32, src1=eu.NULL, descriptor=0x{desc:x}}})')
    for bit in range(6, 32):
        ex = 0x40 | (1 << bit)
        add(f'send.dc1 (8|M0) r0 r32 r64:ud 0x{ex:x} 0x02100000 {{$0}}',
            f'eu.encode_send({{sfid=.DC1, dst=0, src0=32, src1=64, descriptor=0x02100000, extended_descriptor=0x{ex:x}}})')
    for src0 in [112, 127]:
        add(f'(W) send.ts (8|M0) null r{src0} null:ud 0x0 0x02000000 {{EOT,$15}}',
            f'eu.encode_send({{sfid=.Thread_Spawner, dst=eu.NULL, src0={src0}, src1=eu.NULL, descriptor=0x02000000, sbid=15, end_of_thread=true, write_enable=true}})')
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--package', type=Path, default=Path(__file__).resolve().parents[1] / 'bac/intel_xelp')
    parser.add_argument('--odin', default=os.environ.get('ODIN', 'odin'))
    parser.add_argument('--iga', default='iga64')
    args = parser.parse_args()
    matrix = cases()
    with tempfile.TemporaryDirectory(prefix='odin-son-xelp-') as directory:
        tmp = Path(directory)
        shutil.copytree(args.package, tmp / 'intel_xelp',
                        ignore=shutil.ignore_patterns('target.odin', 'div.odin', 'node_specs.odin', 'gen'))
        driver = tmp / 'driver'; driver.mkdir()
        source = ['package main', 'import eu "../intel_xelp"', 'import "core:fmt"', 'import "core:os"', 'main :: proc() {', f'data: [{len(matrix) * 16}]u8', 'at := 0']
        for index, (_, expr) in enumerate(matrix):
            source += ['{', f'w, err := {expr}', f'if err != .None {{ fmt.eprintln("case {index}", err); os.exit(1) }}', 'assert(eu.write_instruction(data[at:at+16], w) == .None)', 'at += 16', '}']
        source += ['assert(os.write_entire_file(os.args[1], data[:]) == nil)', '}']
        (driver / 'main.odin').write_text('\n'.join(source))
        run([args.odin, 'build', driver, '-out:' + str(tmp/'emit')])
        run([tmp/'emit', tmp/'native.bin'])
        (tmp/'oracle.asm').write_text('\n'.join(a for a, _ in matrix) + '\n')
        run([args.iga, '-p=12p1', '-a', '-Xforce-no-compact', tmp/'oracle.asm', '-o', tmp/'oracle.bin'])
        actual, expected = (tmp/'native.bin').read_bytes(), (tmp/'oracle.bin').read_bytes()
        assert len(actual) == len(expected) == 16 * len(matrix)
        for index, (assembly, _) in enumerate(matrix):
            a, e = actual[index*16:index*16+16], expected[index*16:index*16+16]
            assert a == e, f'case {index}: {assembly}\nours={struct.unpack("<4I",a)}\niga ={struct.unpack("<4I",e)}'
        run([args.odin, 'test', tmp/'intel_xelp', '-out:' + str(tmp/'unit'), '-define:ODIN_TEST_FANCY=false'])
        for test in (tmp/'intel_xelp').glob('*_test.odin'):
            test.unlink()
        run([args.odin, 'check', tmp/'intel_xelp', '-target:freestanding_amd64_sysv', '-no-entry-point'])
    print(f'PASS {len(matrix)} native encodings match IGA byte-for-byte; rejection tests and freestanding check passed')


if __name__ == '__main__':
    main()
