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

	file, err := os.open(
		"backend/meta_overloads.odin",
		{.Create, .Trunc, .Write},
	)
	fmt.assertf(err == nil, "%v", err)
	defer os.close(file)

	os.write_string(file, "package backend\n")
	os.write_string(file, "// NOTE: this file is generated: " + COMMAND)
	os.write_string(file, "\n\n")

	file_paths := []string{"./backend/backend.odin"}
	for file_path in file_paths {
		// Read the File:
		data, err := os.read_entire_file(file_path, context.allocator)
		fmt.assertf(err == nil, "%v", err)
		// Parse Into the AST:
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

src_of :: proc(f: ast.File, node: ^ast.Node) -> string {
	return f.src[node.pos.offset:node.end.offset]
}
