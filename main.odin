package main

import zydis "./zydis"
import "core:fmt"

// A small hardcoded blob of x86-64 machine code to disassemble.
//
//   51                      push   rcx
//   8d 45 fa                lea    eax, [rbp-0x6]
//   48 8b 05 39 00 00 00    mov    rax, [rip+0x39]
//   e8 00 00 00 00          call   <rel32>
//   c3                      ret
INSTRUCTIONS := [?]u8 {
	0x51,
	0x8d,
	0x45,
	0xfa,
	0x48,
	0x8b,
	0x05,
	0x39,
	0x00,
	0x00,
	0x00,
	0xe8,
	0x00,
	0x00,
	0x00,
	0x00,
	0xc3,
}

main :: proc() {
	major := (zydis.GetVersion() >> 48) & 0xffff
	minor := (zydis.GetVersion() >> 32) & 0xffff
	fmt.printfln(
		"Zydis v%d.%d — disassembling %d bytes\n",
		major,
		minor,
		len(INSTRUCTIONS),
	)

	// Pretend the code lives here so RIP-relative operands resolve nicely.
	runtime_address: zydis.U64 = 0x0040_0000

	offset: int
	for offset < len(INSTRUCTIONS) {
		instr: zydis.DisassembledInstruction
		status := zydis.DisassembleIntel(
			.LONG_64,
			runtime_address + zydis.U64(offset),
			&INSTRUCTIONS[offset],
			zydis.USize(len(INSTRUCTIONS) - offset),
			&instr,
		)
		if !zydis.SUCCESS(status) {
			fmt.printfln(
				"0x%08x  <decode failed: %#x>",
				runtime_address + zydis.U64(offset),
				status,
			)
			break
		}

		// Raw bytes of just this instruction.
		length := int(instr.info.length)
		fmt.printf("0x%08x  ", instr.runtime_address)
		for b in INSTRUCTIONS[offset:offset + length] {
			fmt.printf("%02x ", b)
		}
		for _ in length ..< 12 {
			fmt.print("   ")
		}

		mnemonic := zydis.MnemonicGetString(instr.info.mnemonic)
		fmt.printfln(
			"%s    (%d operands, %s)",
			cstring(&instr.text[0]),
			instr.info.operand_count_visible,
			mnemonic,
		)

		offset += length
	}
}
