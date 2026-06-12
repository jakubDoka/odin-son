package backend

import "core:fmt"

@(rodata)
X64_CLASSES := [X64_Node_Type]Class_Spec{}

@(rodata)
X64_IDEAL_REG_CLASSES := [I_Node_Type]Reg_Class_Spec {
	.Start = {},
	.Entry = {},
	.CInt = {
		reg_masks = #partial{.General = {{0xFFFF & ~int(1 << X64_Gpa.Rsi)}}},
	},
	.Return = {input_start_idx = 1},
}

@(rodata)
X64_REG_CLASSES := [X64_Node_Type]Reg_Class_Spec{}

X64_Node_Type :: enum u16 {}

X64_Gpa :: enum u16 {
	Rax,
	Rbx,
	Rcx,
	Rdx,
	Rsi,
	Rdi,
	Rbp,
	Rsp,
	R8,
	R9,
	R10,
	R11,
	R12,
	R13,
	R14,
	R15,
}

x64_reg_mask_of :: proc(
	graph: ^Graph,
	re: ^Regalloc,
	id: Node_ID,
	idx: int,
) -> Reg_Mask {
	node := graph_get(graph, id)

	ALL_GENERAL :: 0xffff & ~int(1 << uint(X64_Gpa.Rsp))

	#partial switch node.itype {
	case .Return:
		assert(idx != 0)
		return reg_mask_single(re, {kind = .General, index = u16(X64_Gpa.Rax)})
	case:
		fmt.panicf("TODO: %v")
	}
}
