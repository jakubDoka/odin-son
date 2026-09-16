package main

import "backend"
import "backend/wasm"
import "core:slice"
import "typecheck"
import "vendored/gam/util/arna"

emit_wasm_module :: proc(ctx: ^Gen_Ctx, scratch := context.allocator) -> []u8 {
	context.allocator, _ = arna.scrath(scratch)

	magic := [?]u8{0x00, 0x61, 0x73, 0x6D}
	VERSION: u32 : 1

	Type :: wasm.Type

	Name_Section_Type :: enum u8 {
		module,
		function,
		local,
		type = 4,
		field = 10,
		tag,
	}

	Section_Type :: enum u8 {
		custom,
		type,
		import_,
		function,
		table,
		memory,
		global,
		export,
		start,
		element,
		code,
		data,
		data_count,
		tag,
	}

	@(static, rodata)
	DT_TO_VALTYPE := #partial [backend.Node_Datatype]wasm.Type {
		.I8 ..= .I32      = .i32,
		.I64  = .i64,
		.F64  = .f64,
		.F32  = .f32,
		.V128 = .vec,
	}

	sections: [Section_Type][dynamic]u8
	name_sections: #sparse[Name_Section_Type][dynamic]u8

	func_count := 0

	for prc in ctx.procs[1:] {
		func_count += int(prc.lit.body != nil)
	}

	uleb(&sections[.type], u64(func_count))
	uleb(&sections[.function], u64(func_count))
	uleb(&sections[.export], u64(func_count))
	uleb(&sections[.code], u64(func_count))
	uleb(&name_sections[.function], u64(func_count))

	idx := 0
	for prc in ctx.procs[1:] {
		if prc.lit.body != nil {
			uleb(&sections[.export], u64(len(prc.name)))
			append(&sections[.export], prc.name)
			putb(&sections[.export], u8(0))
			uleb(&sections[.export], u64(idx))

			uleb(&name_sections[.function], u64(idx))
			uleb(&name_sections[.function], u64(len(prc.name)))
			append(&name_sections[.function], prc.name)

			params := prc.param_types
			rets := typecheck.ret_abi(prc.rets)
			encode_func_type(&sections[.type], params, rets.reg_rets)

			assert(len(prc.out.relocs) == 0)
			uleb(&sections[.code], u64(len(prc.out.code)))
			append(&sections[.code], ..prc.out.code)

			uleb(&sections[.function], u64(idx))
			idx += 1
		}
	}

	uleb(&sections[.custom], 4)
	append(&sections[.custom], "name")

	for name_section, kind in name_sections {
		if len(name_section) == 0 do continue

		putb(&sections[.custom], kind)
		uleb(&sections[.custom], u64(len(name_section)))
		append(&sections[.custom], ..name_section[:])
	}

	bytes: [dynamic]u8

	append(&bytes, ..magic[:])
	put_u32(&bytes, VERSION)

	for section, kind in sections {
		if len(section) == 0 do continue

		putb(&bytes, kind)
		uleb(&bytes, u64(len(section)))
		append(&bytes, ..section[:])
	}

	return slice.clone(bytes[:], scratch)

	encode_func_type :: proc(
		buf: ^[dynamic]u8,
		params: []backend.Param_Spec,
		rets: []typecheck.Type,
	) {
		putb(buf, Type.fnc)

		param_count := 0
		for param in params {
			param_count += int(param.dt != .Void)
		}
		uleb(buf, u64(param_count))

		for param in params {
			if param.dt != .Void {
				putb(buf, DT_TO_VALTYPE[param.dt])
			}
		}

		uleb(buf, u64(len(rets)))
		for ret in rets {
			putb(buf, DT_TO_VALTYPE[typecheck.type_to_dt(ret)])
		}
	}

}
