package backend
// NOTE: this file is generated: odin run backend -define:GEN_SPEC=true

when !GEN_SPEC {
Un_Op :: enum u16 {
	Cast = u16(Ideal_Node_Type.Cast),
	Uext = u16(Ideal_Node_Type.Uext),
	F_From_I = u16(Ideal_Node_Type.F_From_I),
	F_To_I = u16(Ideal_Node_Type.F_To_I),
	Neg = u16(Ideal_Node_Type.Neg),
	Sext = u16(Ideal_Node_Type.Sext),
	Not = u16(Ideal_Node_Type.Not),
	F_Demote = u16(Ideal_Node_Type.F_Demote),
	F_Ext = u16(Ideal_Node_Type.F_Ext),
}
Bin_Op :: enum u16 {
	Add = u16(Ideal_Node_Type.Add),
	Rem = u16(Ideal_Node_Type.Rem),
	And = u16(Ideal_Node_Type.And),
	And_Not = u16(Ideal_Node_Type.And_Not),
	U_Shr = u16(Ideal_Node_Type.U_Shr),
	Div = u16(Ideal_Node_Type.Div),
	Lt = u16(Ideal_Node_Type.Lt),
	Ge = u16(Ideal_Node_Type.Ge),
	Xor = u16(Ideal_Node_Type.Xor),
	Ne = u16(Ideal_Node_Type.Ne),
	F_Sub = u16(Ideal_Node_Type.F_Sub),
	F_Div = u16(Ideal_Node_Type.F_Div),
	U_Gt = u16(Ideal_Node_Type.U_Gt),
	U_Ge = u16(Ideal_Node_Type.U_Ge),
	F_Ge = u16(Ideal_Node_Type.F_Ge),
	Shr = u16(Ideal_Node_Type.Shr),
	F_Ne = u16(Ideal_Node_Type.F_Ne),
	F_Le = u16(Ideal_Node_Type.F_Le),
	U_Rem = u16(Ideal_Node_Type.U_Rem),
	Sub = u16(Ideal_Node_Type.Sub),
	Mul = u16(Ideal_Node_Type.Mul),
	U_Div = u16(Ideal_Node_Type.U_Div),
	Le = u16(Ideal_Node_Type.Le),
	Gt = u16(Ideal_Node_Type.Gt),
	Or = u16(Ideal_Node_Type.Or),
	Eq = u16(Ideal_Node_Type.Eq),
	F_Add = u16(Ideal_Node_Type.F_Add),
	F_Mul = u16(Ideal_Node_Type.F_Mul),
	U_Lt = u16(Ideal_Node_Type.U_Lt),
	U_Le = u16(Ideal_Node_Type.U_Le),
	F_Gt = u16(Ideal_Node_Type.F_Gt),
	Shl = u16(Ideal_Node_Type.Shl),
	F_Eq = u16(Ideal_Node_Type.F_Eq),
	F_Lt = u16(Ideal_Node_Type.F_Lt),
}
Root_Node_Type :: enum u16 {
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
	Load_S,
	If,
	Then,
	Else,
	Jump,
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
	F_Ext,
	F_Demote,
}
#assert(size_of(Cfg) % PRECISION == 0)
graph_add_start :: #force_inline proc(graph: ^Graph, name: string) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^Cfg)(graph_get_next_extra_slot(graph, u16(Ideal_Node_Type.Start)))^ = {}
	return graph_add_raw(graph, u16(Ideal_Node_Type.Start), .Void, {})
}
#assert(size_of(Cfg) % PRECISION == 0)
graph_add_entry :: #force_inline proc(graph: ^Graph, name: string, start: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^Cfg)(graph_get_next_extra_slot(graph, u16(Ideal_Node_Type.Entry)))^ = {}
	return graph_add_raw(graph, u16(Ideal_Node_Type.Entry), .Void, {start})
}
#assert(size_of(No_Extra) % PRECISION == 0)
graph_add_poison :: #force_inline proc(graph: ^Graph, name: string) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Ideal_Node_Type.Poison), .Void, {})
}
#assert(size_of(Tup) % PRECISION == 0)
graph_add_param :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype, entry: Node_ID, idx: u32) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^Tup)(graph_get_next_extra_slot(graph, u16(Ideal_Node_Type.Param)))^ = {
		idx = idx
	}
	return graph_add_raw(graph, u16(Ideal_Node_Type.Param), dt, {entry})
}
#assert(size_of(CInt) % PRECISION == 0)
graph_add_c_int :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype, value: i64) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^CInt)(graph_get_next_extra_slot(graph, u16(Ideal_Node_Type.CInt)))^ = {
		value = value
	}
	return graph_add_raw(graph, u16(Ideal_Node_Type.CInt), dt, {})
}
#assert(size_of(No_Extra) % PRECISION == 0)
graph_add_bin_op :: #force_inline proc(graph: ^Graph, name: string, type: Bin_Op, dt: Node_Datatype, lhs: Node_ID, rhs: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(type), dt, {lhs, rhs})
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
graph_add_split :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype, dest: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Ideal_Node_Type.Split), dt, {dest})
}
#assert(size_of(No_Extra) % PRECISION == 0)
graph_add_phi :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype, reg: Node_ID, lhs: Node_ID, rhs: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Ideal_Node_Type.Phi), dt, {reg, lhs, rhs})
}
#assert(size_of(No_Extra) % PRECISION == 0)
graph_add_mem :: #force_inline proc(graph: ^Graph, name: string, ctrl: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Ideal_Node_Type.Mem), .Void, {ctrl})
}
#assert(size_of(No_Extra) % PRECISION == 0)
graph_add_sym :: #force_inline proc(graph: ^Graph, name: string, entry: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Ideal_Node_Type.Sym), .Void, {entry})
}
#assert(size_of(Local) % PRECISION == 0)
graph_add_local :: #force_inline proc(graph: ^Graph, name: string, mem: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^Local)(graph_get_next_extra_slot(graph, u16(Ideal_Node_Type.Local)))^ = {}
	return graph_add_raw(graph, u16(Ideal_Node_Type.Local), .Void, {mem})
}
#assert(size_of(No_Extra) % PRECISION == 0)
graph_add_local_addr :: #force_inline proc(graph: ^Graph, name: string, local: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Ideal_Node_Type.Local_Addr), .I64, {local})
}
#assert(size_of(Tup) % PRECISION == 0)
graph_add_global :: #force_inline proc(graph: ^Graph, name: string) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^Tup)(graph_get_next_extra_slot(graph, u16(Ideal_Node_Type.Global)))^ = {}
	return graph_add_raw(graph, u16(Ideal_Node_Type.Global), .Void, {})
}
#assert(size_of(No_Extra) % PRECISION == 0)
graph_add_global_addr :: #force_inline proc(graph: ^Graph, name: string, global: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Ideal_Node_Type.Global_Addr), .I64, {global})
}
#assert(size_of(Tup) % PRECISION == 0)
graph_add_proc_addr :: #force_inline proc(graph: ^Graph, name: string) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^Tup)(graph_get_next_extra_slot(graph, u16(Ideal_Node_Type.Proc_Addr)))^ = {}
	return graph_add_raw(graph, u16(Ideal_Node_Type.Proc_Addr), .I64, {})
}
#assert(size_of(No_Extra) % PRECISION == 0)
graph_add_copy :: #force_inline proc(graph: ^Graph, name: string, ctrl: Node_ID, mem: Node_ID, dst: Node_ID, src: Node_ID, size: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Ideal_Node_Type.Copy), .Void, {ctrl, mem, dst, src, size})
}
#assert(size_of(No_Extra) % PRECISION == 0)
graph_add_set :: #force_inline proc(graph: ^Graph, name: string, ctrl: Node_ID, mem: Node_ID, dst: Node_ID, value: Node_ID, size: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Ideal_Node_Type.Set), .Void, {ctrl, mem, dst, value, size})
}
#assert(size_of(No_Extra) % PRECISION == 0)
graph_add_store :: #force_inline proc(graph: ^Graph, name: string, ctrl: Node_ID, mem: Node_ID, addr: Node_ID, value: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Ideal_Node_Type.Store), .Void, {ctrl, mem, addr, value})
}
#assert(size_of(No_Extra) % PRECISION == 0)
graph_add_load :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype, ctrl: Node_ID, mem: Node_ID, addr: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Ideal_Node_Type.Load), dt, {ctrl, mem, addr})
}
#assert(size_of(No_Extra) % PRECISION == 0)
graph_add_load_s :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype, ctrl: Node_ID, mem: Node_ID, addr: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(Ideal_Node_Type.Load_S), dt, {ctrl, mem, addr})
}
#assert(size_of(Cfg) % PRECISION == 0)
graph_add_if :: #force_inline proc(graph: ^Graph, name: string, ctrl: Node_ID, cond: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^Cfg)(graph_get_next_extra_slot(graph, u16(Ideal_Node_Type.If)))^ = {}
	return graph_add_raw(graph, u16(Ideal_Node_Type.If), .Void, {ctrl, cond})
}
#assert(size_of(Cfg) % PRECISION == 0)
graph_add_then :: #force_inline proc(graph: ^Graph, name: string, ctrl: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^Cfg)(graph_get_next_extra_slot(graph, u16(Ideal_Node_Type.Then)))^ = {}
	return graph_add_raw(graph, u16(Ideal_Node_Type.Then), .Void, {ctrl})
}
#assert(size_of(Cfg) % PRECISION == 0)
graph_add_else :: #force_inline proc(graph: ^Graph, name: string, ctrl: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^Cfg)(graph_get_next_extra_slot(graph, u16(Ideal_Node_Type.Else)))^ = {}
	return graph_add_raw(graph, u16(Ideal_Node_Type.Else), .Void, {ctrl})
}
#assert(size_of(Cfg) % PRECISION == 0)
graph_add_jump :: #force_inline proc(graph: ^Graph, name: string, ctrl: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^Cfg)(graph_get_next_extra_slot(graph, u16(Ideal_Node_Type.Jump)))^ = {}
	return graph_add_raw(graph, u16(Ideal_Node_Type.Jump), .Void, {ctrl})
}
#assert(size_of(Cfg) % PRECISION == 0)
graph_add_region :: #force_inline proc(graph: ^Graph, name: string, inputs: []Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^Cfg)(graph_get_next_extra_slot(graph, u16(Ideal_Node_Type.Region)))^ = {}
	return graph_add_raw(graph, u16(Ideal_Node_Type.Region), .Void, inputs)
}
#assert(size_of(Cfg) % PRECISION == 0)
graph_add_loop :: #force_inline proc(graph: ^Graph, name: string, ctrl: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^Cfg)(graph_get_next_extra_slot(graph, u16(Ideal_Node_Type.Loop)))^ = {}
	return graph_add_raw(graph, u16(Ideal_Node_Type.Loop), .Void, {ctrl}, extra_capacity = 1)
}
#assert(size_of(Cfg) % PRECISION == 0)
graph_add_always :: #force_inline proc(graph: ^Graph, name: string, ctrl: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^Cfg)(graph_get_next_extra_slot(graph, u16(Ideal_Node_Type.Always)))^ = {}
	return graph_add_raw(graph, u16(Ideal_Node_Type.Always), .Void, {ctrl})
}
#assert(size_of(Cfg) % PRECISION == 0)
graph_add_trap :: #force_inline proc(graph: ^Graph, name: string, ctrl: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^Cfg)(graph_get_next_extra_slot(graph, u16(Ideal_Node_Type.Trap)))^ = {}
	return graph_add_raw(graph, u16(Ideal_Node_Type.Trap), .Void, {ctrl})
}
#assert(size_of(Call) % PRECISION == 0)
graph_add_call :: #force_inline proc(graph: ^Graph, name: string, inputs: []Node_ID, cid: u32) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^Call)(graph_get_next_extra_slot(graph, u16(Ideal_Node_Type.Call)))^ = {
		cid = cid
	}
	return graph_add_raw(graph, u16(Ideal_Node_Type.Call), .Void, inputs)
}
#assert(size_of(Cfg) % PRECISION == 0)
graph_add_call_end :: #force_inline proc(graph: ^Graph, name: string, call: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^Cfg)(graph_get_next_extra_slot(graph, u16(Ideal_Node_Type.Call_End)))^ = {}
	return graph_add_raw(graph, u16(Ideal_Node_Type.Call_End), .Void, {call})
}
#assert(size_of(Tup) % PRECISION == 0)
graph_add_ret :: #force_inline proc(graph: ^Graph, name: string, dt: Node_Datatype, call_end: Node_ID, idx: u32) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^Tup)(graph_get_next_extra_slot(graph, u16(Ideal_Node_Type.Ret)))^ = {
		idx = idx
	}
	return graph_add_raw(graph, u16(Ideal_Node_Type.Ret), dt, {call_end})
}
#assert(size_of(Cfg) % PRECISION == 0)
graph_add_return :: #force_inline proc(graph: ^Graph, name: string, inputs: []Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	(^Cfg)(graph_get_next_extra_slot(graph, u16(Ideal_Node_Type.Return)))^ = {}
	return graph_add_raw(graph, u16(Ideal_Node_Type.Return), .Void, inputs)
}
#assert(size_of(No_Extra) % PRECISION == 0)
graph_add_un_op :: #force_inline proc(graph: ^Graph, name: string, type: Un_Op, dt: Node_Datatype, oprnd: Node_ID) -> (id: Node_ID) {
	push_node_name(graph, name)
	return graph_add_raw(graph, u16(type), dt, {oprnd})
}
#assert(size_of(No_Extra) % PRECISION == 0)
#assert(size_of(No_Extra) % PRECISION == 0)
#assert(size_of(No_Extra) % PRECISION == 0)
#assert(size_of(No_Extra) % PRECISION == 0)
#assert(size_of(No_Extra) % PRECISION == 0)
#assert(size_of(No_Extra) % PRECISION == 0)
#assert(size_of(No_Extra) % PRECISION == 0)
#assert(size_of(No_Extra) % PRECISION == 0)

inherit_idx_of :: #force_inline proc($T: typeid) -> u8 {
	when false {}
	else when T == CInt {return 3}
	else when T == Tup {return 2}
	else when T == Local {return 4}
	else when T == Cfg {return 0}
	else when T == No_Extra {return 1}
	else when T == Call {return 5}
	else {#panic(`the passed type is not subclass of anything`)}
}
}
