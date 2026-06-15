package meta

import "core:fmt"
import "core:odin/ast"
import "core:odin/parser"
import "core:os"
import "core:strings"

COMMAND :: "odin run meta"
SUFFIX :: "_node"

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
			data, err := os.read_entire_file(file_path, context.allocator)
			fmt.assertf(err == nil, "%v", err)
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
		file, err := os.open("tests.odin", {.Create, .Trunc, .Write})
		fmt.assertf(err == nil, "%v", err)
		defer os.close(file)

		os.write_string(file, "package main\n")
		os.write_string(file, "// NOTE: this file is generated: " + COMMAND)
		os.write_string(file, "\n\n")
		os.write_string(file, "import \"core:testing\"\n\n")

		file_paths := []string{"TESTS.md"}
		for file_path in file_paths {
			data, err := os.read_entire_file(file_path, context.allocator)
			fmt.assertf(err == nil, "%v", err)

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
				fmt.fprintfln(
					file,
					"@(test) %v :: proc(t: ^testing.T) {{",
					rall_name,
				)
				fmt.fprintfln(file, "run_test(t, `%v`, `%v`)", rall_name, code)
				fmt.fprintfln(file, "}}")
			}
		}
	}
}

src_of :: proc(f: ast.File, node: ^ast.Node) -> string {
	return f.src[node.pos.offset:node.end.offset]
}
