package typecheck

import "base:intrinsics"
import "core:mem"
import "core:odin/ast"
import "core:odin/tokenizer"
import "core:slice"
import "core:strconv"

constant_base_type :: proc(ty: Type) -> Type {
	if e, ok := unpack_type(ty).(^Enum); ok do return strip_named(e.backing)
	return strip_named(ty)
}

// constant_int extends an integer constant to the full width, a constant that
// committed to a narrower type only has its low bits kept meaningful
constant_int :: proc(meta: ^Check_Meta) -> i128 {
	base := constant_base_type(meta.type)
	if meta.untyped || !in_set(base, INTEGER_TYPES) || in_set(base, WIDE_TYPES) {
		return meta.int
	}
	shift := uint(128 - type_size(base) * 8)
	if in_set(base, SIGNED_TYPES) do return meta.int << shift >> shift
	return i128(meta.uint << shift >> shift)
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

constant_binary :: proc(
	ctx: ^Gen_Ctx,
	node: ^ast.Binary_Expr,
	lhs, rhs: ^Check_Meta,
) -> ^Check_Meta {
	op := node.op.kind
	comparison := .B_Comparison_Begin < op && op < .B_Comparison_End
	base := constant_base_type(lhs.type)
	// untyped constants did not commit to a width yet, so they are folded at
	// the widest one, which lets them still become a 128-bit value
	wide := in_set(base, WIDE_TYPES) || lhs.untyped && rhs.untyped
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
		case is_of(base, ^Bit_Set):
			sub, super := lhs.uint, rhs.uint
			if op == .Gt || op == .Gt_Eq do sub, super = super, sub
			if op == .Cmp_Eq || op == .Not_Eq {
				value = constant_compare(lhs.uint, rhs.uint, op)
			} else {
				value =
					sub &~ super == 0 && (op == .Lt_Eq || op == .Gt_Eq || sub != super)
			}
		case is_of(base, ^Bit_Field):
			value = constant_compare(lhs.uint, rhs.uint, op)
		case in_set(base, FLOAT_TYPES):
			value = constant_compare(lhs.float, rhs.float, op)
		case in_set(base, UNSIGNED_TYPES) && wide:
			value = constant_compare(lhs.uint, rhs.uint, op)
		case in_set(base, SIGNED_TYPES) && wide:
			value = constant_compare(lhs.int, rhs.int, op)
		case in_set(base, UNSIGNED_TYPES):
			value = constant_compare(u64(lhs.uint), u64(rhs.uint), op)
		case in_set(base, SIGNED_TYPES):
			value = constant_compare(i64(lhs.int), i64(rhs.int), op)
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
		res := tcmeta(ctx, .Bool, {int = i128(value)})
		res.untyped = true
		return res
	}

	result := new_clone(lhs^, ctx.types.allocator)
	result.untyped = lhs.untyped && rhs.untyped
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

	if is_of(base, ^Bit_Set) {
		if op == .Add do op = .Or
		if op == .Sub do op = .And_Not
	} else if !in_set(base, INTEGER_TYPES) {
		return error(
			ctx,
			node,
			"constant operation not supported for %v",
			lhs.type,
		)
	}

	signed := in_set(base, SIGNED_TYPES)
	if in_set(constant_base_type(rhs.type), SIGNED_TYPES) &&
	   (op == .Shl || op == .Shr) &&
	   constant_int(rhs) < 0 {
		return error(ctx, node.right, "shift count must be non negative")
	}

	err: string
	if wide {
		result.int, err = constant_integer(op, constant_int(lhs), constant_int(rhs), signed)
	} else {
		value: i64
		value, err = constant_integer(op, i64(lhs.int), i64(rhs.int), signed)
		result.int = signed ? i128(value) : i128(u64(value))
	}

	switch err {
	case "":
	case "division by zero":
		return error(ctx, node.right, err)
	case "unsupported":
		return error(
			ctx,
			node,
			"constant operation not supported: %v",
			node.op.text,
		)
	case:
		return error(ctx, node, err)
	}
	return result

	constant_integer :: proc(
		op: tokenizer.Token_Kind,
		lhs, rhs: $S,
		signed: bool,
	) -> (
		res: S,
		err: string,
	) {
		U :: intrinsics.type_integer_to_unsigned(S)
		BITS :: size_of(S) * 8
		ulhs, urhs := U(lhs), U(rhs)

		#partial switch op {
		case .Add:
			return S(ulhs + urhs), ""
		case .Sub:
			return S(ulhs - urhs), ""
		case .Mul:
			return S(ulhs * urhs), ""
		case .Quo, .Mod, .Mod_Mod:
			if rhs == 0 do return 0, "division by zero"
			if !signed do return S(op == .Quo ? ulhs / urhs : ulhs % urhs), ""
			if lhs == min(S) && rhs == -1 {
				if op == .Quo do return 0, "constant integer overflow"
				return 0, ""
			}
			if op == .Quo do return lhs / rhs, ""
			res = lhs % rhs
			if op == .Mod_Mod && res != 0 && (res < 0) != (rhs < 0) do res += rhs
			return res, ""
		case .And:
			return lhs & rhs, ""
		case .Or:
			return lhs | rhs, ""
		case .Xor:
			return lhs ~ rhs, ""
		case .And_Not:
			return lhs &~ rhs, ""
		case .Shl:
			return urhs < BITS ? S(ulhs << urhs) : 0, ""
		case .Shr:
			if signed do return urhs < BITS ? lhs >> urhs : (lhs < 0 ? -1 : 0), ""
			return urhs < BITS ? S(ulhs >> urhs) : 0, ""
		}
		return 0, "unsupported"
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

}

valid_conversion_type :: proc(ty: Type) -> bool {
	return in_set(constant_base_type(ty), NUMBER_TYPES) || is_data_pointer(ty)
}

// identical_core tells whether a value converts by reinterpreting it as is,
// like in odin the nominal layers are only seen through at the outside, and
// struct and union bodies match by their shape
identical_core :: proc(a, b: Type) -> bool {
	a, b := strip_named(a), strip_named(b)
	if a == b do return true

	#partial switch x in unpack_type(a) {
	case ^Array:
		y := unpack_type(b).(^Array) or_return
		return x.len == y.len && identical_core(x.elem, y.elem)
	case ^Simd:
		y := unpack_type(b).(^Simd) or_return
		return x.len == y.len && identical_core(x.elem, y.elem)
	case ^Struct:
		y := unpack_type(b).(^Struct) or_return
		type_ensure_layout(a)
		type_ensure_layout(b)
		if len(x.fields) != len(y.fields) || x.size != y.size do return false
		for f, i in x.fields {
			g := y.fields[i]
			if f.name != g.name || f.ty != g.ty || f.offset != g.offset || f.tag != g.tag {
				return false
			}
		}
		return x.align == y.align && x.raw_union == y.raw_union && x.packed == y.packed
	case ^Union:
		y := unpack_type(b).(^Union) or_return
		return slice.equal(x.variants, y.variants) && x.tag_ty == y.tag_ty
	}
	return false
}

typecheck_conversion :: proc(
	ctx: ^Gen_Ctx,
	node: ^ast.Node,
	dst: Type,
	src: ^Check_Meta,
	strict := false,
) -> ^Check_Meta {
	if src.type == .Invalid_Type || dst == .Invalid_Type do return &INVALID

	if identical_core(src.type, dst) {
		if !src.known do return tmeta(ctx, dst)
		res := new_clone(src^, ctx.types.allocator)
		res.type = dst
		res.untyped = false
		return res
	}

	// odin converts a bit_field like the integer backing it
	if bf, ok := unpack_type(src.type).(^Bit_Field); ok {
		backing := new_clone(src^, ctx.types.allocator)
		backing.type = bf.backing
		if src.known && in_set(bf.backing, SIGNED_TYPES) {
			shift := uint(128 - type_size(bf.backing) * 8)
			backing.int = (backing.int << shift) >> shift
		}
		return typecheck_conversion(ctx, node, dst, backing, strict)
	}
	if bf, ok := unpack_type(dst).(^Bit_Field); ok {
		res := typecheck_conversion(ctx, node, bf.backing, src, strict)
		if res.type == .Invalid_Type do return res

		res = new_clone(res^, ctx.types.allocator)
		res.type = dst
		if res.known && type_size(dst) < 8 {
			res.uint &= u128(1) << uint(type_size(dst) * 8) - 1
		}
		return res
	}

	if !valid_conversion_type(src.type) || !valid_conversion_type(dst) {
		return error(
			ctx,
			node,
			"unsupported conversion from %v to %v",
			src.type,
			dst,
		)
	}

	if !src.known {
		if call, ok := float_libcall(dst, src.type); ok {
			require_libcall(ctx, node, call)
		}
		return tmeta(ctx, dst)
	}

	if is_data_pointer(dst) {
		if is_data_pointer(src.type) do return tcmeta(ctx, dst, src.lit)
		return global_pointer(ctx, dst, u64(src.uint))
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
		value.uint += u128(src.offset)
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
		else if from_unsigned do value.float = f64(u128(constant_int(src)))
		else do value.float = f64(constant_int(src))
		if to == .F32 do value.float = f64(f32(value.float))
	} else if to == .Bool {
		value.int = i128(
			bool(in_set(from, FLOAT_TYPES) ? src.float != 0 : constant_int(src) != 0),
		)
	} else if in_set(from, FLOAT_TYPES) {
		switch {
		case to == .U128:
			value.uint = u128(src.float)
		case to == .I128:
			value.int = i128(src.float)
		case to_unsigned:
			value.uint = u128(u64(src.float))
		case:
			value.int = i128(i64(src.float))
		}
	} else if in_set(to, WIDE_TYPES) {
		value.int = constant_int(src)
	} else {
		value = src.lit
	}

	return tcmeta(ctx, dst, value)
}

constant_scalar_bytes :: proc(meta: ^Check_Meta, bytes: []u8) -> bool {
	if !meta.known || !valid_conversion_type(meta.type) do return false

	value := meta.int
	if strip_named(meta.type) == .F32 do value = i128(transmute(u32)f32(meta.float))

	data := transmute([16]u8)value
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
							parent = ctx.prc_id,
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
