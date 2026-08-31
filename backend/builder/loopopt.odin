package builder

import backend ".."
import "../../vendored/gam/util/arna"
import "core:mem"
import "core:slice"

loopopt :: proc(graph: ^backend.Graph) -> (optimized: bool) {
	context.allocator, _ = arna.scrath()

	if .Loop_Opt not_in graph.opt_flags do return

	Ctx :: struct {
		using graph: ^backend.Graph,
		sched:       backend.Graph_Schedule,
		cloned:      []Node_ID,
		instrs:      []Node_ID,
	}

	ctx: Ctx
	ctx.graph = graph
	ctx.cloned = make([]Node_ID, graph.gvn * 2)
	backend.graph_schedule(
		graph,
		&ctx.sched,
		context.allocator,
		no_late_pass = true,
	)

	for bb, i in ctx.sched.bbs {
		hnode := backend.graph_expand(ctx, bb.head)
		if hnode.itype != .Loop do continue

		next_ctrl: Node_ID
		for o in hnode.outs {
			if backend.is_cfg(ctx, o.id) {
				next_ctrl = o.id
				break
			}
		}

		nnode := backend.graph_expand(ctx, next_ctrl)
		// TODO: we could do better then this and actually clone calls as well
		if nnode.itype != .If do continue

		then_else_bb: [2]^backend.Graph_Basic_Block
		then_else := [?]Node_ID{nnode.outs[0].id, nnode.outs[1].id}
		break_branch: ^backend.Graph_Basic_Block

		for &n, i in then_else_bb {
			for &obb in ctx.sched.bbs {
				if obb.head == then_else[i] {
					n = &obb
					break
				}
			}
			assert(n != nil)
			if n.loop_tree != bb.loop_tree do break_branch = n
		}

		// NOTE: this if actually does not break out of the loop
		if break_branch == nil do continue

		cond_is_inverted := then_else_bb[0] == break_branch

		ctx.instrs = bb.instrs[:]

		if !check_valid_ops(ctx, nnode.inps[1]) do continue

		cond := clone_up(ctx, nnode.inps[1])

		guard := backend.graph_add_if(ctx, "urlg", hnode.inps[0], cond)
		guard_loop := backend.graph_add_then(ctx, "urltn", guard)
		guard_skip := backend.graph_add_then(ctx, "urles", guard)

		if cond_is_inverted do guard_loop, guard_skip = guard_skip, guard_loop

		backend.graph_set_input(ctx, bb.head, 0, guard_loop)

		check_valid_ops :: proc(ctx: Ctx, root: Node_ID) -> bool {
			if !slice.contains(ctx.instrs, root) do return true

			PROHIBITED_OPS :: bit_set[backend.Ideal_Node_Type] {
				.Copy,
				.Set,
				.Store,
			}
			rnode := graph_expand(ctx, root)
			// TODO: we could clone the stores too, but that requires more
			// complex fixups of memory threads
			if rnode.itype in PROHIBITED_OPS do return false

			for inp in rnode.inps {
				if !check_valid_ops(ctx, inp) do return false
			}

			return true
		}

		clone_up :: proc(ctx: Ctx, root: Node_ID) -> Node_ID {
			if !slice.contains(ctx.instrs, root) do return root

			node := graph_expand(ctx, root)

			if ctx.cloned[node.gvn] == 0 {
				if node.itype == .Phi {
					ctx.cloned[node.gvn] = node.inps[1]
				} else {
					graph := ctx.graph
					PRECISION :: backend.PRECISION

					inps := make([]Node_ID, len(node.inps))

					for &inp, i in inps do inp = clone_up(ctx, node.inps[i])

					size :=
						backend.graph_size(graph, node.rtype) +
						int(node.extra_dwords) * PRECISION

					tag := backend.graph_get_tag(graph, root)
					backend.graph_push_tag(graph, tag)
					slot := arna.alloc(graph.mem, uint(size), PRECISION)

					mem.copy_non_overlapping(
						raw_data(slot),
						node.node,
						len(slot),
					)

					new_node := (^backend.Node)(raw_data(slot))
					new_node.gvn = graph.gvn
					graph.gvn += 1

					new_node.input_idx = u32(graph.mem.pos / backend.PRECISION)
					_ = arna.clone(graph.mem, inps)
					new_node.input_cap = new_node.input_count

					// This should be fine since we kind of reserver memory for
					// dependants, even if we overallocate its a good estimate
					new_node.output_idx = u32(
						graph.mem.pos / backend.PRECISION,
					)
					_ = arna.alloc(
						graph.mem,
						uint(node.output_cap * backend.PRECISION),
						backend.PRECISION,
					)
					new_node.output_count = 0
					new_node.output_cap = node.output_cap

					ctx.cloned[node.gvn] = backend.graph_id(graph, new_node)
				}
			}

			return ctx.cloned[node.gvn]
		}
	}

	return
}
