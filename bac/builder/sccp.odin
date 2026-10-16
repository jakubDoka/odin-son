package builder

import bac ".."
import "base:intrinsics"
import "core:math"

fold_bin_op_lattice :: proc(
	lhs: bac.Lattice,
	op: Bin_Op,
	rhs: bac.Lattice,
	op_ty: bac.Node_Datatype,
) -> (
	res: bac.Lattice,
) {
	if lhs.type == .Top || rhs.type == .Top do return {}
	comparison := op >= .Eq && op <= .U_Ge
	res = bac.DT_TO_LATTICE[op_ty]
	if comparison do res = {
		meta = {type = .Int},
		min = 0,
		max = 1,
	}

	if op_ty in bac.FLOAT_DTS {
		if lhs.type != .Float || rhs.type != .Float do return
		if comparison {
			if lhs.is_nan || rhs.is_nan {
				res.min = i64(op == .Ne)
				res.max = res.min
			}
			return
		}

		res.is_nan = lhs.is_nan || rhs.is_nan
		if res.is_nan {
			res.is_not_ninf = true
			res.is_not_pinf = true
			res.is_not_zero = true
			return
		}
		if !lhs.is_not_nan || !rhs.is_not_nan do return
		lhs_finite := lhs.is_not_ninf && lhs.is_not_pinf
		rhs_finite := rhs.is_not_ninf && rhs.is_not_pinf
		#partial switch op {
		case .Add:
			res.is_not_nan =
				(lhs.is_not_ninf || rhs.is_not_pinf) &&
				(lhs.is_not_pinf || rhs.is_not_ninf)
		case .Sub:
			res.is_not_nan =
				(lhs.is_not_ninf || rhs.is_not_ninf) &&
				(lhs.is_not_pinf || rhs.is_not_pinf)
		case .Mul:
			res.is_not_nan =
				(lhs_finite || rhs.is_not_zero) &&
				(rhs_finite || lhs.is_not_zero)
		case .Div:
			res.is_not_nan =
				(lhs.is_not_zero || rhs.is_not_zero) &&
				(lhs_finite || rhs_finite)
		}
		// Finite operands can still overflow to infinity or underflow to zero.
		return
	}

	if op_ty not_in bac.INT_DTS do return
	if lhs.type != .Int || rhs.type != .Int do return
	full := bac.DT_TO_LATTICE[op_ty]
	bits := u64(bac.DT_SIZE[op_ty] * 8)
	mask := ~u64(0) >> (64 - bits)
	a, b := lhs, rhs
	#partial switch op {
	case .Div, .Rem, .U_Div, .U_Rem:
		// These exceptions trap on some targets, even when the mathematical remainder is zero.
		if b.min <= 0 && b.max >= 0 do return
		if (op == .Div || op == .Rem) &&
		   a.min <= full.min &&
		   b.min <= -1 &&
		   b.max >= -1 {
			return
		}
	}

	if a.min == a.max && b.min == b.max {
		l, r := sext(a.min, op_ty), b.min
		if op != .Shl && op != .Shr && op != .U_Shr do r = sext(r, op_ty)
		#partial switch op {
		case .U_Div, .U_Rem, .U_Shr, .U_Lt, .U_Le, .U_Gt, .U_Ge:
			l = i64(u64(l) & mask)
			if op != .U_Shr do r = i64(u64(r) & mask)
		}
		#partial switch op {
		case .Div, .Rem, .U_Div, .U_Rem:
			if r == 0 do return
			if (op == .Div || op == .Rem) && l == full.min && r == -1 do return
		}
		value := fold_bin_op(l, op, r, op_ty)
		if !comparison do value = sext(value, op_ty)
		return {type = .Int, min = value, max = value}
	}

	lo, hi: i128
	amin, amax := i128(a.min), i128(a.max)
	bmin, bmax := i128(b.min), i128(b.max)
	unsigned := false
	#partial switch op {
	case .U_Div, .U_Rem, .U_Lt, .U_Le, .U_Gt, .U_Ge, .U_Shr:
		unsigned = true
		amin, amax = unsigned_bounds(a, mask)
		if op != .U_Shr do bmin, bmax = unsigned_bounds(b, mask)
	}

	switch op {
	case .Add:
		lo, hi = amin + bmin, amax + bmax
	case .Sub:
		lo, hi = amin - bmax, amax - bmin
	case .Mul:
		products := [4]i128{amin * bmin, amin * bmax, amax * bmin, amax * bmax}
		lo, hi = products[0], products[0]
		for v in products[1:] do lo, hi = min(lo, v), max(hi, v)
	case .Div, .U_Div:
		if bmin <= 0 && bmax >= 0 do return
		quotients := [4]i128 {
			amin / bmin,
			amin / bmax,
			amax / bmin,
			amax / bmax,
		}
		lo, hi = quotients[0], quotients[0]
		for v in quotients[1:] do lo, hi = min(lo, v), max(hi, v)
	case .Rem, .U_Rem:
		if bmin <= 0 && bmax >= 0 do return
		magnitude := max(abs(bmin), abs(bmax)) - 1
		lo = max(amin, -magnitude) if amin < 0 else 0
		hi = min(amax, magnitude) if amax > 0 else 0
	case .Eq, .Ne:
		if amax < bmin || bmax < amin {
			lo = i128(op == .Ne)
			hi = lo
		} else {
			lo, hi = 0, 1
		}
	case .Lt, .U_Lt:
		lo, hi = i128(amax < bmin), i128(amin < bmax)
	case .Le, .U_Le:
		lo, hi = i128(amax <= bmin), i128(amin <= bmax)
	case .Gt, .U_Gt:
		lo, hi = i128(amin > bmax), i128(amax > bmin)
	case .Ge, .U_Ge:
		lo, hi = i128(amin >= bmax), i128(amax >= bmin)
	case .Shl, .Shr, .U_Shr:
		if b.max < 0 || b.min >= i64(bits) {
			if op != .Shr do return {meta = {type = .Int}, min = 0, max = 0}
			lo, hi = i128(a.min >> (bits - 1)), i128(a.max >> (bits - 1))
			break
		}
		if b.min < 0 do return
		smin, smax := u64(b.min), min(u64(b.max), bits - 1)
		if op == .Shl {
			values := [4]i128 {
				amin << smin,
				amin << smax,
				amax << smin,
				amax << smax,
			}
			lo, hi = values[0], values[0]
			for v in values[1:] do lo, hi = min(lo, v), max(hi, v)
		} else {
			values := [4]i128 {
				amin >> smin,
				amin >> smax,
				amax >> smin,
				amax >> smax,
			}
			lo, hi = values[0], values[0]
			for v in values[1:] do lo, hi = min(lo, v), max(hi, v)
		}
		if op != .Shr && b.max >= i64(bits) do lo, hi = min(lo, 0), max(hi, 0)
	case .And, .Or, .Xor, .And_Not:
		aone, apossible := known_bits(a, mask)
		bone, bpossible := known_bits(b, mask)
		one, possible: u64
		#partial switch op {
		case .And:
			one, possible = aone & bone, apossible & bpossible
		case .Or:
			one, possible = aone | bone, apossible | bpossible
		case .Xor:
			one = (aone &~ bpossible) | (bone &~ apossible)
			possible = (apossible &~ bone) | (bpossible &~ aone)
		case .And_Not:
			one, possible = aone &~ bpossible, apossible &~ bone
		}
		sign := u64(1) << (bits - 1)
		if possible & sign != 0 && one & sign == 0 {
			return {
				type = .Int,
				min = sext(i64(one | sign), op_ty),
				max = i64(possible &~ sign),
			}
		}
		return {
			type = .Int,
			min = sext(i64(one), op_ty),
			max = sext(i64(possible), op_ty),
		}
	}

	if comparison do return {type = .Int, min = i64(lo), max = i64(hi)}
	if unsigned {
		sign := i128(1) << (bits - 1)
		if lo < sign && hi >= sign do return full
		return {
			type = .Int,
			min = sext(i64(lo), op_ty),
			max = sext(i64(hi), op_ty),
		}
	}
	if lo < i128(full.min) || hi > i128(full.max) do return full
	return {type = .Int, min = i64(lo), max = i64(hi)}

	unsigned_bounds :: proc(v: bac.Lattice, mask: u64) -> (lo, hi: i128) {
		if v.min < 0 && v.max >= 0 do return 0, i128(mask)
		return i128(u64(v.min) & mask), i128(u64(v.max) & mask)
	}

	known_bits :: proc(v: bac.Lattice, mask: u64) -> (one, possible: u64) {
		varying := (u64(v.min) ~ u64(v.max)) & mask
		if varying != 0 do varying = ~u64(0) >> intrinsics.count_leading_zeros(varying)
		one = u64(v.min) &~ varying & mask
		possible = one | varying
		return
	}
}

sccp_compute :: proc(
	ctx: ^bac.Proc,
	node: bac.Expanded_Node,
) -> (
	res: bac.Lattice,
) {
	id := bac.get_node_id(ctx, node)
	curr := ctx.lattices[node.gvn]

	FORWARD_EXCEPTIONS :: bit_set[bac.Node_Type]{.Nil, .Region, .Entry}

	if bac.is_cfg(ctx, id) && node.itype not_in FORWARD_EXCEPTIONS {
		res = get_lattice(ctx, node.inps[0])
		if res.dead {
			return
		}
	}

	#partial switch node.itype {
	case .Nil:
		return {meta = {type = .Ctlr, dead = true}}
	case .CInt:
		cint := bac.get_extra(ctx, node, bac.CInt)
		if node.dt in bac.FLOAT_DTS {
			value := cint.fvalue
			if node.dt == .F32 do value = f64(f32(value))
			res = {
				type        = .Float,
				is_not_nan  = !math.is_nan(value),
				is_not_pinf = !math.is_inf(value) || value < 0,
				is_not_ninf = !math.is_inf(value) || value > 0,
				is_not_zero = value != 0,
				is_nan      = math.is_nan(value),
			}
		} else if node.dt in bac.INT_DTS {
			res = {
				type = .Int,
				min  = sext(cint.value, node.dt),
				max  = sext(cint.value, node.dt),
			}
		}
	case .Add ..= .And_Not:
		lhs := get_lattice(ctx, node.inps[0])
		rhs := get_lattice(ctx, node.inps[1])

		op := Bin_Op(node.itype)
		op_ty := bac.operation_datatype(ctx, node)
		if node.dt in bac.VECTOR_DTS do break
		res = fold_bin_op_lattice(lhs, op, rhs, op_ty)
		if lhs.type != .Top &&
		   rhs.type != .Top &&
		   node.inps[0] == node.inps[1] &&
		   op >= .Eq &&
		   op <= .U_Ge {
			if op_ty in bac.INT_DTS ||
			   lhs.is_not_nan ||
			   op == .Lt ||
			   op == .Gt {
				value := i64(
					op == .Eq ||
					op == .Le ||
					op == .Ge ||
					op == .U_Le ||
					op == .U_Ge,
				)
				res = {
					type = .Int,
					min  = value,
					max  = value,
				}
			}
		}
		return
	case .Phi:
		if node.inps[0] == 0 do return {}
		ctrl := expand_node(ctx, node.inps[0])
		for inp, i in node.inps[1:] {
			if !get_lattice(ctx, ctrl.inps[i]).dead &&
			   get_lattice(ctx, ctrl.inps[i]).type != .Top {
				res = bac.lattice_meet(res, get_lattice(ctx, inp))
			}

			bac.peep_ctx_add_trigger(ctx, ctrl.inps[i], id)
		}

		res = bac.lattice_join(res, bac.DT_TO_LATTICE[node.dt])
		if res.type == .Int {
			res.widens = curr.widens
			if curr != res {
				res.widens = min(curr.widens + 1, 4)
				if res.widens == 4 {
					res.min = bac.DT_TO_LATTICE[node.dt].min
					res.max = bac.DT_TO_LATTICE[node.dt].max
				}
			}
		}

		return
	case .Mem:
		res.type = .Mem
	case .Entry:
		res.type = .Ctlr
	case .Then, .Else:
		if res.type != .Ctlr {
			return
		}

		the_if := expand_node(ctx, node.inps[0])
		cond := get_lattice(ctx, the_if.inps[1])

		res.type = .Ctlr

		if cond.type != .Bot {
			bac.peep_ctx_add_trigger(ctx, the_if.inps[1], id)
		}

		if cond.type == .Top {
			res.dead = true
			break
		}

		cond_known := cond.type == .Int && cond.min == cond.max

		if cond_known {
			res.dead = (node.itype == .Else) != (cond.min == 0)
		}
	case .Region:
		res.type = .Ctlr
		res.dead = true
		for inp in node.inps {
			lat := get_lattice(ctx, inp)
			res = bac.lattice_meet(res, lat)
		}
	}

	if !bac.is_cfg(ctx, id) && res.type == .Top {
		res = bac.DT_TO_LATTICE[node.dt]
	}

	return
}
