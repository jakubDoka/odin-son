package meta

import "core:fmt"
import "core:odin/ast"
import "core:odin/parser"
import "core:os"
import "core:path/filepath"
import "core:slice"
import "core:strconv"
import "core:strings"

API_DIR :: "bac/bindgen"
OVERLOAD_FILE :: "meta_overloads.odin"

Backend_Package :: struct {
	path:  string,
	name:  string,
	procs: [dynamic]Backend_Proc,
}

Backend_Proc :: struct {
	name:         string,
	file:         ^ast.File,
	lit:          ^ast.Proc_Lit,
	api:          bool,
	node_proc:    bool,
	thread_local: bool,
	doc_comment:  string,
}

has_thread_local :: proc(decl: ^ast.Value_Decl) -> bool {
	for attr in decl.attributes {
		for elem in attr.elems {
			field := elem.derived.(^ast.Ident) or_continue
			if field.name == "thread_local" {
				return true
			}
		}
	}
	return false
}

has_tag :: proc(decl: ^ast.Value_Decl, tag: string) -> bool {
	for attr in decl.attributes {
		for elem in attr.elems {
			field := elem.derived.(^ast.Field_Value) or_continue
			ident := field.field.derived.(^ast.Ident) or_continue
			if ident.name != "tag" do continue
			lit := field.value.derived.(^ast.Basic_Lit) or_continue
			tags, _, ok := strconv.unquote_string(lit.tok.text)
			if !ok do continue
			for tags != "" {
				part, _ := strings.split_iterator(&tags, ",")
				if strings.trim_space(part) == tag do return true
			}
		}
	}
	return false
}

load_backend_packages :: proc(
	dir: string,
) -> (
	packages: [dynamic]Backend_Package,
) {
	entries, err := os.read_all_directory_by_path(dir, context.allocator)
	fmt.assertf(err == nil, "%v: %v", dir, err)
	slice.sort_by(entries, proc(a, b: os.File_Info) -> bool {
		return a.name < b.name
	})

	pkg := Backend_Package {
		path = dir,
	}
	for entry in entries {
		if entry.type == .Directory do continue
		if !strings.has_suffix(entry.name, ".odin") do continue
		if strings.has_suffix(entry.name, "_test.odin") do continue

		data, rerr := os.read_entire_file(entry.fullpath, context.allocator)
		fmt.assertf(rerr == nil, "%v: %v", entry.fullpath, rerr)
		f := new(ast.File)
		f.src = string(data)
		f.fullpath = entry.fullpath
		p: parser.Parser
		ok := parser.parse_file(&p, f)
		fmt.assertf(ok, "failed to parse %v", entry.fullpath)
		pkg.name = f.pkg_name

		for decl in f.decls {
			vdecl := decl.derived.(^ast.Value_Decl) or_continue
			api := has_tag(vdecl, "api")
			node_proc := has_tag(vdecl, "node_proc")
			thread_local := has_thread_local(vdecl)
			if !api && !node_proc do continue
			fmt.assertf(
				len(vdecl.names) == 1,
				"%v: tagged declarations must name a single procedure",
				entry.fullpath,
			)

			if len(vdecl.values) > 0 {
				if lit, pok := vdecl.values[0].derived.(^ast.Proc_Lit); pok {
					fmt.assertf(
						pok,
						"%v: tag overload children, not overload groups",
						entry.fullpath,
					)
					append(
						&pkg.procs,
						Backend_Proc {
							name = src_of(f^, vdecl.names[0]),
							file = f,
							lit = lit,
							api = api,
							node_proc = node_proc,
							doc_comment = src_of(f^, vdecl.docs),
						},
					)
					continue
				}
			}

			append(
				&pkg.procs,
				Backend_Proc {
					name = src_of(f^, vdecl.names[0]),
					file = f,
					api = api,
					thread_local = thread_local,
					doc_comment = src_of(f^, vdecl.docs),
				},
			)
		}
	}

	if pkg.name != "" {
		slice.sort_by(pkg.procs[:], proc(a, b: Backend_Proc) -> bool {
			return a.name < b.name
		})
		append(&packages, pkg)
	}
	for entry in entries {
		if entry.type != .Directory do continue
		append(&packages, ..load_backend_packages(entry.fullpath)[:])
	}
	return
}

gen_backend_overloads :: proc(packages: []Backend_Package) {
	for pkg in packages {
		count := 0
		for prc in pkg.procs do count += int(prc.node_proc)
		if count == 0 do continue
		path, _ := filepath.join({pkg.path, OVERLOAD_FILE})
		file, err := os.open(path, {.Create, .Trunc, .Write})
		fmt.assertf(err == nil, "%v: %v", path, err)
		defer os.close(file)
		fmt.fprintfln(file, "package %v", pkg.name)
		fmt.fprintfln(file, "// NOTE: this file is generated: %v\n", COMMAND)

		imports: map[string]bool
		for prc in pkg.procs {
			if !prc.node_proc do continue
			for imp in prc.file.imports {
				alias := imp.name.text
				if alias == "" {
					path := imp.relpath.text[1:len(imp.relpath.text) - 1]
					alias = filepath.base(path)
					alias = alias[strings.last_index(alias, ":") + 1:]
				}
				if !strings.contains(src_of(prc.file^, prc.lit.type), fmt.tprintf("%v.", alias)) do continue
				source := src_of(prc.file^, imp)
				if source in imports do continue
				imports[source] = true
				fmt.fprintln(file, source)
			}
		}

		for prc in pkg.procs {
			if !prc.node_proc do continue
			name := prc.name
			fmt.assertf(
				strings.has_suffix(name, SUFFIX),
				"%v must end with %v",
				name,
				SUFFIX,
			)
			fmt.fprintfln(
				file,
				"%v :: proc{{%v, %v_id}}",
				name[:len(name) - len(SUFFIX)],
				name,
				name,
			)

			the_arg :: "node: ^Node"
			sig := src_of(prc.file^, prc.lit.type)
			sig, _ = strings.replace_all(sig, the_arg, "id: Node_ID")
			if prc.api do os.write_string(file, "@(tag = \"api\")\n")
			fmt.fprintf(file, "%v_id :: #force_inline %v {{\n\t", name, sig)
			if prc.lit.type.results != nil do os.write_string(file, "return ")
			fmt.fprintf(file, "%v(", name)
			for arg, i in prc.lit.type.params.list {
				if i != 0 do os.write_string(file, ", ")
				if src_of(prc.file^, arg) == the_arg {
					os.write_string(file, "get_node(graph, id)")
				} else {
					repl, _ := strings.replace_all(
						src_of(prc.file^, arg.names[0]),
						"$",
						"",
					)
					os.write_string(file, repl)
				}
			}
			os.write_string(file, ")\n}\n")
		}
	}
}

gen_backend_api :: proc(packages: []Backend_Package) {
	api_packages: [dynamic]Backend_Package
	for pkg in packages {
		for prc in pkg.procs {
			if !prc.api do continue
			append(&api_packages, pkg)
			break
		}
	}

	err := os.make_directory_all(API_DIR)
	fmt.assertf(
		err == nil || err == os.General_Error.Exist,
		"%v: %v",
		API_DIR,
		err,
	)
	path, _ := filepath.join({API_DIR, "api.odin"})
	file, oerr := os.open(path, {.Create, .Trunc, .Write})
	fmt.assertf(oerr == nil, "%v: %v", path, oerr)
	defer os.close(file)
	os.write_string(file, "package bac_bindgen\n")
	fmt.fprintfln(file, "// NOTE: this file is generated: %v\n", COMMAND)
	base, berr := filepath.abs(API_DIR)
	fmt.assertf(berr == nil, "%v: %v", API_DIR, berr)
	for pkg, i in api_packages {
		abs, aerr := filepath.abs(pkg.path)
		fmt.assertf(aerr == nil, "%v: %v", pkg.path, aerr)
		relpath, rerr := filepath.rel(base, abs)
		fmt.assertf(rerr == nil, "%v: %v", pkg.path, rerr)
		fmt.fprintfln(file, "import pkg_%v %q", i, relpath)
	}
	os.write_string(file, `
@(rodata)
API := [?]API_Proc{
`)

	for pkg, i in api_packages {
		abs, _ := filepath.abs(pkg.path)
		relpath, _ := filepath.rel(base, abs)
		for prc in pkg.procs {
			if !prc.api do continue
			ty := fmt.tprintf("type_of(pkg_%v.%v)", i, prc.name)

			fmt.fprintfln(
				file,
				"\t{{%v, %q, %q, %v, %q}},",
				prc.thread_local,
				relpath,
				prc.name,
				ty,
				prc.doc_comment,
			)
		}
	}

	os.write_string(file, "}\n")
}

proc_type_is_generic :: proc(ty: ^ast.Proc_Type) -> (generic: bool) {
	visitor := ast.Visitor {
		data = &generic,
		visit = proc(visitor: ^ast.Visitor, node: ^ast.Node) -> ^ast.Visitor {
			if node == nil do return nil
			if _, ok := node.derived.(^ast.Poly_Type); ok {
				(^bool)(visitor.data)^ = true
				return nil
			}
			return visitor
		},
	}
	ast.walk(&visitor, ty)
	return
}
