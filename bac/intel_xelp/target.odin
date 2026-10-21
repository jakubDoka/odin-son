package bac_intel_xelp

import bac ".."
import "../../utils/arna"
import "../../utils/fmt"

SPEC_NOT_PRESENT :: (#load("node_specs.odin", string) or_else "") == ""
when SPEC_NOT_PRESENT { Node_Type :: bac.Node_Type }

CC_TABLE := [?]bac.Call_Conv{{
	caller_saved = {{bac.Reg(1), bac.Reg(2), bac.Reg(4)}},
	args = {{bac.Reg(1), bac.Reg(2)}},
	rets = {{bac.Reg(4)}},
}}

peep :: proc(ctx: bac.Peep_Ctx, n: bac.Expanded_Node, _: $T) -> Maybe(bac.Node_ID) {
	if n.itype == .Div && n.dt == .F32 do return lower_div(ctx.prc, n.inps[0], n.inps[1])
	if n.itype == .Sub && n.dt == .I32 {
		return iop(ctx.prc, .Add, n.inps[0], ineg(ctx.prc, n.inps[1]))
	}
	return nil
}

post_schedule_peep :: proc(ctx: bac.PS_Peep_Ctx, n: bac.Expanded_Node, _: $T) -> bac.Node_ID {
	return bac.get_node_id(ctx.prc, n)
}

meta_of :: proc(prc: ^bac.Proc, ra: ^bac.Regalloc, n: bac.Expanded_Node, _: $T) -> bac.Regalloc_Node_Meta {
	if n.dt > .Mem && n.dt != .I32 && n.dt != .F32 do panic("unimplemented Xe-LP datatype")
	if n.itype == .Cast {
		source_dt := bac.get_node(prc, n.inps[0]).dt
		if source_dt != .I32 && source_dt != .F32 do panic("unimplemented Xe-LP cast")
	}
	if (n.itype == .And || n.itype == .Or || n.itype == .Xor || n.itype == .Shl || n.itype == .U_Shr) && n.dt != .I32 do panic("unimplemented Xe-LP integer operation")
	@(static, rodata) MASK := [?]i64{~i64(0xf), 0x0000_ffff_ffff_ffff}
	@(static, rodata) READ_MASK := [?]i64{~i64(9), 0x0000_ffff_ffff_ffff}
	@(static, rodata) INPUTS := [2]bac.RM_Intern_Idx{{index = 1}, {index = 1}}
	if n.gvn == 1 {
		ra.mask_len = 128
		bac.rm_intern_slice(ra, 0, MASK[:])
		bac.rm_intern_slice(ra, 0, READ_MASK[:])
	}
	invalid :: bac.INVALID_RM_INDEX
	#partial switch n.itype {
	case .Param: return {out = bac.param_mask(prc, ra, n)}
	case .Ret: return {out = bac.ret_mask(prc, ra, n)}
	case .Return: return bac.cc_node_meta(prc, ra, n, CC_TABLE[:])
	case .CInt: return {out = {}}
	case .Add, .Mul, .And, .Or, .Xor, .Shl, .U_Shr:
		return {out = {}, masks = INPUTS[:]}
	case .Cast: return {out = {}, masks = INPUTS[:1]}
	case .Split: return {out = {index = 1}, masks = INPUTS[:1]}
	case .Poison: return {out = {}}
	case .Mem, .Jump, .Always: return {out = invalid}
	case: fmt.panicf("unimplemented Xe-LP node: %v", n)
	}
	return {out = invalid}
}

put_instruction :: proc(code: ^arna.Allocator, instruction: Instruction, err: Error) {
	fmt.assertf(err == .None, "Xe-LP encoding failed: %v", err)
	bytes: [INSTRUCTION_BYTES]u8
	write_err := write_instruction(bytes[:], instruction)
	assert(write_err == .None)
	bac.emit(code, bytes[:])
}

emit_function :: proc(ctx: bac.Codegen_Emit_Ctx) -> bac.Codegen_Emit_Output {
	for r in ctx.allocs do assert(r.index < 112, "Xe-LP register spills are not implemented")
	assert(len(ctx.bbs) == 1, "Xe-LP control flow is not implemented")
	// Preserve denormals and round-to-nearest in the newly dispatched thread.
	put_instruction(ctx.code, {0x80000166, 0x80018220, 0x01008000, 0x04c004c0}, .None)
	for id in ctx.bbs[0].instrs {
		n := bac.expand_node(ctx.prc, id)
		dst := int(bac.reg_of(ctx, id).index) if n.dt > .Mem else 0
		a: ALU = {dst = dst, distance = 1, type = .U32}
		if n.dt == .F32 do a.type = .F32
		#partial switch n.itype {
		case .Param, .Ret, .Mem: continue
		case .Poison:
			a.op = .Mov
			a.src0 = imm(0)
		case .CInt:
			a.op = .Mov
			a.src0 = imm(u32(bac.get_extra(ctx.prc, n, bac.CInt).value))
		case .Split, .Cast:
			a.op = .Mov
			a.type = .U32
			a.src0 = reg(int(bac.reg_of(ctx, n.inps[0]).index))
		case .Add, .Mul, .And, .Or, .Xor, .Shl, .U_Shr:
			@(static, rodata) OPS := #partial [bac.Node_Type]Opcode{.Add = .Add, .Mul = .Mul, .And = .And, .Or = .Or, .Xor = .Xor, .Shl = .Shl, .U_Shr = .Shr}
			a.op = OPS[n.itype]
			a.src0 = reg(int(bac.reg_of(ctx, n.inps[0]).index))
			a.src1 = reg(int(bac.reg_of(ctx, n.inps[1]).index))
		case .Return:
			put(ctx.code, Sync({kind = .Distance, value = 1}))
			put(ctx.code, Send({sfid = .DC1, dst = NULL, src0 = 3, src1 = 4, descriptor = 0x02026e00, extended_descriptor = 0x40, sbid = 0}))
			put(ctx.code, Sync({kind = .Source, value = 0}))
			put(ctx.code, Send({sfid = .DC0, dst = 126, src0 = 0, src1 = NULL, descriptor = 0x0219e000, sbid = 1, write_enable = true}))
			put(ctx.code, Sync({kind = .Destination, value = 1, write_enable = true}))
			put(ctx.code, ALU({op = .Mov, type = .U32, dst = 127, src0 = reg(0), distance = 1, write_enable = true}))
			put_instruction(ctx.code, {0x80040061, 0x20014aa0, 0, 0}, .None)
			put(ctx.code, Sync({kind = .Distance, value = 1}))
			put(ctx.code, Send({sfid = .Thread_Spawner, dst = NULL, src0 = 127, src1 = NULL, descriptor = 0x02000010, sbid = 1, end_of_thread = true, write_enable = true}))
			continue
		case: fmt.panicf("unimplemented Xe-LP instruction: %v", n)
		}
		put(ctx.code, a)
	}
	return {}
}

put :: proc {put_alu, put_send, put_sync}
put_alu :: proc(code: ^arna.Allocator, a: ALU) {w, err := encode_alu(a); put_instruction(code, w, err)}
put_send :: proc(code: ^arna.Allocator, a: Send) {w, err := encode_send(a); put_instruction(code, w, err)}
put_sync :: proc(code: ^arna.Allocator, a: Sync) {w, err := encode_sync(a); put_instruction(code, w, err)}
