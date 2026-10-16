package bac

import "../vendored/gam/util/arna"
import "core:fmt"
import "core:slice"

Sccp_Output :: struct {
	lattices: []Lattice,
}

Lattice_Type :: enum u64 {
	Top,
	Int,
	Float,
	Ctlr,
	Mem,
	Bot,
}

Lattice :: struct {
	min, max:   i64,
	using meta: bit_field u64 {
		type:        Lattice_Type | 4,
		is_not_nan:  bool         | 1,
		is_not_ninf: bool         | 1,
		is_not_pinf: bool         | 1,
		is_not_zero: bool         | 1,
		is_nan:      bool         | 1,
		dead:        bool         | 1,
		widens:      u64          | 3,
	},
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

	res.type = a.type

	switch a.type {
	case .Mem:
	case .Int:
		res.min = min(a.min, b.min)
		res.max = max(a.max, b.max)
	case .Float:
		res.is_not_nan = a.is_not_nan & b.is_not_nan
		res.is_not_ninf = a.is_not_ninf & b.is_not_ninf
		res.is_not_pinf = a.is_not_pinf & b.is_not_pinf
		res.is_not_zero = a.is_not_zero & b.is_not_zero
		res.is_nan = a.is_nan & b.is_nan
	case .Ctlr:
		res.dead = a.dead & b.dead
	case .Bot, .Top:
		panic("should not reach")
	case:
		fmt.panicf("Unhandled type: %v", a.type)
	}

	return
}

@(rodata)
DT_TO_LATTICE := [Node_Datatype]Lattice {
	.I8 = {
		meta = auto_cast Lattice_Type.Int,
		min = i64(min(i8)),
		max = i64(max(i8)),
	},
	.I16 = {
		meta = auto_cast Lattice_Type.Int,
		min = i64(min(i16)),
		max = i64(max(i16)),
	},
	.I32 = {
		meta = auto_cast Lattice_Type.Int,
		min = i64(min(i32)),
		max = i64(max(i32)),
	},
	.I64 = {
		meta = auto_cast Lattice_Type.Int,
		min = i64(min(i64)),
		max = i64(max(i64)),
	},
	.F32 ..=
	.F64 = {meta = auto_cast Lattice_Type.Float},
	.Void ..=
	.Mem = {meta = auto_cast Lattice_Type.Bot},
	.V128 ..=
	.V512 = {meta = auto_cast Lattice_Type.Bot},
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
		res.is_not_ninf ~= true
		res.is_not_pinf ~= true
		res.is_not_zero ~= true
		res.is_nan ~= true
	case .Ctlr:
		res.dead ~= true
	case .Bot:
		res.type = .Top
	}

	return
}

isa :: proc(this, that: Lattice) -> bool {
	that := that
	that.widens = 0
	return lattice_meet(this, that) == that
}

lattice_join :: proc(a, b: Lattice) -> (res: Lattice) {
	res = lattice_dual(lattice_meet(lattice_dual(a), lattice_dual(b)))
	if (res.type == .Int && res.min > res.max) ||
	   (res.type == .Float && res.is_nan && res.is_not_nan) {
		return {}
	}
	return
}

compute_latices :: proc(
	ctx: ^Proc,
	scratch := context.allocator,
) -> (
	optimized: bool,
) {
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
	slice.reverse(ctx.worklist.data[:ctx.worklist.len])

	when false {
		nodes := slice.clone(worklist.queue.data[:worklist.queue.len])
	}

	ctx.lattices = make([]Lattice, ctx.gvn, scratch)
	ctx.lattices[0] = {
		meta = {type = .Ctlr, dead = true},
	}

	for n in worklist_next(ctx, ctx.worklist) {
		node := expand_node(ctx, n)
		lat := ctx.sccp_compute(ctx, node)
		fmt.assertf(
			isa(ctx.lattices[node.gvn], lat),
			"isa(%v, %v) %v",
			ctx.lattices[node.gvn],
			lat,
			node,
		)
		if lat.type != .Top && ctx.lattices[node.gvn] != lat {
			optimized = true
			ctx.lattices[node.gvn] = lat
			for out in node.outs {
				worklist_add(ctx, &worklist, out.id)
			}
			peep_ctx_flush_triggers(ctx, node)
		}
	}

	if !ODIN_DISABLE_ASSERT {
		collect_nodes(ctx, ctx.worklist)

		//slice.reverse(ctx.worklist.data[:ctx.worklist.len])

		for n in worklist_next(ctx, ctx.worklist) {
			node := expand_node(ctx, n)
			lat := ctx.sccp_compute(ctx, node)
			fmt.assertf(
				ctx.lattices[node.gvn] == lat,
				"%v == %v %v",
				ctx.lattices[node.gvn],
				lat,
				node,
			)
		}
	}

	when false {
		for i in 0 ..< len(nodes) {
			fmt.eprintln(get_node(ctx, nodes[i]), ctx.lattices[i])
		}
	}

	ctx.worklist = nil
	ctx.triggers = nil

	return
}
