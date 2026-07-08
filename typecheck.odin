package main

import "backend"
import "base:runtime"
import "core:fmt"
import "core:mem"
import "core:odin/ast"
import "core:odin/tokenizer"
import "core:strconv"
import "meta"

Lit :: union {
	Proc_ID,
}

Proc_ID :: distinct int

Type :: enum uintptr {
	Void,
	Bool,
	Int,
	I64,
	I32,
	I16,
	I8,
	Uint,
	U64,
	U32,
	U16,
	U8,
	String,
}

@(rodata)
TYPE_SIZES := [Type]int {
	.Void   = 0,
	.Bool   = 1,
	.Int    = 8,
	.I64    = 8,
	.I32    = 4,
	.I16    = 2,
	.I8     = 1,
	.Uint   = 8,
	.U64    = 8,
	.U32    = 4,
	.U16    = 2,
	.U8     = 1,
	.String = 16,
}

type_align :: proc(ty: Type) -> int {
	switch t in unpack_type(ty) {
	case Builtin:
		if ty == .String do return 8
		return TYPE_SIZES[ty]
	case Pointer:
		return 8
	case ^Struct:
		return t.align
	case ^Array:
		return type_align(t.elem)
	case ^Slice:
		return 8
	case ^Lit:
		panic("we should not be type type")
	case:
		panic("wuwut")
	}
}

array_elem_stride :: proc(elem: Type) -> int {
	return mem.align_forward_int(type_size(elem), type_align(elem))
}

type_size :: proc(ty: Type) -> int {
	switch t in unpack_type(ty) {
	case Builtin:
		return TYPE_SIZES[ty]
	case Pointer:
		return 8
	case ^Struct:
		return t.size
	case ^Array:
		return array_elem_stride(t.elem) * t.len
	case ^Slice:
		return 16
	case ^Lit:
		panic("we should not be type type")
	case:
		panic("wuwut")
	}
}

@(rodata)
TYPE_NAMES := [Type]string {
	.Void   = "void",
	.Bool   = "bool",
	.Int    = "int",
	.I64    = "i64",
	.I32    = "i32",
	.I16    = "i16",
	.I8     = "i8",
	.Uint   = "uint",
	.U64    = "u64",
	.U32    = "u32",
	.U16    = "u16",
	.U8     = "u8",
	.String = "string",
}

type_to_dt :: proc(ty: Type) -> backend.Node_Datatype {
	@(static)
	@(rodata)
	TYPE_TO_DT := [Type]backend.Node_Datatype {
		.Void   = .Void,
		.Bool   = .I8,
		.Int    = .I64,
		.I64    = .I64,
		.I32    = .I32,
		.I16    = .I16,
		.I8     = .I8,
		.Uint   = .I64,
		.U64    = .I64,
		.U32    = .I32,
		.U16    = .I16,
		.U8     = .I8,
		.String = .Void,
	}

	switch t in unpack_type(ty) {
	case Builtin:
		return TYPE_TO_DT[ty]
	case Pointer:
		return .I64
	case ^Lit, ^Struct, ^Array, ^Slice:
		return .Void
	case:
		panic("wuwut")
	}
}

UNSIGNED_TYPES :: bit_set[Type]{.Uint, .U64, .U32, .U16, .U8, .Bool}
SIGNED_TYPES :: bit_set[Type]{.Int, .I64, .I32, .I16, .I8}
INTEGER_TYPES :: UNSIGNED_TYPES | SIGNED_TYPES

Type_Kind :: enum uintptr {
	Builtin,
	Pointer,
	Struct,
	Array,
	Slice,
	Lit,
}

Raw_Type :: bit_field uintptr {
	data: uintptr   | 48,
	tag:  Type_Kind | 16,
}

Pointer :: distinct ^Type
Builtin :: distinct Type

Type_Data :: union #no_nil {
	Builtin,
	Pointer,
	^Struct,
	^Array,
	^Slice,
	^Lit,
}

Raw_Type_Data :: struct {
	data: uintptr,
	tag:  Type_Kind,
}

pack_type :: proc(typ: Type_Data) -> Type {
	raw := transmute(Raw_Type_Data)typ
	return Type(Raw_Type{tag = raw.tag, data = raw.data})
}

unpack_type :: proc(typ: Type) -> Type_Data {
	raw := Raw_Type(typ)
	return transmute(Type_Data)Raw_Type_Data{data = raw.data, tag = raw.tag}
}

intern_pointer :: proc(ctx: ^Gen_Ctx, ty: Type) -> Type {
	existing :=
		ctx.pointers[ty] or_else Pointer(new_clone(ty, ctx.types.allocator))
	ctx.pointers[ty] = existing
	return pack_type(existing)
}

intern_array :: proc(ctx: ^Gen_Ctx, elem: Type, length: int) -> Type {
	key := Array_Key{elem, length}
	existing, ok := ctx.arrays[key]
	if !ok {
		existing = new(Array, ctx.types.allocator)
		existing.elem = elem
		existing.len = length
		ctx.arrays[key] = existing
	}
	return pack_type(existing)
}

intern_slice :: proc(ctx: ^Gen_Ctx, elem: Type) -> Type {
	existing, ok := ctx.slices[elem]
	if !ok {
		existing = new(Slice, ctx.types.allocator)
		existing.elem = elem
		ctx.slices[elem] = existing
	}
	return pack_type(existing)
}

intern_lit :: proc(ctx: ^Gen_Ctx, lit: Lit) -> ^Lit {
	existing := ctx.lits[lit] or_else new_clone(lit, ctx.types.allocator)
	ctx.lits[lit] = existing
	return existing
}

emit_type :: proc(ctx: ^Gen_Ctx, expr: ^ast.Node) -> Type {
	if expr == nil do return .Void

	#partial switch d in expr.derived {
	case ^ast.Ident:
		for decl in ctx.file.decls {
			sdecl := decl.derived_stmt.(^ast.Value_Decl) or_continue
			if meta.src_of(ctx.file^, sdecl.names[0]) != d.name do continue

			#partial switch d in sdecl.values[0].derived {
			case ^ast.Struct_Type:
				key := Struct_Key{ctx.file_id, u32(decl.pos.offset)}
				structa, ok := ctx.structs[key]
				if ok do return pack_type(structa)

				structa = new(Struct, ctx.types.allocator)
				ctx.structs[key] = structa

				structa.fields = make(
					[]Struct_Field,
					len(d.fields.list),
					ctx.types.allocator,
				)
				for &field, i in structa.fields {
					ast_field := d.fields.list[i]
					assert(len(ast_field.names) == 1)
					field.name = ast_field.names[0].derived.(^ast.Ident).name
					field.ty = emit_type(ctx, ast_field.type)
					field.offset = mem.align_forward_int(
						structa.size,
						type_align(field.ty),
					)
					structa.size = field.offset + type_size(field.ty)
					structa.align = max(structa.align, type_align(field.ty))
				}
				structa.size = mem.align_forward_int(
					structa.size,
					structa.align,
				)
				return pack_type(structa)
			case:
				fmt.panicf("TODO: %#v", d)
			}
		}

		for name, kind in TYPE_NAMES {
			if name == d.name do return kind
		}

		fmt.panicf("TODO: %#v", expr.derived)
	case ^ast.Pointer_Type:
		return intern_pointer(ctx, emit_type(ctx, d.elem))
	case ^ast.Array_Type:
		elem := emit_type(ctx, d.elem)
		if d.len == nil {
			return intern_slice(ctx, elem)
		}
		len_node := d.len
		if len_ident, is_ident := len_node.derived.(^ast.Ident); is_ident {
			for decl in ctx.file.decls {
				sdecl := decl.derived_stmt.(^ast.Value_Decl) or_continue
				if meta.src_of(ctx.file^, sdecl.names[0]) != len_ident.name {
					continue
				}
				len_node = sdecl.values[0]
				break
			}
		}
		len_lit := len_node.derived.(^ast.Basic_Lit)
		assert(len_lit.tok.kind == .Integer)
		length, ok := strconv.parse_int(len_lit.tok.text)
		assert(ok)
		return intern_array(ctx, elem, length)
	case:
		fmt.panicf("TODO: %#v", expr.derived)
	}
}

Proc :: struct {
	name:      string,
	using sig: Signature,
	ast:       ^ast.Proc_Lit,
	out:       backend.Codegen_Output,
}

Signature :: struct {
	params: []Param,
	rets:   []Param,
}

Param :: struct {
	name: string,
	type: Type,
}

Variable :: struct {
	name:  string,
	idx:   union #no_nil {
		int,
		backend.Node_ID,
	},
	type:  Type,
	ident: ^ast.Expr,
	flags: Var_Flags,
}

Module :: struct {
	files: []ast.File,
}

Global_Ctx :: struct {
	modules: []Module,
}

Types :: struct {
	allocator: runtime.Allocator,
	procs:     [dynamic]Proc,
	scope:     [dynamic]Variable,
	pointers:  map[Type]Pointer,
	structs:   map[Struct_Key]^Struct,
	arrays:    map[Array_Key]^Array,
	slices:    map[Type]^Slice,
	lits:      map[Lit]^Lit,
	globals:   [dynamic]Global_Data,
}

Global_Data :: struct {
	bytes: []u8,
	align: int,
}

Array_Key :: struct {
	elem: Type,
	len:  int,
}

Array :: struct {
	elem: Type,
	len:  int,
}

Slice :: struct {
	elem: Type,
}

File_ID :: distinct u32

Struct_Key :: struct {
	file:   File_ID,
	offset: u32,
}

Struct :: struct {
	fields: []Struct_Field,
	size:   int,
	align:  int,
}

Struct_Field :: struct {
	name:   string,
	ty:     Type,
	offset: int,
}

typecheck :: proc(
	ctx: ^Gen_Ctx,
	prop: Ty_Propagation,
	node: ^ast.Node,
) -> (
	ty: Type,
) {
	if node == nil do return .Void

	defer {
		set_node_data(node, ty)
	}

	#partial switch d in node.derived {
	case ^ast.Block_Stmt:
		prev_scope_len := len(ctx.scope)
		for stmt in d.stmts {
			typecheck(ctx, {}, stmt)
		}
		for var in ctx.scope[prev_scope_len:] {
			set_node_data(var.ident, var.flags)
		}
		resize(&ctx.scope, prev_scope_len)
	case ^ast.Value_Decl:
		assert(len(d.names) == len(d.values))

		inferred_ty := emit_type(ctx, d.type)

		for i in 0 ..< len(d.names) {
			name := meta.src_of(ctx.file^, d.names[i])
			value_ty := typecheck(
				ctx,
				{inferred_ty = inferred_ty},
				d.values[i],
			)
			if inferred_ty != .Void {
				assert(value_ty == inferred_ty)
			}
			set_node_data(d.names[i], Var_Flags{})
			append(
				&ctx.scope,
				Variable{name = name, type = value_ty, ident = d.names[i]},
			)
		}
	case ^ast.Basic_Lit:
		#partial switch d.tok.kind {
		case .Integer, .Rune:
			assert(
				prop.inferred_ty == .Void || prop.inferred_ty in INTEGER_TYPES,
			)
			return prop.inferred_ty != .Void ? prop.inferred_ty : .Int
		case .String:
			return .String
		case:
			fmt.panicf("TODO: missing literal typecheck %v", d)
		}
	case ^ast.Comp_Lit:
		inferred_ty := emit_type(ctx, d.type)
		if inferred_ty == .Void do inferred_ty = prop.inferred_ty

		#partial switch t in unpack_type(inferred_ty) {
		case ^Struct:
			for elem, i in d.elems {
				#partial switch e in elem.derived {
				case ^ast.Field_Value:
					name := meta.src_of(ctx.file^, e.field)
					for &field in t.fields {
						if field.name == name {
							set_node_data(e.field, field.offset)
							fty := typecheck(
								ctx,
								{inferred_ty = field.ty},
								e.value,
							)
							assert(fty == field.ty)
						}
					}
				case:
					field := t.fields[i]
					fty := typecheck(ctx, {inferred_ty = field.ty}, elem)
					assert(fty == field.ty)
				}
			}

			return inferred_ty
		case ^Array:
			for elem in d.elems {
				ety := typecheck(ctx, {inferred_ty = t.elem}, elem)
				assert(ety == t.elem)
			}
			return inferred_ty
		case:
			fmt.panicf("TODO: %v %#v", unpack_type(inferred_ty), d)
		}
	case ^ast.Index_Expr:
		base := typecheck(ctx, {}, d.expr)
		typecheck(ctx, {inferred_ty = .Int}, d.index)
		#partial switch t in unpack_type(base) {
		case ^Array:
			return t.elem
		case ^Slice:
			return t.elem
		case Builtin:
			assert(t == .String)
			return .U8
		case:
			fmt.panicf("TODO: %#v", t)
		}
	case ^ast.Slice_Expr:
		base := typecheck(ctx, {}, d.expr)
		typecheck(ctx, {inferred_ty = .Int}, d.low)
		typecheck(ctx, {inferred_ty = .Int}, d.high)
		#partial switch t in unpack_type(base) {
		case ^Array:
			return intern_slice(ctx, t.elem)
		case ^Slice:
			return base
		case Builtin:
			assert(t == .String)
			return .String
		case:
			fmt.panicf("TODO: %#v", t)
		}
	case ^ast.Selector_Expr:
		base := typecheck(ctx, {}, d.expr)

		#partial switch f in d.field.derived {
		case ^ast.Ident:
			if p, ok := unpack_type(base).(Pointer); ok do base = p^

			#partial switch t in unpack_type(base) {
			case ^Struct:
				for &field in t.fields {
					if field.name == f.name {
						set_node_data(d.field, field.offset)
						return field.ty
					}
				}
			case:
				fmt.panicf("TODO: %#v", t)
			}
		case:
			fmt.panicf("TODO: %#v", d.field.derived)
		}
	case ^ast.Binary_Expr:
		lhs_ty := typecheck(ctx, prop, d.left)
		inferred_ty := lhs_ty
		if d.op.kind == .Shl || d.op.kind == .Shr {
			inferred_ty = .Uint
		}
		rhs_ty := typecheck(ctx, {inferred_ty = inferred_ty}, d.right)
		assert(inferred_ty == rhs_ty)

		if .B_Comparison_Begin < d.op.kind && d.op.kind < .B_Comparison_End {
			return .Bool
		}

		return lhs_ty
	case ^ast.Unary_Expr:
		#partial switch d.op.kind {
		case .And:
			inferred_ty := Type.Void
			if ptr, ok := unpack_type(prop.inferred_ty).(Pointer); ok {
				inferred_ty = ptr^
			}

			inner_ty := typecheck(
				ctx,
				{inferred_ty = inferred_ty, referencing = true},
				d.expr,
			)
			if inferred_ty != .Void {
				assert(inferred_ty == inner_ty)
			}
			return intern_pointer(ctx, inner_ty)
		case .Not:
			inner_ty := typecheck(ctx, {}, d.expr)
			assert(inner_ty == .Bool)
			return .Bool
		case .Sub, .Xor:
			return typecheck(ctx, prop, d.expr)
		case:
			fmt.panicf("TODO: %#v", node.derived)
		}
	case ^ast.Deref_Expr:
		inferred_ty := Type.Void
		if prop.inferred_ty != .Void {
			inferred_ty = intern_pointer(ctx, prop.inferred_ty)
		}

		ty = typecheck(ctx, {inferred_ty = inferred_ty}, d.expr)
		return unpack_type(ty).(Pointer)^
	case ^ast.Expr_Stmt:
		return typecheck(ctx, {}, d.expr)
	case ^ast.If_Stmt:
		cond_ty := typecheck(ctx, {}, d.cond)
		assert(cond_ty == .Bool)
		typecheck(ctx, {}, d.body)
		typecheck(ctx, {}, d.else_stmt)
		return {}
	case ^ast.For_Stmt:
		assert(d.init == nil)
		assert(d.cond == nil)
		assert(d.post == nil)

		typecheck(ctx, {}, d.body)
	case ^ast.Branch_Stmt:
		return {}
	case ^ast.Paren_Expr:
		return typecheck(ctx, prop, d.expr)
	case ^ast.Ident:
		name := d.name
		#reverse for &var in ctx.scope {
			if var.name == name {
				if prop.referencing {
					var.flags |= {.Referenced}
				}
				return var.type
			}
		}

		for p, i in ctx.procs {
			if p.name == name {
				return pack_type(intern_lit(ctx, Proc_ID(i)))
			}
		}

		if name == "false" || name == "true" {
			return .Bool
		}

		return emit_type(ctx, node)
	case ^ast.Call_Expr:
		if id, ok := d.expr.derived.(^ast.Ident); ok && id.name == "len" {
			assert(len(d.args) == 1)
			arg_ty := typecheck(ctx, {}, d.args[0])
			#partial switch t in unpack_type(arg_ty) {
			case ^Array, ^Slice:
			case Builtin:
				assert(t == .String)
			case:
				fmt.panicf("TODO: len of %#v", t)
			}
			return .Int
		}

		callee := typecheck(ctx, {}, d.expr)

		sig: Signature
		#partial switch v in unpack_type(callee) {
		case ^Lit:
			prc_id := v.(Proc_ID)
			prc := &ctx.procs[prc_id]
			sig = prc.sig
		case Builtin:
			assert(v != .Void)
			assert(len(d.args) == 1)
			typecheck(ctx, {}, d.args[0])
			return callee
		case:
			fmt.panicf("TODO: %v %#v", v, d)
		}

		assert(len(sig.params) == len(d.args))
		for param, i in sig.params {
			pty := typecheck(ctx, {inferred_ty = param.type}, d.args[i])
			assert(pty == param.type)
		}

		if len(sig.rets) == 0 do return .Void
		assert(len(sig.rets) == 1)
		return sig.rets[0].type
	case ^ast.Return_Stmt:
		prc := &ctx.procs[ctx.prc]
		assert(len(d.results) == len(prc.rets))
		for i in 0 ..< len(d.results) {
			typecheck(ctx, {inferred_ty = prc.rets[i].type}, d.results[i])
		}
	case ^ast.Assign_Stmt:
		assert(len(d.lhs) == len(d.rhs))
		for i in 0 ..< len(d.lhs) {
			lhs_ty := typecheck(ctx, {}, d.lhs[i])
			typecheck(ctx, {inferred_ty = lhs_ty}, d.rhs[i])
		}
	case:
		fmt.panicf("TODO: %#v", node.derived)
	}

	return .Void
}

Var_Flag :: enum uintptr {
	Referenced,
}

Var_Flags :: bit_set[Var_Flag;uintptr]

get_node_type :: proc(node: ^ast.Node) -> Type {
	return get_node_data(node, Type)
}

get_node_vflags :: proc(node: ^ast.Node) -> Var_Flags {
	_ = node.derived.(^ast.Ident)
	return get_node_data(node, Var_Flags)
}

get_node_data :: proc(node: ^ast.Node, $T: typeid) -> T {
	return transmute(T)raw_data(node.end.file)
}

set_node_data :: proc(node: ^ast.Node, value: $T) {
	raw := (^runtime.Raw_Slice)(&node.end.file)
	raw.data = transmute(rawptr)value
	raw.len = 0
}

is_of :: proc(vl: Type, $K: typeid) -> bool {
	_, ok := unpack_type(vl).(K)
	return ok
}
