package main

import "backend"
import "backend/wasm"
import "core:fmt"
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

	Export_Type :: enum u8 {
		func,
		table,
		mem,
		global,
		tag,
	}

	Mutability :: enum u8 {
		const,
		mut,
	}

	Limit_Type :: enum u8 {
		I32_Open   = 0,
		I32_Closed = 1,
		I64_Open   = 4,
		I64_Closed = 5,
	}

	sections: [Section_Type][dynamic]u8
	name_sections: #sparse[Name_Section_Type][dynamic]u8

	PAGE_SIZE :: 1 << 16
	STACK_SIZE :: 1 << 20

	export_count := 0

	mem_init_size := STACK_SIZE
	mem_count := 0

	mem_count += 1 // memory
	export_count += 1

	uleb(&sections[.memory], u64(mem_count))

	memory: {
		putb(&sections[.memory], Limit_Type.I64_Open)
		uleb(&sections[.memory], u64(mem_init_size / PAGE_SIZE))
	}

	global_count := 0

	global_count += 1 // __stack_pointer
	export_count += 1

	uleb(&sections[.global], u64(global_count))

	stack_pointer: {
		putb(&sections[.global], wasm.Type.i64)
		putb(&sections[.global], Mutability.mut)
		putb(&sections[.global], wasm.Wasm_Opcode.I64_Const)
		sleb(&sections[.global], STACK_SIZE)
		putb(&sections[.global], wasm.Wasm_Opcode.End)
	}

	func_count := 0

	func_idxes := make([]int, len(ctx.procs))

	for prc, i in ctx.procs[1:] {
		func_idxes[1 + i] = func_count
		func_count += int(prc.lit.body != nil)
		if prc.name == "main" do export_count += 1
	}

	uleb(&sections[.type], u64(func_count))
	uleb(&sections[.function], u64(func_count))
	uleb(&sections[.export], u64(export_count))
	uleb(&sections[.code], u64(func_count))
	uleb(&name_sections[.function], u64(func_count))

	export :: proc(
		sec: ^[dynamic]u8,
		name: string,
		type: Export_Type,
		#any_int idx: u64,
	) {
		uleb(sec, u64(len(name)))
		append(sec, name)
		putb(sec, type)
		uleb(sec, idx)
	}

	idx := 0
	for prc in ctx.procs[1:] {
		if prc.lit.body != nil {
			if prc.name == "main" {
				export(&sections[.export], prc.name, .func, idx)
			}

			uleb(&name_sections[.function], u64(idx))
			uleb(&name_sections[.function], u64(len(prc.name)))
			append(&name_sections[.function], prc.name)

			params := prc.param_types
			rets := typecheck.ret_abi(prc.rets)
			encode_func_type(&sections[.type], params, rets.reg_rets)

			for reloc in prc.out.relocs {
				opcode := wasm.Wasm_Opcode(prc.out.code[reloc.offset - 1])
				#partial switch opcode {
				case .Call:
					id := func_idxes[reloc.id]
					fixed_uleb(prc.out.code[reloc.offset:][:4], u64(id))
				case:
					fmt.panicf("TODO: reloc opcode %v", opcode)
				}
			}

			uleb(&sections[.code], u64(len(prc.out.code)))
			append(&sections[.code], ..prc.out.code)

			uleb(&sections[.function], u64(idx))
			idx += 1
		}
	}

	export(&sections[.export], "__stack_pointer", .global, 0)
	export(&sections[.export], "memory", .mem, 0)

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
		if kind == .custom || len(section) == 0 do continue

		putb(&bytes, kind)
		uleb(&bytes, u64(len(section)))
		append(&bytes, ..section[:])
	}

	if len(sections[.custom]) != 0 {
		putb(&bytes, Section_Type.custom)
		uleb(&bytes, u64(len(sections[.custom])))
		append(&bytes, ..sections[.custom][:])
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
