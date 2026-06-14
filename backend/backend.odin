package backend

import "../vendored/gam/util/arna"
import "base:runtime"
import "core:fmt"
import "core:hash"
import "core:mem"
import "core:reflect"
import "core:simd"
import "core:slice"
import "core:strings"
import "core:terminal/ansi"

when NODE_NAMES {
	PREFIX_SIZE :: size_of(string)
} else {
	PREFIX_SIZE :: 0
}

PRECISION :: size_of(u32)
NODE_START :: Node_ID(4 + PREFIX_SIZE) / 4
NODE_ENTRY ::
	Node_ID(
		4 + PREFIX_SIZE + size_of(Node) + size_of(Cfg_Extra) + PREFIX_SIZE,
	) /
	4
NODE_NAMES :: #config(NODE_NAMES, ODIN_DEBUG)

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
	using codegen:     Codegen_Spec,
}

Class_Flags :: bit_set[Class_Flag;u8]

Class_Flag :: enum {
	Is_Basic_Block_Start,
	Pinnable,
	Interned,
	Comutes,
}

Cfg_Extra :: struct {
	using _: struct #raw_union {
		idepth: u32,
		bb_idx: u32,
	},
}

CInt :: struct #align (4) {
	value: i64,
}

No_Extra :: struct {}

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
		itype: Ideal_Node_Type,
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

Node_Intern_Entry :: struct {
	hash: u8,
	id:   Node_ID,
}

Graph :: struct {
	using node_spec: ^Node_Spec,
	interner:        #soa[]Node_Intern_Entry,
	interner_len:    int,
	mem:             ^arna.Allocator,
	gvn:             u32,
	end:             Node_ID,
	dont_intern:     bool,
}

Intern_Vec :: #simd[16]u8

graph_interner_find :: proc(graph: ^Graph, id: Node_ID) -> (int, u8, bool) {
	assert(mem.is_aligned(graph.interner.hash, align_of(Intern_Vec)))

	needle := u8(graph_node_hash(graph, id))

	for mask, i in mem.slice_data_cast(
		[]Intern_Vec,
		graph.interner.hash[:len(graph.interner)],
	) {
		mask := simd.lanes_eq(mask, Intern_Vec(needle))
		bits := transmute(u16)simd.extract_lsbs(mask)
		for bits != 0 {
			idx :=
				i * size_of(Intern_Vec) + int(simd.count_trailing_zeros(bits))
			bits &= bits - 1

			if graph_node_eq(graph, graph.interner.id[idx], id) {
				return idx, needle, true
			}
		}
	}

	return -1, needle, false
}

graph_intern :: proc(graph: ^Graph, id: Node_ID) -> Node_ID {
	if .Interned not_in graph.node_flags[graph_get(graph, id).itype] ||
	   graph.dont_intern {
		return id
	}

	idx, hash, _ := graph_interner_find(graph, id)
	if idx >= 0 do return graph.interner.id[idx]

	if len(graph.interner) == graph.interner_len {
		new_cap := len(graph.interner) * 2 + size_of(Intern_Vec)
		hashes := arna.alloc(graph.mem, uint(new_cap), align_of(Intern_Vec))
		nodes := arna.smake(graph.mem, []Node_ID, new_cap)

		mem.copy_non_overlapping(
			raw_data(hashes),
			graph.interner.hash,
			graph.interner_len,
		)
		mem.copy_non_overlapping(
			raw_data(nodes),
			graph.interner.id,
			graph.interner_len,
		)

		graph.interner.hash = raw_data(hashes)
		graph.interner.id = raw_data(nodes)
		raw_soa_footer_slice(&graph.interner).len = new_cap
	}

	graph.interner[graph.interner_len] = {
		hash = hash,
		id   = id,
	}
	graph.interner_len += 1

	return id
}

graph_unintern :: proc(graph: ^Graph, id: Node_ID) {
	if .Interned in graph.node_flags[graph_get(graph, id).itype] &&
	   !graph.dont_intern {
		idx, _, _ := graph_interner_find(graph, id)
		if idx < 0 do return
		graph.interner_len -= 1
		graph.interner[idx] = graph.interner[graph.interner_len]
		graph.interner[graph.interner_len] = {}
	}
}

graph_node_eq :: proc(graph: ^Graph, a, b: Node_ID) -> bool {
	if a == b do return true

	an, bn := graph_get(graph, a), graph_get(graph, b)
	if an.rtype != bn.rtype do return false
	if an.dt != bn.dt do return false

	if !slice.equal(graph_inputs(graph, an), graph_inputs(graph, bn)) {
		return false
	}

	ad := graph_extra_dwords(graph, an)
	bd := graph_extra_dwords(graph, bn)
	if !slice.equal(ad, bd) do return false

	return true
}

graph_set_input :: proc(
	graph: ^Graph,
	id: Node_ID,
	#any_int idx: int,
	value: Node_ID,
) -> Node_ID {
	node := graph_get(graph, id)

	value_node := graph_get(graph, value)
	value_outputs := graph_outputs(graph, value_node)
	inputs := graph_inputs(graph, node)
	assert(inputs[idx] != 0)

	current_value := graph_get(graph, inputs[idx])
	current_value_outputs := graph_outputs(graph, current_value)
	out_idx, _ := slice.linear_search(
		current_value_outputs,
		Node_Output{id = id, idx = u8(idx)},
	)
	current_value_outputs[out_idx] =
		current_value_outputs[len(current_value_outputs) - 1]
	current_value.output_count -= 1

	graph_add_output(graph, value, id, idx)

	graph_unintern(graph, id)
	inputs[idx] = value
	return graph_intern(graph, id)
}

@(tag = "node_proc")
graph_node_hash_node :: proc(graph: ^Graph, node: ^Node) -> (hash: u32) {
	type := u32(node.rtype)
	dt := u32(node.dt)
	extra_dwords := graph_extra_dwords(graph, node)
	inputs := graph_inputs(graph, node)

	hash += type + dt
	for n in extra_dwords do hash += n
	for n in inputs do hash += u32(n)

	hash_u32 :: proc(x: u32) -> u32 {
		h := x

		h ~= h >> 16
		h *= 0x85eb_ca6b
		h ~= h >> 13
		h *= 0xc2b2_ae35
		h ~= h >> 16

		return h
	}

	hash = hash_u32(hash)

	return
}

@(tag = "node_proc")
graph_extra_dwords_node :: proc(graph: ^Graph, node: ^Node) -> []u32 {
	extra := graph_extra(graph, node)
	return mem.slice_data_cast([]u32, reflect.as_bytes(extra))
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

graph_get_next_extra_slot :: proc(graph: ^Graph, type: u16) -> [^]u32 {
	size := size_of(Node) + int(graph.node_extra_sizes[type]) * PRECISION
	slot := arna.alloc(graph.mem, uint(size), PRECISION)
	graph.mem.pos -= uint(len(slot))

	return auto_cast raw_data(slot)[size_of(Node):]
}

@(disabled = !NODE_NAMES)
push_node_name :: proc(graph: ^Graph, name: string) {
	slot := arna.alloc(graph.mem, size_of(string), 4)
	copy(slot, reflect.as_bytes(name))
}

@(disabled = !NODE_NAMES)
graph_set_name :: proc(graph: ^Graph, node: Node_ID, name: string) {
	copy(
		graph.mem.ptr[int(node) * PRECISION - PREFIX_SIZE:][:PREFIX_SIZE],
		reflect.as_bytes(name),
	)
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
	slot := arna.alloc(graph.mem, uint(size), PRECISION)

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
		graph.mem,
		uint(len(inputs) * PRECISION),
		PRECISION,
	)
	copy(mem.slice_data_cast([]Node_ID, new_inputs), inputs)

	inode := graph_intern(graph, id)
	if inode != id {
		graph.mem.pos = uint(id) * PRECISION
		return inode
	}

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
		slot := arna.alloc(graph.mem, uint(new_cap * PRECISION), PRECISION)
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

graph_extra :: proc {
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

	extra := graph_extra(graph, node)

	graph_display_node_gvn(sb, graph, id)
	fmt.sbprintf(sb, " := %v(", graph.node_kind_name[node.rtype])

	written_one: bool
	graph_display_extra(sb, extra, "", &written_one)

	for inp, i in graph_inputs(graph, node) {
		inode := graph_get(graph, inp)
		if written_one do fmt.sbprintf(sb, ", ")
		written_one = true
		graph_display_node_gvn(sb, graph, inp)
	}
	append(&sb.buf, ") [")
	for out, i in graph_outputs(graph, node) {
		onode := graph_get(graph, out.id)
		if i != 0 do append(&sb.buf, ", ")
		graph_display_node_gvn(sb, graph, out.id)
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

ansi_start :: proc(sb: ^strings.Builder, #any_int gvn: int) {
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
}

ansi_end :: proc(sb: ^strings.Builder) {
	if .Terminal_Color in context.logger.options {
		append(&sb.buf, ansi.CSI + ansi.RESET + ansi.SGR)
	}
}

graph_display_node_gvn :: proc(
	sb: ^strings.Builder,
	graph: ^Graph,
	id: Node_ID,
) {
	gvn := graph_get(graph, id).gvn

	ansi_start(sb, gvn)

	name := ""
	when NODE_NAMES {
		copy(
			reflect.as_bytes(name),
			graph.mem.ptr[int(id) * PRECISION - PREFIX_SIZE:][:PREFIX_SIZE],
		)
	}

	fmt.sbprintf(sb, "#%v%v", gvn, name)

	ansi_end(sb)
}
