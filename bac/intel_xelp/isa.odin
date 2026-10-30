package bac_intel_xelp

when !SPEC_NOT_PRESENT {
	@(rodata)
	FLOAT_OPS := #partial [Node_Type]Op {
		// add (8|M0) r{dst}.0<1>:f r{lhs}.0<8;8,1>:f r{rhs}.0<8;8,1>:f {@1}
		.Add = {0x00030140, 0x00050aa0, 0x0a460005, 0x00460005},
		// add (8|M0) r{dst}.0<1>:f r{lhs}.0<8;8,1>:f -r{rhs}.0<8;8,1>:f {@1}
		.Sub = {0x00030140, 0x00050aa0, 0x0a460005, 0x02460005},
		// mul (8|M0) r{dst}.0<1>:f r{lhs}.0<8;8,1>:f r{rhs}.0<8;8,1>:f {@1}
		.Mul = {0x00030141, 0x00050aa0, 0x0a460005, 0x00460005},
		// A non-float destination converts the comparison mask instead of preserving its bits.
		// cmp (8|M0) (eq)f0.0 r{dst}.0<1>:f r{lhs}.0<8;8,1>:f r{rhs}.0<8;8,1>:f {@1}
		.Eq  = {0x00030170, 0x00050aa0, 0x1a460005, 0x00460005},
		// cmp (8|M0) (ne)f0.0 r{dst}.0<1>:f r{lhs}.0<8;8,1>:f r{rhs}.0<8;8,1>:f {@1}
		.Ne  = {0x00030170, 0x00050aa0, 0x2a460005, 0x00460005},
		// cmp (8|M0) (lt)f0.0 r{dst}.0<1>:f r{lhs}.0<8;8,1>:f r{rhs}.0<8;8,1>:f {@1}
		.Lt  = {0x00030170, 0x00050aa0, 0x5a460005, 0x00460005},
		// cmp (8|M0) (le)f0.0 r{dst}.0<1>:f r{lhs}.0<8;8,1>:f r{rhs}.0<8;8,1>:f {@1}
		.Le  = {0x00030170, 0x00050aa0, 0x6a460005, 0x00460005},
		// cmp (8|M0) (gt)f0.0 r{dst}.0<1>:f r{lhs}.0<8;8,1>:f r{rhs}.0<8;8,1>:f {@1}
		.Gt  = {0x00030170, 0x00050aa0, 0x3a460005, 0x00460005},
		// cmp (8|M0) (ge)f0.0 r{dst}.0<1>:f r{lhs}.0<8;8,1>:f r{rhs}.0<8;8,1>:f {@1}
		.Ge  = {0x00030170, 0x00050aa0, 0x4a460005, 0x00460005},
		// mov (8|M0) r{dst}.0<1>:f -r{src}.0<8;8,1>:f {@1}
		.Neg = {0x00030161, 0x00052aa0, 0x00460005, 0},
		// math.inv (8|M0) r{dst}.0<1>:f r{src}.0<8;8,1>:f {@1,$2}
		.Inv = {0x00039238, 0x00050aa0, 0x10460005, 0},
	}

	@(rodata)
	UNSIGNED_CMP := #partial [Node_Type]Node_Type {
		.U_Lt = .Lt,
		.U_Gt = .Gt,
		.U_Le = .Le,
		.U_Ge = .Ge,
	}

	@(rodata)
	INT_OPS := #partial [Node_Type]Op {
		// mul (8|M0) r{dst}.0<1>:ud r{lhs}.0<8;8,1>:ud r{rhs}.0<16;8,2>:uw {@1}
		.Mul_Lo16 = {0x00030141, 0x00050220, 0x01460005, 0x00560006},
		// mul (8|M0) r{dst}.0<1>:ud r{lhs}.0<8;8,1>:ud r{rhs}.1<16;8,2>:uw {@1}
		.Mul_Hi16 = {0x00030141, 0x00050220, 0x01460005, 0x00560016},
		// add (8|M0) r{dst}.0<1>:ud r{lhs}.0<8;8,1>:ud r{rhs}.0<8;8,1>:ud {@1}
		.Add      = {0x00030140, 0x00050220, 0x02460005, 0x00460005},
		// add (8|M0) r{dst}.0<1>:ud r{lhs}.0<8;8,1>:ud -r{rhs}.0<8;8,1>:ud {@1}
		.Sub      = {0x00030140, 0x00050220, 0x02460005, 0x02460005},
		// shl (8|M0) r{dst}.0<1>:ud r{lhs}.0<8;8,1>:ud r{rhs}.0<8;8,1>:ud {@1}
		.Shl      = {0x00030169, 0x00050220, 0x02460005, 0x00460005},
		// shr (8|M0) r{dst}.0<1>:ud r{lhs}.0<8;8,1>:ud r{rhs}.0<8;8,1>:ud {@1}
		.U_Shr    = {0x00030168, 0x00050220, 0x02460005, 0x00460005},
		// asr (8|M0) r{dst}.0<1>:d r{lhs}.0<8;8,1>:d r{rhs}.0<8;8,1>:ud {@1}
		.Shr      = {0x0003016c, 0x00050660, 0x02460005, 0x00460005},
		// and (8|M0) r{dst}.0<1>:ud r{lhs}.0<8;8,1>:ud r{rhs}.0<8;8,1>:ud {@1}
		.And      = {0x00030165, 0x00050220, 0x02460005, 0x00460005},
		// or (8|M0) r{dst}.0<1>:ud r{lhs}.0<8;8,1>:ud r{rhs}.0<8;8,1>:ud {@1}
		.Or       = {0x00030166, 0x00050220, 0x02460005, 0x00460005},
		// xor (8|M0) r{dst}.0<1>:ud r{lhs}.0<8;8,1>:ud r{rhs}.0<8;8,1>:ud {@1}
		.Xor      = {0x00030167, 0x00050220, 0x02460005, 0x00460005},
		// math.iqot (8|M0) r{dst}.0<1>:ud r{lhs}.0<8;8,1>:ud r{rhs}.0<8;8,1>:ud {@1,$2}
		.U_Div    = {0x00039238, 0x00050220, 0xc2460005, 0x00460005},
		// math.irem (8|M0) r{dst}.0<1>:ud r{lhs}.0<8;8,1>:ud r{rhs}.0<8;8,1>:ud {@1,$2}
		.U_Rem    = {0x00039238, 0x00050220, 0xd2460005, 0x00460005},
	}
}

Opcode :: enum u8 {
	// Control / synchronization
	Illegal = 0x00,
	Sync    = 0x01,
	Jmpi    = 0x20,
	Brd     = 0x21,
	If      = 0x22,
	Brc     = 0x23,
	Else    = 0x24,
	Endif   = 0x25,
	While   = 0x27,
	Break   = 0x28,
	Cont    = 0x29,
	Halt    = 0x2A,
	Calla   = 0x2B,
	Call    = 0x2C,
	Ret     = 0x2D,
	Goto    = 0x2E,
	Join    = 0x2F,

	// Messages
	Send    = 0x31,
	Sendc   = 0x32,

	// Math / arithmetic
	Math    = 0x38,
	Add     = 0x40,
	Mul     = 0x41,
	Avg     = 0x42,
	Frc     = 0x43,
	Rndu    = 0x44,
	Rndd    = 0x45,
	Rnde    = 0x46,
	Rndz    = 0x47,
	Mac     = 0x48,
	Mach    = 0x49,
	Lzd     = 0x4A,
	Fbh     = 0x4B,
	Fbl     = 0x4C,
	Cbit    = 0x4D,
	Addc    = 0x4E,
	Subb    = 0x4F,
	Mad     = 0x5B,
	Madm    = 0x5D,

	// Data movement / selection
	Nop     = 0x60,
	Mov     = 0x61,
	Sel     = 0x62,
	Movi    = 0x63,

	// Logic / bit operations
	Not     = 0x64,
	And     = 0x65,
	Or      = 0x66,
	Xor     = 0x67,
	Shr     = 0x68,
	Shl     = 0x69,
	Smov    = 0x6A,
	Asr     = 0x6C,
	Ror     = 0x6E,
	Rol     = 0x6F,

	// Comparisons / conditional selection
	Cmp     = 0x70,
	Cmpn    = 0x71,
	Csel    = 0x72,

	// Bitfield operations
	Bfrev   = 0x77,
	Bfe     = 0x78,
	Bfi1    = 0x79,
	Bfi2    = 0x7A,
}

Data_Type :: enum u8 {
	UB = 0x0,
	UW = 0x1,
	UD = 0x2,
	B  = 0x4,
	W  = 0x5,
	D  = 0x6,
	HF = 0x9,
	F  = 0xa,
}

Register_File :: enum u8 {
	ARF,
	GRF,
}

SFID :: enum u8 {
	TS  = 0x7,
	DC1 = 0xc,
}

SBID_Mode :: enum u8 {
	Wait_Dst = 0x20,
	Wait_Src = 0x30,
	Set      = 0x40,
}
