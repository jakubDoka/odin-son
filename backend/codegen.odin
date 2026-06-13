package backend

import "../vendored/gam/util/arna"
import "core:reflect"

Codegen_Spec :: struct {
	emit_function: proc(_: Codegen_Emit_Ctx) -> Codegen_Output,
}

Codegen_Emit_Ctx :: struct {
	using graph:    ^Graph,
	using schedule: ^Graph_Schedule,
	using buf:      Codegen_Emit_Buf,
	allocs:         []Reg,
}

Codegen_Emit_Buf :: struct {
	code:    ^arna.Allocator,
	scratch: ^arna.Allocator,
}

Codegen_Output :: struct {
	code: []u8,
}

emit :: #force_no_inline proc(buf: ^arna.Allocator, bytes: []u8) {
	b := arna.smake(buf, []u8, len(bytes))
	copy(b, bytes)
}

emit_anys :: #force_no_inline proc(buf: ^arna.Allocator, values: ..any) {
	for value in values {
		b := reflect.as_bytes(value)
		bytes := arna.smake(buf, []u8, len(b))
		copy(bytes, b)
	}
}
