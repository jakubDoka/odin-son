package builder

import backend ".."
import "../../vendored/gam/util/arna"
import "../../vendored/gam/util/bit_arr"
import "core:fmt"
import "core:mem"
import "core:slice"

loopopt :: proc(graph: ^backend.Graph) -> (optimized: bool) {
	context.allocator, _ = arna.scrath()

	if .Loop_Opt not_in graph.opt_flags do return

	defer graph.peeped &= !optimized

	Ctx :: struct {
		using graph:   ^backend.Graph,
		sched:         backend.Graph_Schedule,
		cloned_up:     []Node_ID,
		cloned_down:   []Node_ID,
		node_blocks:   []^backend.Graph_Basic_Block,
		in_loop_nodes: bit_arr.Bit_Set,
		instrs:        []Node_ID,
		current_loop:  Node_ID,
	}

	block_of :: proc(
		ctx: Ctx,
		node: Node_ID,
	) -> (
		v: ^backend.Graph_Basic_Block,
	) {
		defer fmt.assertf(v != nil, "%v", graph_get(ctx, node))
		return ctx.node_blocks[graph_get(ctx, node).gvn]
	}

	ctx: Ctx
	ctx.graph = graph
	ctx.cloned_up = make([]Node_ID, graph.gvn * 2)
	ctx.cloned_down = make([]Node_ID, graph.gvn * 2)
	ctx.node_blocks = make(type_of(ctx.node_blocks), graph.gvn * 2)
	ctx.in_loop_nodes = bit_arr.init(graph.gvn * 2)
	backend.graph_schedule(
		graph,
		&ctx.sched,
		context.allocator,
		no_late_pass = true,
	)

	reserve(&ctx.sched.bbs, len(ctx.sched.bbs) * 2)

	for &bb in ctx.sched.bbs {
		hnode := graph_get(ctx.graph, bb.head)
		ctx.node_blocks[hnode.gvn] = &bb
		for instr in bb.instrs {
			if backend.graph_has_flag(
				ctx.graph,
				instr,
				.Is_Basic_Block_Start,
			) {continue}
			inode := graph_get(ctx.graph, instr)
			ctx.node_blocks[inode.gvn] = &bb
		}
	}

	rotate: for &bb, i in ctx.sched.bbs {
		if graph_get(ctx, bb.head).rtype == backend.DEAD_NODE_KIND {
			continue
		}

		hnode := backend.graph_expand(ctx, bb.head)
		if hnode.itype != .Loop do continue

		bnd := graph_expand(ctx, hnode.inps[1])

		// NOTE: this should mean rotation does noting/already rotated
		if bnd.itype == .If do continue
		if len(block_of(ctx, hnode.inps[1]).instrs) == 1 &&
		   (bnd.itype == .Else || bnd.itype == .Then) &&
		   graph_get(ctx, bnd.inps[0]).itype == .If &&
		   block_of(ctx, bnd.inps[0]).loop_tree == bb.loop_tree {

			already_latch := false
			for out in backend.graph_outs(ctx, bnd.inps[0]) {
				if graph_get(ctx, out.id).itype == .Loop {
					already_latch = true
				}
			}

			if !already_latch {
				backend.graph_subsume(ctx, bnd.inps[0], hnode.inps[1])
				continue
			}
		}

		next_ctrl := bb.instrs[len(bb.instrs) - 1]

		nnode := backend.graph_expand(ctx, next_ctrl)
		// TODO: we could do better then this and actually clone calls as well
		if nnode.itype != .If do continue

		then_else_bb: [2]^backend.Graph_Basic_Block
		then_else := [?]Node_ID{nnode.outs[0].id, nnode.outs[1].id}
		break_branch: ^backend.Graph_Basic_Block
		continue_branch: ^backend.Graph_Basic_Block

		for &n, i in then_else_bb {
			n = block_of(ctx, then_else[i])
			if n.loop_tree != bb.loop_tree {
				break_branch = n
			} else {
				continue_branch = n
			}
		}

		// NOTE: this if actually does not break out of the loop
		if break_branch == nil do continue

		fmt.assertf(
			continue_branch != nil,
			"%v %v",
			then_else_bb,
			bb.loop_tree,
		)

		assert(
			graph_get(ctx, break_branch.head).rtype != backend.DEAD_NODE_KIND,
		)

		cond_is_inverted := then_else_bb[0] == break_branch

		ctx.current_loop = bb.head
		ctx.instrs = bb.instrs[:]

		to_clone: [dynamic]Node_ID

		bit_arr.set_all(ctx.in_loop_nodes, false)

		#reverse for instr in bb.instrs[:len(bb.instrs) - 1] {
			nd := graph_expand(ctx, instr)
			for out in nd.outs {
				blk := block_of(ctx, out.id)
				if !in_loop(bb.loop_tree, blk.loop_tree) {
					append(&to_clone, instr)
					break
				}
			}
		}

		for node in to_clone {
			if !check_valid_ops(ctx, node) do continue rotate
		}
		if !check_valid_ops(ctx, nnode.inps[1]) do continue

		optimized = true

		guard_cond := clone_by(
			ctx,
			nnode.inps[1],
			1,
			block_of(ctx, hnode.inps[0]),
		)

		guard := backend.graph_add_if(ctx, "urlg", hnode.inps[0], guard_cond)
		ctx.node_blocks[graph_get(ctx, guard).gvn] = block_of(
			ctx,
			hnode.inps[0],
		)

		guard_loop := backend.graph_add_then(ctx, "urltn", guard)
		wire_up_new_block(&ctx, guard_loop, bb.loop_tree.parent)
		guard_skip := backend.graph_add_else(ctx, "urles", guard)
		wire_up_new_block(&ctx, guard_skip, bb.loop_tree.parent)

		back_cond := clone_by(
			ctx,
			nnode.inps[1],
			2,
			block_of(ctx, hnode.inps[1]),
		)

		backend.graph_set_input(ctx, next_ctrl, 1, back_cond)

		if cond_is_inverted do guard_loop, guard_skip = guard_skip, guard_loop

		backend.graph_set_input(ctx, bb.head, 0, guard_loop)

		join := backend.graph_add_region(
			ctx,
			"urljn",
			{guard_skip, break_branch.head, graph.start},
		)
		join_bb := wire_up_new_block(&ctx, join, bb.loop_tree.parent)

		wire_up_new_block :: proc(
			ctx: ^Ctx,
			node: Node_ID,
			ltree: ^backend.Loop_Tree,
		) -> ^backend.Graph_Basic_Block {
			append(
				&ctx.sched.bbs,
				backend.Graph_Basic_Block{head = node, loop_tree = ltree},
			)
			join_bb := &ctx.sched.bbs[len(ctx.sched.bbs) - 1]
			ctx.node_blocks[graph_get(ctx, node).gvn] = join_bb
			return join_bb
		}

		bouts := backend.graph_outs(ctx, break_branch.head)
		#reverse for out in bouts[:len(bouts) - 1] {
			backend.graph_set_input(ctx, out.id, out.idx, join)
		}

		for instr in break_branch.instrs {
			if !backend.graph_has_flag(ctx, instr, .Is_Basic_Block_Start) {
				ctx.node_blocks[graph_get(ctx, instr).gvn] = join_bb
			}
		}

		if !ODIN_DISABLE_ASSERT {
			for &bb in ctx.sched.bbs {
				if graph_get(ctx, bb.head).rtype == backend.DEAD_NODE_KIND do continue
				assert(block_of(ctx, bb.head) == &bb)
			}
		}

		hnode = graph_expand(ctx, bb.head)

		#reverse for out in to_clone {
			init := clone_by(ctx, out, 1, block_of(ctx, hnode.inps[0]))
			back := clone_by(ctx, out, 2, block_of(ctx, hnode.inps[1]))

			onode := graph_expand(ctx, out)
			nphy := backend.graph_add_phi(
				ctx,
				"urlph",
				onode.dt,
				join,
				init,
				back,
			)
			ctx.node_blocks[graph_get(ctx, nphy).gvn] = join_bb

			oouts := backend.graph_outs(ctx, out)

			rewire: #reverse for pout in oouts {
				blk := block_of(ctx, pout.id)
				ponode := graph_get(ctx, pout.id)

				if in_loop(bb.loop_tree, blk.loop_tree) {
					continue
				}

				dblk := blk.head
				if ponode.itype == .Phi {
					dblk = graph_expand(ctx, dblk).inps[pout.idx - 1]
					if graph_get(ctx, dblk).itype == .If {
						dblk = graph_expand(ctx, dblk).inps[0]
					}
					fmt.assertf(
						backend.graph_has_flag(
							ctx,
							dblk,
							.Is_Basic_Block_Start,
						),
						"%v",
						graph_get(ctx, dblk),
					)
				}

				pdblk := dblk

				for {
					if !ODIN_DISABLE_ASSERT && dblk == ctx.start {
						ctx.sched = {}
						fmt.eprintln(join, pdblk, bb)
						backend.graph_schedule(
							ctx,
							&ctx.sched,
							context.allocator,
							no_late_pass = true,
						)
						panic("brah")
					}

					if bb.head == dblk {
						assert(bb.loop_tree == block_of(ctx, dblk).loop_tree)
					}

					if in_loop(bb.loop_tree, block_of(ctx, dblk).loop_tree) {
						continue rewire
					}

					if dblk == join {
						break
					}

					// NOTE: this should be fine since we never move the join
					dblk = backend.graph_idom(ctx, dblk)
				}

				backend.graph_set_input(ctx, pout.id, pout.idx, nphy)
			}
		}

		in_loop :: proc(
			this: ^backend.Loop_Tree,
			tested: ^backend.Loop_Tree,
		) -> bool {
			assert(tested != nil)
			assert(this != nil)
			for cursor := tested; cursor != nil; cursor = cursor.parent {
				if cursor == this {
					return true
				}
			}

			return false
		}

		backend.graph_pin(ctx, continue_branch.head)
		couts := backend.graph_outs(ctx, continue_branch.head)
		for out in couts[:len(couts) - 1] {
			backend.graph_set_input(ctx, out.id, out.idx, bb.head)
		}

		backend.graph_set_input(ctx, next_ctrl, 0, hnode.inps[1])
		backend.graph_set_input(ctx, bb.head, 1, next_ctrl)

		backend.graph_unpin(ctx, continue_branch.head)
	}

	graph.invalid_idoms |= optimized

	if !ODIN_DISABLE_ASSERT {
		ctx.sched = {}
		backend.graph_schedule(
			ctx,
			&ctx.sched,
			context.allocator,
			no_late_pass = true,
		)
	}

	return

	check_valid_ops :: proc(ctx: Ctx, root: Node_ID) -> bool {
		if !slice.contains(ctx.instrs, root) do return true

		PROHIBITED_OPS :: bit_set[backend.Ideal_Node_Type]{.Copy, .Set, .Store}
		rnode := graph_expand(ctx, root)
		// TODO: we could clone the stores too, but that requires more
		// complex fixups of memory threads
		if rnode.itype in PROHIBITED_OPS do return false

		if rnode.itype != .Phi {
			for inp in rnode.inps {
				if !check_valid_ops(ctx, inp) do return false
			}
		}

		return true
	}

	clone_by :: proc(
		ctx: Ctx,
		root: Node_ID,
		phy_idx: int,
		ctrl: ^backend.Graph_Basic_Block,
	) -> Node_ID {
		if root == ctx.current_loop {
			return ctrl.head
		}

		if !slice.contains(ctx.instrs, root) do return root

		cloned := ctx.cloned_down
		if phy_idx == 1 {
			cloned = ctx.cloned_up
		} else {
			assert(phy_idx == 2)
		}

		node := graph_expand(ctx, root)
		if cloned[node.gvn] == 0 {
			if node.itype == .Phi && node.inps[0] == ctx.current_loop {
				cloned[node.gvn] = node.inps[phy_idx]
			} else {
				graph := ctx.graph
				PRECISION :: backend.PRECISION

				prev := graph.mem.pos

				inps := make([]Node_ID, len(node.inps))

				for &inp, i in inps {
					inp = clone_by(ctx, node.inps[i], phy_idx, ctrl)
				}

				size :=
					backend.graph_size(graph, node.rtype) +
					int(node.extra_dwords) * PRECISION

				tag := backend.graph_get_tag(graph, root)
				backend.graph_push_tag(graph, tag)
				slot := arna.alloc(graph.mem, uint(size), PRECISION)

				mem.copy_non_overlapping(raw_data(slot), node.node, len(slot))

				new_node := (^backend.Node)(raw_data(slot))
				new_node.gvn = graph.gvn
				graph.gvn += 1

				new_node.input_idx = u32(graph.mem.pos / backend.PRECISION)
				_ = arna.clone(graph.mem, inps)
				new_node.input_cap = new_node.input_count

				// This should be fine since we kind of reserver memory for
				// dependants, even if we overallocate its a good estimate
				new_node.output_idx = u32(graph.mem.pos / backend.PRECISION)
				_ = arna.alloc(
					graph.mem,
					uint(node.output_cap * backend.PRECISION),
					backend.PRECISION,
				)
				new_node.output_count = 0
				new_node.output_cap = node.output_cap

				id := backend.graph_id(graph, new_node)
				interned := backend.graph_intern(graph, id)
				if interned != id {
					graph.mem.pos = prev
					id = interned
					graph.gvn -= 1
					cloned[node.gvn] = id
				} else {
					ctx.node_blocks[new_node.gvn] = ctrl
					cloned[node.gvn] = id
					for inp, i in inps {
						backend.graph_add_output(ctx, inp, cloned[node.gvn], i)
					}
				}
			}
		}

		return cloned[node.gvn]
	}
}
