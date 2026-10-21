package typecheck

import xelp "../bac/intel_xelp"
import "core:math"

emit_gpu_xelp_body :: proc(ctx: ^Gen_Ctx) -> ([]u8, bool) {
	program: []u32
	count := 0
	for prc in ctx.procs {
		if !prc.gpu_tag do continue
		program = prc.gpu_program
		count += 1
	}
	if count != 1 || len(program) == 0 || len(program) > 64 || len(program) % 4 != 0 do return nil, false
	for i := 0; i < len(program); i += 4 {
		if program[i] != 1 || program[i+1] > 3 || program[i+2] > 3 do return nil, false
		value := transmute(f32)program[i+3]
		if math.is_nan(value) || math.is_inf(value) do return nil, false
	}
	code := make([]u8, len(program)/4 * 2 * xelp.INSTRUCTION_BYTES, ctx.types.allocator)
	for i := 0; i < len(program); i += 4 {
		dst, src := 16 + int(program[i+1]), 16 + int(program[i+2])
		mul, mul_err := xelp.encode_alu({op = .Mul, dst = 20, src0 = xelp.reg(src), src1 = xelp.imm(program[i+3]), distance = 1})
		add, add_err := xelp.encode_alu({op = .Add, dst = dst, src0 = xelp.reg(dst), src1 = xelp.reg(20), distance = 1})
		if mul_err != .None || add_err != .None { delete(code, ctx.types.allocator); return nil, false }
		at := i/4 * 2 * xelp.INSTRUCTION_BYTES
		if xelp.write_instruction(code[at:], mul) != .None || xelp.write_instruction(code[at+xelp.INSTRUCTION_BYTES:], add) != .None {
			delete(code, ctx.types.allocator)
			return nil, false
		}
	}
	return code, true
}
