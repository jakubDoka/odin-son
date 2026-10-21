package bac
// NOTE: this file is generated: 

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
	Simd_Reduce_Add_Bisect,
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
