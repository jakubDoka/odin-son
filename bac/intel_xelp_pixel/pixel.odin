package bac_intel_xelp_pixel

Op_Kind :: enum {A, B, Constant, Add, Sub, Neg, Mul, Eq, Ne, Lt, Le, Gt, Ge, And, Or, Not, Select, Return}
Value_Type :: enum {F32, Bool}
Op :: struct {
    kind: Op_Kind,
    bits: u32,
    inputs: [3]int,
    type: Value_Type,
}

Machine_Op :: struct {
    alu: ALU,
    dst: int,
    inputs: [2]int,
    count: int,
}

Lowering :: struct {
    code: [dynamic]Machine_Op,
    values: int,
}

input_count :: proc(kind: Op_Kind) -> int {
    #partial switch kind {
    case .A, .B, .Constant: return 0
    case .Neg, .Not, .Return: return 1
    case .Select: return 3
    case: return 2
    }
}

lower :: proc(ops: []Op) -> (machine: []Machine_Op, values: int) {
    live := make([]bool, len(ops))
    defer delete(live)
    live[len(ops)-1] = true
    #reverse for op, i in ops {
        if !live[i] do continue
        for n in 0..<input_count(op.kind) do live[op.inputs[n]] = true
    }
    mapping := make([]int, len(ops))
    defer delete(mapping)
    state := Lowering{values = 2, code = make([dynamic]Machine_Op)}
    for op, i in ops {
        if !live[i] do continue
        a, b, c := mapping[op.inputs[0]], mapping[op.inputs[1]], mapping[op.inputs[2]]
        ty := op.type == .F32 ? Data_Type.F32 : Data_Type.U32
        result: int
        switch op.kind {
        case .A: result = 0
        case .B: result = 1
        case .Constant:
            result = add(&state, {op = .Mov, type = ty, src0 = imm(op.bits)})
        case .Add, .Mul, .And, .Or:
            @(static, rodata) OPS := #partial [Op_Kind]Opcode{.Add = .Add, .Mul = .Mul, .And = .And, .Or = .Or}
            result = add(&state, {op = OPS[op.kind], type = ty}, {a, b}, 2)
        case .Sub:
            negated := add(&state, {op = .Xor, type = .U32, src1 = imm(0x80000000)}, {b, 0}, 1)
            result = add(&state, {op = .Add, type = .F32}, {a, negated}, 2)
        case .Neg, .Not:
            bits := op.kind == .Neg ? u32(0x80000000) : u32(1)
            result = add(&state, {op = .Xor, type = .U32, src1 = imm(bits)}, {a, 0}, 1)
        case .Eq, .Ne, .Lt, .Le, .Gt, .Ge:
            @(static, rodata) CONDITIONS := #partial [Op_Kind]Condition{.Eq = .Eq, .Ne = .Ne, .Lt = .Lt, .Le = .Le, .Gt = .Gt, .Ge = .Ge}
            cmp_ty := ops[op.inputs[0]].type == .F32 ? Data_Type.F32 : Data_Type.U32
            mask := add(&state, {op = .Cmp, type = cmp_ty, condition = CONDITIONS[op.kind]}, {a, b}, 2)
            result = add(&state, {op = .And, type = .U32, src1 = imm(1)}, {mask, 0}, 1)
        case .Select:
            append(&state.code, Machine_Op{
                alu = {op = .Cmp, type = .U32, condition = .Ne, src1 = imm(0)},
                dst = -1, inputs = {a, 0}, count = 1,
            })
            result = add(&state, {op = .Sel, type = ty, predicate = .F0}, {b, c}, 2)
        case .Return:
            append(&state.code, Machine_Op{alu = {op = .Mov, type = .U32}, dst = -2, inputs = {a, 0}, count = 1})
        }
        mapping[i] = result
    }
    return state.code[:], state.values
}

add :: proc(state: ^Lowering, alu: ALU, inputs := [2]int{}, count := 0) -> int {
    result := state.values
    state.values += 1
    append(&state.code, Machine_Op{alu = alu, dst = result, inputs = inputs, count = count})
    return result
}

allocate :: proc(machine: []Machine_Op, values: int) -> ([]int, bool) {
    last_use := make([]int, values)
    defer delete(last_use)
    for &n in last_use do n = -1
    for op, i in machine {
        for n in 0..<op.count do last_use[op.inputs[n]] = i
    }
    registers := make([]int, values)
    registers[0], registers[1] = 1, 2
    busy: [112]bool
    for op, i in machine {
        if op.dst >= 0 {
            found := false
            for r in 5..<112 {
                if busy[r] do continue
                registers[op.dst] = r
                busy[r] = true
                found = true
                break
            }
            if !found { delete(registers); return nil, false }
        }
        for n in 0..<op.count {
            value := op.inputs[n]
            if value >= 2 && last_use[value] == i do busy[registers[value]] = false
        }
        if op.dst >= 0 && last_use[op.dst] < 0 do busy[registers[op.dst]] = false
    }
    return registers, true
}

compile :: proc(ops: []Op) -> ([]u8, string) {
    if len(ops) == 0 || ops[len(ops)-1].kind != .Return do return nil, "pixel program requires a final return"
    for op, i in ops {
        for n in 0..<input_count(op.kind) {
            if op.inputs[n] < 0 || op.inputs[n] >= i do return nil, "invalid pixel value dependency"
        }
    }
    machine, values := lower(ops)
    defer delete(machine)
    if len(machine) > 24*1024/INSTRUCTION_BYTES do return nil, "pixel program exceeds the 24 KiB native body limit"
    registers, allocated := allocate(machine, values)
    if !allocated do return nil, "pixel program exceeds available registers; spilling is unsupported"
    defer delete(registers)
    code := make([]u8, len(machine)*INSTRUCTION_BYTES)
    for op, i in machine {
        alu := op.alu
        alu.distance = 1
        if op.dst == -1 do alu.dst = NULL
        else if op.dst == -2 do alu.dst = 4
        else do alu.dst = registers[op.dst]
        if op.count > 0 do alu.src0 = reg(registers[op.inputs[0]])
        if op.count > 1 do alu.src1 = reg(registers[op.inputs[1]])
        instruction, err := encode_alu(alu)
        if err != .None { delete(code); return nil, "pixel instruction cannot be encoded" }
        write_instruction(code[i*INSTRUCTION_BYTES:], instruction)
    }
    return code, ""
}
