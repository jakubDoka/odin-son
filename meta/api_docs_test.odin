package meta

import "../utils/arna"
import "core:odin/ast"
import "core:odin/parser"
import "core:testing"

@(test)
backend_api_doc_comments :: proc(t: ^testing.T) {
	arna.init_scratch(1 << 20)
	defer arna.deinit_scratch()
	context.allocator, _ = arna.scrath()
	f := ast.File {
		src = `package fixture

/// A "quoted" comment with a \path.
@(tag = "api")
single :: proc() {}

/// First line.
/// Second line.
@(tag = "api")
@(require_results)
multiple :: proc() -> bool { return true }

/**
 * A block comment.
 */
@(tag = "api")
block :: proc() {}

@(tag = "api")
undocumented :: proc() {} // Not a doc comment.
`,
	}
	p: parser.Parser
	if !testing.expect(t, parser.parse_file(&p, &f)) do return
	expected := [?]string {
		`/// A "quoted" comment with a \path.`,
		"/// First line.\n/// Second line.",
		"/**\n * A block comment.\n */",
		"",
	}
	testing.expect_value(t, len(f.decls), len(expected))
	for decl, i in f.decls {
		vdecl := decl.derived.(^ast.Value_Decl)
		testing.expect(t, has_tag(vdecl, "api"))
		testing.expect_value(t, src_of(f, vdecl.docs), expected[i])
	}
}
