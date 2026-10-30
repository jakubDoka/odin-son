#!/usr/bin/env python3
"""Compile the upstream GPU corpus ahead of time, without opening a GPU device."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_TESTS = (
    "gpu_simplest",
    "gpu_float_less",
    "gpu_if_else",
    "gpu_loop_continue",
    "gpu_nested_loops",
)

EXPORTER = r'''
package main

import "../bac"
import "../bac/intel_xelp_poc"
import "../odinc"
import "../odinc/typecheck"
import "../utils/arna"
import "base:runtime"
import "core:encoding/json"
import "core:fmt"
import "core:hash"
import "core:math/rand"
import "core:mem"
import "core:odin/ast"
import "core:odin/parser"
import "core:os"
import "core:strings"

Record :: struct {
    name, kernel, result_type: string,
    max_float_ulps: int,
    input_bits: [][8]u32,
    expected_bits: [8]u32,
}

compile :: proc(name, source, result_type: string, count, max_ulps: int,
                reference: proc(args: [][8]f32) -> [8]u32) -> Record {
    types: typecheck.Types
    arna.scratch[0].reserved = 1024*1024
    arna.scratch[1].reserved = 1024*1024
    for &arena in mem.slice_data_cast([]arna.Allocator, mem.ptr_to_bytes(&types.mems)) do arena.reserved = 1024*1024
    types.mems.type.reserved = 16*1024*1024
    typecheck.types_init(&types)
    defer typecheck.types_deinit(&types)
    global: typecheck.Global_Ctx
    errors: strings.Builder
    ctx: odinc.Gen_Ctx
    stats: bac.Stats
    ctx.stats = &stats
    ctx.types = &types
    ctx.global = &global
    ctx.errors = strings.to_writer(&errors)
    bac.current_prc = &ctx
    defer bac.current_prc = nil

    file := ast.File{src=source, fullpath=name}
    p: parser.Parser
    {
        context.allocator = types.allocator
        if !parser.parse_file(&p, &file) do panic("GPU source parse failed")
    }
    ctx.files.allocator = types.allocator
    ctx.modules.allocator = types.allocator
    append(&ctx.files, file)
    append(&ctx.modules, typecheck.Module{name=file.pkg_name, file_count=1})
    ctx.modules[0].imports.allocator = types.allocator
    ctx.modules[0].imports["intrinsics"] = typecheck.MODULE_INTRINSICS
    decls := make([dynamic]typecheck.Decl, context.temp_allocator)
    typecheck.collect_decls(file, &decls, 0)
    typecheck.module_add_decls(&ctx, 0, decls[:])
    typecheck.typecheck_program(&ctx)
    if ctx.error_cnt != 0 { fmt.eprintln(strings.to_string(errors)); os.exit(1) }

    ctx.target = {name="intel_xelp", cc=&intel_xelp_poc.CC_TABLE[intel_xelp_poc.XELP_CC], spec=&intel_xelp_poc.SPEC}
    emit: bac.Codegen_Emit_Ctx
    odinc.emit_proc(&ctx, 1, odinc.OPT_LEVELS[len(odinc.OPT_LEVELS)-2], &emit)
    code := ctx.procs[1].out.code
    if len(code) == 0 || len(code)%16 != 0 do panic("invalid Xe-LP kernel size")
    filename := strings.concatenate({name, ".bin"})
    if os.write_entire_file(filename, code) != nil do panic("cannot write GPU kernel")

    rng: rand.PCG_Random_State
    context.random_generator = rand.pcg_random_generator(&rng)
    runtime.random_generator_reset_u64(context.random_generator, hash.fnv64a(transmute([]u8)name))
    args := make([][8]f32, count)
    for &slot in mem.slice_data_cast([]f32, args) do slot = rand.float32()*2-1
    if count != 0 do args[0][1] = -0.0
    if count > 1 {
        args[1][0] = args[0][0]
        args[1][1] = 0
        args[1][2] = args[0][2]
    }
    record := Record{name=name, kernel=filename, result_type=result_type, max_float_ulps=max_ulps,
                     input_bits=mem.slice_data_cast([][8]u32, args), expected_bits=reference(args)}
    fmt.eprintfln("%s: %d bytes", name, len(code))
    return record
}

main :: proc() {
    bac.init_custom_fmt()
    typecheck.init_type_fmt()
    records: [dynamic]Record
    // GENERATED_CALLS
    bytes, err := json.marshal(records[:])
    if err != nil || os.write_entire_file("records.json", bytes) != nil do panic("cannot write GPU metadata")
}
'''


def corpus():
    markdown = (ROOT / "tests/GPU-TESTS.md").read_text()
    generated = (ROOT / "tests/tests.odin").read_text()
    blocks = re.findall(r"^#### ([^\n]+)\n```odin\n(.*?)^```", markdown, re.M | re.S)
    if not blocks:
        raise ValueError("GPU corpus is empty")
    tests = []
    for title, source in blocks:
        name = title.strip().replace(" ", "_")
        if not re.fullmatch(r"[a-zA-Z_][a-zA-Z_0-9]*", name):
            raise ValueError(f"invalid test name: {name}")
        metadata = re.search(
            rf"run_gpu_test\(t, `{re.escape(name)}`, `(.*?)`, (\d+), \{{([^}}]+)\}}, wide_main, (\d+)\)",
            generated, re.S,
        )
        # Upstream's generated nested-loop case still carries obsolete comment lines.
        def without_comments(text):
            return "\n".join(line for line in text.strip().splitlines() if not line.lstrip().startswith("//"))

        if not metadata or without_comments(metadata[1]) != without_comments(source):
            raise ValueError(f"regenerate tests/tests.odin before exporting {name}")
        count, result, ulps = int(metadata[2]), metadata[3].strip(), int(metadata[4])
        if not 1 <= count <= 8 or result not in ("f32", "bool"):
            raise ValueError(f"unsupported GPU fixture signature: {name}")
        tests.append(dict(name=name, source=source, count=count, result=result, ulps=ulps))
    if len({test["name"] for test in tests}) != len(tests):
        raise ValueError("duplicate GPU test name")
    return tests


def exporter(tests):
    calls, references = [], []
    for test in tests:
        name, source = test["name"], test["source"]
        body = source.replace("package main", "", 1).replace("main ::", "main_ ::", 1)
        arguments = ", ".join(f"args[{i}][lane]" for i in range(test["count"]))
        value = f"main_({arguments})"
        bits = f"transmute(u32){value}" if test["result"] == "f32" else f"u32({value})"
        references.append(f"""
reference_{name} :: proc(args: [][8]f32) -> [8]u32 {{
{body}
    result: [8]u32
    for lane in 0..<8 do result[lane] = {bits}
    return result
}}
""")
        calls.append(
            f'append(&records, compile("{name}", `{source}`, "{test["result"]}", '
            f'{test["count"]}, {test["ulps"]}, reference_{name}))'
        )
    return EXPORTER.replace("// GENERATED_CALLS", "\n    ".join(calls)) + "\n".join(references)


def run(args, **kwargs):
    subprocess.run([str(arg) for arg in args], check=True, timeout=20, **kwargs)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--odin", default=os.environ.get("ODIN", "odin"))
    parser.add_argument("--cc", default=os.environ.get("CC", "gcc"))
    parser.add_argument("--output", type=Path, default=ROOT / "trueos/build/gpu-tests")
    selection = parser.add_mutually_exclusive_group()
    selection.add_argument("--test", action="append", dest="names", help="select a named test (repeatable)")
    selection.add_argument("--all", action="store_true", help="export the entire corpus instead of the five smoke tests")
    args = parser.parse_args()
    odin = shutil.which(args.odin)
    if not odin:
        parser.error("Odin compiler not found; set ODIN or --odin")
    tests = corpus()
    names = args.names or DEFAULT_TESTS
    if not args.all:
        by_name = {test["name"]: test for test in tests}
        unknown = set(names) - by_name.keys()
        if unknown:
            parser.error(f"unknown GPU tests: {', '.join(sorted(unknown))}")
        tests = [by_name[name] for name in dict.fromkeys(names)]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    previous = output / "manifest.json"
    previous_kernels = []
    if previous.exists():
        previous_kernels = [record["kernel"] for record in json.loads(previous.read_text())["tests"]]
    with tempfile.TemporaryDirectory(prefix="odin-gpu-aot-") as directory:
        stage = Path(directory)
        for name in ("bac", "odinc"):
            shutil.copytree(ROOT / name, stage / name)
        (stage / "utils").symlink_to(ROOT / "utils", target_is_directory=True)
        # Older host Odin needs an explicit enum type; upstream sources stay unchanged.
        codegen = stage / "bac/codegen.odin"
        codegen.write_text(codegen.read_text().replace("max(node.lane, .I16)", "max(node.lane, Lane_Type.I16)"))
        (stage / "exporter").mkdir()
        (stage / "exporter/main.odin").write_text(exporter(tests))
        obj, executable = stage / "exporter.o", stage / "compile-gpu-tests"
        run([odin, "build", stage / "exporter", "-build-mode:obj", "-use-single-module", f"-out:{obj}"])
        run([args.cc, obj, "-lm", "-ldl", "-lpthread", "-o", executable])
        artifacts = stage / "artifacts"
        artifacts.mkdir()
        run([executable], cwd=artifacts)
        records = json.loads((artifacts / "records.json").read_text())
        if [record["name"] for record in records] != [test["name"] for test in tests]:
            raise ValueError("incomplete GPU export")
        for test, record in zip(tests, records):
            binary = (artifacts / record["kernel"]).read_bytes()
            record.update(bytes=len(binary), sha256=hashlib.sha256(binary).hexdigest(),
                          source_sha256=hashlib.sha256(test["source"].encode()).hexdigest())
            (output / record["kernel"]).write_bytes(binary)
        manifest = dict(version=1, target="intel_xelp", platform="12p1", simd_width=8,
                        optimization="all", byte_order="little", gpu_executed=False,
                        source_revision=subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
                        corpus_sha256=hashlib.sha256((ROOT / "tests/GPU-TESTS.md").read_bytes()).hexdigest(),
                        tests=records)
        (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
        current_kernels = {record["kernel"] for record in records}
        for filename in set(previous_kernels) - current_kernels:
            if Path(filename).name == filename and re.fullmatch(r"gpu_[a-zA-Z_0-9]+\.bin", filename):
                (output / filename).unlink(missing_ok=True)
    print(f"Compiled {len(records)} GPU kernels ({sum(record['bytes'] for record in records)} bytes) into {output}")


if __name__ == "__main__":
    main()
