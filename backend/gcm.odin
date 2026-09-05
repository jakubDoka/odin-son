package backend

import "../vendored/gam/util/arna"
import "../vendored/gam/util/bit_arr"
import "base:runtime"
import "core:container/queue"
import "core:fmt"
import "core:log"
import "core:os"
import "core:slice"

Graph_Basic_Block :: struct {
	head:      Node_ID,
	tail:      Node_ID,
	instrs:    [dynamic]Node_ID,
	offset:    u32,
	loop_tree: ^Loop_Tree,
}

Graph_Schedule :: struct {
	bbs: [dynamic]Graph_Basic_Block,
}

Loop_Tree :: struct {
	parent:   ^Loop_Tree,
	depth:    u32,
	infinite: bool,
}

graph_lca :: proc(graph: ^Graph, a, b: Node_ID) -> Node_ID {
	if a == 0 do return b
	if b == 0 do return a

	a, b := a, b
	for a != b {
		adepth, bdepth := graph_idepth(graph, a), graph_idepth(graph, b)
		if adepth >= bdepth do a = graph_idom(graph, a)
		if bdepth >= adepth do b = graph_idom(graph, b)
	}
	return a
}

@(tag = "node_proc")
graph_idom_node :: proc(graph: ^Graph, node: ^Node) -> Node_ID {
	inps := graph_inps(graph, node)

	#partial switch node.itype {
	case .Start:
		return 0
	case .Entry,
	     .Return,
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
		cached := inps[len(inps) - 1]
		if cached != 0 && graph_get(graph, cached).itype == .If {
			return cached
		}

		assert(len(inps) > 1)

		lca: Node_ID
		for inp in inps[:len(inps) - 1] {
			lca = graph_lca(graph, lca, inp)
		}

		//graph_set_input(graph, graph_id(graph, node), len(inps) - 1, lca)

		assert(lca != graph.start && lca != 0)

		return lca
	case:
		fmt.panicf("TODO: %v", node.itype)
	}
}

@(tag = "node_proc")
graph_idepth_node :: proc(graph: ^Graph, node: ^Node) -> u32 {
	extra := graph_extra(graph, node, Cfg)
	inps := graph_inps(graph, node)

	fmt.assertf(extra != nil, "%v", node)

	if extra.idepth != 0 {
		return extra.idepth
	}

	#partial switch node.itype {
	case .Start:
	case .Entry,
	     .Return,
	     .If,
	     .Else,
	     .Then,
	     .Jump,
	     .Loop,
	     .Call_End,
	     .Call,
	     .Trap,
	     .Always:
		extra.idepth = 1 + graph_idepth(graph, inps[0])
	case .Region:
		mx: u32
		for inp in inps {
			mx = max(mx, graph_idepth(graph, inp))
		}
		extra.idepth = 1 + mx
	case:
		fmt.panicf("TODO: %v", node.itype)
	}

	return extra.idepth
}

graph_schedule :: proc(
	graph: ^Graph,
	gs: ^Graph_Schedule,
	scratch: runtime.Allocator,
	no_late_pass := false,
) {
	context.allocator, _ = arna.scrath(scratch)

	Loop_Ctx :: struct {
		using graph: ^Graph,
		loop_trees:  []^Loop_Tree,
		root:        ^Loop_Tree,
	}

	lctx: Loop_Ctx
	lctx.graph = graph
	lctx.loop_trees = make([]^Loop_Tree, graph.gvn * 2)

	lctx.root = new(Loop_Tree, scratch)
	lctx.root.depth = 1

	if graph.end != 0 {
		end := graph_expand(graph, graph.end)
		lctx.loop_trees[end.gvn] = lctx.root

		end_ctrl := graph_expand(graph, end.inps[0])
		lctx.loop_trees[end_ctrl.gvn] = lctx.root
	}
	build_loop_tree(&lctx, graph.entry, lctx.root, !no_late_pass, scratch)
	lctx.root.depth = 0

	if graph.end != 0 {
		end := graph_expand(graph, graph.end)
		if !no_late_pass {
			remove_count := 0
			#reverse for inp, i in end.inps {
				inode := graph_expand(graph, inp)
				idx := int(inode.itype == .Phi)
				if len(inode.inps) == 2 {
					graph_set_input(graph, graph.end, i, inode.inps[idx])
					remove_count += 1
				}
			}
			fmt.assertf(
				remove_count == 0 || remove_count == len(end.inps),
				"%v %v",
				remove_count,
				len(end.inps),
			)
		}

		if graph_has_unreachable_return(graph) {
			for rv, i in end.inps[RET_PREFIX:] {
				graph_remove_output(
					graph,
					rv,
					{id = graph.end, idx = i + RET_PREFIX},
				)
			}
			end.input_count = RET_PREFIX
		}

		// NOTE: this might happen when we eliminate the old return and at the
		// same time bind with a loop trap
		ret := graph_expand(graph, graph.end)
		#reverse for vl, i in ret.inps[1:] {
			val := graph_get(graph, vl)
			if val.itype == .Poison {
				ret.input_count -= 1
				graph_remove_output(graph, vl, {id = graph.end, idx = 1 + i})
			}
		}
	}

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
		node := graph_expand(ctx, root)

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

		if node.itype == .Loop {
			tree.depth = 0
			if tree.parent == nil {
				assert(tree != ctx.root)
				tree.parent = prev_tree
			}
			deepest = tree.parent

			if tree.infinite {
				if emit_always {
					prev_sloc := graph_push_sloc(
						ctx,
						graph_dbg_slot(ctx, node.node)^,
					)
					defer graph_pop_sloc(ctx, prev_sloc)

					fmt.assertf(
						graph_get(ctx, node.inps[1]).itype != .If,
						"%v %v",
						graph_get(ctx, node.inps[1]),
						rawptr(tree),
					)

					always := graph_add_always(ctx, "alw", node.inps[1])
					then := graph_add_then(ctx, "athn", always)
					ctx.loop_trees[graph_get(ctx, then).gvn] = tree
					graph_set_input(ctx, root, 1, then)

					else_ := graph_add_else(ctx, "aels", always)
					ctx.loop_trees[graph_get(ctx, else_).gvn] = ctx.root
					reg := graph_merge_returns(ctx, {else_})
					ctx.loop_trees[graph_get(ctx, reg).gvn] = ctx.root

					reg_gvn := graph_get(ctx, graph_inps(ctx, reg)[0]).gvn
					// NOTE: we might have created a region here if there was no
					// returnt node
					if ctx.loop_trees[reg_gvn] == nil {
						ctx.loop_trees[reg_gvn] = ctx.root
					}
				}

				deepest = ctx.root
				tree.parent = ctx.root
			}
		} else {
			ctx.loop_trees[node.gvn] = deepest
		}

		return deepest

		select :: proc(
			a: ^Loop_Tree,
			b: ^Loop_Tree,
			deepest: bool,
		) -> ^Loop_Tree {
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

	bbs: [dynamic]Graph_Basic_Block
	bbs.allocator = scratch
	cfg_rpos: [dynamic]Node_ID
	visited := bit_arr.init(graph.gvn * 2)

	cfg_reverse_postorder(
		graph,
		graph.start,
		&cfg_rpos,
		visited,
		!no_late_pass,
	)

	cfg_reverse_postorder :: proc(
		graph: ^Graph,
		root: Node_ID,
		cfg_rpos: ^[dynamic]Node_ID,
		visited: bit_arr.Bit_Set,
		insert_jumps: bool,
	) {
		node := graph_expand(graph, root)

		if bit_arr.contains(visited, node.gvn) {
			return
		}
		bit_arr.set(visited, node.gvn)

		for o in node.outs {
			onode := graph_get(graph, o.id)
			if is_cfg(graph, o.id) {
				if ((onode.itype == .Region &&
						   o.idx != int(onode.input_count - 1)) ||
					   onode.itype == .Loop) &&
				   node.itype != .Jump &&
				   node.itype != .Trap &&
				   node.itype != .If &&
				   insert_jumps {
					prev := graph_push_sloc(
						graph,
						graph_dbg_slot(graph, node.node)^,
					)
					jmp := graph_add_jump(graph, "jump", root)
					graph_pop_sloc(graph, prev)
					graph_set_input(graph, o.id, o.idx, jmp)
					cfg_reverse_postorder(
						graph,
						jmp,
						cfg_rpos,
						visited,
						insert_jumps,
					)
				} else {
					cfg_reverse_postorder(
						graph,
						o.id,
						cfg_rpos,
						visited,
						insert_jumps,
					)
				}
			}
		}

		append(cfg_rpos, root)
	}

	slice.reverse(cfg_rpos[:])

	Ctx :: struct {
		graph:          ^Graph,
		using _:        struct #raw_union {
			early_schedules: []Node_ID,
			block_idxs:      []u32,
		},
		late_schedules: []Node_ID,
		nodes:          []Node_ID,
		antideps:       [][dynamic]Node_ID,
		extra_outputs:  []u16,
	}

	ctx: Ctx
	ctx.graph = graph
	ctx.early_schedules = make([]Node_ID, graph.gvn)
	ctx.late_schedules = make([]Node_ID, graph.gvn)
	ctx.nodes = make([]Node_ID, graph.gvn)
	ctx.antideps = make([][dynamic]Node_ID, graph.gvn)
	ctx.extra_outputs = make([]u16, graph.gvn)

	for id in cfg_rpos {
		cfg := graph_extra(graph, id, Cfg)
		ctrl := graph_expand(graph, id)
		cfg.idepth = 0
		if ctrl.itype == .Region {
			graph_set_input(graph, id, len(ctrl.inps) - 1, graph.start)
		}
		ctx.early_schedules[ctrl.gvn] = id

		for out in ctrl.outs {
			onode := graph_expand(graph, out.id)
			ctx.early_schedules[onode.gvn] = id
			if is_cfg(graph, out.id) do continue
			ctx.nodes[onode.gvn] = out.id
		}
	}

	graph.invalid_idoms = false

	for id in cfg_rpos {
		ctrl := graph_expand(graph, id)

		for out in ctrl.outs {
			onode := graph_expand(graph, out.id)
			for i in onode.inps {
				if is_cfg(graph, i) do continue
				sched_early(ctx, i)
			}
		}

		for i in ctrl.inps {
			if is_cfg(graph, i) do continue
			sched_early(ctx, i)
		}

		sched_early :: proc(ctx: Ctx, root: Node_ID) {
			graph := ctx.graph
			node := graph_expand(graph, root)

			if ctx.early_schedules[node.gvn] != 0 {
				return
			}

			sched := graph.entry

			for inp in node.inps {
				sched_early(ctx, inp)

				inp_node := graph_get(graph, inp)

				if graph_idepth(graph, ctx.early_schedules[inp_node.gvn]) >
				   graph_idepth(graph, sched) {
					sched = ctx.early_schedules[inp_node.gvn]
				}
			}

			ctx.early_schedules[node.gvn] = sched
			ctx.nodes[node.gvn] = root
		}
	}

	worklist: queue.Queue(Node_ID)
	queue.init(&worklist, int(graph.gvn))
	if graph.end != 0 && !no_late_pass {
		worklist_add(graph, &worklist, graph.end)
	}

	rounds := 0

	for n in worklist_next(graph, &worklist) {
		rounds += 1

		node := graph_expand(graph, n)

		assert(ctx.late_schedules[node.gvn] == 0)

		ready := true

		if node.is_load {
			snode := graph_expand(graph, node.inps[1])
			for out in snode.outs {
				onode := graph_expand(graph, out.id)
				if ctx.late_schedules[onode.gvn] == 0 &&
				   !onode.is_load &&
				   onode.itype != .Local {
					ready = false
				}
			}
		}

		if !ready do continue

		if graph_has_flag(graph, n, .Is_Basic_Block_Start) {
			assert(n != graph.start)
			ctx.late_schedules[node.gvn] = n
		} else if 0 < len(node.inps) && is_cfg(graph, node.inps[0]) {
			fmt.assertf(node.inps[0] != graph.start, "%v", node.node)
			ctx.late_schedules[node.gvn] = node.inps[0]
		} else {
			fmt.assertf(!node.is_store, "%v", node)
			for out in node.outs {
				onode := graph_expand(graph, out.id)
				if ctx.late_schedules[onode.gvn] == 0 &&
				   (!onode.is_load || !node.is_store) {
					worklist_add(graph, &worklist, out.id)
					ready = false
				}
			}
		}

		if !ready do continue

		lca := ctx.late_schedules[node.gvn]
		if lca == 0 {
			if len(node.outs) == 0 {
				lca = ctx.early_schedules[node.gvn]
				if lca == 0 {
					ctx.nodes[node.gvn] = n
					lca = graph.entry
				}
				log.warn("free node with no outputs:", node.node, lca)
			}

			for out in node.outs {
				onode := graph_expand(graph, out.id)
				if onode.is_load && node.is_store do continue
				olca := ctx.late_schedules[onode.gvn]

				fmt.assertf(is_cfg(graph, olca), "%v", onode.node)

				if onode.itype == .Phi {
					jmp := graph_inps(graph, olca)[out.idx - 1]
					fmt.assertf(
						jmp != graph.start,
						"%v %v %v",
						onode,
						node,
						graph_get(graph, olca),
					)
					olca = graph_inps(graph, jmp)[0]
				}
				lca = graph_lca(graph, lca, olca)
			}

			for !graph_has_flag(graph, lca, .Is_Basic_Block_Start) {
				lca = graph_idom(graph, lca)
				assert(lca != 0)
			}

			assert(lca != graph.start)
			ctx.late_schedules[node.gvn] = lca
		}

		lca = add_antydeps(ctx, node, lca)

		add_antydeps :: proc(
			ctx: Ctx,
			node: Expanded_Node,
			lca: Node_ID,
		) -> Node_ID {
			id := graph_id(ctx.graph, node)
			lca := lca
			if !node.is_load do return lca

			mnode := graph_expand(ctx.graph, node.inps[1])
			for out in mnode.outs {
				onode := graph_expand(ctx.graph, out.id)
				if onode.is_store && ctx.late_schedules[onode.gvn] == lca {
					append(&ctx.antideps[onode.gvn], id)
					ctx.extra_outputs[node.gvn] += 1
				}
			}

			return lca
		}

		if node.itype == .Loop {
			for out in node.outs {
				onode := graph_expand(graph, out.id)
				if ctx.late_schedules[onode.gvn] == 0 {
					worklist_add(graph, &worklist, out.id)
				}
			}
		}

		if node.itype != .Entry {
			for inp in node.inps {
				inode := graph_expand(graph, inp)
				if ctx.late_schedules[inode.gvn] == 0 {
					worklist_add(graph, &worklist, inp)
				}
			}
		}

		if node.is_store ||
		   (node.itype == .Phi && node.dt == .Void) ||
		   node.itype == .Call ||
		   node.itype == .Return {
			for out in node.outs {
				onode := graph_expand(graph, out.id)
				if ctx.late_schedules[onode.gvn] == 0 && onode.is_load {
					worklist_add(graph, &worklist, out.id)
				}
			}

			if node.itype == .Phi {
				for inp in node.inps[1:] {
					for out in graph_outs(graph, inp) {
						onode := graph_expand(graph, out.id)
						if ctx.late_schedules[onode.gvn] == 0 &&
						   onode.is_load {
							worklist_add(graph, &worklist, out.id)
						}
					}
				}
			} else if 1 < len(node.inps) {
				for out in graph_outs(graph, node.inps[1]) {
					onode := graph_expand(graph, out.id)
					if ctx.late_schedules[onode.gvn] == 0 && onode.is_load {
						worklist_add(graph, &worklist, out.id)
					}
				}
			}
		}
	}

	add_efficiency_stat(graph, .late_schedule_rounds, rounds, graph.gvn)

	bb_idx := 0
	for id, i in cfg_rpos {
		if graph_has_flag(graph, id, .Is_Basic_Block_Start) {
			block := graph_get(graph, id)
			ctx.late_schedules[block.gvn] = Node_ID(bb_idx)
			loop_tree := lctx.loop_trees[block.gvn]

			if graph.end != 0 {
				if loop_tree == nil {
					log.error("missing loop tree at", block)
					loop_tree = new(Loop_Tree)
				}
				tree_depth(loop_tree)
			}

			bb_idx += 1

			tail: Node_ID
			if i + 1 < len(cfg_rpos) &&
			   !graph_has_flag(graph, cfg_rpos[i + 1], .Is_Basic_Block_Start) {
				tail = cfg_rpos[i + 1]
			} else {
				for out in graph_outs(graph, id) {
					if is_cfg(graph, out.id) {
						tail = out.id
					}
				}
			}
			append(
				&bbs,
				Graph_Basic_Block {
					head = id,
					tail = tail,
					loop_tree = loop_tree,
					instrs = make([dynamic]Node_ID, scratch),
				},
			)
		}
	}

	has_unscheduled := false

	ctx.late_schedules[graph_get(graph, graph.sym).gvn] = graph.entry
	ctx.late_schedules[graph_get(graph, graph.root_mem).gvn] = graph.entry

	for n, i in ctx.nodes {
		if n == 0 do continue
		node := graph_get(graph, n)
		late := ctx.late_schedules[i]
		early := ctx.early_schedules[i]
		sched := graph.end == 0 || no_late_pass ? early : late
		ctx.late_schedules[i] = sched
		if sched == 0 {
			log.error("not scheduled:", node)
			has_unscheduled = true
			continue
		}
		bb := ctx.late_schedules[graph_get(graph, sched).gvn]
		ctx.block_idxs[i] = u32(len(bbs[bb].instrs))
		append(&bbs[bb].instrs, n)
	}

	for &bb in bbs {
		if bb.tail == 0 do continue
		append(&bb.instrs, bb.tail)
		ctx.late_schedules[graph_get(graph, bb.tail).gvn] = bb.head
		if !no_late_pass {
			schedule_block2(ctx, &bb)
		}
	}

	gs.bbs = bbs

	if graph.end != 0 {
		if !no_late_pass {
			verify_schedule_integrity(graph, gs, ctx.antideps, no_late_pass)
		}
	}

	if 0 == 1 {
		graph_display(os.to_writer(os.stderr), graph, gs)
		// 	if has_unscheduled do panic("")
	}

	schedule_block2 :: proc(ctx: Ctx, bb: ^Graph_Basic_Block) {
		PUSHED_UP :: bit_set[Ideal_Node_Type]{.Phi, .Ret, .Param}

		graph := ctx.graph

		phi_count := 0
		for instr, i in bb.instrs {
			if graph_get(graph, instr).itype in PUSHED_UP {
				ordered_remove(&bb.instrs, i)
				inject_at(&bb.instrs, phi_count, instr)
				phi_count += 1
			}
		}

		// TODO: this is extremely stupid but works, fix later
		changed := true
		for i in 0 ..< 1000 {
			changed = false

			for &instr, i in bb.instrs {
				inode := graph_expand(graph, instr)

				if inode.itype not_in PUSHED_UP {
					for &oinstr in bb.instrs[i + 1:] {
						if slice.contains(inode.inps, oinstr) ||
						   slice.contains(ctx.antideps[inode.gvn][:], oinstr) {

							instr, oinstr = oinstr, instr
							changed = true
							break
						}
					}
				}
			}

			if !changed do break
		}

		#reverse for instr, i in bb.instrs {
			inode := graph_expand(graph, instr)
			#reverse for inp in inode.inps {
				innode := graph_expand(graph, inp)
				if innode.output_count + ctx.extra_outputs[innode.gvn] == 1 &&
				   innode.itype not_in PUSHED_UP {
					pos := slice.linear_search(bb.instrs[:i], inp) or_continue
					slice.rotate_left(bb.instrs[pos:i], 1)
					break
				}
			}
		}
	}

	// TODO: this is slow, but I suspect its just because the schedule quality
	// is worse
	schedule_block :: proc(ctx: Ctx, bb: ^Graph_Basic_Block) {
		PUSHED_UP :: bit_set[Ideal_Node_Type] {
			.Phi,
			.Ret,
			.Param,
			.Mem,
			.Root_Mem,
			.Sym,
		}

		context.allocator, _ = arna.scrath()

		graph := ctx.graph

		Meta :: struct {
			instr:               Node_ID,
			priority:            int,
			remining_dependants: int,
		}

		metas := make([]Meta, len(bb.instrs))
		for instr, i in bb.instrs do metas[i].instr = instr

		cursor := len(bb.instrs) - 1
		schedulable := cursor - 1

		for i := 0; i <= schedulable; {
			meta := &metas[i]

			inode := graph_expand(ctx.graph, meta.instr)

			if inode.itype in PUSHED_UP {
				meta.priority = 1000
			} else if inode.output_count == 1 {
				if graph_get(ctx.graph, inode.outs[0].id).itype == .If {
					meta.priority = 1
				} else if graph_get(ctx.graph, inode.outs[0].id).itype ==
				   .Phi {
					meta.priority = 5
				} else {
					meta.priority = 10
				}
			} else {
				meta.priority = 100
			}

			for out in inode.outs {
				onode := graph_get(ctx.graph, out.id)
				if ctx.late_schedules[onode.gvn] == bb.head &&
				   onode.itype != .Phi {
					meta.remining_dependants += 1
				}
			}

			meta.remining_dependants += int(ctx.extra_outputs[inode.gvn])

			if meta.remining_dependants == 0 {
				metas[i], metas[schedulable] = metas[schedulable], metas[i]
				schedulable -= 1
			} else {
				i += 1
			}
		}

		for cursor >= 0 {
			fmt.assertf(schedulable < cursor, "%v", metas[cursor])
			best := &metas[cursor]
			for i := schedulable + 1; i < cursor; i += 1 {
				if best.priority > metas[i].priority {
					best = &metas[i]
				}
			}

			assert(best.remining_dependants == 0)

			inode := graph_expand(ctx.graph, best.instr)
			len := len(inode.inps)
			if inode.itype == .Call {
				len = int(inode.input_cap)
			}

			inp_grouns := [?][]Node_ID {
				raw_data(inode.inps)[:len],
				ctx.antideps[inode.gvn][:],
			}

			if inode.itype == .Phi do inp_grouns = {}

			for inpg in inp_grouns {
				dec: for inp in inpg {
					if is_cfg(ctx.graph, inp) do continue

					inode := graph_get(ctx.graph, inp)
					if ctx.late_schedules[inode.gvn] == bb.head {
						for i := schedulable; i >= 0; i -= 1 {
							if metas[i].instr == inp {
								assert(metas[i].remining_dependants > 0)
								metas[i].remining_dependants -= 1
								if metas[i].remining_dependants == 0 {
									metas[i], metas[schedulable] =
										metas[schedulable], metas[i]
									schedulable -= 1
								}
								continue dec
							}
						}

						fmt.panicf(
							"wut %v %v",
							inode,
							schedulable,
							ctx.late_schedules[inode.gvn],
						)
					}
				}
			}

			best^, metas[cursor] = metas[cursor], best^
			cursor -= 1
		}

		assert(schedulable == -1)

		for m, i in metas do bb.instrs[i] = m.instr
	}
}

@(disabled = ODIN_DISABLE_ASSERT)
verify_schedule_integrity :: proc(
	graph: ^Graph,
	sched: ^Graph_Schedule,
	antys: [][dynamic]Node_ID = {},
	no_late_pass := false,
) {
	schedules := make([]Node_ID, graph.gvn)

	for bb in sched.bbs {
		for instr, i in bb.instrs {
			inode := graph_expand(graph, instr)

			if inode.itype != .Phi {
				for oinstr in bb.instrs[i + 1:] {
					fmt.assertf(
						!slice.contains(inode.inps, oinstr),
						"\n%v\n%v",
						inode,
						graph_get(graph, oinstr),
					)
					if len(antys) != 0 {
						assert(!slice.contains(antys[inode.gvn][:], oinstr))
					}
				}
			}

			if graph_has_flag(graph, instr, .Is_Basic_Block_Start) do continue

			fmt.assertf(schedules[inode.gvn] == 0, "%v", inode.node)
			schedules[inode.gvn] = bb.head

		}
		assert(is_cfg(graph, bb.instrs[len(bb.instrs) - 1]))
	}

	for bb in sched.bbs {
		seen_phi := false
		#reverse for instr in bb.instrs {
			inode := graph_get(graph, instr)
			is_phi_or_mem := inode.itype == .Phi || inode.itype == .Mem
			fmt.assertf(!seen_phi || is_phi_or_mem, "%v", inode)
			seen_phi |= inode.itype == .Phi
		}

		if bb.head != graph.entry {
			nd := graph_expand(graph, bb.head)
			for inp in nd.inps[:len(nd.inps) - int(nd.itype == .Loop)] {
				if !is_cfg(graph, inp) do continue
				fmt.assertf(
					graph_idepth(graph, inp) < graph_idepth(graph, bb.head),
					"%v %v",
					graph_expand(graph, inp),
					nd,
				)
			}
		}

		for instr in bb.instrs {
			if graph_has_flag(graph, instr, .Is_Basic_Block_Start) do continue
			inode := graph_expand(graph, instr)
			if len(inode.outs) == 0 &&
			   !graph_has_flag(graph, instr, .Immortal) &&
			   !no_late_pass {
				log.error("dead node in the schedule:", inode.node)
			}

			for inp, i in inode.inps {
				innode := graph_expand(graph, inp)
				if is_cfg(graph, inp) do continue

				insched := schedules[innode.gvn]
				fmt.assertf(insched != 0, "%v", inode)

				latest := schedules[inode.gvn]
				fmt.assertf(latest != 0, "%v", inode)
				if inode.itype == .Phi {
					latest = graph_inps(graph, inode.inps[0])[i - 1]
					if graph_get(graph, latest).itype == .Jump ||
					   graph_get(graph, latest).itype == .If ||
					   graph_get(graph, latest).itype == .Trap {
						latest = graph_inps(graph, latest)[0]
					}
					fmt.assertf(
						graph_has_flag(graph, latest, .Is_Basic_Block_Start),
						"%v",
						latest,
					)
				}

				for insched != latest {
					fmt.assertf(latest != 0, "%v %v", inode, innode)
					latest = graph_idom(graph, latest)
				}
			}
		}
	}
}

is_cfg :: proc(graph: ^Graph, id: Node_ID) -> bool {
	return graph_extra(graph, id, Cfg) != nil
}
