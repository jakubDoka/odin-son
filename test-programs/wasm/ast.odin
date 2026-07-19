package main

// In-memory representation of a decoded WASM module. Everything a future
// interpreter needs is laid out flat and index/offset addressable: function
// signatures resolve by index into `typecheck.Module.types`, code bodies are flat
// instruction streams carrying their decoded immediates, and export/import/data
// names are (offset, length) spans into the original module byte slice.
//
// Node kinds, section ids, value types and opcodes are plain integer constants
// because the JIT frontend has no `enum`.

// --- value types -----------------------------------------------------------

VT_I32 :: 0x7f
VT_I64 :: 0x7e
VT_F32 :: 0x7d
VT_F64 :: 0x7c
VT_EMPTY :: 0x40 // block type: no result

// --- section ids -----------------------------------------------------------

SEC_CUSTOM :: 0
SEC_TYPE :: 1
SEC_IMPORT :: 2
SEC_FUNCTION :: 3
SEC_TABLE :: 4
SEC_MEMORY :: 5
SEC_GLOBAL :: 6
SEC_EXPORT :: 7
SEC_START :: 8
SEC_ELEMENT :: 9
SEC_CODE :: 10
SEC_DATA :: 11

// --- external kinds (imports / exports) ------------------------------------

EXT_FUNC :: 0
EXT_TABLE :: 1
EXT_MEM :: 2
EXT_GLOBAL :: 3

// --- opcodes (representative subset of the MVP) ----------------------------

OP_UNREACHABLE :: 0x00
OP_NOP :: 0x01
OP_BLOCK :: 0x02
OP_LOOP :: 0x03
OP_IF :: 0x04
OP_ELSE :: 0x05
OP_END :: 0x0b
OP_BR :: 0x0c
OP_BR_IF :: 0x0d
OP_RETURN :: 0x0f
OP_CALL :: 0x10
OP_DROP :: 0x1a
OP_SELECT :: 0x1b

OP_LOCAL_GET :: 0x20
OP_LOCAL_SET :: 0x21
OP_LOCAL_TEE :: 0x22
OP_GLOBAL_GET :: 0x23
OP_GLOBAL_SET :: 0x24

OP_LOAD_LO :: 0x28 // i32.load .. i64.store32 all carry a memarg (align, offset)
OP_STORE_HI :: 0x3e
OP_MEMORY_SIZE :: 0x3f
OP_MEMORY_GROW :: 0x40

OP_I32_CONST :: 0x41
OP_I64_CONST :: 0x42
OP_F32_CONST :: 0x43
OP_F64_CONST :: 0x44

// numeric ops with no immediate span 0x45..0xc4
OP_NUM_LO :: 0x45
OP_NUM_HI :: 0xc4

OP_I32_EQZ :: 0x45
OP_I32_EQ :: 0x46
OP_I32_LT_S :: 0x48
OP_I64_EQZ :: 0x50
OP_I64_LE_S :: 0x53
OP_I32_ADD :: 0x6a
OP_I32_SUB :: 0x6b
OP_I32_MUL :: 0x6c
OP_I64_ADD :: 0x7c
OP_I64_SUB :: 0x7d
OP_I64_MUL :: 0x7e

// --- decoded nodes ---------------------------------------------------------

// Instr is one decoded instruction. `x` holds the primary immediate (const
// value, local/global/func index, branch label, or block type); for memory
// loads/stores `x` is the alignment and `y` the offset.
Instr :: struct {
	op: int,
	x:  i64,
	y:  i64,
}

Local :: struct {
	count:   int,
	valtype: int,
}

// FuncType references its parameter and result value types as (offset, count)
// spans into the module-wide `valtypes` array. Nested arrays are avoided on
// purpose: every element type stored in an `Array` is a flat struct of scalars.
FuncType :: struct {
	param_off:    int,
	param_count:  int,
	result_off:   int,
	result_count: int,
}

Import :: struct {
	mod_off: int,
	mod_len: int,
	nm_off:  int,
	nm_len:  int,
	kind:    int,
	index:   int,
}

Export :: struct {
	nm_off: int,
	nm_len: int,
	kind:   int,
	index:  int,
}

Global :: struct {
	valtype:  int,
	mutable:  int,
	init_op:  int,
	init_val: i64,
}

Memory :: struct {
	min:     int,
	max:     int,
	has_max: int,
}

Data :: struct {
	mem_index: int,
	off_op:    int,
	off_val:   i64,
	bytes_off: int,
	bytes_len: int,
}

// Code references its local declarations and instruction stream as (offset,
// count) spans into the module-wide `locals` / `instrs` arrays.
Code :: struct {
	local_off:   int,
	local_count: int,
	instr_off:   int,
	instr_count: int,
	body_size:   int,
	local_total: int,
}

// Element types are now carried directly by each `Array(T)`; the old flat
// stride table is gone.
Module :: struct {
	ok:            bool,
	version:       u32,
	section_count: int,
	start_func:    int, // -1 when absent
	types:         Array(FuncType),
	valtypes:      Array(int), // param/result value types, referenced by FuncType
	imports:       Array(Import),
	funcs:         Array(int), // type index per function
	mems:          Array(Memory),
	globals:       Array(Global),
	exports:       Array(Export),
	locals:        Array(Local), // referenced by Code
	instrs:        Array(Instr), // referenced by Code
	codes:         Array(Code),
	datas:         Array(Data),
}

// --- name lookups ----------------------------------------------------------

valtype_name :: proc(t: int) -> string {
	if t == VT_I32 do return "i32"
	if t == VT_I64 do return "i64"
	if t == VT_F32 do return "f32"
	if t == VT_F64 do return "f64"
	if t == VT_EMPTY do return "void"
	return "?"
}

section_name :: proc(id: int) -> string {
	if id == SEC_CUSTOM do return "custom"
	if id == SEC_TYPE do return "type"
	if id == SEC_IMPORT do return "import"
	if id == SEC_FUNCTION do return "function"
	if id == SEC_TABLE do return "table"
	if id == SEC_MEMORY do return "memory"
	if id == SEC_GLOBAL do return "global"
	if id == SEC_EXPORT do return "export"
	if id == SEC_START do return "start"
	if id == SEC_ELEMENT do return "element"
	if id == SEC_CODE do return "code"
	if id == SEC_DATA do return "data"
	return "?"
}

ext_kind_name :: proc(k: int) -> string {
	if k == EXT_FUNC do return "func"
	if k == EXT_TABLE do return "table"
	if k == EXT_MEM do return "memory"
	if k == EXT_GLOBAL do return "global"
	return "?"
}

opcode_name :: proc(op: int) -> string {
	if op == OP_UNREACHABLE do return "unreachable"
	if op == OP_NOP do return "nop"
	if op == OP_BLOCK do return "block"
	if op == OP_LOOP do return "loop"
	if op == OP_IF do return "if"
	if op == OP_ELSE do return "else"
	if op == OP_END do return "end"
	if op == OP_BR do return "br"
	if op == OP_BR_IF do return "br_if"
	if op == OP_RETURN do return "return"
	if op == OP_CALL do return "call"
	if op == OP_DROP do return "drop"
	if op == OP_SELECT do return "select"
	if op == OP_LOCAL_GET do return "local.get"
	if op == OP_LOCAL_SET do return "local.set"
	if op == OP_LOCAL_TEE do return "local.tee"
	if op == OP_GLOBAL_GET do return "global.get"
	if op == OP_GLOBAL_SET do return "global.set"
	if op == 0x28 do return "i32.load"
	if op == 0x29 do return "i64.load"
	if op == 0x2c do return "i32.load8_s"
	if op == 0x2d do return "i32.load8_u"
	if op == 0x2e do return "i32.load16_s"
	if op == 0x2f do return "i32.load16_u"
	if op == 0x36 do return "i32.store"
	if op == 0x37 do return "i64.store"
	if op == 0x3a do return "i32.store8"
	if op == 0x3b do return "i32.store16"
	if op == OP_MEMORY_SIZE do return "memory.size"
	if op == OP_MEMORY_GROW do return "memory.grow"
	if op == OP_I32_CONST do return "i32.const"
	if op == OP_I64_CONST do return "i64.const"
	if op == OP_F32_CONST do return "f32.const"
	if op == OP_F64_CONST do return "f64.const"
	if op == OP_I32_EQZ do return "i32.eqz"
	if op == OP_I32_EQ do return "i32.eq"
	if op == OP_I32_LT_S do return "i32.lt_s"
	if op == OP_I64_EQZ do return "i64.eqz"
	if op == OP_I64_LE_S do return "i64.le_s"
	if op == 0x47 do return "i32.ne"
	if op == 0x49 do return "i32.lt_u"
	if op == 0x4a do return "i32.gt_s"
	if op == 0x4b do return "i32.gt_u"
	if op == 0x4c do return "i32.le_s"
	if op == 0x4d do return "i32.le_u"
	if op == 0x4e do return "i32.ge_s"
	if op == 0x4f do return "i32.ge_u"
	if op == 0x51 do return "i64.eq"
	if op == 0x52 do return "i64.ne"
	if op == 0x55 do return "i64.gt_s"
	if op == 0x59 do return "i64.ge_s"
	if op == OP_I32_ADD do return "i32.add"
	if op == OP_I32_SUB do return "i32.sub"
	if op == OP_I32_MUL do return "i32.mul"
	if op == 0x6d do return "i32.div_s"
	if op == 0x6e do return "i32.div_u"
	if op == 0x6f do return "i32.rem_s"
	if op == 0x70 do return "i32.rem_u"
	if op == 0x71 do return "i32.and"
	if op == 0x72 do return "i32.or"
	if op == 0x73 do return "i32.xor"
	if op == 0x74 do return "i32.shl"
	if op == 0x75 do return "i32.shr_s"
	if op == 0x76 do return "i32.shr_u"
	if op == OP_I64_ADD do return "i64.add"
	if op == OP_I64_SUB do return "i64.sub"
	if op == OP_I64_MUL do return "i64.mul"
	if op == 0x7f do return "i64.div_s"
	if op == 0x81 do return "i64.rem_s"
	if op == 0x83 do return "i64.and"
	if op == 0x84 do return "i64.or"
	if op == 0x85 do return "i64.xor"
	if op == 0x86 do return "i64.shl"
	if op == 0x87 do return "i64.shr_s"
	if op == 0xa7 do return "i32.wrap_i64"
	if op == 0xac do return "i64.extend_i32_s"
	if op == 0xad do return "i64.extend_i32_u"
	return "op"
}
