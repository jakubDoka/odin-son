package typecheck

import "../backend"
import "../backend/builder"
import "../vendored/gam/util/arna"
import "base:runtime"
import "core:fmt"
import "core:hash"
import "core:io"
import "core:log"
import "core:mem"
import "core:odin/ast"
import "core:odin/tokenizer"
import "core:reflect"
import "core:slice"
import "core:strconv"
import "core:strings"

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
	type:     arna.Allocator,
}

Gen_Ctx :: struct {
	using global: ^Global_Ctx,
	using types:  ^Types,
	using graph:  backend.Graph,
	cc:           ^backend.Call_Conv,
	target_spec:  ^backend.Node_Spec,
	node_scope:   backend.Node_ID,
	mem_slot:     int,
	loop:         ^Loop_State,
	file:         ^ast.File,
	file_id:      File_ID,
	module:       Module_ID,
	prc:          Proc_ID,
	ret_ptrs:     []backend.Node_ID,
	poly_types:   #soa[dynamic]Poly_Entry,
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
}

Poly_Data :: struct {
	idx:            int,
	specialization: Type,
}

Check_Meta :: struct {
	type: Type,
	lit:  Lit,
}

Proc_ID :: distinct int

Type :: enum uintptr {
	Void,
	Poly,
	Typeid,
	Intrinsic,
	Module,
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
	case ^Poly_Data:
		fmt.panicf("POLY TODO: %v", ty)
	}
	if ty == .String do return 8
	return TYPE_SIZES[ty]
}

array_elem_stride :: proc(elem: Type) -> int {
	return mem.align_forward_int(type_size(elem), type_align(elem))
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
		return array_elem_stride(t.elem) * t.len
	case ^Slice:
		return 16
	case ^Enum:
		return type_size(t.backing)
	case ^Union:
		return t.size
	case ^Poly_Data:
		fmt.panicf("POLY TODO: %v", ty)
	}
	return TYPE_SIZES[ty]
}

@(rodata)
TYPE_NAMES := #partial [Type]string {
	.Void    = "void",
	.Typeid  = "typeid",
	.Bool    = "bool",
	.Int     = "int",
	.I64     = "i64",
	.I32     = "i32",
	.I16     = "i16",
	.I8      = "i8",
	.Uint    = "uint",
	.U64     = "u64",
	.U32     = "u32",
	.U16     = "u16",
	.U8      = "u8",
	.Uintptr = "uintptr",
	.Rawptr  = "rawptr",
	.String  = "string",
	.F32     = "f32",
	.F64     = "f64",
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
	case ^Poly_Data:
		fmt.panicf("POLY TODO: %v", ty)
	}
	return TYPE_TO_DT[ty]
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
	^Poly_Data,
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
	case ^Poly_Data:
		fmt.wprintf(w, "$poly%v", t.idx)
	case:
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

intern_poly :: proc(ctx: ^Gen_Ctx, poly: Poly_Data) -> Type {
	existing := ctx.polys[poly] or_else new_clone(poly, ctx.types.allocator)
	ctx.polys[poly] = existing
	return pack_type(existing)
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
	args := intern_type_slice(ctx, args)
	key := Struct_Inst_Key{base, string(mem.slice_data_cast([]u8, args))}
	if existing, ok := ctx.struct_insts[key]; ok do return pack_type(existing)

	structa := new(Struct, ctx.types.allocator)
	structa.align = 1
	structa.params = args
	ctx.struct_insts[key] = structa

	polys: [dynamic]Check_Meta
	for fld, i in base.param_names {
		append(&polys, Check_Meta{.Typeid, {typeida = args[i]}})
	}

	structa.fields = make(
		[]Struct_Field,
		len(base.fields),
		ctx.types.allocator,
	)
	for &field, i in structa.fields {
		field = base.fields[i]
		field.ty = instantiate_polys(ctx, polys[:], field.ty) or_else panic("")
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
	lit: Lit
	return new_clone(Check_Meta{ty, lit}, ctx.types.allocator)
}

tpmeta :: proc(ctx: ^Gen_Ctx, ty: Type) -> ^Check_Meta {
	return new_clone(Check_Meta{.Typeid, {typeida = ty}}, ctx.types.allocator)
}

proc_meta :: proc(ctx: ^Gen_Ctx, pid: Proc_ID) -> ^Check_Meta {
	m := new(Check_Meta, ctx.types.allocator)
	m.type = pack_type(ctx.procs[pid].sig)
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
	return new_clone(Check_Meta{inferred, meta.lit}, ctx.types.allocator)
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
	vl := typecheck(
		ctx,
		{
			inferred_ty = ty,
			key = Decl_Key{decl.name, decl.file, u32(decl.value.pos.offset)},
		},
		decl.value,
	)
	assert(vl.type == ty || ty == .Void)

	return vl
}

module_add_decls :: proc(ctx: ^Gen_Ctx, mid: Module_ID, decls: []Decl) {
	mod := &ctx.modules[mid]

	backend.grow_search_space(
		&mod.decl_idx,
		mem.align_forward_int(len(decls), align_of(backend.Intern_Vec)),
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

extract_polys :: proc(
	ctx: ^Gen_Ctx,
	slots: []Check_Meta,
	croot: Type,
	proot: Type,
) -> bool {
	#partial switch t in unpack_type(proot) {
	case Pointer:
		cr := unpack_type(croot).(Pointer) or_return
		return extract_polys(ctx, slots, cr^, t^)
	case Multi_Pointer:
		cr := unpack_type(croot).(Multi_Pointer) or_return
		return extract_polys(ctx, slots, cr^, t^)
	case ^Struct:
		if len(t.params) == 0 do break
		ct := unpack_type(croot).(^Struct) or_return
		for i in 0 ..< len(t.params) {
			extract_polys(ctx, slots, ct.params[i], t.params[i]) or_return
		}
		return true
	case ^Poly_Data:
		if slots[t.idx].lit.typeida != .Void {
			return slots[t.idx].lit.typeida == croot
		}
		slots[t.idx] = {.Typeid, {typeida = croot}}
		if t.specialization != .Void {
			return extract_polys(ctx, slots, croot, t.specialization)
		}
		return true
	}

	return croot == proot
}

instantiate_polys :: proc(
	ctx: ^Gen_Ctx,
	slots: []Check_Meta,
	root: Type,
) -> (
	t: Type,
	ok: bool,
) {
	#partial switch t in unpack_type(root) {
	case Pointer:
		return intern_pointer(
				ctx,
				instantiate_polys(ctx, slots, t^) or_return,
			),
			true
	case Multi_Pointer:
		return intern_multi_pointer(
				ctx,
				instantiate_polys(ctx, slots, t^) or_return,
			),
			true
	case ^Struct:
		if len(t.params) == 0 do return root, true
		new_args := make([]Type, len(t.params), context.temp_allocator)
		for a, i in t.params {
			new_args[i] = instantiate_polys(ctx, slots, a) or_return
		}
		return instantiate_struct(ctx, t, new_args), true
	case ^Poly_Data:
		if slots[t.idx].type == .Void {
			return {}, false
		}
		assert(slots[t.idx].type == .Typeid)
		return slots[t.idx].lit.typeida, true
	}
	return root, true
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
	fmt.assertf(
		res.type == .Typeid || res.type == .Void,
		"%v %#v",
		res.type,
		expr.derived,
	)
	return res.lit.typeida
}

Proc :: struct {
	name:        string,
	param_names: []string,
	ret_names:   []string,
	poly_names:  []string,
	poly_values: []Check_Meta,
	param_types: []backend.Node_Datatype,
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

Varuable_Idx :: union #no_nil {
	int,
	backend.Node_ID,
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
	polys: ^Proc_Type,
}

Types :: struct {
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
	slices:         map[Slice]^Slice,
	polys:          map[Poly_Data]^Poly_Data,
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
	types.polys.allocator = types.allocator
	types.proc_types.allocator = types.allocator
	types.type_slices.allocator = types.allocator
	types.globals.allocator = types.allocator
	types.global_vars.allocator = types.allocator
	types.scope.allocator = types.allocator
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
	name:   string,
	ty:     Type,
	offset: int,
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

typecheck :: proc(
	ctx: ^Gen_Ctx,
	prop: Ty_Propagation,
	node: ^ast.Node,
) -> (
	ty: ^Check_Meta,
) {
	context.allocator, _ = arna.scrath()

	if node == nil do return &VOID

	defer {
		set_node_data(node, ty)
	}

	#partial switch d in node.derived {
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
				d := param.derived.(^ast.Field).names[0].derived.(^ast.Poly_Type)
				res := intern_poly(ctx, Poly_Data{len(ctx.poly_types), .Void})
				append(
					&ctx.poly_types,
					Poly_Entry{d.type.name, {.Typeid, {typeida = res}}},
				)
				structa.param_names[i] = d.type.name
			}
		}

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
			if d.poly_params == nil {
				field.offset = mem.align_forward_int(
					structa.size,
					type_align(field.ty),
				)
				structa.size = field.offset + type_size(field.ty)
				structa.align = max(structa.align, type_align(field.ty))
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
				vname = fd.field.derived.(^ast.Ident).name
				cv, cok := const_eval_int(fd.value)
				assert(cok)
				vval = cv
			case:
				fmt.panicf("TODO: enum field %#v", f.derived)
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
		len_node := d.len
		if len_ident, is_ident := len_node.derived.(^ast.Ident); is_ident {
			if sdecl, ok := find_module_decl(ctx, ctx.module, len_ident.name);
			   ok {
				len_node = sdecl.value
			}
		}
		len_lit := len_node.derived.(^ast.Basic_Lit)
		assert(len_lit.tok.kind == .Integer)
		length, ok := strconv.parse_int(len_lit.tok.text)
		assert(ok)
		return tpmeta(ctx, intern_array(ctx, elem, length))
	case ^ast.Poly_Type:
		res := intern_poly(
			ctx,
			Poly_Data{len(ctx.poly_types), emit_type(ctx, d.specialization)},
		)
		append(
			&ctx.poly_types,
			Poly_Entry{d.type.name, {.Typeid, {typeida = res}}},
		)
		return tpmeta(ctx, res)
	case ^ast.Proc_Type:
		sig, _, _ := typecheck_sig(ctx, d)
		return tpmeta(ctx, pack_type(sig))
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
		if len(d.values) == 1 && len(d.names) > 1 {
			typecheck(ctx, {}, d.values[0])
			sig, ok := call_sig(ctx, d.values[0])
			assert(ok)
			assert(len(sig.rets) == len(d.names))
			rabi := ret_abi(sig.rets)

			for i in 0 ..< len(d.names) {
				name := src_of(ctx.file^, d.names[i])
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
			assert(inferred_ty != .Void)
			flags: Var_Flags
			if type_to_dt(inferred_ty) == .Void do flags |= {.Referenced}
			for i in 0 ..< len(d.names) {
				name := src_of(ctx.file^, d.names[i])
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

		assert(len(d.names) == len(d.values))

		for i in 0 ..< len(d.names) {
			name := src_of(ctx.file^, d.names[i])

			if u, ok := unpack_type(inferred_ty).(^Union); ok {
				value_ty := typecheck(ctx, {}, d.values[i])
				if value_ty.type != inferred_ty {
					_, found := union_variant_index(u, value_ty.type)
					fmt.assertf(
						found,
						"%v is not a variant of %v",
						value_ty.type,
						inferred_ty,
					)
				}
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

			value_ty := typecheck(
				ctx,
				{inferred_ty = inferred_ty},
				d.values[i],
			)
			if inferred_ty != .Void {
				assert(value_ty.type == inferred_ty)
			}
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
		#partial switch d.tok.kind {
		case .Integer, .Rune:
			fmt.assertf(
				prop.inferred_ty == .Void ||
				prop.inferred_ty in INTEGER_TYPES ||
				prop.inferred_ty in FLOAT_TYPES,
				"TODO: missing literal typecheck %#v, inferred_ty: %v",
				d,
				prop.inferred_ty,
			)
			return tmeta(
				ctx,
				prop.inferred_ty != .Void ? prop.inferred_ty : .Int,
			)
		case .Float:
			assert(
				prop.inferred_ty == .Void || prop.inferred_ty in FLOAT_TYPES,
			)
			return tmeta(
				ctx,
				prop.inferred_ty != .Void ? prop.inferred_ty : .F64,
			)
		case .String:
			return tmeta(ctx, .String)
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
					name := src_of(ctx.file^, e.field)
					for &field in t.fields {
						if field.name == name {
							set_node_data(e.field, field.offset)
							fty := typecheck(
								ctx,
								{inferred_ty = field.ty},
								e.value,
							)
							fmt.assertf(
								fty.type == field.ty,
								"%v == %v %#v",
								fty.type,
								field.ty,
								e.value.derived,
							)
						}
					}
				case:
					field := t.fields[i]
					fty := typecheck(ctx, {inferred_ty = field.ty}, elem)
					assert(fty.type == field.ty)
				}
			}

			return tmeta(ctx, inferred_ty)
		case ^Array:
			for elem in d.elems {
				ety := typecheck(ctx, {inferred_ty = t.elem}, elem)
				assert(ety.type == t.elem)
			}
			return tmeta(ctx, inferred_ty)
		case:
			fmt.panicf("TODO: %v %#v", unpack_type(inferred_ty), d)
		}
	case ^ast.Index_Expr:
		base := typecheck(ctx, {}, d.expr)
		typecheck(ctx, {inferred_ty = .Int}, d.index)
		#partial switch t in unpack_type(base.type) {
		case ^Array:
			return tmeta(ctx, t.elem)
		case ^Slice:
			return tmeta(ctx, t.elem)
		case String_Type:
			return tmeta(ctx, .U8)
		case Pointer:
			#partial switch nt in unpack_type(t^) {
			case ^Array:
				return tmeta(ctx, intern_multi_pointer(ctx, nt.elem))
			case:
				fmt.panicf("TODO: index ptr to type of %#v", t)
			}
		case Multi_Pointer:
			return tmeta(ctx, t^)
		case:
			fmt.panicf("TODO: %#v", t)
		}
	case ^ast.Slice_Expr:
		base := typecheck(ctx, {}, d.expr)
		typecheck(ctx, {inferred_ty = .Int}, d.low)
		typecheck(ctx, {inferred_ty = .Int}, d.high)
		#partial switch t in unpack_type(base.type) {
		case ^Array:
			return tmeta(ctx, intern_slice(ctx, t.elem))
		case ^Slice:
			return base
		case String_Type:
			return tmeta(ctx, .String)
		case Pointer:
			#partial switch nt in unpack_type(t^) {
			case ^Array:
				return tmeta(ctx, intern_multi_pointer(ctx, nt.elem))
			case:
				fmt.panicf("TODO: slice ptr to type of %#v", t)
			}
		case Multi_Pointer:
			if d.high == nil do return base
			return tmeta(ctx, intern_slice(ctx, t^))
		case:
			fmt.panicf("TODO: %#v", t)
		}
	case ^ast.Selector_Expr:
		base := typecheck(ctx, {}, d.expr)

		#partial switch f in d.field.derived {
		case ^ast.Ident:
			if base.type == .Module {
				mid := base.lit.module
				if mid == MODULE_INTRINSICS {
					return intrinsic_meta(
						ctx,
						reflect.enum_from_name(
							Intrinsic,
							f.name,
						) or_else panic(""),
					)
				}

				pid, pok := find_module_decl(ctx, mid, f.name)
				fmt.assertf(
					pok,
					"module %q has no symbol %q",
					ctx.modules[mid].name,
					f.name,
				)
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
				fmt.panicf("enum has no variant %q", f.name)
			case ^Struct:
				for &field in t.fields {
					if field.name == f.name {
						assert(field.ty != .Void)
						set_node_data(d.field, field.offset)
						return tmeta(ctx, field.ty)
					}
				}
				fmt.panicf("TODO: field not found %v %v", base_ty, f.name)
			case:
				fmt.panicf("TODO: %#v", t)
			}
		case:
			fmt.panicf("TODO: %#v", d.field.derived)
		}
	case ^ast.Implicit_Selector_Expr:
		e, ok := unpack_type(prop.inferred_ty).(^Enum)
		fmt.assertf(
			ok,
			"implicit selector needs enum context: %v",
			prop.inferred_ty,
		)
		for v in e.variants {
			if v.name == d.field.name {
				set_node_data(d.field, int(v.value))
				return tmeta(ctx, prop.inferred_ty)
			}
		}
		fmt.panicf("enum has no variant %q", d.field.name)
	case ^ast.Type_Assertion:
		base := typecheck(ctx, {}, d.expr)
		u, ok := unpack_type(base.type).(^Union)
		assert(ok)
		target := emit_type(ctx, d.type)
		_, found := union_variant_index(u, target)
		fmt.assertf(found, "type %v is not a variant of %v", target, base.type)
		return tmeta(ctx, target)
	case ^ast.Binary_Expr:
		is_comparison :=
			.B_Comparison_Begin < d.op.kind && d.op.kind < .B_Comparison_End

		if is_nil_lit(d.left) || is_nil_lit(d.right) {
			operand := is_nil_lit(d.left) ? d.right : d.left
			oty := typecheck(ctx, {}, operand)
			assert(is_of(oty.type, ^Union))
			return tmeta(ctx, .Bool)
		}

		if is_num_lit(d.left) &&
		   !is_num_lit(d.right) &&
		   prop.inferred_ty == .Void {
			rhs_ty := typecheck(ctx, {}, d.right)
			lhs_ty := typecheck(ctx, {inferred_ty = rhs_ty.type}, d.left)
			assert(lhs_ty.type == rhs_ty.type)
			return is_comparison ? tmeta(ctx, .Bool) : rhs_ty
		}

		lhs_ty := typecheck(ctx, prop, d.left)
		inferred_ty := lhs_ty.type
		if d.op.kind == .Shl || d.op.kind == .Shr {
			inferred_ty = .Uint
		}
		rhs_ty := typecheck(ctx, {inferred_ty = inferred_ty}, d.right)
		fmt.assertf(
			inferred_ty == rhs_ty.type,
			"%v == %v %#v",
			inferred_ty,
			rhs_ty.type,
			d,
		)

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

			inner_ty := typecheck(
				ctx,
				{inferred_ty = inferred_ty, referencing = true},
				d.expr,
			)
			if inferred_ty != .Void {
				fmt.assertf(
					inferred_ty == inner_ty.type,
					"%v == %v",
					inferred_ty,
					inner_ty.type,
				)
			}
			return tmeta(ctx, intern_pointer(ctx, inner_ty.type))
		case .Not:
			inner_ty := typecheck(ctx, {}, d.expr)
			assert(inner_ty.type == .Bool)
			return tmeta(ctx, .Bool)
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

		inner := typecheck(ctx, {inferred_ty = inferred_ty}, d.expr)
		return tmeta(ctx, unpack_type(inner.type).(Pointer)^)
	case ^ast.Expr_Stmt:
		return typecheck(ctx, {}, d.expr)
	case ^ast.If_Stmt:
		cond_ty := typecheck(ctx, {}, d.cond)
		assert(cond_ty.type == .Bool)
		typecheck(ctx, {}, d.body)
		typecheck(ctx, {}, d.else_stmt)
		return &VOID
	case ^ast.Switch_Stmt:
		assert(d.init == nil)
		cond_ty := typecheck(ctx, {}, d.cond)
		body := d.body.derived.(^ast.Block_Stmt)
		for clause_node in body.stmts {
			clause := clause_node.derived.(^ast.Case_Clause)
			for v in clause.list {
				typecheck(ctx, {inferred_ty = cond_ty.type}, v)
			}
			prev := len(ctx.scope)
			for stmt in clause.body do typecheck(ctx, {}, stmt)
			resize(&ctx.scope, prev)
		}
		return &VOID
	case ^ast.Type_Switch_Stmt:
		tag := d.tag.derived.(^ast.Assign_Stmt)
		binding := src_of(ctx.file^, tag.lhs[0])
		union_ty := typecheck(ctx, {}, tag.rhs[0])
		assert(is_of(union_ty.type, ^Union))
		body := d.body.derived.(^ast.Block_Stmt)
		for clause_node in body.stmts {
			clause := clause_node.derived.(^ast.Case_Clause)
			bind_ty := union_ty.type
			if len(clause.list) > 0 {
				bind_ty = emit_type(ctx, clause.list[0])
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
		assert(d.init == nil)
		assert(d.cond == nil)
		assert(d.post == nil)

		typecheck(ctx, {}, d.body)
	case ^ast.Branch_Stmt:
		return &VOID
	case ^ast.Paren_Expr:
		return typecheck(ctx, prop, d.expr)
	case ^ast.Ident:
		name := d.name
		#reverse for &var in ctx.scope {
			if var.name == name {
				if prop.referencing {
					var.flags |= {.Referenced}
				}
				return tmeta(ctx, var.type)
			}
		}

		for entry in ctx.poly_types {
			if entry.name == d.name {
				return new_clone(entry.meta, ctx.types.allocator)
			}
		}

		if mid, ok := ctx.modules[ctx.module].imports[name]; ok {
			return module_meta(ctx, Module_ID(mid))
		}

		if decl, ok := find_module_decl(ctx, ctx.module, name); ok {
			return integrate_inferrence(ctx, decl, prop.inferred_ty)
		}

		if name == "false" || name == "true" {
			return tmeta(ctx, .Bool)
		}

		if name == "nil" {
			assert(prop.inferred_ty != .Void)
			return tmeta(ctx, prop.inferred_ty)
		}

		if name == "_" {
			return &VOID
		}

		for name, kind in TYPE_NAMES {
			if name == d.name do return tpmeta(ctx, kind)
		}

		fmt.panicf("TODO: %#v", node.derived)
	case ^ast.Call_Expr:
		switch get_builtin_proc(d.expr) {
		case .nil:
		case .len:
			assert(len(d.args) == 1)
			arg_ty := typecheck(ctx, {}, d.args[0])
			#partial switch t in unpack_type(arg_ty.type) {
			case ^Array, ^Slice:
			case String_Type:
			case:
				fmt.panicf("TODO: len of %#v", t)
			}
			return tmeta(ctx, .Int)
		case .raw_data:
			assert(len(d.args) == 1)
			arg_ty := typecheck(ctx, {}, d.args[0])
			#partial switch t in unpack_type(arg_ty.type) {
			case ^Slice:
				return tmeta(ctx, intern_multi_pointer(ctx, t.elem))
			case String_Type:
				return tmeta(ctx, intern_multi_pointer(ctx, .U8))
			case Pointer:
				#partial switch nt in unpack_type(t^) {
				case ^Array:
					return tmeta(ctx, intern_multi_pointer(ctx, nt.elem))
				case:
					fmt.panicf("TODO: raw_data of of %#v", t)
				}
			case:
				fmt.panicf("TODO: raw_data of of %#v", t)
			}
		case .size_of, .align_of:
			assert(len(d.args) == 1)
			ty := emit_type(ctx, d.args[0])
			return tmeta(
				ctx,
				prop.inferred_ty != .Void ? prop.inferred_ty : .Int,
			)
		}

		callee := typecheck(ctx, {}, d.expr)

		sig: ^Proc_Type
		proc_id: Proc_ID
		#partial switch v in unpack_type(callee.type) {
		case ^Proc_Type:
			sig = v
			proc_id = callee.lit.procid
		case Intrinsic_Type:
			switch callee.lit.intrinsic {
			case .syscall:
				for arg in d.args {
					pty := typecheck(ctx, {inferred_ty = .Uintptr}, arg)
					fmt.assertf(
						pty.type == .Uintptr,
						"%v, %#v",
						pty.type,
						arg.derived,
					)
				}
				return tmeta(ctx, .Uintptr)
			}
		case Module_Type:
			fmt.panicf("Cant call a module")
		case Typeid_Type:
			#partial switch t in unpack_type(callee.lit.typeida) {
			case ^Struct:
				args := make([]Type, len(d.args), context.temp_allocator)
				for arg, i in d.args {
					args[i] = emit_type(ctx, arg)
				}
				return tpmeta(ctx, instantiate_struct(ctx, t, args))
			case:
				assert(len(d.args) == 1)
				typecheck(ctx, {}, d.args[0])
				return tmeta(ctx, callee.lit.typeida)
			}
		}

		if len(d.args) == 1 && len(d.args) != len(sig.params) {
			typecheck(ctx, {}, d.args[0])
			inner_sig, ok := call_sig(ctx, d.args[0])
			assert(ok)
			assert(len(inner_sig.rets) == len(sig.params))
			for param, i in sig.params {
				assert(param == inner_sig.rets[i])
			}
		} else {
			assert(len(sig.params) == len(d.args))
			prc := ctx.procs[proc_id]
			if len(prc.poly_names) != 0 {
				assert(len(prc.poly_values) == 0)
				polys := make([]Check_Meta, len(prc.poly_names))

				params := make([]Type, len(prc.params))
				rets := make([]Type, len(prc.rets))

				for param, i in sig.params {
					inferred_ty: Type
					inferred_ty =
						instantiate_polys(
							ctx,
							polys,
							param,
						) or_else inferred_ty

					pty := typecheck(
						ctx,
						{inferred_ty = inferred_ty},
						d.args[i],
					)
					ok := extract_polys(ctx, polys, pty.type, param)
					assert(ok)
					params[i] = pty.type
				}

				for poly in polys {
					assert(poly.type != .Void)
				}

				for ret, i in sig.rets {
					rets[i] =
						instantiate_polys(ctx, polys, ret) or_else panic("")
				}

				params = intern_type_slice(ctx, params)
				rets = intern_type_slice(ctx, rets)
				ptype := Proc_Type{params, rets}
				sig = intern_proc_type(ctx, &ptype)

				key := Proc_Inst_Key{proc_id, sig}

				existing, ok := ctx.proc_insts[key]
				if !ok {
					name: strings.Builder
					name.buf.allocator = ctx.types.allocator
					append(&name.buf, prc.name)
					for slot in polys {
						assert(slot.type == .Typeid)
						fmt.sbprintf(&name, " %v", slot.lit.typeida)
					}
					prc.name = string(name.buf[:])
					prc.sig = sig
					{context.allocator = ctx.types.allocator
						prc.lit = ast.clone(prc.lit).derived.(^ast.Proc_Lit)
					}
					prc.poly_values = slice.clone(polys, ctx.types.allocator)
					existing = Proc_ID(len(ctx.types.procs))
					append(&ctx.types.procs, prc)
					ctx.proc_insts[key] = existing
				}

				callee = new_clone(callee^, ctx.types.allocator)
				callee.type = pack_type(sig)
				callee.lit.procid = existing
				set_node_data(d.expr, callee)
			} else {
				for param, i in sig.params {
					pty := typecheck(ctx, {inferred_ty = param}, d.args[i])
					fmt.assertf(
						pty.type == param,
						"%v == %v %#v",
						pty.type,
						param,
						d.args[i],
					)
				}
			}
		}

		if len(sig.rets) == 1 do return tmeta(ctx, sig.rets[0])
		return &VOID
	case ^ast.Return_Stmt:
		prc := &ctx.procs[ctx.prc]
		assert(len(d.results) == len(prc.rets))
		for i in 0 ..< len(d.results) {
			typecheck(ctx, {inferred_ty = prc.rets[i]}, d.results[i])
		}
	case ^ast.Assign_Stmt:
		if len(d.rhs) == 1 && len(d.lhs) > 1 {
			typecheck(ctx, {}, d.rhs[0])
			sig, ok := call_sig(ctx, d.rhs[0])
			assert(ok)
			assert(len(sig.rets) == len(d.lhs))
			for i in 0 ..< len(d.lhs) {
				lhs_ty := typecheck(ctx, {}, d.lhs[i])
				assert(lhs_ty.type == sig.rets[i])
			}
			return &VOID
		}

		assert(len(d.lhs) == len(d.rhs))
		for i in 0 ..< len(d.lhs) {
			lhs_ty := typecheck(ctx, {}, d.lhs[i])
			if u, ok := unpack_type(lhs_ty.type).(^Union); ok {
				rhs_ty := typecheck(ctx, {}, d.rhs[i])
				if rhs_ty.type != lhs_ty.type {
					_, found := union_variant_index(u, rhs_ty.type)
					fmt.assertf(
						found,
						"%v is not a variant of %v",
						rhs_ty.type,
						lhs_ty.type,
					)
				}
				continue
			}
			typecheck(ctx, {inferred_ty = lhs_ty.type}, d.rhs[i])
		}
	case:
		fmt.panicf("TODO: %#v", node.derived)
	}

	if ty == nil do ty = &VOID

	return
}

Var_Flag :: enum uintptr {
	Referenced,
}

Var_Flags :: bit_set[Var_Flag;uintptr]

get_node_meta :: proc(node: ^ast.Node) -> ^Check_Meta {
	return get_node_data(node, ^Check_Meta)
}

get_node_type :: proc(node: ^ast.Node) -> Type {
	return get_node_meta(node).type
}

// is_builtin reports whether `ty` is one of the zero sized builtin types (the
// low, data less variants of Type_Data), i.e. it is stored as the bare enum
// value.
is_builtin :: proc(ty: Type) -> bool {
	return Raw_Type(ty).tag < len(reflect.enum_field_names(Type))
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

init_single_file_program :: proc(ctx: ^Gen_Ctx, f: ^ast.File) {
	ctx.files.allocator = ctx.types.allocator
	ctx.modules.allocator = ctx.types.allocator
	if f.pkg_name == "" do f.pkg_name = "main"
	append(&ctx.files, f^)
	append(&ctx.modules, Module{name = f.pkg_name, file_count = 1})

	decls := make([dynamic]Decl, context.temp_allocator)
	collect_decls(f^, &decls, 0)
	module_add_decls(ctx, 0, decls[:])
}

typecheck_sig :: proc(
	ctx: ^Gen_Ctx,
	prc: ^ast.Proc_Type,
) -> (
	^Proc_Type,
	[]string,
	[]string,
) {
	plist := prc.params.list
	rlist: []^ast.Field
	if prc.results != nil {
		rlist = prc.results.list
	}

	params := make([]Type, len(plist))
	param_names := make([]string, len(plist), ctx.types.allocator)
	rets := make([]Type, len(rlist))
	ret_names := make([]string, len(rlist), ctx.types.allocator)

	lists := [][]^ast.Field{plist, rlist}
	tys := [][]Type{params, rets}
	names := [][]string{param_names, ret_names}

	clear(&ctx.poly_types)
	for list, j in lists {
		tys := tys[j]
		names := names[j]

		for param, i in list {
			assert(len(param.names) <= 1)
			pname := ""
			if len(param.names) == 1 {
				pname = src_of(ctx.file^, param.names[0])
			}

			tys[i] = emit_type(ctx, param.type)
			names[i] = pname
		}
	}

	sig := Proc_Type {
		params = intern_type_slice(ctx, params),
		rets   = intern_type_slice(ctx, rets),
	}

	return intern_proc_type(ctx, &sig), param_names, ret_names
}

typecheck_proc :: proc(
	ctx: ^Gen_Ctx,
	mid: Module_ID,
	decl: Maybe(Decl_Key),
	prc: ^ast.Proc_Lit,
) -> Proc_ID {
	context.allocator, _ = arna.scrath()

	isig, param_names, ret_names := typecheck_sig(ctx, prc.type)

	decl := decl.? or_else {}

	append(
		&ctx.procs,
		Proc {
			name = decl.name,
			lit = prc,
			module = mid,
			poly_names = slice.clone(
				ctx.poly_types.name[:len(ctx.poly_types)],
				ctx.types.allocator,
			),
			file = ctx.file,
			file_id = ctx.file_id,
			sig = isig,
			param_names = param_names,
			ret_names = ret_names,
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
					fmt.panicf(
						"TODO: non-constant global initializer: %v",
						decl.id.name,
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
		ctx.prc = auto_cast i
		ctx.module = prc.module
		ctx.file = prc.file
		ctx.file_id = prc.file_id
		ctx.mems.scratch.pos = 0
		ctx.scope = make([dynamic]Variable, arna.allocator(&ctx.mems.scratch))

		if len(prc.poly_names) != 0 && len(prc.poly_values) == 0 do continue

		clear(&ctx.poly_types)
		assert(len(prc.poly_names) == len(prc.poly_values))
		for i in 0 ..< len(prc.poly_names) {
			append(
				&ctx.poly_types,
				Poly_Entry{prc.poly_names[i], prc.poly_values[i]},
			)
		}

		for par, i in prc.params {
			append(&ctx.scope, Variable{name = prc.param_names[i], type = par})
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
