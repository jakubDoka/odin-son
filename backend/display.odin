package backend

import "../vendored/gam/util/arna"
import "base:runtime"
import "core:fmt"
import "core:io"
import "core:mem"
import "core:reflect"
import "core:terminal/ansi"

graph_display :: proc(
	w: io.Writer,
	graph: ^Graph,
	ctx: ^Graph_Schedule = nil,
	prefix: proc(_: io.Writer, _: ^Node, _: Graph_Basic_Block) = nil,
	regs: []Reg = {},
) {
	context.allocator, _ = arna.scrath()

	ctx := ctx
	our_ctx: Graph_Schedule

	if ctx == nil {
		graph_schedule(graph, &our_ctx, context.allocator)
		ctx = &our_ctx
	}

	seen_loop_trees: map[^Loop_Tree]int

	for bb in ctx.bbs {
		if bb.loop_tree != nil {
			if bb.loop_tree not_in seen_loop_trees {
				seen_loop_trees[bb.loop_tree] = len(seen_loop_trees)
			}
			if bb.loop_tree.parent not_in seen_loop_trees {
				seen_loop_trees[bb.loop_tree.parent] = len(seen_loop_trees)
			}

			fmt.wprintf(
				w,
				"%02i:%02i:%02i ",
				bb.loop_tree.depth,
				seen_loop_trees[bb.loop_tree],
				seen_loop_trees[bb.loop_tree.parent],
			)
		}

		graph_display_node(w, graph, bb.head, scheduled = true)

		fmt.wprint(w, " {\n")

		for instr in bb.instrs {
			inode := graph_get(graph, instr)
			if inode.itype == .Phi {
				continue
			}

			fmt.wprint(w, "  ")
			if len(regs) != 0 {
				if inode.dt != .Void {
					reg := regs[inode.gvn]
					fmt.wprintf(
						w,
						"%v%03i",
						reg_kind_char(reg.kind),
						reg.index,
					)
				} else {
					fmt.wprint(w, "    ")
				}
			} else if prefix != nil {
				prefix(w, inode, bb)
			}
			graph_display_node(w, graph, instr, scheduled = true)
			fmt.wprint(w, "\n")
		}

		fmt.wprint(w, "}\n")
	}
}

graph_display_node :: proc(
	w: io.Writer,
	graph: ^Graph,
	id: Node_ID,
	scheduled := false,
) {
	node := graph_expand(graph, id)

	extra := graph_extra(graph, node)

	graph_display_node_gvn(w, graph, id)
	if node.dt != .Void {
		fmt.wprintf(w, ":%v", node.dt)
	}
	fmt.wprintf(w, ":%v(", graph.node_kind_name[node.rtype])

	written_one: bool
	if node.mem_alignment_pow != 0 {
		written_one = true
		fmt.wprintf(w, "align: %v", 1 << node.mem_alignment_pow)
	}

	graph_display_extra(w, extra, "", &written_one)

	for inp, i in node.inps {
		if written_one {
			if i == int(node.input_count) {
				fmt.wprintf(w, "; ")
			} else {
				fmt.wprintf(w, ", ")
			}
		}
		written_one = true
		graph_display_node_gvn(w, graph, inp)
	}

	if node.itype == .Jump && scheduled {
		reg := node.outs[0]
		rnode := graph_expand(graph, reg.id)
		for out in rnode.outs {
			onode := graph_expand(graph, out.id)
			if onode.itype == .Phi {
				if written_one do fmt.wprintf(w, ", ")
				written_one = true
				graph_display_node_gvn(w, graph, onode.inps[1 + reg.idx])
			}
		}
	}

	if (node.itype == .Region || node.itype == .Loop) && scheduled {
		for out in node.outs {
			onode := graph_get(graph, out.id)
			if onode.itype == .Phi {
				if written_one do fmt.wprintf(w, ", ")
				written_one = true
				graph_display_node_gvn(w, graph, out.id)
			}
		}
	}

	fmt.wprint(w, ") [")
	written_one = false
	for out in node.outs {
		if out.id != 0 {
			onode := graph_expand(graph, out.id)
			if onode.itype == .Phi && scheduled {
				if out.idx != 0 {
					reg := onode.inps[0]
					rnode := graph_expand(graph, reg)
					idx := 0
					for ro in rnode.outs {
						if ro.id == out.id do break
						idx += int(graph_get(graph, ro.id).itype == .Phi)
					}
					if written_one do fmt.wprintf(w, ", ")
					written_one = true
					graph_display_node_gvn(w, graph, rnode.inps[out.idx - 1])
					fmt.wprintf(w, ":%v", 1 + idx)
				}
				continue
			}
		}
		if written_one do fmt.wprintf(w, ", ")
		written_one = true
		graph_display_node_gvn(w, graph, out.id)
		fmt.wprintf(w, ":%v", out.idx)
	}
	fmt.wprint(w, "]")
}

graph_display_extra :: proc(
	w: io.Writer,
	extra: any,
	name: string,
	written_one: ^bool,
) {
	#partial switch info in
		type_info_of(reflect.typeid_base(extra.id)).variant {
	case runtime.Type_Info_Struct:
		for field in reflect.struct_fields_zipped(extra.id) {
			extra_field := reflect.struct_field_value(extra, field)
			graph_display_extra(w, extra_field, field.name, written_one)
			if .raw_union in info.flags do break
		}
		return
	}

	if !mem.check_zero(reflect.as_bytes(extra)) {
		if written_one^ do fmt.wprint(w, ", ")
		written_one^ = true
		if name != "" {
			fmt.wprintf(w, "%v: ", name)
		}
		fmt.wprint(w, extra)
	}
}

ansi_start :: proc(w: io.Writer, #any_int gvn: int) {
	if .Terminal_Color in context.logger.options {
		Combo :: struct {
			fg: string,
			bg: string,
		}

		colors := [?]Combo {
			{fg = ansi.FG_BRIGHT_BLACK},
			{fg = ansi.FG_BRIGHT_RED},
			{fg = ansi.FG_BRIGHT_GREEN},
			{fg = ansi.FG_BRIGHT_YELLOW},
			{fg = ansi.FG_BRIGHT_BLUE},
			{fg = ansi.FG_BRIGHT_MAGENTA},
			{fg = ansi.FG_BRIGHT_CYAN},
			{fg = ansi.FG_RED},
			{fg = ansi.FG_GREEN},
			{fg = ansi.FG_YELLOW},
			{fg = ansi.FG_BLUE},
			{fg = ansi.FG_MAGENTA},
			{fg = ansi.FG_CYAN},
			{fg = ansi.FG_BLACK, bg = ansi.BG_WHITE},
			{fg = ansi.FG_BLACK, bg = ansi.BG_RED},
			{fg = ansi.FG_BLACK, bg = ansi.BG_GREEN},
			{fg = ansi.FG_BLACK, bg = ansi.BG_YELLOW},
			{fg = ansi.FG_WHITE, bg = ansi.BG_BLUE},
			{fg = ansi.FG_WHITE, bg = ansi.BG_BRIGHT_BLACK},
			{fg = ansi.FG_BLACK, bg = ansi.BG_MAGENTA},
			{fg = ansi.FG_BLACK, bg = ansi.BG_CYAN},
			{fg = ansi.FG_BLACK, bg = ansi.BG_WHITE},
		}

		pick := colors[gvn % len(colors)]

		if pick.fg != "" {
			fmt.wprintf(w, ansi.CSI + "%v" + ansi.SGR, pick.fg)
		}

		if pick.bg != "" {
			fmt.wprintf(w, ansi.CSI + "%v" + ansi.SGR, pick.bg)
		}
	}
}

ansi_end :: proc(w: io.Writer) {
	if .Terminal_Color in context.logger.options {
		fmt.wprint(w, ansi.CSI + ansi.RESET + ansi.SGR)
	}
}

graph_get_node_name :: proc(graph: ^Graph, id: Node_ID) -> (name: string) {
	when NODE_NAMES {
		copy(
			reflect.as_bytes(name),
			graph.mem.ptr[int(id) * PRECISION - PREFIX_SIZE:][:PREFIX_SIZE],
		)
	}
	return
}

graph_display_node_gvn :: proc(w: io.Writer, graph: ^Graph, id: Node_ID) {
	if id == 0 {
		fmt.wprint(w, "nl")
		return
	}
	n := graph_get(graph, id)

	ansi_start(w, n.gvn)

	fmt.wprintf(w, "#%v%v", n.gvn, graph_get_node_name(graph, id))

	ansi_end(w)
}
