package wasm

import backend ".."
import "../../vendored/gam/util/arna"
import "base:runtime"
import "core:fmt"
import "core:mem"
import "core:slice"
import "core:sort"

Reg :: backend.Reg
emit :: backend.emit
emit_leb :: backend.emit_leb
graph_expand :: backend.graph_expand
graph_get :: backend.graph_get

MASK_SIZE :: 64

wtype :: #force_inline proc(node: backend.Expanded_Node) -> WASM_Node_Type {
	return WASM_Node_Type(node.rtype)
}

wasm_extra :: #force_inline proc(
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

WASM_SYSTEMV_CC := backend.Call_Conv {
	name = "WASM_SYSTEMV_CC",
	args = {
		.Vector = transmute([]Reg)runtime.Raw_Slice{len = 64},
		.General = transmute([]Reg)runtime.Raw_Slice{len = 64},
	},
}

when SPEC_NOT_PRESENT {
	Reg_Kind :: backend.Reg_Kind

	inherit_idx_of :: proc($T: typeid) -> u8 {return 0}

	wasm_collect_meta :: proc(
		_: ^backend.Graph,
		_: ^backend.Regalloc,
		_: ^backend.Graph_Schedule,
	) -> (
		[]backend.Regalloc_Node_Meta,
		int,
	) {
		return {}, 0
	}

	WASM_Node_Type :: enum u16 {
		Get_Local,
		Set_Local,
		Tee_Local,
		Drop,
	}

	@(rodata)
	WASM_CLASSES := [WASM_Node_Type]backend.Class_Spec {
		.Get_Local = {no_ctor = true},
		.Set_Local = {no_ctor = true},
		.Tee_Local = {no_ctor = true},
		.Drop = {no_ctor = true},
	}

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

wasm_meta_of :: #force_inline proc(
	graph: ^backend.Graph,
	ra: ^backend.Regalloc,
	node: backend.Expanded_Node,
	_: $T,
) -> backend.Regalloc_Node_Meta {
	out := backend.INVALID_RM_INDEX

	single :: backend.rm_intern_single
	rslice :: backend.rm_intern_slice

	@(rodata, static)
	I64_MASK := [?]i64{i64(max(u32))}

	I64_MASK_IDX :: backend.RM_Intern_Idx{}

	@(rodata, static)
	I64_MASK_SLOTS := [8]backend.RM_Intern_Idx{}

	if node.gvn == 0 {
		ra.mask_len = MASK_SIZE
		rslice(ra, .General, I64_MASK[:])
	}

	if context.user_index == 0 {
		#partial switch wtype(node) {
		case .Root_Mem,
		     .Sym,
		     .Return,
		     .CInt,
		     .Mul,
		     .Add,
		     .Eq,
		     .If,
		     .Jump,
		     .Split,
		     .Local,
		     .Local_Addr,
		     .Call,
		     .Store,
		     .Ret,
		     .Mem:
			return {out = out}
		case .Phi:
			if node.dt == .Void do return {out = out}
			return {
				out = I64_MASK_IDX,
				input_start = 1,
				masks = I64_MASK_SLOTS[:len(node.inps) - 1],
			}
		case .Param:
			idx := backend.graph_extra(graph, node, backend.Tup).idx
			return {out = single(ra, {kind = .General, index = u16(idx)})}
		case .Tee_Local:
			return {out = I64_MASK_IDX}
		case .Set_Local:
			return {out = I64_MASK_IDX}
		case .Get_Local:
			return {out = out, masks = I64_MASK_SLOTS[:1]}
		}
	} else {
		#partial switch wtype(node) {
		case .Root_Mem, .Sym, .Jump, .Local, .Mem:
			return {out = out}
		case .Store:
			return {
				out = I64_MASK_IDX,
				input_start = 2,
				masks = I64_MASK_SLOTS[:2],
			}
		case .Return:
			return {out = out, input_start = 2, masks = I64_MASK_SLOTS[:]}
		case .If:
			return {out = out, input_start = 1, masks = I64_MASK_SLOTS[:1]}
		case .Split:
			return {out = I64_MASK_IDX, masks = I64_MASK_SLOTS[:1]}
		case .Call:
			return {
				out = out,
				input_start = 3,
				masks = I64_MASK_SLOTS[:len(node.inps) - 3],
			}
		case .Phi:
			if node.dt == .Void do return {out = out}
			return {
				out = I64_MASK_IDX,
				input_start = 1,
				masks = I64_MASK_SLOTS[:len(node.inps) - 1],
			}
		case .Mul, .Add, .Eq:
			return {out = I64_MASK_IDX, masks = I64_MASK_SLOTS[:2]}
		case .CInt, .Local_Addr, .Ret, .Param:
			return {out = I64_MASK_IDX}
		}
	}

	fmt.panicf("TODO %v", node)
}

wasm_pre_regalloc_hook :: proc(
	ra: ^backend.Regalloc,
	graph: ^backend.Graph,
	sched: ^backend.Graph_Schedule,
) {
	// NOTE: try to find a efficient ordering of instructions to use the wasm
	// stack as much as possible, its greedy

	Ctx :: struct {
		using graph: ^backend.Graph,
		metas:       []backend.Regalloc_Node_Meta,
		instrs:      ^[dynamic]backend.Node_ID,
		sets:        []backend.Node_ID,
		rcs:         []int,
		cursor:      int,
	}

	ctx: Ctx
	ctx.graph = graph

	for bb, i in sched.bbs {
		graph_get(ctx, bb.head).gvn = u32(i)
	}

	splits: [dynamic]backend.Node_ID

	// NOTE: we do splits here becuase dealing with phy self conflicts is just
	// annoying, maybe we can do better, but not right now
	for &bb in sched.bbs {
		hnode := graph_expand(ctx, bb.head)
		if hnode.itype != .Region && hnode.itype != .Loop do continue

		for inp, i in hnode.inps[:len(hnode.inps) - int(hnode.itype == .Region)] {
			pred_head := backend.graph_inps(ctx, inp)[0]
			pnode := graph_expand(ctx, pred_head)
			pred := &sched.bbs[pnode.gvn]

			for phy in bb.instrs {
				pnode := graph_expand(ctx, phy)
				if pnode.itype != .Phi do break
				if pnode.dt == .Void do continue

				split := backend.graph_add_split(
					ctx,
					"wspl",
					pnode.dt,
					pnode.inps[1 + i],
				)
				backend.graph_set_input(ctx, phy, 1 + i, split)
				inject_at(&pred.instrs, len(pred.instrs) - 1, split)
				append(&splits, split)
			}
		}
	}

	defs: int
	{
		context.user_index = 1
		ctx.metas, defs = wasm_collect_meta(graph, ra, sched)
	}
	ctx.sets = make([]backend.Node_ID, defs)
	ctx.rcs = make([]int, defs)

	old_gvn := ctx.gvn

	for &bb in sched.bbs {
		ctx.cursor = len(bb.instrs)
		ctx.instrs = &bb.instrs

		for instr, i in bb.instrs {
			inode := graph_expand(ctx, instr)
			for dep in backend.data_deps(ctx.metas[inode.gvn], inode) {
				ctx.rcs[graph_get(ctx, dep).gvn] += int(
					slice.contains(bb.instrs[:i], dep),
				)
			}
		}

		hnode := graph_expand(ctx, bb.head)
		if hnode.itype == .Call_End {
			ret_count := 0
			for instr in bb.instrs {
				inode := graph_expand(ctx, instr)
				if inode.itype != .Ret do break
				ret_count += 1
			}

			context.user_ptr = &ctx
			sort.bubble_sort_proc(
				bb.instrs[:ret_count],
				proc(a, b: backend.Node_ID) -> int {
					ctx := (^Ctx)(context.user_ptr)
					return (sort.compare_u32s(
								backend.graph_extra(ctx, b, backend.Tup).idx,
								backend.graph_extra(ctx, a, backend.Tup).idx,
							))
				},
			)

			add_drop :: proc(ctx: Ctx) -> backend.Node_ID {
				return backend.graph_add_raw(
					ctx,
					"rdrp",
					u16(WASM_Node_Type.Drop),
					.Void,
					{},
				)
			}

			real_ret_count :=
				backend.graph_extra(ctx, hnode.inps[0], backend.Call).ret_count

			// NOTE: we need to insert drops ofr the rets that are dead
			laxt_idx := real_ret_count
			for i := 0; i < real_ret_count; i += 1 {
				// NOTE: we rely on the fact there is at least one non ret node
				ret := bb.instrs[i]
				idx := -1
				if graph_get(ctx, ret).itype == .Ret {
					idx = int(backend.graph_extra(ctx, ret, backend.Tup).idx)
				}
				for _ in idx ..< laxt_idx - 1 {
					inject_at(&bb.instrs, i, add_drop(ctx))
					i += 1
				}
				laxt_idx = idx
			}
		}

		for ctx.cursor > 0 {
			stackify(&ctx)
		}

		stackify :: proc(ctx: ^Ctx) {
			ctx.cursor -= 1
			instr := ctx.instrs[ctx.cursor]
			inode := graph_expand(ctx, instr)

			if inode.itype == .Phi do return

			deps := backend.data_deps(ctx.metas[inode.gvn], inode)
			#reverse for dep, i in deps {
				dnode := graph_expand(ctx, dep)

				shift: {
					if dnode.itype == .Ret do break shift
					if dnode.itype == .Param do break shift
					if dnode.itype == .Phi do break shift

					pos := slice.linear_search(
						ctx.instrs[:ctx.cursor],
						dep,
					) or_break shift

					ctx.rcs[graph_get(ctx, dep).gvn] -= 1

					if ctx.rcs[graph_get(ctx, dep).gvn] > 0 do break shift

					if len(dnode.outs) > 1 {
						graph_get(ctx, get_or_add_set(ctx, dnode.gvn)).rtype =
							u16(WASM_Node_Type.Tee_Local)
					}

					slice.rotate_left(ctx.instrs[pos:ctx.cursor], 1)
					stackify(ctx)
					continue
				}

				dep := dep
				if dnode.itype != .Phi && dnode.itype != .Param {
					dep = get_or_add_set(ctx, dnode.gvn)
				}

				get := backend.graph_add_raw(
					ctx,
					"uget",
					u16(WASM_Node_Type.Get_Local),
					.Void,
					{dep},
				)

				if dnode.itype == .Phi {
					backend.graph_set_input(
						ctx,
						instr,
						int(ctx.metas[inode.gvn].input_start) + i,
						ctx.start,
					)
				}

				inject_at(ctx.instrs, ctx.cursor, get)
			}
		}

		get_or_add_set :: proc(ctx: ^Ctx, gvn: u32) -> backend.Node_ID {
			if ctx.sets[gvn] == 0 {
				ctx.sets[gvn] = backend.graph_add_raw(
					ctx,
					"uset",
					u16(WASM_Node_Type.Set_Local),
					.Void,
					{},
				)
			}

			return ctx.sets[gvn]
		}
	}

	for &bb in sched.bbs {
		for i := 0; i < len(bb.instrs); i += 1 {
			instr := bb.instrs[i]
			inode := graph_expand(ctx, instr)
			if inode.gvn >= old_gvn ||
			   !backend.is_def(ctx.metas[inode.gvn]) {continue}
			if ctx.sets[inode.gvn] != 0 {
				insert_pos := i + 1
				for ; graph_get(ctx, bb.instrs[insert_pos]).itype == .Phi;
				    insert_pos += 1 {}
				inject_at(&bb.instrs, insert_pos, ctx.sets[inode.gvn])
			}
		}
	}

	for split in splits {
		graph_get(ctx, split).rtype = u16(WASM_Node_Type.Set_Local)
	}
}

Ctx :: struct {
	using inner: backend.Codegen_Emit_Ctx,
	stack_size:  i32,
	code_start:  u32,
	bb_metas:    []BB_Meta,
	block_stack: [dynamic]int,
	final_order: [dynamic]int,
	blocks:      [dynamic]Block,
}

BB_Meta :: struct {
	break_block: int,
}

Block :: struct {
	start:     int,
	end:       int,
	origin:    int,
	worse:     int,
	stack_pos: int,
}

wasm_emit_function :: proc(
	ectx: backend.Codegen_Emit_Ctx,
) -> backend.Codegen_Output {
	context.allocator, _ = arna.scrath()

	ctx: Ctx
	ctx.inner = ectx

	Local_Type :: enum {
		i64,
	}

	@(static, rodata)
	LOCAL_TO_WASM := [Local_Type]Type {
		.i64 = .i64,
	}

	@(static, rodata)
	DT_TO_LOCAL_TYPE := #partial [backend.Node_Datatype]Local_Type {
		.I64 = .i64,
	}

	alloc_ty :: proc(reg: backend.Reg) -> (Local_Type, i16) {
		switch reg.kind {
		case .General:
			switch reg.index {
			case 0 ..< 32:
				return .i64, i16(reg.index)
			case:
				panic("TODO")
			}
		case .Vector:
			panic("TODO")
		}

		panic("no")
	}

	ctx.code_start = u32(ctx.code.pos)
	reloc_start := ctx.relocs.pos

	backend.layout_stack(ctx.graph, ctx.schedule, &ctx.stack_size)

	compute_blocks: {
		ctx.blocks = make([dynamic]Block, 1, len(ctx.schedule.bbs) + 1)

		for bb, i in ctx.schedule.bbs {
			graph_get(ctx, bb.head).gvn = u32(i)
		}

		blocks := &ctx.blocks

		for bb, i in ctx.schedule.bbs {
			tail := bb.instrs[len(bb.instrs) - 1]
			tnode := graph_expand(ctx, tail)
			for next in tnode.outs {
				nnode := graph_expand(ctx, next.id)
				assert(
					next.idx != len(nnode.inps) - 1 || nnode.itype != .Region,
				)
				if int(nnode.gvn) != i + 1 {
					append(
						blocks,
						Block{start = i, origin = i, end = int(nnode.gvn)},
					)
				}
			}
		}

		slice.sort_by(
			blocks[1:],
			proc(a, b: Block) -> bool {return a.end > b.end},
		)

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
			for ; cursor < len(blocks) && blocks[cursor].end == i;
			    cursor += 1 {
				if blocks[cursor].start <= best_start {
					blocks[cursor].worse = best
					best = cursor
				} else {
					blocks[cursor].worse = blocks[best].worse
					blocks[best].worse = cursor
				}
			}

			if best != 0 {
				append(&ctx.block_stack, best)

				for cursor := best;
				    cursor != 0;
				    cursor = blocks[cursor].worse {
					ctx.bb_metas[blocks[cursor].origin].break_block = cursor
				}
			}
		}

		assert(len(ctx.block_stack) == 0)
	}

	param_counts: [Local_Type]i16
	for param in ctx.param_specs {
		if param.dt == .Void do continue
		param_counts[DT_TO_LOCAL_TYPE[param.dt]] += 1
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
	for cnt in local_counts {
		local_count += int(cnt != 0)
	}

	emit_leb(ctx.code, local_count)
	for cnt, kind in local_counts {
		if cnt != 0 {
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

	cursor := len(ctx.final_order) - 1
	for bb, i in ctx.schedule.bbs {
		for len(ctx.block_stack) > 0 &&
		    ctx.blocks[ctx.block_stack[len(ctx.block_stack) - 1]].end == i {
			pop(&ctx.block_stack)
			emit_op(ctx.code, .End)
		}

		for ; cursor >= 0 && ctx.blocks[ctx.final_order[cursor]].start == i;
		    cursor -= 1 {
			ctx.blocks[ctx.final_order[cursor]].stack_pos = len(
				ctx.block_stack,
			)
			append(&ctx.block_stack, ctx.final_order[cursor])
			emit_op(ctx.code, .Block)
			emit(ctx.code, {0x40})
		}

		for instr in bb.instrs {
			wasm_emit_instr(&ctx, instr, i, struct{}{})
		}
	}
	emit_op(ctx.code, .End)

	relocs := mem.slice_data_cast(
		[]backend.Reloc,
		ctx.relocs.ptr[reloc_start:ctx.relocs.pos],
	)

	return {code = ctx.code.ptr[ctx.code_start:ctx.code.pos], relocs = relocs}
}

@(disabled = GEN_SPEC)
wasm_emit_instr :: proc(ctx: ^Ctx, instr: backend.Node_ID, block: int, _: $T) {
	node := graph_expand(ctx, instr)
	kind := wtype(node)

	block := &ctx.blocks[ctx.bb_metas[block].break_block]
	label := len(ctx.block_stack) - block.stack_pos - 1

	@(static, rodata)
	NODE_TO_OP := #partial [WASM_Node_Type]Wasm_Opcode {
		.Mul       = .I64_Mul,
		.Add       = .I64_Add,
		.Eq        = .I64_Eq,
		.Set_Local = .Local_Set,
		.Tee_Local = .Local_Tee,
	}

	#partial switch kind {
	case .Root_Mem, .Sym, .Phi, .Local, .Ret, .Mem, .Param:
	case .CInt:
		cint := backend.graph_extra(ctx, node, backend.CInt)

		switch node.dt {
		case .I8, .I16, .I32:
			emit_op(ctx.code, .I32_Const)
			emit_leb(ctx.code, cint.value)
		case .I64:
			emit_op(ctx.code, .I64_Const)
			emit_leb(ctx.code, cint.value)
		case .F32:
			emit_op(ctx.code, .F32_Const)
			backend.emit_anys(ctx.code, f32(cint.fvalue))
		case .F64:
			emit_op(ctx.code, .F64_Const)
			backend.emit_anys(ctx.code, cint.fvalue)
		case .V128:
			panic("TODO")
		case .Void, .V256, .V512:
			panic("no")
		}
	case .Mul, .Add, .Eq:
		emit_op(ctx.code, NODE_TO_OP[kind])
	case .Get_Local:
		emit_op(ctx.code, .Local_Get)
		emit_leb(ctx.code, loc_of(ctx, node.inps[0]))
	case .Tee_Local, .Set_Local:
		emit_op(ctx.code, NODE_TO_OP[kind])
		emit_leb(ctx.code, loc_of(ctx, instr))
	case .Call:
		call := backend.graph_extra(ctx, node, backend.Call)

		emit_op(ctx.code, .Call)
		backend.add_reloc(ctx.relocs)^ = {
			offset = u32(ctx.code.pos) - ctx.code_start,
			kind   = .Text,
			size   = .r4,
			id     = call.cid,
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
	case .Jump:
		if block != &ctx.blocks[0] {
			emit_op(ctx.code, .Br)
			emit_leb(ctx.code, u64(label))
		}
	case .If:
		if block != &ctx.blocks[0] {
			emit_op(ctx.code, .Br_If)
			emit_leb(ctx.code, u64(label))
		}
	case:
		fmt.panicf("TODO: %v", node)
	}
}

loc_of :: proc(ctx: ^Ctx, node: backend.Node_ID) -> u16 {
	return ctx.allocs[graph_get(ctx, node).gvn].index
}

emit_op :: proc(buf: ^arna.Allocator, op: Wasm_Opcode) {
	emit(buf, {u8(op)})
}
