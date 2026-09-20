package arm

import backend ".."

Reg :: backend.Reg

RK_GENERAL :: Reg_Kind(0)
RK_VECTOR :: Reg_Kind(1)
RK_COUNT :: 2

X0 :: Reg(0)
X1 :: Reg(1)
X2 :: Reg(2)
X3 :: Reg(3)
X4 :: Reg(4)
X5 :: Reg(5)
X6 :: Reg(6)
X7 :: Reg(7)
X8 :: Reg(8)
X9 :: Reg(9)
X10 :: Reg(10)
X11 :: Reg(11)
X12 :: Reg(12)
X13 :: Reg(13)
X14 :: Reg(14)
X15 :: Reg(15)
X16 :: Reg(16)
X17 :: Reg(17)
X18 :: Reg(18)
X19 :: Reg(19)
X20 :: Reg(20)
X21 :: Reg(21)
X22 :: Reg(22)
X23 :: Reg(23)
X24 :: Reg(24)
X25 :: Reg(25)
X26 :: Reg(26)
X27 :: Reg(27)
X28 :: Reg(28)
X29 :: Reg(29)
X30 :: Reg(30)
XZR :: Reg(31)

V_BANK :: u16(RK_VECTOR) << 12
V0 :: Reg(V_BANK | 0)
V1 :: Reg(V_BANK | 1)
V2 :: Reg(V_BANK | 2)
V3 :: Reg(V_BANK | 3)
V4 :: Reg(V_BANK | 4)
V5 :: Reg(V_BANK | 5)
V6 :: Reg(V_BANK | 6)
V7 :: Reg(V_BANK | 7)
V8 :: Reg(V_BANK | 8)
V9 :: Reg(V_BANK | 9)
V10 :: Reg(V_BANK | 10)
V11 :: Reg(V_BANK | 11)
V12 :: Reg(V_BANK | 12)
V13 :: Reg(V_BANK | 13)
V14 :: Reg(V_BANK | 14)
V15 :: Reg(V_BANK | 15)
V16 :: Reg(V_BANK | 16)
V17 :: Reg(V_BANK | 17)
V18 :: Reg(V_BANK | 18)
V19 :: Reg(V_BANK | 19)
V20 :: Reg(V_BANK | 20)
V21 :: Reg(V_BANK | 21)
V22 :: Reg(V_BANK | 22)
V23 :: Reg(V_BANK | 23)
V24 :: Reg(V_BANK | 24)
V25 :: Reg(V_BANK | 25)
V26 :: Reg(V_BANK | 26)
V27 :: Reg(V_BANK | 27)
V28 :: Reg(V_BANK | 28)
V29 :: Reg(V_BANK | 29)
V30 :: Reg(V_BANK | 30)
V31 :: Reg(V_BANK | 31)

ARM_SYSTEMV_CC := backend.Call_Conv {
	name         = "ARM_SYSTEMV_CC",
	caller_saved = {
		{
			X0,
			X1,
			X2,
			X3,
			X4,
			X5,
			X6,
			X7,
			X8,
			X9,
			X10,
			X11,
			X12,
			X13,
			X14,
			X15,
			X16,
			X17,
			X18,
		},
		{
			V0,
			V1,
			V2,
			V3,
			V4,
			V5,
			V6,
			V7,
			V16,
			V17,
			V18,
			V19,
			V20,
			V21,
			V22,
			V23,
			V24,
			V25,
			V26,
			V27,
			V28,
			V29,
			V30,
			V31,
		},
	},
	callee_saved = {
		{X19, X20, X21, X22, X23, X24, X25, X26, X27, X28},
		{V8, V9, V10, V11, V12, V13, V14, V15},
	},
	args         = {
		{X0, X1, X2, X3, X4, X5, X6, X7},
		{V0, V1, V2, V3, V4, V5, V6, V7},
	},
	rets         = {{X0, X1}, {V0, V1}},
}

GEN_SPEC :: #config(ARM_GEN_SPEC, false)

COMMAND :: "odin run backend/arm -define:ARM_GEN_SPEC=true"

SPEC_NOT_PRESENT :: (#load("node_specs.odin", string) or_else "") == ""

when SPEC_NOT_PRESENT {
	Reg_Kind :: backend.Reg_Kind

	inherit_idx_of :: proc($T: typeid) -> u8 {return 0}

	ARM_Node_Type :: enum u16 {}

	when !GEN_SPEC {
		#panic("Missing generated files, run `" + COMMAND + "`")
	}
}

arm_peep :: proc(
	_: backend.Peep_Ctx,
	_: backend.Expanded_Node,
	_: $T,
) -> backend.Node_ID {
	return 0
}

arm_post_schedule_peep :: proc(
	_: backend.PS_Peep_Ctx,
	_: backend.Expanded_Node,
	_: $T,
) -> backend.Node_ID {
	return 0
}

arm_emit_function :: proc(
	_: backend.Codegen_Emit_Ctx,
) -> backend.Codegen_Output {
	panic("arm backend is unimplemented")
}
