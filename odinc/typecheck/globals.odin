package typecheck

import "../../utils/arna"
import "core:mem"
import "core:odin/ast"
import "core:slice"

is_data_pointer :: proc(ty: Type) -> bool {
	return(
		strip_named(ty) == .Rawptr ||
		is_of(ty, Pointer) ||
		is_of(ty, Multi_Pointer) \
	)
}

alloc_global :: proc(ctx: ^Gen_Ctx, ty: Type, node: ^ast.Node) -> u32 {
	size := type_size(ty)
	MAX_GLOBAL_SIZE :: 1024 * 1024
	if size < 0 || size > MAX_GLOBAL_SIZE {
		error(
			ctx,
			node,
			"Globals bigger then %vb are not supported",
			MAX_GLOBAL_SIZE,
		)
		return 0
	}

	return add_global(ctx, make([]u8, size, ctx.types.allocator), type_align(ty))
}

global_pointer :: proc(ctx: ^Gen_Ctx, ty: Type, value: u64) -> ^Check_Meta {
	value := value
	bytes := slice.clone(mem.ptr_to_bytes(&value), ctx.types.allocator)
	return tcmeta(ctx, ty, {dest = {add_global(ctx, bytes, 0), 0}})
}

global_zero :: proc(
	ctx: ^Gen_Ctx,
	prop: Ty_Propagation,
) -> (
	^Check_Meta,
	bool,
) {
	if is_data_pointer(prop.inferred_ty) {
		return global_pointer(ctx, prop.inferred_ty, 0), false
	}

	if type_to_dt(prop.inferred_ty) == .Void {
		return gi_end(ctx, gi_init(ctx, prop, .Void))
	}

	return tcmeta(ctx, prop.inferred_ty, {}), false
}

global_reloc :: proc(ctx: ^Gen_Ctx, dest: Global_Dest, to: Global_Dest) {
	global := &ctx.globals[dest.idx]
	bytes := global.bytes[dest.offset:][:8]
	if ctx.globals[to.idx].align == 0 {
		value: u64
		copy(mem.ptr_to_bytes(&value), ctx.globals[to.idx].bytes)
		value += u64(to.offset)
		copy(bytes, mem.ptr_to_bytes(&value))
		return
	}

	append(&global.relocs, Global_Reloc{dest.offset, to.idx, to.offset})
	slice.fill(bytes, 0)
}

global_store :: proc(ctx: ^Gen_Ctx, dest: Global_Dest, meta: ^Check_Meta) {
	context.allocator, _ = arna.scrath()
	if meta.lvalue && meta.dest == dest do return

	relocs: []Global_Reloc
	if meta.lvalue do relocs = slice.clone(ctx.globals[meta.idx].relocs[:])

	size := type_size(meta.type)
	global := &ctx.globals[dest.idx]
	for i := 0; i < len(global.relocs); {
		rel := global.relocs[i]
		if dest.offset <= rel.in_offset &&
		   rel.in_offset < dest.offset + u32(size) {
			ordered_remove(&global.relocs, i)
		} else {
			i += 1
		}
	}

	bytes := global.bytes[dest.offset:][:size]
	if meta.lvalue {
		source := ctx.globals[meta.idx]
		copy(bytes, source.bytes[meta.offset:][:size])

		for rel in relocs {
			if meta.offset <= rel.in_offset &&
			   rel.in_offset < meta.offset + u32(size) {
				rel := rel
				rel.in_offset = dest.offset + rel.in_offset - meta.offset
				append(&ctx.globals[dest.idx].relocs, rel)
			}
		}
	} else if is_data_pointer(meta.type) {
		global_reloc(ctx, dest, meta.dest)
	} else if is_of(meta.type, ^Proc_Type) {
		slice.fill(bytes, 0)
		if meta.procid != 0 {
			append(
				&ctx.globals[dest.idx].relocs,
				Global_Reloc{dest.offset, u32(meta.procid), max(u32)},
			)
		}
	} else if strip_named(meta.type) == .String {
		value := constant_string(ctx, meta)
		data := slice.clone(transmute([]u8)value, ctx.types.allocator)
		idx := add_global(ctx, data, 1)
		global_reloc(ctx, dest, {idx, 0})

		length := i64(len(value))
		copy(bytes[8:], mem.ptr_to_bytes(&length))
	} else {
		value := meta.lit
		if strip_named(meta.type) == .F32 {
			value.uint = u64(transmute(u32)f32(meta.float))
		}

		assert(size <= size_of(value))
		copy(bytes, mem.ptr_to_bytes(&value)[:size])
	}
}

global_load :: proc(ctx: ^Gen_Ctx, meta: ^Check_Meta) -> ^Check_Meta {
	if !meta.known || !meta.lvalue || type_to_dt(meta.type) == .Void do return meta

	global := ctx.globals[meta.idx]
	if global.align == 0 ||
	   u64(meta.offset) + u64(type_size(meta.type)) > u64(len(global.bytes)) {
		return error(
			ctx,
			ctx.file.pkg_decl,
			"can not read through a dangling pointer at compile time",
		)
	}

	for rel in global.relocs {
		if rel.in_offset != meta.offset do continue

		if rel.to_offset == max(u32) {
			return tcmeta(ctx, meta.type, {procid = Proc_ID(rel.to)})
		}

		return tcmeta(ctx, meta.type, {dest = {rel.to, rel.to_offset}})
	}

	value: Lit
	copy(
		mem.ptr_to_bytes(&value),
		global.bytes[meta.offset:][:type_size(meta.type)],
	)
	if is_data_pointer(meta.type) do return global_pointer(ctx, meta.type, value.uint)

	if strip_named(meta.type) == .F32 {
		value.float = f64(transmute(f32)u32(value.uint))
	}
	if in_set(constant_base_type(meta.type), SIGNED_TYPES) {
		shift := uint(64 - type_size(meta.type) * 8)
		value.int = (value.int << shift) >> shift
	}

	return tcmeta(ctx, meta.type, value)
}

global_string :: proc(ctx: ^Gen_Ctx, meta: ^Check_Meta) -> ^Check_Meta {
	if meta.lvalue do return meta

	idx := add_global(ctx, make([]u8, 16, ctx.types.allocator), 8)
	dest := Global_Dest{idx, 0}
	global_store(ctx, dest, meta)
	return lcmeta(ctx, .String, dest)
}

global_field :: proc(
	ctx: ^Gen_Ctx,
	meta: ^Check_Meta,
	ty: Type,
	offset: int,
) -> ^Check_Meta {
	return lcmeta(ctx, ty, {meta.idx, meta.offset + u32(offset)})
}

global_raw_data :: proc(
	ctx: ^Gen_Ctx,
	node: ^ast.Node,
	base: ^Check_Meta,
) -> ^Check_Meta {
	#partial switch t in unpack_type(base.type) {
	case ^Array:
		return tcmeta(ctx, intern_multi_pointer(ctx, t.elem), {dest = base.dest})
	case Pointer:
		if array, ok := unpack_type(t^).(^Array); ok {
			ptr_ty := intern_multi_pointer(ctx, array.elem)
			return tcmeta(ctx, ptr_ty, {dest = base.dest})
		}
	case ^Slice:
		ptr_ty := intern_multi_pointer(ctx, t.elem)
		field := global_field(ctx, base, ptr_ty, 0)
		return global_load(ctx, field)
	case String_Type:
		base := global_string(ctx, base)
		ptr_ty := intern_multi_pointer(ctx, .U8)
		field := global_field(ctx, base, ptr_ty, 0)
		return global_load(ctx, field)
	case Multi_Pointer:
		return base
	}

	return error(ctx, node, "can not take the raw_data of a %v", base.type)
}

global_index :: proc(
	ctx: ^Gen_Ctx,
	node: ^ast.Node,
	base: ^Check_Meta,
	index: i64,
) -> ^Check_Meta {
	base := global_load(ctx, base)

	elem: Type
	length := i64(max(i32))
	data := base.dest
	#partial switch t in unpack_type(base.type) {
	case ^Array:
		elem, length = t.elem, i64(t.len)
	case Pointer:
		if array, ok := unpack_type(t^).(^Array); ok {
			elem, length = array.elem, i64(array.len)
		}
	case ^Slice:
		elem = t.elem
		length = global_load(ctx, global_field(ctx, base, .Int, 8)).int
		data = global_raw_data(ctx, node, base).dest
	case String_Type:
		elem = .U8
		base := global_string(ctx, base)
		length = global_load(ctx, global_field(ctx, base, .Int, 8)).int
		data = global_raw_data(ctx, node, base).dest
	case Multi_Pointer:
		elem = t^
	}

	if elem == .Void do return error(ctx, node, "can not index a %v", base.type)
	if index < 0 || index >= length do return error(ctx, node, "constant index out of bounds")

	offset := u64(data.offset) + u64(index) * u64(type_size(elem))
	if offset > u64(max(u32)) do return error(ctx, node, "constant pointer offset is too large")

	data.offset = u32(offset)
	return lcmeta(ctx, elem, data)
}

global_slice :: proc(
	ctx: ^Gen_Ctx,
	prop: Ty_Propagation,
	node: ^ast.Slice_Expr,
	base: ^Check_Meta,
	low, high: ^Check_Meta,
) -> ^Check_Meta {
	base := base
	elem, ty: Type
	length := i64(-1)
	#partial switch t in unpack_type(base.type) {
	case ^Array:
		elem, length = t.elem, i64(t.len)
	case Pointer:
		if array, ok := unpack_type(t^).(^Array); ok {
			elem, length = array.elem, i64(array.len)
		}
	case ^Slice:
		elem, ty = t.elem, base.type
		length = global_load(ctx, global_field(ctx, base, .Int, 8)).int
	case String_Type:
		elem, ty = .U8, base.type
		base = global_string(ctx, base)
		length = global_load(ctx, global_field(ctx, base, .Int, 8)).int
	case Multi_Pointer:
		elem = t^
	}

	if elem == .Void do return error(ctx, node, "can not slice a %v", base.type)

	lo := node.low == nil ? 0 : low.int
	hi := node.high == nil ? length : high.int
	if lo < 0 ||
	   (node.high != nil && hi < 0) ||
	   (hi >= 0 && lo > hi) ||
	   (length >= 0 && hi > length) {
		return error(ctx, node, "constant slice out of bounds")
	}

	data := global_raw_data(ctx, node, base)
	offset := u64(data.offset) + u64(lo) * u64(type_size(elem))
	if offset > u64(max(u32)) do return error(ctx, node, "constant pointer offset is too large")

	data = tcmeta(ctx, data.type, {dest = {data.idx, u32(offset)}})
	if hi < 0 do return data

	if ty == .Void do ty = intern_slice(ctx, elem)
	init := gi_init(ctx, prop, ty)
	gi_ensure_stored(ctx, init, data)

	gi_set_offset(&init, 8)
	gi_ensure_stored(ctx, init, tcmeta(ctx, .Int, {int = hi - lo}))
	return gi_end(ctx, init)
}
