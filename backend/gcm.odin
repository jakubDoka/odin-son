package backend

import "../vendored/gam/util/bit_arr"
import "core:container/queue"
import "core:fmt"
import "core:log"
import "core:slice"
import "core:strings"
import "core:sync"

Graph_Basic_Block :: struct {
	head:      Node_ID,
	tail:      Node_ID,
	instrs:    [dynamic]Node_ID,
	offset:    u32,
	loop_tree: ^Loop_Tree,
}

Graph_Schedule :: struct {
	bbs: []Graph_Basic_Block,
}

Loop_Tree :: struct {
	parent:   ^Loop_Tree,
	depth:    u32,
	infinite: bool,
}

Redundancy_Counter :: struct {
	mut:   sync.Mutex,
	min:   int,
	total: int,
}

redundancy_add :: proc(
	counter: ^Redundancy_Counter,
	#any_int min: int,
	#any_int total: int,
) {
	sync.guard(&counter.mut)
	counter.min += min
	counter.total += total
}

redundancy_log :: proc(counter: ^Redundancy_Counter, loc := #caller_location) {
	sync.guard(&counter.mut)
	log.info(
		counter.min,
		counter.total,
		f32(counter.min) / f32(counter.total),
		location = loc,
	)
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
	     .Always:
		return inps[0]
	case .Region:
		assert(len(inps) == 2)
		return graph_lca(graph, inps[0], inps[1])
	case:
		fmt.panicf("TODO: %v", node.itype)
	}
}

@(tag = "node_proc")
graph_idepth_node :: proc(graph: ^Graph, node: ^Node) -> u32 {
	extra := graph_extra(graph, node, Cfg)
	inps := graph_inps(graph, node)

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
	     .Always:
		extra.idepth = 1 + graph_idepth(graph, inps[0])
	case .Region:
		assert(len(inps) == 2)
		extra.idepth =
			1 + max(graph_idepth(graph, inps[0]), graph_idepth(graph, inps[1]))
	case:
		fmt.panicf("TODO: %v", node.itype)
	}

	return extra.idepth
}

gvn_redc: Redundancy_Counter

graph_schedule :: proc(graph: ^Graph, gs: ^Graph_Schedule) {
	Loop_Ctx :: struct {
		using graph: ^Graph,
		loop_trees:  []^Loop_Tree,
		root:        ^Loop_Tree,
	}

	lctx: Loop_Ctx
	lctx.graph = graph
	lctx.loop_trees = make([]^Loop_Tree, graph.gvn * 2)

	lctx.root = new(Loop_Tree)

	if graph.end != 0 {
		lctx.loop_trees[graph_get(graph, graph.end).gvn] = lctx.root
		build_loop_tree(&lctx, NODE_ENTRY, lctx.root)
	}

	tree_depth :: proc(tree: ^Loop_Tree) -> u32 {
		assert(tree != nil)
		if tree.parent == nil do return 0
		if tree.depth == 0 {
			tree.depth = 1 + tree_depth(tree.parent)
		}
		return tree.depth
	}

	build_loop_tree :: proc(
		ctx: ^Loop_Ctx,
		root: Node_ID,
		tree: ^Loop_Tree,
	) -> ^Loop_Tree {
		tree := tree
		node := graph_expand(ctx, root)

		otree := ctx.loop_trees[node.gvn]
		if otree != nil {
			return otree
		}

		prev_tree := tree

		if node.itype == .Loop {
			tree = new(Loop_Tree)
			tree.depth = 1 + prev_tree.depth
			tree.infinite = true
			ctx.loop_trees[node.gvn] = tree
		}

		deepest: ^Loop_Tree
		for o in node.outs {
			if !is_cfg(ctx, o.id) do continue
			other := build_loop_tree(ctx, o.id, tree)
			deepest = select(deepest, other, true)
			if other != tree {
				tree.parent = select(tree.parent, other, true)
				tree.infinite = false
			}
		}

		if node.itype == .Loop {
			tree.depth = 0
			if tree.parent == nil {
				tree.parent = prev_tree
			}
			deepest = tree.parent

			if tree.infinite {
				always := graph_add_always(ctx, "alw", node.inps[1])
				then := graph_add_then(ctx, "athn", always)
				ctx.loop_trees[graph_get(ctx, then).gvn] = tree
				graph_set_input(ctx, root, 1, then)

				else_ := graph_add_else(ctx, "aels", always)
				ctx.loop_trees[graph_get(ctx, else_).gvn] = ctx.root
				reg := graph_merge_returns(ctx, {else_})
				ctx.loop_trees[graph_get(ctx, reg).gvn] = ctx.root
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
	cfg_rpos: [dynamic]Node_ID
	visited := bit_arr.init(graph.gvn * 2)

	// TODO: add loop tree building

	cfg_reverse_postorder(graph, NODE_START, &cfg_rpos, visited)

	cfg_reverse_postorder :: proc(
		graph: ^Graph,
		root: Node_ID,
		cfg_rpos: ^[dynamic]Node_ID,
		visited: bit_arr.Bit_Set,
	) {
		node := graph_expand(graph, root)

		if bit_arr.contains(visited, node.gvn) {
			return
		}
		bit_arr.set(visited, node.gvn)

		for o in node.outs {
			onode := graph_get(graph, o.id)
			if graph_extra(graph, o.id, Cfg) != nil {
				if (onode.itype == .Region || onode.itype == .Loop) &&
				   node.itype != .Jump {
					jmp := graph_add_jump(graph, "jump", root)
					graph_set_input(graph, o.id, o.idx, jmp)
					cfg_reverse_postorder(graph, jmp, cfg_rpos, visited)
				} else {
					cfg_reverse_postorder(graph, o.id, cfg_rpos, visited)
				}
			}
		}

		append(cfg_rpos, root)
	}

	slice.reverse(cfg_rpos[:])

	Ctx :: struct {
		graph:           ^Graph,
		early_schedules: []Node_ID,
		late_schedules:  []Node_ID,
		nodes:           []Node_ID,
	}

	ctx: Ctx
	ctx.graph = graph
	ctx.early_schedules = make([]Node_ID, graph.gvn)
	ctx.late_schedules = make([]Node_ID, graph.gvn)
	ctx.nodes = make([]Node_ID, graph.gvn)

	for id in cfg_rpos {
		ctrl := graph_expand(graph, id)
		ctx.early_schedules[ctrl.gvn] = id

		for out in ctrl.outs {
			onode := graph_expand(graph, out.id)
			ctx.early_schedules[onode.gvn] = id
			if is_cfg(graph, out.id) do continue
			ctx.nodes[onode.gvn] = out.id
		}
	}

	for id in cfg_rpos {
		ctrl := graph_expand(graph, id)

		for out in ctrl.outs {
			onode := graph_expand(graph, out.id)
			for i in onode.inps[:onode.ordered_input_count] {
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

			sched := NODE_ENTRY

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

	in_worklist := bit_arr.init(graph.gvn)
	worklist: queue.Queue(Node_ID)
	queue.init(&worklist, int(graph.gvn))
	if graph.end != 0 {
		queue.push_front(&worklist, graph.end)
		bit_arr.set(in_worklist, graph_get(graph, graph.end).gvn)
	}

	rounds := 0

	for n in queue.pop_front_safe(&worklist) {
		rounds += 1

		node := graph_expand(graph, n)
		bit_arr.set(in_worklist, node.gvn, false)

		assert(ctx.late_schedules[node.gvn] == 0)

		ready := true
		if graph_has_flag(graph, n, .Is_Basic_Block_Start) {
			ctx.late_schedules[node.gvn] = n
		} else if 0 < len(node.inps) && is_cfg(graph, node.inps[0]) {
			ctx.late_schedules[node.gvn] = node.inps[0]
		} else {
			for out in node.outs {
				onode := graph_expand(graph, out.id)
				if ctx.late_schedules[onode.gvn] == 0 {
					if bit_arr.set(in_worklist, onode.gvn) {
						queue.push_back(&worklist, out.id)
					}
					ready = false
				}
			}
		}

		if !ready do continue

		lca := ctx.late_schedules[node.gvn]
		if lca == 0 {
			for out in node.outs {
				onode := graph_expand(graph, out.id)
				olca := ctx.late_schedules[onode.gvn]

				assert(is_cfg(graph, olca))

				if onode.itype == .Phi {
					jmp := graph_inps(graph, olca)[out.idx - 1]
					olca = graph_inps(graph, jmp)[0]
				}
				lca = graph_lca(graph, lca, olca)
			}

			if !graph_has_flag(graph, lca, .Is_Basic_Block_Start) {
				lca = graph_idom(graph, lca)
			}
			ctx.late_schedules[node.gvn] = lca
		}

		if node.itype == .Loop {
			for out in node.outs {
				onode := graph_expand(graph, out.id)
				if ctx.late_schedules[onode.gvn] == 0 {
					if bit_arr.set(in_worklist, onode.gvn) {
						queue.push_back(&worklist, out.id)
					}
				}
			}
		}

		if node.itype != .Entry {
			for inp in node.inps {
				inode := graph_expand(graph, inp)
				if ctx.late_schedules[inode.gvn] == 0 {
					if bit_arr.set(in_worklist, inode.gvn) {
						queue.push_back(&worklist, inp)
					}
				}
			}
		}
	}

	if false {
		redundancy_add(&gvn_redc, graph.gvn, rounds)
		redundancy_log(&gvn_redc)
	}

	bb_idx := 0
	for id, i in cfg_rpos {
		if graph_has_flag(graph, id, .Is_Basic_Block_Start) {
			ctx.late_schedules[graph_get(graph, id).gvn] = Node_ID(bb_idx)
			loop_tree := lctx.loop_trees[graph_get(graph, id).gvn]

			if graph.end != 0 {
				assert(loop_tree != nil)
				tree_depth(loop_tree)
			}

			bb_idx += 1

			tail: Node_ID
			if i + 1 < len(cfg_rpos) &&
			   !graph_has_flag(graph, cfg_rpos[i + 1], .Is_Basic_Block_Start) {
				tail = cfg_rpos[i + 1]
			} else {
				log.error("oob gcm schedule")
			}
			append(
				&bbs,
				Graph_Basic_Block {
					head = id,
					tail = tail,
					loop_tree = loop_tree,
				},
			)
		}
	}

	for node, i in ctx.nodes {
		if node == 0 do continue
		late := ctx.late_schedules[i]
		early := ctx.early_schedules[i]
		sched := graph.end == 0 ? early : late
		bb := ctx.late_schedules[graph_get(graph, sched).gvn]
		append(&bbs[bb].instrs, node)
	}

	for &bb in bbs {
		if bb.tail == 0 do continue
		schedule_block(graph, &bb)
		append(&bb.instrs, bb.tail)
	}

	gs.bbs = bbs[:]

	if graph.end != 0 {
		verify_schedule_integrity(graph, gs)
	}

	schedule_block :: proc(graph: ^Graph, bb: ^Graph_Basic_Block) {
		phi_count := 0
		for instr, i in bb.instrs {
			if graph_get(graph, instr).itype == .Phi {
				ordered_remove(&bb.instrs, i)
				inject_at(&bb.instrs, phi_count, instr)
				phi_count += 1
			}
		}

		// TODO: this is extremely stupid but works, fix later
		changed := true
		for _ in 0 ..< 1000 {
			changed = false

			for &instr, i in bb.instrs {
				inode := graph_expand(graph, instr)

				if inode.itype != .Phi {
					for &oinstr in bb.instrs[i + 1:] {
						if slice.contains(inode.inps, oinstr) {
							instr, oinstr = oinstr, instr
							changed = true
						}
					}
				}
			}

			if !changed do break
		}
	}
}

@(disabled = ODIN_DISABLE_ASSERT)
verify_schedule_integrity :: proc(graph: ^Graph, sched: ^Graph_Schedule) {
	schedules := make([]Node_ID, graph.gvn)

	if false {
		sb: strings.Builder
		append(&sb.buf, "\n")
		graph_display(strings.to_writer(&sb), graph, sched)
		log.info(string(sb.buf[:]))
	}

	for bb in sched.bbs {
		for instr, i in bb.instrs {
			inode := graph_expand(graph, instr)

			if inode.itype != .Phi {
				for oinstr in bb.instrs[i + 1:] {
					assert(!slice.contains(inode.inps, oinstr))
				}
			}

			fmt.assertf(schedules[inode.gvn] == 0, "%v", inode.node)
			schedules[inode.gvn] = bb.head
		}
	}

	for bb in sched.bbs {
		for instr in bb.instrs {
			inode := graph_expand(graph, instr)
			assert(
				len(inode.outs) != 0 ||
				graph_has_flag(graph, instr, .Immortal),
			)

			for inp, i in inode.inps {
				innode := graph_expand(graph, inp)
				if is_cfg(graph, inp) do continue

				insched := schedules[innode.gvn]

				latest := schedules[inode.gvn]
				if inode.itype == .Phi {
					jmp := graph_inps(graph, inode.inps[0])[i - 1]
					latest = graph_inps(graph, jmp)[0]
				}

				for insched != latest {
					latest = graph_idom(graph, latest)
				}
			}
		}
	}
}

is_cfg :: proc(graph: ^Graph, id: Node_ID) -> bool {
	return graph_extra(graph, id, Cfg) != nil
}
