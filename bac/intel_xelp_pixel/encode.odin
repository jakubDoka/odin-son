package bac_intel_xelp_pixel

Instruction :: [4]u32
NULL :: -1
GRF_COUNT :: 128
INSTRUCTION_BYTES :: 16

Opcode :: enum u8 {Mov = 0x61, Add = 0x40, Mul = 0x41, Cmp = 0x70, Sel = 0x62, And = 0x65, Or = 0x66, Xor = 0x67, Shr = 0x68, Shl = 0x69}
Data_Type :: enum {F32, U32}
Condition :: enum u8 {None, Eq, Ne, Gt, Ge, Lt, Le}
Predicate :: enum {None, F0, Not_F0}
Source_Kind :: enum {Register, Immediate}
Source :: struct {
	kind: Source_Kind,
	reg: int,
	bits: u32,
	broadcast: bool,
}
ALU :: struct {
	op: Opcode,
	type: Data_Type,
	dst: int,
	src0, src1: Source,
	condition: Condition,
	predicate: Predicate,
	distance: u8,
	write_enable: bool,
}
Error :: enum {None, Opcode, Type, Register, Source, Condition, Predicate, Dependency, Buffer}

reg :: proc(index: int, broadcast := false) -> Source {
	return {kind = .Register, reg = index, broadcast = broadcast}
}
imm :: proc(bits: u32) -> Source {return {kind = .Immediate, bits = bits}}
imm_f32 :: proc(value: f32) -> Source {return imm(transmute(u32)value)}

valid_reg :: proc(index: int) -> bool {return index >= 0 && index < GRF_COUNT}
valid_source :: proc(src: Source) -> bool {
	switch src.kind {
	case .Register: return valid_reg(src.reg) && src.bits == 0
	case .Immediate: return src.reg == 0 && !src.broadcast
	}
	return false
}

source_bits :: proc(src: Source) -> u32 {
	if src.broadcast do return (u32(src.reg) << 8) | 4
	return (u32(src.reg) << 8) | 0x00460005
}

encode_alu :: proc(a: ALU) -> (Instruction, Error) {
	if a.op != .Mov && a.op != .Add && a.op != .Mul && a.op != .Cmp && a.op != .Sel && a.op != .And && a.op != .Or && a.op != .Xor && a.op != .Shr && a.op != .Shl do return {}, .Opcode
	if (a.op == .And || a.op == .Or || a.op == .Xor || a.op == .Shr || a.op == .Shl) && a.type != .U32 do return {}, .Type
	if a.type != .F32 && a.type != .U32 do return {}, .Type
	if !valid_reg(a.dst) && !(a.op == .Cmp && a.dst == NULL) do return {}, .Register
	if !valid_source(a.src0) do return {}, .Source
	if a.op != .Mov && (!valid_source(a.src1) || a.src0.kind != .Register) do return {}, .Source
	if a.op == .Mov && a.src1 != (Source{}) do return {}, .Source
	if a.condition > .Le || (a.op == .Cmp) != (a.condition != .None) do return {}, .Condition
	if a.predicate != .None && a.predicate != .F0 && a.predicate != .Not_F0 do return {}, .Predicate
	if a.op == .Sel && a.predicate == .None do return {}, .Predicate
	if a.distance > 7 do return {}, .Dependency

	// mov/add/mul/cmp/sel/and/or/xor (8|M0) r{dst}.0<1>:{type} r{src0}.0<8;8,1>:{type} r{src1}.0<8;8,1>:{type} {@distance}
	w: Instruction
	w[0] = u32(a.op) | (3 << 16) | (u32(a.distance) << 8)
	if a.write_enable do w[0] |= 1 << 31
	if a.predicate != .None do w[0] |= 1 << 24
	if a.predicate == .Not_F0 do w[0] |= 1 << 28
	type_bits := u32(2)
	if a.type == .F32 do type_bits = 10
	w[1] = (type_bits << 4) | (type_bits << 8) | (1 << 16)
	if a.dst != NULL do w[1] |= (u32(a.dst) << 24) | (1 << 18)
	if a.op == .Mov {
		if a.src0.kind == .Immediate {
			w[1] |= 1 << 14
			w[3] = a.src0.bits
		} else {
			w[2] = source_bits(a.src0)
		}
	} else {
		w[2] = source_bits(a.src0) | (type_bits << 24) | (u32(a.condition) << 28)
		if a.src1.kind == .Immediate {
			w[1] |= 1 << 15
			w[3] = a.src1.bits
		} else {
			w[3] = source_bits(a.src1)
		}
	}
	return w, .None
}

write_instruction :: proc(dst: []u8, instruction: Instruction) -> Error {
	if len(dst) < INSTRUCTION_BYTES do return .Buffer
	for word, i in instruction {
		for j in 0 ..< 4 do dst[4*i+j] = u8(word >> uint(8*j))
	}
	return .None
}
