package anal

import backend ".."
import "../../vendored/gam/util/arna"
import "core:fmt"

GEN_SPEC :: #config(ANAL_GEN_SPEC, false)

COMMAND :: "odin run backend/anal -define:ANAL_GEN_SPEC=true"

SPEC_NOT_PRESENT :: (#load("node_specs.odin", string) or_else "") == ""

@(rodata)
ANAL_IDEAL_REG_CLASSES := [backend.Ideal_Node_Type]backend.Reg_Class_Spec{}

anal_peep :: proc(
	ctx: backend.Peep_Ctx,
	node: backend.Expanded_Node,
	_: $T,
) -> backend.Node_ID {return 0}

anal_post_schedule_peep :: proc(
	ctx: backend.PS_Peep_Ctx,
	node: backend.Expanded_Node,
	_: $T,
) -> backend.Node_ID {
	return 0
}

when SPEC_NOT_PRESENT {
	Reg_Kind :: backend.Reg_Kind

	inherit_idx_of :: proc($T: typeid) -> u8 {return 0}

	Anal_Node_Type :: enum u16 {}

	when !GEN_SPEC {
		#panic("Missing generated files, run `" + COMMAND + "`")
	}
}

anal_emit_function :: proc(
	ectx: backend.Codegen_Emit_Ctx,
) -> backend.Codegen_Output {
	msg_start := ectx.buf.code.pos
	err_cnt := 0
	wrt := arna.to_stream(ectx.buf.code)

	check_local_bounds: {
		fmt.wprintln(wrt, "wootah")
	}

	return {code = ectx.code.ptr[msg_start:ectx.code.pos]}
}
