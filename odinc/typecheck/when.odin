package typecheck

import "core:odin/ast"

Decl_Condition :: struct {
	parent: ^Decl_Condition,
	expr:   ^ast.Expr,
	// NOTE: as in, the value that makes this trigger
	value:  bool,
}

when_condition :: proc(ctx: ^Gen_Ctx, expr: ^ast.Expr) -> ^Check_Meta {
	if len(expr.end.file) == 0 do return get_node_meta(expr)
	set_node_data(expr, &INVALID)
	value := typecheck_eval(ctx, {inferred_ty = .Bool}, expr)
	return expect(ctx, expr, value, .Bool)
}

decl_enabled :: proc(ctx: ^Gen_Ctx, mid: Module_ID, decl: ^Decl) -> bool {
	if decl.condition == nil do return true
	previous_module, previous_file := ctx.module, ctx.file_id
	previous_prc_id := ctx.prc_id
	defer {
		ctx.module = previous_module
		ctx.file_id = previous_file
		ctx.file = &ctx.files[previous_file]
		ctx.prc_id = previous_prc_id
	}
	ctx.module = mid
	ctx.prc_id = 0
	ctx.file_id = decl.file
	ctx.file = &ctx.files[decl.file]
	return enabled(ctx, decl.condition)

	enabled :: proc(ctx: ^Gen_Ctx, condition: ^Decl_Condition) -> bool {
		if condition == nil do return true
		if !enabled(ctx, condition.parent) do return false
		value := when_condition(ctx, condition.expr)
		return(
			value.type == .Bool &&
			value.known &&
			(value.int != 0) == condition.value \
		)
	}
}

typecheck_package_stmts :: proc(ctx: ^Gen_Ctx, stmts: []^ast.Stmt) {
	for stmt in stmts {
		#partial switch d in stmt.derived {
		case ^ast.When_Stmt:
			cond := when_condition(ctx, d.cond)
			if cond.type != .Bool do continue
			selected := cond.int != 0 ? d.body : d.else_stmt
			if selected == nil do continue
			if block, ok := selected.derived.(^ast.Block_Stmt); ok {
				typecheck_package_stmts(ctx, block.stmts)
			} else {
				typecheck_package_stmts(ctx, {selected})
			}
		case ^ast.Expr_Stmt:
			typecheck(ctx, {}, stmt)
		}
	}
}
