package meta

import api "../bac/bindgen"
import "core:fmt"
import "core:odin/ast"
import "core:odin/parser"
import "core:path/filepath"
import "core:testing"

parse_backend_test_source :: proc(src: string) -> ^ast.File {
	f := new(ast.File)
	f.src = src
	f.fullpath = "backend_test_input.odin"
	p: parser.Parser
	assert(parser.parse_file(&p, f))
	return f
}

@(test)
backend_tags :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	f := parse_backend_test_source(
		`package example
@(tag = "api")
plain :: proc() {}
@(tag = "node_proc, api")
both_node :: proc() {}
@(other = "api", tag = "not_api")
other :: proc() {}
`,
	)
	for decl, i in f.decls {
		vdecl := decl.derived.(^ast.Value_Decl)
		testing.expect_value(t, has_tag(vdecl, "api"), i < 2)
		testing.expect_value(t, has_tag(vdecl, "node_proc"), i == 1)
	}
}

@(test)
backend_generic_types :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	f := parse_backend_test_source(
		`package example
plain :: proc(value: int) -> int { return value }
generic :: proc(value: $T) -> T { return value }
typed :: proc($T: typeid) -> ^T { return nil }
nested :: proc(values: []Entry($T)) {}
constant :: proc($count: int) {}
`,
	)
	for decl, i in f.decls {
		vdecl := decl.derived.(^ast.Value_Decl)
		lit := vdecl.values[0].derived.(^ast.Proc_Lit)
		testing.expect_value(t, proc_type_is_generic(lit.type), i != 0)
	}
}

@(test)
backend_api_table :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	root := fmt.tprintf("%v/../bac", #directory)
	base, _ := filepath.abs(fmt.tprintf("%v/bindgen", root))
	seen: map[[2]string]bool
	for entry in api.API {
		key := [2]string{entry.package_path, entry.name}
		testing.expectf(t, key not_in seen, "duplicate API entry: %v", key)
		seen[key] = true
	}
	count := 0
	for pkg in load_backend_packages(root) {
		abs, _ := filepath.abs(pkg.path)
		rel, _ := filepath.rel(base, abs)
		for prc in pkg.procs {
			if !prc.api do continue
			count += 1
			key := [2]string{rel, prc.name}
			testing.expectf(t, key in seen, "missing API entry: %v", key)
			for entry in api.API {
				if entry.package_path != rel || entry.name != prc.name do continue
				testing.expect_value(
					t,
					entry.type == nil,
					proc_type_is_generic(prc.lit.type),
				)
			}
		}
	}
	testing.expect_value(t, count, len(api.API))
	testing.expect(t, [2]string{"..", "get_extra"} not_in seen)
	testing.expect(t, [2]string{"..", "get_static_extra_node"} in seen)
	testing.expect(t, [2]string{"..", "get_static_extra_node_id"} in seen)
	testing.expect(t, [2]string{"../builder", "inline_call"} not_in seen)
	testing.expect(t, [2]string{"../builder", "inline_graph"} in seen)
	testing.expect(t, [2]string{"../builder", "inline_stencil"} in seen)
}
