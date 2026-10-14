package bac

import "../vendored/gam/util/arna"
import "core:fmt"
import "core:slice"

Sccp_Output :: struct {
	lattices: []Lattice,
}

Sccp_Lattice_Kind :: enum int {
	Top,
	Int,
	Float,
	Ctlr,
	Mem,
	Bot,
}

Lattice :: struct {
	type:       Sccp_Lattice_Kind,
	widens:     i64,
	min, max:   i64,
	is_not_nan: bool,
	dead:       bool,
	checksum:   u32,
}

get_lattice :: proc(ctx: ^Proc, node: Node_ID) -> Lattice {
	if .Sccp not_in ctx.computed_passes do return {}
	idx := get_node(ctx, node)
	return slice.get(ctx.lattices, int(idx.gvn)) or_else {}
}

lattice_meet :: proc(a, b: Lattice) -> (res: Lattice) {
	if a.type == .Top || b.type == .Bot do return b
	if b.type == .Top || a.type == .Bot do return a

	if a.type != b.type {
		res.type = .Bot
		return
	}

	res.widens = max(a.widens, b.widens)

	res.type = a.type

	switch a.type {
	case .Mem:
	case .Int:
		res.min = min(a.min, b.min)
		res.max = max(a.max, b.max)
	case .Float:
		res.is_not_nan = a.is_not_nan & b.is_not_nan
	case .Ctlr:
		res.dead = a.dead & b.dead
	case .Bot, .Top:
		panic("should not reach")
	case:
		fmt.panicf("Unhandled type: %v", a.type)
	}

	return
}

lattice_dual :: proc(v: Lattice) -> (res: Lattice) {
	res = v

	switch v.type {
	case .Top:
		res.type = .Bot
	case .Mem:
	case .Int:
		res.min, res.max = res.max, res.min
	case .Float:
		res.is_not_nan ~= true
	case .Ctlr:
		res.dead ~= true
	case .Bot:
		res.type = .Top
	}

	return
}

lattice_join :: proc(a: Lattice, b: Lattice) -> Lattice {
	return lattice_dual(lattice_meet(lattice_dual(a), lattice_dual(b)))
}

compute_latices :: proc(
	ctx: ^Proc,
	scratch := context.allocator,
) -> (
	optimized: bool,
) {
	{return}

	if ctx.sccp_compute == nil do return

	pass_quard(ctx, .Sccp, &optimized) or_return

	if .Sccp not_in ctx.opt_flags && false do return

	context.allocator, _ = arna.scrath(scratch)

	worklist: Worklist
	triggers: [dynamic][dynamic]Node_ID
	ctx.worklist = &worklist
	ctx.triggers = &triggers

	worklist_init(ctx.worklist, ctx.gvn)
	collect_nodes(ctx, ctx.worklist)

	ctx.lattices = make([]Lattice, ctx.gvn, scratch)

	for n in worklist_next(ctx, ctx.worklist) {
		node := expand_node(ctx, n)
		lat := ctx.sccp_compute(ctx, node)
		if lat.type != .Top && ctx.lattices[node.gvn] != lat {
			optimized = true
			ctx.lattices[node.gvn] = lat
			for out in node.outs {
				worklist_add(ctx, &worklist, out.id)
			}
			peep_ctx_flush_triggers(ctx, node)
		}
	}

	ctx.worklist = nil
	ctx.triggers = nil

	return
}
