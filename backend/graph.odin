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
	Builder,
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
	Immortal,
}

Cfg_Extra :: struct {
	using _: struct #raw_union {
		idepth: u32,
		bb_idx: u32,
	},
}

Region :: struct {
	using base: Cfg_Extra,
}

Scope :: struct #align (4) {
	done: bool,
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
	id:  Node_ID | 22,
	idx: int     | 10,
}

Node :: struct {
	using _:             struct #raw_union {
		itype: Ideal_Node_Type,
		btype: Builder_Node_Type,
		xtype: X64_Node_Type,
		rtype: u16,
	},
	using _:             bit_field u8 {
		dt: Node_Datatype | 8,
	},
	user_idx:            u8,
	gvn:                 u32,
	input_idx:           u32,
	ordered_input_count: u16,
	input_count:         u16,
	output_idx:          u32,
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
	using node_spec:        ^Node_Spec,
	interner:               #soa[]Node_Intern_Entry,
	interner_len:           int,
	mem:                    ^arna.Allocator,
	gvn:                    u32,
	end:                    Node_ID,
	dont_intern:            bool,
	// TODO: somehow comment this out on release, idk how
	is_in_transition_state: bool,
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
	assert(!graph.is_in_transition_state)

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
	assert(!graph.is_in_transition_state)

	if .Interned in graph.node_flags[graph_get(graph, id).itype] &&
	   !graph.dont_intern {
		idx, _, _ := graph_interner_find(graph, id)
		if idx < 0 do return
		graph.interner_len -= 1
		graph.interner[idx] = graph.interner[graph.interner_len]
		graph.interner[graph.interner_len] = {}
	}
}

graph_subsume :: proc(graph: ^Graph, with: Node_ID, target: Node_ID) {
	// TODO: explain this to AI and try to make it find bugs here

	wnode := graph_expand(graph, with)
	tnode := graph_expand(graph, target)

	graph_ensure_available_output_cap(graph, wnode, tnode.output_count)

	wnode.output_count += tnode.output_count
	tnode.output_count = 0

	wnode = graph_expand(graph, with)
	copy(wnode.outs[len(wnode.outs) - len(tnode.outs):], tnode.outs)

	for out in tnode.outs {
		graph_unintern(graph, out.id)
		graph_inps(graph, out.id)[out.idx] = with
	}
	graph_delete(graph, tnode)

	wnode = graph_expand(graph, with)

	keep := 0
	for out in tnode.outs {
		for oout in wnode.outs {
			if out == oout {
				tnode.outs[keep] = out
				keep += 1
			}
		}
	}
	tnode.outs = tnode.outs[:keep]

	for out in tnode.outs {
		graph_intern(graph, out.id)
	}
}

graph_node_eq :: proc(graph: ^Graph, a, b: Node_ID) -> bool {
	if a == b do return true

	an, bn := graph_get(graph, a), graph_get(graph, b)
	if an.rtype != bn.rtype do return false
	if an.dt != bn.dt do return false

	if !slice.equal(graph_inps(graph, an), graph_inps(graph, bn)) {
		return false
	}

	ad := graph_extra_dwords(graph, an)
	bd := graph_extra_dwords(graph, bn)
	if !slice.equal(ad, bd) do return false

	return true
}

graph_get_scope_value :: proc(
	graph: ^Graph,
	scope: Node_ID,
	#any_int idx: int,
) -> Node_ID {
	scope_node := graph_get(graph, scope)
	assert(scope_node.btype == .Scope)

	val := graph_inps(graph, scope_node)[idx]
	vnode := graph_expand(graph, val)
	if vnode.btype == .Scope {
		pval := val
		val = graph_get_scope_value(graph, val, idx)
		cvnode := graph_expand(graph, val)
		if cvnode.btype != .Lazy_Phi || vnode.inps[0] != cvnode.inps[0] {
			val = graph_add_lazyPhi(
				graph,
				"lphi",
				graph_get(graph, val).dt,
				vnode.inps[0],
				val,
			)
			graph_set_input(graph, pval, idx, val)
		}
		graph_set_input(graph, scope, idx, val)
	}

	return val
}

graph_push_scope_value :: proc(
	graph: ^Graph,
	scope: Node_ID,
	value: Node_ID,
) -> int {
	scope_node := graph_get(graph, scope)
	assert(scope_node.btype == .Scope)

	idx := graph_add_input(graph, scope_node, value, is_scope = true)
	graph_add_output(graph, value, scope, idx)
	return idx
}

graph_truncate_scope :: proc(
	graph: ^Graph,
	scope: Node_ID,
	#any_int to_len: int,
) {
	if scope == 0 do return
	snode := graph_expand(graph, scope)
	assert(snode.btype == .Scope)
	assert(to_len <= int(snode.ordered_input_count))

	for &inp, i in snode.inps[to_len:snode.ordered_input_count] {
		graph_remove_output(graph, inp, {idx = to_len + i, id = scope})
		inp = 0
	}

	snode.ordered_input_count = u16(to_len)
}

graph_merge_scopes :: proc(
	graph: ^Graph,
	lctrl: Node_ID,
	rctrl: Node_ID,
) -> Node_ID {
	if lctrl == 0 do return rctrl
	if rctrl == 0 do return lctrl

	lnode := graph_expand(graph, lctrl)
	assert(lnode.btype == .Scope)
	rnode := graph_expand(graph, rctrl)
	assert(rnode.btype == .Scope)

	assert(lnode.ordered_input_count == rnode.ordered_input_count)

	region := graph_add_region(graph, "reg", lnode.inps[0], rnode.inps[0])

	for i in 1 ..< lnode.ordered_input_count {
		if lnode.inps[i] == rnode.inps[i] do continue
		lvalue := graph_get_scope_value(graph, lctrl, i)
		rvalue := graph_get_scope_value(graph, rctrl, i)
		if lvalue == rvalue do continue
		phi := graph_add_phi(
			graph,
			"phi",
			graph_get(graph, lvalue).dt,
			region,
			lvalue,
			rvalue,
		)
		graph_set_input(graph, lctrl, i, phi)
	}

	graph_set_input(graph, lctrl, 0, region)
	graph_delete(graph, rnode)

	return lctrl
}

graph_set_input :: proc(
	graph: ^Graph,
	id: Node_ID,
	#any_int idx: int,
	value: Node_ID,
) -> Node_ID {
	node := graph_expand(graph, id)

	assert(node.inps[idx] != 0)

	graph_remove_output(graph, node.inps[idx], {idx = idx, id = id})

	graph_add_output(graph, value, id, idx)

	graph_unintern(graph, id)
	node.inps[idx] = value
	return graph_intern(graph, id)
}

graph_clone :: proc(graph: ^Graph, id: Node_ID) -> Node_ID {
	node := graph_expand(graph, id)
	graph.dont_intern = true
	idx := graph_get_next_extra_slot(graph, node.rtype)
	extra := graph_extra_dwords(graph, node)
	copy(idx[:len(extra)], extra)
	push_node_name(graph, graph_get_node_name(graph, id))
	new := graph_add_raw(graph, node.rtype, node.dt, node.inps)
	graph_get(graph, new).ordered_input_count = node.ordered_input_count
	graph.dont_intern = false
	return new
}

@(tag = "node_proc")
graph_remove_output_node :: proc(
	graph: ^Graph,
	node: ^Node,
	out: Node_Output,
) {
	outs := graph_outs(graph, node)
	out_idx := slice.linear_search(outs, out) or_else panic("")
	outs[out_idx] = outs[len(outs) - 1]
	node.output_count -= 1
	graph_delete(graph, node, indirect = true)
}

@(tag = "node_proc")
graph_node_hash_node :: proc(graph: ^Graph, node: ^Node) -> (hash: u32) {
	type := u32(node.rtype)
	dt := u32(node.dt)
	extra_dwords := graph_extra_dwords(graph, node)
	inps := graph_inps(graph, node)

	hash += type + dt
	for n in extra_dwords do hash += n
	for n in inps do hash += u32(n)

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

graph_id :: #force_inline proc(graph: ^Graph, node: ^Node) -> Node_ID {
	return Node_ID((uintptr(node) - uintptr(graph.mem.ptr)) / PRECISION)
}

@(tag = "node_proc")
graph_delete_node :: proc(graph: ^Graph, node: ^Node, indirect := false) {
	id := graph_id(graph, node)
	if node.output_count != 0 do return
	if .Immortal in graph.node_flags[node.rtype] && indirect do return

	for inp, i in graph_inps(graph, node) {
		if inp == 0 do continue
		graph_remove_output(graph, inp, {idx = i, id = id})
	}

	graph_unintern(graph, graph_id(graph, node))
	node^ = {}
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

Expanded_Node :: struct {
	using node:   ^Node,
	inps:         []Node_ID,
	outs:         []Node_Output,
	data_start:   int,
	inplace_slot: int,
}

graph_expand :: #force_no_inline proc(
	graph: ^Graph,
	id: Node_ID,
) -> Expanded_Node {
	node := graph_get(graph, id)
	return {
		node,
		graph_inps(graph, node),
		graph_outs(graph, node),
		int(graph.first_input_idxs[node.rtype]),
		int(graph.inplace_slot_idxs[node.rtype]),
	}
}

@(tag = "node_proc")
graph_inps_node :: #force_inline proc(
	graph: ^Graph,
	node: ^Node,
) -> []Node_ID {
	return ([^]Node_ID)(graph.mem.ptr)[node.input_idx:][:node.input_count]
}

@(tag = "node_proc")
graph_outs_node :: #force_inline proc(
	graph: ^Graph,
	node: ^Node,
) -> []Node_Output {
	return(
		([^]Node_Output)(graph.mem.ptr)[node.output_idx:][:node.output_count] \
	)
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
	inps: []Node_ID,
	extra_capacity: int = 0,
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
		input_idx           = u32(graph.mem.pos / PRECISION),
		ordered_input_count = u16(len(inps)),
		input_count         = u16(len(inps)),
	}

	new_inps := arna.alloc(
		graph.mem,
		uint(int(len(inps) + extra_capacity) * PRECISION),
		PRECISION,
		zeroed = ODIN_DEBUG,
	)
	copy(mem.slice_data_cast([]Node_ID, new_inps), inps)

	inode := graph_intern(graph, id)
	if inode != id {
		graph.mem.pos = uint(id) * PRECISION
		return inode
	}

	for inp, i in inps {
		if inp == 0 do continue
		graph_add_output(graph, inp, id, i)
	}

	graph.gvn += 1

	return
}

@(tag = "node_proc")
graph_add_input_node :: proc(
	graph: ^Graph,
	node: ^Node,
	inp: Node_ID,
	is_scope := false,
) -> int {
	assert(is_scope, "TODO")

	free_idx := int(node.ordered_input_count)
	grow: if node.ordered_input_count == node.input_count || !is_scope {
		if !is_scope {
			free_idx, _ = slice.linear_search_reverse(
				graph_inps(graph, node),
				0,
			)
			if free_idx >= 0 do break grow
			free_idx = int(node.input_count)
		}

		base := u32(graph.mem.pos / PRECISION)
		new_cap := node.input_count * 2 + 2
		slot := arna.alloc(
			graph.mem,
			uint(new_cap * PRECISION),
			PRECISION,
			zeroed = !is_scope,
		)
		copy(mem.slice_data_cast([]Node_ID, slot), graph_inps(graph, node))
		node.input_count = new_cap
		node.input_idx = base

	}

	graph_inps(graph, node)[free_idx] = inp
	node.ordered_input_count += u16(is_scope)

	return free_idx
}

@(tag = "node_proc")
graph_add_extra_input_node :: proc(graph: ^Graph, node: ^Node, inp: Node_ID) {
	node.input_count += 1
	node.ordered_input_count += 1
	graph_inps(graph, node)[node.input_count - 1] = inp
	graph_add_output(graph, inp, graph_id(graph, node), node.input_count - 1)
}

graph_ensure_available_output_cap :: proc(
	graph: ^Graph,
	node: ^Node,
	available: u16,
) {
	if node.output_cap - node.output_count < available {
		base := u32(graph.mem.pos / PRECISION)
		new_cap := max(node.output_cap * 2 + 2, node.output_cap + available)
		slot := arna.alloc(graph.mem, uint(new_cap * PRECISION), PRECISION)
		copy(mem.slice_data_cast([]Node_Output, slot), graph_outs(graph, node))
		node.output_cap = new_cap
		node.output_idx = base
	}
}

@(tag = "node_proc")
graph_add_output_node :: proc(
	graph: ^Graph,
	node: ^Node,
	out: Node_ID,
	#any_int i: int,
) {
	graph_ensure_available_output_cap(graph, node, 1)

	node.output_count += 1
	assert(i < 256)
	graph_outs(graph, node)[node.output_count - 1] = {
		id  = out,
		idx = i,
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
	assert(int(node.rtype) < len(graph.inheritance_table))
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
	prefix: proc(_: ^strings.Builder, _: ^Node, _: Graph_Basic_Block) = nil,
	regs: []Reg = {},
) {
	ctx := ctx
	our_ctx: Graph_Schedule

	if ctx == nil {
		graph_schedule(graph, &our_ctx)
		ctx = &our_ctx
	}

	for bb in ctx.bbs {
		graph_display_node(sb, graph, bb.head)

		append(&sb.buf, " {\n")

		for instr in bb.instrs {
			inode := graph_get(graph, instr)
			//if inode.itype == .Phi {
			//	continue
			//}

			append(&sb.buf, "  ")
			if len(regs) != 0 {
				if inode.dt != .Void {
					reg := regs[inode.gvn]
					fmt.sbprintf(
						sb,
						"%v%03i",
						reg_kind_char(reg.kind),
						reg.index,
					)
				} else {
					append(&sb.buf, "    ")
				}
			} else if prefix != nil {
				prefix(sb, inode, bb)
			}
			graph_display_node(sb, graph, instr)
			append(&sb.buf, "\n")
		}

		append(&sb.buf, "}\n")
	}
}

graph_display_node :: proc(sb: ^strings.Builder, graph: ^Graph, id: Node_ID) {
	node := graph_expand(graph, id)

	extra := graph_extra(graph, node)

	graph_display_node_gvn(sb, graph, id)
	fmt.sbprintf(sb, ":%v(", graph.node_kind_name[node.rtype])

	written_one: bool
	graph_display_extra(sb, extra, "", &written_one)

	for inp, i in node.inps {
		inode := graph_get(graph, inp)
		if written_one do fmt.sbprintf(sb, ", ")
		written_one = true
		graph_display_node_gvn(sb, graph, inp)
	}

	if node.itype == .Jump {
		reg := node.outs[0]
		rnode := graph_expand(graph, reg.id)
		for out in rnode.outs {
			onode := graph_expand(graph, out.id)
			if onode.itype == .Phi {
				if written_one do fmt.sbprintf(sb, ", ")
				written_one = true
				graph_display_node_gvn(sb, graph, onode.inps[1 + reg.idx])
			}
		}
	}

	if node.itype == .Region || node.itype == .Loop {
		for out in node.outs {
			onode := graph_get(graph, out.id)
			if onode.itype == .Phi {
				if written_one do fmt.sbprintf(sb, ", ")
				written_one = true
				graph_display_node_gvn(sb, graph, out.id)
			}
		}
	}

	append(&sb.buf, ") [")
	written_one = false
	for out, i in node.outs {
		onode := graph_expand(graph, out.id)
		if onode.itype == .Phi {
			if out.idx != 0 {
				reg := onode.inps[0]
				rnode := graph_expand(graph, reg)
				idx := 0
				for ro in rnode.outs {
					if ro.id == out.id do break
					idx += int(graph_get(graph, ro.id).itype == .Phi)
				}
				if written_one do fmt.sbprintf(sb, ", ")
				written_one = true
				graph_display_node_gvn(sb, graph, rnode.inps[out.idx - 1])
				fmt.sbprintf(sb, ":%v", 1 + idx)
			}
			continue
		}
		if written_one do fmt.sbprintf(sb, ", ")
		written_one = true
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
			{fg = ansi.FG_BRIGHT_WHITE},
			{fg = ansi.FG_RED},
			{fg = ansi.FG_GREEN},
			{fg = ansi.FG_YELLOW},
			{fg = ansi.FG_BLUE},
			{fg = ansi.FG_MAGENTA},
			{fg = ansi.FG_CYAN},
			{fg = ansi.FG_WHITE},
			{fg = ansi.FG_BLACK, bg = ansi.BG_WHITE},
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
			append(&sb.buf, ansi.CSI)
			append(&sb.buf, pick.fg)
			append(&sb.buf, ansi.SGR)
		}

		if pick.bg != "" {
			append(&sb.buf, ansi.CSI)
			append(&sb.buf, pick.bg)
			append(&sb.buf, ansi.SGR)
		}
	}
}

ansi_end :: proc(sb: ^strings.Builder) {
	if .Terminal_Color in context.logger.options {
		append(&sb.buf, ansi.CSI + ansi.RESET + ansi.SGR)
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

graph_display_node_gvn :: proc(
	sb: ^strings.Builder,
	graph: ^Graph,
	id: Node_ID,
) {
	n := graph_get(graph, id)

	ansi_start(sb, n.gvn)

	fmt.sbprintf(sb, "#%v%v", n.gvn, graph_get_node_name(graph, id))

	ansi_end(sb)
}
