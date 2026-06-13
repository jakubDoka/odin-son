package backend

import "../vendored/gam/util/arna"
import "base:intrinsics"
import "core:fmt"

NOOP_REX :: 0b0100_0000

@(rodata)
X64_CLASSES := [X64_Node_Type]Class_Spec{}

GPA_MASK :: []int{0xFFFF & ~int(1 << X64_Reg.Rsi)}
GPA_SPILL_MASK :: []int{~int(1 << X64_Reg.Rsi)}

@(rodata)
X64_IDEAL_REG_CLASSES := [Ideal_Node_Type]Reg_Class_Spec {
	.Start = {},
	.Entry = {},
	.CInt = {reg_masks = #partial{.General = {GPA_MASK}}},
	.Add ..= .Mul = {reg_masks = #partial{.General = {GPA_MASK, GPA_MASK, GPA_MASK}}, inplace_slot_idx = 0},
	.Split = {
		reg_masks = #partial{.General = {GPA_SPILL_MASK, GPA_SPILL_MASK}},
	},
	.Return = {input_start_idx = 1},
}

@(rodata)
X64_REG_CLASSES := [X64_Node_Type]Reg_Class_Spec{}

Mod :: enum u8 {
	Indirect,
	Indirect_Disp8,
	Indirect_Disp32,
	Direct,
}

mod_rm :: proc(mod: Mod, reg: X64_Reg, r_m: X64_Reg) -> u8 {
	Mod_Rm :: bit_field u8 {
		r_m: X64_Reg | 3,
		reg: X64_Reg | 3,
		mod: Mod     | 2,
	}

	return u8(Mod_Rm{mod = mod, reg = reg, r_m = r_m})
}

sib :: proc(base: X64_Reg, index: X64_Reg, #any_int scale: int) -> u8 {
	Sib :: bit_field u8 {
		base:  X64_Reg | 3,
		index: X64_Reg | 3,
		scale: u8      | 2,
	}

	assert(intrinsics.count_ones(scale) == 1 && scale <= 8)

	return u8(
		Sib {
			base = base,
			index = index,
			scale = u8(intrinsics.count_trailing_zeros(scale)),
		},
	)
}

rex :: proc(reg, ptr, idx: X64_Reg, wide: bool) -> u8 {
	res: u8 = NOOP_REX

	if wide do res |= 0b0000_1000
	if reg_idx(reg) >= 8 do res |= 0b0000_0100
	if reg_idx(idx) >= 8 do res |= 0b0000_0010
	if reg_idx(ptr) >= 8 do res |= 0b0000_0001

	return res
}

X64_Reg :: enum u16 {
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
	// NOTE: we wrap around when using this
	Xmm0,
	Xmm1,
	Xmm2,
	Xmm3,
	Xmm4,
	Xmm5,
	Xmm6,
	Xmm7,
	Xmm8,
	Xmm9,
	Xmm10,
	Xmm11,
	Xmm12,
	Xmm13,
	Xmm14,
	Xmm15,
}

reg_idx :: proc(reg: X64_Reg) -> u16 {
	return u16(reg) & 0xf
}

x64_reg_mask_of :: proc(
	graph: ^Graph,
	re: ^Regalloc,
	id: Node_ID,
	idx: int,
) -> Reg_Mask {
	node := graph_get(graph, id)

	ALL_GENERAL :: 0xffff & ~int(1 << uint(X64_Reg.Rsp))

	#partial switch node.itype {
	case .Return:
		assert(idx != 0)
		return reg_mask_single(re, {kind = .General, index = u16(X64_Reg.Rax)})
	case:
		fmt.panicf("TODO: %v")
	}
}

when !GEN_SPEC {
	x64_emit_function :: proc(ctx: Codegen_Emit_Ctx) -> Codegen_Output {
		start := ctx.code.pos

		reg_of :: proc(ctx: Codegen_Emit_Ctx, id: Node_ID) -> X64_Reg {
			node := graph_get(ctx, id)
			return X64_Reg(ctx.allocs[node.gvn].index)
		}

		assert(len(ctx.bbs) == 1)
		for bb in ctx.bbs {
			for instr in bb.instrs {
				node := graph_get(ctx, instr)
				inputs := graph_inputs(ctx, node)
				switch node.xtype {
				case .Start, .Entry:
					panic("Not reachable form here")
				case .CInt:
					emit_single_op(ctx.code, 0xb8, reg_of(ctx, instr))
					emit_anys(ctx.code, graph_extra(ctx, node, CInt).value)
				case .Add:
					dst := reg_of(ctx, inputs[0])
					rhs := reg_of(ctx, inputs[1])
					rx := rex(rhs, dst, .Rax, true)
					emit(ctx.code, {rx, 0x01, mod_rm(.Direct, rhs, dst)})
				case .Mul:
					dst := reg_of(ctx, inputs[0])
					rhs := reg_of(ctx, inputs[1])
					rx := rex(dst, dst, .Rax, true)
					emit(ctx.code, {rx, 0x0f, 0xaf, mod_rm(.Direct, dst, rhs)})
				case .Split:
					dst := reg_of(ctx, instr)
					src := reg_of(ctx, inputs[0])
					if dst == src do break
					assert(int(dst) < 16)
					assert(int(src) < 16)
					emit_reg_op(ctx.code, 0x89, src, dst)
				case .Return:
					emit(ctx.code, {0xc3})
				}
			}
		}

		return {code = ctx.code.ptr[start:ctx.code.pos]}
	}
}

emit_single_op :: proc(code: ^arna.Allocator, op_base: u8, dst: X64_Reg) {
	emit(code, {rex(.Rax, dst, .Rax, true), op_base + u8(reg_idx(dst))})
}

//pub fn emitRegOp(self: *X86_64Gen, op: u8, dst: Reg, src: Reg) void {
//    self.emitRex(dst, src, .rax, 8);
//    self.emitBytes(&.{ op, Reg.Mod.direct.rm(dst, src) });
//}

emit_reg_op :: proc(
	code: ^arna.Allocator,
	op: u8,
	dst: X64_Reg,
	src: X64_Reg,
) {
	emit(code, {rex(dst, src, .Rax, true), op, mod_rm(.Direct, dst, src)})
}
