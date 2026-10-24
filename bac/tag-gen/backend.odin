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
	procs: [dynamic]Backend_Item,
}

Backend_Item :: struct {
	name:         string,
	file:         ^ast.File,
	lit:          ^ast.Proc_Lit,
	api:          bool,
	node_proc:    bool,
	priority:     int,
	thread_local: bool,
	doc_comment:  string,
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

			thread_local: bool

			tags: []string
			for attr in vdecl.attributes {
				for elem in attr.elems {
					if field, ok := elem.derived.(^ast.Ident);
					   ok && field.name == "thread_local" {
						thread_local = true
					}
					field := elem.derived.(^ast.Field_Value) or_continue
					ident := field.field.derived.(^ast.Ident) or_continue
					if ident.name != "tag" do continue
					lit := field.value.derived.(^ast.Basic_Lit) or_continue
					unq_tags, _, ok := strconv.unquote_string(lit.tok.text)
					if ok do tags = strings.split(unq_tags, ",")
				}
			}

			api := slice.contains(tags, "api")
			if (pkg.name == "bac" || pkg.name == "bac_ssa") &&
			   entry.name == "node_specs.odin" &&
			   len(vdecl.names) == 1 {
				api |= strings.has_prefix(src_of(f^, vdecl.names[0]), "add_")
			}
			node_proc := slice.contains(tags, "node_proc")
			if !api && !node_proc do continue
			fmt.assertf(
				len(vdecl.names) == 1,
				"%v: tagged declarations must name a single procedure",
				entry.fullpath,
			)

			priority: int

			for tag in tags {
				if strings.starts_with(tag, "priority=") {
					priority, ok = strconv.parse_int(tag[len("priority="):])
					fmt.assertf(ok, "priority should be a number: %v %v", tag, decl.pos)
				}
			}

			lit: ^ast.Proc_Lit

			if len(vdecl.values) > 0 {
				lit, _ = vdecl.values[0].derived.(^ast.Proc_Lit)
			}

			append(
				&pkg.procs,
				Backend_Item {
					name = src_of(f^, vdecl.names[0]),
					file = f,
					lit = lit,
					api = api,
					node_proc = node_proc,
					priority = priority,
					thread_local = thread_local,
					doc_comment = src_of(f^, vdecl.docs),
				},
			)
		}
	}

	if pkg.name != "" {
		slice.sort_by(
			pkg.procs[:],
			proc(a, b: Backend_Item) -> bool {return a.name < b.name},
		)
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

		imports: map[string]struct{}
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
				imports[source] = {}
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
					os.write_string(file, "get_node(prc, id)")
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

	Item :: struct {
		using prc: Backend_Item,
		relpath:   string,
		pkg:       int,
	}

	items: [dynamic]Item

	for pkg, i in api_packages {
		abs, _ := filepath.abs(pkg.path)
		relpath, _ := filepath.rel(base, abs)
		for prc in pkg.procs {
			append(&items, {prc, relpath, i})
		}
	}

	slice.sort_by_key(items[:], proc(i: Item) -> int {return -i.priority})

	for prc in items {
		if !prc.api do continue
		ty := fmt.tprintf("type_of(pkg_%v.%v)", prc.pkg, prc.name)

		fmt.fprintfln(
			file,
			"\t{{%q, %q, %v, %q}},",
			prc.relpath,
			prc.name,
			ty,
			prc.doc_comment,
		)
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
