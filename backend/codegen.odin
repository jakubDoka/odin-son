package backend

import "../vendored/gam/util/arna"
import "base:intrinsics"
import "core:encoding/varint"
import "core:reflect"
import "core:sort"

Call_Conv :: struct {
	name:          string,
	callee_saved:  [][]Reg,
	caller_saved:  [][]Reg,
	args:          [][]Reg,
	rets:          [][]Reg,
	red_zone_size: i32,
	is_syscall:    bool,
	cfi_spec:      Cfi_Spec,
}

Peep_Fn :: proc(_: Peep_Ctx, _: Expanded_Node) -> Node_ID

Codegen_Spec :: struct {
	emit_function:      proc(_: Codegen_Emit_Ctx) -> Codegen_Output,
	peep:               Peep_Fn,
	post_schedule_peep: PS_Peep_Fn,
	pre_regalloc_hook:  Pre_Regalloc_Hook,
}

// The fixed part of a DWARF CIE: everything the unwinder needs before the
// first Cfi_Op of a procedure is applied.
Cfi_Spec :: struct {
	cfa_reg:            u8,
	return_addr_reg:    u8,
	initial_cfa_offset: u32,
	code_align:         u32,
	data_align:         i32,
}

Cfi_Kind :: enum u8 {
	Def_Cfa_Offset,
	Save_Reg,
	Restore_Reg,
	Remember_State,
	Restore_State,
}

// A frame state change that becomes current at `offset` (procedure relative,
// i.e. right after the instruction that performed it).
Cfi_Op :: struct {
	offset: u32,
	arg:    u32,
	kind:   Cfi_Kind,
	reg:    u8,
}

PS_Peep_Fn :: proc(_: PS_Peep_Ctx, node: Expanded_Node) -> Node_ID

Pre_Regalloc_Hook :: proc(_: ^Regalloc, _: ^Graph, _: ^Graph_Schedule)

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
	param_specs:      []Param_Spec,
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
	slocs:  ^arna.Allocator,
	cfi:    ^arna.Allocator,
}

Codegen_Output :: struct {
	relocs:    []Reloc,
	slocs:     []Sloc,
	cfi:       []Cfi_Op,
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

param_mask :: proc(
	graph: ^Graph,
	ra: ^Regalloc,
	node: ^Node,
	spill_base: Maybe(u16) = nil,
	mask: Maybe(Reg) = nil,
) -> RM_Intern_Idx {
	kind := ra.datatype_to_reg_kind[node.dt]
	args := ra.args[kind]
	arg_ext := graph_extra(graph, node, Tup)
	idx := 0
	for a in ra.param_specs[:arg_ext.idx] {
		if a.dt == .Void do continue
		idx += int(ra.datatype_to_reg_kind[a.dt] == kind)
	}

	reg: Reg
	if int(idx) < len(args) {
		if raw_data(args) == nil {
			reg = {
				kind  = kind,
				index = u16(idx),
			}
		} else {
			reg = args[idx]
		}
	} else {
		reg = {
			kind  = kind,
			index = spill_base.? + u16(idx) - u16(len(args)),
		}
	}
	return rm_intern_single(ra, reg)
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

add_sloc :: #force_no_inline proc(buf: ^arna.Allocator) -> ^Sloc {
	return (^Sloc)(raw_data(arna.alloc(buf, size_of(Sloc), align_of(Sloc))))
}

add_cfi :: #force_no_inline proc(buf: ^arna.Allocator) -> ^Cfi_Op {
	return (^Cfi_Op)(
		raw_data(arna.alloc(buf, size_of(Cfi_Op), align_of(Cfi_Op))),
	)
}

emit_leb :: proc(buf: ^arna.Allocator, value: $T) {
	when intrinsics.type_is_unsigned(T) {
		encode :: varint.encode_uleb128
		up :: u128
	} else {
		encode :: varint.encode_ileb128
		up :: i128
	}

	LEB_MAX_BYTES :: 10
	bf := arna.alloc(buf, LEB_MAX_BYTES, 1)
	size := encode(bf, up(value)) or_else panic("")
	buf.pos -= len(bf) - uint(size)
}

layout_stack :: proc(
	ctx: ^Graph,
	schedule: ^Graph_Schedule,
	stack_size: ^i32,
) -> (
	has_call: bool,
) {
	for bb in schedule.bbs {
		bnode := graph_expand(ctx, bb.head)

		for ins in bb.instrs {
			has_call |= graph_get(ctx, ins).itype in CALLS
		}

		if bnode.itype != .Call_End do continue
		cnode := graph_expand(ctx, bnode.inps[0])
		call_stack_size: i32
		for inp in cnode.inps {
			inode := graph_expand(ctx, inp)
			if inode.itype != .Local do continue
			iext := graph_extra(ctx, inode, Local)
			call_stack_size += iext.size
			iext.offset = call_stack_size - iext.size
		}
		stack_size^ = max(stack_size^, call_stack_size)
	}

	emem := ctx.root_mem
	mem_outs := graph_outs(ctx, emem)

	Local_Slot :: bit_field u64 {
		node:     Node_ID | 32,
		priority: i32     | 32,
	}
	locals: [dynamic]Local_Slot

	for mout in mem_outs {
		mnode := graph_expand(ctx, mout.id)
		if mnode.itype == .Local {
			extra := graph_extra(ctx, mnode, Local)
			append(
				&locals,
				Local_Slot {
					node = mout.id,
					priority = intrinsics.count_trailing_zeros(extra.size),
				},
			)
		}
	}

	sort.quick_sort(locals[:])

	for loc in locals {
		extra := graph_extra(ctx, loc.node, Local)
		stack_size^ += extra.size
		extra.offset = stack_size^ - extra.size
	}

	return
}

uleb :: proc(b: ^[dynamic]u8, value: u64) {
	v := value
	for {
		byte := u8(v & 0x7f)
		v >>= 7
		if v != 0 do byte |= 0x80
		append(b, byte)
		if v == 0 do break
	}
}

sleb :: proc(b: ^[dynamic]u8, value: i64) {
	v := value
	for {
		byte := u8(v & 0x7f)
		v >>= 7
		sign := (byte & 0x40) != 0
		done := (v == 0 && !sign) || (v == -1 && sign)
		if !done do byte |= 0x80
		append(b, byte)
		if done do break
	}
}

putb :: #force_inline proc(b: ^[dynamic]u8, vl: $T) {
	append(b, transmute(u8)vl)
}
