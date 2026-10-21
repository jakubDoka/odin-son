package bac_intel_xelp

import bac ".."

icon :: proc(p: ^bac.Proc, v: u32) -> bac.Node_ID {return bac.add_c_int(p, "div", .I32, i64(v))}
iop :: proc(p: ^bac.Proc, op: bac.Bin_Op, a, b: bac.Node_ID) -> bac.Node_ID {
	if op == .Sub do return iop(p, .Add, a, ineg(p, b))
	return bac.add_bin_op(p, "div", op, .I32, a, b)
}
ineg :: proc(p: ^bac.Proc, a: bac.Node_ID) -> bac.Node_ID {return iop(p, .Add, iop(p, .Xor, a, icon(p, 0xffff_ffff)), icon(p, 1))}
izero :: proc(p: ^bac.Proc, a: bac.Node_ID) -> bac.Node_ID {
	nonzero := iop(p, .U_Shr, iop(p, .Or, a, ineg(p, a)), icon(p, 31))
	return iop(p, .Add, nonzero, icon(p, 0xffff_ffff))
}
ilt :: proc(p: ^bac.Proc, a, b: bac.Node_ID) -> bac.Node_ID {
	return ineg(p, iop(p, .U_Shr, iop(p, .Sub, a, b), icon(p, 31)))
}
iselect :: proc(p: ^bac.Proc, mask, a, b: bac.Node_ID) -> bac.Node_ID {
	return iop(p, .Xor, b, iop(p, .And, mask, iop(p, .Xor, a, b)))
}

// Integer restoring division avoids a reciprocal approximation and its
// overflow, subnormal, and double-rounding failures. All temporaries are
// graph values, so the shared allocator owns every GRF used by this expansion.
lower_div :: proc(p: ^bac.Proc, numerator, denominator: bac.Node_ID) -> bac.Node_ID {
	z, one, all := icon(p, 0), icon(p, 1), icon(p, 0xffff_ffff)
	hi := icon(p, 0x0080_0000)
	n := bac.add_un_op(p, "div-bits", .Cast, .I32, numerator)
	d := bac.add_un_op(p, "div-bits", .Cast, .I32, denominator)
	ne := iop(p, .And, iop(p, .U_Shr, n, icon(p, 23)), icon(p, 255))
	de := iop(p, .And, iop(p, .U_Shr, d, icon(p, 23)), icon(p, 255))
	nf := iop(p, .And, n, icon(p, 0x007f_ffff))
	df := iop(p, .And, d, icon(p, 0x007f_ffff))
	nz := izero(p, iop(p, .And, n, icon(p, 0x7fff_ffff)))
	dz := izero(p, iop(p, .And, d, icon(p, 0x7fff_ffff)))
	nmax := izero(p, iop(p, .Xor, ne, icon(p, 255)))
	dmax := izero(p, iop(p, .Xor, de, icon(p, 255)))
	ninf := iop(p, .And, nmax, izero(p, nf))
	dinf := iop(p, .And, dmax, izero(p, df))
	invalid := iop(p, .Or, iop(p, .And, nz, dz), iop(p, .And, ninf, dinf))
	invalid = iop(p, .Or, invalid, iop(p, .And, nmax, iop(p, .Xor, izero(p, nf), all)))
	invalid = iop(p, .Or, invalid, iop(p, .And, dmax, iop(p, .Xor, izero(p, df), all)))
	na, da := nf, df
	for pair in 0 ..< 2 {
		e := pair == 0 ? ne : de
		f := pair == 0 ? nf : df
		empty := izero(p, e)
		m := iop(p, .Or, f, iop(p, .And, iop(p, .Xor, empty, all), hi))
		e = iselect(p, empty, one, e)
		for shift in ([5]u32{16, 8, 4, 2, 1}) {
			mask := izero(p, iop(p, .U_Shr, m, icon(p, 24-shift)))
			m = iselect(p, mask, iop(p, .Shl, m, icon(p, shift)), m)
			e = iop(p, .Sub, e, iop(p, .And, mask, icon(p, shift)))
		}
		if pair == 0 {na = m; ne = e} else {da = m; de = e}
	}
	exponent := iop(p, .Add, iop(p, .Sub, ne, de), icon(p, 127))
	less := ilt(p, na, da)
	na = iselect(p, less, iop(p, .Shl, na, one), na)
	exponent = iop(p, .Sub, exponent, iop(p, .And, less, one))
	remainder := iop(p, .Sub, na, da)
	quotient := hi
	for bit := 22; bit >= 0; bit -= 1 {
		remainder = iop(p, .Shl, remainder, one)
		ge := iop(p, .Xor, ilt(p, remainder, da), all)
		remainder = iop(p, .Sub, remainder, iop(p, .And, da, ge))
		quotient = iop(p, .Or, quotient, iop(p, .And, ge, icon(p, u32(1) << uint(bit))))
	}
	normal := ilt(p, z, exponent)
	k := iop(p, .And, iop(p, .Sub, one, exponent), iop(p, .Xor, normal, all))
	k = iselect(p, ilt(p, icon(p, 24), k), icon(p, 24), k)
	truncated := iop(p, .U_Shr, quotient, k)
	lost := iop(p, .And, quotient, iop(p, .Sub, iop(p, .Shl, one, k), one))
	guard := iop(p, .Shl, one, iop(p, .Sub, k, one))
	twice := iop(p, .Shl, remainder, one)
	more := iselect(p, normal, ilt(p, da, twice), ilt(p, guard, lost))
	tie := iselect(p, normal, izero(p, iop(p, .Xor, da, twice)), izero(p, iop(p, .Xor, guard, lost)))
	sticky := iop(p, .Or, iop(p, .And, truncated, one), iselect(p, normal, z, remainder))
	round := iop(p, .And, iop(p, .Or, more, iop(p, .And, tie, iop(p, .Xor, izero(p, sticky), all))), one)
	rounded := iop(p, .Add, truncated, round)
	packed := iop(p, .Add, iop(p, .Shl, exponent, icon(p, 23)), iop(p, .Sub, rounded, hi))
	result := iselect(p, normal, packed, rounded)
	result = iselect(p, ilt(p, icon(p, 254), exponent), icon(p, 0x7f80_0000), result)
	result = iselect(p, ilt(p, exponent, icon(p, transmute(u32)i32(-23))), z, result)
	result = iselect(p, dz, icon(p, 0x7f80_0000), result)
	result = iselect(p, iop(p, .Or, nz, dinf), z, result)
	result = iselect(p, ninf, icon(p, 0x7f80_0000), result)
	result = iop(p, .Or, result, iop(p, .And, iop(p, .Xor, n, d), icon(p, 0x8000_0000)))
	result = iselect(p, invalid, icon(p, 0x7fc0_0000), result)
	return bac.add_un_op(p, "div-value", .Cast, .F32, result)
}
