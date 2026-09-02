package builder

import backend ".."
import "../../vendored/gam/util/arna"
import "core:fmt"
import "core:mem"
import "core:slice"

loopopt :: proc(graph: ^backend.Graph) -> (optimized: bool) {
	context.allocator, _ = arna.scrath()

	if .Loop_Opt not_in graph.opt_flags || true do return

	defer graph.peeped &= !optimized

	Ctx :: struct {
		using graph: ^backend.Graph,
		sched:       backend.Graph_Schedule,
		cloned:      []Node_ID,
		node_blocks: []^backend.Graph_Basic_Block,
		instrs:      []Node_ID,
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
	ctx.cloned = make([]Node_ID, graph.gvn * 2)
	ctx.node_blocks = make(type_of(ctx.node_blocks), graph.gvn * 2)
	backend.graph_schedule(
		graph,
		&ctx.sched,
		context.allocator,
		no_late_pass = true,
	)

	for &bb in ctx.sched.bbs {
		hnode := graph_get(ctx.graph, bb.head)
		ctx.node_blocks[hnode.gvn] = &bb
		for instr in bb.instrs {
			inode := graph_get(ctx.graph, instr)
			ctx.node_blocks[inode.gvn] = &bb
		}
	}

	for bb, i in ctx.sched.bbs {
		if graph_get(ctx, bb.head).rtype == backend.DEAD_NODE_KIND {
			continue
		}

		hnode := backend.graph_expand(ctx, bb.head)
		if hnode.itype != .Loop do continue
		// NOTE: this should mean rotation does noting/already rotated
		if graph_get(ctx, hnode.inps[1]).itype == .If do continue

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

		cond_is_inverted := then_else_bb[0] == break_branch

		ctx.instrs = bb.instrs[:]

		if !check_valid_ops(ctx, nnode.inps[1]) do continue

		optimized = true

		guard_cond := clone_by(
			ctx,
			nnode.inps[1],
			1,
			block_of(ctx, hnode.inps[0]),
		)

		guard := backend.graph_add_if(ctx, "urlg", hnode.inps[0], guard_cond)
		guard_loop := backend.graph_add_then(ctx, "urltn", guard)
		guard_skip := backend.graph_add_else(ctx, "urles", guard)

		slice.fill(ctx.cloned, 0)
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

		bouts := backend.graph_outs(ctx, break_branch.head)
		#reverse for out in bouts[:len(bouts) - 1] {
			backend.graph_set_input(ctx, out.id, out.idx, join)
		}

		#reverse for out in hnode.outs {
			onode := graph_expand(ctx, out.id)
			if onode.itype == .Phi {
				nphy := backend.graph_add_phi(
					ctx,
					"urlph",
					onode.dt,
					join,
					onode.inps[1],
					onode.inps[2],
				)

				oouts := backend.graph_outs(ctx, onode.inps[2])
				assert(oouts[len(oouts) - 1].id == nphy)

				rewire: #reverse for pout in oouts[:len(oouts) - 1] {
					blk := block_of(ctx, pout.id)

					for cursor := blk.loop_tree;
					    cursor != nil;
					    cursor = cursor.parent {
						if cursor == bb.loop_tree do continue rewire
					}

					backend.graph_set_input(ctx, pout.id, pout.idx, nphy)
				}

				backend.graph_delete(ctx, nphy)
			}
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
		if !slice.contains(ctx.instrs, root) do return root

		node := graph_expand(ctx, root)

		if ctx.cloned[node.gvn] == 0 {
			if node.itype == .Phi {
				ctx.cloned[node.gvn] = node.inps[phy_idx]
			} else {
				graph := ctx.graph
				PRECISION :: backend.PRECISION

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

				ctx.cloned[node.gvn] = backend.graph_id(graph, new_node)
				ctx.node_blocks[new_node.gvn] = ctrl

				for inp, i in inps {
					backend.graph_add_output(ctx, inp, ctx.cloned[node.gvn], i)
				}
			}
		}

		return ctx.cloned[node.gvn]
	}
}
