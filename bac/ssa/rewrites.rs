
r: ([Shl ..= .U_Shr] dt: [I8 ..= I64] vl
    match {
        (CInt {value >= i64(bac.DT_SIZE[r.dt] * 8)} value) => overflow,
        (CInt value) => imm,
        {dt < .I32} => widen,
        shift,
    }) :: match {
    {overflow && r != .Shr} => (CInt value: 0)
    overflow => shsign: (AMD64_Shr dt vl imm: ||{i32(bac.DT_SIZE[r.dt] * 8 - 1)})
    imm => ({r.rtype + BIN_OP_OFFSET} vl imm: ||{i32(value)})
    widen => shnrw: (U_Conv dt shwd: (
        {r.rtype} @work I32 shwdv: ({r.itype == .Shr ? .Conv : .U_Conv} I32 vl)))
    _ => shgrd: (Select @work dt
        shntv: ({r.rtype + BIN_OP_OFFSET} dt vl shift) 
        match {
            {r == .Shr} => (AMD64_Shr dt vl imm: ||{i32(bac.DT_SIZE[r.dt] * 8 - 1)})
            _ => (CInt value: 0)
        }
        shrng: (AMD64_U_Lt @work I8 shift imm: {bac.DT_SIZE[r.dt] * 8}))
}

// dsl: rust
