package bac
// NOTE: this file is generated: 

INHERITANCE_TABLE :: []u16{		0b1, // Nil
		0b1, // Entry
		0b1, // Then
		0b1, // Else
		0b1, // Region
		0b1, // Loop
		0b1, // Call_End
		0b10, // End
		0b100, // Dbg_Sym_Decl
		0b10, // Dbg_Sym_Update
		0b10, // Dbg_Scope
		0b1, // If
		0b1, // Jump
		0b1, // Trap
		0b1001, // Call
		0b1, // Always
		0b1, // Return
		0b10, // Poison
		0b10, // Mem
		0b10, // Split_Mem
		0b10, // Merge_Mem
		0b10, // Sym
		0b10000, // Local
		0b100000, // Global
		0b100000, // Param
		0b100000, // Ret
		0b10, // Phi
		0b1000000, // CInt
		0b10, // Add
		0b10, // Sub
		0b10, // And
		0b10, // Or
		0b10, // Xor
		0b10, // Eq
		0b10, // Ne
		0b10, // Le
		0b10, // Lt
		0b10, // Gt
		0b10, // Ge
		0b10, // U_Lt
		0b10, // U_Gt
		0b10, // U_Le
		0b10, // U_Ge
		0b10, // Shl
		0b10, // Shr
		0b10, // U_Shr
		0b10, // Mul
		0b10, // Div
		0b10, // U_Div
		0b10, // Rem
		0b10, // U_Rem
		0b10, // And_Not
		0b10, // Split
		0b10, // Local_Addr
		0b10, // Global_Addr
		0b100000, // Proc_Addr
		0b10, // Copy
		0b10, // Set
		0b10, // Store
		0b10, // Load
		0b10, // Neg
		0b10, // Not
		0b10, // Cast
		0b10, // Conv
		0b10, // U_Conv
		0b10, // Splat
		0b10, // Ctz
		0b10, // Simd_Extract_Lsbs
		0b10, // Simd_Extract_Msbs
		0b10, // Simd_Reduce_Add_Bisect
		0b10, // Select
		0b10, // Thread_Id
		0b10, // Lane_Id
		0b100000, // Uniform_Addr
}
NODE_EXTRA_SIZES :: []u8{		1, // Nil -> Cfg
		1, // Entry -> Cfg
		1, // Then -> Cfg
		1, // Else -> Cfg
		1, // Region -> Cfg
		1, // Loop -> Cfg
		1, // Call_End -> Cfg
		0, // End -> No_Extra
		6, // Dbg_Sym_Decl -> Dbg_Sym
		0, // Dbg_Sym_Update -> No_Extra
		0, // Dbg_Scope -> No_Extra
		1, // If -> Cfg
		1, // Jump -> Cfg
		1, // Trap -> Cfg
		4, // Call -> Call
		1, // Always -> Cfg
		1, // Return -> Cfg
		0, // Poison -> No_Extra
		0, // Mem -> No_Extra
		0, // Split_Mem -> No_Extra
		0, // Merge_Mem -> No_Extra
		0, // Sym -> No_Extra
		2, // Local -> Local
		1, // Global -> Tup
		1, // Param -> Tup
		1, // Ret -> Tup
		0, // Phi -> No_Extra
		2, // CInt -> CInt
		0, // Add -> No_Extra
		0, // Sub -> No_Extra
		0, // And -> No_Extra
		0, // Or -> No_Extra
		0, // Xor -> No_Extra
		0, // Eq -> No_Extra
		0, // Ne -> No_Extra
		0, // Le -> No_Extra
		0, // Lt -> No_Extra
		0, // Gt -> No_Extra
		0, // Ge -> No_Extra
		0, // U_Lt -> No_Extra
		0, // U_Gt -> No_Extra
		0, // U_Le -> No_Extra
		0, // U_Ge -> No_Extra
		0, // Shl -> No_Extra
		0, // Shr -> No_Extra
		0, // U_Shr -> No_Extra
		0, // Mul -> No_Extra
		0, // Div -> No_Extra
		0, // U_Div -> No_Extra
		0, // Rem -> No_Extra
		0, // U_Rem -> No_Extra
		0, // And_Not -> No_Extra
		0, // Split -> No_Extra
		0, // Local_Addr -> No_Extra
		0, // Global_Addr -> No_Extra
		1, // Proc_Addr -> Tup
		0, // Copy -> No_Extra
		0, // Set -> No_Extra
		0, // Store -> No_Extra
		0, // Load -> No_Extra
		0, // Neg -> No_Extra
		0, // Not -> No_Extra
		0, // Cast -> No_Extra
		0, // Conv -> No_Extra
		0, // U_Conv -> No_Extra
		0, // Splat -> No_Extra
		0, // Ctz -> No_Extra
		0, // Simd_Extract_Lsbs -> No_Extra
		0, // Simd_Extract_Msbs -> No_Extra
		0, // Simd_Reduce_Add_Bisect -> No_Extra
		0, // Select -> No_Extra
		0, // Thread_Id -> No_Extra
		0, // Lane_Id -> No_Extra
		1, // Uniform_Addr -> Tup
}
	NODE_FLAGS :: []Class_Flags{
		{}, // Nil
		{Class_Flag.Is_Basic_Block_Start}, // Entry
		{Class_Flag.Is_Basic_Block_Start}, // Then
		{Class_Flag.Is_Basic_Block_Start}, // Else
		{Class_Flag.Is_Basic_Block_Start}, // Region
		{Class_Flag.Is_Basic_Block_Start}, // Loop
		{Class_Flag.Is_Basic_Block_Start}, // Call_End
		{}, // End
		{}, // Dbg_Sym_Decl
		{}, // Dbg_Sym_Update
		{}, // Dbg_Scope
		{}, // If
		{}, // Jump
		{}, // Trap
		{}, // Call
		{}, // Always
		{}, // Return
		{Class_Flag.Interned}, // Poison
		{Class_Flag.Store}, // Mem
		{Class_Flag.Store}, // Split_Mem
		{Class_Flag.Store}, // Merge_Mem
		{}, // Sym
		{}, // Local
		{}, // Global
		{}, // Param
		{}, // Ret
		{Class_Flag.Interned}, // Phi
		{Class_Flag.Interned, Class_Flag.Clonable}, // CInt
		{Class_Flag.Interned, Class_Flag.Comutes}, // Add
		{Class_Flag.Interned}, // Sub
		{Class_Flag.Interned, Class_Flag.Comutes}, // And
		{Class_Flag.Interned, Class_Flag.Comutes}, // Or
		{Class_Flag.Interned, Class_Flag.Comutes}, // Xor
		{Class_Flag.Interned, Class_Flag.Comutes}, // Eq
		{Class_Flag.Interned, Class_Flag.Comutes}, // Ne
		{Class_Flag.Interned}, // Le
		{Class_Flag.Interned}, // Lt
		{Class_Flag.Interned}, // Gt
		{Class_Flag.Interned}, // Ge
		{Class_Flag.Interned}, // U_Lt
		{Class_Flag.Interned}, // U_Gt
		{Class_Flag.Interned}, // U_Le
		{Class_Flag.Interned}, // U_Ge
		{Class_Flag.Interned}, // Shl
		{Class_Flag.Interned}, // Shr
		{Class_Flag.Interned}, // U_Shr
		{Class_Flag.Interned, Class_Flag.Comutes}, // Mul
		{Class_Flag.Interned}, // Div
		{Class_Flag.Interned}, // U_Div
		{Class_Flag.Interned}, // Rem
		{Class_Flag.Interned}, // U_Rem
		{Class_Flag.Interned}, // And_Not
		{}, // Split
		{Class_Flag.Clonable}, // Local_Addr
		{Class_Flag.Interned, Class_Flag.Clonable}, // Global_Addr
		{Class_Flag.Interned, Class_Flag.Clonable}, // Proc_Addr
		{Class_Flag.Store}, // Copy
		{Class_Flag.Store}, // Set
		{Class_Flag.Store}, // Store
		{Class_Flag.Interned, Class_Flag.Load}, // Load
		{Class_Flag.Interned}, // Neg
		{Class_Flag.Interned}, // Not
		{Class_Flag.Interned}, // Cast
		{Class_Flag.Interned}, // Conv
		{Class_Flag.Interned}, // U_Conv
		{Class_Flag.Interned}, // Splat
		{Class_Flag.Interned}, // Ctz
		{Class_Flag.Interned}, // Simd_Extract_Lsbs
		{Class_Flag.Interned}, // Simd_Extract_Msbs
		{Class_Flag.Interned}, // Simd_Reduce_Add_Bisect
		{Class_Flag.Interned}, // Select
		{Class_Flag.Interned}, // Thread_Id
		{Class_Flag.Interned}, // Lane_Id
		{Class_Flag.Interned}, // Uniform_Addr
}
	NODE_EXTRA_TYPES :: []typeid{
		Cfg,
		Cfg,
		Cfg,
		Cfg,
		Cfg,
		Cfg,
		Cfg,
		No_Extra,
		Dbg_Sym,
		No_Extra,
		No_Extra,
		Cfg,
		Cfg,
		Cfg,
		Call,
		Cfg,
		Cfg,
		No_Extra,
		No_Extra,
		No_Extra,
		No_Extra,
		No_Extra,
		Local,
		Tup,
		Tup,
		Tup,
		No_Extra,
		CInt,
		No_Extra,
		No_Extra,
		No_Extra,
		No_Extra,
		No_Extra,
		No_Extra,
		No_Extra,
		No_Extra,
		No_Extra,
		No_Extra,
		No_Extra,
		No_Extra,
		No_Extra,
		No_Extra,
		No_Extra,
		No_Extra,
		No_Extra,
		No_Extra,
		No_Extra,
		No_Extra,
		No_Extra,
		No_Extra,
		No_Extra,
		No_Extra,
		No_Extra,
		No_Extra,
		No_Extra,
		Tup,
		No_Extra,
		No_Extra,
		No_Extra,
		No_Extra,
		No_Extra,
		No_Extra,
		No_Extra,
		No_Extra,
		No_Extra,
		No_Extra,
		No_Extra,
		No_Extra,
		No_Extra,
		No_Extra,
		No_Extra,
		No_Extra,
		No_Extra,
		Tup,
}
Bin_Op :: enum u16 {
	Add = u16(Node_Type.Add),
	Sub = u16(Node_Type.Sub),
	And = u16(Node_Type.And),
	Or = u16(Node_Type.Or),
	Xor = u16(Node_Type.Xor),
	Eq = u16(Node_Type.Eq),
	Ne = u16(Node_Type.Ne),
	Le = u16(Node_Type.Le),
	Lt = u16(Node_Type.Lt),
	Gt = u16(Node_Type.Gt),
	Ge = u16(Node_Type.Ge),
	U_Lt = u16(Node_Type.U_Lt),
	U_Gt = u16(Node_Type.U_Gt),
	U_Le = u16(Node_Type.U_Le),
	U_Ge = u16(Node_Type.U_Ge),
	Shl = u16(Node_Type.Shl),
	Shr = u16(Node_Type.Shr),
	U_Shr = u16(Node_Type.U_Shr),
	Mul = u16(Node_Type.Mul),
	Div = u16(Node_Type.Div),
	U_Div = u16(Node_Type.U_Div),
	Rem = u16(Node_Type.Rem),
	U_Rem = u16(Node_Type.U_Rem),
	And_Not = u16(Node_Type.And_Not),
}
Un_Op :: enum u16 {
	Neg = u16(Node_Type.Neg),
	Not = u16(Node_Type.Not),
	Cast = u16(Node_Type.Cast),
	Conv = u16(Node_Type.Conv),
	U_Conv = u16(Node_Type.U_Conv),
	Splat = u16(Node_Type.Splat),
	Ctz = u16(Node_Type.Ctz),
	Simd_Extract_Lsbs = u16(Node_Type.Simd_Extract_Lsbs),
	Simd_Extract_Msbs = u16(Node_Type.Simd_Extract_Msbs),
	Simd_Reduce_Add_Bisect = u16(Node_Type.Simd_Reduce_Add_Bisect),
}
Node_Type :: enum u16 {
	Nil,
	Entry,
	Then,
	Else,
	Region,
	Loop,
	Call_End,
	End,
	Dbg_Sym_Decl,
	Dbg_Sym_Update,
	Dbg_Scope,
	If,
	Jump,
	Trap,
	Call,
	Always,
	Return,
	Poison,
	Mem,
	Split_Mem,
	Merge_Mem,
	Sym,
	Local,
	Global,
	Param,
	Ret,
	Phi,
	CInt,
	Add,
	Sub,
	And,
	Or,
	Xor,
	Eq,
	Ne,
	Le,
	Lt,
	Gt,
	Ge,
	U_Lt,
	U_Gt,
	U_Le,
	U_Ge,
	Shl,
	Shr,
	U_Shr,
	Mul,
	Div,
	U_Div,
	Rem,
	U_Rem,
	And_Not,
	Split,
	Local_Addr,
	Global_Addr,
	Proc_Addr,
	Copy,
	Set,
	Store,
	Load,
	Neg,
	Not,
	Cast,
	Conv,
	U_Conv,
	Splat,
	Ctz,
	Simd_Extract_Lsbs,
	Simd_Extract_Msbs,
	Simd_Reduce_Add_Bisect,
	Select,
	Thread_Id,
	Lane_Id,
	Uniform_Addr,
}
add_entry :: #force_inline proc(prc: ^Proc, name: string) -> (_id: Node_ID) {
	(^Cfg)(get_next_extra_slot(prc, u16(Node_Type.Entry), 0))^ = {
	}
	return add_raw(prc, name, u16(Node_Type.Entry), .Void, {})
}
add_then :: #force_inline proc(prc: ^Proc, name: string, ctrl: Node_ID) -> (_id: Node_ID) {
	(^Cfg)(get_next_extra_slot(prc, u16(Node_Type.Then), 0))^ = {
	}
	return add_raw(prc, name, u16(Node_Type.Then), .Void, {ctrl})
}
add_else :: #force_inline proc(prc: ^Proc, name: string, ctrl: Node_ID) -> (_id: Node_ID) {
	(^Cfg)(get_next_extra_slot(prc, u16(Node_Type.Else), 0))^ = {
	}
	return add_raw(prc, name, u16(Node_Type.Else), .Void, {ctrl})
}
add_region :: #force_inline proc(prc: ^Proc, name: string, inputs: []Node_ID) -> (_id: Node_ID) {
	(^Cfg)(get_next_extra_slot(prc, u16(Node_Type.Region), 0))^ = {
	}
	return add_raw(prc, name, u16(Node_Type.Region), .Void, inputs)
}
add_loop :: #force_inline proc(prc: ^Proc, name: string, ctrl: Node_ID) -> (_id: Node_ID) {
	(^Cfg)(get_next_extra_slot(prc, u16(Node_Type.Loop), 0))^ = {
	}
	return add_raw(prc, name, u16(Node_Type.Loop), .Void, {ctrl}, {extra_capacity = 1,})
}
@(tag = "api")
add_call_end :: #force_inline proc(prc: ^Proc, name: string, call: Node_ID) -> (_id: Node_ID) {
	(^Cfg)(get_next_extra_slot(prc, u16(Node_Type.Call_End), 0))^ = {
	}
	return add_raw(prc, name, u16(Node_Type.Call_End), .Void, {call})
}
add_end :: #force_inline proc(prc: ^Proc, name: string, inputs: []Node_ID) -> (_id: Node_ID) {
	return add_raw(prc, name, u16(Node_Type.End), .Void, inputs)
}
add_dbg_sym_decl :: #force_inline proc(prc: ^Proc, name: string) -> (_id: Node_ID) {
	(^Dbg_Sym)(get_next_extra_slot(prc, u16(Node_Type.Dbg_Sym_Decl), 0))^ = {
	}
	return add_raw(prc, name, u16(Node_Type.Dbg_Sym_Decl), .Void, {})
}
add_dbg_sym_update :: #force_inline proc(prc: ^Proc, name: string, new_value: Node_ID, prev_update: Node_ID) -> (_id: Node_ID) {
	return add_raw(prc, name, u16(Node_Type.Dbg_Sym_Update), .Void, {new_value, prev_update})
}
add_dbg_scope :: #force_inline proc(prc: ^Proc, name: string, inputs: []Node_ID) -> (_id: Node_ID) {
	return add_raw(prc, name, u16(Node_Type.Dbg_Scope), .Void, inputs)
}
add_if :: #force_inline proc(prc: ^Proc, name: string, ctrl: Node_ID, cond: Node_ID) -> (_id: Node_ID) {
	(^Cfg)(get_next_extra_slot(prc, u16(Node_Type.If), 0))^ = {
	}
	return add_raw(prc, name, u16(Node_Type.If), .Void, {ctrl, cond})
}
add_jump :: #force_inline proc(prc: ^Proc, name: string, ctrl: Node_ID) -> (_id: Node_ID) {
	(^Cfg)(get_next_extra_slot(prc, u16(Node_Type.Jump), 0))^ = {
	}
	return add_raw(prc, name, u16(Node_Type.Jump), .Void, {ctrl})
}
@(tag = "api")
add_trap :: #force_inline proc(prc: ^Proc, name: string, inputs: []Node_ID) -> (_id: Node_ID) {
	(^Cfg)(get_next_extra_slot(prc, u16(Node_Type.Trap), 0))^ = {
	}
	return add_raw(prc, name, u16(Node_Type.Trap), .Void, inputs)
}
@(tag = "api")
add_call :: #force_inline proc(prc: ^Proc, name: string, inputs: []Node_ID, extra: Call) -> (_id: Node_ID) {
	(^Call)(get_next_extra_slot(prc, u16(Node_Type.Call), 0))^ = extra
	return add_raw(prc, name, u16(Node_Type.Call), .Void, inputs)
}
add_always :: #force_inline proc(prc: ^Proc, name: string, inputs: []Node_ID) -> (_id: Node_ID) {
	(^Cfg)(get_next_extra_slot(prc, u16(Node_Type.Always), 0))^ = {
	}
	return add_raw(prc, name, u16(Node_Type.Always), .Void, inputs)
}
add_return :: #force_inline proc(prc: ^Proc, name: string, inputs: []Node_ID) -> (_id: Node_ID) {
	(^Cfg)(get_next_extra_slot(prc, u16(Node_Type.Return), 0))^ = {
	}
	return add_raw(prc, name, u16(Node_Type.Return), .Void, inputs)
}
add_poison :: #force_inline proc(prc: ^Proc, name: string) -> (_id: Node_ID) {
	return add_raw(prc, name, u16(Node_Type.Poison), .Void, {})
}
@(tag = "api")
add_mem :: #force_inline proc(prc: ^Proc, name: string, ctrl: Node_ID) -> (_id: Node_ID) {
	return add_raw(prc, name, u16(Node_Type.Mem), .Mem, {ctrl})
}
add_split_mem :: #force_inline proc(prc: ^Proc, name: string, mem: Node_ID) -> (_id: Node_ID) {
	return add_raw(prc, name, u16(Node_Type.Split_Mem), .Mem, {mem})
}
add_merge_mem :: #force_inline proc(prc: ^Proc, name: string, inputs: []Node_ID) -> (_id: Node_ID) {
	return add_raw(prc, name, u16(Node_Type.Merge_Mem), .Mem, inputs)
}
add_sym :: #force_inline proc(prc: ^Proc, name: string, entry: Node_ID) -> (_id: Node_ID) {
	return add_raw(prc, name, u16(Node_Type.Sym), .Void, {entry})
}
@(tag = "api")
add_local :: #force_inline proc(prc: ^Proc, name: string, mem: Node_ID) -> (_id: Node_ID) {
	(^Local)(get_next_extra_slot(prc, u16(Node_Type.Local), 0))^ = {
	}
	return add_raw(prc, name, u16(Node_Type.Local), .Void, {mem})
}
@(tag = "api")
add_global :: #force_inline proc(prc: ^Proc, name: string, idx: u32) -> (_id: Node_ID) {
	(^Tup)(get_next_extra_slot(prc, u16(Node_Type.Global), 0))^ = {
		idx = idx,
	}
	return add_raw(prc, name, u16(Node_Type.Global), .Void, {})
}
add_param :: #force_inline proc(prc: ^Proc, name: string, dt: Node_Datatype, entry: Node_ID, idx: u32) -> (_id: Node_ID) {
	(^Tup)(get_next_extra_slot(prc, u16(Node_Type.Param), 0))^ = {
		idx = idx,
	}
	return add_raw(prc, name, u16(Node_Type.Param), dt, {entry})
}
@(tag = "api")
add_ret :: #force_inline proc(prc: ^Proc, name: string, dt: Node_Datatype, call_end: Node_ID, idx: u32) -> (_id: Node_ID) {
	(^Tup)(get_next_extra_slot(prc, u16(Node_Type.Ret), 0))^ = {
		idx = idx,
	}
	return add_raw(prc, name, u16(Node_Type.Ret), dt, {call_end})
}
add_phi :: #force_inline proc(prc: ^Proc, name: string, dt: Node_Datatype, reg: Node_ID, lhs: Node_ID, rhs: Node_ID) -> (_id: Node_ID) {
	return add_raw(prc, name, u16(Node_Type.Phi), dt, {reg, lhs, rhs})
}
@(tag = "api")
add_c_int :: #force_inline proc(prc: ^Proc, name: string, dt: Node_Datatype, value: i64) -> (_id: Node_ID) {
	(^CInt)(get_next_extra_slot(prc, u16(Node_Type.CInt), 0))^ = {
		value = value,
	}
	return add_raw(prc, name, u16(Node_Type.CInt), dt, {})
}
@(tag = "api")
add_bin_op :: #force_inline proc(prc: ^Proc, name: string, type: Bin_Op, dt: Node_Datatype, lhs: Node_ID, rhs: Node_ID, lane: Lane_Type = {}) -> (_id: Node_ID) {
	return add_raw(prc, name, u16(type), dt, {lhs, rhs}, {lane = lane,})
}
add_split :: #force_inline proc(prc: ^Proc, name: string, dt: Node_Datatype, dest: Node_ID) -> (_id: Node_ID) {
	return add_raw(prc, name, u16(Node_Type.Split), dt, {dest})
}
@(tag = "api")
add_local_addr :: #force_inline proc(prc: ^Proc, name: string, local: Node_ID) -> (_id: Node_ID) {
	return add_raw(prc, name, u16(Node_Type.Local_Addr), .I64, {local})
}
@(tag = "api")
add_global_addr :: #force_inline proc(prc: ^Proc, name: string, global: Node_ID) -> (_id: Node_ID) {
	return add_raw(prc, name, u16(Node_Type.Global_Addr), .I64, {global})
}
@(tag = "api")
add_proc_addr :: #force_inline proc(prc: ^Proc, name: string, idx: u32) -> (_id: Node_ID) {
	(^Tup)(get_next_extra_slot(prc, u16(Node_Type.Proc_Addr), 0))^ = {
		idx = idx,
	}
	return add_raw(prc, name, u16(Node_Type.Proc_Addr), .I64, {})
}
@(tag = "api")
add_copy :: #force_inline proc(prc: ^Proc, name: string, ctrl: Node_ID, mem: Node_ID, dst: Node_ID, src: Node_ID, size: Node_ID) -> (_id: Node_ID) {
	return add_raw(prc, name, u16(Node_Type.Copy), .Mem, {ctrl, mem, dst, src, size})
}
@(tag = "api")
add_set :: #force_inline proc(prc: ^Proc, name: string, ctrl: Node_ID, mem: Node_ID, dst: Node_ID, value: Node_ID, size: Node_ID) -> (_id: Node_ID) {
	return add_raw(prc, name, u16(Node_Type.Set), .Mem, {ctrl, mem, dst, value, size})
}
add_store :: #force_inline proc(prc: ^Proc, name: string, ctrl: Node_ID, mem: Node_ID, addr: Node_ID, value: Node_ID) -> (_id: Node_ID) {
	return add_raw(prc, name, u16(Node_Type.Store), .Mem, {ctrl, mem, addr, value})
}
add_load :: #force_inline proc(prc: ^Proc, name: string, dt: Node_Datatype, ctrl: Node_ID, mem: Node_ID, addr: Node_ID) -> (_id: Node_ID) {
	return add_raw(prc, name, u16(Node_Type.Load), dt, {ctrl, mem, addr})
}
@(tag = "api")
add_un_op :: #force_inline proc(prc: ^Proc, name: string, type: Un_Op, dt: Node_Datatype, oprnd: Node_ID, lane: Lane_Type = {}) -> (_id: Node_ID) {
	return add_raw(prc, name, u16(type), dt, {oprnd}, {lane = lane,})
}
@(tag = "api")
add_select :: #force_inline proc(prc: ^Proc, name: string, dt: Node_Datatype, on_true: Node_ID, on_false: Node_ID, condition: Node_ID) -> (_id: Node_ID) {
	return add_raw(prc, name, u16(Node_Type.Select), dt, {on_true, on_false, condition})
}

inherit_idx_of :: #force_inline proc($T: typeid) -> u8 {
	when false {}
	else when T == CInt {return 6}
	else when T == Call {return 3}
	else when T == Cfg {return 0}
	else when T == Dbg_Sym {return 2}
	else when T == Local {return 4}
	else when T == No_Extra {return 1}
	else when T == Tup {return 5}
	else {#panic(`the passed type is not subclass of anything`)}
}
#assert(size_of(CInt) % PRECISION == 0)
#assert(size_of(Call) % PRECISION == 0)
#assert(size_of(Cfg) % PRECISION == 0)
#assert(size_of(Dbg_Sym) % PRECISION == 0)
#assert(size_of(Local) % PRECISION == 0)
#assert(size_of(No_Extra) % PRECISION == 0)
#assert(size_of(Tup) % PRECISION == 0)
