package bac

import "../vendored/gam/util/arna"
import "base:intrinsics"
import "core:encoding/varint"
import "core:fmt"
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

Pre_Regalloc_Hook :: proc(_: ^Regalloc, _: ^Proc, _: ^Schedule)

PS_Peep_Ctx :: struct {
	using graph: ^Proc,
	preds:       []Node_ID,
}

Codegen_Emit_Ctx :: struct {
	using graph:      ^Proc,
	using schedule:   ^Schedule,
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
	r32,
	r26,
	r2_19,
}

RELOC_SIZE := [Reloc_Size]u32 {
	.r32   = 4,
	.r26   = 4,
	.r2_19 = 4,
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
	addend_32: i32,
	r2:        bit_field u32 {
		addend_26: i32 | 26,
		padd:      u32 | 6,
	},
	r3:        bit_field u32 {
		padd2:     u32 | 5,
		addend_19: i32 | 19,
		padd3:     u32 | 8,
	},
	r4:        bit_field u32 {
		padd4:        u32 | 5,
		addend_hi_19: i32 | 19,
		padd5:        u32 | 5,
		addend_lo_2:  i32 | 2,
		padd6:        u32 | 1,
	},
}

cc_node_meta :: proc(
	graph: ^Proc,
	ra: ^Regalloc,
	node: Expanded_Node,
) -> Regalloc_Node_Meta {
	cc := ra.cc
	// NOTE: this handles the edge case where there is no memory returned,
	// this happens when we only have infinite loops that terminate the
	// function
	prefix := min(2, len(node.inps))
	call: ^Call = get_extra(graph, node, Call)
	if call != nil {
		prefix = CALL_PREFIX
		cc = &graph.cc_table[call.ccid]
	}

	real_len := len(node.inps)
	for ; get_node(graph, node.inps[real_len - 1]).itype == .Local;
	    real_len -= 1 {}

	inited := prefix

	nmasks := make([]RM_Intern_Idx, real_len - inited)

	banks := cc.args
	if node.itype == .Return do banks = ra.rets

	counts := make([]int, len(ra.spill_boundary))
	for n, i in node.inps[inited:real_len] {
		rk := graph.datatype_to_reg_kind[get_node(graph, n).dt]
		nmasks[i] = rm_intern_single(ra, banks[rk][counts[rk]])
		counts[rk] += 1
	}

	if call != nil && call.indirect {
		nmasks[len(nmasks) - 1] = {}
	}

	return {out = INVALID_RM_INDEX, input_start = u8(prefix), masks = nmasks}
}

param_mask :: proc(
	graph: ^Proc,
	ra: ^Regalloc,
	node: ^Node,
	mask: Maybe(Reg) = nil,
) -> RM_Intern_Idx {
	kind := ra.datatype_to_reg_kind[node.dt]
	args := ra.args[kind]
	arg_ext := get_extra(graph, node, Tup)
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
			index = u16(ra.spill_boundary[kind]) + u16(idx) - u16(len(args)),
		}
	}
	return rm_intern_single(ra, reg)
}

ret_mask :: proc(
	graph: ^Proc,
	ra: ^Regalloc,
	node: Expanded_Node,
) -> RM_Intern_Idx {
	// TODO: this is actually incorrect, we need to iterate the previous
	// rets to figure this out safely
	cend := expand_node(graph, node.inps[0])
	call := get_extra(graph, cend.inps[0], Call)
	ret_ext := get_extra(graph, node, Tup)
	kind := ra.datatype_to_reg_kind[node.dt]

	idx := 0
	for a in call.rets[:ret_ext.idx] {
		idx += int(ra.datatype_to_reg_kind[a] == kind)
	}

	return rm_intern_single(ra, ra.rets[kind][idx])
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

spill_slot_offset :: proc(
	ctx: Codegen_Emit_Ctx,
	stack_param_offset: [][dynamic]i32,
	spill_slot_base: []i32,
	spill_slot_size: []i32,
	reg: Reg,
) -> i32 {
	rcount := u16(ctx.spill_boundary[reg.kind])
	if reg.index < rcount do return 0

	param_count := len(stack_param_offset[reg.kind])
	if int(reg.index - rcount) < param_count {
		return stack_param_offset[reg.kind][reg.index - rcount]
	}
	return(
		spill_slot_base[reg.kind] +
		(i32(reg.index) - i32(param_count) - i32(rcount)) *
			spill_slot_size[reg.kind] \
	)
}

layout_spill_slots :: proc(
	ctx: Codegen_Emit_Ctx,
	spill_slot_base: []i32,
	spill_slot_size: []i32,
	stack_size: ^i32,
) {
	spill_slot_count: [8]i32
	for reg in ctx.allocs {
		spill_slot_count[reg.kind] = max(
			spill_slot_count[reg.kind],
			i32(reg.index) - i32(ctx.spill_boundary[reg.kind]) + 1,
		)
	}

	for size, kind in spill_slot_count[:len(spill_slot_base)] {
		spill_slot_base[kind] = i32(stack_size^)
		stack_size^ += size * spill_slot_size[kind]
	}
}

compute_param_offsets :: proc(
	ctx: Codegen_Emit_Ctx,
	params: []Node_ID,
	stack_size: ^i32,
	stack_param_offset: [][dynamic]i32,
	param_offset: i32 = 0,
) {
	param_offset := param_offset
	for param, i in ctx.param_specs {
		param_id := params[i]

		extra := get_extra(ctx.graph, param_id, Local)
		if extra != nil {
			fmt.assertf(
				extra.size == param.size,
				"%v == %v",
				extra.size,
				param.size,
			)
			extra.offset = param_offset
		}

		if param.size > 0 && param.dt != .Void {
			assert(param.size == 8, "TODO")
			stack_size^ -= param.size
			kind := ctx.datatype_to_reg_kind[param.dt]
			append(&stack_param_offset[kind], i32(param_offset))
		}

		param_offset += param.size
	}
}

layout_call_args :: proc(
	ctx: ^Proc,
	schedule: ^Schedule,
	stack_size: ^i32,
) -> (
	has_call: bool,
) {
	for bb in schedule.bbs {
		bnode := expand_node(ctx, bb.head)

		for ins in bb.instrs {
			has_call |= get_node(ctx, ins).itype in CALLS
		}

		if bnode.itype != .Call_End do continue
		cnode := expand_node(ctx, bnode.inps[0])
		call_stack_size: i32
		for inp in cnode.inps {
			inode := expand_node(ctx, inp)
			if inode.itype != .Local do continue
			iext := get_extra(ctx, inode, Local)
			call_stack_size += iext.size
			iext.offset = call_stack_size - iext.size
		}
		stack_size^ = max(stack_size^, call_stack_size)
	}

	return
}

layout_locals :: proc(ctx: ^Proc, schedule: ^Schedule, stack_size: ^i32) {
	emem := ctx.root_mem
	mem_outs := get_outputs(ctx, emem)

	Local_Slot :: bit_field u64 {
		node:     Node_ID | 32,
		priority: i32     | 32,
	}
	locals: [dynamic]Local_Slot

	for mout in mem_outs {
		mnode := expand_node(ctx, mout.id)
		if mnode.itype == .Local {
			extra := get_extra(ctx, mnode, Local)
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
		extra := get_extra(ctx, loc.node, Local)
		stack_size^ += extra.size
		extra.offset = stack_size^ - extra.size
	}
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
