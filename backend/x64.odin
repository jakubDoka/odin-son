package backend

import "../vendored/gam/util/arna"
import "../vendored/gam/util/bit_arr"
import "base:intrinsics"
import "core:fmt"
import "core:reflect"

NOOP_REX :: 0b0100_0000

GPA_MASK :: []int{0xFFFF & ~int(1 << X64_Reg.Rsp)}
GPA_SPILL_MASK :: []int{~int(1 << X64_Reg.Rsp)}
RIP :: X64_Reg.Rbp
NO_INDEX :: X64_Reg.Rsp

@(rodata)
X64_IDEAL_REG_CLASSES := [Ideal_Node_Type]Reg_Class_Spec {
	.Start = {},
	.Entry = {},
	.CInt = {reg_masks = #partial{.General = {GPA_MASK}}},
	.Add ..= .Eq = {reg_masks = #partial{.General = {GPA_MASK, GPA_MASK, GPA_MASK}}, inplace_slot_idx = 0},
	.Split = {
		reg_masks = #partial{.General = {GPA_SPILL_MASK, GPA_SPILL_MASK}},
	},
	.Phi = {
		reg_masks = #partial{
			.General = {GPA_SPILL_MASK, GPA_SPILL_MASK, GPA_SPILL_MASK},
		},
	},
	.If = {
		reg_masks = #partial{.General = {{}, GPA_MASK}},
		input_start_idx = 1,
	},
	.Then = {},
	.Else = {},
	.Jump = {input_start_idx = 1},
	.Region = {},
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

mod_sm :: #force_inline proc(mod: Mod, #any_int sub: int, r_m: X64_Reg) -> u8 {
	return mod_rm(mod, X64_Reg(sub), r_m)
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
	Rsp,
	Rbp,
	Rsi,
	Rdi,
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
		fmt.panicf("TODO: %v %v", node.itype, idx)
	}
}

when !GEN_SPEC {
	x64_emit_function :: proc(ectx: Codegen_Emit_Ctx) -> Codegen_Output {
		start := ectx.code.pos

		Ctx :: struct {
			using inner:     Codegen_Emit_Ctx,
			spill_slot_base: [Reg_Kind]int,
		}

		ctx: Ctx
		ctx.inner = ectx

		reg_kind_of :: proc(
			ctx: Codegen_Emit_Ctx,
			id: Node_ID,
		) -> (
			X64_Reg,
			Reg_Kind,
		) {
			node := graph_get(ctx, id)
			return X64_Reg(ctx.allocs[node.gvn].index),
				ctx.allocs[node.gvn].kind
		}

		reg_of :: proc(ctx: Codegen_Emit_Ctx, id: Node_ID) -> X64_Reg {
			node := graph_get(ctx, id)
			return X64_Reg(ctx.allocs[node.gvn].index)
		}

		spill_slot_count: [Reg_Kind]int

		slot: [2]int
		used := bit_arr.init_from_masks(slot[:])

		for reg in ctx.allocs {
			spill_slot_count[reg.kind] = max(
				spill_slot_count[reg.kind],
				int(reg.index) - 16 + 1,
			)
			bit_arr.set_unbounded(used, int(reg.index))
		}

		total_spill_size := 0
		for size, kind in spill_slot_count {
			ctx.spill_slot_base[kind] = total_spill_size
			total_spill_size += size
		}

		stack_size := total_spill_size * 8

		for reg in ([]X64_Reg{.Rbx, .Rbp, .R12, .R13, .R14, .R15}) {
			if bit_arr.contains(used, int(reg)) {
				emit_single_op(ctx.code, 0x50, reg)
			}
		}

		if stack_size != 0 {
			emit_imm_op(ctx.code, 0x81, 0b101, .Rsp, stack_size)
		}

		Local_Reloc :: struct {
			dest:   u32,
			offset: u32,
			off:    u32,
		}

		local_relocs := make([dynamic]Local_Reloc, 0, len(ctx.bbs))
		block_base := ctx.gvn - u32(len(ctx.bbs))

		for &bb, i in ctx.bbs {
			bb.offset = u32(ctx.code.pos)
			for instr in bb.instrs {
				node := graph_expand(ctx, instr)
				switch node.xtype {
				case .Start, .Entry, .Then, .Else, .Region:
					panic("Not reachable form here")
				case .If:
					cond := reg_of(ctx, node.inps[1])
					rx := rex(cond, cond, .Rax, true)
					emit(ctx.code, {rx, 0x85, mod_rm(.Direct, cond, cond)})

					assert(len(node.outs) == 2)
					append(
						&local_relocs,
						Local_Reloc {
							dest = graph_get(ctx, node.outs[1].id).gvn -
							block_base,
							offset = u32(ctx.code.pos),
							off = 2,
						},
					)

					emit(ctx.code, {0x0f, 0x84, 0, 0, 0, 0})

					fallthrough
				case .Jump:
					append(
						&local_relocs,
						Local_Reloc {
							dest = graph_get(ctx, node.outs[0].id).gvn -
							block_base,
							offset = u32(ctx.code.pos),
							off = 1,
						},
					)

					emit(ctx.code, {0xE9, 0, 0, 0, 0})
				case .Phi:
				case .CInt:
					emit_single_op(ctx.code, 0xb8, reg_of(ctx, instr))
					emit_anys(ctx.code, graph_extra(ctx, node, CInt).value)
				case .Add:
					dst := reg_of(ctx, node.inps[0])
					rhs := reg_of(ctx, node.inps[1])
					rx := rex(rhs, dst, .Rax, true)
					emit(ctx.code, {rx, 0x01, mod_rm(.Direct, rhs, dst)})
				case .Mul:
					dst := reg_of(ctx, node.inps[0])
					rhs := reg_of(ctx, node.inps[1])
					rx := rex(dst, rhs, .Rax, true)
					emit(ctx.code, {rx, 0x0f, 0xaf, mod_rm(.Direct, dst, rhs)})
				case .Eq:
					lhs := reg_of(ctx, node.inps[0])
					rhs := reg_of(ctx, node.inps[1])
					rx := rex(lhs, rhs, .Rax, true)
					emit(ctx.code, {rx, 0x3b, mod_rm(.Direct, lhs, rhs)})

					rx = rex(.Rax, lhs, .Rax, true)
					emit(
						ctx.code,
						{rx, 0x0F, 0x94, mod_sm(.Direct, 0b000, lhs)},
					)

					rx = rex(lhs, lhs, .Rax, true)
					emit(ctx.code, {rx, 0x0F, 0xB6, mod_rm(.Direct, lhs, lhs)})
				case .Split:
					dst, dkind := reg_kind_of(ctx, instr)
					src, skind := reg_kind_of(ctx, node.inps[0])
					assert(dkind == skind)
					if dst == src do break
					if int(dst) >= 16 {
						dst_offset :=
							ctx.spill_slot_base[dkind] + 8 * (int(dst) - 16)

						assert(int(src) < 16)

						emit(ctx.code, {rex(src, .Rsp, .Rax, true), 0x89})
						emit_indirect_addr(
							ctx.code,
							src,
							.Rsp,
							NO_INDEX,
							1,
							dst_offset,
						)
					} else if int(src) >= 16 {
						src_offset :=
							ctx.spill_slot_base[dkind] + 8 * (int(src) - 16)
						assert(int(dst) < 16)

						emit(ctx.code, {rex(dst, .Rsp, .Rax, true), 0x8b})
						emit_indirect_addr(
							ctx.code,
							dst,
							.Rsp,
							NO_INDEX,
							1,
							src_offset,
						)
					} else {
						assert(int(dst) < 16)
						assert(int(src) < 16)

						emit_reg_op(ctx.code, 0x89, src, dst)
					}
				case .Return:
					if stack_size != 0 {
						emit_imm_op(ctx.code, 0x81, 0b101, .Rsp, -stack_size)
					}

					#reverse for reg in ([]X64_Reg {
							.Rbx,
							.Rbp,
							.R12,
							.R13,
							.R14,
							.R15,
						}) {
						if bit_arr.contains(used, int(reg)) {
							emit_single_op(ctx.code, 0x58, reg)
						}
					}

					emit(ctx.code, {0xc3})
				}
			}
		}

		for reloc in local_relocs {
			size: u32 = 4

			dst_offset := ctx.bbs[reloc.dest].offset
			jump := dst_offset - reloc.offset - size - reloc.off

			copy(
				ctx.code.ptr[reloc.offset + reloc.off:][:size],
				reflect.as_bytes(jump),
			)
		}

		return {code = ctx.code.ptr[start:ctx.code.pos]}
	}
}

emit_single_op :: proc(code: ^arna.Allocator, op_base: u8, dst: X64_Reg) {
	emit(
		code,
		{rex(.Rax, dst, .Rax, true), op_base + u8(reg_idx(dst) & 0b111)},
	)
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

// pub fn fromDis(dis: i64) Mod {
//     return switch (dis) {
//         0 => .indirect,
//         std.math.minInt(i8)...-1, 1...std.math.maxInt(i8) => .indirect_disp8,
//         else => .indirect_disp32,
//     };
// }

mod_from_dis :: proc(dis: i64) -> Mod {
	switch dis {
	case 0:
		return .Indirect
	case -128 ..< 127:
		return .Indirect_Disp8
	case:
		return .Indirect_Disp32
	}
}

emit_indirect_addr :: proc(
	code: ^arna.Allocator,
	reg: X64_Reg,
	base: X64_Reg,
	index: X64_Reg,
	scale: u64,
	#any_int dis: i64,
	is_reloc: bool = false,
) {
	mod := mod_from_dis(dis)

	assert(mod != .Direct)

	ill_base := base == .Rsp || base == .R12

	if mod == .Indirect && !is_reloc && (base == RIP || base == .R13) {
		mod = .Indirect_Disp8
	}

	if index != NO_INDEX || ill_base || scale != 1 {
		emit(code, {mod_rm(mod, reg, .Rsp), sib(base, index, scale)})
	} else {
		emit(code, {mod_rm(mod, reg, base)})
	}

	switch mod {
	case .Indirect:
	case .Indirect_Disp8:
		emit(code, {u8(dis)})
	case .Indirect_Disp32:
		emit_anys(code, u32(dis))
	case .Direct:
		fallthrough
	case:
		panic("unreachable")
	}
}

emit_imm_op :: proc(
	code: ^arna.Allocator,
	op: u8,
	mod: u8,
	dst: X64_Reg,
	#any_int imm: i64,
) {
	is_small_imm := imm >= -128 && imm <= 127

	emit(
		code,
		{
			rex(dst, .Rax, .Rax, true),
			op + 2 * u8(is_small_imm),
			mod_rm(.Direct, X64_Reg(mod), dst),
		},
	)

	if is_small_imm {
		emit(code, {u8(imm)})
	} else {
		emit_anys(code, u32(imm))
	}
}
