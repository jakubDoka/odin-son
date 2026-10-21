package bac_wasm

import bac ".."
import "../../utils/arna"
import "../../utils/fmt"
import "base:runtime"
import "core:encoding/varint"
import "core:slice"
import "core:sort"

Reg :: bac.Reg
emit :: bac.emit
emit_leb :: bac.emit_leb
expand_node :: bac.expand_node
get_node :: bac.get_node

MASK_SIZE :: 64

RK_I64 :: Reg_Kind(0)
RK_I32 :: Reg_Kind(1)
RK_F64 :: Reg_Kind(2)
RK_F32 :: Reg_Kind(3)
RK_V128 :: Reg_Kind(4)
RK_COUNT :: 5

wtype :: #force_inline proc(node: bac.Expanded_Node) -> Node_Type {
	return Node_Type(node.rtype)
}

wextra :: #force_inline proc(
	prc: ^bac.Proc,
	node: ^bac.Node,
	$T: typeid,
) -> ^T {
	if prc.inheritance_table[node.rtype] & (1 << inherit_idx_of(T)) == 0 {
		return nil
	}
	return (^T)(&node.extra)
}

SPEC_NOT_PRESENT :: (#load("node_specs.odin", string) or_else "") == ""

WASM_SYSTEMV_CC :: 0

@(tag = "api", rodata, export, link_name = "bac_wasm_CC_TABLE")
CC_TABLE := [?]bac.Call_Conv {
	WASM_SYSTEMV_CC = {},
}

Lane_Op :: struct {
	laneidx: u32,
}

Mem_Op :: struct #align (4) {
	using meta: bit_field u64 {
		offset: i64               | 59,
		source: bac.Node_Datatype | 4,
		signed: bool              | 1,
	},
}

when SPEC_NOT_PRESENT {
	Reg_Kind :: bac.Reg_Kind

	inherit_idx_of :: proc($T: typeid) -> u8 {return 0}

	collect_meta :: proc(
		_: ^bac.Proc,
		_: ^bac.Regalloc,
		_: ^bac.Schedule,
	) -> (
		[]bac.Regalloc_Node_Meta,
		int,
	) {
		return {}, 0
	}

	add_extract_lane_u :: proc(
		prc: ^bac.Proc,
		name: string,
		dt: bac.Node_Datatype,
		vec: bac.Node_ID,
		laneidx: u32,
	) -> bac.Node_ID {
		return 0
	}

	add_select :: proc(
		prc: ^bac.Proc,
		name: string,
		dt: bac.Node_Datatype,
		on_true, on_false, condition: bac.Node_ID,
	) -> bac.Node_ID {
		return 0
	}

	Node_Type :: enum u16 {
		WASM_Store,
		WASM_Load,
		Get_Local,
		Set_Local,
		Tee_Local,
		Drop,
		Stub,
		Extract_Lane_U,
		WASM_Shl,
		WASM_Shr,
		WASM_U_Shr,
		Select,
	}
}

peep :: proc(
	ctx: bac.Peep_Ctx,
	node: bac.Expanded_Node,
	_: $T,
) -> Maybe(bac.Node_ID) {
	inp: bac.Expanded_Node
	if 0 < len(node.inps) {
		inp = expand_node(ctx, node.inps[0])
	}
	kind := wtype(node)
	#partial switch kind {
	case .Add ..= .And_Not, .Neg, .Not:
		NARROW_DTS :: bit_set[bac.Node_Datatype]{.I8, .I16}
		if node.dt in bac.VECTOR_DTS ||
		   bac.operation_datatype(ctx, node) not_in NARROW_DTS {
			break
		}

		signed :=
			kind in bit_set[Node_Type]{.Le, .Lt, .Gt, .Ge, .Div, .Rem, .Shr}
		ext: bac.Un_Op = signed ? .Conv : .U_Conv
		inps: [2]bac.Node_ID
		for inp, i in node.inps {
			inps[i] = inp
			inp_dt := get_node(ctx, inp).dt
			if inp_dt in NARROW_DTS {
				inp_ext := ext
				if .Shl <= kind && kind <= .U_Shr && i == 1 do inp_ext = .U_Conv
				inps[i] = bac.add_un_op(ctx, "iext", inp_ext, .I32, inp)
				bac.worklist_add(ctx, ctx.worklist, inps[i])
			}
		}

		comparison := .Eq <= kind && kind <= .U_Ge
		dt := comparison ? node.dt : bac.Node_Datatype.I32
		wide := bac.add_raw(
			ctx,
			"iwide",
			node.rtype,
			dt,
			inps[:len(node.inps)],
		)
		bac.worklist_add(ctx, ctx.worklist, wide)
		if comparison do return wide

		// Consumers must still observe overflow at the original width, including stores.
		return bac.add_un_op(ctx, "inar", .U_Conv, node.dt, wide)
	}

	#partial switch kind {
	case .Shl ..= .U_Shr:
		if node.dt not_in bac.INT_DTS do break

		count := node.inps[1]
		count_dt := get_node(ctx, count).dt
		constant := bac.get_extra(ctx, count, bac.CInt)
		bits := i64(bac.DT_SIZE[node.dt] * 8)
		if constant != nil && constant.value == 0 do return node.inps[0]
		if count_dt < .I32 {
			count_dt = .I32
			count = bac.add_un_op(ctx, "shcext", .U_Conv, count_dt, count)
			bac.worklist_add(ctx, ctx.worklist, count)
		}

		in_range: bac.Node_ID
		if constant != nil {
			if u64(constant.value) >= u64(bits) {
				if kind != .Shr do return bac.add_c_int(ctx, "shzero", node.dt, 0)
				count = bac.add_c_int(ctx, "shlimit", count_dt, bits - 1)
			}
		} else {
			in_range = bac.add_bin_op(
				ctx,
				"shrange",
				.U_Lt,
				.I8,
				count,
				bac.add_c_int(ctx, "shwidth", count_dt, bits),
			)
			if kind == .Shr {
				count = add_select(
					ctx,
					"shclamp",
					count_dt,
					count,
					bac.add_c_int(ctx, "shlimit", count_dt, bits - 1),
					in_range,
				)
			}
		}

		// Check the full count before wrapping it to the native shift's width.
		if count_dt != node.dt {
			count = bac.add_un_op(ctx, "shcount", .U_Conv, node.dt, count)
			bac.worklist_add(ctx, ctx.worklist, count)
		}
		@(static, rodata)
		NATIVE_SHIFTS := [3]Node_Type{.WASM_Shl, .WASM_Shr, .WASM_U_Shr}
		shift := bac.add_raw(
			ctx,
			"shnative",
			u16(NATIVE_SHIFTS[int(kind) - int(Node_Type.Shl)]),
			node.dt,
			{node.inps[0], count},
		)
		if constant != nil || kind == .Shr do return shift
		return add_select(
			ctx,
			"shguard",
			node.dt,
			shift,
			bac.add_c_int(ctx, "shzero", node.dt, 0),
			in_range,
		)
	case .Conv, .U_Conv:
		if inp.dt not_in bac.INT_DTS ||
		   node.dt not_in bac.INT_DTS ||
		   inp.dt >= node.dt {
			break
		}

		signed := kind == .Conv

		if wtype(inp) == .WASM_Load && len(inp.outs) == 1 {
			ext := wextra(ctx, inp, Mem_Op)
			if inp.dt == ext.source || (ext.signed == signed) {
				ext.signed = signed
				inp.dt = node.dt
				return node.inps[0]
			}
		}

		if wtype(inp) == .Load && len(inp.outs) == 1 {
			(^Mem_Op)(
				bac.get_next_extra_slot(ctx, u16(Node_Type.WASM_Load), 0),
			)^ = {
				source = inp.dt,
				signed = signed,
			}
			return bac.add_raw(
				ctx,
				"sxld",
				u16(Node_Type.WASM_Load),
				node.dt,
				inp.inps,
			)
		}
	case .Load, .Store:
		op := Node_Type.WASM_Load
		if node.itype == .Store do op = Node_Type.WASM_Store

		base, off := bac.base_and_offset(ctx, node.inps[2])

		changed := false

		bnode := expand_node(ctx, base)
		if bnode.itype == .Local_Addr && kind != .Store {
			base = bnode.inps[0]
			changed = true
		}

		if off != 0 || changed {
			(^Mem_Op)(bac.get_next_extra_slot(ctx, u16(op), 0))^ = {
				source = node.dt,
				offset = i64(off),
			}
			inps := slice.clone(node.inps)
			inps[2] = base
			return bac.add_raw(ctx, "offm", u16(op), node.dt, inps)
		}
	case .And_Not:
		return bac.add_bin_op(
			ctx,
			"ana",
			.And,
			node.dt,
			node.inps[0],
			bac.add_bin_op(
				ctx,
				"ann",
				.Xor,
				node.dt,
				node.inps[1],
				bac.add_c_int(ctx, "acn", node.dt, -1),
			),
		)
	case .Neg:
		if node.dt <= .I64 {
			return bac.add_bin_op(
				ctx,
				"sneg",
				.Sub,
				node.dt,
				bac.add_c_int(ctx, "zr", node.dt, 0),
				node.inps[0],
			)
		}
	case .Not:
		return bac.add_bin_op(
			ctx,
			"sneg",
			.Xor,
			node.dt,
			bac.add_c_int(ctx, "m1", node.dt, -1),
			node.inps[0],
		)
	case .Simd_Reduce_Add_Bisect:
		// TODO: maybe dont divide here
		lane_count := bac.DT_SIZE[inp.dt] / bac.LANE_SIZE[node.lane]

		sum := add_extract_lane_u(
			ctx,
			"rabe",
			node.dt,
			node.inps[0],
			0,
			lane = node.lane,
		)
		for lane in 1 ..< lane_count {
			next := add_extract_lane_u(
				ctx,
				"rabe",
				node.dt,
				node.inps[0],
				u32(lane),
				lane = node.lane,
			)

			sum = bac.add_bin_op(ctx, "rabs", .Add, node.dt, sum, next)
			bac.worklist_add(ctx, ctx.worklist, sum)
		}

		return sum
	}

	return nil
}

post_schedule_peep :: proc(
	ctx: bac.PS_Peep_Ctx,
	node: bac.Expanded_Node,
	_: $T,
) -> bac.Node_ID {
	return 0
}

meta_of :: #force_inline proc(
	prc: ^bac.Proc,
	ra: ^bac.Regalloc,
	node: bac.Expanded_Node,
	_: $T,
) -> bac.Regalloc_Node_Meta {
	out := bac.INVALID_RM_INDEX

	single :: bac.rm_intern_single
	rslice :: bac.rm_intern_slice

	@(rodata, static)
	FULL_MASK := [?]i64{-1}

	mask_of :: #force_inline proc(kind: Reg_Kind) -> bac.RM_Intern_Idx {
		return {kind = kind}
	}

	@(rodata, static)
	SLOT_TABLE := [RK_COUNT][8]bac.RM_Intern_Idx {
		{0 ..< 8 = {kind = RK_I64}},
		{0 ..< 8 = {kind = RK_I32}},
		{0 ..< 8 = {kind = RK_F64}},
		{0 ..< 8 = {kind = RK_F32}},
		{0 ..< 8 = {kind = RK_V128}},
	}

	rk := ra.datatype_to_reg_kind[node.dt]
	mask := mask_of(rk)
	masks := SLOT_TABLE[rk][:]

	imasks := masks
	if 0 < len(node.inps) {
		irk := ra.datatype_to_reg_kind[get_node(prc, node.inps[0]).dt]
		imasks = SLOT_TABLE[irk][:]
	}

	if node.gvn == 1 {
		if ra.cc == nil {
			ra.cc = &CC_TABLE[WASM_SYSTEMV_CC]
		}

		ra.mask_len = MASK_SIZE
		for kind in 0 ..< RK_COUNT {
			rslice(ra, kind, FULL_MASK[:])
		}
	}

	dup :: #force_inline proc(
		msks: []bac.RM_Intern_Idx,
	) -> []bac.RM_Intern_Idx {
		return slice.clone(msks)
	}

	switch wtype(node) {
	case:
		fallthrough
	case .Nil ..= .Dbg_Scope, .Simd_Reduce_Add_Bisect:
		fmt.panicf("should not reach these: %v", node)
	case .Poison ..=
	     .Global,
	     .Return,
	     .CInt,
	     .Add ..=
	     .U_Rem,
	     .If,
	     .Jump,
	     .Local_Addr,
	     .Call,
	     .Store,
	     .Load,
	     .Ret,
	     .Drop,
	     .Set,
	     .Copy,
	     .And_Not,
	     .Conv,
	     .U_Conv,
	     .Stub,
	     .Not,
	     .Neg,
	     .Cast,
	     .Global_Addr,
	     .Proc_Addr,
	     .Always,
	     .Trap,
	     .Extract_Lane_U,
	     .Splat,
	     .Simd_Extract_Lsbs,
	     .Ctz,
	     .WASM_Shl ..=
	     .WASM_U_Shr,
	     .Select,
	     .WASM_Load,
	     .WASM_Store:
		return {out = out}
	case .Phi:
		if node.dt <= .Mem do return {out = out}
		pmasks := make([]bac.RM_Intern_Idx, len(node.inps) - 1)
		slice.fill(pmasks, mask)
		return {out = mask, input_start = 1, masks = pmasks}
	case .Param:
		return {out = bac.param_mask(prc, ra, node)}
	case .Tee_Local:
		return {out = mask}
	case .Set_Local:
		return {out = mask}
	case .Get_Local:
		return {out = out, masks = imasks[:1]}
	case .Split:
		return {out = mask, masks = masks[:1]}
	}
}

pre_regalloc_hook :: proc(
	ra: ^bac.Regalloc,
	prc: ^bac.Proc,
	sched: ^bac.Schedule,
) {
	// NOTE: try to find a efficient ordering of instructions to use the wasm
	// stack as much as possible, its greedy

	Ctx :: struct {
		using prc: ^bac.Proc,
		metas:     []Meta,
		instrs:    ^[dynamic]bac.Node_ID,
		sets:      []bac.Node_ID,
		rcs:       []int,
		cursor:    int,
	}

	ctx: Ctx
	ctx.prc = prc

	prc.dont_delete, prc.dont_intern = true, true
	defer prc.dont_delete, prc.dont_intern = false, false

	for bb, i in sched.bbs {
		get_node(ctx, bb.head).gvn = u32(i)
	}

	splits: [dynamic]bac.Node_ID

	// NOTE: we do splits here becuase dealing with phy self conflicts is just
	// annoying, maybe we can do better, but not right now
	for &bb in sched.bbs {
		hnode := expand_node(ctx, bb.head)

		for i := 0; i < len(bb.instrs); i += 1 {
			instr := bb.instrs[i]
			inode := expand_node(ctx, instr)
			for inp, j in inode.inps {
				innode := expand_node(ctx, inp)

				is_clonable := false
				cint := bac.get_extra(ctx, innode, bac.CInt)
				if cint != nil && innode.dt <= .I64 {
					bufa: [1]u8
					_, error := varint.encode_ileb128(
						bufa[:],
						i128(cint.value),
					)
					is_clonable = error == nil
				}

				if is_clonable && len(innode.outs) > 1 {
					clone := bac.clone(ctx, inp)
					bac.set_input(ctx, instr, j, clone)

					if inode.itype == .Phi {
						block_head := bac.get_inputs(ctx, hnode.inps[j - 1])[0]
						block := &sched.bbs[bac.get_node(ctx, block_head).gvn]
						inject_at(&block.instrs, len(block.instrs) - 1, clone)
					} else {
						inject_at(&bb.instrs, i, clone)
						i += 1
					}
				}
			}
		}

		if hnode.itype == .Call_End {
			ret_count := 0
			for instr in bb.instrs {
				inode := expand_node(ctx, instr)
				if inode.itype != .Ret do break
				ret_count += 1
			}

			context.user_ptr = &ctx
			sort.bubble_sort_proc(
				bb.instrs[:ret_count],
				proc(a, b: bac.Node_ID) -> int {
					ctx := (^Ctx)(context.user_ptr)
					return (sort.compare_u32s(
								bac.get_extra(ctx, b, bac.Tup).idx,
								bac.get_extra(ctx, a, bac.Tup).idx,
							))
				},
			)

			add_drop :: proc(ctx: Ctx) -> bac.Node_ID {
				return bac.add_raw(ctx, "rdrp", u16(Node_Type.Drop), .Void, {})
			}

			real_ret_count :=
				bac.get_extra(ctx, hnode.inps[0], bac.Call).ret_count

			// NOTE: we need to insert drops ofr the rets that are dead
			laxt_idx := real_ret_count
			for i := 0; i < real_ret_count; i += 1 {
				// NOTE: we rely on the fact there is at least one non ret node
				ret := bb.instrs[i]
				idx := -1
				if get_node(ctx, ret).itype == .Ret {
					idx = int(bac.get_extra(ctx, ret, bac.Tup).idx)
				}
				for _ in idx ..< laxt_idx - 1 {
					inject_at(&bb.instrs, i, add_drop(ctx))
					i += 1
				}
				laxt_idx = idx
			}
		}
	}

	bac.verify_schedule_integrity(ctx, sched)

	Meta :: struct {
		def:         bool,
		is_mem:      bool,
		input_start: u8,
		input_count: u8,
	}

	meta_of :: proc(ctx: ^Ctx, node: bac.Expanded_Node, _: $T) -> Meta {
		// TODO: this is uselss to be strongly typed, we anyway just use the
		// length, and wether the out is invalid
		switch wtype(node) {
		case:
			fallthrough
		case .Nil ..=
		     .Dbg_Scope,
		     .Simd_Reduce_Add_Bisect,
		     .Get_Local,
		     .Set_Local,
		     .Tee_Local,
		     .Stub:
			fmt.panicf("should not reach these: %v", node)
		case .Poison ..= .Global, .Jump, .Drop, .Always, .Trap:
			return {}
		case .Load, .WASM_Load:
			is_local := get_node(ctx, node.inps[2]).itype == .Local
			return {
				def = true,
				is_mem = true,
				input_start = 2 + u8(is_local),
				input_count = 1 - u8(is_local),
			}
		case .Store, .WASM_Store:
			is_local := get_node(ctx, node.inps[2]).itype == .Local
			return {
				def = true,
				is_mem = true,
				input_start = 2 + u8(is_local),
				input_count = 2 - u8(is_local),
			}
		case .Split:
			return {def = true, input_count = 1}
		case .If:
			return {input_start = 1, input_count = 1}
		case .Call, .Return:
			prefix: u8 = bac.CALL_PREFIX
			if node.itype == .Return do prefix = bac.RET_PREFIX

			prefix = min(prefix, u8(len(node.inps)))

			real_len := len(node.inps)
			for ; get_node(ctx, node.inps[real_len - 1]).itype == .Local;
			    real_len -= 1 {}

			return {input_start = prefix, input_count = u8(real_len) - prefix}
		case .Set, .Copy:
			return {is_mem = true, input_start = 2, input_count = 3}
		case .Phi:
			if node.dt <= .Mem do return {}
			return {
				def = true,
				input_start = 1,
				input_count = u8(len(node.inps) - 1),
			}
		case .Add ..= .And_Not, .WASM_Shl ..= .WASM_U_Shr:
			return {def = true, input_count = 2}
		case .Select:
			return {def = true, input_count = 3}
		case .Conv,
		     .U_Conv,
		     .Not,
		     .Neg,
		     .Cast,
		     .Extract_Lane_U,
		     .Splat,
		     .Simd_Extract_Lsbs,
		     .Ctz:
			return {def = true, input_count = 1}
		case .CInt, .Local_Addr, .Ret, .Param, .Global_Addr, .Proc_Addr:
			return {def = true}
		}
	}

	collect_meta :: #force_inline proc(
		ctx: ^Ctx,
		sched: ^bac.Schedule,
	) -> (
		slots: []Meta,
		def_count: int,
	) {
		prc := ctx.prc

		slots = make([]Meta, int(prc.gvn) - len(sched.bbs))
		rev_count := int(prc.gvn) - len(sched.bbs)

		idx := 0
		for bb, j in sched.bbs {
			get_node(prc, bb.head).gvn = u32(len(slots) + 1 + j)
			for instr in bb.instrs {
				inode := expand_node(prc, instr)

				inode.gvn = u32(idx)
				idx += 1

				when SPEC_NOT_PRESENT {
					meta: Meta
				} else {
					meta := meta_of(ctx, inode, struct{}{})
				}
				meta.input_count += meta.input_start

				if !meta.def {
					rev_count -= 1
					inode.gvn = u32(rev_count)
				} else {
					inode.gvn = u32(def_count)
					def_count += 1
				}

				slots[inode.gvn] = meta
			}
		}

		return
	}

	data_deps :: proc(meta: Meta, node: bac.Expanded_Node) -> []bac.Node_ID {
		return node.inps[meta.input_start:meta.input_count]
	}

	defs: int
	ctx.metas, defs = collect_meta(&ctx, sched)
	ctx.sets = make([]bac.Node_ID, defs)
	ctx.rcs = make([]int, defs)

	old_gvn := ctx.gvn

	for &bb in sched.bbs {
		ctx.cursor = len(bb.instrs)
		ctx.instrs = &bb.instrs

		for instr, i in bb.instrs {
			inode := expand_node(ctx, instr)
			for dep in data_deps(ctx.metas[inode.gvn], inode) {
				if get_node(ctx, dep).itype == .Poison do continue
				ctx.rcs[get_node(ctx, dep).gvn] += int(
					slice.contains(bb.instrs[:i], dep),
				)
			}
		}

		for ctx.cursor > 0 {
			stackify(&ctx)
		}

		NO_SET_KINDS :: bit_set[bac.Node_Type]{.Param, .Phi}

		stackify :: proc(ctx: ^Ctx) {
			ctx.cursor -= 1
			instr := ctx.instrs[ctx.cursor]
			inode := expand_node(ctx, instr)

			if inode.itype == .Phi && inode.dt > .Mem {
				for inp, i in inode.inps[1:] {
					if get_node(ctx, inp).itype == .Poison do continue
					set := get_or_add_set(ctx, get_node(ctx, inp))
					bac.set_input(ctx, instr, 1 + i, set)
				}
				return
			}

			deps := data_deps(ctx.metas[inode.gvn], inode)
			#reverse for sdep, i in deps {
				dnode := expand_node(ctx, sdep)

				shift: {
					if dnode.itype == .Ret do break shift
					if dnode.itype == .Param do break shift
					if dnode.itype == .Phi do break shift

					pos := slice.linear_search(
						ctx.instrs[:ctx.cursor],
						sdep,
					) or_break shift

					ctx.rcs[get_node(ctx, sdep).gvn] -= 1

					if ctx.rcs[get_node(ctx, sdep).gvn] > 0 do break shift

					if ctx.metas[dnode.gvn].is_mem {
						has_mem := false
						for n in ctx.instrs[pos:ctx.cursor] {
							has_mem |= ctx.metas[get_node(ctx, n).gvn].is_mem
						}
						if has_mem do break shift
					}

					if len(dnode.outs) > 1 {
						dp := get_or_add_set(ctx, dnode)
						if dp != sdep {
							get_node(ctx, dp).rtype = u16(Node_Type.Tee_Local)
						}
					}

					slice.rotate_left(ctx.instrs[pos:ctx.cursor], 1)
					stackify(ctx)
					continue
				}

				dep := get_or_add_set(ctx, dnode)

				get := bac.add_raw(
					ctx,
					"uget",
					u16(Node_Type.Get_Local),
					.Void,
					{dep},
				)

				if dnode.itype in NO_SET_KINDS {
					// TODO: reuse these
					stub := bac.add_raw(
						ctx,
						"stub",
						u16(Node_Type.Stub),
						dnode.dt,
						{},
					)

					inject_at(ctx.instrs, ctx.cursor, stub)

					bac.set_input(
						ctx,
						instr,
						int(ctx.metas[inode.gvn].input_start) + i,
						stub,
					)
				}

				inject_at(ctx.instrs, ctx.cursor, get)
			}
		}

		get_or_add_set :: proc(ctx: ^Ctx, node: ^bac.Node) -> bac.Node_ID {
			if node.itype in NO_SET_KINDS {
				return bac.get_node_id(ctx, node)
			}

			if ctx.sets[node.gvn] == 0 {
				ctx.sets[node.gvn] = bac.add_raw(
					ctx,
					"uset",
					u16(Node_Type.Set_Local),
					node.dt,
					{bac.get_node_id(ctx, node)},
				)
			}

			return ctx.sets[node.gvn]
		}
	}

	for &bb in sched.bbs {
		for i := 0; i < len(bb.instrs); i += 1 {
			instr := bb.instrs[i]
			inode := expand_node(ctx, instr)
			if inode.gvn >= old_gvn || !ctx.metas[inode.gvn].def {continue}
			if ctx.sets[inode.gvn] != 0 {
				insert_pos := i + 1
				for ; get_node(ctx, bb.instrs[insert_pos]).itype == .Phi;
				    insert_pos += 1 {}
				inject_at(&bb.instrs, insert_pos, ctx.sets[inode.gvn])
			}
		}
	}

	for split in splits {
		get_node(ctx, split).rtype = u16(Node_Type.Set_Local)
	}
}

Local_Type_Projection :: struct {
	param_projs: []u16,
	local_start: int,
}

Ctx :: struct {
	using inner: bac.Codegen_Emit_Ctx,
	stack_size:  i32,
	local_projs: [RK_COUNT]Local_Type_Projection,
	bb_metas:    []BB_Meta,
	block_stack: [dynamic]int,
	final_order: [dynamic]int,
	blocks:      [dynamic]Block,
}

BB_Meta :: struct {
	break_block: int,
}

Block_Kind :: enum int {
	Block,
	Loop,
}

Block :: struct {
	loop_too:  bool,
	start:     int,
	end:       int,
	origin:    int,
	worse:     int,
	stack_pos: int,
}

Local_Type :: enum Reg_Kind {
	i64  = RK_I64,
	i32  = RK_I32,
	f64  = RK_F64,
	f32  = RK_F32,
	v128 = RK_V128,
}

@(rodata)
LOCAL_TO_WASM := [Local_Type]Type {
	.i32  = .i32,
	.i64  = .i64,
	.f32  = .f32,
	.f64  = .f64,
	.v128 = .vec,
}

emit_function :: proc(ectx: bac.Codegen_Emit_Ctx) -> bac.Codegen_Emit_Output {
	context.allocator, _ = arna.scrath(ectx.prc.temps)

	ctx: Ctx
	ctx.inner = ectx

	alloc_ty :: proc(reg: bac.Reg) -> (Local_Type, i16) {
		return Local_Type(reg.kind), i16(reg.index)
	}

	ctx.code_start = ctx.code.pos
	ctx.constants_start = ctx.constants.pos

	bac.layout_call_args(ctx.prc, ctx.schedule, &ctx.stack_size)
	bac.layout_locals(ctx.prc, ctx.schedule, &ctx.stack_size)

	compute_blocks: {
		ctx.blocks = make([dynamic]Block, 1, len(ctx.schedule.bbs) + 1)

		for bb, i in ctx.schedule.bbs {
			get_node(ctx, bb.head).gvn = u32(i)
		}

		blocks := &ctx.blocks

		for bb, i in ctx.schedule.bbs {
			hnode := expand_node(ctx, bb.head)
			tail := bb.instrs[len(bb.instrs) - 1]
			tnode := expand_node(ctx, tail)

			if hnode.itype == .Loop {
				pred := expand_node(ctx, hnode.inps[1])
				pred_blk := int(get_node(ctx, pred.inps[0]).gvn)
				append(
					blocks,
					Block {
						loop_too = true,
						start = i,
						origin = pred_blk,
						end = pred_blk,
					},
				)
			}

			for next in tnode.outs {
				nnode := expand_node(ctx, next.id)
				if int(nnode.gvn) != i + 1 &&
				   nnode.itype != .Loop &&
				   nnode.itype != .End {
					start := i

					for ; get_node(ctx, ctx.schedule.bbs[start].head).itype ==
					    .Call_End;
					    start -= 1 {
					}

					append(
						blocks,
						Block{start = start, origin = i, end = int(nnode.gvn)},
					)
				}
			}
		}

		slice.sort_by(blocks[1:], proc(a, b: Block) -> bool {
			return a.end > b.end
		})

		ctx.bb_metas = make([]BB_Meta, len(ctx.schedule.bbs))

		ctx.final_order = make([dynamic]int, 0, len(blocks))
		ctx.block_stack = make([dynamic]int, 0, len(blocks))
		cursor := 1
		for i := len(ctx.schedule.bbs) - 1; i >= 0; i -= 1 {
			for len(ctx.block_stack) > 0 &&
			    blocks[ctx.block_stack[len(ctx.block_stack) - 1]].start >= i {
				idx := pop(&ctx.block_stack)
				blocks[idx].start = i
				append(&ctx.final_order, idx)
			}

			// NOTE: create a linked list of guys that coalesce into the best block
			best_start := len(ctx.schedule.bbs)
			best := 0
			loop := 0
			for ; cursor < len(blocks) && blocks[cursor].end == i;
			    cursor += 1 {
				if blocks[cursor].loop_too {
					loop = cursor
					continue
				}

				if blocks[cursor].start <= best_start {
					blocks[cursor].worse = best
					best = cursor
					best_start = blocks[cursor].start
				} else {
					blocks[cursor].worse = blocks[best].worse
					blocks[best].worse = cursor
				}
			}

			if blocks[best].start >= blocks[loop].start {
				best, loop = loop, best
			}

			for b in ([]int{best, loop}) {
				if b != 0 {
					if blocks[b].start == i {
						assert(blocks[b].loop_too)
						append(&ctx.final_order, b)
					} else {
						append(&ctx.block_stack, b)
					}

					for wcursor := b;
					    wcursor != 0;
					    wcursor = blocks[wcursor].worse {

						fmt.assertf(
							blocks[wcursor].start >= blocks[b].start,
							"%v %v",
							blocks[wcursor],
							blocks[b],
						)

						ctx.bb_metas[blocks[wcursor].origin].break_block = b
					}
				}
			}
		}

		assert(len(ctx.block_stack) == 0)
	}

	param_counts: [RK_COUNT]i16
	total_param_count := 0
	for param in ctx.param_specs {
		if param.dt == .Void do continue
		assert(param.dt != .Mem)
		param_counts[ctx.regalloc.datatype_to_reg_kind[param.dt]] += 1
		total_param_count += 1
	}

	for &proj, i in ctx.local_projs {
		proj.param_projs = make([]u16, param_counts[i])
		cursor := 0
		idx := 0
		for param in ctx.param_specs {
			if param.dt == .Void do continue

			if ctx.regalloc.datatype_to_reg_kind[param.dt] == Reg_Kind(i) {
				proj.param_projs[cursor] = u16(idx)
				cursor += 1
			}

			idx += 1
		}
	}

	local_counts: [Local_Type]i16
	for alloc in ctx.allocs {
		kind, index := alloc_ty(alloc)
		local_counts[kind] = max(
			local_counts[kind],
			index + 1 - param_counts[kind],
		)
	}

	local_count := 0
	for cursor := total_param_count; cnt, i in local_counts {
		local_count += int(cnt != 0)
		ctx.local_projs[i].local_start = cursor
		cursor += int(cnt)
	}

	emit_leb(ctx.code, local_count)
	for cnt, kind in local_counts {
		if cnt != 0 {
			assert(cnt > 0)
			emit_leb(ctx.code, cnt)
			emit(ctx.code, {u8(LOCAL_TO_WASM[kind])})
		}
	}

	prolog: if ctx.stack_size != 0 {
		emit_op(ctx.code, .Global_Get)
		emit_leb(ctx.code, u64(0))
		emit_op(ctx.code, .I64_Const)
		emit_leb(ctx.code, ctx.stack_size)
		emit_op(ctx.code, .I64_Sub)
		emit_op(ctx.code, .Global_Set)
		emit_leb(ctx.code, u64(0))
	}

	if !ODIN_DISABLE_ASSERT {
		for a in ctx.final_order {
			for b in ctx.final_order {
				if a == b do continue

				a_block := ctx.blocks[a]
				b_block := ctx.blocks[b]
				fmt.assertf(
					(a_block.start >= b_block.end ||
						b_block.start >= a_block.end) ||
					(a_block.start >= b_block.start &&
							b_block.end >= a_block.end) ||
					(a_block.start <= b_block.start &&
							b_block.end <= a_block.end),
					"%v %v",
					a_block,
					b_block,
				)
			}
		}
	}

	// if we dont have a return then 0 will still trigger unreachable insertion
	ret_idx := 0
	cursor := len(ctx.final_order) - 1
	for bb, i in ctx.schedule.bbs {
		close_loop := false
		for len(ctx.block_stack) > 0 &&
		    ctx.blocks[ctx.block_stack[len(ctx.block_stack) - 1]].end == i {
			loop_too := ctx.blocks[pop(&ctx.block_stack)].loop_too
			assert(!close_loop || !loop_too)
			close_loop |= loop_too
			if !close_loop do emit_op(ctx.code, .End)
		}

		if close_loop {
			append(&ctx.block_stack, -1)
		}

		for ; cursor >= 0 && ctx.blocks[ctx.final_order[cursor]].start == i;
		    cursor -= 1 {
			ctx.blocks[ctx.final_order[cursor]].stack_pos = len(
				ctx.block_stack,
			)
			append(&ctx.block_stack, ctx.final_order[cursor])
			if ctx.blocks[ctx.final_order[cursor]].loop_too {
				emit_op(ctx.code, .Loop)
				if ctx.blocks[ctx.final_order[cursor]].end == i {
					close_loop = true
				}
			} else {
				emit_op(ctx.code, .Block)
			}
			emit(ctx.code, {0x40})
		}

		for instr in bb.instrs {
			emit_instr(&ctx, instr, i, struct{}{})
		}

		if close_loop {
			emit_op(ctx.code, .End)
			pop(&ctx.block_stack)
		}

		if get_node(ctx, bb.tail).itype == .Return {
			ret_idx = i
		}
	}

	if ret_idx != len(ctx.schedule.bbs) - 1 {
		emit_op(ctx.code, .Unreachable)
	}

	emit_op(ctx.code, .End)

	return {}
}

@(disabled = SPEC_NOT_PRESENT)
emit_instr :: proc(ctx: ^Ctx, instr: bac.Node_ID, block: int, _: $T) {
	node := expand_node(ctx, instr)
	kind := wtype(node)
	op := NODE_TO_OP[kind][node.dt]
	lane_op := NODE_TO_LANE_OP[kind][node.lane]

	#partial switch kind {
	case .Eq ..= .U_Ge:
		op = NODE_TO_OP[kind][get_node(ctx, node.inps[0]).dt]
	}

	block := &ctx.blocks[ctx.bb_metas[block].break_block]
	label := len(ctx.block_stack) - block.stack_pos - 1

	inp: ^bac.Node
	if 0 < len(node.inps) {
		inp = get_node(ctx, node.inps[0])
	}

	mem_op: Mem_Op
	mem_op_ext := wextra(ctx, node, Mem_Op)
	if mem_op_ext != nil {
		mem_op = mem_op_ext^
	} else {
		mem_op.source = node.dt
	}

	switch kind {
	case:
		fallthrough
	case .Nil ..= .Dbg_Scope, .Simd_Reduce_Add_Bisect, .And_Not, .Neg:
		fmt.panicf("Should not reach this: %v", node)
	case .Poison ..= .Phi, .Stub:
	case .CInt:
		cint := bac.get_extra(ctx, node, bac.CInt)

		switch node.dt {
		case .I8, .I16, .I32:
			emit_op(ctx.code, .I32_Const)
			emit_leb(ctx.code, cint.value)
		case .I64:
			emit_op(ctx.code, .I64_Const)
			emit_leb(ctx.code, cint.value)
		case .F32:
			emit_op(ctx.code, .F32_Const)
			bac.emit_anys(ctx.code, f32(cint.fvalue))
		case .F64:
			emit_op(ctx.code, .F64_Const)
			bac.emit_anys(ctx.code, cint.fvalue)
		case .V128:
			assert(cint.value == 0)
			emit_op(ctx.code, .I32_Const)
			emit_leb(ctx.code, cint.value)
			emit_op_fd(ctx.code, .I32x4_Splat)
		case .Void, .Mem, .V256, .V512:
			fmt.panicf("no")
		}
	case .WASM_Shl ..= .WASM_U_Shr, .Select:
		emit_op(ctx.code, op)
	case .Add ..= .U_Rem, .Drop, .Not, .Ctz:
		if node.dt == .V128 {
			fmt.assertf(lane_op != .V128_Load, "%v", node)
			emit_op_fd(ctx.code, lane_op)
		} else {
			#partial switch kind {
			case .Shl, .U_Shr, .Shr:
				fmt.panicf("unlowered scalar shift: %v", node)
			}
			assert(op != .Unreachable)
			emit_op(ctx.code, op)
			if kind == .Not && node.dt == .I64 {
				emit_op(ctx.code, .I64_Extend_I32_U)
			}
		}
	case .Split:
		emit_op(ctx.code, .Local_Get)
		emit_leb(ctx.code, loc_of(ctx, node.inps[0]))
		emit_op(ctx.code, .Local_Set)
		emit_leb(ctx.code, loc_of(ctx, instr))
	case .Conv, .U_Conv:
		unsigned := kind == .U_Conv
		assert(inp.dt in bac.INT_DTS || inp.dt in bac.FLOAT_DTS)
		assert(node.dt in bac.INT_DTS || node.dt in bac.FLOAT_DTS)
		assert(inp.dt != node.dt)

		if inp.dt in bac.INT_DTS && node.dt in bac.INT_DTS {
			int_dt := min(inp.dt, node.dt)
			unsigned |= inp.dt > node.dt

			if inp.dt == .I64 {
				emit_op(ctx.code, .I32_Wrap_I64)
			}

			switch int_dt {
			case .I8, .I16:
				if unsigned {
					emit_op(ctx.code, .I32_Const)
					emit_leb(ctx.code, int_dt == .I8 ? 0xff : 0xffff)
					emit_op(ctx.code, .I32_And)
				} else {
					emit_op(
						ctx.code,
						int_dt == .I8 ? .I32_Extend8_S : .I32_Extend16_S,
					)
				}
			case .I32:
			case .Void, .Mem, .I64 ..= .V512:
				fmt.panicf("NO")
			}

			if node.dt == .I64 {
				emit_op(
					ctx.code,
					unsigned ? .I64_Extend_I32_U : .I64_Extend_I32_S,
				)
			}
			break
		}

		Class :: enum {
			i32,
			i64,
			f32,
			f64,
		}

		@(rodata, static)
		DT_TO_CLASS := #partial [bac.Node_Datatype]Class {
			.I8 ..= .I32     = .i32,
			.I64 = .i64,
			.F32 = .f32,
			.F64 = .f64,
		}

		@(rodata, static)
		CONV_TABLE := [Class][Class][2]Opcode {
			.i32 = #partial{
				.f32 = {.I32_Trunc_F32_S, .I32_Trunc_F32_U},
				.f64 = {.I32_Trunc_F64_S, .I32_Trunc_F64_U},
			},
			.i64 = #partial{
				.f32 = {.I64_Trunc_F32_S, .I64_Trunc_F32_U},
				.f64 = {.I64_Trunc_F64_S, .I64_Trunc_F64_U},
			},
			.f32 = #partial{
				.i32 = {.F32_Convert_I32_S, .F32_Convert_I32_U},
				.i64 = {.F32_Convert_I64_S, .F32_Convert_I64_U},
				.f64 = {.F32_Demote_F64, .F32_Demote_F64},
			},
			.f64 = #partial{
				.i32 = {.F64_Convert_I32_S, .F64_Convert_I32_U},
				.i64 = {.F64_Convert_I64_S, .F64_Convert_I64_U},
				.f32 = {.F64_Promote_F32, .F64_Promote_F32},
			},
		}

		dst := DT_TO_CLASS[node.dt]
		src := DT_TO_CLASS[inp.dt]
		emit_op(ctx.code, CONV_TABLE[dst][src][int(unsigned)])
	case .Cast:
		switch node.dt {
		case .I32:
			assert(inp.dt == .F32)
			emit_op(ctx.code, .I32_Reinterpret_F32)
		case .F32:
			assert(inp.dt == .I32)
			emit_op(ctx.code, .F32_Reinterpret_I32)
		case .I64:
			assert(inp.dt == .F64)
			emit_op(ctx.code, .I64_Reinterpret_F64)
		case .F64:
			assert(inp.dt == .I64)
			emit_op(ctx.code, .F64_Reinterpret_I64)
		case .Void, .Mem, .I8, .I16, .V128 ..= .V512:
			fmt.panicf("no %v %v", node, inp)
		}
	case .Get_Local:
		emit_op(ctx.code, .Local_Get)
		emit_leb(ctx.code, loc_of(ctx, node.inps[0]))
	case .Tee_Local, .Set_Local:
		emit_op(ctx.code, op)
		emit_leb(ctx.code, loc_of(ctx, instr))
	case .Local_Addr:
		offset := i32(bac.get_extra(ctx, node.inps[0], bac.Local).offset)

		emit_op(ctx.code, .Global_Get)
		emit_leb(ctx.code, u64(0))
		emit_op(ctx.code, .I64_Const)
		emit_leb(ctx.code, offset)
		emit_op(ctx.code, .I64_Add)
	case .Global_Addr:
		id := bac.get_extra(ctx, node.inps[0], bac.Tup).idx

		emit_op(ctx.code, .Global_Get)
		bac.add_reloc(ctx.relocs)^ = {
			offset = u32(ctx.code.pos - ctx.code_start),
			kind   = .Global,
			size   = .r32,
			id     = id,
		}
		emit(ctx.code, {0, 0, 0, 0})
	case .Store, .WASM_Store:
		vl := get_node(ctx, node.inps[3])
		if vl.dt == .V128 {
			emit_op_fd(ctx.code, .V128_Store)
		} else {
			emit_op(ctx.code, NODE_TO_OP[.Store][vl.dt])
		}
		emit_leb(ctx.code, 0)
		emit_leb(ctx.code, u64(mem_op.offset))
	case .Load, .WASM_Load:
		base := bac.get_extra(ctx, node.inps[2], bac.Local)
		extra_offset: i32
		if base != nil {
			extra_offset = base.offset
			emit_op(ctx.code, .Global_Get)
			emit_leb(ctx.code, u64(0))
		}

		if node.dt == .V128 {
			emit_op_fd(ctx.code, .V128_Load)
		} else {
			if mem_op.signed {
				@(static, rodata)
				OP_TABLE :=
					#partial [bac.Node_Datatype][bac.Node_Datatype]Opcode {
						.I64 = #partial{
							.I8 = .I64_Load8_S,
							.I16 = .I64_Load16_S,
							.I32 = .I64_Load32_S,
						},
						.I32 = #partial{
							.I8 = .I32_Load8_S,
							.I16 = .I32_Load16_S,
						},
						.I16 = #partial{.I8 = .I32_Load8_S},
					}

				op = OP_TABLE[node.dt][mem_op.source]
			} else if mem_op.source != node.dt {
				@(static, rodata)
				OP_TABLE :=
					#partial [bac.Node_Datatype][bac.Node_Datatype]Opcode {
						.I64 = #partial{
							.I8 = .I64_Load8_U,
							.I16 = .I64_Load16_U,
							.I32 = .I64_Load32_U,
						},
						.I32 = #partial{
							.I8 = .I32_Load8_U,
							.I16 = .I32_Load16_U,
						},
						.I16 = #partial{.I8 = .I32_Load8_U},
					}

				op = OP_TABLE[node.dt][mem_op.source]
			}

			emit_op(ctx.code, op)
		}
		emit_leb(ctx.code, 0)
		emit_leb(ctx.code, u64(mem_op.offset + i64(extra_offset)))
	case .Set:
		emit_op_fc(ctx.code, .Memory_Fill)
		emit_leb(ctx.code, u64(0))
	case .Copy:
		emit_op_fc(ctx.code, .Memory_Copy)
		emit_leb(ctx.code, u64(0))
		emit_leb(ctx.code, u64(0))
	case .Call:
		call := bac.get_extra(ctx, node, bac.Call)

		if bac.is_indirect_call(node) {
			emit_op(ctx.code, .I32_Wrap_I64)
			emit_op(ctx.code, .Call_Indirect)
			bac.add_reloc(ctx.relocs)^ = {
					offset = u32(ctx.code.pos - ctx.code_start),
					kind   = .Text,
					size   = .r32,
					id     = u32(ctx.constants.pos - ctx.constants_start),
				}
			emit(ctx.code, {0, 0, 0, 0})
			emit_leb(ctx.code, u64(0)) // table idx

			real_len := len(node.inps)
			for ; get_node(ctx, node.inps[real_len - 1]).itype == .Local;
			    real_len -= 1 {}

			params := make([]bac.Param_Spec, real_len - bac.CALL_PREFIX - 1)

			for inp, i in node.inps[bac.CALL_PREFIX + 1:real_len] {
				params[i] = {
						dt = get_node(ctx, inp).dt,
					}
			}

			rets := call.rets[:call.ret_count]

			// TODO: write directly
			buf: [dynamic]u8
			append(&buf, 0)
			prev_len := len(buf)
			encode_func_type(&buf, params, rets)
			buf[prev_len - 1] = u8(len(buf) - prev_len)

			emit(ctx.constants, buf[:])
		} else {
			emit_op(ctx.code, .Call)
			bac.add_reloc(ctx.relocs)^ = {
					offset = u32(ctx.code.pos - ctx.code_start),
					kind   = .Text,
					size   = .r32,
					id     = call.cid,
				}
			emit(ctx.code, {0, 0, 0, 0})
		}
	case .Extract_Lane_U:
		lane := wextra(ctx, node, Lane_Op).laneidx
		emit_op_fd(ctx.code, lane_op)
		emit_leb(ctx.code, lane)
	case .Splat, .Simd_Extract_Lsbs:
		emit_op_fd(ctx.code, lane_op)
	case .Proc_Addr:
		id := bac.get_extra(ctx, instr, bac.Tup).idx

		emit_op(ctx.code, .I64_Const)
		bac.add_reloc(ctx.relocs)^ = {
				offset = u32(ctx.code.pos - ctx.code_start),
				kind   = .Text,
				size   = .r32,
				id     = id,
			}
		emit(ctx.code, {0, 0, 0, 0})
	case .Return:
		epilog: if ctx.stack_size != 0 {
			emit_op(ctx.code, .Global_Get)
			emit_leb(ctx.code, u64(0))
			emit_op(ctx.code, .I64_Const)
			emit_leb(ctx.code, ctx.stack_size)
			emit_op(ctx.code, .I64_Add)
			emit_op(ctx.code, .Global_Set)
			emit_leb(ctx.code, u64(0))
		}

		emit_op(ctx.code, .Return)
	case .Jump, .Always:
		if block != &ctx.blocks[0] {
			emit_op(ctx.code, .Br)
			emit_leb(ctx.code, u64(label))
		}
	case .If:
		loop_idx := -1
		for out, i in node.outs {
			if get_node(ctx, out.id).itype == .Loop do loop_idx = i
		}

		if get_node(ctx, node.inps[1]).dt > .I32 {
			emit_op(ctx.code, .I32_Wrap_I64)
		}

		if loop_idx == 1 {
			emit_op(ctx.code, .I32_Eqz)
		}

		if loop_idx != -1 {
			emit_op(ctx.code, .Br_If)
			emit_leb(ctx.code, u64(label))
		} else if block != &ctx.blocks[0] {
			emit_op(ctx.code, .Br_If)
			emit_leb(ctx.code, u64(label))
		}
	case .Trap:
		emit_op(ctx.code, .Unreachable)
	}
}

loc_of :: proc(ctx: ^Ctx, node: bac.Node_ID) -> u16 {
	reg := ctx.allocs[get_node(ctx, node).gvn]
	proj := ctx.local_projs[reg.kind]
	if int(reg.index) < len(proj.param_projs) {
		return proj.param_projs[reg.index]
	} else {
		return u16(proj.local_start) + reg.index - u16(len(proj.param_projs))
	}
}

emit_op_fd :: proc(buf: ^arna.Allocator, op: Opcode_FD) {
	emit(buf, {0xfd})
	emit_leb(buf, u64(op))
}

emit_op_fc :: proc(buf: ^arna.Allocator, op: Opcode_FC) {
	emit(buf, {0xfc})
	emit_leb(buf, u64(op))
}

emit_op :: proc(buf: ^arna.Allocator, op: Opcode) {
	emit(buf, {u8(op)})
}
