package zydis

import "core:c"

when ODIN_OS == .Linux {
	foreign import lib {"../vendored/zydis/build/libZydis.a", "../vendored/zydis/build/zycore/libZycore.a"}
} else {
	#panic("zydis bindings: add a foreign import for this platform")
}

U8 :: c.uint8_t
U16 :: c.uint16_t
U32 :: c.uint32_t
U64 :: c.uint64_t
I8 :: c.int8_t
I16 :: c.int16_t
I32 :: c.int32_t
I64 :: c.int64_t
USize :: c.size_t
Bool :: U8

Status :: U32

SUCCESS :: proc "contextless" (status: Status) -> bool {
	return (status & 0x8000_0000) == 0
}

MAX_INSTRUCTION_LENGTH :: 15
MAX_OPERAND_COUNT :: 10
MAX_OPERAND_COUNT_VISIBLE :: 5

MachineMode :: enum i32 {
	LONG_64,
	LONG_COMPAT_32,
	LONG_COMPAT_16,
	LEGACY_32,
	LEGACY_16,
	REAL_16,
}

StackWidth :: enum i32 {
	_16,
	_32,
	_64,
}

ElementType :: enum i32 {
	INVALID,
	STRUCT,
	UINT,
	INT,
	FLOAT16,
	FLOAT32,
	FLOAT64,
	FLOAT80,
	BFLOAT16,
	LONGBCD,
	CC,
}

OperandType :: enum i32 {
	UNUSED,
	REGISTER,
	MEMORY,
	POINTER,
	IMMEDIATE,
}

OperandEncoding :: enum i32 {
	NONE,
	MODRM_REG,
	MODRM_RM,
	OPCODE,
	NDSNDD,
	IS4,
	MASK,
	DISP8,
	DISP16,
	DISP32,
	DISP64,
	DISP16_32_64,
	DISP32_32_64,
	DISP16_32_32,
	UIMM8,
	UIMM16,
	UIMM32,
	UIMM64,
	UIMM16_32_64,
	UIMM32_32_64,
	UIMM16_32_32,
	SIMM8,
	SIMM16,
	SIMM32,
	SIMM64,
	SIMM16_32_64,
	SIMM32_32_64,
	SIMM16_32_32,
	JIMM8,
	JIMM16,
	JIMM32,
	JIMM64,
	JIMM16_32_64,
	JIMM32_32_64,
	JIMM16_32_32,
}

OperandVisibility :: enum i32 {
	INVALID,
	EXPLICIT,
	IMPLICIT,
	HIDDEN,
}

OperandActions :: U8

OperandAction :: enum U8 {
	READ      = 0x01,
	WRITE     = 0x02,
	CONDREAD  = 0x04,
	CONDWRITE = 0x08,
}

InstructionEncoding :: enum i32 {
	LEGACY,
	_3DNOW,
	XOP,
	VEX,
	EVEX,
	MVEX,
	REX2,
}

OpcodeMap :: enum i32 {
	DEFAULT,
	_0F,
	_0F38,
	_0F3A,
	MAP4,
	MAP5,
	MAP6,
	MAP7,
	_0F0F,
	XOP8,
	XOP9,
	XOPA,
}

MemoryOperandType :: enum i32 {
	INVALID,
	MEM,
	AGEN,
	MIB,
	VSIB,
}

BranchType :: enum i32 {
	NONE,
	SHORT,
	NEAR,
	FAR,
	ABSOLUTE,
}

MaskMode :: enum i32 {
	NONE,
	DISABLED,
	MERGING,
	ZEROING,
	CONTROL,
	CONTROL_ZEROING,
}

BroadcastMode :: enum i32 {
	NONE,
	_1_TO_2,
	_1_TO_4,
	_1_TO_8,
	_1_TO_16,
	_1_TO_32,
	_1_TO_64,
	_2_TO_4,
	_2_TO_8,
	_2_TO_16,
	_4_TO_8,
	_4_TO_16,
	_8_TO_16,
}

RoundingMode :: enum i32 {
	NONE,
	RN,
	RD,
	RU,
	RZ,
}

SwizzleMode :: enum i32 {
	NONE,
	DCBA,
	CDAB,
	BADC,
	DACB,
	AAAA,
	BBBB,
	CCCC,
	DDDD,
}

ConversionMode :: enum i32 {
	NONE,
	FLOAT16,
	SINT8,
	UINT8,
	SINT16,
	UINT16,
}

SourceConditionCode :: enum i32 {
	NONE,
	O,
	NO,
	B,
	NB,
	Z,
	NZ,
	BE,
	NBE,
	S,
	NS,
	TRUE,
	FALSE,
	L,
	NL,
	LE,
	NLE,
}

PrefixType :: enum i32 {
	IGNORED,
	EFFECTIVE,
	MANDATORY,
}

Mnemonic :: distinct i32
Register :: distinct i32
ISASet :: distinct i32
ISAExt :: distinct i32
InstructionCategory :: distinct i32

ElementSize :: U16
OperandAttributes :: U8
InstructionAttributes :: U64
AccessedFlagsMask :: U32
DefaultFlagsValue :: U8

DecodedOperandReg :: struct {
	value: Register,
}

DecodedOperandMemDisp :: struct {
	value:  I64,
	offset: U8,
	size:   U8,
}

DecodedOperandMem :: struct {
	type:    MemoryOperandType,
	segment: Register,
	base:    Register,
	index:   Register,
	scale:   U8,
	disp:    DecodedOperandMemDisp,
}

DecodedOperandPtr :: struct {
	segment: U16,
	offset:  U32,
}

DecodedOperandImmValue :: struct #raw_union {
	u: U64,
	s: I64,
}

DecodedOperandImm :: struct {
	is_signed:   Bool,
	is_address:  Bool,
	is_relative: Bool,
	value:       DecodedOperandImmValue,
	offset:      U8,
	size:        U8,
}

DecodedOperand :: struct {
	id:            U8,
	visibility:    OperandVisibility,
	actions:       OperandActions,
	encoding:      OperandEncoding,
	size:          U16,
	element_type:  ElementType,
	element_size:  ElementSize,
	element_count: U16,
	attributes:    OperandAttributes,
	type:          OperandType,
	using _:       struct #raw_union {
		reg: DecodedOperandReg,
		mem: DecodedOperandMem,
		ptr: DecodedOperandPtr,
		imm: DecodedOperandImm,
	},
}

AccessedFlags :: struct {
	tested:    AccessedFlagsMask,
	modified:  AccessedFlagsMask,
	set_0:     AccessedFlagsMask,
	set_1:     AccessedFlagsMask,
	undefined: AccessedFlagsMask,
}

DecodedInstructionAvxMask :: struct {
	mode: MaskMode,
	reg:  Register,
}

DecodedInstructionAvxBroadcast :: struct {
	is_static: Bool,
	mode:      BroadcastMode,
}

DecodedInstructionAvxRounding :: struct {
	mode: RoundingMode,
}

DecodedInstructionAvxSwizzle :: struct {
	mode: SwizzleMode,
}

DecodedInstructionAvxConversion :: struct {
	mode: ConversionMode,
}

DecodedInstructionAvx :: struct {
	vector_length:     U16,
	mask:              DecodedInstructionAvxMask,
	broadcast:         DecodedInstructionAvxBroadcast,
	rounding:          DecodedInstructionAvxRounding,
	swizzle:           DecodedInstructionAvxSwizzle,
	conversion:        DecodedInstructionAvxConversion,
	has_sae:           Bool,
	has_eviction_hint: Bool,
}

DecodedInstructionApx :: struct {
	uses_egpr:     Bool,
	has_nf:        Bool,
	has_zu:        Bool,
	has_ppx:       Bool,
	scc:           SourceConditionCode,
	default_flags: DefaultFlagsValue,
}

DecodedInstructionMeta :: struct {
	category:        InstructionCategory,
	isa_set:         ISASet,
	isa_ext:         ISAExt,
	branch_type:     BranchType,
	exception_class: i32,
}

RawPrefix :: struct {
	type:  PrefixType,
	value: U8,
}

RawRex :: struct {
	W, R, X, B, offset: U8,
}

RawRex2 :: struct {
	M0, R4, X4, B4, W, R3, X3, B3, offset: U8,
}

RawXop :: struct {
	R, X, B, m_mmmm, W, vvvv, L, pp, offset: U8,
}

RawVex :: struct {
	R, X, B, m_mmmm, W, vvvv, L, pp, offset, size: U8,
}

RawEvex :: struct {
	R3,
	X3,
	B3,
	R4,
	B4,
	mmm,
	W,
	vvvv,
	U,
	X4,
	pp,
	z,
	L2,
	L,
	b,
	V4,
	aaa,
	ND,
	NF,
	SCC,
	offset: U8,
}

RawMvex :: struct {
	R, X, B, R2, mmmm, W, vvvv, pp, E, SSS, V2, kkk, offset: U8,
}

RawModRm :: struct {
	mod, reg, rm, offset: U8,
}

RawSib :: struct {
	scale, index, base, offset: U8,
}

RawDisp :: struct {
	value:  I64,
	size:   U8,
	offset: U8,
}

RawImm :: struct {
	is_signed:   Bool,
	is_address:  Bool,
	is_relative: Bool,
	value:       DecodedOperandImmValue,
	size:        U8,
	offset:      U8,
}

DecodedInstructionRaw :: struct {
	prefix_count: U8,
	prefixes:     [MAX_INSTRUCTION_LENGTH]RawPrefix,
	encoding2:    InstructionEncoding,
	using _:      struct #raw_union {
		rex:  RawRex,
		rex2: RawRex2,
		xop:  RawXop,
		vex:  RawVex,
		evex: RawEvex,
		mvex: RawMvex,
	},
	modrm:        RawModRm,
	sib:          RawSib,
	disp:         RawDisp,
	imm:          [2]RawImm,
}

DecodedInstruction :: struct {
	machine_mode:          MachineMode,
	mnemonic:              Mnemonic,
	length:                U8,
	encoding:              InstructionEncoding,
	opcode_map:            OpcodeMap,
	opcode:                U8,
	stack_width:           U8,
	operand_width:         U8,
	address_width:         U8,
	operand_count:         U8,
	operand_count_visible: U8,
	attributes:            InstructionAttributes,
	cpu_flags:             ^AccessedFlags,
	fpu_flags:             ^AccessedFlags,
	avx:                   DecodedInstructionAvx,
	apx:                   DecodedInstructionApx,
	meta:                  DecodedInstructionMeta,
	raw:                   DecodedInstructionRaw,
}

DisassembledInstruction :: struct {
	runtime_address: U64,
	info:            DecodedInstruction,
	operands:        [MAX_OPERAND_COUNT]DecodedOperand,
	text:            [96]u8,
}

@(default_calling_convention = "c", link_prefix = "Zydis")
foreign lib {
	DisassembleIntel :: proc(machine_mode: MachineMode, runtime_address: U64, buffer: rawptr, length: USize, instruction: ^DisassembledInstruction) -> Status ---
	DisassembleATT :: proc(machine_mode: MachineMode, runtime_address: U64, buffer: rawptr, length: USize, instruction: ^DisassembledInstruction) -> Status ---

	MnemonicGetString :: proc(mnemonic: Mnemonic) -> cstring ---
	RegisterGetString :: proc(reg: Register) -> cstring ---
	ISASetGetString :: proc(isa_set: ISASet) -> cstring ---
	ISAExtGetString :: proc(isa_ext: ISAExt) -> cstring ---
	CategoryGetString :: proc(category: InstructionCategory) -> cstring ---
	GetVersion :: proc() -> U64 ---
}
