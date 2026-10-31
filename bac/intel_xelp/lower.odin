package bac_intel_xelp

import bac ".."
import "../../utils/fmt"
import "base:intrinsics"

extract_uniform :: proc(
	prc: ^bac.Proc,
	addr: bac.Expanded_Node,
	dt: bac.Node_Datatype,
	half: u32,
) -> bac.Node_ID {
	offset := bac.get_extra(prc, addr, bac.Tup).idx
	assert(offset % 4 == 0 && offset + half * 4 < GRF_BYTES)
	return bac.add_raw(
		prc,
		"uniform",
		u16(Node_Type.Extract_Lane),
		dt,
		{addr.inps[0]},
		extra = &bac.Tup{offset / 4 + half},
	)
}

split_address :: proc(
	prc: ^bac.Proc,
	id: bac.Node_ID,
) -> (
	lo, hi: bac.Node_ID,
) {
	node := expand_node(prc, id)
	zero := bac.add_c_int(prc, "zero", .I32, 0)
	if node.dt == .I32 do return id, zero
	#partial switch node.itype {
	case .CInt:
		bits := u64(bac.get_extra(prc, node, bac.CInt).value)
		lo = bac.add_c_int(prc, "lo", .I32, i64(u32(bits)))
		hi = bac.add_c_int(prc, "hi", .I32, i64(bits >> 32))
	case .Load:
		addr := expand_node(prc, node.inps[2])
		assert(
			addr.itype == .Uniform_Addr,
			"only uniform pointer loads are supported",
		)
		lo = extract_uniform(prc, addr, .I32, 0)
		hi = extract_uniform(prc, addr, .I32, 1)
	case .Conv, .U_Conv:
		src := node.inps[0]
		assert(get_node(prc, src).dt == .I32)
		hi = zero
		if node.itype == .Conv {
			hi = bac.add_bin_op(
				prc,
				"sign",
				.Shr,
				.I32,
				src,
				bac.add_c_int(prc, "bits", .I32, 31),
			)
		}
		return src, hi
	case .Add:
		al, ah := split_address(prc, node.inps[0])
		bl, bh := split_address(prc, node.inps[1])
		lo = bac.add_bin_op(prc, "addrlo", .Add, .I32, al, bl)
		carry := bac.add_bin_op(prc, "carry", .U_Lt, .I32, lo, al)
		hi = bac.add_bin_op(
			prc,
			"addrhi",
			.Add,
			.I32,
			bac.add_bin_op(prc, "high", .Add, .I32, ah, bh),
			carry,
		)
	case .Mul, .Shl:
		al, ah := split_address(prc, node.inps[0])
		rhs := expand_node(prc, node.inps[1])
		assert(rhs.itype == .CInt, "pointer strides must be constant")
		amount := u64(bac.get_extra(prc, rhs, bac.CInt).value)
		if node.itype == .Mul {
			assert(intrinsics.count_ones(amount) == 1)
			amount = u64(intrinsics.count_trailing_zeros(amount))
		}
		assert(amount < 32)
		if amount == 0 do return al, ah
		shift := bac.add_c_int(prc, "scale", .I32, i64(amount))
		lo = bac.add_bin_op(prc, "offsetlo", .Shl, .I32, al, shift)
		hi = bac.add_bin_op(
			prc,
			"offsethi",
			.Or,
			.I32,
			bac.add_bin_op(prc, "highshift", .Shl, .I32, ah, shift),
			bac.add_bin_op(
				prc,
				"lowshift",
				.U_Shr,
				.I32,
				al,
				bac.add_c_int(prc, "remaining", .I32, i64(32 - amount)),
			),
		)
	case:
		fmt.panicf("unsupported 64-bit GPU address: %v", node)
	}

	return
}
