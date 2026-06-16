package backend

import "../vendored/gam/util/bit_arr"
import "core:fmt"
import "core:log"
import "core:slice"

Graph_Basic_Block :: struct {
	head:   Node_ID,
	tail:   Node_ID,
	instrs: [dynamic]Node_ID,
	offset: u32,
}

Graph_Schedule :: struct {
	bbs: []Graph_Basic_Block,
}

@(tag = "node_proc")
graph_idom_node :: proc(graph: ^Graph, node: ^Node) -> Node_ID {
	inps := graph_inps(graph, node)

	#partial switch node.itype {
	case .Start:
		return 0
	case .Entry, .Return, .If, .Else, .Then, .Jump, .Loop:
		return inps[0]
	case .Region:
		assert(len(inps) == 2)
		a, b := inps[0], inps[1]
		for a != b {
			adepth, bdepth := graph_idepth(graph, a), graph_idepth(graph, a)
			if adepth <= bdepth do a = graph_idom(graph, a)
			if bdepth <= adepth do b = graph_idom(graph, b)
		}
		return a
	case:
		fmt.panicf("TODO: %v", node.itype)
	}
}

@(tag = "node_proc")
graph_idepth_node :: proc(graph: ^Graph, node: ^Node) -> u32 {
	extra := graph_extra(graph, node, Cfg_Extra)
	inps := graph_inps(graph, node)

	if extra.idepth != 0 {
		return extra.idepth
	}

	#partial switch node.itype {
	case .Start:
	case .Entry, .Return, .If, .Else, .Then, .Jump, .Loop:
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

graph_schedule :: proc(graph: ^Graph, gs: ^Graph_Schedule) {
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
			if graph_extra(graph, o.id, Cfg_Extra) != nil {
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
		nodes:           []Node_ID,
	}

	ctx: Ctx
	ctx.graph = graph
	ctx.early_schedules = make([]Node_ID, graph.gvn)
	ctx.nodes = make([]Node_ID, graph.gvn)

	for id in cfg_rpos {
		ctrl := graph_expand(graph, id)
		ctx.early_schedules[ctrl.gvn] = id

		for out in ctrl.outs {
			onode := graph_expand(graph, out.id)
			ctx.early_schedules[onode.gvn] = id
			if graph_extra(graph, out.id, Cfg_Extra) != nil do continue
			ctx.nodes[onode.gvn] = out.id
		}

		for out in ctrl.outs {
			onode := graph_expand(graph, out.id)
			for i in onode.inps {
				if graph_extra(graph, i, Cfg_Extra) != nil do continue
				sched_early(ctx, i)
			}
		}

		for i in ctrl.inps {
			if graph_extra(graph, i, Cfg_Extra) != nil do continue

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

	bb_idx := 0
	for id, i in cfg_rpos {
		if graph_has_flag(graph, id, .Is_Basic_Block_Start) {
			extra := graph_extra(graph, id, Cfg_Extra)
			extra.bb_idx = u32(bb_idx)
			bb_idx += 1

			tail: Node_ID
			if i + 1 < len(cfg_rpos) &&
			   !graph_has_flag(graph, cfg_rpos[i + 1], .Is_Basic_Block_Start) {
				tail = cfg_rpos[i + 1]
			} else {
				log.error("oob gcm schedule")
			}
			append(&bbs, Graph_Basic_Block{head = id, tail = tail})
		}
	}

	for node, i in ctx.nodes {
		if node == 0 do continue
		bb := graph_extra(graph, ctx.early_schedules[i], Cfg_Extra).bb_idx
		append(&bbs[bb].instrs, node)
	}

	for &bb in bbs {
		if bb.tail == 0 do continue
		append(&bb.instrs, bb.tail)
	}

	gs.bbs = bbs[:]
}
