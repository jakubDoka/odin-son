package meta

import "core:fmt"
import "core:odin/ast"
import "core:os"
import "core:slice"
import "core:strings"

COMMAND :: "odin run meta"
SUFFIX :: "_node"

// corpus is regenerated from TESTS.md on every run, crashes are imported from
// whatever afl-fuzz dumped into FUZZ_OUT_DIR and then kept around forever
FUZZ_CORPUS_DIR :: "fuzz/corpus"
FUZZ_CRASH_DIR :: "fuzz/crashes"
FUZZ_OUT_DIR :: "fuzz/out"

main :: proc() {
	context.allocator = context.temp_allocator

	gen_backend_overloads(load_backend_packages("bac")[:])
	gen_backend_api(load_backend_packages(".")[:])

	{
		tests: [dynamic]Test

		file, err := os.open("tests/tests.odin", {.Create, .Trunc, .Write})
		fmt.assertf(err == nil, "%v", err)
		defer os.close(file)

		os.write_string(file, "#+build !wasm32\n")
		os.write_string(file, "package tests\n")
		os.write_string(file, "// NOTE: this file is generated: " + COMMAND)
		os.write_string(file, "\n\n")
		os.write_string(file, "import \"core:testing\"\n")
		os.write_string(file, "import \"base:intrinsics\"\n")

		os.remove_all(FUZZ_CORPUS_DIR)
		os.make_directory_all(FUZZ_CORPUS_DIR)

		file_paths := []string{"tests/TESTS.md"}
		for file_path in file_paths {
			data, derr := os.read_entire_file(file_path, context.allocator)
			fmt.assertf(derr == nil, "%v", derr)

			src := string(data)

			for {
				needle := "#### "
				idx := strings.index(src, needle)
				if idx < 0 do break
				src = src[idx + len(needle):]

				needle = "\n```odin"
				name_end_idx := strings.index(src, needle)
				if name_end_idx < 0 do break
				name := src[:name_end_idx]
				src = src[name_end_idx + len(needle):]

				if strings.contains(name, "\n") {
					continue
				}

				needle = "```"
				code_end_idx := strings.index(src, needle)
				if code_end_idx < 0 do break
				code := src[:code_end_idx]
				src = src[code_end_idx + len(needle):]

				rall_name, _ := strings.replace_all(name, " ", "_", context.allocator)

				corpus_path, _ := os.join_path(
					{FUZZ_CORPUS_DIR, fmt.tprintf("%v.odin", rall_name)},
					context.allocator,
				)
				cerr := os.write_entire_file(corpus_path, transmute([]byte)code)
				fmt.assertf(cerr == nil, "%v: %v", corpus_path, cerr)

				append(&tests, Test{rall_name, code, .Normal})

				DISABLED_TESTS := [?]string {
					"memset_conversion_preserves_reads_inside_the_loop",
					"memset_conversion_preserves_store_before_loop_exit",
					"multiply_add_preserves_intermediate_rounding",
					//"simd_byte_mask_extracts_least_significant_bits",
					"simd_byte_reduction_wraps_before_widening",
					"simd_u16_reduction_includes_every_lane",
					"simd_word_mask_extracts_one_bit_per_lane",
				}
				if slice.contains(DISABLED_TESTS[:], rall_name) {
					os.write_string(
						file,
						"// Disabled: known failure predating select lowering.\n",
					)
				} else {
					os.write_string(file, "@(test) ")
				}
				fmt.fprintfln(file, "%v :: proc(t: ^testing.T) {{", rall_name)

				// a `fail ...` test is expected to be rejected by our
				// typechecker, so it can't be compiled by odin to obtain the
				// expected exit code
				if strings.has_prefix(name, "fail ") {
					fmt.fprintfln(file, "run_test(t, `%v`, `%v`, 0)", rall_name, code)
					fmt.fprintfln(file, "}}")
					continue
				}

				inlined, _ := strings.replace_all(code, "package main", "")
				inlined, _ = strings.replace_all(inlined, "main ::", "main_ ::")
				fmt.fprintfln(file, "%v", inlined)
				fmt.fprintfln(
					file,
					"run_test(t, `%v`, `%v`, main_())",
					rall_name,
					code,
				)
				fmt.fprintfln(file, "}}")
			}
		}

		gen_fuzz_crash_tests(file, &tests)

		os.write_string(file, "when #config(BENCH_TESTS, false) {\n")
		os.write_string(file, "main :: proc() {\n")

		os.write_string(file, "NAMES := []string{\n")
		for test in tests {
			fmt.fprintfln(file, "`%v`,", test.name)
		}
		os.write_string(file, "}\n")

		os.write_string(file, "CODE := []string{\n")
		for test in tests {
			fmt.fprintfln(file, "`%v`,", test.code)
		}
		os.write_string(file, "}\n")

		os.write_string(file, "IS_FUZZ := []bool{\n")
		for test in tests {
			fmt.fprintfln(file, "%v,", test.kind == .Fuzz)
		}
		os.write_string(file, "}\n")

		os.write_string(file, "for i in 0 ..< len(CODE) {")
		os.write_string(file, "run_test(nil, NAMES[i], CODE[i], 0, ")
		os.write_string(file, "diff = false, no_run = IS_FUZZ[i] || NO_RUN)\n")
		os.write_string(file, "}\n")

		os.write_string(file, "}\n")
		os.write_string(file, "}\n")
	}
}

Test :: struct {
	name: string,
	code: string,
	kind: enum {
		Normal,
		Fuzz,
	},
}

// afl-fuzz writes one file per unique crash under `<out>/<worker>/crashes/`;
// those get copied into FUZZ_CRASH_DIR (named after their content hash so
// re-importing the same crash is a no-op) and each becomes a test
gen_fuzz_crash_tests :: proc(file: ^os.File, test_names: ^[dynamic]Test) {
	os.make_directory_all(FUZZ_CRASH_DIR)

	workers, werr := os.read_all_directory_by_path(
		FUZZ_OUT_DIR,
		context.allocator,
	)
	if werr == nil do for worker in workers {
		crash_dir, _ := os.join_path({worker.fullpath, "crashes"}, context.allocator)
		crashes, cerr := os.read_all_directory_by_path(crash_dir, context.allocator)
		if cerr != nil do continue

		for crash in crashes {
			if !strings.has_prefix(crash.name, "id:") do continue

			data, derr := os.read_entire_file(crash.fullpath, context.allocator)
			if derr != nil do continue

			dst, _ := os.join_path({FUZZ_CRASH_DIR, fmt.tprintf("%v.odin", hash_name(data))}, context.allocator)
			if os.exists(dst) do continue
			werr := os.write_entire_file(dst, data)
			fmt.assertf(werr == nil, "%v: %v", dst, werr)
		}
	}

	kept, kerr := os.read_all_directory_by_path(
		FUZZ_CRASH_DIR,
		context.allocator,
	)
	if kerr != nil do return

	slice.sort_by(kept, proc(a, b: os.File_Info) -> bool {
		return a.name < b.name
	})

	for crash in kept {
		if !strings.has_suffix(crash.name, ".odin") do continue
		name := fmt.tprintf("fuzz_%v", crash.name[:len(crash.name) - len(".odin")])

		append(
			test_names,
			Test {
				name,
				fmt.tprintf(`#load("../%v/%v")`, FUZZ_CRASH_DIR, crash.name),
				.Fuzz,
			},
		)

		fmt.fprintfln(file, "@(test) %v :: proc(t: ^testing.T) {{", name)
		// the input is raw fuzzer output, so it can't be inlined as a literal
		fmt.fprintfln(
			file,
			`run_test(t, "%v", string(#load("../%v/%v")), 0,
				diff = false, no_run = true)`,
			name,
			FUZZ_CRASH_DIR,
			crash.name,
		)
		fmt.fprintfln(file, "}}")
	}
}

hash_name :: proc(data: []byte) -> string {
	hash: u64 = 0xcbf29ce484222325
	for b in data {
		hash = (hash ~ u64(b)) * 0x100000001b3
	}
	return fmt.tprintf("%016x", hash)
}

src_of :: proc(f: ast.File, node: ^ast.Node) -> string {
	if node == nil do return ""
	return f.src[node.pos.offset:node.end.offset]
}
