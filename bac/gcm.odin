package bac

import "../utils/arna"
import "../utils/bit_arr"
import "../utils/fmt"
import "base:runtime"
import "core:slice"

Basic_Block :: struct {
	head:      Node_ID,
	tail:      Node_ID,
	instrs:    [dynamic]Node_ID,
	offset:    u32,
	loop_tree: ^Loop_Tree,
}

Schedule :: struct {
	bbs: [dynamic]Basic_Block,
}

Loop_Tree :: struct {
	parent:         ^Loop_Tree,
	depth:          u32,
	infinite:       bool,
	already_always: bool,
}

compute_lca :: proc(prc: ^Proc, a, b: Node_ID) -> Node_ID {
	a, b := a, b
	for a != b {
		if a == 0 do return b
		if b == 0 do return a
		adepth, bdepth := get_idepth(prc, a), get_idepth(prc, b)
		if adepth >= bdepth do a = get_idom(prc, a)
		if bdepth >= adepth do b = get_idom(prc, b)
	}
	return a
}

@(tag = "node_proc")
get_idom_node :: proc(prc: ^Proc, node: ^Node) -> Node_ID {
	inps := get_inputs(prc, node)

	#partial switch node.itype {
	case .Entry, .Nil:
		return 0
	case .Return,
	     .If,
	     .Else,
	     .Then,
	     .Jump,
	     .Loop,
	     .Call,
	     .Call_End,
	     .Trap,
	     .Always:
		return inps[0]
	case .Region:
		fmt.assertf(len(inps) > 1, "wut %v", node)

		lca: Node_ID
		for inp in inps {
			lca = compute_lca(prc, lca, inp)
		}

		return lca
	case:
		fmt.panicf("TODO: %v", node.itype)
	}
}

@(tag = "node_proc")
get_idepth_node :: proc(prc: ^Proc, node: ^Node) -> u32 {
	extra := get_extra(prc, node, Cfg)
	inps := get_inputs(prc, node)

	fmt.assertf(extra != nil, "%v", node)

	if extra.idepth > prc.min_idepth {
		return extra.idepth
	}

	#partial switch node.itype {
	case .Nil:
		return prc.min_idepth + 1
	case .Entry:
		extra.idepth = prc.min_idepth + 1
	case .Return,
	     .If,
	     .Else,
	     .Then,
	     .Jump,
	     .Loop,
	     .Call_End,
	     .Call,
	     .Trap,
	     .Always:
		extra.idepth = 1 + get_idepth(prc, inps[0])
	case .Region:
		mx: u32
		for inp in inps {
			mx = max(mx, get_idepth(prc, inp))
		}
		extra.idepth = 1 + mx
	case:
		fmt.panicf("TODO: %v", node.itype)
	}

	prc.max_idepth = max(prc.max_idepth, extra.idepth)
	return extra.idepth
}

insert_alwasy :: proc(ctx: ^Proc, root: Node_ID) -> Node_ID {
	node := expand_node(ctx, root)

	inps: [dynamic]Node_ID
	append(&inps, node.inps[1])
	for out in node.outs {
		onode := get_node(ctx, out.id)
		if onode.itype == .Phi && onode.dt == .Mem {
			append(&inps, out.id)
		}
	}

	always := add_always(ctx, "alw", inps[:])
	then := add_then(ctx, "athn", always)
	set_input(ctx, root, 1, then)

	connect(ctx, ctx.end, always)

	return then
}

Schedule_Mode :: enum {
	for_regalloc,
	for_loopopt,
	for_display,
}

/// The function initialzes `gs` with the graph schedule. This is a
/// sidestructure that is trivial to invalidate. It supports 2 modes:
/// - regalloc - slow and full schedule, it is required for regalloc to work
///   properly
/// - loopopt - this is fast aproximet schedule that mainly makes querying loop
///   invariant code more efficiently.
@(tag = "api,priority=94")
schedule_graph :: proc(
	prc: ^Proc,
	gs: ^Schedule,
	purpose: Schedule_Mode,
	scratch := context.allocator,
) {
	loop_opt := purpose == .for_loopopt
	gs^ = {}

	context.allocator, _ = arna.scrath(prc.temps, scratch)

	Loop_Ctx :: struct {
		using prc:  ^Proc,
		loop_trees: []^Loop_Tree,
		root:       ^Loop_Tree,
	}

	lctx: Loop_Ctx
	lctx.prc = prc
	lctx.loop_trees = make([]^Loop_Tree, prc.gvn * 2)

	lctx.root = new(Loop_Tree, scratch)
	lctx.root.depth = 1

	for inp in get_inputs(prc, prc.end) {
		if is_end_ctrl(prc, inp) {
			inode := expand_node(prc, inp)
			if inode.itype != .Always {
				lctx.loop_trees[inode.gvn] = lctx.root
			}
		}
	}

	build_loop_tree(&lctx, prc.entry, lctx.root, !loop_opt, scratch)
	lctx.root.depth = 0

	tree_depth :: proc(tree: ^Loop_Tree, depht := 0) -> u32 {
		assert(tree != nil)
		assert(depht < 1024)
		if tree.parent == nil do return 0
		if tree.depth == 0 {
			tree.depth = 1 + tree_depth(tree.parent, depht + 1)
		}
		return tree.depth
	}

	build_loop_tree :: proc(
		ctx: ^Loop_Ctx,
		root: Node_ID,
		tree: ^Loop_Tree,
		emit_always: bool,
		scratch: runtime.Allocator,
	) -> ^Loop_Tree {
		tree := tree
		node := expand_node(ctx, root)

		otree := ctx.loop_trees[node.gvn]
		if otree != nil {
			return otree
		}

		prev_tree := tree

		if node.itype == .Loop {
			tree = new(Loop_Tree, scratch)
			tree.depth = 1 + prev_tree.depth
			tree.infinite = true
			ctx.loop_trees[node.gvn] = tree
		}

		deepest: ^Loop_Tree
		for o in node.outs {
			if !is_cfg(ctx, o.id) do continue
			other := build_loop_tree(ctx, o.id, tree, emit_always, scratch)

			// The other != tree check is not enough, rotated loops cause the
			// tree to be different from both if branches
			new_deepest := select(deepest, other, true)
			if new_deepest != deepest && deepest != nil {
				new_deepest.parent = select(new_deepest.parent, deepest, true)
				new_deepest.infinite = false
			}
			deepest = new_deepest

			if other != tree {
				//fmt.assertf(tree != ctx.root, "%v", rawptr(other))
				tree.parent = select(tree.parent, other, true)
				tree.infinite = false
			}
		}

		if node.itype == .Always {
			deepest.already_always = true
		}

		if node.itype == .Loop {
			tree.depth = 0
			if tree.parent == nil {
				assert(tree != ctx.root)
				tree.parent = prev_tree
			}
			deepest = tree.parent

			if tree.infinite {
				if emit_always && !tree.already_always {
					prev_sloc := push_sloc(ctx, get_sloc(ctx, node.node)^)
					defer pop_sloc(ctx, prev_sloc)

					fmt.assertf(
						get_node(ctx, node.inps[1]).itype != .If &&
						get_node(ctx, node.inps[1]).itype != .Jump,
						"%v %v",
						get_node(ctx, node.inps[1]),
						rawptr(tree),
					)

					then := insert_alwasy(ctx, root)
					ctx.loop_trees[get_node(ctx, then).gvn] = tree
				}

				deepest = ctx.root
				tree.parent = ctx.root
			}
		} else {
			ctx.loop_trees[node.gvn] = deepest
		}

		return deepest

		select :: proc(a: ^Loop_Tree, b: ^Loop_Tree, deepest: bool) -> ^Loop_Tree {
			assert(a == nil || a.depth != 0)
			assert(b == nil || b.depth != 0)
			if a == nil do return b
			if b == nil do return a
			if deepest {
				if a.depth < b.depth do return b
				return a
			} else {
				if a.depth < b.depth do return a
				return b
			}
		}
	}

	bbs: [dynamic]Basic_Block
	bbs.allocator = scratch
	cfg_rpos: [dynamic]Node_ID
	visited := bit_arr.init(prc.gvn * 2)

	cfg_reverse_postorder(
		prc,
		prc.entry,
		&cfg_rpos,
		visited,
		purpose == .for_regalloc,
	)

	cfg_reverse_postorder :: proc(
		prc: ^Proc,
		root: Node_ID,
		cfg_rpos: ^[dynamic]Node_ID,
		visited: bit_arr.Bit_Set,
		insert_jumps: bool,
	) {
		node := expand_node(prc, root)

		if bit_arr.contains(visited, node.gvn) {
			return
		}
		bit_arr.set(visited, node.gvn)

		for o in node.outs {
			onode := get_node(prc, o.id)
			if is_cfg(prc, o.id) {
				if (onode.itype == .Region || onode.itype == .Loop) &&
				   node.itype != .Jump &&
				   node.itype != .Trap &&
				   node.itype != .If &&
				   insert_jumps {
					prev := push_sloc(prc, get_sloc(prc, node.node)^)
					jmp := add_jump(prc, "jump", root)
					pop_sloc(prc, prev)
					set_input(prc, o.id, o.idx, jmp)
					cfg_reverse_postorder(prc, jmp, cfg_rpos, visited, insert_jumps)
				} else {
					cfg_reverse_postorder(prc, o.id, cfg_rpos, visited, insert_jumps)
				}
			}
		}

		append(cfg_rpos, root)
	}

	slice.reverse(cfg_rpos[:])

	Ctx :: struct {
		using prc:             ^Proc,
		using _:               struct #raw_union {
			early_schedules: []Node_ID,
			antidep_node:    []Node_ID,
			block_idxs:      []u32,
		},
		late_schedules:        []Node_ID,
		nodes:                 []Node_ID,
		antideps:              [][dynamic]Node_ID,
		extra_outputs:         []u16,
		seen_during_inference: bit_arr.Bit_Set,
	}

	ctx: Ctx
	ctx.prc = prc
	ctx.early_schedules = make([]Node_ID, prc.gvn)
	ctx.late_schedules = make([]Node_ID, prc.gvn)
	ctx.nodes = make([]Node_ID, prc.gvn)
	ctx.antideps = make([][dynamic]Node_ID, prc.gvn)
	ctx.extra_outputs = make([]u16, prc.gvn)
	ctx.seen_during_inference = bit_arr.init(prc.gvn)

	for id in cfg_rpos {
		ctrl := expand_node(prc, id)
		ctx.early_schedules[ctrl.gvn] = id

		for out in ctrl.outs {
			onode := expand_node(prc, out.id)
			ctx.early_schedules[onode.gvn] = id
			if is_cfg(prc, out.id) do continue
			ctx.nodes[onode.gvn] = out.id
		}
	}

	for id in cfg_rpos {
		ctrl := expand_node(prc, id)

		for out in ctrl.outs {
			onode := expand_node(prc, out.id)
			for i in onode.inps {
				if is_cfg(prc, i) do continue
				sched_early(ctx, i)
			}
		}

		for i in ctrl.inps {
			if is_cfg(prc, i) do continue
			sched_early(ctx, i)
		}

		sched_early :: proc(ctx: Ctx, root: Node_ID) {
			prc := ctx.prc
			node := expand_node(prc, root)

			if ctx.early_schedules[node.gvn] != 0 {
				return
			}

			sched := prc.entry

			for inp in node.inps {
				sched_early(ctx, inp)

				inp_node := get_node(prc, inp)

				if get_idepth(prc, ctx.early_schedules[inp_node.gvn]) >
				   get_idepth(prc, sched) {
					sched = ctx.early_schedules[inp_node.gvn]
				}
			}

			ctx.early_schedules[node.gvn] = sched
			ctx.nodes[node.gvn] = root
		}
	}

	worklist: Worklist
	worklist_init(&worklist, int(prc.gvn))
	bit_arr.set(worklist.in_queue, 0)
	if !loop_opt {
		for inp in get_inputs(prc, prc.end) {
			worklist_add(prc, &worklist, inp)
		}
	}

	rounds := 0

	for n in worklist_next(prc, &worklist) {
		rounds += 1

		node := expand_node(prc, n)

		assert(ctx.late_schedules[node.gvn] == 0)

		ready := true
		free := false

		PINNED_NODES :: bit_set[Node_Type]{.Phi, .Param, .Ret, .Dbg_Scope}

		lca := ctx.late_schedules[node.gvn]

		if has_flag(prc, n, .Is_Basic_Block_Start) {
			assert(n != 0)
			lca = n
		} else if (node.itype in PINNED_NODES ||
			   (node.itype == .Mem &&
					   get_node(prc, node.inps[0]).itype == .Call_End) ||
			   is_cfg(prc, n)) {
			lca = node.inps[0]
		} else {
			free = true
			if node.is_load && !node.is_store {
				snode := expand_node(prc, node.inps[1])
				for out in snode.outs {
					onode := expand_node(prc, out.id)
					if ctx.late_schedules[onode.gvn] == 0 &&
					   !onode.is_load &&
					   onode.itype != .Local {
						ready = false
					}
				}
			}

			for out in node.outs {
				onode := expand_node(prc, out.id)
				if ctx.late_schedules[onode.gvn] == 0 {
					worklist_add(prc, &worklist, out.id)
					ready = false
				}
			}
		}

		if !ready do continue

		if lca == 0 {
			if len(node.outs) == 0 {
				lca = ctx.early_schedules[node.gvn]
				if lca == 0 {
					ctx.nodes[node.gvn] = n
					lca = prc.entry
				}
				//log.warn("free node with no outputs:", node.node, lca)
			}

			for out in node.outs {
				onode := expand_node(prc, out.id)
				olca := ctx.late_schedules[onode.gvn]

				fmt.assertf(is_cfg(prc, olca), "%v", onode.node)

				if onode.itype == .Phi {
					jmp := get_inputs(prc, olca)[out.idx - 1]
					olca = get_inputs(prc, jmp)[0]
				}
				lca = compute_lca(prc, lca, olca)
			}
		}

		lca = add_mem_antydeps(ctx, node, lca)

		for !has_flag(prc, lca, .Is_Basic_Block_Start) {
			lca = get_idom(prc, lca)
			fmt.assertf(lca != 0, "%v", node)
		}

		if free {
			for cursor := lca; cursor != ctx.early_schedules[node.gvn]; {
				if cursor == 0 do break
				fmt.assertf(
					cursor != 0,
					"%v %v %v",
					node,
					lca,
					ctx.early_schedules[node.gvn],
				)
				cursor = get_idom(ctx.prc, cursor)
				lca = better(ctx, lctx, lca, cursor)
			}
		}

		fmt.assertf(lca != 0, "%v", node)
		ctx.late_schedules[node.gvn] = lca

		if node.itype == .Loop {
			for out in node.outs {
				onode := expand_node(prc, out.id)
				if ctx.late_schedules[onode.gvn] == 0 {
					worklist_add(prc, &worklist, out.id)
				}
			}
		}

		if node.itype != .Entry {
			for inp in node.inps {
				inode := expand_node(prc, inp)
				if ctx.late_schedules[inode.gvn] == 0 {
					worklist_add(prc, &worklist, inp)
				}
			}
			for inp in ctx.antideps[node.gvn] {
				inode := get_node(prc, inp)
				if ctx.late_schedules[inode.gvn] == 0 {
					worklist_add(prc, &worklist, inp)
				}
			}
		}

		if node.is_store ||
		   (node.itype == .Phi && node.dt <= .Mem) ||
		   node.itype == .Call ||
		   node.itype == .Return {
			for out in node.outs {
				onode := expand_node(prc, out.id)
				if ctx.late_schedules[onode.gvn] == 0 && onode.is_load {
					worklist_add(prc, &worklist, out.id)
				}
			}

			if node.itype == .Phi {
				for inp in node.inps[1:] {
					for out in get_outputs(prc, inp) {
						onode := expand_node(prc, out.id)
						if ctx.late_schedules[onode.gvn] == 0 && onode.is_load {
							worklist_add(prc, &worklist, out.id)
						}
					}
				}
			} else if 1 < len(node.inps) {
				for out in get_outputs(prc, node.inps[1]) {
					onode := expand_node(prc, out.id)
					if ctx.late_schedules[onode.gvn] == 0 && onode.is_load {
						worklist_add(prc, &worklist, out.id)
					}
				}
			}
		}

		better :: proc(
			ctx: Ctx,
			lctx: Loop_Ctx,
			current, next: Node_ID,
		) -> Node_ID {
			if !has_flag(ctx.prc, next, .Is_Basic_Block_Start) {
				return current
			}

			if tree_depth(lctx.loop_trees[get_node(ctx.prc, current).gvn]) >
			   tree_depth(lctx.loop_trees[get_node(ctx.prc, next).gvn]) {
				return next
			}

			if get_idepth(ctx.prc, current) < get_idepth(ctx.prc, next) {
				return next
			}

			return current
		}

		add_mem_antydeps :: proc(
			ctx: Ctx,
			node: Expanded_Node,
			lca: Node_ID,
		) -> Node_ID {
			id := get_node_id(ctx.prc, node)
			lca := lca
			if !node.is_load do return lca

			assert(lca != 0)

			mnode := expand_node(ctx.prc, node.inps[1])

			bound := ctx.early_schedules[node.gvn]
			advance_stack: [dynamic]Node_ID
			append(&advance_stack, lca)

			for cursor in pop_safe(&advance_stack) {
				cnode := expand_node(ctx.prc, cursor)

				if ctx.antidep_node[cnode.gvn] != id {
					ctx.antidep_node[cnode.gvn] = id

					if cursor != bound {
						for inp in cnode.inps {
							if is_cfg(ctx.prc, inp) {
								append(&advance_stack, inp)
							}
						}
					}
				}
			}

			for out in mnode.outs {
				onode := expand_node(ctx.prc, out.id)
				ctrl := ctx.late_schedules[onode.gvn]
				cnode := expand_node(ctx.prc, ctrl)

				pull_up := false

				if onode.is_store || onode.itype == .Call {
					pull_up = ctx.antidep_node[cnode.gvn] == id
				}

				if onode.itype == .Phi {
					jmp := cnode.inps[out.idx - 1]
					ctrl = get_inputs(ctx.prc, jmp)[0]
					pull_up = ctx.antidep_node[get_node(ctx.prc, ctrl).gvn] == id
				}

				fmt.assertf(
					has_flag(ctx.prc, ctrl, .Is_Basic_Block_Start) || ctrl == 0,
					"%v",
					ctrl,
				)

				if pull_up {
					lca = compute_lca(ctx.prc, lca, ctrl)
				}
			}

			for out in mnode.outs {
				onode := expand_node(ctx.prc, out.id)

				fmt.assertf(
					!onode.is_store || ctx.late_schedules[onode.gvn] != 0,
					"%v",
					onode,
				)

				if onode.is_store && ctx.late_schedules[onode.gvn] == lca {
					append(&ctx.antideps[onode.gvn], id)
					ctx.extra_outputs[node.gvn] += 1
				}
			}

			return lca
		}
	}

	add_efficiency_stat(prc, .late_schedule_rounds, rounds, prc.gvn)

	bb_idx := 0
	for id, i in cfg_rpos {
		if has_flag(prc, id, .Is_Basic_Block_Start) {
			block := get_node(prc, id)
			ctx.late_schedules[block.gvn] = Node_ID(bb_idx)
			loop_tree := lctx.loop_trees[block.gvn]

			if loop_tree == nil {
				//log.error("missing loop tree at", block)
				loop_tree = new(Loop_Tree)
			}
			tree_depth(loop_tree)

			bb_idx += 1

			tail: Node_ID
			if i + 1 < len(cfg_rpos) &&
			   !has_flag(prc, cfg_rpos[i + 1], .Is_Basic_Block_Start) {
				tail = cfg_rpos[i + 1]
			} else {
				for out in get_outputs(prc, id) {
					if is_cfg(prc, out.id) {
						tail = out.id
					}
				}
			}
			append(
				&bbs,
				Basic_Block {
					head = id,
					tail = tail,
					loop_tree = loop_tree,
					instrs = make([dynamic]Node_ID, scratch),
				},
			)
		}
	}

	has_unscheduled := false

	ctx.nodes[get_node(prc, prc.end).gvn] = 0

	for n, i in ctx.nodes {
		if n == 0 do continue
		node := get_node(prc, n)
		late := ctx.late_schedules[i]
		early := ctx.early_schedules[i]
		sched := loop_opt ? early : late
		ctx.late_schedules[i] = sched
		if sched == 0 {
			//log.error("not scheduled:", node)
			has_unscheduled = true
			continue
		}
		bb := ctx.late_schedules[get_node(prc, sched).gvn]
		ctx.block_idxs[i] = u32(len(bbs[bb].instrs))
		append(&bbs[bb].instrs, n)
	}

	for &bb in bbs {
		if bb.tail == 0 do continue
		append(&bb.instrs, bb.tail)
		ctx.late_schedules[get_node(prc, bb.tail).gvn] = bb.head
		if !loop_opt {
			schedule_block(ctx, &bb)
		}
	}

	gs.bbs = bbs

	if 0 == 1 {
		//display_graph(os.to_writer(os.stderr), prc, gs)
		// 	if has_unscheduled do panic("")
	}

	if !loop_opt {
		verify_schedule_integrity(prc, gs, ctx.antideps, loop_opt)
	}

	schedule_block :: proc(ctx: Ctx, bb: ^Basic_Block) {
		PUSHED_UP :: bit_set[Node_Type]{.Phi, .Ret, .Param}

		prc := ctx.prc

		phi_count := 0
		for instr, i in bb.instrs {
			if get_node(prc, instr).itype in PUSHED_UP {
				ordered_remove(&bb.instrs, i)
				inject_at(&bb.instrs, phi_count, instr)
				phi_count += 1
			}
		}

		changed := true
		for l in 0 ..< 1000 {
			assert(l < 1000 - 1)
			changed = false

			for &instr, i in bb.instrs {
				inode := expand_node(prc, instr)

				if inode.itype not_in PUSHED_UP {
					slcs := [][]Node_ID{inode.inps, ctx.antideps[inode.gvn][:]}
					search: for slc in slcs {
						for inp in slc {
							idx := arna.simd_search(bb.instrs[i + 1:], inp) or_continue
							instr, bb.instrs[i + 1 + idx] = bb.instrs[i + 1 + idx], instr
							changed = true
							break search
						}
					}
				}
			}
			if !changed do break
		}

		#reverse for instr, i in bb.instrs {
			inode := expand_node(prc, instr)

			// NOTE: push single use as late as possible
			#reverse for inp in inode.inps {
				innode := expand_node(prc, inp)

				if innode.output_count + ctx.extra_outputs[innode.gvn] == 1 &&
				   innode.itype not_in PUSHED_UP {
					pos := slice.linear_search(bb.instrs[:i], inp) or_continue
					slice.rotate_left(bb.instrs[pos:i], 1)
					break
				}
			}
		}

		// NOTE: we shift the phy backedges as late as possible, regalloc
		// likes that more
		push_down: if get_node(prc, bb.head).itype == .Loop {
			boundary := len(bb.instrs) - 1
			for ; boundary > 0 && get_node(prc, bb.instrs[boundary - 1]).dt == .Void;
			    boundary -= 1 {}

			if phi_count > boundary do break push_down

			for instr in bb.instrs[:phi_count] {
				inode := expand_node(prc, instr)
				if inode.dt <= .Mem do continue
				pos := slice.linear_search(
					bb.instrs[phi_count:boundary],
					inode.inps[2],
				) or_continue
				pos += phi_count

				next := expand_node(prc, inode.inps[2])

				lowest_schedule := boundary
				for out in next.outs {
					if out.id == instr do continue
					posa := slice.linear_search(
						bb.instrs[pos:lowest_schedule],
						out.id,
					) or_continue
					posa += pos
					lowest_schedule = min(lowest_schedule, posa)
				}
				slice.rotate_left(bb.instrs[pos:lowest_schedule], 1)
			}
		}
	}
}

@(disabled = ODIN_DISABLE_ASSERT)
verify_schedule_integrity :: proc(
	prc: ^Proc,
	sched: ^Schedule,
	antys: [][dynamic]Node_ID = {},
	no_late_pass := false,
) {
	schedules := make([]Node_ID, prc.gvn)

	for bb in sched.bbs {
		for instr, i in bb.instrs {
			inode := expand_node(prc, instr)

			if inode.itype != .Phi {
				for oinstr in bb.instrs[i + 1:] {
					fmt.assertf(
						!slice.contains(inode.inps, oinstr),
						"\n%v\n%v",
						inode,
						get_node(prc, oinstr),
					)
					if len(antys) != 0 {
						fmt.assertf(
							!slice.contains(antys[inode.gvn][:], oinstr),
							"%v %v",
							antys[inode.gvn][:],
							oinstr,
							inode,
						)
					}
				}
			}

			if has_flag(prc, instr, .Is_Basic_Block_Start) do continue

			fmt.assertf(schedules[inode.gvn] == 0, "%v", inode.node)
			schedules[inode.gvn] = bb.head
		}
		fmt.assertf(
			is_cfg(prc, bb.instrs[len(bb.instrs) - 1]),
			"%v",
			get_node(prc, bb.instrs[len(bb.instrs) - 1]),
		)
	}

	for bb in sched.bbs {
		seen_phi := false
		#reverse for instr in bb.instrs {
			inode := get_node(prc, instr)
			is_phi_or_mem := inode.itype == .Phi || inode.itype == .Mem
			fmt.assertf(!seen_phi || is_phi_or_mem, "%v", inode)
			seen_phi |= inode.itype == .Phi
		}

		if bb.head != prc.entry {
			nd := expand_node(prc, bb.head)
			for inp in nd.inps[:len(nd.inps) - int(nd.itype == .Loop)] {
				if !is_cfg(prc, inp) do continue
				fmt.assertf(
					get_idepth(prc, inp) < get_idepth(prc, bb.head) ||
					expand_node(prc, inp).itype == .Jump,
					"%v %v",
					expand_node(prc, inp),
					nd,
				)
			}
		}

		for instr in bb.instrs {
			if has_flag(prc, instr, .Is_Basic_Block_Start) do continue
			inode := expand_node(prc, instr)
			if len(inode.outs) == 0 && !no_late_pass {
				//log.error("dead node in the schedule:", inode.node)
			}

			for inp, i in inode.inps {
				innode := expand_node(prc, inp)
				if is_cfg(prc, inp) do continue

				insched := schedules[innode.gvn]
				fmt.assertf(insched != 0, "%v", inode)

				latest := schedules[inode.gvn]
				fmt.assertf(latest != 0, "%v", inode)
				if inode.itype == .Phi {
					latest = get_inputs(prc, inode.inps[0])[i - 1]
					if get_node(prc, latest).itype == .Jump ||
					   get_node(prc, latest).itype == .If ||
					   get_node(prc, latest).itype == .Trap {
						latest = get_inputs(prc, latest)[0]
					}
					fmt.assertf(
						has_flag(prc, latest, .Is_Basic_Block_Start),
						"%v",
						latest,
					)
				}

				for insched != latest {
					fmt.assertf(latest != 0, "%v %v", inode, innode)
					latest = get_idom(prc, latest)
				}
			}
		}
	}
}

is_cfg :: proc(prc: ^Proc, id: Node_ID) -> bool {
	return get_extra(prc, id, Cfg) != nil
}
