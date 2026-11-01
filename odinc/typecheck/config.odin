package typecheck

import "core:fmt"
import "core:odin/ast"
import "core:odin/parser"
import "core:odin/tokenizer"
import "core:strings"

parse_config_define :: proc(
	definition: string,
) -> (
	name, value: string,
	ok: bool,
) {
	index := strings.index_byte(definition, '=')
	if index <= 0 do return
	name = definition[:index]
	return name, definition[index + 1:], true
}

typecheck_config :: proc(
	ctx: ^Gen_Ctx,
	prop: Ty_Propagation,
	node: ^ast.Call_Expr,
) -> (
	ty: ^Check_Meta,
) {
	args, valid_args := expect_args(ctx, node, node.args, 2, &ty)
	if !valid_args do return ty

	name, ok := args[0].derived.(^ast.Ident)
	if !ok do return error(ctx, args[0], "expected a configuration name")

	default := typecheck_eval(ctx, prop, args[1])
	if default.type == .Invalid_Type do return &INVALID
	if default.type != .String && !in_set(default.type, NUMBER_TYPES) {
		return error(ctx, args[1], "configuration default must be a scalar")
	}

	value, found := ctx.configs[name.name]
	if !found do return default

	context.allocator = ctx.types.allocator
	quoted := strings.trim_space(value)
	if default.type == .String &&
	   (len(quoted) == 0 || (quoted[0] != '"' && quoted[0] != '`')) {
		value = fmt.aprintf("%q", value)
	}

	filename: strings.Builder
	fmt.sbprintf(&filename, "#config(%s)", name.name)

	file := ast.File {
		src      = value,
		fullpath = string(filename.buf[:]),
	}
	p := parser.default_parser()
	p.file = &file
	tokenizer.init(&p.tok, file.src, file.fullpath, p.err)
	parser.advance_token(&p)
	expr := parser.parse_expr(&p, false)
	if p.error_count != 0 || p.tok.error_count != 0 || p.curr_tok.kind != .EOF {
		return error(
			ctx,
			node,
			"invalid value for configuration %q: %q",
			name.name,
			value,
		)
	}

	meta := typecheck_eval(ctx, {inferred_ty = default.type}, expr)
	if meta.type == .Invalid_Type do return &INVALID
	if default.type != .Bool &&
	   meta.type != .Bool &&
	   in_set(default.type, NUMBER_TYPES) &&
	   in_set(meta.type, NUMBER_TYPES) {
		return typecheck_conversion(ctx, node, default.type, meta)
	}
	if meta.type != default.type {
		return error(
			ctx,
			node,
			"configuration %q: expected %v, found %v",
			name.name,
			default.type,
			meta.type,
		)
	}
	return meta
}
