package wasm

import backend ".."
import "../../vendored/gam/util/arna"
import "core:fmt"

Reg :: backend.Reg
emit :: backend.emit
graph_expand :: backend.graph_expand
graph_get :: backend.graph_get

xtype :: #force_inline proc(node: backend.Expanded_Node) -> WASM_Node_Type {
	return WASM_Node_Type(node.rtype)
}

x64_extra :: #force_inline proc(
	graph: ^backend.Graph,
	node: ^backend.Node,
	$T: typeid,
) -> ^T {
	if graph.inheritance_table[node.rtype] & (1 << inherit_idx_of(T)) == 0 {
		return nil
	}
	return (^T)(&node.extra)
}

GEN_SPEC :: #config(WASM_GEN_SPEC, false)

COMMAND :: "odin run backend/wasm -define:WASM_GEN_SPEC=true"

SPEC_NOT_PRESENT :: (#load("node_specs.odin", string) or_else "") == ""

@(rodata)
WASM_SYSTEMV_CC := backend.Call_Conv {
	name = "WASM_SYSTEMV_CC",
}

when SPEC_NOT_PRESENT {
	Reg_Kind :: backend.Reg_Kind

	inherit_idx_of :: proc($T: typeid) -> u8 {return 0}

	WASM_Node_Type :: enum u16 {}

	@(rodata)
	WASM_CLASSES := [WASM_Node_Type]backend.Class_Spec{}

	when !GEN_SPEC {
		#panic("Missing generated files, run `" + COMMAND + "`")
	}
} else {
	@(rodata)
	WASM_CLASSES := [WASM_Node_Type]backend.Class_Spec{}
}

wasm_peep :: proc(
	ctx: backend.Peep_Ctx,
	node: backend.Expanded_Node,
	_: $T,
) -> backend.Node_ID {
	return 0
}

wasm_post_schedule_peep :: proc(
	ctx: backend.PS_Peep_Ctx,
	node: backend.Expanded_Node,
	_: $T,
) -> backend.Node_ID {
	return 0
}

wasm_meta_of :: proc(
	graph: ^backend.Graph,
	ra: ^backend.Regalloc,
	node: backend.Expanded_Node,
	_: $T,
) -> backend.Regalloc_Node_Meta {
	fmt.panicf("TODO %v", node)
}

Ctx :: struct {
	using inner: backend.Codegen_Emit_Ctx,
}

wasm_emit_function :: proc(
	ectx: backend.Codegen_Emit_Ctx,
) -> backend.Codegen_Output {
	context.allocator, _ = arna.scrath()

	fmt.panicf("TODO")
}

@(disabled = GEN_SPEC)
wasm_emit_instr :: proc(
	ctx: ^Ctx,
	instr: backend.Node_ID,
	is_consecutive: bool,
	_: $T,
) {
	fmt.panicf("TODO")
}
