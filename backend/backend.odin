package backend

import "../vendored/gam/util/arna"
import "base:runtime"
import "core:fmt"
import "core:mem"
import "core:reflect"
import "core:strings"
import "core:terminal/ansi"

PRECISION :: size_of(u32)
NODE_START :: Node_ID(4) / 4
NODE_ENTRY :: Node_ID(4 + size_of(Node) + size_of(Cfg_Extra)) / 4
REGLOGS :: #config(REGLOGS, false)

Node_Spec_Name :: enum {
	Ideal,
	X64,
}

Node_Spec :: struct {
	node_extra_sizes:  []u8,
	inheritance_table: []u8,
	node_flags:        []Class_Flags,
	node_extra_types:  []typeid,
	node_kind_name:    []string,
	using regalloc:    Regalloc_Spec,
}

Class_Flags :: bit_set[Class_Flag;u8]

Class_Flag :: enum {
	Is_Basic_Block_Start,
	Pinnable,
}

Cfg_Extra :: struct {
	using _: struct #raw_union {
		idom:   u32,
		bb_idx: u32,
	},
}

CInt :: struct #align (4) {
	value: i64,
}

I_Node_Type :: enum u16 {
	Start,
	Entry,
	CInt,
	Return,
}

Node_Datatype :: enum u8 {
	Void,
	I8,
	I16,
	I32,
	I64,
}

Node_ID :: distinct u32

Node_Output :: bit_field u32 {
	id:  Node_ID | 24,
	idx: u8      | 8,
}

Node :: struct {
	using _:             struct #raw_union {
		itype: I_Node_Type,
		xtype: X64_Node_Type,
		rtype: u16,
	},
	using _:             bit_field u8 {
		dt: Node_Datatype | 8,
	},
	user_idx:            u8,
	gvn:                 u32,
	inputs:              u32,
	ordered_input_count: u16,
	input_count:         u16,
	outputs:             u32,
	output_count:        u16,
	output_cap:          u16,
	extra:               [0]u32,
}

#assert(size_of(Node) == 24)

Graph :: struct {
	using node_spec: ^Node_Spec,
	mem:             arna.Allocator,
	gvn:             u32,
	end:             Node_ID,
}

graph_get :: #force_inline proc(graph: ^Graph, id: Node_ID) -> ^Node {
	assert(id != 0)
	return (^Node)(&([^]u32)(graph.mem.ptr)[id])
}

@(tag = "node_proc")
graph_idom_node :: proc(graph: ^Graph, node: ^Node) -> Node_ID {
	#partial switch node.itype {
	case .Start:
		return 0
	case .Entry, .Return:
		return graph_inputs(graph, node)[0]
	case:
		panic("TODO")
	}
}

@(tag = "node_proc")
graph_inputs_node :: #force_inline proc(
	graph: ^Graph,
	node: ^Node,
) -> []Node_ID {
	return ([^]Node_ID)(graph.mem.ptr)[node.inputs:][:node.input_count]
}

@(tag = "node_proc")
graph_outputs_node :: #force_inline proc(
	graph: ^Graph,
	node: ^Node,
) -> []Node_Output {
	return ([^]Node_Output)(graph.mem.ptr)[node.outputs:][:node.output_count]
}

graph_add_raw :: proc(
	graph: ^Graph,
	type: u16,
	dt: Node_Datatype,
	inputs: []Node_ID,
) -> (
	id: Node_ID,
) {
	id = Node_ID(graph.mem.pos / PRECISION)

	size := size_of(Node) + int(graph.node_extra_sizes[type]) * PRECISION
	slot := arna.alloc(&graph.mem, uint(size), PRECISION)

	node := (^Node)(raw_data(slot))
	node^ = {
		rtype               = type,
		dt                  = dt,
		gvn                 = graph.gvn,
		inputs              = u32(graph.mem.pos / PRECISION),
		ordered_input_count = u16(len(inputs)),
		input_count         = u16(len(inputs)),
	}

	new_inputs := arna.alloc(
		&graph.mem,
		uint(len(inputs) * PRECISION),
		PRECISION,
	)
	copy(mem.slice_data_cast([]Node_ID, new_inputs), inputs)

	for inp, i in inputs {
		graph_add_output(graph, inp, id, i)
	}

	graph.gvn += 1

	return
}

@(tag = "node_proc")
graph_add_output_node :: proc(
	graph: ^Graph,
	node: ^Node,
	out: Node_ID,
	i: int,
) {
	if node.output_cap == node.output_count {
		base := u32(graph.mem.pos / PRECISION)
		new_cap := node.output_cap * 2 + 2
		slot := arna.alloc(&graph.mem, uint(new_cap * PRECISION), PRECISION)
		copy(
			mem.slice_data_cast([]Node_Output, slot),
			graph_outputs(graph, node),
		)
		node.output_cap = new_cap
		node.outputs = base
	}

	node.output_count += 1
	assert(i < 256)
	graph_outputs(graph, node)[node.output_count - 1] = {
		id  = out,
		idx = u8(i),
	}
}

graph_is_block_start_node :: proc(graph: ^Graph, node: ^Node) -> bool {
	return node.itype == .Entry
}

graph_get_extra :: proc {
	graph_get_any_extra_node,
	graph_get_any_extra_node_id,
	graph_get_static_extra_node,
	graph_get_static_extra_node_id,
}

@(tag = "node_proc")
graph_get_static_extra_node :: #force_inline proc(
	graph: ^Graph,
	node: ^Node,
	$T: typeid,
) -> ^T {
	if graph.inheritance_table[node.rtype] & (1 << inherit_idx_of(T)) ==
	   0 {return nil}
	return (^T)(&node.extra)
}

@(tag = "node_proc")
graph_get_any_extra_node :: #force_inline proc(
	graph: ^Graph,
	node: ^Node,
) -> any {
	return {&node.extra, graph.node_extra_types[node.rtype]}
}

@(tag = "node_proc")
graph_has_flag_node :: #force_inline proc(
	graph: ^Graph,
	node: ^Node,
	flag: Class_Flag,
) -> bool {
	return flag in graph.node_flags[node.rtype]
}

graph_display :: proc(
	sb: ^strings.Builder,
	graph: ^Graph,
	ctx: ^Graph_Schedule = nil,
	regs: []Reg = {},
) {
	if ctx != nil {
		for bb in ctx.bbs {
			graph_display_node(sb, graph, bb.head)
			append(&sb.buf, " {\n")

			for instr in bb.instrs {
				append(&sb.buf, "  ")
				instr_node := graph_get(graph, instr)
				if len(regs) != 0 {
					if instr_node.dt != .Void {
						reg := regs[instr_node.gvn]
						fmt.sbprintf(
							sb,
							"%v%03i",
							reg_kind_char(reg.kind),
							reg.index,
						)
					} else {
						append(&sb.buf, "    ")
					}
				}
				graph_display_node(sb, graph, instr)
				append(&sb.buf, "\n")
			}

			append(&sb.buf, "}")
		}
	}
}

graph_display_node :: proc(sb: ^strings.Builder, graph: ^Graph, id: Node_ID) {
	node := graph_get(graph, id)

	extra := graph_get_extra(graph, node)

	graph_display_node_gvn(sb, node.gvn)
	fmt.sbprintf(sb, " := %v(", graph.node_kind_name[node.rtype])

	written_one: bool
	graph_display_extra(sb, extra, "", &written_one)

	for inp, i in graph_inputs(graph, node) {
		inode := graph_get(graph, inp)
		if written_one do fmt.sbprintf(sb, ", ")
		written_one = true
		graph_display_node_gvn(sb, inode.gvn)
	}
	append(&sb.buf, ") [")
	for out, i in graph_outputs(graph, node) {
		onode := graph_get(graph, out.id)
		if i != 0 do append(&sb.buf, ", ")
		graph_display_node_gvn(sb, onode.gvn)
		fmt.sbprintf(sb, ":%v", out.idx)
	}
	append(&sb.buf, "]")
}

graph_display_extra :: proc(
	sb: ^strings.Builder,
	extra: any,
	name: string,
	written_one: ^bool,
) {
	#partial switch info in
		type_info_of(reflect.typeid_base(extra.id)).variant {
	case runtime.Type_Info_Struct:
		for field in reflect.struct_fields_zipped(extra.id) {
			extra := reflect.struct_field_value(extra, field)
			graph_display_extra(sb, extra, field.name, written_one)
			if .raw_union in info.flags do break
		}
		return
	}

	if written_one^ do append(&sb.buf, ", ")
	written_one^ = true
	if name != "" {
		fmt.sbprintf(sb, "%v: ", name)
	}
	fmt.sbprint(sb, extra)
}

graph_display_node_gvn :: proc(sb: ^strings.Builder, gvn: u32) {
	if .Terminal_Color in context.logger.options {
		colors := [?]string {
			ansi.FG_BRIGHT_RED,
			ansi.FG_BRIGHT_GREEN,
			ansi.FG_BRIGHT_YELLOW,
			ansi.FG_BRIGHT_BLUE,
			ansi.FG_BRIGHT_MAGENTA,
			ansi.FG_BRIGHT_CYAN,
			ansi.FG_BRIGHT_WHITE,
			ansi.FG_RED,
			ansi.FG_GREEN,
			ansi.FG_YELLOW,
			ansi.FG_BLUE,
			ansi.FG_MAGENTA,
			ansi.FG_CYAN,
			ansi.FG_WHITE,
		}
		append(&sb.buf, ansi.CSI)
		append(&sb.buf, colors[gvn % len(colors)])
		append(&sb.buf, ansi.SGR)
	}

	fmt.sbprintf(sb, "#%v", gvn)

	if .Terminal_Color in context.logger.options {
		append(&sb.buf, ansi.CSI + ansi.RESET + ansi.SGR)
	}
}
