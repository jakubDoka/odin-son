package bac_intel_xelp

import "core:testing"

@(test)
reject_unsupported_operands :: proc(t: ^testing.T) {
	base := ALU{op = .Add, dst = 1, src0 = reg(2), src1 = reg(3)}
	for index in ([]int{-2, -1, 128, 256}) {
		a := base; a.dst = index
		_, err := encode_alu(a)
		testing.expect(t, err == .Register)
		a = base; a.src0 = reg(index)
		_, err = encode_alu(a)
		testing.expect(t, err == .Source)
	}
	a := base; a.src0 = imm(1)
	_, err := encode_alu(a); testing.expect(t, err == .Source)
	a = base; a.op = .Sel
	_, err = encode_alu(a); testing.expect(t, err == .Predicate)
	a = base; a.op = .Cmp
	_, err = encode_alu(a); testing.expect(t, err == .Condition)
	a = base; a.condition = .Lt
	_, err = encode_alu(a); testing.expect(t, err == .Condition)
	a = base; a.distance = 8
	_, err = encode_alu(a); testing.expect(t, err == .Dependency)
	a = base; a.op = Opcode(0xff)
	_, err = encode_alu(a); testing.expect(t, err == .Opcode)
	a = base; a.type = Data_Type(99)
	_, err = encode_alu(a); testing.expect(t, err == .Type)
	a = base; a.predicate = Predicate(99)
	_, err = encode_alu(a); testing.expect(t, err == .Predicate)
	a = base; a.op = .Cmp; a.condition = Condition(255)
	_, err = encode_alu(a); testing.expect(t, err == .Condition)
	a = base; a.src1.kind = Source_Kind(99)
	_, err = encode_alu(a); testing.expect(t, err == .Source)
	a = base; a.op = .Mov
	_, err = encode_alu(a); testing.expect(t, err == .Source)
}

@(test)
reject_invalid_messages :: proc(t: ^testing.T) {
	base := Send{sfid = .DC1, dst = 10, src0 = 20, src1 = NULL, descriptor = 0x02100000}
	_, err := encode_send(base); testing.expect(t, err == .None)
	s := base; s.sbid = 16
	_, err = encode_send(s); testing.expect(t, err == .Dependency)
	s = base; s.extended_descriptor = 1
	_, err = encode_send(s); testing.expect(t, err == .Descriptor)
	s = base; s.descriptor |= 1 << 29
	_, err = encode_send(s); testing.expect(t, err == .Descriptor)
	s = base; s.descriptor = 0x00100000
	_, err = encode_send(s); testing.expect(t, err == .Payload)
	s = base; s.dst = NULL
	_, err = encode_send(s); testing.expect(t, err == .Payload)
	s = base; s.src0 = 127; s.descriptor = 0x04100000
	_, err = encode_send(s); testing.expect(t, err == .Payload)
	s = base; s.dst = 127; s.descriptor = 0x02200000
	_, err = encode_send(s); testing.expect(t, err == .Payload)
	s = base; s.extended_descriptor = 0x80
	_, err = encode_send(s); testing.expect(t, err == .Payload)
	s = base; s.src1 = 127; s.extended_descriptor = 0x80
	_, err = encode_send(s); testing.expect(t, err == .Payload)
	s = base; s.end_of_thread = true
	_, err = encode_send(s); testing.expect(t, err == .End_Of_Thread)
	s = base; s.sfid = SFID(15)
	_, err = encode_send(s); testing.expect(t, err == .SFID)
}

@(test)
reject_invalid_dependencies :: proc(t: ^testing.T) {
	for s in ([]Sync{{kind = .Distance, value = 0}, {kind = .Distance, value = 8}, {kind = .Source, value = 16}, {kind = .Destination, value = 16}, {kind = .All_Reads, value = 1}, {kind = .All_Writes, value = 1}, {kind = Sync_Kind(99)}}) {
		_, err := encode_sync(s)
		testing.expect(t, err == .Dependency)
	}
}

@(test)
little_endian_and_short_buffer :: proc(t: ^testing.T) {
	data := [16]u8{0 ..= 15 = 0xaa}
	original := data
	testing.expect(t, write_instruction(data[:15], {0x12345678, 0, 0, 0}) == .Buffer)
	testing.expect(t, data == original)
	testing.expect(t, write_instruction(data[:], {0x12345678, 0, 0, 0xabcdef01}) == .None)
	testing.expect(t, data[0] == 0x78 && data[3] == 0x12 && data[12] == 1 && data[15] == 0xab)
}
