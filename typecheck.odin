package main

import "backend"
import "base:runtime"
import "core:fmt"
import "core:io"
import "core:mem"
import "core:odin/ast"
import "core:odin/tokenizer"
import "core:reflect"
import "core:slice"
import "core:strconv"
import "meta"
import "vendored/gam/util/arna"

Lit :: union {
	Proc_ID,
	Module_ID,
	Intrinsic,
}

Proc_ID :: distinct int

Type :: enum uintptr {
	Void,
	Typeid,
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
TYPE_SIZES := [Type]int {
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
	switch t in unpack_type(ty) {
	case Builtin:
		if ty == .String do return 8
		return TYPE_SIZES[ty]
	case Pointer, Multi_Pointer:
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
	case Pointer, Multi_Pointer:
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
	case ^Lit:
		panic("we should not be type type")
	case:
		panic("wuwut")
	}
}

@(rodata)
TYPE_NAMES := [Type]string {
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
	TYPE_TO_DT := [Type]backend.Node_Datatype {
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

	switch t in unpack_type(ty) {
	case Builtin:
		assert(int(ty) < len(TYPE_TO_DT))
		return TYPE_TO_DT[ty]
	case Pointer, Multi_Pointer:
		return .I64
	case ^Enum:
		return type_to_dt(t.backing)
	case ^Lit, ^Struct, ^Array, ^Slice, ^Union:
		return .Void
	case:
		panic("wuwut")
	}
}

UNSIGNED_TYPES :: bit_set[Type]{.Uint, .U64, .U32, .U16, .U8, .Bool, .Uintptr}
SIGNED_TYPES :: bit_set[Type]{.Int, .I64, .I32, .I16, .I8}
INTEGER_TYPES :: UNSIGNED_TYPES | SIGNED_TYPES
FLOAT_TYPES :: bit_set[Type]{.F32, .F64}

Type_Kind :: enum uintptr {
	Builtin,
	Pointer,
	Struct,
	Array,
	Slice,
	Lit,
	Enum,
	Union,
}

Raw_Type :: bit_field uintptr {
	data: uintptr   | 48,
	tag:  Type_Kind | 16,
}

Multi_Pointer :: distinct ^Type
Pointer :: distinct ^Type
Builtin :: distinct Type

Type_Data :: union #no_nil {
	Builtin,
	Pointer,
	Multi_Pointer,
	^Struct,
	^Array,
	^Slice,
	^Lit,
	^Enum,
	^Union,
}

Raw_Type_Data :: struct {
	data: uintptr,
	tag:  Type_Kind,
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
	switch t in unpack_type(ty) {
	case Builtin:
		fmt.wprint(w, TYPE_NAMES[Type(t)])
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
	case ^Lit:
		fmt.wprintf(w, "lit(%v)", t^)
	}
}

pack_type :: proc(typ: Type_Data) -> Type {
	raw := transmute(Raw_Type_Data)typ
	return Type(Raw_Type{tag = raw.tag, data = raw.data})
}

unpack_type :: proc(typ: Type) -> Type_Data {
	raw := Raw_Type(typ)
	return transmute(Type_Data)Raw_Type_Data{data = raw.data, tag = raw.tag}
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

find_module_decl :: proc(
	ctx: ^Gen_Ctx,
	mod: Module_ID,
	name: string,
) -> (
	sdecl: ^ast.Value_Decl,
	f: ^ast.File,
	fid: File_ID,
	ok: bool,
) {
	module := &ctx.modules[mod]
	for i in 0 ..< module.file_count {
		file := &ctx.files[module.file_start + i]
		for decl in file.decls {
			sd := decl.derived_stmt.(^ast.Value_Decl) or_continue
			if len(sd.names) == 0 do continue
			if meta.src_of(file^, sd.names[0]) == name {
				return sd, file, File_ID(module.file_start + i), true
			}
		}
	}
	return
}

// find_module_proc returns the global Proc_ID of a procedure named `name`
// defined directly in `mod`, if any.
find_module_proc :: proc(
	ctx: ^Gen_Ctx,
	mod: Module_ID,
	name: string,
) -> (
	Proc_ID,
	bool,
) {
	m := ctx.modules[mod]
	for i in m.proc_start ..< m.proc_start + m.proc_count {
		if ctx.procs[i].name == name do return Proc_ID(i), true
	}
	return 0, false
}

// find_module_global returns the global variable named `name` defined directly
// in `mod`, if any.
find_module_global :: proc(
	ctx: ^Gen_Ctx,
	mod: Module_ID,
	name: string,
) -> (
	^Global_Var,
	bool,
) {
	for &g in ctx.global_vars {
		if g.module == mod && g.name == name do return &g, true
	}
	return nil, false
}

emit_type :: proc(
	ctx: ^Gen_Ctx,
	expr: ^ast.Node,
	key: Maybe(Decl_Key) = nil,
) -> (
	ret: Type,
) {
	if expr == nil do return .Void

	intern_decl :: proc(
		mapa: ^map[Decl_Key]^$T,
		key: Maybe(Decl_Key),
		ret: ^Type,
	) -> (
		^T,
		bool,
	) {
		if key, ok := key.?; ok {
			record, ok := mapa[key]
			ret^ = pack_type(record)
			if ok do return nil, false
		}
		record := new(T, mapa.allocator)
		if key, ok := key.?; ok do mapa[key] = record
		return record, true
	}

	#partial switch d in expr.derived {
	case ^ast.Ident:
		if sdecl, dfile, dfid, ok := find_module_decl(ctx, ctx.module, d.name);
		   ok {
			key := Decl_Key{dfid, u32(sdecl.pos.offset)}
			return emit_type(ctx, sdecl.values[0], key)
		}

		for name, kind in TYPE_NAMES {
			if name == d.name do return kind
		}

		fmt.panicf("TODO: %#v", expr.derived)
	case ^ast.Struct_Type:
		structa := intern_decl(&ctx.structs, key, &ret) or_break

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
		structa.size = mem.align_forward_int(structa.size, structa.align)
		return pack_type(structa)
	case ^ast.Enum_Type:
		e := intern_decl(&ctx.enums, key, &ret) or_break

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
		return pack_type(e)
	case ^ast.Union_Type:
		u := intern_decl(&ctx.unions, key, &ret) or_break

		Geneva :: struct($T: typeid) {
			v: T,
		}

		v := Geneva(u8){}

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
		return pack_type(u)
	case ^ast.Multi_Pointer_Type:
		return intern_multi_pointer(ctx, emit_type(ctx, d.elem))
	case ^ast.Pointer_Type:
		return intern_pointer(ctx, emit_type(ctx, d.elem))
	case ^ast.Array_Type:
		elem := emit_type(ctx, d.elem)
		if d.len == nil {
			return intern_slice(ctx, elem)
		}
		len_node := d.len
		if len_ident, is_ident := len_node.derived.(^ast.Ident); is_ident {
			if sdecl, _, _, ok := find_module_decl(
				ctx,
				ctx.module,
				len_ident.name,
			); ok {
				len_node = sdecl.values[0]
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

	return
}

Proc :: struct {
	name:      string,
	using sig: Signature,
	lit:       ^ast.Proc_Lit,
	module:    Module_ID,
	file:      ^ast.File,
	file_id:   File_ID,
	out:       backend.Codegen_Output,
}

Signature :: struct {
	params: []Param,
	rets:   []Param,
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
	extras:      []Param,
	srets_start: int,
	reg_rets:    []Param,
}

ret_abi :: proc(rets: []Param) -> (rabi: Ret_ABI) {
	if len(rets) == 0 do return
	last := rets[len(rets) - 1]
	is_sret := int(type_size(last.type) > 16)
	rabi.extras = rets[:len(rets) - 1 + is_sret]
	rabi.srets_start = len(rabi.extras) - is_sret
	rabi.reg_rets = rets[len(rabi.extras):]

	return
}

ret_is_by_pointer :: proc(abi: Ret_ABI, idx: int) -> bool {
	return idx < len(abi.extras) || abi.srets_start < len(abi.extras)
}

call_sig :: proc(ctx: ^Gen_Ctx, node: ^ast.Node) -> (Signature, bool) {
	call, cok := node.derived.(^ast.Call_Expr)
	if !cok do return {}, false
	if id, iok := call.expr.derived.(^ast.Ident); iok && id.name == "len" {
		return {}, false
	}
	lit, lok := unpack_type(typecheck(ctx, {}, call.expr)).(^Lit)
	if !lok do return {}, false
	pid, pok := lit.(Proc_ID)
	if !pok do return {}, false
	return ctx.procs[pid].sig, true
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

Module :: struct {
	name:       string,
	dir:        string,
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

Types :: struct {
	tstats:         backend.Stats,
	mems:           Mems,
	allocator:      runtime.Allocator,
	procs:          [dynamic]Proc,
	scope:          [dynamic]Variable,
	pointers:       map[Type]Pointer,
	multi_pointers: map[Type]Multi_Pointer,
	structs:        map[Struct_Key]^Struct,
	enums:          map[Struct_Key]^Enum,
	unions:         map[Struct_Key]^Union,
	arrays:         map[Array_Key]^Array,
	slices:         map[Type]^Slice,
	lits:           map[Lit]^Lit,
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
	types.pointers.allocator = types.allocator
	types.multi_pointers.allocator = types.allocator
	types.structs.allocator = types.allocator
	types.enums.allocator = types.allocator
	types.unions.allocator = types.allocator
	types.arrays.allocator = types.allocator
	types.slices.allocator = types.allocator
	types.lits.allocator = types.allocator
	types.globals.allocator = types.allocator
	types.global_vars.allocator = types.allocator
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

Enum :: struct {
	backing:  Type,
	variants: []Enum_Variant,
}

Enum_Variant :: struct {
	name:  string,
	value: i64,
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
		if len(d.values) == 1 && len(d.names) > 1 {
			typecheck(ctx, {}, d.values[0])
			sig, ok := call_sig(ctx, d.values[0])
			assert(ok)
			assert(len(sig.rets) == len(d.names))
			rabi := ret_abi(sig.rets)

			for i in 0 ..< len(d.names) {
				name := meta.src_of(ctx.file^, d.names[i])
				flags: Var_Flags
				if ret_is_by_pointer(rabi, i) {
					flags |= {.Referenced}
				}
				set_node_data(d.names[i], flags)
				append(
					&ctx.scope,
					Variable {
						name = name,
						type = sig.rets[i].type,
						ident = d.names[i],
						flags = flags,
					},
				)
			}
			return .Void
		}

		inferred_ty := emit_type(ctx, d.type)

		if len(d.values) == 0 {
			assert(inferred_ty != .Void)
			flags: Var_Flags
			if type_to_dt(inferred_ty) == .Void do flags |= {.Referenced}
			for i in 0 ..< len(d.names) {
				name := meta.src_of(ctx.file^, d.names[i])
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
			return .Void
		}

		assert(len(d.names) == len(d.values))

		for i in 0 ..< len(d.names) {
			name := meta.src_of(ctx.file^, d.names[i])

			if u, ok := unpack_type(inferred_ty).(^Union); ok {
				value_ty := typecheck(ctx, {}, d.values[i])
				if value_ty != inferred_ty {
					_, found := union_variant_index(u, value_ty)
					fmt.assertf(
						found,
						"%v is not a variant of %v",
						value_ty,
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
				prop.inferred_ty == .Void ||
				prop.inferred_ty in INTEGER_TYPES ||
				prop.inferred_ty in FLOAT_TYPES,
			)
			return prop.inferred_ty != .Void ? prop.inferred_ty : .Int
		case .Float:
			assert(
				prop.inferred_ty == .Void || prop.inferred_ty in FLOAT_TYPES,
			)
			return prop.inferred_ty != .Void ? prop.inferred_ty : .F64
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
		case Pointer:
			#partial switch nt in unpack_type(t^) {
			case ^Array:
				return intern_multi_pointer(ctx, nt.elem)
			case:
				fmt.panicf("TODO: index ptr to type of %#v", t)
			}
		case Multi_Pointer:
			return t^
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
		case Pointer:
			#partial switch nt in unpack_type(t^) {
			case ^Array:
				return intern_multi_pointer(ctx, nt.elem)
			case:
				fmt.panicf("TODO: slice ptr to type of %#v", t)
			}
		case Multi_Pointer:
			if d.high == nil do return base
			return intern_slice(ctx, t^)
		case:
			fmt.panicf("TODO: %#v", t)
		}
	case ^ast.Selector_Expr:
		base := typecheck(ctx, {}, d.expr)

		#partial switch f in d.field.derived {
		case ^ast.Ident:
			if lit, ok := unpack_type(base).(^Lit); ok {
				if mid, mok := lit.(Module_ID); mok {
					if mid == MODULE_INTRINSICS {
						return pack_type(
							intern_lit(
								ctx,
								reflect.enum_from_name(
									Intrinsic,
									f.name,
								) or_else panic(""),
							),
						)
					}

					pid, pok := find_module_proc(ctx, mid, f.name)
					fmt.assertf(
						pok,
						"module %q has no symbol %q",
						ctx.modules[mid].name,
						f.name,
					)
					return pack_type(intern_lit(ctx, pid))
				}
			}

			if e, ok := unpack_type(base).(^Enum); ok {
				for v in e.variants {
					if v.name == f.name {
						set_node_data(d.field, int(v.value))
						return base
					}
				}
				fmt.panicf("enum has no variant %q", f.name)
			}

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
				return prop.inferred_ty
			}
		}
		fmt.panicf("enum has no variant %q", d.field.name)
	case ^ast.Type_Assertion:
		base := typecheck(ctx, {}, d.expr)
		u, ok := unpack_type(base).(^Union)
		assert(ok)
		target := emit_type(ctx, d.type)
		_, found := union_variant_index(u, target)
		fmt.assertf(found, "type %v is not a variant of %v", target, base)
		return target
	case ^ast.Binary_Expr:
		is_comparison :=
			.B_Comparison_Begin < d.op.kind && d.op.kind < .B_Comparison_End

		if is_nil_lit(d.left) || is_nil_lit(d.right) {
			operand := is_nil_lit(d.left) ? d.right : d.left
			oty := typecheck(ctx, {}, operand)
			assert(is_of(oty, ^Union))
			return .Bool
		}

		if is_num_lit(d.left) &&
		   !is_num_lit(d.right) &&
		   prop.inferred_ty == .Void {
			rhs_ty := typecheck(ctx, {}, d.right)
			lhs_ty := typecheck(ctx, {inferred_ty = rhs_ty}, d.left)
			assert(lhs_ty == rhs_ty)
			return is_comparison ? .Bool : rhs_ty
		}

		lhs_ty := typecheck(ctx, prop, d.left)
		inferred_ty := lhs_ty
		if d.op.kind == .Shl || d.op.kind == .Shr {
			inferred_ty = .Uint
		}
		rhs_ty := typecheck(ctx, {inferred_ty = inferred_ty}, d.right)
		assert(inferred_ty == rhs_ty)

		if is_comparison {
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
	case ^ast.Switch_Stmt:
		assert(d.init == nil)
		cond_ty := typecheck(ctx, {}, d.cond)
		body := d.body.derived.(^ast.Block_Stmt)
		for clause_node in body.stmts {
			clause := clause_node.derived.(^ast.Case_Clause)
			for v in clause.list {
				typecheck(ctx, {inferred_ty = cond_ty}, v)
			}
			prev := len(ctx.scope)
			for stmt in clause.body do typecheck(ctx, {}, stmt)
			resize(&ctx.scope, prev)
		}
		return {}
	case ^ast.Type_Switch_Stmt:
		tag := d.tag.derived.(^ast.Assign_Stmt)
		binding := meta.src_of(ctx.file^, tag.lhs[0])
		union_ty := typecheck(ctx, {}, tag.rhs[0])
		assert(is_of(union_ty, ^Union))
		body := d.body.derived.(^ast.Block_Stmt)
		for clause_node in body.stmts {
			clause := clause_node.derived.(^ast.Case_Clause)
			bind_ty := union_ty
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

		if mid, ok := ctx.modules[ctx.module].imports[name]; ok {
			return pack_type(intern_lit(ctx, Module_ID(mid)))
		}

		if pid, ok := find_module_proc(ctx, ctx.module, name); ok {
			return pack_type(intern_lit(ctx, pid))
		}

		if g, ok := find_module_global(ctx, ctx.module, name); ok {
			return g.type
		}

		if name == "false" || name == "true" {
			return .Bool
		}

		if name == "_" {
			return .Void
		}

		if sdecl, _, _, ok := find_module_decl(ctx, ctx.module, name); ok {
			if len(sdecl.values) == 1 {
				if _, is_lit := sdecl.values[0].derived.(^ast.Basic_Lit);
				   is_lit {
					return typecheck(ctx, prop, sdecl.values[0])
				}
			}
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

		if id, ok := d.expr.derived.(^ast.Ident); ok && id.name == "raw_data" {
			assert(len(d.args) == 1)
			arg_ty := typecheck(ctx, {}, d.args[0])
			#partial switch t in unpack_type(arg_ty) {
			case ^Slice:
				return intern_multi_pointer(ctx, t.elem)
			case Builtin:
				assert(t == .String)
				return intern_multi_pointer(ctx, .U8)
			case Pointer:
				#partial switch nt in unpack_type(t^) {
				case ^Array:
					return intern_multi_pointer(ctx, nt.elem)
				case:
					fmt.panicf("TODO: raw_data of of %#v", t)
				}
			case:
				fmt.panicf("TODO: raw_data of of %#v", t)
			}
		}

		callee := typecheck(ctx, {}, d.expr)

		sig: Signature
		#partial switch v in unpack_type(callee) {
		case ^Lit:
			switch l in v^ {
			case Proc_ID:
				prc := &ctx.procs[l]
				sig = prc.sig
			case Intrinsic:
				switch l {
				case .syscall:
					for arg in d.args {
						pty := typecheck(ctx, {inferred_ty = .Uintptr}, arg)
						assert(pty == .Uintptr)
					}
					return .Uintptr
				}
			case Module_ID:
				fmt.panicf("Cant call a module")
			}
		case Builtin:
			assert(v != .Void)
			assert(len(d.args) == 1)
			typecheck(ctx, {}, d.args[0])
			return callee
		case Multi_Pointer, Pointer:
			assert(len(d.args) == 1)
			typecheck(ctx, {inferred_ty = .Uintptr}, d.args[0])
			return callee
		case:
			fmt.panicf("TODO: %v %#v", v, d)
		}

		if len(d.args) == 1 && len(d.args) != len(sig.params) {
			typecheck(ctx, {}, d.args[0])
			inner_sig, ok := call_sig(ctx, d.args[0])
			assert(ok)
			assert(len(inner_sig.rets) == len(sig.params))
			for param, i in sig.params {
				assert(param.type == inner_sig.rets[i].type)
			}
		} else {
			assert(len(sig.params) == len(d.args))
			for param, i in sig.params {
				pty := typecheck(ctx, {inferred_ty = param.type}, d.args[i])
				assert(pty == param.type)
			}
		}

		if len(sig.rets) == 1 do return sig.rets[0].type
		return .Void
	case ^ast.Return_Stmt:
		prc := &ctx.procs[ctx.prc]
		assert(len(d.results) == len(prc.rets))
		for i in 0 ..< len(d.results) {
			typecheck(ctx, {inferred_ty = prc.rets[i].type}, d.results[i])
		}
	case ^ast.Assign_Stmt:
		if len(d.rhs) == 1 && len(d.lhs) > 1 {
			typecheck(ctx, {}, d.rhs[0])
			sig, ok := call_sig(ctx, d.rhs[0])
			assert(ok)
			assert(len(sig.rets) == len(d.lhs))
			for i in 0 ..< len(d.lhs) {
				lhs_ty := typecheck(ctx, {}, d.lhs[i])
				assert(lhs_ty == sig.rets[i].type)
			}
			return .Void
		}

		assert(len(d.lhs) == len(d.rhs))
		for i in 0 ..< len(d.lhs) {
			lhs_ty := typecheck(ctx, {}, d.lhs[i])
			if u, ok := unpack_type(lhs_ty).(^Union); ok {
				rhs_ty := typecheck(ctx, {}, d.rhs[i])
				if rhs_ty != lhs_ty {
					_, found := union_variant_index(u, rhs_ty)
					fmt.assertf(
						found,
						"%v is not a variant of %v",
						rhs_ty,
						lhs_ty,
					)
				}
				continue
			}
			typecheck(ctx, {inferred_ty = lhs_ty}, d.rhs[i])
		}
	case ^ast.Pointer_Type:
		return emit_type(ctx, node)
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
}

register_module_procs :: proc(ctx: ^Gen_Ctx, mid: Module_ID) {
	ctx.module = mid
	mod := &ctx.modules[mid]
	mod.proc_start = len(ctx.procs)

	for i in 0 ..< mod.file_count {
		ctx.file_id = File_ID(mod.file_start + i)
		ctx.file = &ctx.files[ctx.file_id]

		for decl in ctx.file.decls {
			block := decl.derived_stmt.(^ast.Foreign_Block_Decl) or_continue
			body := block.body.derived.(^ast.Block_Stmt) or_continue
			for vl in body.stmts {
				sdecl := vl.derived.(^ast.Value_Decl) or_continue
				if len(sdecl.values) == 0 do continue
				prc := sdecl.values[0].derived.(^ast.Proc_Lit) or_continue
				assert(prc.body == nil)
				typecheck_proc(ctx, mid, sdecl, prc)
			}
		}

		for decl in ctx.file.decls {
			sdecl := decl.derived_stmt.(^ast.Value_Decl) or_continue
			if len(sdecl.values) == 0 do continue
			prc := sdecl.values[0].derived.(^ast.Proc_Lit) or_continue
			typecheck_proc(ctx, mid, sdecl, prc)
		}
	}

	typecheck_proc :: proc(
		ctx: ^Gen_Ctx,
		mid: Module_ID,
		sdecl: ^ast.Value_Decl,
		prc: ^ast.Proc_Lit,
	) {

		plist := prc.type.params.list
		rlist: []^ast.Field
		if prc.type.results != nil {
			rlist = prc.type.results.list
		}

		params := make([]Param, len(plist), ctx.types.allocator)
		rets := make([]Param, len(rlist), ctx.types.allocator)

		lists := [][]^ast.Field{plist, rlist}
		tys := [][]Param{params, rets}

		for list, j in lists {
			tys := tys[j]

			for param, i in list {
				assert(len(param.names) <= 1)
				pname := ""
				if len(param.names) == 1 {
					pname = meta.src_of(ctx.file^, param.names[0])
				}

				tys[i] = {pname, emit_type(ctx, param.type)}
			}
		}

		append(
			&ctx.procs,
			Proc {
				name = meta.src_of(ctx.file^, sdecl.names[0]),
				lit = prc,
				module = mid,
				file = ctx.file,
				file_id = ctx.file_id,
				params = params,
				rets = rets,
			},
		)
	}

	mod.proc_count = len(ctx.procs) - mod.proc_start
}

register_module_globals :: proc(ctx: ^Gen_Ctx, mid: Module_ID) {
	ctx.module = mid
	mod := &ctx.modules[mid]

	for i in 0 ..< mod.file_count {
		ctx.file_id = File_ID(mod.file_start + i)
		ctx.file = &ctx.files[ctx.file_id]

		for decl in ctx.file.decls {
			sdecl := decl.derived_stmt.(^ast.Value_Decl) or_continue
			if !sdecl.is_mutable do continue

			for name_node, j in sdecl.names {
				name := meta.src_of(ctx.file^, name_node)
				if name == "_" do continue

				ty: Type
				if sdecl.type != nil {
					ty = emit_type(ctx, sdecl.type)
				} else {
					assert(len(sdecl.values) == len(sdecl.names))
					ty = typecheck(ctx, {}, sdecl.values[j])
				}

				init: ^ast.Expr
				if j < len(sdecl.values) do init = sdecl.values[j]

				append(&ctx.global_vars, Global_Var{name, mid, ty, 0, init})
			}
		}
	}
}

typecheck_program :: proc(ctx: ^Gen_Ctx) {
	for mid in 0 ..< len(ctx.modules) {
		register_module_procs(ctx, Module_ID(mid))
		register_module_globals(ctx, Module_ID(mid))
	}

	for &prc, i in ctx.procs {
		ctx.prc = auto_cast i
		ctx.module = prc.module
		ctx.file = prc.file
		ctx.file_id = prc.file_id
		ctx.mems.scratch.pos = 0
		ctx.scope = make([dynamic]Variable, arna.allocator(&ctx.mems.scratch))

		for par in prc.params {
			append(&ctx.scope, Variable{name = par.name, type = par.type})
		}

		typecheck(ctx, {}, prc.lit.body)
	}
}
