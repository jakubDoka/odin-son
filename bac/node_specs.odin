package bac
// NOTE: this file is generated: 

Un_Op :: enum u16 {
	Uext = u16(Node_Type.Uext),
	Sext = u16(Node_Type.Sext),
	F_To_I = u16(Node_Type.F_To_I),
	Cast = u16(Node_Type.Cast),
	Not = u16(Node_Type.Not),
	Neg = u16(Node_Type.Neg),
	Ctz = u16(Node_Type.Ctz),
	Splat = u16(Node_Type.Splat),
	Simd_Reduce_Add_Bisect = u16(Node_Type.Simd_Reduce_Add_Bisect),
	Simd_Extract_Lsbs = u16(Node_Type.Simd_Extract_Lsbs),
	U_F_From_I = u16(Node_Type.U_F_From_I),
	F_From_I = u16(Node_Type.F_From_I),
	F_Demote = u16(Node_Type.F_Demote),
	F_Ext = u16(Node_Type.F_Ext),
}
Bin_Op :: enum u16 {
	Add = u16(Node_Type.Add),
	Rem = u16(Node_Type.Rem),
	And = u16(Node_Type.And),
	And_Not = u16(Node_Type.And_Not),
	U_Shr = u16(Node_Type.U_Shr),
	Div = u16(Node_Type.Div),
	Lt = u16(Node_Type.Lt),
	Ge = u16(Node_Type.Ge),
	Xor = u16(Node_Type.Xor),
	Ne = u16(Node_Type.Ne),
	F_Sub = u16(Node_Type.F_Sub),
	F_Div = u16(Node_Type.F_Div),
	U_Gt = u16(Node_Type.U_Gt),
	U_Ge = u16(Node_Type.U_Ge),
	F_Ge = u16(Node_Type.F_Ge),
	Shr = u16(Node_Type.Shr),
	F_Ne = u16(Node_Type.F_Ne),
	F_Le = u16(Node_Type.F_Le),
	U_Rem = u16(Node_Type.U_Rem),
	Sub = u16(Node_Type.Sub),
	Mul = u16(Node_Type.Mul),
	U_Div = u16(Node_Type.U_Div),
	Le = u16(Node_Type.Le),
	Gt = u16(Node_Type.Gt),
	Or = u16(Node_Type.Or),
	Eq = u16(Node_Type.Eq),
	F_Add = u16(Node_Type.F_Add),
	F_Mul = u16(Node_Type.F_Mul),
	U_Lt = u16(Node_Type.U_Lt),
	U_Le = u16(Node_Type.U_Le),
	F_Gt = u16(Node_Type.F_Gt),
	Shl = u16(Node_Type.Shl),
	F_Eq = u16(Node_Type.F_Eq),
	F_Lt = u16(Node_Type.F_Lt),
}
Node_Type :: enum u16 {
	Start,
	Entry,
	Poison,
	Param,
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
	F_Add,
	F_Sub,
	F_Mul,
	F_Div,
	F_Eq,
	F_Ne,
	F_Lt,
	F_Le,
	F_Gt,
	F_Ge,
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
	Phi,
	Mem,
	Root_Mem,
	Sym,
	Local,
	Local_Addr,
	Global,
	Global_Addr,
	Proc_Addr,
	Copy,
	Set,
	Store,
	Load,
	If,
	Then,
	Else,
	Jump,
	Dead,
	Region,
	Loop,
	Always,
	Trap,
	Call,
	Call_End,
	Ret,
	Return,
	Neg,
	Not,
	Sext,
	Uext,
	Cast,
	F_To_I,
	F_From_I,
	U_F_From_I,
	F_Ext,
	F_Demote,
	Splat,
	Ctz,
	Simd_Extract_Lsbs,
	Simd_Reduce_Add_Bisect,
	CV128,
}
#assert(size_of(Cfg) % PRECISION == 0)
add_start :: #force_inline proc(graph: ^Graph, name: string) -> (_id: Node_ID) {
	(^Cfg)(get_next_extra_slot(graph, u16(Node_Type.Start), 0))^ = {}
	return add_raw(graph, name, u16(Node_Type.Start), .Void, {})
}
#assert(size_of(Cfg) % PRECISION == 0)
add_entry :: #force_inline proc(graph: ^Graph, name: string, start: Node_ID) -> (_id: Node_ID) {
	(^Cfg)(get_next_extra_slot(graph, u16(Node_Type.Entry), 0))^ = {}
	return add_raw(graph, name, u16(Node_Type.Entry), .Void, {start})
}
#assert(size_of(No_Extra) % PRECISION == 0)
add_poison :: #force_inline proc(graph: ^Graph, name: string) -> (_id: Node_ID) {
	return add_raw(graph, name, u16(Node_Type.Poison), .Void, {})
}
#assert(size_of(Tup) % PRECISION == 0)
add_param :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype, entry: Node_ID, idx: u32) -> (_id: Node_ID) {
	(^Tup)(get_next_extra_slot(graph, u16(Node_Type.Param), 0))^ = {
		idx = idx,
	}
	return add_raw(graph, name, u16(Node_Type.Param), dt, {entry})
}
#assert(size_of(CInt) % PRECISION == 0)
add_c_int :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype, value: i64) -> (_id: Node_ID) {
	(^CInt)(get_next_extra_slot(graph, u16(Node_Type.CInt), 0))^ = {
		value = value,
	}
	return add_raw(graph, name, u16(Node_Type.CInt), dt, {})
}
#assert(size_of(No_Extra) % PRECISION == 0)
add_bin_op :: #force_inline proc(graph: ^Graph, name: string, type: Bin_Op, dt: Node_Datatype, lhs: Node_ID, rhs: Node_ID, lane: Lane_Type = {}) -> (_id: Node_ID) {
	return add_raw(graph, name, u16(type), dt, {lhs, rhs}, {lane = lane,})
}
#assert(size_of(No_Extra) % PRECISION == 0)
#assert(size_of(No_Extra) % PRECISION == 0)
#assert(size_of(No_Extra) % PRECISION == 0)
#assert(size_of(No_Extra) % PRECISION == 0)
#assert(size_of(No_Extra) % PRECISION == 0)
#assert(size_of(No_Extra) % PRECISION == 0)
#assert(size_of(No_Extra) % PRECISION == 0)
#assert(size_of(No_Extra) % PRECISION == 0)
#assert(size_of(No_Extra) % PRECISION == 0)
#assert(size_of(No_Extra) % PRECISION == 0)
#assert(size_of(No_Extra) % PRECISION == 0)
#assert(size_of(No_Extra) % PRECISION == 0)
#assert(size_of(No_Extra) % PRECISION == 0)
#assert(size_of(No_Extra) % PRECISION == 0)
#assert(size_of(No_Extra) % PRECISION == 0)
#assert(size_of(No_Extra) % PRECISION == 0)
#assert(size_of(No_Extra) % PRECISION == 0)
#assert(size_of(No_Extra) % PRECISION == 0)
#assert(size_of(No_Extra) % PRECISION == 0)
#assert(size_of(No_Extra) % PRECISION == 0)
#assert(size_of(No_Extra) % PRECISION == 0)
#assert(size_of(No_Extra) % PRECISION == 0)
#assert(size_of(No_Extra) % PRECISION == 0)
#assert(size_of(No_Extra) % PRECISION == 0)
#assert(size_of(No_Extra) % PRECISION == 0)
#assert(size_of(No_Extra) % PRECISION == 0)
#assert(size_of(No_Extra) % PRECISION == 0)
#assert(size_of(No_Extra) % PRECISION == 0)
#assert(size_of(No_Extra) % PRECISION == 0)
#assert(size_of(No_Extra) % PRECISION == 0)
#assert(size_of(No_Extra) % PRECISION == 0)
#assert(size_of(No_Extra) % PRECISION == 0)
#assert(size_of(No_Extra) % PRECISION == 0)
#assert(size_of(No_Extra) % PRECISION == 0)
add_split :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype, dest: Node_ID) -> (_id: Node_ID) {
	return add_raw(graph, name, u16(Node_Type.Split), dt, {dest})
}
#assert(size_of(No_Extra) % PRECISION == 0)
add_phi :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype, reg: Node_ID, lhs: Node_ID, rhs: Node_ID) -> (_id: Node_ID) {
	return add_raw(graph, name, u16(Node_Type.Phi), dt, {reg, lhs, rhs})
}
#assert(size_of(No_Extra) % PRECISION == 0)
add_mem :: #force_inline proc(graph: ^Graph, name: string, ctrl: Node_ID) -> (_id: Node_ID) {
	return add_raw(graph, name, u16(Node_Type.Mem), .Void, {ctrl})
}
#assert(size_of(No_Extra) % PRECISION == 0)
add_root_mem :: #force_inline proc(graph: ^Graph, name: string, ctrl: Node_ID) -> (_id: Node_ID) {
	return add_raw(graph, name, u16(Node_Type.Root_Mem), .Void, {ctrl})
}
#assert(size_of(No_Extra) % PRECISION == 0)
add_sym :: #force_inline proc(graph: ^Graph, name: string, entry: Node_ID) -> (_id: Node_ID) {
	return add_raw(graph, name, u16(Node_Type.Sym), .Void, {entry})
}
#assert(size_of(Local) % PRECISION == 0)
add_local :: #force_inline proc(graph: ^Graph, name: string, mem: Node_ID) -> (_id: Node_ID) {
	(^Local)(get_next_extra_slot(graph, u16(Node_Type.Local), 0))^ = {}
	return add_raw(graph, name, u16(Node_Type.Local), .Void, {mem})
}
#assert(size_of(No_Extra) % PRECISION == 0)
add_local_addr :: #force_inline proc(graph: ^Graph, name: string, local: Node_ID) -> (_id: Node_ID) {
	return add_raw(graph, name, u16(Node_Type.Local_Addr), .I64, {local})
}
#assert(size_of(Tup) % PRECISION == 0)
add_global :: #force_inline proc(graph: ^Graph, name: string) -> (_id: Node_ID) {
	(^Tup)(get_next_extra_slot(graph, u16(Node_Type.Global), 0))^ = {}
	return add_raw(graph, name, u16(Node_Type.Global), .Void, {})
}
#assert(size_of(No_Extra) % PRECISION == 0)
add_global_addr :: #force_inline proc(graph: ^Graph, name: string, global: Node_ID) -> (_id: Node_ID) {
	return add_raw(graph, name, u16(Node_Type.Global_Addr), .I64, {global})
}
#assert(size_of(Tup) % PRECISION == 0)
add_proc_addr :: #force_inline proc(graph: ^Graph, name: string, idx: u32) -> (_id: Node_ID) {
	(^Tup)(get_next_extra_slot(graph, u16(Node_Type.Proc_Addr), 0))^ = {
		idx = idx,
	}
	return add_raw(graph, name, u16(Node_Type.Proc_Addr), .I64, {})
}
#assert(size_of(No_Extra) % PRECISION == 0)
add_copy :: #force_inline proc(graph: ^Graph, name: string, ctrl: Node_ID, mem: Node_ID, dst: Node_ID, src: Node_ID, size: Node_ID) -> (_id: Node_ID) {
	return add_raw(graph, name, u16(Node_Type.Copy), .Void, {ctrl, mem, dst, src, size})
}
#assert(size_of(No_Extra) % PRECISION == 0)
add_set :: #force_inline proc(graph: ^Graph, name: string, ctrl: Node_ID, mem: Node_ID, dst: Node_ID, value: Node_ID, size: Node_ID) -> (_id: Node_ID) {
	return add_raw(graph, name, u16(Node_Type.Set), .Void, {ctrl, mem, dst, value, size})
}
#assert(size_of(No_Extra) % PRECISION == 0)
add_store :: #force_inline proc(graph: ^Graph, name: string, ctrl: Node_ID, mem: Node_ID, addr: Node_ID, value: Node_ID) -> (_id: Node_ID) {
	return add_raw(graph, name, u16(Node_Type.Store), .Void, {ctrl, mem, addr, value})
}
#assert(size_of(No_Extra) % PRECISION == 0)
add_load :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype, ctrl: Node_ID, mem: Node_ID, addr: Node_ID) -> (_id: Node_ID) {
	return add_raw(graph, name, u16(Node_Type.Load), dt, {ctrl, mem, addr})
}
#assert(size_of(Cfg) % PRECISION == 0)
add_if :: #force_inline proc(graph: ^Graph, name: string, ctrl: Node_ID, cond: Node_ID) -> (_id: Node_ID) {
	(^Cfg)(get_next_extra_slot(graph, u16(Node_Type.If), 0))^ = {}
	return add_raw(graph, name, u16(Node_Type.If), .Void, {ctrl, cond})
}
#assert(size_of(Cfg) % PRECISION == 0)
add_then :: #force_inline proc(graph: ^Graph, name: string, ctrl: Node_ID) -> (_id: Node_ID) {
	(^Cfg)(get_next_extra_slot(graph, u16(Node_Type.Then), 0))^ = {}
	return add_raw(graph, name, u16(Node_Type.Then), .Void, {ctrl})
}
#assert(size_of(Cfg) % PRECISION == 0)
add_else :: #force_inline proc(graph: ^Graph, name: string, ctrl: Node_ID) -> (_id: Node_ID) {
	(^Cfg)(get_next_extra_slot(graph, u16(Node_Type.Else), 0))^ = {}
	return add_raw(graph, name, u16(Node_Type.Else), .Void, {ctrl})
}
#assert(size_of(Cfg) % PRECISION == 0)
add_jump :: #force_inline proc(graph: ^Graph, name: string, ctrl: Node_ID) -> (_id: Node_ID) {
	(^Cfg)(get_next_extra_slot(graph, u16(Node_Type.Jump), 0))^ = {}
	return add_raw(graph, name, u16(Node_Type.Jump), .Void, {ctrl})
}
#assert(size_of(Cfg) % PRECISION == 0)
add_dead :: #force_inline proc(graph: ^Graph, name: string) -> (_id: Node_ID) {
	(^Cfg)(get_next_extra_slot(graph, u16(Node_Type.Dead), 0))^ = {}
	return add_raw(graph, name, u16(Node_Type.Dead), .Void, {})
}
#assert(size_of(Cfg) % PRECISION == 0)
add_region :: #force_inline proc(graph: ^Graph, name: string, inputs: []Node_ID) -> (_id: Node_ID) {
	(^Cfg)(get_next_extra_slot(graph, u16(Node_Type.Region), 0))^ = {}
	return add_raw(graph, name, u16(Node_Type.Region), .Void, inputs)
}
#assert(size_of(Cfg) % PRECISION == 0)
add_loop :: #force_inline proc(graph: ^Graph, name: string, ctrl: Node_ID) -> (_id: Node_ID) {
	(^Cfg)(get_next_extra_slot(graph, u16(Node_Type.Loop), 0))^ = {}
	return add_raw(graph, name, u16(Node_Type.Loop), .Void, {ctrl}, {extra_capacity = 1,})
}
#assert(size_of(Cfg) % PRECISION == 0)
add_always :: #force_inline proc(graph: ^Graph, name: string, ctrl: Node_ID) -> (_id: Node_ID) {
	(^Cfg)(get_next_extra_slot(graph, u16(Node_Type.Always), 0))^ = {}
	return add_raw(graph, name, u16(Node_Type.Always), .Void, {ctrl})
}
#assert(size_of(Cfg) % PRECISION == 0)
add_trap :: #force_inline proc(graph: ^Graph, name: string, ctrl: Node_ID) -> (_id: Node_ID) {
	(^Cfg)(get_next_extra_slot(graph, u16(Node_Type.Trap), 0))^ = {}
	return add_raw(graph, name, u16(Node_Type.Trap), .Void, {ctrl})
}
#assert(size_of(Call) % PRECISION == 0)
add_call :: #force_inline proc(graph: ^Graph, name: string, inputs: []Node_ID, cid: u32) -> (_id: Node_ID) {
	(^Call)(get_next_extra_slot(graph, u16(Node_Type.Call), 0))^ = {
		cid = cid,
	}
	return add_raw(graph, name, u16(Node_Type.Call), .Void, inputs)
}
#assert(size_of(Cfg) % PRECISION == 0)
add_call_end :: #force_inline proc(graph: ^Graph, name: string, call: Node_ID) -> (_id: Node_ID) {
	(^Cfg)(get_next_extra_slot(graph, u16(Node_Type.Call_End), 0))^ = {}
	return add_raw(graph, name, u16(Node_Type.Call_End), .Void, {call})
}
#assert(size_of(Tup) % PRECISION == 0)
add_ret :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype, call_end: Node_ID, idx: u32) -> (_id: Node_ID) {
	(^Tup)(get_next_extra_slot(graph, u16(Node_Type.Ret), 0))^ = {
		idx = idx,
	}
	return add_raw(graph, name, u16(Node_Type.Ret), dt, {call_end})
}
#assert(size_of(Cfg) % PRECISION == 0)
add_return :: #force_inline proc(graph: ^Graph, name: string, inputs: []Node_ID) -> (_id: Node_ID) {
	(^Cfg)(get_next_extra_slot(graph, u16(Node_Type.Return), 0))^ = {}
	return add_raw(graph, name, u16(Node_Type.Return), .Void, inputs)
}
#assert(size_of(No_Extra) % PRECISION == 0)
add_un_op :: #force_inline proc(graph: ^Graph, name: string, type: Un_Op, dt: Node_Datatype, oprnd: Node_ID, lane: Lane_Type = {}) -> (_id: Node_ID) {
	return add_raw(graph, name, u16(type), dt, {oprnd}, {lane = lane,})
}
#assert(size_of(No_Extra) % PRECISION == 0)
#assert(size_of(No_Extra) % PRECISION == 0)
#assert(size_of(No_Extra) % PRECISION == 0)
#assert(size_of(No_Extra) % PRECISION == 0)
#assert(size_of(No_Extra) % PRECISION == 0)
#assert(size_of(No_Extra) % PRECISION == 0)
#assert(size_of(No_Extra) % PRECISION == 0)
#assert(size_of(No_Extra) % PRECISION == 0)
#assert(size_of(No_Extra) % PRECISION == 0)
#assert(size_of(No_Extra) % PRECISION == 0)
#assert(size_of(No_Extra) % PRECISION == 0)
#assert(size_of(No_Extra) % PRECISION == 0)
#assert(size_of(No_Extra) % PRECISION == 0)
#assert(size_of(CV128) % PRECISION == 0)
add_cv128 :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype, lo: u64, hi: u64) -> (_id: Node_ID) {
	(^CV128)(get_next_extra_slot(graph, u16(Node_Type.CV128), 0))^ = {
		lo = lo,
		hi = hi,
	}
	return add_raw(graph, name, u16(Node_Type.CV128), dt, {})
}

inherit_idx_of :: #force_inline proc($T: typeid) -> u8 {
	when false {}
	else when T == Local {return 4}
	else when T == Tup {return 2}
	else when T == No_Extra {return 1}
	else when T == Call {return 5}
	else when T == Cfg {return 0}
	else when T == CInt {return 3}
	else when T == CV128 {return 6}
	else {#panic(`the passed type is not subclass of anything`)}
}
