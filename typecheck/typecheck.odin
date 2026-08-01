package typecheck

import "../backend"
import "../backend/builder"
import "../vendored/gam/util/arna"
import "base:intrinsics"
import "base:runtime"
import "core:fmt"
import "core:hash"
import "core:io"
import "core:math"
import "core:mem"
import "core:odin/ast"
import "core:odin/tokenizer"
import "core:reflect"
import "core:slice"
import "core:strconv"
import "core:strings"

Call :: backend.Call
Node_ID :: backend.Node_ID
Call_Conv :: backend.Call_Conv

MODULE_INTRINSICS :: 0

Ty_Propagation :: struct {
	inferred_ty: Type,
	referencing: bool,
	key:         Maybe(Decl_Key),
}

Mems :: struct {
	graph:    arna.Allocator,
	regalloc: arna.Allocator,
	scratch:  arna.Allocator,
	code:     arna.Allocator,
	reloc:    arna.Allocator,
	sloc:     arna.Allocator,
	cfi:      arna.Allocator,
	type:     arna.Allocator,
}

Target :: struct {
	name: string,
	cc:   ^Call_Conv,
	spec: ^backend.Node_Spec,
}

Gen_Ctx :: struct {
	using global: ^Global_Ctx,
	using types:  ^Types,
	using graph:  backend.Graph,
	node_scope:   Node_ID,
	mem_slot:     int,
	loop:         ^Loop_State,
	file:         ^ast.File,
	file_id:      File_ID,
	module:       Module_ID,
	prc:          Proc_ID,
	ret_ptrs:     []Node_ID,
	poly_types:   #soa[dynamic]Poly_Entry,
	slocs:        map[backend.Sloc]backend.D_Node_ID,
	eval_depth:   int,
	error_cnt:    int,
	errors:       io.Writer,
}

Poly_Entry :: struct {
	name: string,
	meta: Check_Meta,
}

Loop_Control :: enum int {
	Break,
	Continue,
}

Loop_State :: struct {
	parent:       ^Loop_State,
	label:        string,
	using bstate: builder.Loop_State,
}

Lit :: struct #raw_union {
	procid:    Proc_ID,
	module:    Module_ID,
	typeida:   Type,
	intrinsic: Intrinsic,
	int:       i64,
	rune:      rune,
	float:     f64,
	string:    ^string,
}

Check_Meta :: struct {
	type:      Type,
	known:     bool,
	using lit: Lit,
}

Ident_Meta_Kind :: enum int {
	Local,
	Poly,
	Module,
	Decl,
	Const,
	Discard,
	Builtin,
	Nil,
}

Ident_Meta :: struct {
	kind:    Ident_Meta_Kind,
	using _: struct #raw_union {
		index: int,
		decl:  ^Decl,
		value: i64,
	},
}

Proc_ID :: distinct int

Type :: enum uintptr {
	Void,
	Invalid_Type,
	Typeid,
	Intrinsic,
	Module,
	Bool,
	I8,
	I16,
	I32,
	I64,
	Int,
	U8,
	U16,
	U32,
	U64,
	Uint,
	Uintptr,
	Rawptr,
	String,
	F32,
	F64,
}

@(rodata)
TYPE_SIZES := #partial [Type]int {
	.Void    = 0,
	.Typeid  = 8,
	.Bool    = 1,
	.Int     = 8,
	.I64     = 8,
	.I32     = 4,
	.I16     = 2,
	.I8      = 1,
	.Uint    = 8,
	.U64     = 8,
	.U32     = 4,
	.U16     = 2,
	.U8      = 1,
	.Uintptr = 8,
	.Rawptr  = 8,
	.String  = 16,
	.F32     = 4,
	.F64     = 8,
}

// error reports `msg` at `node` and yields the poison meta, so that callers can
// simply `return error(...)` and let the invalid type flow through the rest of
// the check. Any diagnostic mentioning an already poisoned type is a follow up
// of an earlier one and is dropped, which is what keeps the recovery quiet.
error :: proc(
	ctx: ^Gen_Ctx,
	node: ^ast.Node,
	msg: string,
	args: ..any,
) -> ^Check_Meta {
	for arg in args {
		if ty, ok := arg.(Type); ok && ty == .Invalid_Type do return &INVALID
	}

	ctx.error_cnt += 1
	pos := node.pos
	fmt.wprintf(ctx.errors, "%s(%d:%d): ", pos.file, pos.line, pos.column)
	fmt.wprintf(ctx.errors, msg, ..args)
	fmt.wprintf(ctx.errors, "\n")
	return &INVALID
}

assignable :: proc(want, got: Type) -> bool {
	if want == got do return true
	if want == .Void || want == .Invalid_Type || got == .Invalid_Type do return true
	if u, ok := unpack_type(want).(^Union); ok {
		_, found := union_variant_index(u, got)
		return found
	}
	return false
}

expect :: proc(
	ctx: ^Gen_Ctx,
	node: ^ast.Node,
	got: ^Check_Meta,
	want: Type,
) -> ^Check_Meta {
	if node == nil || assignable(want, got.type) do return got
	return error(ctx, node, "expected %v, found %v", want, got.type)
}

typecheck_as :: proc(
	ctx: ^Gen_Ctx,
	want: Type,
	node: ^ast.Node,
) -> ^Check_Meta {
	return expect(ctx, node, typecheck(ctx, {inferred_ty = want}, node), want)
}

// unwrap_type is the recovering counterpart of `unpack_type(ty).(T)`: on a
// mismatch it reports `msg` (which receives the offending type) and the caller
// bails out with the poison meta.
unwrap_type :: proc(
	ctx: ^Gen_Ctx,
	node: ^ast.Node,
	ty: Type,
	$T: typeid,
	msg: string,
) -> (
	res: T,
	err: ^Check_Meta,
) {
	ok: bool
	res, ok = unpack_type(ty).(T)
	if !ok do err = error(ctx, node, msg, ty)
	return
}

type_align :: proc(ty: Type) -> int {
	#partial switch t in unpack_type(ty) {
	case ^Proc_Type, Pointer, Multi_Pointer:
		return 8
	case ^Struct:
		return t.align
	case ^Array:
		return type_align(t.elem)
	case ^Slice:
		return 8
	case ^Enum:
		return type_align(t.backing)
	case ^Union:
		return t.align
	case ^Simd:
		return type_size(t.elem) * t.len
	}
	if ty == .String do return 8
	// a poisoned type still gets laid out, and a 0 alignment would trip the
	// alignment math
	if ty == .Invalid_Type do return 1
	return TYPE_SIZES[ty]
}

const_eval_int :: proc(node: ^ast.Expr) -> (value: i64, ok: bool) {
	#partial switch d in node.derived {
	case ^ast.Basic_Lit:
		if d.tok.kind != .Integer do return 0, false
		return i64(strconv.parse_u64(d.tok.text) or_return), true
	case ^ast.Unary_Expr:
		if d.op.text != "-" do return 0, false
		inner := const_eval_int(d.expr) or_return
		return -inner, true
	case ^ast.Binary_Expr:
		lhs, rhs :=
			const_eval_int(d.left) or_return, const_eval_int(d.right) or_return
		#partial switch d.op.kind {
		case .Mul:
			return lhs * rhs, true
		}
	case ^ast.Paren_Expr:
		return const_eval_int(d.expr)
	}
	return 0, false
}

type_size :: proc(ty: Type) -> int {
	#partial switch t in unpack_type(ty) {
	case ^Proc_Type, Pointer, Multi_Pointer:
		return 8
	case ^Struct:
		return t.size
	case ^Array:
		return type_size(t.elem) * t.len
	case ^Slice:
		return 16
	case ^Enum:
		return type_size(t.backing)
	case ^Union:
		return t.size
	case ^Simd:
		return type_size(t.elem) * t.len
	}
	return TYPE_SIZES[ty]
}

@(rodata)
TYPE_NAMES := #partial [Type]string {
	.Void         = "void",
	.Invalid_Type = "invalid type",
	.Typeid       = "typeid",
	.Bool         = "bool",
	.Int          = "int",
	.I64          = "i64",
	.I32          = "i32",
	.I16          = "i16",
	.I8           = "i8",
	.Uint         = "uint",
	.U64          = "u64",
	.U32          = "u32",
	.U16          = "u16",
	.U8           = "u8",
	.Uintptr      = "uintptr",
	.Rawptr       = "rawptr",
	.String       = "string",
	.F32          = "f32",
	.F64          = "f64",
}

type_to_dt :: proc(ty: Type) -> backend.Node_Datatype {
	@(static)
	@(rodata)
	TYPE_TO_DT := #partial [Type]backend.Node_Datatype {
		.Void    = .Void,
		.Typeid  = .I64,
		.Bool    = .I8,
		.Int     = .I64,
		.I64     = .I64,
		.I32     = .I32,
		.I16     = .I16,
		.I8      = .I8,
		.Uint    = .I64,
		.U64     = .I64,
		.U32     = .I32,
		.U16     = .I16,
		.U8      = .I8,
		.Uintptr = .I64,
		.Rawptr  = .I64,
		.String  = .Void,
		.F32     = .F32,
		.F64     = .F64,
	}

	#partial switch t in unpack_type(ty) {
	case ^Proc_Type, Pointer, Multi_Pointer:
		return .I64
	case ^Enum:
		return type_to_dt(t.backing)
	case ^Struct, ^Array, ^Slice, ^Union:
		return .Void
	case ^Simd:
		return simd_dt(type_size(t.elem) * t.len)
	}
	return TYPE_TO_DT[ty]
}

// a Type doubles as a tagged pointer for the composite types, so only the
// small enum members can ever be inside one of the sets below
in_set :: proc(ty: Type, set: bit_set[Type]) -> bool {
	return ty <= .F64 && ty in set
}

UNSIGNED_TYPES :: bit_set[Type]{.Uint, .U64, .U32, .U16, .U8, .Bool, .Uintptr}
SIGNED_TYPES :: bit_set[Type]{.Int, .I64, .I32, .I16, .I8}
INTEGER_TYPES :: UNSIGNED_TYPES | SIGNED_TYPES
FLOAT_TYPES :: bit_set[Type]{.F32, .F64}

Raw_Type :: bit_field u64 {
	tag:  int     | 16,
	data: uintptr | min(48, size_of(uintptr) * 8),
}

Multi_Pointer :: distinct ^Type
Pointer :: distinct ^Type
Builtin :: distinct Type

Void_Type :: struct {}
Invalid_Type :: struct {}
Typeid_Type :: struct {}
Intrinsic_Type :: struct {}
Module_Type :: struct {}
Bool_Type :: struct {}
Int_Type :: struct {}
I64_Type :: struct {}
I32_Type :: struct {}
I16_Type :: struct {}
I8_Type :: struct {}
Uint_Type :: struct {}
U64_Type :: struct {}
U32_Type :: struct {}
U16_Type :: struct {}
U8_Type :: struct {}
Uintptr_Type :: struct {}
Rawptr_Type :: struct {}
String_Type :: struct {}
F32_Type :: struct {}
F64_Type :: struct {}

Type_Data :: union #no_nil {
	Void_Type,
	Invalid_Type,
	Typeid_Type,
	Intrinsic_Type,
	Module_Type,
	Bool_Type,
	Int_Type,
	I64_Type,
	I32_Type,
	I16_Type,
	I8_Type,
	Uint_Type,
	U64_Type,
	U32_Type,
	U16_Type,
	U8_Type,
	Uintptr_Type,
	Rawptr_Type,
	String_Type,
	F32_Type,
	F64_Type,
	Pointer,
	Multi_Pointer,
	^Proc_Type,
	^Struct,
	^Array,
	^Slice,
	^Enum,
	^Union,
	^Simd,
}

Raw_Type_Data :: struct {
	data: uintptr,
	tag:  int,
}

init_type_fmt :: proc() {
	fmt.register_user_formatter(
		Type,
		proc(fi: ^fmt.Info, value: any, r: rune) -> bool {
			type_display(fi.writer, value.(Type))
			return true
		},
	)

	fmt.register_user_formatter(
		Type_Data,
		proc(fi: ^fmt.Info, value: any, r: rune) -> bool {
			type_display(fi.writer, pack_type(value.(Type_Data)))
			return true
		},
	)
}

type_display :: proc(w: io.Writer, ty: Type) {
	#partial switch t in unpack_type(ty) {
	case Pointer:
		io.write_rune(w, '^')
		type_display(w, (^Type)(t)^)
	case Multi_Pointer:
		fmt.wprint(w, "[^]")
		type_display(w, (^Type)(t)^)
	case ^Slice:
		fmt.wprint(w, "[]")
		type_display(w, t.elem)
	case ^Array:
		fmt.wprintf(w, "[%v]", t.len)
		type_display(w, t.elem)
	case ^Simd:
		fmt.wprintf(w, "#simd[%v]", t.len)
		type_display(w, t.elem)
	case ^Struct:
		io.write_string(w, "struct {")
		for field, i in t.fields {
			if i != 0 do io.write_string(w, ", ")
			fmt.wprintf(w, "%v: ", field.name)
			type_display(w, field.ty)
		}
		io.write_rune(w, '}')
	case ^Enum:
		io.write_string(w, "enum {")
		for v, i in t.variants {
			if i != 0 do io.write_string(w, ", ")
			fmt.wprintf(w, "%v = %v", v.name, v.value)
		}
		io.write_rune(w, '}')
	case ^Union:
		io.write_string(w, "union {")
		for v, i in t.variants {
			if i != 0 do io.write_string(w, ", ")
			type_display(w, v)
		}
		io.write_rune(w, '}')
	case ^Proc_Type:
		io.write_string(w, "proc(")
		for a, i in t.params {
			if i != 0 do io.write_string(w, ", ")
			type_display(w, a)
		}
		io.write_rune(w, ')')

		if len(t.rets) > 0 {
			io.write_string(w, " -> ")
			for a, i in t.rets {
				if i != 0 do io.write_string(w, ", ")
				type_display(w, a)
			}
		}
	case:
		assert(ty <= .F64)
		fmt.wprint(w, TYPE_NAMES[ty])
	}
}

pack_type :: proc(typ: Type_Data) -> Type {
	raw := transmute(Raw_Type_Data)typ
	return Type(Raw_Type{tag = raw.tag, data = raw.data})
}

unpack_type :: proc(typ: Type) -> Type_Data {
	raw := Raw_Type(typ)
	return(
		transmute(Type_Data)Raw_Type_Data {
			data = raw.data,
			tag = int(raw.tag),
		} \
	)
}

intern_type_slice :: proc(ctx: ^Gen_Ctx, tys: []Type) -> []Type {
	key := string(mem.slice_data_cast([]u8, tys))
	existing :=
		ctx.type_slices[key] or_else slice.clone(tys, ctx.types.allocator)
	ctx.type_slices[string(mem.slice_data_cast([]u8, existing))] = existing
	return existing
}

intern_proc_type :: proc(ctx: ^Gen_Ctx, ty: ^Proc_Type) -> ^Proc_Type {
	key := string(mem.ptr_to_bytes(ty))
	existing := ctx.proc_types[key] or_else new_clone(ty^, ctx.types.allocator)
	ctx.proc_types[string(mem.ptr_to_bytes(existing))] = existing
	return existing
}

intern_multi_pointer :: proc(ctx: ^Gen_Ctx, ty: Type) -> Type {
	existing :=
		ctx.multi_pointers[ty] or_else Multi_Pointer(
			new_clone(ty, ctx.types.allocator),
		)
	ctx.multi_pointers[ty] = existing
	return pack_type(existing)
}

intern_pointer :: proc(ctx: ^Gen_Ctx, ty: Type) -> Type {
	existing :=
		ctx.pointers[ty] or_else Pointer(new_clone(ty, ctx.types.allocator))
	ctx.pointers[ty] = existing
	return pack_type(existing)
}

intern_array :: proc(ctx: ^Gen_Ctx, elem: Type, length: int) -> Type {
	key := Array{elem, length}
	existing := ctx.arrays[key] or_else new_clone(key, ctx.types.allocator)
	ctx.arrays[key] = existing
	return pack_type(existing)
}

intern_slice :: proc(ctx: ^Gen_Ctx, elem: Type) -> Type {
	key := Slice{elem}
	existing := ctx.slices[key] or_else new_clone(key, ctx.types.allocator)
	ctx.slices[key] = existing
	return pack_type(existing)
}

intern_simd :: proc(ctx: ^Gen_Ctx, elem: Type, length: int) -> Type {
	fmt.assertf(math.is_power_of_two(length), "%v", length)
	key := Simd{elem, length}
	existing := ctx.simds[key] or_else new_clone(key, ctx.types.allocator)
	ctx.simds[key] = existing
	return pack_type(existing)
}

simd_dt :: proc(size: int) -> backend.Node_Datatype {
	fmt.assertf(math.is_power_of_two(size), "%v", size)
	fmt.assertf(16 <= size, "%v", size)
	assert(size <= 64)
	return backend.Node_Datatype(
		int(backend.Node_Datatype.V128) +
		intrinsics.count_trailing_zeros(size) -
		intrinsics.count_trailing_zeros(16),
	)
}

int_type_for_size :: proc(size: int) -> Type {
	assert(math.is_power_of_two(size))
	assert(size <= 8)
	return Type(int(Type.U8) + intrinsics.count_trailing_zeros(size))
}

// instantiate_struct returns the concrete struct type produced by applying the
// parametric struct declared at `base` (AST `node`) to `args`. Instances are
// interned by (base, args) so identical instantiations share one `^Struct`.
// When `args` are still polymorphic (a `$T` leaked in from an enclosing generic
// signature) the fields/size are left unresolved: only the (base, args) shape is
// needed there, and it is re-instantiated with concrete args at call time.
instantiate_struct :: proc(
	ctx: ^Gen_Ctx,
	base: ^Struct,
	args: []Type,
) -> Type {
	context.allocator, _ = arna.scrath()

	args := intern_type_slice(ctx, args)
	key := Struct_Inst_Key{base, string(mem.slice_data_cast([]u8, args))}
	if existing, ok := ctx.struct_insts[key]; ok do return pack_type(existing)

	structa := new(Struct, ctx.types.allocator)
	structa.align = 1
	structa.params = args
	ctx.struct_insts[key] = structa

	prev_polys := len(ctx.poly_types)
	defer resize(&ctx.poly_types, prev_polys)
	for fld, i in base.param_names {
		append(
			&ctx.poly_types,
			Poly_Entry {
				name = fld,
				meta = {type = .Typeid, known = true, typeida = args[i]},
			},
		)
	}

	structa.fields = make(
		[]Struct_Field,
		len(base.fields),
		ctx.types.allocator,
	)
	for &field, i in structa.fields {
		field = base.fields[i]
		field.ty = emit_type(ctx, ast.clone(field.ty_ast))
		// TODO: extract this to a layout computation
		field.offset = mem.align_forward_int(
			structa.size,
			type_align(field.ty),
		)
		structa.size = field.offset + type_size(field.ty)
		structa.align = max(structa.align, type_align(field.ty))
	}
	structa.size = mem.align_forward_int(structa.size, structa.align)

	return pack_type(structa)
}

tmeta :: proc(ctx: ^Gen_Ctx, ty: Type) -> ^Check_Meta {
	return new_clone(Check_Meta{type = ty}, ctx.types.allocator)
}

tcmeta :: proc(ctx: ^Gen_Ctx, ty: Type, value: Lit) -> ^Check_Meta {
	return new_clone(
		Check_Meta{type = ty, known = true, lit = value},
		ctx.types.allocator,
	)
}

tpmeta :: proc(ctx: ^Gen_Ctx, ty: Type) -> ^Check_Meta {
	return new_clone(
		Check_Meta{type = .Typeid, known = true, typeida = ty},
		ctx.types.allocator,
	)
}

proc_meta :: proc(ctx: ^Gen_Ctx, pid: Proc_ID) -> ^Check_Meta {
	m := new(Check_Meta, ctx.types.allocator)
	m.type = pack_type(ctx.procs[pid].sig)
	m.known = true
	m.lit.procid = pid
	return m
}

module_meta :: proc(ctx: ^Gen_Ctx, mid: Module_ID) -> ^Check_Meta {
	m := new(Check_Meta, ctx.types.allocator)
	m.type = .Module
	m.lit.module = mid
	return m
}

intrinsic_meta :: proc(ctx: ^Gen_Ctx, intr: Intrinsic) -> ^Check_Meta {
	m := new(Check_Meta, ctx.types.allocator)
	m.type = .Intrinsic
	m.lit.intrinsic = intr
	return m
}

hash_name :: proc(name: string) -> u8 {
	return max(u8(hash.fnv32a(transmute([]u8)name)), 1)
}

find_module_decl :: proc(
	ctx: ^Gen_Ctx,
	mod: Module_ID,
	name: string,
) -> (
	sdecl: ^Decl,
	ok: bool,
) {
	needle := hash_name(name)

	module := &ctx.modules[mod]
	for iter := backend.simd_iter_from(
		module.decl_idx.hash[:len(module.decl_idx)],
		needle,
	); idx in backend.simd_iter_next(&iter) {
		decl := &module.decl_idx.id[idx]
		if decl.name != name do continue
		typecheck_decl(ctx, mod, decl)
		return decl, true
	}

	return
}

integrate_inferrence :: proc(
	ctx: ^Gen_Ctx,
	decl: ^Decl,
	inferred: Type,
) -> ^Check_Meta {
	meta := get_node_meta(decl.value)
	if decl.is_mutable do return meta
	if inferred == .Void do return meta
	if meta.type == inferred do return meta
	return new_clone(
		Check_Meta{type = inferred, known = meta.known, lit = meta.lit},
		ctx.types.allocator,
	)
}

typecheck_decl :: proc(
	ctx: ^Gen_Ctx,
	mid: Module_ID,
	decl: ^Decl,
) -> ^Check_Meta {
	if len(decl.value.end.file) == 0 && decl.value != &nil_node {
		return get_node_meta(decl.value)
	}

	prev_module := ctx.module
	prev_file_id := ctx.file_id

	defer {
		ctx.module = prev_module
		ctx.file_id = prev_file_id
		ctx.file = &ctx.files[prev_file_id]
	}

	ctx.module = Module_ID(mid)
	mod := &ctx.modules[mid]

	ctx.file_id = decl.file
	ctx.file = &ctx.files[ctx.file_id]

	if decl.value == &nil_node {
		decl.value = new_clone(nil_node, ctx.types.allocator)
	}
	ty := emit_type(ctx, decl.ty)
	vl: ^Check_Meta
	if decl.is_mutable {
		vl = typecheck(
			ctx,
			{
				inferred_ty = ty,
				key = Decl_Key {
					decl.name,
					decl.file,
					u32(decl.value.pos.offset),
				},
			},
			decl.value,
		)
	} else {
		vl = typecheck_eval(
			ctx,
			{
				inferred_ty = ty,
				key = Decl_Key {
					decl.name,
					decl.file,
					u32(decl.value.pos.offset),
				},
			},
			decl.value,
		)
	}

	return expect(ctx, decl.value, vl, ty)
}

module_add_decls :: proc(ctx: ^Gen_Ctx, mid: Module_ID, decls: []Decl) {
	mod := &ctx.modules[mid]

	backend.grow_search_space(
		&mod.decl_idx,
		mem.align_forward_int(len(decls), align_of(backend.Intern_Vec)),
		ctx.types.allocator,
	)

	for dcl, i in decls {
		mod.decl_idx[i] = {hash_name(dcl.name), dcl}
	}
}

nil_node: ast.Bad_Expr = {}

collect_decls :: proc(f: ast.File, decls: ^[dynamic]Decl, file_id: File_ID) {
	// TODO: put this into the global init once this ICE is fixed
	nil_node.derived = &nil_node
	nil_node.derived_expr = &nil_node

	for stmt in f.decls {
		if decl, ok := stmt.derived_stmt.(^ast.Value_Decl); ok {
			for name, i in decl.names {

				vl := &nil_node.node
				if i < len(decl.values) do vl = decl.values[i]
				append(
					decls,
					Decl {
						name = src_of(f, name),
						ty = decl.type,
						value = vl,
						file = file_id,
						is_mutable = decl.is_mutable,
					},
				)
			}
		}

		if block, ok := stmt.derived_stmt.(^ast.Foreign_Block_Decl); ok {
			body := block.body.derived.(^ast.Block_Stmt) or_continue
			for vl in body.stmts {
				decl := vl.derived.(^ast.Value_Decl) or_continue
				if len(decl.values) == 0 do continue
				append(
					decls,
					Decl {
						name = src_of(f, decl.names[0]),
						ty = decl.type,
						value = decl.values[0],
						file = file_id,
					},
				)
			}
		}
	}
}

has_polys :: proc(ctx: ^Gen_Ctx, root: ^ast.Expr) -> (found: bool) {
	context.user_ptr = &found
	ast.inspect(root, proc(n: ^ast.Node) -> bool {
			if n == nil do return false
			found := (^bool)(context.user_ptr)
			_, ok := n.derived.(^ast.Poly_Type)
			found^ |= ok
			return !found^
		})
	return
}

extract_polys :: proc(
	ctx: ^Gen_Ctx,
	slots: ^#soa[dynamic]Poly_Entry,
	croot: Check_Meta,
	proot: ^ast.Expr,
) -> bool {
	#partial switch d in proot.derived {
	case ^ast.Pointer_Type:
		if croot.type != .Typeid do return false
		ptr := unpack_type(croot.typeida).(Pointer) or_return
		return extract_polys(
			ctx,
			slots,
			{type = .Typeid, typeida = ptr^},
			d.elem,
		)
	case ^ast.Multi_Pointer_Type:
		if croot.type != .Typeid do return false
		ptr := unpack_type(croot.typeida).(Multi_Pointer) or_return
		return extract_polys(
			ctx,
			slots,
			{type = .Typeid, typeida = ptr^},
			d.elem,
		)
	case ^ast.Call_Expr:
		if croot.type != .Typeid do return false
		stru := unpack_type(croot.typeida).(^Struct) or_return
		if len(stru.params) != len(d.args) do return false
		for arg, i in stru.params {
			extract_polys(
				ctx,
				slots,
				{type = .Typeid, typeida = arg},
				d.args[i],
			) or_return
		}
	case ^ast.Array_Type:
		if croot.type != .Typeid do return false
		if d.len == nil {
			slc := unpack_type(croot.typeida).(^Slice) or_return
			return extract_polys(
				ctx,
				slots,
				{type = .Typeid, typeida = slc.elem},
				d.elem,
			)
		}

		if d.tag != nil {
			if tag, is_tag := d.tag.derived.(^ast.Basic_Directive);
			   is_tag && tag.name == "simd" {
				simd := unpack_type(croot.typeida).(^Simd) or_return
				return(
					extract_polys(
						ctx,
						slots,
						{type = .Int, int = i64(simd.len)},
						d.len,
					) &&
					extract_polys(
						ctx,
						slots,
						{type = .Typeid, typeida = simd.elem},
						d.elem,
					) \
				)
			}
		}
	case ^ast.Poly_Type:
		croot := croot
		croot.known = true
		append(slots, Poly_Entry{d.type.name, croot})
		if d.specialization != nil {
			extract_polys(ctx, slots, croot, d.specialization)
		}
	case:
	}

	return true
}

intern_decl :: proc(
	ctx: ^Gen_Ctx,
	mapa: ^map[Decl_Key]^$T,
	key: Maybe(Decl_Key),
	ret: ^^Check_Meta,
) -> (
	^T,
	bool,
) {
	if key, ok := key.?; ok {
		record, ok := mapa[key]
		ret^ = tpmeta(ctx, pack_type(record))
		if ok do return nil, false
	}
	record := new(T, mapa.allocator)
	if key, ok := key.?; ok do mapa[key] = record
	return record, true
}

emit_type :: proc(ctx: ^Gen_Ctx, expr: ^ast.Node) -> (ret: Type) {
	res := typecheck(ctx, {inferred_ty = .Typeid}, expr)
	if res.type == .Void do return .Void
	if res.type != .Typeid {
		error(ctx, expr, "expected a type, found a value of type %v", res.type)
		return .Invalid_Type
	}
	return res.lit.typeida
}

Proc :: struct {
	name:        string,
	polys:       #soa[]Poly_Entry,
	param_types: []backend.Param_Spec,
	using sig:   ^Proc_Type,
	lit:         ^ast.Proc_Lit,
	module:      Module_ID,
	file:        ^ast.File,
	file_id:     File_ID,
	stencil:     backend.Stencil,
	out:         backend.Codegen_Output,
}

// A module level (global) mutable variable. The backing data lives in
// ctx.globals; `idx` is assigned lazily at emit time (see emit_module_globals)
// because ctx.globals is cleared between typechecking and codegen.
Global_Var :: struct {
	name:   string,
	module: Module_ID,
	type:   Type,
	idx:    u32,
	init:   ^ast.Expr,
}

Param :: struct {
	name: string,
	type: Type,
}

Ret_ABI :: struct {
	extras:      []Type,
	srets_start: int,
	reg_rets:    []Type,
}

ret_abi :: proc(rets: []Type) -> (rabi: Ret_ABI) {
	if len(rets) == 0 do return
	last := rets[len(rets) - 1]
	is_sret := int(type_size(last) > 16)
	rabi.extras = rets[:len(rets) - 1 + is_sret]
	rabi.srets_start = len(rabi.extras) - is_sret
	rabi.reg_rets = rets[len(rabi.extras):]

	return
}

ret_is_by_pointer :: proc(abi: Ret_ABI, idx: int) -> bool {
	return idx < len(abi.extras) || abi.srets_start < len(abi.extras)
}

call_sig :: proc(ctx: ^Gen_Ctx, node: ^ast.Node) -> (^Proc_Type, bool) {
	call, cok := node.derived.(^ast.Call_Expr)
	if !cok do return {}, false
	ty := get_node_type(call.expr)
	return unpack_type(ty).(^Proc_Type)
}

// expect_integer checks an index like expression, any integer width will do
expect_integer :: proc(ctx: ^Gen_Ctx, node: ^ast.Node) -> ^Check_Meta {
	got := typecheck(ctx, {inferred_ty = .Int}, node)
	if node == nil ||
	   got.type == .Invalid_Type ||
	   in_set(got.type, INTEGER_TYPES) {
		return got
	}
	return error(ctx, node, "expected an integer, found %v", got.type)
}

// expect_args validates the arity of a builtin or intrinsic call and hands the
// arguments back, so a mismatch can be `or_return`ed
expect_args :: proc(
	ctx: ^Gen_Ctx,
	node: ^ast.Node,
	args: []^ast.Expr,
	count: int,
) -> (
	res: []^ast.Expr,
	err: ^Check_Meta,
) {
	if len(args) != count {
		return nil, error(
			ctx,
			node,
			"expected %v arguments, found %v",
			count,
			len(args),
		)
	}
	return args, nil
}

// destructured_sig validates the `a, b := f()` shape, where the results of a
// single call are spread over `count` bindings
destructured_sig :: proc(
	ctx: ^Gen_Ctx,
	node: ^ast.Node,
	count: int,
) -> (
	sig: ^Proc_Type,
	err: ^Check_Meta,
) {
	ok: bool
	if sig, ok = call_sig(ctx, node); !ok {
		return nil, error(
			ctx,
			node,
			"expected a call returning %v values",
			count,
		)
	}
	if len(sig.rets) != count {
		return nil, error(
			ctx,
			node,
			"expected %v values, the call returns %v",
			count,
			len(sig.rets),
		)
	}
	return
}

Varuable_Idx :: union #no_nil {
	int,
	Node_ID,
	Lit,
}

Variable :: struct {
	name:  string,
	idx:   Varuable_Idx,
	type:  Type,
	ident: ^ast.Expr,
	flags: Var_Flags,
}

Module_ID :: distinct int

Intrinsic :: enum int {
	syscall,
	trap,
	simd_lanes_eq,
	simd_extract_lsbs,
	simd_reduce_add_bisect,
	count_trailing_zeros,
}

Builtin_Proc :: enum int {
	nil,
	len,
	raw_data,
	size_of,
	align_of,
}

get_builtin_proc :: proc(node: ^ast.Node) -> Builtin_Proc {
	#partial switch d in node.derived {
	case ^ast.Ident:
		return reflect.enum_from_name(Builtin_Proc, d.name) or_else {}
	}
	return {}
}

Decl :: struct {
	name:       string,
	ty:         ^ast.Expr,
	value:      ^ast.Expr,
	file:       File_ID,
	is_mutable: bool,
	global_idx: u32,
}

Module :: struct {
	name:       string,
	dir:        string,
	decl_idx:   #soa[]backend.SS_Entry(Decl),
	file_start: int,
	file_count: int,
	// range into ctx.procs occupied by this module's procedures
	proc_start: int,
	proc_count: int,
	// local import name -> module index
	imports:    map[string]Module_ID,
}

Global_Ctx :: struct {
	root:        string,
	collections: map[string]string,
	modules:     [dynamic]Module,
	// every loaded file, indexable by File_ID
	files:       [dynamic]ast.File,
}

Proc_Type_Key :: string
Type_Slice_Key :: string

Struct_Inst_Key :: struct {
	base: ^Struct,
	args: string,
}

Proc_Inst_Key :: struct {
	base:  Proc_ID,
	polys: string,
}

Types :: struct {
	target:         Target,
	check:          bool,
	tstats:         backend.Stats,
	mems:           Mems,
	allocator:      runtime.Allocator,
	procs:          [dynamic]Proc,
	scope:          [dynamic]Variable,
	proc_insts:     map[Proc_Inst_Key]Proc_ID,
	pointers:       map[Type]Pointer,
	multi_pointers: map[Type]Multi_Pointer,
	structs:        map[Decl_Key]^Struct,
	struct_insts:   map[Struct_Inst_Key]^Struct,
	enums:          map[Decl_Key]^Enum,
	unions:         map[Decl_Key]^Union,
	arrays:         map[Array]^Array,
	simds:          map[Simd]^Simd,
	slices:         map[Slice]^Slice,
	proc_types:     map[Proc_Type_Key]^Proc_Type,
	type_slices:    map[Type_Slice_Key][]Type,
	globals:        [dynamic]Global_Data,
	global_vars:    [dynamic]Global_Var,
}

types_init :: proc(types: ^Types) {
	_ = arna.bulk_init(
		&arna.scratch[0],
		&arna.scratch[1],
		&types.mems.graph,
		&types.mems.regalloc,
		&types.mems.scratch,
		&types.mems.code,
		&types.mems.reloc,
		&types.mems.sloc,
		&types.mems.cfi,
		&types.mems.type,
	)

	types.allocator = arna.allocator(&types.mems.type)
	types.procs.allocator = types.allocator
	types.proc_insts.allocator = types.allocator
	types.pointers.allocator = types.allocator
	types.multi_pointers.allocator = types.allocator
	types.structs.allocator = types.allocator
	types.struct_insts.allocator = types.allocator
	types.enums.allocator = types.allocator
	types.unions.allocator = types.allocator
	types.arrays.allocator = types.allocator
	types.slices.allocator = types.allocator
	types.proc_types.allocator = types.allocator
	types.type_slices.allocator = types.allocator
	types.globals.allocator = types.allocator
	types.global_vars.allocator = types.allocator
	types.scope.allocator = types.allocator
	types.simds.allocator = types.allocator
}

types_deinit :: proc(types: ^Types) {
	arna.bulk_destroy(
		&arna.scratch[0],
		&arna.scratch[1],
		&types.mems.graph,
		&types.mems.regalloc,
		&types.mems.scratch,
		&types.mems.code,
		&types.mems.reloc,
		&types.mems.sloc,
		&types.mems.cfi,
		&types.mems.type,
	)
}

Global_Data :: struct {
	bytes: []u8,
	align: int,
}

Array :: struct {
	elem: Type,
	len:  int,
}

Slice :: struct {
	elem: Type,
}

Simd :: struct {
	elem: Type,
	len:  int,
}

File_ID :: distinct u32

Decl_Key :: struct {
	name:   string,
	file:   File_ID,
	offset: u32,
}

Struct :: struct {
	param_names: []string,
	params:      []Type,
	fields:      []Struct_Field,
	size:        int,
	align:       int,
}

Struct_Field :: struct {
	name:    string,
	using _: struct #raw_union {
		ty:     Type,
		ty_ast: ^ast.Expr,
	},
	offset:  int,
}

Enum :: struct {
	backing:  Type,
	variants: []Enum_Variant,
}

Enum_Variant :: struct {
	name:  string,
	value: i64,
}

Proc_Type :: struct {
	params: []Type,
	rets:   []Type,
}

// Union memory layout: the active variant's payload lives at offset 0, and the
// tag (1-based variant index, 0 == nil) lives at `tag_offset`.
Union :: struct {
	variants:   []Type,
	tag_ty:     Type,
	tag_offset: int,
	size:       int,
	align:      int,
}

union_variant_index :: proc(u: ^Union, ty: Type) -> (int, bool) {
	return slice.linear_search(u.variants, ty)
}

@(rodata)
VOID := Check_Meta {
	type = .Void,
}

// `known` so that a poisoned value can also flow through the constant
// evaluating paths without tripping their invariants
@(rodata)
INVALID := Check_Meta {
	type  = .Invalid_Type,
	known = true,
}

typecheck_eval :: proc(
	ctx: ^Gen_Ctx,
	prop: Ty_Propagation,
	node: ^ast.Node,
) -> (
	ty: ^Check_Meta,
) {
	ctx.eval_depth += 1
	defer ctx.eval_depth -= 1
	defer fmt.assertf(ty.known, "%v", ty.type)
	return typecheck(ctx, prop, node)
}

typecheck :: proc(
	ctx: ^Gen_Ctx,
	prop: Ty_Propagation,
	node: ^ast.Node,
) -> (
	ty: ^Check_Meta,
) {
	context.allocator, _ = arna.scrath()

	if node == nil do return &VOID

	for p in ctx.procs[1:] {
		assert(p.lit.type != nil)
	}

	defer {
		set_node_data(node, ty)
		fmt.assertf(
			ty.known || ctx.eval_depth == 0,
			"%v %#v",
			ty,
			node.derived,
		)
	}

	#partial match: switch d in node.derived {
	case ^ast.Bad_Expr:
		return tmeta(ctx, prop.inferred_ty)
	case ^ast.Struct_Type:
		structa := intern_decl(ctx, &ctx.structs, prop.key, &ty) or_break
		structa.align = 1

		prev := len(ctx.poly_types)
		if d.poly_params != nil {
			structa.param_names = make(
				[]string,
				len(d.poly_params.list),
				ctx.types.allocator,
			)
			for param, i in d.poly_params.list {
				pd, is_poly := param.derived.(^ast.Field).names[0].derived.(^ast.Poly_Type)
				if !is_poly {
					return error(
						ctx,
						param,
						"TODO: only $T struct parameters are supported",
					)
				}
				structa.param_names[i] = pd.type.name
			}
		}

		structa.fields = make(
			[]Struct_Field,
			len(d.fields.list),
			ctx.types.allocator,
		)
		for &field, i in structa.fields {
			ast_field := d.fields.list[i]
			if len(ast_field.names) != 1 {
				return error(
					ctx,
					ast_field,
					"TODO: a struct field needs exactly one name, found %v",
					len(ast_field.names),
				)
			}
			fname, is_ident := ast_field.names[0].derived.(^ast.Ident)
			if !is_ident {
				return error(ctx, ast_field.names[0], "expected a field name")
			}
			field.name = fname.name

			if d.poly_params == nil {
				field.ty = emit_type(ctx, ast_field.type)
				field.offset = mem.align_forward_int(
					structa.size,
					type_align(field.ty),
				)
				structa.size = field.offset + type_size(field.ty)
				structa.align = max(structa.align, type_align(field.ty))
			} else {
				field.ty_ast = ast_field.type
			}
		}
		structa.size = mem.align_forward_int(structa.size, structa.align)

		resize(&ctx.poly_types, prev)

		return tpmeta(ctx, pack_type(structa))
	case ^ast.Enum_Type:
		e := intern_decl(ctx, &ctx.enums, prop.key, &ty) or_break

		e.backing = d.base_type != nil ? emit_type(ctx, d.base_type) : .Int
		e.variants = make([]Enum_Variant, len(d.fields), ctx.types.allocator)
		next := i64(0)
		for f, i in d.fields {
			vname: string
			vval := next
			#partial switch fd in f.derived {
			case ^ast.Ident:
				vname = fd.name
			case ^ast.Field_Value:
				fname, is_ident := fd.field.derived.(^ast.Ident)
				if !is_ident do return error(ctx, fd.field, "expected a variant name")
				vname = fname.name
				cv, cok := const_eval_int(fd.value)
				if !cok {
					return error(
						ctx,
						fd.value,
						"enum variant value must be a constant integer",
					)
				}
				vval = cv
			case:
				return error(ctx, f, "expected an enum variant")
			}
			e.variants[i] = {vname, vval}
			next = vval + 1
		}
		return tpmeta(ctx, pack_type(e))
	case ^ast.Union_Type:
		u := intern_decl(ctx, &ctx.unions, prop.key, &ty) or_break

		u.variants = make([]Type, len(d.variants), ctx.types.allocator)
		max_size := 0
		max_align := 1
		for v, i in d.variants {
			vt := emit_type(ctx, v)
			u.variants[i] = vt
			max_size = max(max_size, type_size(vt))
			max_align = max(max_align, type_align(vt))
		}
		u.tag_ty = .I64
		tag_size := type_size(u.tag_ty)
		u.tag_offset = mem.align_forward_int(max_size, tag_size)
		u.align = max(max_align, tag_size)
		u.size = mem.align_forward_int(u.tag_offset + tag_size, u.align)
		return tpmeta(ctx, pack_type(u))
	case ^ast.Multi_Pointer_Type:
		return tpmeta(ctx, intern_multi_pointer(ctx, emit_type(ctx, d.elem)))
	case ^ast.Pointer_Type:
		return tpmeta(ctx, intern_pointer(ctx, emit_type(ctx, d.elem)))
	case ^ast.Array_Type:
		elem := emit_type(ctx, d.elem)
		if d.len == nil {
			return tpmeta(ctx, intern_slice(ctx, elem))
		}
		res := typecheck_eval(ctx, {inferred_ty = .Int}, d.len)
		if res.type != .Int || res.lit.int < 0 {
			return error(
				ctx,
				d.len,
				"array length must be a non negative integer, found %v",
				res.type,
			)
		}
		if d.tag != nil {
			if tag, is_tag := d.tag.derived.(^ast.Basic_Directive);
			   is_tag && tag.name == "simd" {
				length := int(res.lit.int)
				if !math.is_power_of_two(length) {
					return error(
						ctx,
						d.len,
						"a #simd length must be a power of two, found %v",
						length,
					)
				}
				size := type_size(elem) * length
				if size < 16 || size > 64 {
					return error(
						ctx,
						node,
						"a #simd vector must be 16 to 64 bytes, this one is %v",
						size,
					)
				}
				return tpmeta(ctx, intern_simd(ctx, elem, length))
			}
		}
		return tpmeta(ctx, intern_array(ctx, elem, int(res.lit.int)))
	case ^ast.Poly_Type:
		return error(ctx, node, "$%v is not bound here", d.type.name)
	case ^ast.Proc_Type:
		sig, concrete := typecheck_sig(ctx, d)
		if !concrete {
			return error(ctx, node, "a proc type can not be polymorphic")
		}
		return tpmeta(ctx, pack_type(sig))
	case ^ast.Block_Stmt:
		prev_scope_len := len(ctx.scope)

		for stmt in d.stmts {
			decl := stmt.derived.(^ast.Value_Decl) or_continue

			if len(decl.names) == 0 do continue
			if decl.is_mutable do continue

			ty := emit_type(ctx, decl.type)

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
				res := typecheck_eval(ctx, {inferred_ty = ty}, decl.values[i])
				append(
					&ctx.scope,
					Variable {
						name = src_of(ctx.file^, name),
						type = res.type,
						idx = res.lit,
						ident = name,
					},
				)
			}
		}

		for stmt in d.stmts {
			typecheck(ctx, {}, stmt)
		}
		for var in ctx.scope[prev_scope_len:] {
			set_node_data(var.ident, var.flags)
		}
		resize(&ctx.scope, prev_scope_len)
	case ^ast.Value_Decl:
		if !d.is_mutable do return &VOID

		if len(d.values) == 1 && len(d.names) > 1 {
			typecheck(ctx, {}, d.values[0])
			sig := destructured_sig(ctx, d.values[0], len(d.names)) or_return
			rabi := ret_abi(sig.rets)

			for i in 0 ..< len(d.names) {
				name := src_of(ctx.file^, d.names[i])
				if name == "_" do continue
				flags: Var_Flags
				if ret_is_by_pointer(rabi, i) {
					flags |= {.Referenced}
				}
				set_node_data(d.names[i], flags)
				append(
					&ctx.scope,
					Variable {
						name = name,
						type = sig.rets[i],
						ident = d.names[i],
						flags = flags,
					},
				)
			}
			return &VOID
		}

		inferred_ty := emit_type(ctx, d.type)

		if len(d.values) == 0 {
			if inferred_ty == .Void {
				return error(ctx, node, "a variable needs a type or a value")
			}
			flags: Var_Flags
			if type_to_dt(inferred_ty) == .Void do flags |= {.Referenced}
			for i in 0 ..< len(d.names) {
				name := src_of(ctx.file^, d.names[i])
				if name == "_" do continue
				set_node_data(d.names[i], flags)
				append(
					&ctx.scope,
					Variable {
						name = name,
						type = inferred_ty,
						ident = d.names[i],
						flags = flags,
					},
				)
			}
			return &VOID
		}

		if len(d.names) != len(d.values) {
			return error(
				ctx,
				node,
				"expected %v values, found %v",
				len(d.names),
				len(d.values),
			)
		}

		for i in 0 ..< len(d.names) {
			name := src_of(ctx.file^, d.names[i])
			if name == "_" do continue

			if is_of(inferred_ty, ^Union) {
				value_ty := typecheck(ctx, {}, d.values[i])
				expect(ctx, d.values[i], value_ty, inferred_ty)
				flags := Var_Flags{.Referenced}
				set_node_data(d.names[i], flags)
				append(
					&ctx.scope,
					Variable {
						name = name,
						type = inferred_ty,
						ident = d.names[i],
						flags = flags,
					},
				)
				continue
			}

			value_ty := typecheck_as(ctx, inferred_ty, d.values[i])
			set_node_data(d.names[i], Var_Flags{})
			append(
				&ctx.scope,
				Variable {
					name = name,
					type = value_ty.type,
					ident = d.names[i],
				},
			)
		}
	case ^ast.Proc_Lit:
		return proc_meta(ctx, typecheck_proc(ctx, ctx.module, prop.key, d))
	case ^ast.Basic_Lit:
		ty := prop.inferred_ty

		#partial switch d.tok.kind {
		case .Integer:
			if ty != .Void &&
			   !in_set(ty, INTEGER_TYPES) &&
			   !in_set(ty, FLOAT_TYPES) {
				return error(
					ctx,
					node,
					"an integer literal can not be a %v",
					ty,
				)
			}

			if ty == .Void do ty = .Int

			value, ok := strconv.parse_u64(d.tok.text)
			if !ok do return error(ctx, node, "malformed integer literal")

			if in_set(ty, INTEGER_TYPES) {
				return tcmeta(ctx, ty, {int = i64(value)})
			} else {
				return tcmeta(ctx, ty, {float = f64(value)})
			}
		case .Float:
			if ty != .Void && !in_set(ty, FLOAT_TYPES) {
				return error(ctx, node, "a float literal can not be a %v", ty)
			}
			if ty == .Void do ty = .F64
			value, ok := strconv.parse_f64(d.tok.text)
			if !ok do return error(ctx, node, "malformed float literal")
			return tcmeta(ctx, ty, {float = f64(value)})
		case .Rune:
			if ty != .Void && !in_set(ty, INTEGER_TYPES) {
				return error(ctx, node, "a rune literal can not be a %v", ty)
			}
			if ty == .Void do ty = .U8
			inner := d.tok.text[1:len(d.tok.text) - 1]
			r, _, _, ok := strconv.unquote_char(inner, '\'')
			if !ok do return error(ctx, node, "malformed rune literal")
			return tcmeta(ctx, ty, {rune = r})
		case .String:
			return expect(
				ctx,
				node,
				tcmeta(ctx, .String, {string = &d.tok.text}),
				ty,
			)
		case:
			return error(ctx, node, "TODO: %v literals", d.tok.kind)
		}
	case ^ast.Comp_Lit:
		inferred_ty := emit_type(ctx, d.type)
		if inferred_ty == .Void do inferred_ty = prop.inferred_ty

		#partial switch t in unpack_type(inferred_ty) {
		case ^Struct:
			for elem, i in d.elems {
				#partial switch e in elem.derived {
				case ^ast.Field_Value:
					name := src_of(ctx.file^, e.field)
					found := false
					for &field in t.fields {
						if field.name != name do continue
						found = true
						set_node_data(e.field, field.offset)
						typecheck_as(ctx, field.ty, e.value)
					}
					if !found {
						error(
							ctx,
							e.field,
							"%v has no field %q",
							inferred_ty,
							name,
						)
					}
				case:
					if i >= len(t.fields) {
						error(
							ctx,
							elem,
							"%v has only %v fields",
							inferred_ty,
							len(t.fields),
						)
						continue
					}
					typecheck_as(ctx, t.fields[i].ty, elem)
				}
			}

			return tmeta(ctx, inferred_ty)
		case ^Array:
			if len(d.elems) > t.len {
				error(
					ctx,
					node,
					"%v holds only %v elements, found %v",
					inferred_ty,
					t.len,
					len(d.elems),
				)
			}
			for elem in d.elems {
				typecheck_as(ctx, t.elem, elem)
			}
			return tmeta(ctx, inferred_ty)
		case:
			return error(
				ctx,
				node,
				"a compound literal can not construct a %v",
				inferred_ty,
			)
		}
	case ^ast.Index_Expr:
		base := typecheck(ctx, {}, d.expr)
		expect_integer(ctx, d.index)
		#partial switch t in unpack_type(base.type) {
		case ^Array:
			return tmeta(ctx, t.elem)
		case ^Slice:
			return tmeta(ctx, t.elem)
		case String_Type:
			return tmeta(ctx, .U8)
		case Pointer:
			if nt, ok := unpack_type(t^).(^Array); ok {
				return tmeta(ctx, intern_multi_pointer(ctx, nt.elem))
			}
		case Multi_Pointer:
			return tmeta(ctx, t^)
		}
		return error(ctx, d.expr, "can not index a %v", base.type)
	case ^ast.Slice_Expr:
		base := typecheck(ctx, {}, d.expr)
		expect_integer(ctx, d.low)
		expect_integer(ctx, d.high)
		#partial switch t in unpack_type(base.type) {
		case ^Array:
			return tmeta(ctx, intern_slice(ctx, t.elem))
		case ^Slice:
			return base
		case String_Type:
			return tmeta(ctx, .String)
		case Pointer:
			if nt, ok := unpack_type(t^).(^Array); ok {
				return tmeta(ctx, intern_multi_pointer(ctx, nt.elem))
			}
		case Multi_Pointer:
			if d.high == nil do return base
			return tmeta(ctx, intern_slice(ctx, t^))
		}
		return error(ctx, d.expr, "can not slice a %v", base.type)
	case ^ast.Selector_Expr:
		base := typecheck(ctx, {}, d.expr)

		f, is_ident := d.field.derived.(^ast.Ident)
		if !is_ident do return error(ctx, d.field, "expected a field name")

		if base.type == .Module {
			mid := base.lit.module
			if mid == MODULE_INTRINSICS {
				intr, iok := reflect.enum_from_name(Intrinsic, f.name)
				if !iok {
					return error(ctx, d.field, "unknown intrinsic %q", f.name)
				}
				return intrinsic_meta(ctx, intr)
			}

			pid, pok := find_module_decl(ctx, mid, f.name)
			if !pok {
				return error(
					ctx,
					d.field,
					"module %q has no symbol %q",
					ctx.modules[mid].name,
					f.name,
				)
			}
			return integrate_inferrence(ctx, pid, prop.inferred_ty)
		}

		base_ty := base.type
		if p, ok := unpack_type(base_ty).(Pointer); ok do base_ty = p^

		if base.type == .Typeid {
			base_ty = base.lit.typeida
		}

		#partial switch t in unpack_type(base_ty) {
		case ^Enum:
			for v in t.variants {
				if v.name == f.name {
					set_node_data(d.field, int(v.value))
					return tmeta(ctx, base.lit.typeida)
				}
			}
			return error(ctx, d.field, "%v has no variant %q", base_ty, f.name)
		case ^Struct:
			for &field in t.fields {
				if field.name == f.name {
					set_node_data(d.field, field.offset)
					return tmeta(ctx, field.ty)
				}
			}
		}
		return error(ctx, d.field, "%v has no field %q", base_ty, f.name)
	case ^ast.Implicit_Selector_Expr:
		e := unwrap_type(
			ctx,
			node,
			prop.inferred_ty,
			^Enum,
			"an implicit selector needs an enum context, found %v",
		) or_return
		for v in e.variants {
			if v.name == d.field.name {
				set_node_data(d.field, int(v.value))
				return tmeta(ctx, prop.inferred_ty)
			}
		}
		return error(
			ctx,
			d.field,
			"%v has no variant %q",
			prop.inferred_ty,
			d.field.name,
		)
	case ^ast.Type_Assertion:
		base := typecheck(ctx, {}, d.expr)
		u := unwrap_type(
			ctx,
			d.expr,
			base.type,
			^Union,
			"can not type assert a %v",
		) or_return
		target := emit_type(ctx, d.type)
		if _, found := union_variant_index(u, target); !found {
			return error(
				ctx,
				d.type,
				"%v is not a variant of %v",
				target,
				base.type,
			)
		}
		return tmeta(ctx, target)
	case ^ast.Binary_Expr:
		is_comparison :=
			.B_Comparison_Begin < d.op.kind && d.op.kind < .B_Comparison_End

		// the result type of a comparison says nothing about its operands
		prop := prop
		if is_comparison do prop.inferred_ty = .Void

		if is_nil_lit(d.left) || is_nil_lit(d.right) {
			operand := is_nil_lit(d.left) ? d.right : d.left
			oty := typecheck(ctx, {}, operand)
			_ = unwrap_type(
				ctx,
				operand,
				oty.type,
				^Union,
				"only a union can be compared to nil, found %v",
			) or_return
			return tmeta(ctx, .Bool)
		}

		if is_num_lit(d.left) &&
		   !is_num_lit(d.right) &&
		   prop.inferred_ty == .Void {
			rhs_ty := typecheck(ctx, {}, d.right)
			lhs_ty := typecheck_as(ctx, rhs_ty.type, d.left)

			if !is_comparison &&
			   lhs_ty.known &&
			   rhs_ty.known &&
			   in_set(lhs_ty.type, INTEGER_TYPES) {
				#partial switch d.op.kind {
				case .Quo:
					if rhs_ty.int == 0 {
						return error(ctx, d.right, "division by zero")
					}
					lhs_ty.int /= rhs_ty.int
				case .Add:
					lhs_ty.int += rhs_ty.int
				case:
					return error(
						ctx,
						node,
						"TODO: constant folding of %v",
						d.op.text,
					)
				}
			}

			return is_comparison ? tmeta(ctx, .Bool) : lhs_ty
		}

		lhs_ty := typecheck(ctx, prop, d.left)
		inferred_ty := lhs_ty.type
		if d.op.kind == .Shl || d.op.kind == .Shr {
			inferred_ty = .Uint
		}
		typecheck_as(ctx, inferred_ty, d.right)

		if is_comparison {
			return tmeta(ctx, .Bool)
		}

		return lhs_ty
	case ^ast.Unary_Expr:
		#partial switch d.op.kind {
		case .And:
			inferred_ty := Type.Void
			if ptr, ok := unpack_type(prop.inferred_ty).(Pointer); ok {
				inferred_ty = ptr^
			}

			inner_ty := expect(
				ctx,
				d.expr,
				typecheck(
					ctx,
					{inferred_ty = inferred_ty, referencing = true},
					d.expr,
				),
				inferred_ty,
			)
			return tmeta(ctx, intern_pointer(ctx, inner_ty.type))
		case .Not:
			typecheck_as(ctx, .Bool, d.expr)
			return tmeta(ctx, .Bool)
		case .Sub, .Xor:
			return typecheck(ctx, prop, d.expr)
		case:
			return error(ctx, node, "TODO: unary %v", d.op.text)
		}
	case ^ast.Deref_Expr:
		inferred_ty := Type.Void
		if prop.inferred_ty != .Void {
			inferred_ty = intern_pointer(ctx, prop.inferred_ty)
		}

		inner := typecheck(ctx, {inferred_ty = inferred_ty}, d.expr)
		ptr := unwrap_type(
			ctx,
			d.expr,
			inner.type,
			Pointer,
			"can not dereference a %v",
		) or_return
		return tmeta(ctx, ptr^)
	case ^ast.Expr_Stmt:
		return typecheck(ctx, {}, d.expr)
	case ^ast.If_Stmt:
		if d.init != nil do error(ctx, d.init, "TODO: an if with an initializer")
		typecheck_as(ctx, .Bool, d.cond)
		typecheck(ctx, {}, d.body)
		typecheck(ctx, {}, d.else_stmt)
		return &VOID
	case ^ast.Switch_Stmt:
		if d.init != nil {
			error(ctx, d.init, "TODO: a switch with an initializer")
		}
		cond_ty := typecheck(ctx, {}, d.cond)
		body := d.body.derived.(^ast.Block_Stmt) or_else nil
		if body == nil do return error(ctx, d.body, "expected a switch body")
		for clause_node in body.stmts {
			clause := clause_node.derived.(^ast.Case_Clause) or_else nil
			if clause == nil do continue
			for v in clause.list {
				typecheck(ctx, {inferred_ty = cond_ty.type}, v)
			}
			prev := len(ctx.scope)
			for stmt in clause.body do typecheck(ctx, {}, stmt)
			resize(&ctx.scope, prev)
		}
		return &VOID
	case ^ast.Type_Switch_Stmt:
		tag, is_assign := d.tag.derived.(^ast.Assign_Stmt)
		if !is_assign {
			return error(ctx, d.tag, "TODO: a type switch needs a binding")
		}
		binding := src_of(ctx.file^, tag.lhs[0])
		union_ty := typecheck(ctx, {}, tag.rhs[0])
		uni := unwrap_type(
			ctx,
			tag.rhs[0],
			union_ty.type,
			^Union,
			"can not type switch on a %v",
		) or_return
		body := d.body.derived.(^ast.Block_Stmt) or_else nil
		if body == nil do return error(ctx, d.body, "expected a switch body")
		for clause_node in body.stmts {
			clause := clause_node.derived.(^ast.Case_Clause) or_else nil
			if clause == nil do continue
			bind_ty := union_ty.type
			if len(clause.list) > 0 {
				bind_ty = emit_type(ctx, clause.list[0])
				if _, found := union_variant_index(uni, bind_ty); !found {
					error(
						ctx,
						clause.list[0],
						"%v is not a variant of %v",
						bind_ty,
						union_ty.type,
					)
				}
			}
			prev := len(ctx.scope)
			set_node_data(tag.lhs[0], Var_Flags{.Referenced})
			append(
				&ctx.scope,
				Variable {
					name = binding,
					type = bind_ty,
					ident = tag.lhs[0],
					flags = {.Referenced},
				},
			)
			for stmt in clause.body do typecheck(ctx, {}, stmt)
			resize(&ctx.scope, prev)
		}
		return &VOID
	case ^ast.For_Stmt:
		if d.init != nil || d.cond != nil || d.post != nil {
			error(ctx, node, "TODO: only `for {{ .. }}` is supported")
		}

		typecheck(ctx, {}, d.body)
	case ^ast.Range_Stmt:
		if d.init != nil do error(ctx, d.init, "TODO: a for with an initializer")
		expr_meta := typecheck(ctx, {}, d.expr)
		elem: Type
		#partial switch t in unpack_type(expr_meta.type) {
		case ^Slice:
			elem = t.elem
		case ^Array:
			elem = t.elem
		case String_Type:
			elem = .U8
		case:
			return error(
				ctx,
				d.expr,
				"can not range over a %v",
				expr_meta.type,
			)
		}

		prev := len(ctx.scope)
		val_types := [2]Type{elem, .Int}
		for v, i in d.vals {
			if i >= len(val_types) {
				error(ctx, v, "a range yields at most 2 values")
				break
			}
			inner := v
			if un, is_un := v.derived.(^ast.Unary_Expr); is_un do inner = un.expr
			id, is_ident := inner.derived.(^ast.Ident)
			if !is_ident {
				error(ctx, v, "expected a binding name")
				continue
			}
			append(
				&ctx.scope,
				Variable{name = id.name, type = val_types[i], ident = v},
			)
		}
		typecheck(ctx, {}, d.body)
		for var in ctx.scope[prev:] {
			set_node_data(var.ident, var.flags)
		}
		resize(&ctx.scope, prev)
	case ^ast.Branch_Stmt:
		return &VOID
	case ^ast.Paren_Expr:
		return typecheck(ctx, prop, d.expr)
	case ^ast.Type_Cast:
		if d.tok.kind != .Transmute {
			return error(ctx, node, "TODO: %v", d.tok.text)
		}
		dst := emit_type(ctx, d.type)
		src := typecheck(ctx, {}, d.expr)
		if type_size(dst) != type_size(src.type) {
			return error(
				ctx,
				node,
				"can not transmute %v (%v bytes) into %v (%v bytes)",
				src.type,
				type_size(src.type),
				dst,
				type_size(dst),
			)
		}
		return tmeta(ctx, dst)
	case ^ast.Ident:
		meta := new(Ident_Meta, ctx.types.allocator)
		defer {
			set_ident_meta(d, meta)
		}

		fmt.assertf(len(d.name) != 0, "%v %#v", get_ident_meta(d), d)

		#reverse for &var, i in ctx.scope {
			if var.name == d.name {
				if prop.referencing {
					var.flags |= {.Referenced}
				}
				meta.kind = .Local
				meta.index = i

				if lit, ok := var.idx.(Lit); ok {
					return tcmeta(ctx, var.type, lit)
				}

				return tmeta(ctx, var.type)
			}
		}

		for entry, i in ctx.poly_types {
			if entry.name == d.name {
				meta.kind = .Poly
				meta.index = i
				return new_clone(entry.meta, ctx.types.allocator)
			}
		}

		if mid, ok := ctx.modules[ctx.module].imports[d.name]; ok {
			meta.kind = .Module
			return module_meta(ctx, Module_ID(mid))
		}

		if decl, ok := find_module_decl(ctx, ctx.module, d.name); ok {
			meta.kind = .Decl
			meta.decl = decl
			return integrate_inferrence(ctx, decl, prop.inferred_ty)
		}

		if d.name == "false" || d.name == "true" {
			meta.kind = .Const
			meta.value = i64(d.name == "true")
			return tmeta(ctx, .Bool)
		}

		if d.name == "nil" {
			if prop.inferred_ty == .Void {
				return error(ctx, node, "can not infer the type of nil")
			}
			meta.kind = .Nil
			return tmeta(ctx, prop.inferred_ty)
		}

		if d.name == "_" {
			meta.kind = .Discard
			return &VOID
		}

		for name, kind in TYPE_NAMES {
			if name == d.name {
				meta.kind = .Builtin
				return tpmeta(ctx, kind)
			}
		}

		return error(ctx, node, "undeclared identifier %q", d.name)
	case ^ast.Call_Expr:
		bprc := get_builtin_proc(d.expr)
		switch bprc {
		case .nil:
		case .len:
			args := expect_args(ctx, node, d.args, 1) or_return
			arg_ty := typecheck(ctx, {}, args[0])
			#partial switch t in unpack_type(arg_ty.type) {
			case ^Array, ^Slice, String_Type:
				return tmeta(ctx, .Int)
			}
			return error(
				ctx,
				args[0],
				"can not take the len of a %v",
				arg_ty.type,
			)
		case .raw_data:
			args := expect_args(ctx, node, d.args, 1) or_return
			arg_ty := typecheck(ctx, {}, args[0])
			#partial switch t in unpack_type(arg_ty.type) {
			case ^Slice:
				return tmeta(ctx, intern_multi_pointer(ctx, t.elem))
			case String_Type:
				return tmeta(ctx, intern_multi_pointer(ctx, .U8))
			case Pointer:
				if nt, ok := unpack_type(t^).(^Array); ok {
					return tmeta(ctx, intern_multi_pointer(ctx, nt.elem))
				}
			}
			return error(
				ctx,
				args[0],
				"can not take the raw_data of a %v",
				arg_ty.type,
			)
		case .size_of, .align_of:
			args := expect_args(ctx, node, d.args, 1) or_return
			ty := emit_type(ctx, args[0])
			return tcmeta(
				ctx,
				prop.inferred_ty != .Void ? prop.inferred_ty : .Int,
				{int = i64(bprc == .size_of ? type_size(ty) : type_align(ty))},
			)
		}

		callee := typecheck(ctx, {}, d.expr)

		sig: ^Proc_Type
		proc_id: Proc_ID
		#partial switch v in unpack_type(callee.type) {
		case ^Proc_Type:
			sig = v
			proc_id = callee.lit.procid
			if sig == nil && proc_id == 0 {
				return error(ctx, d.expr, "can not call this expression")
			}
		case Intrinsic_Type:
			switch callee.lit.intrinsic {
			case .syscall:
				for arg in d.args {
					typecheck_as(ctx, .Uintptr, arg)
				}
				return tmeta(ctx, .Uintptr)
			case .trap:
				expect_args(ctx, node, d.args, 0) or_return
				break match
			case .simd_lanes_eq:
				args := expect_args(ctx, node, d.args, 2) or_return
				a := typecheck(ctx, {}, args[0])
				typecheck_as(ctx, a.type, args[1])
				_ = unwrap_type(
					ctx,
					args[0],
					a.type,
					^Simd,
					"expected a #simd vector, found %v",
				) or_return
				return tmeta(ctx, a.type)
			case .simd_extract_lsbs:
				args := expect_args(ctx, node, d.args, 1) or_return
				a := typecheck(ctx, {}, args[0])
				sd := unwrap_type(
					ctx,
					args[0],
					a.type,
					^Simd,
					"expected a #simd vector, found %v",
				) or_return
				bytes := (sd.len + 7) / 8
				return tmeta(ctx, int_type_for_size(bytes))
			case .count_trailing_zeros:
				args := expect_args(ctx, node, d.args, 1) or_return
				a := typecheck(ctx, {inferred_ty = prop.inferred_ty}, args[0])
				if !in_set(a.type, INTEGER_TYPES) {
					return error(
						ctx,
						args[0],
						"expected an integer, found %v",
						a.type,
					)
				}
				return tmeta(ctx, a.type)
			case .simd_reduce_add_bisect:
				args := expect_args(ctx, node, d.args, 1) or_return
				a := typecheck(ctx, {}, args[0])
				sd := unwrap_type(
					ctx,
					args[0],
					a.type,
					^Simd,
					"expected a #simd vector, found %v",
				) or_return
				return tmeta(ctx, sd.elem)
			}
		case Module_Type:
			return error(ctx, d.expr, "can not call a module")
		case Typeid_Type:
			#partial switch t in unpack_type(callee.lit.typeida) {
			case ^Struct:
				if len(d.args) != len(t.param_names) {
					return error(
						ctx,
						node,
						"expected %v type arguments, found %v",
						len(t.param_names),
						len(d.args),
					)
				}
				args := make([]Type, len(d.args))
				for arg, i in d.args {
					args[i] = emit_type(ctx, arg)
				}
				return tpmeta(ctx, instantiate_struct(ctx, t, args))
			case:
				args := expect_args(ctx, node, d.args, 1) or_return
				typecheck(ctx, {}, args[0])
				return tmeta(ctx, callee.lit.typeida)
			}
		case:
			return error(ctx, d.expr, "can not call a %v", callee.type)
		}

		if sig != nil && len(d.args) == 1 && len(d.args) != len(sig.params) {
			typecheck(ctx, {}, d.args[0])
			destructured_sig(ctx, d.args[0], len(sig.params)) or_return
			inner_sig, _ := call_sig(ctx, d.args[0])
			for param, i in sig.params {
				expect(ctx, d.args[0], tmeta(ctx, inner_sig.rets[i]), param)
			}
		} else {
			prc := ctx.procs[proc_id]
			if prc.sig == nil && proc_id != 0 {
				assert(len(prc.polys) == 0)

				prev_polys := len(ctx.poly_types)

				ar_rets: []^ast.Field
				if prc.lit.type.results != nil {
					ar_rets = prc.lit.type.results.list
				}

				params := make([]Type, len(prc.lit.type.params.list))

				if len(d.args) != len(params) {
					return error(
						ctx,
						node,
						"expected %v arguments, found %v",
						len(params),
						len(d.args),
					)
				}

				for param_ast, i in prc.lit.type.params.list {
					if len(param_ast.names) != 1 {
						return error(
							ctx,
							param_ast,
							"TODO: a parameter needs exactly one name",
						)
					}

					inferred_ty := Type.Void
					if !has_polys(ctx, param_ast.type) {
						ast := ast.clone(param_ast.type)
						inferred_ty = emit_type(ctx, ast)
					}

					res: ^Check_Meta
					if poly, ok := param_ast.names[0].derived.(^ast.Poly_Type);
					   ok {
						res = typecheck_eval(
							ctx,
							{inferred_ty = inferred_ty},
							d.args[i],
						)

						append(
							&ctx.poly_types,
							Poly_Entry{poly.type.name, res^},
						)
					} else {
						res = typecheck(
							ctx,
							{inferred_ty = inferred_ty},
							d.args[i],
						)
					}

					if !extract_polys(
						ctx,
						&ctx.poly_types,
						{type = .Typeid, typeida = res.type},
						param_ast.type,
					) {
						return error(
							ctx,
							d.args[i],
							"can not infer the polymorphic parameters from %v",
							res.type,
						)
					}

					params[i] = res.type
				}

				names := ctx.poly_types.name[prev_polys:len(ctx.poly_types)]
				polys := ctx.poly_types.meta[prev_polys:len(ctx.poly_types)]
				if len(polys) == 0 {
					return error(
						ctx,
						d.expr,
						"the polymorphic parameters can not be inferred from the arguments",
					)
				}
				poly_bytes := string(mem.slice_data_cast([]u8, polys))
				key := Proc_Inst_Key{proc_id, poly_bytes}

				existing, ok := ctx.proc_insts[key]
				if !ok {
					name: strings.Builder
					name.buf.allocator = ctx.types.allocator
					append(&name.buf, prc.name)
					for slot in polys {
						if slot.type == .Typeid {
							fmt.sbprintf(&name, " %v", slot.lit.typeida)
						} else {
							fmt.sbprintf(&name, " =%v", slot.lit.int)
						}
					}
					prc.name = string(name.buf[:])
					{context.allocator = ctx.types.allocator
						prc.lit = ast.clone(prc.lit).derived.(^ast.Proc_Lit)
					}

					rets := make([]Type, len(ar_rets))

					ast_rets: []^ast.Field
					if prc.lit.type.results != nil {
						ast_rets = prc.lit.type.results.list
					}

					for ret, i in ast_rets {
						rets[i] = emit_type(ctx, ret.type)
					}

					params = intern_type_slice(ctx, params)
					rets = intern_type_slice(ctx, rets)
					ptype := Proc_Type{params, rets}
					prc.sig = intern_proc_type(ctx, &ptype)

					names = slice.clone(names, ctx.types.allocator)
					polys = slice.clone(polys, ctx.types.allocator)
					prc.polys = soa_zip(name = names, meta = polys)
					key.polys = string(mem.slice_data_cast([]u8, polys))

					existing = Proc_ID(len(ctx.types.procs))
					append(&ctx.types.procs, prc)
					ctx.proc_insts[key] = existing
				}

				sig = ctx.procs[existing].sig

				resize(&ctx.poly_types, prev_polys)

				callee = new_clone(callee^, ctx.types.allocator)
				callee.type = pack_type(sig)
				callee.lit.procid = existing
				set_node_data(d.expr, callee)
			} else {
				args := expect_args(
					ctx,
					node,
					d.args,
					len(sig.params),
				) or_return
				for param, i in sig.params {
					typecheck_as(ctx, param, args[i])
				}
			}
		}

		if sig == nil do return &INVALID
		if len(sig.rets) == 1 do return tmeta(ctx, sig.rets[0])
		return &VOID
	case ^ast.Return_Stmt:
		prc := &ctx.procs[ctx.prc]
		if len(d.results) != len(prc.rets) {
			return error(
				ctx,
				node,
				"expected %v return values, found %v",
				len(prc.rets),
				len(d.results),
			)
		}
		for i in 0 ..< len(d.results) {
			typecheck_as(ctx, prc.rets[i], d.results[i])
		}
	case ^ast.Assign_Stmt:
		if len(d.rhs) == 1 && len(d.lhs) > 1 {
			typecheck(ctx, {}, d.rhs[0])
			sig := destructured_sig(ctx, d.rhs[0], len(d.lhs)) or_return
			for i in 0 ..< len(d.lhs) {
				lhs_ty := typecheck(ctx, {}, d.lhs[i])
				expect(ctx, d.lhs[i], lhs_ty, sig.rets[i])
			}
			return &VOID
		}

		if len(d.lhs) != len(d.rhs) {
			return error(
				ctx,
				node,
				"expected %v values, found %v",
				len(d.lhs),
				len(d.rhs),
			)
		}
		for i in 0 ..< len(d.lhs) {
			lhs_ty := typecheck(ctx, {}, d.lhs[i])
			if is_of(lhs_ty.type, ^Union) {
				rhs_ty := typecheck(ctx, {}, d.rhs[i])
				expect(ctx, d.rhs[i], rhs_ty, lhs_ty.type)
				continue
			}
			typecheck_as(ctx, lhs_ty.type, d.rhs[i])
		}
	case:
		return error(
			ctx,
			node,
			"TODO: %v",
			reflect.union_variant_typeid(node.derived),
		)
	}

	if ty == nil do ty = &VOID

	return
}

Var_Flag :: enum uintptr {
	Referenced,
}

Var_Flags :: bit_set[Var_Flag;uintptr]

get_node_meta :: proc(node: ^ast.Node) -> ^Check_Meta {
	if node == nil do return &VOID
	return get_node_data(node, ^Check_Meta)
}

get_node_type :: proc(node: ^ast.Node) -> Type {
	return get_node_meta(node).type
}

get_node_vflags :: proc(node: ^ast.Node) -> Var_Flags {
	_ = node.derived.(^ast.Ident)
	return get_node_data(node, Var_Flags)
}

get_node_data :: proc(node: ^ast.Node, $T: typeid) -> T {
	return transmute(T)raw_data(node.end.file)
}

set_ident_meta :: proc(node: ^ast.Ident, value: ^Ident_Meta) {
	raw := (^runtime.Raw_Slice)(&node.name)
	raw.data = value
	raw.len = 0
}

get_ident_meta :: proc(node: ^ast.Ident) -> ^Ident_Meta {
	return transmute(^Ident_Meta)raw_data(node.name)
}

set_node_data :: proc(node: ^ast.Node, value: $T) {
	raw := (^runtime.Raw_Slice)(&node.end.file)
	raw.data = transmute(rawptr)value
	raw.len = 0
}

is_num_lit :: proc(node: ^ast.Node) -> bool {
	n := node
	for {
		#partial switch d in n.derived {
		case ^ast.Paren_Expr:
			n = d.expr
			continue
		case ^ast.Unary_Expr:
			if d.op.kind == .Sub || d.op.kind == .Add {
				n = d.expr
				continue
			}
			return false
		case ^ast.Basic_Lit:
			return d.tok.kind == .Integer || d.tok.kind == .Float
		}
		return false
	}
}

is_nil_lit :: proc(node: ^ast.Node) -> bool {
	n := node
	if p, ok := n.derived.(^ast.Paren_Expr); ok do n = p.expr
	id, ok := n.derived.(^ast.Ident)
	return ok && id.name == "nil"
}

is_of :: proc(vl: Type, $K: typeid) -> bool {
	_, ok := unpack_type(vl).(K)
	return ok
}

typecheck_sig :: proc(
	ctx: ^Gen_Ctx,
	prc: ^ast.Proc_Type,
) -> (
	ty: ^Proc_Type,
	concrete: bool,
) {
	if has_polys(ctx, prc) do return

	plist := prc.params.list
	rlist: []^ast.Field
	if prc.results != nil {
		rlist = prc.results.list
	}

	params := make([]Type, len(plist))
	rets := make([]Type, len(rlist))

	lists := [][]^ast.Field{plist, rlist}
	tys := [][]Type{params, rets}

	clear(&ctx.poly_types)
	for list, j in lists {
		tys := tys[j]

		for param, i in list {
			if len(param.names) > 1 {
				error(ctx, param, "TODO: a parameter needs at most one name")
			}

			tys[i] = emit_type(ctx, param.type)
		}
	}

	sig := Proc_Type {
		params = intern_type_slice(ctx, params),
		rets   = intern_type_slice(ctx, rets),
	}

	return intern_proc_type(ctx, &sig), true
}

typecheck_proc :: proc(
	ctx: ^Gen_Ctx,
	mid: Module_ID,
	decl: Maybe(Decl_Key),
	prc: ^ast.Proc_Lit,
) -> Proc_ID {
	context.allocator, _ = arna.scrath()

	isig, generic := typecheck_sig(ctx, prc.type)

	decl := decl.? or_else {}

	assert(prc.type != nil)

	append(
		&ctx.procs,
		Proc {
			name = decl.name,
			lit = prc,
			module = mid,
			file = ctx.file,
			file_id = ctx.file_id,
			sig = isig,
		},
	)

	clear(&ctx.poly_types)

	return Proc_ID(len(ctx.procs) - 1)
}

typecheck_program :: proc(ctx: ^Gen_Ctx) {
	ctx.poly_types.allocator = ctx.types.allocator

	@(static) stt: ast.Proc_Lit
	append(&ctx.procs, Proc{lit = &stt})

	for mid in 0 ..< len(ctx.modules) {
		ctx.module = Module_ID(mid)
		mod := &ctx.modules[mid]

		for &decl in mod.decl_idx {
			if decl.hash == 0 do break

			vl := typecheck_decl(ctx, ctx.module, &decl.id)

			if !decl.id.is_mutable do continue

			size := type_size(vl.type)
			bytes := make([]u8, size, ctx.globals.allocator)

			if decl.id.value.derived != &nil_node {
				value, cok := const_eval_int(decl.id.value)
				if !cok {
					error(
						ctx,
						decl.id.value,
						"TODO: non constant global initializer",
					)
				}
				val_bytes := transmute([8]u8)value
				copy(bytes, val_bytes[:size])
			}

			decl.id.global_idx = add_global(ctx, bytes, type_align(vl.type))
		}
	}

	for i := 1; i < len(ctx.procs); i += 1 {
		prc := ctx.procs[i]
		if prc.sig == nil do continue

		ctx.prc = auto_cast i
		ctx.module = prc.module
		ctx.file = prc.file
		ctx.file_id = prc.file_id
		ctx.mems.scratch.pos = 0
		ctx.scope = make([dynamic]Variable, arna.allocator(&ctx.mems.scratch))

		clear(&ctx.poly_types)
		for e in prc.polys {
			append(&ctx.poly_types, e)
		}

		for par, i in prc.params {
			asta := prc.lit.type.params.list[i]
			if len(asta.names) != 1 do continue

			#partial switch d in asta.names[0].derived {
			case ^ast.Ident:
				append(&ctx.scope, Variable{name = d.name, type = par})
			case ^ast.Poly_Type:
			case:
				error(ctx, asta.names[0], "expected a parameter name")
			}

		}

		typecheck(ctx, {}, prc.lit.body)
	}

}

src_of :: proc(f: ast.File, node: ^ast.Node) -> string {
	if node == nil do return ""
	return f.src[node.pos.offset:node.end.offset]
}

add_global :: proc(ctx: ^Gen_Ctx, bytes: []u8, align: int) -> u32 {
	idx := u32(len(ctx.globals))
	append(&ctx.globals, Global_Data{bytes = bytes, align = align})
	return idx
}
