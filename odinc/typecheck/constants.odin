package typecheck

import "core:mem"
import "core:odin/ast"
import "core:odin/tokenizer"
import "core:strconv"

constant_base_type :: proc(ty: Type) -> Type {
	if e, ok := unpack_type(ty).(^Enum); ok do return e.backing
	return ty
}

constant_string :: proc(ctx: ^Gen_Ctx, meta: ^Check_Meta) -> string {
	if meta.lvalue {
		data := global_raw_data(ctx, nil, meta)
		length := global_load(ctx, global_field(ctx, meta, .Int, 8)).int
		return string(ctx.globals[data.idx].bytes[data.offset:][:length])
	}

	value, _, ok := strconv.unquote_string(meta.string^)
	assert(ok)
	return value
}

constant_compare :: proc(lhs, rhs: $T, op: tokenizer.Token_Kind) -> bool {
	#partial switch op {
	case .Cmp_Eq:
		return lhs == rhs
	case .Not_Eq:
		return lhs != rhs
	case .Lt:
		return lhs < rhs
	case .Lt_Eq:
		return lhs <= rhs
	case .Gt:
		return lhs > rhs
	case .Gt_Eq:
		return lhs >= rhs
	case:
		unreachable()
	}
}

constant_binary :: proc(
	ctx: ^Gen_Ctx,
	node: ^ast.Binary_Expr,
	lhs, rhs: ^Check_Meta,
) -> ^Check_Meta {
	op := node.op.kind
	comparison := .B_Comparison_Begin < op && op < .B_Comparison_End
	base := constant_base_type(lhs.type)
	if comparison {
		value: bool
		switch {
		case base == .String:
			value = constant_compare(
				constant_string(ctx, lhs),
				constant_string(ctx, rhs),
				op,
			)
		case base == .Typeid:
			value = constant_compare(lhs.typeida, rhs.typeida, op)
		case in_set(base, FLOAT_TYPES):
			value = constant_compare(lhs.float, rhs.float, op)
		case in_set(base, UNSIGNED_TYPES):
			value = constant_compare(lhs.uint, rhs.uint, op)
		case in_set(base, SIGNED_TYPES):
			value = constant_compare(lhs.int, rhs.int, op)
		case is_data_pointer(base):
			left, right := lhs.dest, rhs.dest
			left_global, right_global :=
				ctx.globals[left.idx], ctx.globals[right.idx]
			if left_global.align == 0 && right_global.align == 0 {
				left_value, right_value: u64
				copy(mem.ptr_to_bytes(&left_value), left_global.bytes)
				copy(mem.ptr_to_bytes(&right_value), right_global.bytes)
				value = constant_compare(
					left_value + u64(left.offset),
					right_value + u64(right.offset),
					op,
				)
			} else if op == .Cmp_Eq || op == .Not_Eq {
				value = (left == right) == (op == .Cmp_Eq)
			} else if left.idx == right.idx {
				value = constant_compare(left.offset, right.offset, op)
			} else {
				return error(
					ctx,
					node,
					"can not order constant pointers to different globals",
				)
			}
		case is_of(base, ^Proc_Type):
			value = constant_compare(lhs.procid, rhs.procid, op)
		case:
			return error(
				ctx,
				node,
				"constant comparison not supported for %v",
				lhs.type,
			)
		}
		return tcmeta(ctx, .Bool, {int = i64(value)})
	}

	result := new_clone(lhs^, ctx.types.allocator)
	if in_set(base, FLOAT_TYPES) {
		#partial switch op {
		case .Add:
			result.float += rhs.float
		case .Sub:
			result.float -= rhs.float
		case .Mul:
			result.float *= rhs.float
		case .Quo:
			if rhs.float == 0 do return error(ctx, node.right, "division by zero")
			result.float /= rhs.float
		case:
			return error(
				ctx,
				node,
				"constant operation not supported: %v",
				node.op.text,
			)
		}
		if base == .F32 do result.float = f64(f32(result.float))
		return result
	}

	if !in_set(base, INTEGER_TYPES) {
		return error(
			ctx,
			node,
			"constant operation not supported for %v",
			lhs.type,
		)
	}

	signed := in_set(base, SIGNED_TYPES)
	#partial switch op {
	case .Add:
		result.uint += rhs.uint
	case .Sub:
		result.uint -= rhs.uint
	case .Mul:
		result.uint *= rhs.uint
	case .Quo, .Mod, .Mod_Mod:
		if rhs.uint == 0 do return error(ctx, node.right, "division by zero")
		if signed {
			if lhs.int == min(i64) && rhs.int == -1 {
				if op == .Quo do return error(ctx, node, "constant integer overflow")
				result.int = 0
			} else if op == .Quo {
				result.int /= rhs.int
			} else {
				result.int %= rhs.int
				if op == .Mod_Mod &&
				   result.int != 0 &&
				   (result.int < 0) != (rhs.int < 0) {
					result.int += rhs.int
				}
			}
		} else if op == .Quo {
			result.uint /= rhs.uint
		} else {
			result.uint %= rhs.uint
		}
	case .And:
		result.uint &= rhs.uint
	case .Or:
		result.uint |= rhs.uint
	case .Xor:
		result.uint ~= rhs.uint
	case .And_Not:
		result.uint &~= rhs.uint
	case .Shl, .Shr:
		if in_set(constant_base_type(rhs.type), SIGNED_TYPES) && rhs.int < 0 {
			return error(ctx, node.right, "shift count must be non negative")
		}
		if op == .Shl {
			result.uint = rhs.uint < 64 ? lhs.uint << rhs.uint : 0
		} else if signed {
			result.int = rhs.uint < 64 ? lhs.int >> rhs.uint : (lhs.int < 0 ? -1 : 0)
		} else {
			result.uint = rhs.uint < 64 ? lhs.uint >> rhs.uint : 0
		}
	case:
		return error(
			ctx,
			node,
			"constant operation not supported: %v",
			node.op.text,
		)
	}
	return result
}

valid_conversion_type :: proc(ty: Type) -> bool {
	return(
		in_set(constant_base_type(ty), NUMBER_TYPES) ||
		ty == .Rawptr ||
		is_of(ty, Pointer) ||
		is_of(ty, Multi_Pointer) \
	)
}

typecheck_conversion :: proc(
	ctx: ^Gen_Ctx,
	node: ^ast.Node,
	dst: Type,
	src: ^Check_Meta,
	strict := false,
) -> ^Check_Meta {
	if src.type == .Invalid_Type || dst == .Invalid_Type do return &INVALID

	if !valid_conversion_type(src.type) || !valid_conversion_type(dst) {
		return error(
			ctx,
			node,
			"unsupported conversion from %v to %v",
			src.type,
			dst,
		)
	}

	if !src.known do return tmeta(ctx, dst)

	if src.type == dst do return src

	if is_data_pointer(dst) {
		if is_data_pointer(src.type) do return tcmeta(ctx, dst, src.lit)
		return global_pointer(ctx, dst, src.uint)
	}

	if is_data_pointer(src.type) {
		global := ctx.globals[src.idx]
		if global.align != 0 {
			return error(
				ctx,
				node,
				"a relocatable pointer can not be converted to a constant integer",
			)
		}

		value: Lit
		copy(mem.ptr_to_bytes(&value), global.bytes)
		value.uint += u64(src.offset)
		return tcmeta(ctx, dst, value)
	}

	from, to := constant_base_type(src.type), constant_base_type(dst)
	value: Lit

	to_unsigned := in_set(to, UNSIGNED_TYPES)
	from_unsigned := in_set(from, UNSIGNED_TYPES)

	if from == to {
		value = src.lit
	} else if in_set(to, FLOAT_TYPES) {
		if in_set(from, FLOAT_TYPES) do value.float = src.float
		else if in_set(from, UNSIGNED_TYPES) do value.float = f64(src.uint)
		else do value.float = f64(src.int)
		if to == .F32 do value.float = f64(f32(value.float))
	} else if to == .Bool {
		value.int = i64(
			bool(in_set(from, FLOAT_TYPES) ? src.float != 0 : src.uint != 0),
		)
	} else if in_set(from, FLOAT_TYPES) {
		if to_unsigned do value.uint = u64(src.float)
		else do value.int = i64(src.float)
	} else {
		value = src.lit
	}

	return tcmeta(ctx, to, value)
}

constant_scalar_bytes :: proc(meta: ^Check_Meta, bytes: []u8) -> bool {
	if !meta.known || !valid_conversion_type(meta.type) do return false

	value := meta.int
	if meta.type == .F32 do value = i64(transmute(u32)f32(meta.float))

	data := transmute([8]u8)value
	assert(len(bytes) <= len(data))
	copy(bytes, data[:len(bytes)])

	return true
}

typecheck_directive :: proc(
	ctx: ^Gen_Ctx,
	prop: Ty_Propagation,
	node: ^ast.Call_Expr,
	directive: ^ast.Basic_Directive,
) -> (
	ty: ^Check_Meta,
) {
	switch directive.name {
	case "config":
		return typecheck_config(ctx, prop, node)
	case "assert":
		if len(node.args) < 1 || len(node.args) > 2 {
			return error(
				ctx,
				node,
				"#assert expects a condition and an optional message",
			)
		}

		cond := typecheck_eval_as(ctx, node.args[0], .Bool)

		message := "compile-time assertion failed"
		if len(node.args) == 2 {
			msg := typecheck_eval_as(ctx, node.args[1], .String)
			if msg.type == .String do message = constant_string(ctx, msg)
		}

		if cond.type == .Bool && cond.known && cond.int == 0 {
			return error(ctx, node, "%s", message)
		}
		return &VOID
	case "panic":
		args, ok := expect_args(ctx, node, node.args, 1, &ty)
		if !ok do return ty
		message := typecheck_eval_as(ctx, args[0], .String)
		if message.type != .String do return &INVALID
		return error(ctx, node, "%s", constant_string(ctx, message))
	case:
		return error(ctx, node, "unsupported directive #%s", directive.name)
	}
}

typecheck_block_constants :: proc(ctx: ^Gen_Ctx, stmts: []^ast.Stmt) {
	for stmt in stmts {
		decl := stmt.derived.(^ast.Value_Decl) or_continue
		if len(decl.names) == 0 || decl.is_mutable do continue
		if len(decl.names) != len(decl.values) {
			error(
				ctx,
				stmt,
				"expected %v values, found %v",
				len(decl.names),
				len(decl.values),
			)
			continue
		}

		for name, i in decl.names {
			ident := extract_var_ident(ctx, name) or_continue
			append(
				&ctx.scope,
				Variable {
					name = ident.name,
					type = .Invalid_Type,
					idx = new_clone(
						Decl {
							name = ident.name,
							ty = decl.type,
							value = decl.values[i],
							file = ctx.file_id,
						},
						ctx.types.allocator,
					),
					ident = ident,
				},
			)
		}
	}
}

expand_when_stmts :: proc(
	ctx: ^Gen_Ctx,
	stmts: []^ast.Stmt,
	result: ^[dynamic]^ast.Stmt,
) {
	for stmt in stmts {
		selected := stmt
		for {
			branch := selected.derived.(^ast.When_Stmt) or_break

			cond := typecheck_eval_as(ctx, branch.cond, .Bool)
			if cond.type != .Bool {
				selected = nil
				break
			}

			selected = cond.int != 0 ? branch.body : branch.else_stmt
			if selected == nil do break
		}
		if selected == nil do continue

		if selected != stmt {
			block := selected.derived.(^ast.Block_Stmt)
			typecheck_block_constants(ctx, block.stmts)
			expand_when_stmts(ctx, block.stmts, result)
		} else {
			append(result, stmt)
		}
	}
}
