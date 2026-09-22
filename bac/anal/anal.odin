package anal

import bac ".."
import "../../vendored/gam/util/arna"
import "core:fmt"
Node_ID :: bac.Node_ID

SPEC_NOT_PRESENT :: (#load("node_specs.odin", string) or_else "") == ""

peep :: proc(
	ctx: bac.Peep_Ctx,
	node: bac.Expanded_Node,
	_: $T,
) -> Node_ID {return 0}

post_schedule_peep :: proc(
	ctx: bac.PS_Peep_Ctx,
	node: bac.Expanded_Node,
	_: $T,
) -> Node_ID {
	return 0
}

when SPEC_NOT_PRESENT {
	Reg_Kind :: bac.Reg_Kind

	inherit_idx_of :: proc($T: typeid) -> u8 {return 0}

	Node_Type :: enum u16 {}
}

emit_function :: proc(ectx: bac.Codegen_Emit_Ctx) -> bac.Codegen_Output {
	msg_start := ectx.buf.code.pos
	err_cnt := 0
	wrt := arna.to_stream(ectx.buf.code)

	check_local_bounds: {
		fmt.wprintln(wrt, "wootah")
	}

	return {code = ectx.code.ptr[msg_start:ectx.code.pos]}
}
