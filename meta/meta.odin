package meta

import "core:fmt"
import "core:odin/ast"
import "core:odin/parser"
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

	{
		file, err := os.open(
			"backend/meta_overloads.odin",
			{.Create, .Trunc, .Write},
		)
		fmt.assertf(err == nil, "%v", err)
		defer os.close(file)

		os.write_string(file, "package backend\n")
		os.write_string(file, "// NOTE: this file is generated: " + COMMAND)
		os.write_string(file, "\n\n")

		file_paths := []string{"./backend/graph.odin", "./backend/gcm.odin"}
		for file_path in file_paths {
			data, derr := os.read_entire_file(file_path, context.allocator)
			fmt.assertf(derr == nil, "%v", derr)
			p := parser.Parser{}
			f := ast.File {
				src      = string(data),
				fullpath = file_path,
			}
			ok := parser.parse_file(&p, &f); assert(ok)

			for decl in f.decls {
				vdecl := decl.derived.(^ast.Value_Decl) or_continue

				found := false
				for attr in vdecl.attributes {
					for elem in attr.elems {
						field := elem.derived_expr.(^ast.Field_Value) or_continue
						lit := field.value.derived.(^ast.Basic_Lit) or_continue
						found |= lit.tok.text == `"node_proc"`
					}
				}

				if !found do continue

				pdecl := decl.derived_stmt.(^ast.Value_Decl)
				procl := pdecl.values[0].derived_expr.(^ast.Proc_Lit)

				name := src_of(f, pdecl.names[0])

				fmt.fprintfln(
					file,
					"%v :: proc{{%v, %v_id}}",
					name[:len(name) - len(SUFFIX)],
					name,
					name,
				)

				the_arg :: "node: ^Node"

				sig := src_of(f, procl.type)
				has_return := strings.contains(sig, " -> ")
				sig, _ = strings.replace_all(
					sig,
					the_arg,
					"id: Node_ID",
					context.allocator,
				)

				fmt.fprintf(file, "%v_id :: #force_inline %v {{\n", name, sig)
				if has_return {
					fmt.fprintf(file, "\treturn %v(", name)
				} else {
					fmt.fprintf(file, "\t%v(", name)
				}

				for arg, i in procl.type.params.list {
					source := src_of(f, arg)

					if i != 0 do os.write_string(file, ", ")

					if source == the_arg {
						os.write_string(file, "graph_get(graph, id)")
					} else {
						repl, _ := strings.replace_all(
							src_of(f, arg.names[0]),
							"$",
							"",
							context.allocator,
						)
						os.write_string(file, repl)
					}
				}

				os.write_string(file, ")\n}\n")
			}
		}
	}

	{
		file, err := os.open("tests/tests.odin", {.Create, .Trunc, .Write})
		fmt.assertf(err == nil, "%v", err)
		defer os.close(file)

		os.write_string(file, "#+build !wasm32\n")
		os.write_string(file, "package tests\n")
		os.write_string(file, "// NOTE: this file is generated: " + COMMAND)
		os.write_string(file, "\n\n")
		os.write_string(file, "import \"core:testing\"\n\n")
		os.write_string(file, "import \"base:intrinsics\"\n\n")
		os.write_string(file, "import main \"..\"\n\n")

		os.remove_all(FUZZ_CORPUS_DIR)
		os.make_directory_all(FUZZ_CORPUS_DIR)

		file_paths := []string{"TESTS.md"}
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

				rall_name, _ := strings.replace_all(
					name,
					" ",
					"_",
					context.allocator,
				)

				corpus_path, _ := os.join_path(
					{FUZZ_CORPUS_DIR, fmt.tprintf("%v.odin", rall_name)},
					context.allocator,
				)
				cerr := os.write_entire_file(
					corpus_path,
					transmute([]byte)code,
				)
				fmt.assertf(cerr == nil, "%v: %v", corpus_path, cerr)

				fmt.fprintfln(
					file,
					"@(test) %v :: proc(t: ^testing.T) {{",
					rall_name,
				)

				// a `fail ...` test is expected to be rejected by our
				// typechecker, so it can't be compiled by odin to obtain the
				// expected exit code
				if strings.has_prefix(name, "fail ") {
					fmt.fprintfln(
						file,
						"main.run_test(t, `%v`, `%v`, 0)",
						rall_name,
						code,
					)
					fmt.fprintfln(file, "}}")
					continue
				}

				inlined, _ := strings.replace_all(code, "package main", "")
				inlined, _ = strings.replace_all(
					inlined,
					"main ::",
					"main_ ::",
				)
				fmt.fprintfln(file, "%v", inlined)
				fmt.fprintfln(
					file,
					"main.run_test(t, `%v`, `%v`, main_())",
					rall_name,
					code,
				)
				fmt.fprintfln(file, "}}")
			}
		}

		gen_fuzz_crash_tests(file)
	}
}

// afl-fuzz writes one file per unique crash under `<out>/<worker>/crashes/`;
// those get copied into FUZZ_CRASH_DIR (named after their content hash so
// re-importing the same crash is a no-op) and each becomes a test
gen_fuzz_crash_tests :: proc(file: ^os.File) {
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
		name := fmt.tprintf(
			"fuzz_%v",
			crash.name[:len(crash.name) - len(".odin")],
		)
		fmt.fprintfln(file, "@(test) %v :: proc(t: ^testing.T) {{", name)
		// the input is raw fuzzer output, so it can't be inlined as a literal
		fmt.fprintfln(
			file,
			"main.run_test(t, `%v`, string(#load(\"../%v/%v\")), 0)",
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
