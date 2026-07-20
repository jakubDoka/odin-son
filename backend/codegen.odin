package backend

import "../vendored/gam/util/arna"
import "core:reflect"

Call_Conv :: struct {
	name:          string,
	callee_saved:  [Reg_Kind][]Reg,
	caller_saved:  [Reg_Kind][]Reg,
	args:          [Reg_Kind][]Reg,
	rets:          [Reg_Kind][]Reg,
	red_zone_size: i32,
	is_syscall:    bool,
}

Codegen_Spec :: struct {
	emit_function:      proc(_: Codegen_Emit_Ctx) -> Codegen_Output,
	peep:               Peep_Fn,
	post_schedule_peep: PS_Peep_Fn,
}

PS_Peep_Fn :: proc(_: PS_Peep_Ctx, node: Expanded_Node) -> Node_ID

PS_Peep_Ctx :: struct {
	using graph: ^Graph,
	preds:       []Node_ID,
}

Codegen_Emit_Ctx :: struct {
	using graph:      ^Graph,
	using schedule:   ^Graph_Schedule,
	using abi:        ^Call_Conv,
	using buf:        Codegen_Emit_Buf,
	emit_got_imports: bool,
	lib_calls:        Lib_Calls,
	allocs:           []Reg,
}

Lib_Calls :: struct {
	copy: Lib_Call,
	set:  Lib_Call,
}

Lib_Call :: bit_field u32 {
	id:       u32  | 31,
	absolute: bool | 1,
}

Codegen_Emit_Buf :: struct {
	code:   ^arna.Allocator,
	relocs: ^arna.Allocator,
}

Codegen_Output :: struct {
	relocs:    []Reloc,
	code:      []u8,
	constants: []u8,
}

Reloc_Kind :: enum u32 {
	Text,
	Got,
	Global,
}

Reloc_Size :: enum u32 {
	r4,
}

RELOC_SIZE := [Reloc_Size]u32 {
	.r4 = 4,
}

Reloc :: struct {
	offset:  u32,
	using _: bit_field u32 {
		kind: Reloc_Kind | 2,
		size: Reloc_Size | 2,
		id:   u32        | 28,
	},
}

RELOC_BIG_CONSTANT_BASE :: (~u32(0) >> 4) - (1 << 22)

Reloc_Slot :: struct #raw_union #align (1) {
	addend_4: u32,
}

emit :: #force_no_inline proc(buf: ^arna.Allocator, bytes: []u8) {
	b := arna.smake(buf, []u8, len(bytes), zeroed = false)
	copy(b, bytes)
}

emit_anys :: #force_no_inline proc(buf: ^arna.Allocator, values: ..any) {
	for value in values {
		b := reflect.as_bytes(value)
		bytes := arna.smake(buf, []u8, len(b), zeroed = false)
		copy(bytes, b)
	}
}

emit_aligned :: #force_no_inline proc(buf: ^arna.Allocator, vl: $T) -> ^T {
	slot := arna.alloc(buf, size_of(T), align_of(T))
	(^T)(raw_data(slot))^ = vl
	return (^T)(raw_data(slot))
}

add_reloc :: #force_no_inline proc(buf: ^arna.Allocator) -> ^Reloc {
	return (^Reloc)(raw_data(arna.alloc(buf, size_of(Reloc), align_of(Reloc))))
}
