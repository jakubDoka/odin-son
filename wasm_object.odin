package main

import "backend"
import "backend/wasm"
import "core:fmt"
import "core:mem"
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

	global_count := 0

	global_count += 1 // __stack_pointer
	export_count += 1

	global_count += len(ctx.globals)

	uleb(&sections[.global], u64(global_count))

	emit_global :: proc(
		buf: ^[dynamic]u8,
		ty: wasm.Type,
		mutability: Mutability,
		#any_int offset: i64,
	) {
		putb(buf, ty)
		putb(buf, mutability)
		putb(buf, wasm.Wasm_Opcode.I64_Const)
		sleb(buf, offset)
		putb(buf, wasm.Wasm_Opcode.End)
	}

	stack_pointer: {
		emit_global(&sections[.global], .i64, .mut, STACK_SIZE)
	}

	init_mem_start := 0
	global_idxes := make([]int, len(ctx.globals))
	global_idx := 1
	for i in 0 ..< 2 {
		do_zeroed := i == 0

		if !do_zeroed {
			init_mem_start = mem_init_size
		}

		for global, i in ctx.globals {
			if do_zeroed == slice.all_of(global.bytes, 0) {
				mem_init_size = mem.align_forward_int(
					mem_init_size,
					global.align,
				)
				emit_global(&sections[.global], .i64, .const, mem_init_size)
				mem_init_size += len(global.bytes)
				global_idxes[i] = global_idx
				global_idx += 1
			}
		}
	}

	mem_count += 1 // memory
	export_count += 1

	uleb(&sections[.memory], u64(mem_count))

	memory: {
		putb(&sections[.memory], Limit_Type.I64_Open)
		uleb(
			&sections[.memory],
			u64((mem_init_size + PAGE_SIZE - 1) / PAGE_SIZE),
		)
	}

	data_count := 0
	data_count += 1 // static init memory

	uleb(&sections[.data], u64(data_count))

	static_init: {
		putb(&sections[.data], u8(0))

		putb(&sections[.data], wasm.Wasm_Opcode.I64_Const)
		sleb(&sections[.data], i64(init_mem_start))
		putb(&sections[.data], wasm.Wasm_Opcode.End)

		uleb(&sections[.data], u64(mem_init_size - init_mem_start))
		for global, i in ctx.globals {
			offset := init_mem_start
			if !slice.all_of(global.bytes, 0) {
				padding := mem.align_forward_int(offset, global.align) - offset
				resize(&sections[.data], len(sections[.data]) + padding)
				append(&sections[.data], ..global.bytes)
				offset += len(global.bytes)
			}
		}
	}

	func_count := 0

	func_idxes := make([]int, len(ctx.procs))

	for prc, i in ctx.procs[1:] {
		func_idxes[1 + i] = func_count
		func_count += int(prc.lit.body != nil && prc.sig != nil)
		if prc.name == "main" do export_count += 1
	}

	type_count := 0

	type_count += func_count

	for prc in ctx.procs[1:] {
		for reloc in prc.out.relocs {
			opcode := wasm.Wasm_Opcode(prc.out.code[reloc.offset - 1])
			#partial switch opcode {
			case .Call_Indirect:
				type_count += 1
			case:
			}
		}
	}

	uleb(&sections[.type], u64(type_count))
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

	indirect_ids: [dynamic]int

	idx := 0
	type_idx := 0
	for prc in ctx.procs[1:] {
		if prc.lit.body != nil && prc.sig != nil {
			if prc.name == "main" {
				export(&sections[.export], prc.name, .func, idx)
			}

			uleb(&name_sections[.function], u64(idx))
			uleb(&name_sections[.function], u64(len(prc.name)))
			append(&name_sections[.function], prc.name)

			for reloc in prc.out.relocs {
				id: u64
				opcode := wasm.Wasm_Opcode(prc.out.code[reloc.offset - 1])
				#partial switch opcode {
				case .I64_Const:
					// TODO: dedup
					id = u64(len(indirect_ids))
					append(&indirect_ids, func_idxes[reloc.id])
				case .Call:
					id = u64(func_idxes[reloc.id])
				case .Global_Get:
					id = u64(global_idxes[reloc.id])
				case .Call_Indirect:
					len := prc.out.constants[reloc.id]
					bytes := prc.out.constants[reloc.id + 1:][:len]
					append(&sections[.type], ..bytes)
					id = u64(type_idx)
					type_idx += 1
				case:
					fmt.panicf("TODO: reloc opcode %v", opcode)
				}
				fixed_uleb(prc.out.code[reloc.offset:][:4], id)
			}

			uleb(&sections[.code], u64(len(prc.out.code)))
			append(&sections[.code], ..prc.out.code)

			params := prc.param_types
			rets := typecheck.ret_abi(prc.rets)
			encode_func_type(&sections[.type], params, rets.reg_rets)

			uleb(&sections[.function], u64(type_idx))
			idx += 1

			type_idx += 1
		}
	}

	export(&sections[.export], "__stack_pointer", .global, 0)
	export(&sections[.export], "memory", .mem, 0)

	uleb(&sections[.custom], 4)
	append(&sections[.custom], "name")

	table_count := 0

	table_count += 1 // dyn_call_table

	uleb(&sections[.table], u64(table_count))

	dyn_call_table: {
		putb(&sections[.table], u8(0x70))
		putb(&sections[.table], Limit_Type.I32_Closed)
		uleb(&sections[.table], u64(len(indirect_ids)))
		uleb(&sections[.table], u64(len(indirect_ids)))
	}

	elem_count := 0

	elem_count += 1 // init_dyn_call_table

	uleb(&sections[.element], u64(table_count))
	init_dyn_call_table: {
		putb(&sections[.element], u8(0))

		putb(&sections[.element], wasm.Wasm_Opcode.I32_Const)
		sleb(&sections[.element], 0)
		putb(&sections[.element], wasm.Wasm_Opcode.End)

		uleb(&sections[.element], u64(len(indirect_ids)))
		for id in indirect_ids {
			uleb(&sections[.element], u64(id))
		}
	}

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
		ret_dts: [dynamic; 2]backend.Node_Datatype
		assert(len(rets) <= 1)
		for ret in rets {
			if typecheck.is_of(ret, ^typecheck.Simd) {
				append(&ret_dts, backend.Node_Datatype.V128)
				continue
			}

			rets, ok := x86_reg_class_classify(ret)

			if len(rets) == 1 && type_to_dt(ret) != .Void {
				rets[0] = type_to_dt(ret)
			}

			ret_dts = rets
		}

		wasm.encode_func_type(buf, params, ret_dts[:])
	}
}
