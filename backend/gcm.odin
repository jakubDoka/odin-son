package backend

import "../vendored/gam/util/bit_arr"
import "core:slice"

Graph_Basic_Block :: struct {
	head:   Node_ID,
	tail:   Node_ID,
	instrs: [dynamic]Node_ID,
}

Graph_Schedule :: struct {
	bbs: []Graph_Basic_Block,
}

@(tag = "node_proc")
graph_idepth_node :: proc(graph: ^Graph, node: ^Node) -> u32 {
	extra := graph_extra(graph, node, Cfg_Extra)
	inputs := graph_inputs(graph, node)

	if extra.idepth != 0 || node.itype == .Start {
		return extra.idepth
	}

	extra.idepth = graph_idepth(graph, inputs[0]) + 1
	return extra.idepth
}

graph_schedule :: proc(graph: ^Graph, gs: ^Graph_Schedule) {
	bbs: [dynamic]Graph_Basic_Block
	cfg_rpos: [dynamic]Node_ID
	visited := bit_arr.init(graph.gvn)

	// TODO: add loop tree building

	cfg_reverse_postorder(graph, NODE_START, &cfg_rpos, visited)

	cfg_reverse_postorder :: proc(
		graph: ^Graph,
		root: Node_ID,
		cfg_rpos: ^[dynamic]Node_ID,
		visited: bit_arr.Bit_Set,
	) {
		node := graph_get(graph, root)

		if bit_arr.contains(visited, node.gvn) {
			return
		}
		bit_arr.set(visited, node.gvn)

		for o in graph_outputs(graph, node) {
			if graph_extra(graph, o.id, Cfg_Extra) != nil {
				cfg_reverse_postorder(graph, o.id, cfg_rpos, visited)
			}
		}

		append(cfg_rpos, root)
	}

	slice.reverse(cfg_rpos[:])

	Ctx :: struct {
		graph:           ^Graph,
		early_schedules: []Node_ID,
		nodes:           []Node_ID,
	}

	ctx: Ctx
	ctx.graph = graph
	ctx.early_schedules = make([]Node_ID, graph.gvn)
	ctx.nodes = make([]Node_ID, graph.gvn)

	for id in cfg_rpos {
		ctrl := graph_get(graph, id)
		ctx.early_schedules[ctrl.gvn] = graph_idom(graph, ctrl)

		for i in graph_inputs(graph, id) {
			if graph_extra(graph, i, Cfg_Extra) != nil do continue

			sched_early(ctx, i)

			sched_early :: proc(ctx: Ctx, root: Node_ID) {
				graph := ctx.graph
				node := graph_get(graph, root)

				if ctx.early_schedules[node.gvn] != 0 do return

				sched := NODE_ENTRY

				for inp in graph_inputs(graph, node) {
					sched_early(ctx, inp)

					inp_node := graph_get(graph, inp)

					if graph_idepth(graph, ctx.early_schedules[inp_node.gvn]) >
					   graph_idepth(graph, sched) {
						sched = inp
					}
				}

				ctx.early_schedules[node.gvn] = sched
				ctx.nodes[node.gvn] = root
			}
		}
	}

	bb_idx := 0
	for id, i in cfg_rpos {
		if graph_has_flag(graph, id, .Is_Basic_Block_Start) {
			extra := graph_extra(graph, id, Cfg_Extra)
			extra.bb_idx = u32(bb_idx)
			bb_idx += 1

			append(&bbs, Graph_Basic_Block{head = id, tail = cfg_rpos[i + 1]})
		}
	}

	for node, i in ctx.nodes {
		if node == 0 do continue
		bb := graph_extra(graph, ctx.early_schedules[i], Cfg_Extra).bb_idx
		append(&bbs[bb].instrs, node)
	}

	for &bb in bbs {
		append(&bb.instrs, bb.tail)
	}

	gs.bbs = bbs[:]
}
