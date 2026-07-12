package main

import "backend"
import "base:runtime"
import "core:fmt"
import "core:mem"
import "core:odin/ast"
import "core:odin/tokenizer"
import "core:slice"
import "core:strconv"
import "meta"
import "vendored/gam/util/arna"

Opt_Level :: struct {
	name:  string,
	flags: backend.Graph_Opt_Flags,
}

Abi_Param :: struct {
	size:    int,
	spilled: bool,
	copied:  bool,
	by_ptr:  bool,
	scalar:  bool,
	dt:      backend.Node_Datatype,
}

Abi_Param2 :: struct {
	size:    int,
	spilled: bool,
	copied:  bool,
	by_ptr:  bool,
	scalar:  bool,
	dt:      [dynamic; 2]backend.Node_Datatype,
}

Abi_Type :: enum int {
	Odin,
	C,
}

Abi_Sm :: struct {
	type:      Abi_Type,
	used_regs: [backend.Reg_Kind]int,
}

X86_Reg_Class :: enum u8 {
	No_Class,
	Sse_32,
	Sse,
	Sse_Up,
	Integer,
}

x86_reg_class_classify :: proc(
	ty: Type,
) -> (
	slots: [dynamic; 2]backend.Node_Datatype,
	ok: bool,
) {
	MAX_SIZE :: 512 / 64
	class_slots: [MAX_SIZE]X86_Reg_Class

	size := type_size(ty)

	if size > MAX_SIZE * 8 do return

	classify(ty, class_slots[:]) or_return

	relevant := class_slots[:(size + 7) / 8]

	assert(!slice.contains(relevant, X86_Reg_Class.Sse_Up), "TODO")

	if len(relevant) > 2 do return

	@(static, rodata)
	X86_REG_CLASS_TO_DT := #partial [X86_Reg_Class]backend.Node_Datatype {
		.Integer = .I64,
		.Sse_32  = .F32,
		.Sse     = .F64,
	}

	for v in relevant {
		dt := X86_REG_CLASS_TO_DT[v]
		append(&slots, dt)
	}

	ok = true
	return

	classify :: proc(
		ty: Type,
		slots: []X86_Reg_Class,
		offset: int = 0,
	) -> bool {
		mem.is_aligned(rawptr(uintptr(offset)), type_align(ty)) or_return

		switch t in unpack_type(ty) {
		case Builtin:
			@(static, rodata)
			TYPE_TO_REGLCASS := [Type]X86_Reg_Class {
				.Void   = .No_Class,
				.Bool ..= .Uintptr        = .Integer,
				.String = .Integer,
				.F32    = .Sse_32,
				.F64    = .Sse,
			}

			if slots[offset / 8] == .Sse_32 do slots[offset / 8] = .Sse
			slots[offset / 8] = max(slots[offset / 8], TYPE_TO_REGLCASS[ty])
			if t == .String do slots[offset / 8 + 1] = .Integer
		case Pointer, Multi_Pointer:
			slots[offset / 8] = .Integer
		case ^Slice:
			slots[offset / 8] = .Integer
			slots[offset / 8 + 1] = .Integer
		case ^Struct:
			for f in t.fields {
				classify(f.ty, slots, offset + f.offset) or_return
			}
		case ^Array:
			step := type_size(t.elem)
			for i in 0 ..< t.len {
				classify(t.elem, slots, offset + i * step) or_return
			}
		case ^Lit:
			panic("should not happen")
		}

		return true
	}
}

abi_sm_add2 :: proc(
	ctx: ^Gen_Ctx,
	sm: ^Abi_Sm,
	ty: Type,
) -> (
	par: Abi_Param2,
	ok: bool,
) {
	cata, oka := x86_reg_class_classify(ty)

	par.dt = cata

	par.size = type_size(ty)
	forced_stack := type_to_dt(ty) == .Void
	par.scalar = !forced_stack

	if !oka {
		switch sm.type {
		case .Odin:
			par.by_ptr = true
			par.scalar = true
			par.dt = {.I64}
			par.size = 0
		case .C:
			par.spilled = true
			par.size = 0
		}
		ok = true
		return
	}

	for p in cata {
		rk := ctx.cc_dt_to_reg_kind[p]
		par.spilled |= sm.used_regs[rk] >= len(ctx.cc.args[rk])
		sm.used_regs[rk] += 1
	}

	if par.spilled {
		for p in cata {
			rk := ctx.cc_dt_to_reg_kind[p]
			sm.used_regs[rk] -= 1
		}
	}

	par.copied |= len(par.dt) > 1 && !par.spilled
	par.copied |= len(par.dt) == 1 && forced_stack

	ok = len(par.dt) != 0
	if !par.copied do par.size = 0
	if par.scalar do par.dt = {type_to_dt(ty)}
	return
}

abi_sm_add :: proc(
	ctx: ^Gen_Ctx,
	sm: ^Abi_Sm,
	ty: Type,
) -> (
	par: Abi_Param,
	ok: bool = true,
) {
	cata, oka := x86_reg_class_classify(ty)

	par.size = type_size(ty)
	par.dt = type_to_dt(ty)
	forced_stack := par.dt == .Void
	if par.size > 16 do par.dt = .I64
	rk := ctx.cc_dt_to_reg_kind[par.dt]

	par.scalar = !forced_stack
	par.spilled = sm.used_regs[rk] >= len(ctx.cc.args[rk])
	switch par.size {
	case 0:
		assert(len(cata) == 0)
		return {}, false
	case 1 ..= 8:
		assert(len(cata) == 1)
		assert(ctx.cc_dt_to_reg_kind[cata[0]] == rk)
		par.copied = forced_stack
		sm.used_regs[rk] += 1
	case 9 ..= 16:
		assert(len(cata) == 2)
		assert(ctx.cc_dt_to_reg_kind[cata[0]] == rk)
		assert(ctx.cc_dt_to_reg_kind[cata[1]] == rk)
		par.spilled = sm.used_regs[rk] + 1 >= len(ctx.cc.args[rk])
		par.copied = !par.spilled
		if !par.spilled do sm.used_regs[rk] += 2
	case 17 ..= int(~uint(0) >> 1):
		assert(!oka)
		par.by_ptr = true
		par.scalar = true
	}

	if !par.copied do par.size = 0

	return
}

Mems :: struct {
	graph:    arna.Allocator,
	regalloc: arna.Allocator,
	scratch:  arna.Allocator,
	code:     arna.Allocator,
	reloc:    arna.Allocator,
	type:     arna.Allocator,
}

Gen_Ctx :: struct {
	using global:      ^Global_Ctx,
	using types:       ^Types,
	using graph:       backend.Graph,
	cc:                ^backend.Call_Conv,
	cc_dt_to_reg_kind: ^[backend.Node_Datatype]backend.Reg_Kind,
	node_scope:        backend.Node_ID,
	root_mem:          backend.Node_ID,
	mem_slot:          int,
	loop:              ^Loop_State,
	file:              ^ast.File,
	file_id:           File_ID,
	module:            Module_ID,
	prc:               Proc_ID,
	ret_ptrs:          []backend.Node_ID,
}

Loop_Control :: enum int {
	Break,
	Continue,
}

Loop_State :: struct {
	parent:       ^Loop_State,
	label:        string,
	using bstate: backend.Loop_State,
}

Propagation :: struct {
	dest: backend.Node_ID,
}

Ty_Propagation :: struct {
	inferred_ty: Type,
	referencing: bool,
}

ctx_ctrl :: proc(ctx: ^Gen_Ctx) -> backend.Node_ID {
	return backend.graph_inps(ctx, ctx.node_scope)[0]
}

ctx_mem :: proc(ctx: ^Gen_Ctx) -> backend.Node_ID {
	return backend.graph_get_scope_value(ctx, ctx.node_scope, ctx.mem_slot)
}

ctx_set_mem :: proc(ctx: ^Gen_Ctx, mem: backend.Node_ID) {
	backend.graph_set_input(ctx, ctx.node_scope, ctx.mem_slot, mem)
}

Value :: bit_field u32 {
	id:        backend.Node_ID | 31,
	is_lvalue: bool            | 1,
}

to_rvalue_ty :: proc(
	ctx: ^Gen_Ctx,
	value: Value,
	ty: Type,
) -> backend.Node_ID {
	if !value.is_lvalue do return value.id
	dt := type_to_dt(ty)
	assert(dt != .Void)
	if is_signed_subword(ty) {
		return backend.graph_add_load_s(
			ctx,
			"sltr",
			dt,
			ctx_ctrl(ctx),
			ctx_mem(ctx),
			value.id,
		)
	}
	return field_load(ctx, "ultr", dt, value.id)
}

to_rvalue :: proc {
	to_rvalue_ty,
	to_rvalue_expr,
}

to_rvalue_expr :: proc(
	ctx: ^Gen_Ctx,
	value: Value,
	node: ^ast.Node,
) -> backend.Node_ID {
	return to_rvalue(ctx, value, get_node_type(node))
}

is_signed_subword :: proc(ty: Type) -> bool {
	bt := unpack_type(ty).(Builtin) or_return
	return Type(bt) in SIGNED_TYPES && backend.DT_SIZE[type_to_dt(ty)] < 8
}

tok_to_binop :: proc(
	ty: Type,
	tok: tokenizer.Token_Kind,
) -> (
	kind: backend.Bin_Op,
	name: string,
) {
	Op_Info :: struct {
		kind: backend.Bin_Op,
		name: string,
	}

	@(static)
	@(rodata)
	SIGNED_TABLE := #partial [tokenizer.Token_Kind]Op_Info {
		.Add        = {.Add, "add"},
		.Add_Eq     = {.Add, "adde"},
		.Sub        = {.Sub, "sub"},
		.Sub_Eq     = {.Sub, "sube"},
		.Mul        = {.Mul, "mul"},
		.Mul_Eq     = {.Mul, "mule"},
		.Cmp_Eq     = {.Eq, "eq"},
		.Not_Eq     = {.Ne, "ne"},
		.Lt         = {.Lt, "lt"},
		.Lt_Eq      = {.Le, "le"},
		.Gt         = {.Gt, "gt"},
		.Gt_Eq      = {.Ge, "ge"},
		.Quo        = {.Div, "div"},
		.Quo_Eq     = {.Div, "dive"},
		.Mod        = {.Rem, "rem"},
		.Mod_Eq     = {.Rem, "reme"},
		.And        = {.And, "and"},
		.And_Eq     = {.And, "ande"},
		.Or         = {.Or, "or"},
		.Or_Eq      = {.Or, "ore"},
		.Xor        = {.Xor, "xor"},
		.Xor_Eq     = {.Xor, "xore"},
		.And_Not    = {.And_Not, "andn"},
		.And_Not_Eq = {.And_Not, "andne"},
		.Shl        = {.Shl, "shl"},
		.Shl_Eq     = {.Shl, "shle"},
		.Shr        = {.Shr, "shr"},
		.Shr_Eq     = {.Shr, "shre"},
	}

	@(static)
	@(rodata)
	UNSIGNED_TABLE := #partial [tokenizer.Token_Kind]Op_Info {
		.Lt     = {.U_Lt, "ltu"},
		.Lt_Eq  = {.U_Le, "leu"},
		.Gt     = {.U_Gt, "gtu"},
		.Gt_Eq  = {.U_Ge, "geu"},
		.Quo    = {.U_Div, "divu"},
		.Quo_Eq = {.U_Div, "diveu"},
		.Mod    = {.U_Rem, "remu"},
		.Mod_Eq = {.U_Rem, "remeu"},
		.Shr    = {.U_Shr, "shru"},
		.Shr_Eq = {.U_Shr, "shreu"},
	}

	@(static)
	@(rodata)
	FLOAT_TABLE := #partial [tokenizer.Token_Kind]Op_Info {
		.Add    = {.F_Add, "fadd"},
		.Add_Eq = {.F_Add, "fadde"},
		.Sub    = {.F_Sub, "fsub"},
		.Sub_Eq = {.F_Sub, "fsube"},
		.Mul    = {.F_Mul, "fmul"},
		.Mul_Eq = {.F_Mul, "fmule"},
		.Quo    = {.F_Div, "fdiv"},
		.Quo_Eq = {.F_Div, "fdive"},
		.Cmp_Eq = {.F_Eq, "feq"},
		.Not_Eq = {.F_Ne, "fne"},
		.Lt     = {.F_Lt, "flt"},
		.Lt_Eq  = {.F_Le, "fle"},
		.Gt     = {.F_Gt, "fgt"},
		.Gt_Eq  = {.F_Ge, "fge"},
	}

	if ty in FLOAT_TYPES {
		finfo := FLOAT_TABLE[tok]
		return finfo.kind, finfo.name
	}

	info := SIGNED_TABLE[tok]
	uinfo := UNSIGNED_TABLE[tok]
	if ty in UNSIGNED_TYPES && uinfo.kind != {} do info = uinfo
	return info.kind, info.name
}

emit_float_const :: proc(
	ctx: ^Gen_Ctx,
	dt: backend.Node_Datatype,
	value: f64,
) -> backend.Node_ID {
	return backend.graph_add_c_int(ctx, "fbits", dt, transmute(i64)value)
}

Sym :: union #no_nil {
	Value,
	int,
}

module_const_lit :: proc(ctx: ^Gen_Ctx, id: ^ast.Ident) -> (^ast.Node, bool) {
	#reverse for var in ctx.scope {
		if var.name == id.name do return nil, false
	}
	if _, ok := find_module_global(ctx, ctx.module, id.name); ok {
		return nil, false
	}
	if sdecl, _, _, ok := find_module_decl(ctx, ctx.module, id.name); ok {
		if len(sdecl.values) == 1 {
			if _, is_lit := sdecl.values[0].derived.(^ast.Basic_Lit); is_lit {
				return sdecl.values[0], true
			}
		}
	}
	return nil, false
}

ctx_lookup_lvalue :: proc(ctx: ^Gen_Ctx, expr: ^ast.Node) -> Sym {
	if id, ok := expr.derived.(^ast.Ident); ok {
		#reverse for var in ctx.scope {
			if var.name == id.name {
				switch idx in var.idx {
				case int:
					return idx
				case backend.Node_ID:
					return Value{id = idx, is_lvalue = true}
				}
			}
		}

		switch id.name {
		case "false":
			return Value(backend.graph_add_c_int(ctx, "false", .I8, 0))
		case "true":
			return Value(backend.graph_add_c_int(ctx, "true", .I8, 1))
		}

		if gv, ok := find_module_global(ctx, ctx.module, id.name); ok {
			g := backend.graph_add_global(ctx, gv.name)
			backend.graph_extra(ctx, g, backend.Tup).idx = gv.idx
			ptr := backend.graph_add_global_addr(ctx, gv.name, g)
			return Value{id = ptr, is_lvalue = true}
		}

		fmt.panicf("TODO: undefined variable: %v %#v", id.name, expr)
	} else {
		return emit_nodes(ctx, {}, expr)
	}
}

store_value :: proc {
	store_value_ty,
	store_value_expr,
}

store_value_expr :: proc(
	ctx: ^Gen_Ctx,
	name: string,
	ptr: backend.Node_ID,
	value: Value,
	node: ^ast.Node,
) {
	store_value(ctx, name, ptr, value, get_node_type(node))
}

store_value_ty :: proc(
	ctx: ^Gen_Ctx,
	name: string,
	ptr: backend.Node_ID,
	value: Value,
	ty: Type,
) {
	if ptr == value.id && value.is_lvalue {
		return
	}

	if type_to_dt(ty) == .Void {
		fmt.assertf(value.is_lvalue, "%v %v", value, ty)
		ctx_set_mem(
			ctx,
			backend.graph_add_copy(
				ctx,
				name,
				ctx_ctrl(ctx),
				ctx_mem(ctx),
				ptr,
				value.id,
				backend.graph_add_c_int(
					ctx,
					"msize",
					.I32,
					i64(type_size(ty)),
				),
			),
		)
	} else {
		field_store(ctx, name, ptr, 0, to_rvalue(ctx, value, ty))
	}
}

alloca :: proc(
	ctx: ^Gen_Ctx,
	name: string,
	ty: Type,
	zeroed := true,
	is_arg := false,
) -> backend.Node_ID {
	root := is_arg ? ctx.entry : ctx.root_mem
	alloca := backend.graph_add_local(ctx, name, root)
	backend.graph_extra(ctx, alloca, backend.Local).size = i32(type_size(ty))
	ptr := backend.graph_add_local_addr(ctx, name, alloca)

	if zeroed {
		zero := backend.graph_add_c_int(ctx, "zero", .I8, 0)
		size := backend.graph_add_c_int(ctx, "size", .I32, i64(type_size(ty)))
		ctx_set_mem(
			ctx,
			backend.graph_add_set(
				ctx,
				"zinit",
				ctx_ctrl(ctx),
				ctx_mem(ctx),
				ptr,
				zero,
				size,
			),
		)
	}

	return ptr
}

is_static :: proc(d: ^ast.Value_Decl) -> bool {
	for attr in d.attributes {
		for elem in attr.elems {
			if id, ok := elem.derived.(^ast.Ident); ok {
				if id.name == "static" do return true
			}
		}
	}
	return false
}

const_eval_int :: proc(node: ^ast.Expr) -> (value: i64, ok: bool) {
	#partial switch d in node.derived {
	case ^ast.Basic_Lit:
		if d.tok.kind != .Integer do return 0, false
		return i64(strconv.parse_u64(d.tok.text) or_return), true
	case ^ast.Unary_Expr:
		if d.op.text != "-" do return 0, false
		inner := const_eval_int(d.expr) or_return
		return -inner, true
	case ^ast.Paren_Expr:
		return const_eval_int(d.expr)
	}
	return 0, false
}

emit_module_globals :: proc(ctx: ^Gen_Ctx) {
	for &gv in ctx.global_vars {
		size := type_size(gv.type)
		bytes := make([]u8, size, ctx.globals.allocator)

		if gv.init != nil && type_to_dt(gv.type) != .Void {
			value, cok := const_eval_int(gv.init)
			if !cok {
				fmt.panicf(
					"TODO: non-constant global initializer: %v",
					gv.name,
				)
			}
			val_bytes := transmute([8]u8)value
			copy(bytes, val_bytes[:size])
		}

		gv.idx = add_global(ctx, bytes, type_align(gv.type))
	}
}

add_global :: proc(ctx: ^Gen_Ctx, bytes: []u8, align: int) -> u32 {
	idx := u32(len(ctx.globals))
	append(&ctx.globals, Global_Data{bytes = bytes, align = align})
	return idx
}

field_offset :: proc(
	ctx: ^Gen_Ctx,
	base: backend.Node_ID,
	offset: int,
) -> backend.Node_ID {
	if offset == 0 do return base
	off := backend.graph_add_c_int(ctx, "foff", .I64, i64(offset))
	return backend.graph_add_bin_op(ctx, "fld", .Add, .I64, base, off)
}

field_store :: proc(
	ctx: ^Gen_Ctx,
	name: string,
	base: backend.Node_ID,
	offset: int,
	value: backend.Node_ID,
) {
	ctx_set_mem(
		ctx,
		backend.graph_add_store(
			ctx,
			name,
			ctx_ctrl(ctx),
			ctx_mem(ctx),
			field_offset(ctx, base, offset),
			value,
		),
	)
}

field_load :: proc(
	ctx: ^Gen_Ctx,
	name: string,
	dt: backend.Node_Datatype,
	base: backend.Node_ID,
	offset: int = 0,
) -> backend.Node_ID {
	return backend.graph_add_load(
		ctx,
		name,
		dt,
		ctx_ctrl(ctx),
		ctx_mem(ctx),
		field_offset(ctx, base, offset),
	)
}

index_offset :: proc(
	ctx: ^Gen_Ctx,
	base: backend.Node_ID,
	index: backend.Node_ID,
	stride: int,
) -> backend.Node_ID {
	if stride == 0 do return base

	index := index
	if stride > 1 {
		index = backend.graph_add_bin_op(
			ctx,
			"snoff",
			.Mul,
			.I64,
			index,
			backend.graph_add_c_int(ctx, "sst", .I64, i64(stride)),
		)
	}

	return backend.graph_add_bin_op(ctx, "snd", .Add, .I64, base, index)
}

emit_proc :: proc(
	ctx: ^Gen_Ctx,
	prc: ^Proc,
	i: int,
	level: Opt_Level,
	emit_ctx: ^backend.Codegen_Emit_Ctx,
) {
	ctx.prc = auto_cast i
	ctx.module = prc.module
	ctx.file = prc.file
	ctx.file_id = prc.file_id
	ctx.graph = {}
	ctx.node_spec = &backend.SPECS[.Builder]
	ctx.mem = &ctx.mems.graph
	ctx.mem.pos = backend.PRECISION
	ctx.opt_flags = level.flags
	ctx.stats = &ctx.tstats

	backend.current_graph = ctx

	clear(&ctx.scope)

	ctx.start = backend.graph_add_start(ctx, "start")
	ctx.entry = backend.graph_add_entry(ctx, "entry", ctx.start)
	ctx.root_mem = backend.graph_add_mem(ctx, "emem", ctx.entry)

	ctx.node_scope = backend.graph_add_scope(ctx, "scope", ctx.entry)
	ctx.mem_slot = backend.graph_push_scope_value(
		ctx,
		ctx.node_scope,
		ctx.root_mem,
	)

	rabi := ret_abi(prc.rets[:])
	ctx.ret_ptrs = nil

	sm: Abi_Sm
	arg_cnts: [backend.Reg_Kind]u32

	ctx.ret_ptrs = make(
		[]backend.Node_ID,
		len(rabi.extras),
		context.temp_allocator,
	)

	for j in rabi.srets_start ..< len(rabi.extras) {
		ctx.ret_ptrs[j] = backend.graph_add_arg(
			ctx,
			"sret",
			.I64,
			ctx.entry,
			arg_cnts[.General],
		)
		arg_cnts[.General] += 1
		backend.graph_pin(ctx, ctx.ret_ptrs[j])
		apa := abi_sm_add2(ctx, &sm, .I64) or_else panic("")
		assert(!apa.spilled && !apa.by_ptr)
	}

	for par in prc.params {
		apa := abi_sm_add2(ctx, &sm, par.type) or_continue

		value: backend.Node_ID
		if apa.scalar {
			dt := apa.dt[0]
			bank := ctx.cc_dt_to_reg_kind[dt]
			value = backend.graph_add_arg(
				ctx,
				"arg",
				dt,
				ctx.entry,
				arg_cnts[bank],
			)
			arg_cnts[bank] += 1
		} else {
			value = alloca(
				ctx,
				"sarg",
				par.type,
				zeroed = false,
				is_arg = !apa.copied,
			)
		}

		for dt, j in apa.dt[:(apa.size + 7) / 8] {
			bank := ctx.cc_dt_to_reg_kind[dt]
			vl := backend.graph_add_arg(
				ctx,
				"arg",
				dt,
				ctx.entry,
				arg_cnts[bank],
			)
			arg_cnts[bank] += 1
			emit_arbitrary_store(ctx, value, vl, apa.size, j * 8, dt)
		}

		value_idx: Varuable_Idx
		if apa.scalar && !apa.by_ptr {
			value_idx = backend.graph_push_scope_value(
				ctx,
				ctx.node_scope,
				value,
			)
		} else {
			value_idx = value
		}

		append(&ctx.scope, Variable{par.name, value_idx, par.type, nil, {}})
	}

	for j in 0 ..< rabi.srets_start {
		ctx.ret_ptrs[j] = backend.graph_add_arg(
			ctx,
			"retp",
			.I64,
			ctx.entry,
			arg_cnts[.General],
		)
		arg_cnts[.General] += 1
		backend.graph_pin(ctx, ctx.ret_ptrs[j])
		_ = abi_sm_add2(ctx, &sm, .I64) or_else panic("")
	}

	emit_nodes(ctx, {}, prc.lit.body)

	for ptr in ctx.ret_ptrs {
		backend.graph_unpin(ctx, ptr)
	}

	if ctx.node_scope != 0 {
		assert(len(prc.rets) == 0)
		values := [2]backend.Node_ID{ctx_ctrl(ctx), ctx_mem(ctx)}
		backend.graph_merge_returns(ctx, values[:])
		backend.graph_delete(ctx, ctx.node_scope)
		ctx.node_scope = 0
	}

	backend.graph_iter_peeps(ctx)
	backend.memopt(ctx)

	backend.graph_iter_peeps(ctx)

	spec := &backend.SPECS[.X64]
	ctx.node_spec = spec

	backend.graph_iter_peeps(ctx)

	backend.graph_poll_gc(ctx)

	ctx.mems.scratch.pos = 0

	schedule: backend.Graph_Schedule
	backend.graph_schedule(ctx, &schedule, arna.allocator(&ctx.mems.scratch))

	backend.graph_schedule_peeps(ctx, &schedule)

	ra: backend.Regalloc
	ra.spec = spec
	ra.cc = &backend.X64_SYSTEMV_CC

	regs := backend.regalloc(
		&ra,
		ctx,
		&schedule,
		arna.allocator(&ctx.mems.scratch),
	)

	emit_ctx.graph = ctx
	emit_ctx.schedule = &schedule
	emit_ctx.abi = ra.cc
	emit_ctx.buf = {
		code   = &ctx.mems.code,
		relocs = &ctx.mems.reloc,
	}
	emit_ctx.allocs = regs

	prc.out = spec.emit_function(emit_ctx^)
}

emit_nodes :: proc(
	ctx: ^Gen_Ctx,
	prop: Propagation,
	node: ^ast.Node,
) -> Value {
	if node == nil do return {}

	ty := get_node_type(node)
	dt := type_to_dt(ty)

	res: backend.Node_ID
	lvalue: bool

	unpack :: proc(vl: Value) -> (backend.Node_ID, bool) {
		return vl.id, vl.is_lvalue
	}

	tmp, _ := arna.scrath(context.temp_allocator)

	#partial match: switch d in node.derived {
	case ^ast.Block_Stmt:
		prev_local_scope_len := len(ctx.scope)
		prev_scope_len := backend.graph_get(ctx, ctx.node_scope).input_count
		for stmt in d.stmts {
			emit_nodes(ctx, {}, stmt)
			if ctx.node_scope == 0 do break
		}
		for v in ctx.scope[prev_local_scope_len:] {
			switch n in v.idx {
			case backend.Node_ID:
				backend.graph_unpin(ctx, n)
			case int:
			}
		}
		resize(&ctx.scope, prev_local_scope_len)
		backend.graph_truncate_scope(ctx, ctx.node_scope, prev_scope_len)
	case ^ast.Expr_Stmt:
		node := emit_nodes(ctx, {}, d.expr)
		if node.id != 0 {
			backend.graph_delete(ctx, node.id)
		}
	case ^ast.Assign_Stmt:
		if len(d.rhs) == 1 && len(d.lhs) > 1 {
			assert(d.op.kind == .Eq)
			prc, ok := call_proc_of(ctx, d.rhs[0])
			assert(ok)
			assert(len(prc.rets) == len(d.lhs))
			rabi := ret_abi(prc.rets[:])

			syms := make([]Sym, len(d.lhs), tmp)
			out_slots := make([]backend.Node_ID, len(d.lhs), tmp)
			for lhs, i in d.lhs {
				if id, iok := lhs.derived.(^ast.Ident); iok && id.name == "_" {
					continue
				}
				syms[i] = ctx_lookup_lvalue(ctx, lhs)
				if v, vok := syms[i].(Value);
				   vok && ret_is_by_pointer(rabi, i) {
					out_slots[i] = v.id
				}
			}

			results := emit_call(
				ctx,
				d.rhs[0].derived.(^ast.Call_Expr),
				prc,
				out_slots,
			)

			for r, i in results {
				if id, iok := d.lhs[i].derived.(^ast.Ident);
				   iok && id.name == "_" {
					continue
				}
				vty := prc.rets[i].type
				switch sym in syms[i] {
				case int:
					rv := to_rvalue_ty(ctx, r, vty)
					backend.graph_set_input(ctx, ctx.node_scope, sym, rv)
				case Value:
					store_value(ctx, "masss", sym.id, r, vty)
				}
			}
			break
		}

		assert(len(d.lhs) == len(d.rhs))
		Value_Slot :: struct {
			idx: int,
			vl:  backend.Node_ID,
		}
		values := make([dynamic]Value_Slot, 0, len(d.lhs), tmp)
		Mem_Store :: struct {
			ptr: backend.Node_ID,
			vl:  backend.Node_ID,
			lhs: ^ast.Node,
		}
		mem_stores := make([dynamic]Mem_Store, 0, len(d.lhs), tmp)

		for i in 0 ..< len(d.lhs) {
			lhs := d.lhs[i]
			rhs := d.rhs[i]
			if id, iok := lhs.derived.(^ast.Ident); iok && id.name == "_" {
				node := emit_nodes(ctx, {}, rhs)
				if node.id != 0 {
					backend.graph_delete(ctx, node.id)
				}
				continue
			}
			sym := ctx_lookup_lvalue(ctx, lhs)
			switch sym in sym {
			case int:
				value := to_rvalue(
					ctx,
					emit_nodes(ctx, {}, rhs),
					get_node_type(rhs),
				)
				if d.op.kind != .Eq {
					op, name := tok_to_binop(get_node_type(rhs), d.op.kind)
					value = auto_cast backend.graph_add_bin_op(
						ctx,
						name,
						op,
						type_to_dt(get_node_type(lhs)),
						backend.graph_get_scope_value(
							ctx,
							ctx.node_scope,
							sym,
						),
						value,
					)
				}

				backend.graph_pin(ctx, value)

				append(&values, Value_Slot{sym, value})
			case Value:
				assert(sym.is_lvalue)
				if d.op.kind == .Eq {
					if len(d.lhs) == 1 {
						value := emit_nodes(ctx, {dest = sym.id}, rhs)
						store_value(ctx, "asss", sym.id, value, lhs)
					} else {
						value := to_rvalue(
							ctx,
							emit_nodes(ctx, {}, rhs),
							get_node_type(rhs),
						)
						backend.graph_pin(ctx, value)
						append(&mem_stores, Mem_Store{sym.id, value, lhs})
					}
				} else {
					op, name := tok_to_binop(get_node_type(rhs), d.op.kind)
					vl := to_rvalue(ctx, sym, rhs)
					backend.graph_pin(ctx, vl)
					value := backend.graph_add_bin_op(
						ctx,
						name,
						op,
						type_to_dt(get_node_type(lhs)),
						vl,
						to_rvalue(
							ctx,
							emit_nodes(ctx, {}, rhs),
							get_node_type(rhs),
						),
					)
					backend.graph_unpin(ctx, vl)
					store_value(ctx, "asss", sym.id, Value(value), lhs)
				}
			}
		}

		for s in values {
			backend.graph_set_input(ctx, ctx.node_scope, s.idx, s.vl)
			backend.graph_unpin(ctx, s.vl)
		}

		for s in mem_stores {
			store_value(ctx, "asss", s.ptr, Value(s.vl), s.lhs)
			backend.graph_unpin(ctx, s.vl)
		}
	case ^ast.Binary_Expr:
		lhsv := emit_nodes(ctx, {}, d.left)
		backend.graph_pin(ctx, lhsv.id)
		rhsv := emit_nodes(ctx, {}, d.right)
		lhs, rhs := to_rvalue(ctx, lhsv, d.left), to_rvalue(ctx, rhsv, d.right)
		kind, name := tok_to_binop(get_node_type(d.left), d.op.kind)
		res = backend.graph_add_bin_op(ctx, name, kind, dt, lhs, rhs)
		backend.graph_unpin(ctx, lhsv.id)
	case ^ast.Unary_Expr:
		#partial switch d.op.kind {
		case .And:
			node := emit_nodes(ctx, {}, d.expr)
			assert(node.is_lvalue)
			res = node.id
		case .Not:
			operand := to_rvalue(ctx, emit_nodes(ctx, {}, d.expr), d.expr)
			zero := backend.graph_add_c_int(ctx, "zero", dt, 0)
			res = backend.graph_add_bin_op(ctx, "lnot", .Eq, dt, operand, zero)
		case .Sub, .Xor:
			oty := get_node_type(d.expr)
			operand := to_rvalue(ctx, emit_nodes(ctx, {}, d.expr), d.expr)

			if d.op.kind == .Sub && dt in backend.FLOAT_DTS {
				zero := emit_float_const(ctx, dt, 0)
				res = backend.graph_add_bin_op(
					ctx,
					"fneg",
					.F_Sub,
					dt,
					zero,
					operand,
				)
				break
			}

			op: backend.Un_Op = d.op.kind == .Sub ? .Neg : .Not
			name := d.op.kind == .Sub ? "neg" : "not"
			res = backend.graph_add_un_op(ctx, name, op, dt, operand)
		case:
			fmt.panicf("TODO: %#v", node.derived)
		}
	case ^ast.Deref_Expr:
		res = to_rvalue(ctx, emit_nodes(ctx, {}, d.expr), d.expr)
		lvalue = true
	case ^ast.Return_Stmt:
		rets := ctx.procs[ctx.prc].rets
		rabi := ret_abi(rets)

		values := make([]backend.Node_ID, 4, tmp)
		i := 2

		emit_reg_ret :: proc(
			ctx: ^Gen_Ctx,
			values: []backend.Node_ID,
			i: ^int,
			r: ^ast.Node,
		) {
			ty := get_node_type(r)
			vl := emit_nodes(ctx, {}, r)
			if type_to_dt(ty) == .Void {
				assert(vl.is_lvalue)
				size := type_size(ty)
				values[i^] = emit_arbitrary_load(ctx, vl.id, size)
				i^ += 1
				if size > 8 {
					values[i^] = emit_arbitrary_load(ctx, vl.id, size, 8)
					i^ += 1
				}
			} else {
				values[i^] = to_rvalue(ctx, vl, r)
				i^ += 1
			}
		}

		for ptr, j in ctx.ret_ptrs {
			r := d.results[j]
			vl := emit_nodes(ctx, {dest = ptr}, r)
			store_value(ctx, "rpst", ptr, vl, get_node_type(r))
		}

		for reg, j in rabi.reg_rets {
			emit_reg_ret(ctx, values, &i, d.results[len(ctx.ret_ptrs) + j])
		}

		values[0] = ctx_ctrl(ctx)
		values[1] = ctx_mem(ctx)
		backend.graph_merge_returns(ctx, values[:i])
		backend.graph_delete(ctx, ctx.node_scope)
		ctx.node_scope = 0
	case ^ast.Basic_Lit:
		#partial switch d.tok.kind {
		case .Integer:
			value, ok := strconv.parse_u64(d.tok.text)
			assert(ok)
			if dt in backend.FLOAT_DTS {
				res = emit_float_const(ctx, dt, f64(value))
			} else {
				res = backend.graph_add_c_int(ctx, "cnst", dt, i64(value))
			}
		case .Float:
			value, ok := strconv.parse_f64(d.tok.text)
			assert(ok)
			res = emit_float_const(ctx, dt, value)
		case .Rune:
			inner := d.tok.text[1:len(d.tok.text) - 1]
			r, _, _, ok := strconv.unquote_char(inner, '\'')
			assert(ok)
			res = backend.graph_add_c_int(ctx, "cnst", dt, i64(r))
		case .String:
			str, _, ok := strconv.unquote_string(
				d.tok.text,
				context.temp_allocator,
			)
			assert(ok)

			idx := add_global(ctx, transmute([]u8)str, 1)
			g := backend.graph_add_global(ctx, "str")
			backend.graph_extra(ctx, g, backend.Tup).idx = idx
			addr := backend.graph_add_global_addr(ctx, "str", g)

			slot := prop.dest
			if slot == 0 do slot = alloca(ctx, "str", .String, zeroed = false)

			field_store(ctx, "sptrst", slot, 0, addr)
			len := backend.graph_add_c_int(ctx, "slenc", .I64, i64(len(str)))
			field_store(ctx, "slenst", slot, 8, len)

			res, lvalue = slot, true
		case:
			fmt.panicf("TODO: %#v", node.derived)
		}
	case ^ast.Value_Decl:
		if len(d.values) == 1 && len(d.names) > 1 {
			prc, ok := call_proc_of(ctx, d.values[0])
			assert(ok)
			assert(len(prc.rets) == len(d.names))

			results := emit_call(
				ctx,
				d.values[0].derived.(^ast.Call_Expr),
				prc,
				nil,
			)

			for r, i in results {
				name := meta.src_of(ctx.file^, d.names[i])
				if name == "_" do continue
				flags := get_node_vflags(d.names[i])
				vty := prc.rets[i].type

				if r.is_lvalue {
					backend.graph_pin(ctx, r.id)
					append(
						&ctx.scope,
						Variable{name, r.id, vty, d.names[i], flags},
					)
				} else {
					backend.graph_set_name(ctx, r.id, name)
					idx := backend.graph_push_scope_value(
						ctx,
						ctx.node_scope,
						r.id,
					)
					append(
						&ctx.scope,
						Variable{name, idx, vty, d.names[i], flags},
					)
				}
			}
			break
		}

		assert(len(d.names) == len(d.values))
		for i in 0 ..< len(d.names) {
			name := meta.src_of(ctx.file^, d.names[i])
			vty := get_node_type(d.values[i])
			flags := get_node_vflags(d.names[i])

			if is_static(d) {
				size := type_size(vty)
				bytes := make([]u8, size, ctx.globals.allocator)

				if type_to_dt(vty) != .Void {
					value, cok := const_eval_int(d.values[i])
					if !cok {
						fmt.panicf(
							"TODO: non-constant static initializer: %v",
							name,
						)
					}
					val_bytes := transmute([8]u8)value
					copy(bytes, val_bytes[:size])
				}

				idx := add_global(ctx, bytes, type_align(vty))
				g := backend.graph_add_global(ctx, name)
				backend.graph_extra(ctx, g, backend.Tup).idx = idx
				ptr := backend.graph_add_global_addr(ctx, name, g)
				backend.graph_pin(ctx, ptr)

				append(&ctx.scope, Variable{name, ptr, vty, d.names[i], flags})
			} else if .Referenced in flags || type_to_dt(vty) == .Void {
				ptr := alloca(
					ctx,
					name,
					vty,
					zeroed = type_to_dt(vty) == .Void,
				)
				backend.graph_pin(ctx, ptr)

				value := emit_nodes(ctx, {dest = ptr}, d.values[i])
				store_value(ctx, "init", ptr, value, vty)

				append(&ctx.scope, Variable{name, ptr, vty, d.names[i], flags})
			} else {
				value := to_rvalue(
					ctx,
					emit_nodes(ctx, {}, d.values[i]),
					d.values[i],
				)
				backend.graph_set_name(ctx, value, name)
				idx := backend.graph_push_scope_value(
					ctx,
					ctx.node_scope,
					value,
				)
				append(&ctx.scope, Variable{name, idx, vty, d.names[i], flags})
			}
		}
	case ^ast.Comp_Lit:
		dest := prop.dest != 0 ? prop.dest : alloca(ctx, "comp", ty)

		#partial switch t in unpack_type(ty) {
		case ^Struct:
			for elem, i in d.elems {
				offset: int
				ast_value: ^ast.Node
				#partial switch e in elem.derived {
				case ^ast.Field_Value:
					offset = get_node_data(e.field, int)
					ast_value = e.value
				case:
					offset = t.fields[i].offset
					ast_value = elem
				}

				field_ptr := field_offset(ctx, dest, offset)
				value := emit_nodes(ctx, {dest = field_ptr}, ast_value)
				store_value(ctx, "finit", field_ptr, value, ast_value)
			}
			res, lvalue = dest, true
		case ^Array:
			stride := array_elem_stride(t.elem)
			for elem, i in d.elems {
				elem_ptr := field_offset(ctx, dest, i * stride)
				value := emit_nodes(ctx, {dest = elem_ptr}, elem)
				store_value(ctx, "ainit", elem_ptr, value, t.elem)
			}
			res, lvalue = dest, true
		case:
			fmt.panicf("TODO: %#v", d)
		}
	case ^ast.Selector_Expr:
		base := emit_nodes(ctx, {}, d.expr)
		base_ty := unpack_type(get_node_type(d.expr))
		#partial switch f in d.field.derived {
		case ^ast.Ident:
			if pty, ok := base_ty.(Pointer); ok {
				base_ty = unpack_type(pty^)
				base.is_lvalue = true
			}

			#partial switch t in base_ty {
			case ^Struct:
				assert(base.is_lvalue)
				offset := get_node_data(d.field, int)
				field_ptr := field_offset(ctx, base.id, offset)
				res, lvalue = field_ptr, true
			case:
				fmt.panicf("TODO: %#v", t)
			}
		case:
			fmt.panicf("TODO: %#v", d.field.derived)
		}
	case ^ast.Index_Expr:
		base := emit_nodes(ctx, {}, d.expr)

		if is_of(get_node_type(d.expr), Multi_Pointer) {
			base = Value(to_rvalue(ctx, base, d.expr))
		} else {
			assert(base.is_lvalue)
		}

		base_ptr := base.id
		base_is_ptr := false
		if is_of(get_node_type(d.expr), ^Slice) ||
		   get_node_type(d.expr) == .String {
			base_ptr = field_load(ctx, "sdata", .I64, base.id)
		}

		idx := to_rvalue(ctx, emit_nodes(ctx, {}, d.index), d.index)

		stride := array_elem_stride(ty)
		res = index_offset(ctx, base_ptr, idx, stride)
		lvalue = true
	case ^ast.Slice_Expr:
		base := emit_nodes(ctx, {}, d.expr)

		stride: int
		#partial switch t in unpack_type(ty) {
		case ^Slice:
			stride = array_elem_stride(t.elem)
		case Builtin:
			assert(t == .String)
			stride = 1
		case:
			fmt.panicf("TODO: slice result %#v", t)
		}

		base_ptr: backend.Node_ID
		src_len: backend.Node_ID
		#partial switch t in unpack_type(get_node_type(d.expr)) {
		case Pointer:
			#partial switch nt in unpack_type(t^) {
			case ^Array:
				base_ptr = to_rvalue(ctx, base, d.expr)
				src_len = backend.graph_add_c_int(
					ctx,
					"alen",
					.I64,
					i64(nt.len),
				)
			case:
				fmt.panicf("TODO: index ptr to type of %#v", t)
			}
		case ^Array:
			base_ptr = base.id
			src_len = backend.graph_add_c_int(ctx, "alen", .I64, i64(t.len))
		case Builtin:
			assert(t == .String)
			assert(base.is_lvalue)
			base_ptr = field_load(ctx, "sdata", .I64, base.id)
			src_len = field_load(ctx, "slen", .I64, base.id, 8)
		case ^Slice:
			assert(base.is_lvalue)
			base_ptr = field_load(ctx, "sdata", .I64, base.id)
			src_len = field_load(ctx, "slen", .I64, base.id, 8)
		case Multi_Pointer:
			base_ptr = to_rvalue(ctx, base, d.expr)
		case:
			fmt.panicf("TODO: slice of %#v", t)
		}

		backend.graph_pin(ctx, base_ptr)
		backend.graph_pin(ctx, src_len)

		low: backend.Node_ID = backend.graph_add_c_int(ctx, "slo", .I64, 0)
		if d.low != nil {
			low = to_rvalue(ctx, emit_nodes(ctx, {}, d.low), d.low)
		}
		backend.graph_pin(ctx, low)

		high := src_len
		if d.high != nil {
			high = to_rvalue(ctx, emit_nodes(ctx, {}, d.high), d.high)
		}
		backend.graph_pin(ctx, high)

		new_data := index_offset(ctx, base_ptr, low, stride)

		dest := new_data
		if high != 0 {
			dest = prop.dest != 0 ? prop.dest : alloca(ctx, "slice", ty)
			field_store(ctx, "sptr", dest, 0, new_data)
			new_len := backend.graph_add_bin_op(
				ctx,
				"snl",
				.Sub,
				.I64,
				high,
				low,
			)
			field_store(ctx, "sptr", dest, 8, new_len)
		}

		backend.graph_unpin(ctx, base_ptr)
		backend.graph_unpin(ctx, src_len)
		backend.graph_unpin(ctx, low)
		backend.graph_unpin(ctx, high)

		res, lvalue = dest, high != 0
	case ^ast.Ident:
		if lit, is_const := module_const_lit(ctx, d); is_const {
			res, lvalue = unpack(emit_nodes(ctx, prop, lit))
			break
		}

		sym := ctx_lookup_lvalue(ctx, d)
		switch sym in sym {
		case int:
			res = backend.graph_get_scope_value(ctx, ctx.node_scope, sym)
			assert(backend.graph_get(ctx, res).btype != .Scope)
		case Value:
			res, lvalue = unpack(sym)
		}
	case ^ast.Paren_Expr:
		res, lvalue = unpack(emit_nodes(ctx, prop, d.expr))
	case ^ast.If_Stmt:
		cond := to_rvalue(ctx, emit_nodes(ctx, {}, d.cond), d.cond)

		if_state: backend.If_State
		backend.graph_start_if(ctx, ctx.node_scope, &if_state, cond)
		emit_nodes(ctx, {}, d.body)
		backend.graph_start_else(ctx, &ctx.node_scope, &if_state)
		emit_nodes(ctx, {}, d.else_stmt)
		backend.graph_end_else(ctx, &ctx.node_scope, &if_state)
	case ^ast.For_Stmt:
		assert(d.init == nil)
		assert(d.cond == nil)
		assert(d.post == nil)

		loop_state: Loop_State
		loop_state.label = meta.src_of(ctx.file^, d.label)
		loop_state.parent = ctx.loop
		ctx.loop = &loop_state

		backend.graph_start_loop(ctx, ctx.node_scope, &loop_state)
		emit_nodes(ctx, {}, d.body)

		backend.graph_end_loop(ctx, &ctx.node_scope, &loop_state)

		ctx.loop = ctx.loop.parent
	case ^ast.Call_Expr:
		if id, ok := d.expr.derived.(^ast.Ident); ok && id.name == "len" {
			#partial switch t in unpack_type(get_node_type(d.args[0])) {
			case ^Array:
				res = backend.graph_add_c_int(ctx, "len", dt, i64(t.len))
			case ^Slice:
				slc := emit_nodes(ctx, {}, d.args[0])
				assert(slc.is_lvalue)
				res = field_load(ctx, "slen", dt, slc.id, 8)
			case Builtin:
				assert(t == .String)
				slc := emit_nodes(ctx, {}, d.args[0])
				assert(slc.is_lvalue)
				res = field_load(ctx, "slen", dt, slc.id, 8)
			case:
				fmt.panicf("TODO: len of %#v", t)
			}
			break
		}

		if id, ok := d.expr.derived.(^ast.Ident); ok && id.name == "raw_data" {
			#partial switch t in unpack_type(get_node_type(d.args[0])) {
			case ^Array:
				slc := emit_nodes(ctx, {}, d.args[0])
				assert(slc.is_lvalue)
				res = slc.id
			case ^Slice:
				slc := emit_nodes(ctx, {}, d.args[0])
				assert(slc.is_lvalue)
				res = field_load(ctx, "slen", dt, slc.id, 0)
			case Builtin:
				assert(t == .String)
				slc := emit_nodes(ctx, {}, d.args[0])
				assert(slc.is_lvalue)
				res = field_load(ctx, "slen", dt, slc.id, 0)
			case Pointer:
				#partial switch nt in unpack_type(t^) {
				case ^Array:
					slc := emit_nodes(ctx, {}, d.args[0])
					res = to_rvalue(ctx, slc, d.args[0])
				case:
					fmt.panicf("TODO: index ptr to type of %#v", t)
				}
			case:
				fmt.panicf("TODO: raw_data of %#v", t)
			}
			break
		}

		base_ty := get_node_type(d.expr)

		#partial switch t in unpack_type(base_ty) {
		case ^Lit:
			switch l in t^ {
			case Proc_ID:
				prc := &ctx.procs[l]

				results := emit_call(ctx, d, prc, nil, prop.dest)
				if len(results) > 0 {
					last := results[len(results) - 1]
					res, lvalue = last.id, last.is_lvalue
				}
			case Intrinsic:
				switch l {
				case .syscall:
					args := make(
						[]backend.Node_ID,
						CALL_PREFIX + len(d.args),
						tmp,
					)
					for arg, i in d.args {
						vl := emit_nodes(ctx, {}, arg)
						args[CALL_PREFIX + i] = to_rvalue(ctx, vl, arg)
						backend.graph_pin(ctx, args[CALL_PREFIX + i])
					}

					args[0] = ctx_ctrl(ctx)
					args[1] = ctx_mem(ctx)

					call := backend.graph_add_call(ctx, "call", args, ~u32(0))
					backend.graph_extra(ctx, call, backend.Call).ccid = 1
					cnode := backend.graph_get(ctx, call)
					for arg in args[CALL_PREFIX:] {
						backend.graph_unpin(ctx, arg)
					}
					call_end := backend.graph_add_call_end(ctx, "calle", call)

					backend.graph_set_input(ctx, ctx.node_scope, 0, call_end)
					ctx_set_mem(
						ctx,
						backend.graph_add_mem(ctx, "cmem", call_end),
					)

					res = backend.graph_add_ret(ctx, "cret", .I64, call_end, 0)

					break match
				}
			case Module_ID:
				panic("calling a module?")
			}
		case Builtin:
			dest_dt := type_to_dt(base_ty)
			src_ty := get_node_type(d.args[0])
			src_dt := type_to_dt(src_ty)
			arg := to_rvalue(ctx, emit_nodes(ctx, {}, d.args[0]), d.args[0])

			dst_float := dest_dt in backend.FLOAT_DTS
			src_float := src_dt in backend.FLOAT_DTS

			switch {
			case dst_float && src_float:
				if dest_dt == src_dt {
					res = arg
				} else if dest_dt == .F64 {
					res = backend.graph_add_un_op(
						ctx,
						"fext",
						.F_Ext,
						dest_dt,
						arg,
					)
				} else {
					res = backend.graph_add_un_op(
						ctx,
						"fdem",
						.F_Demote,
						dest_dt,
						arg,
					)
				}
			case dst_float && !src_float:
				wide := arg
				if backend.DT_SIZE[src_dt] < 8 {
					wop: backend.Un_Op = src_ty in SIGNED_TYPES ? .Sext : .Uext
					wide = backend.graph_add_un_op(ctx, "iwd", wop, .I64, arg)
				}
				res = backend.graph_add_un_op(
					ctx,
					"i2f",
					.F_From_I,
					dest_dt,
					wide,
				)
			case !dst_float && src_float:
				res = backend.graph_add_un_op(
					ctx,
					"f2i",
					.F_To_I,
					dest_dt,
					arg,
				)
			case:
				op: backend.Un_Op = .Uext
				if src_ty in SIGNED_TYPES {
					op = .Sext
				}
				if type_size(src_ty) > type_size(base_ty) {
					op = .Cast
				}
				res = backend.graph_add_un_op(ctx, "cst", op, dest_dt, arg)
			}
		case Multi_Pointer, Pointer:
			res = to_rvalue(ctx, emit_nodes(ctx, {}, d.args[0]), d.args[0])
		case:
			fmt.panicf("TODO: %v %v", t, node)
		}
	case ^ast.Branch_Stmt:
		label := meta.src_of(ctx.file^, d.label)

		loop := ctx.loop
		for ; loop != nil; loop = loop.parent {
			if loop.label == label || label == "" {
				break
			}
		}
		assert(loop != nil)

		variant := backend.Loop_Control(-1)
		#partial switch d.tok.kind {
		case .Break:
			variant = .Break
		case .Continue:
			variant = .Continue
		case:
			fmt.panicf("TODO: %#v", node.derived)
		}

		backend.graph_loop_control(variant, ctx, ctx.node_scope, loop)
		ctx.node_scope = 0
	case:
		fmt.panicf("TODO: %#v", node.derived)
	}

	res = backend.graph_peep(ctx, res)

	return {id = res, is_lvalue = lvalue}
}

CALL_PREFIX :: 2

call_proc_of :: proc(ctx: ^Gen_Ctx, node: ^ast.Node) -> (^Proc, bool) {
	call, cok := node.derived.(^ast.Call_Expr)
	if !cok do return nil, false
	lit, lok := unpack_type(get_node_type(call.expr)).(^Lit)
	if !lok do return nil, false
	pid, pok := lit.(Proc_ID)
	if !pok do return nil, false
	return &ctx.procs[u32(pid)], true
}

emit_call :: proc(
	ctx: ^Gen_Ctx,
	d: ^ast.Call_Expr,
	prc: ^Proc,
	out_slots: []backend.Node_ID,
	prop_dest: backend.Node_ID = 0,
) -> []Value {
	tmp, _ := arna.scrath(context.temp_allocator)

	idx := u32(ctx.prc)
	for &p, i in ctx.procs {
		if &p == prc {
			idx = u32(i)
			break
		}
	}

	rets := prc.rets
	rabi := ret_abi(rets)
	ptr_ty := intern_pointer(ctx, .I64)

	results := make([]Value, len(rets), tmp)

	slots := make([]backend.Node_ID, len(rets), tmp)
	for j in 0 ..< len(rets) {
		if out_slots != nil && out_slots[j] != 0 {
			slots[j] = out_slots[j]
		}
		if ret_is_by_pointer(rabi, j) && slots[j] == 0 {
			slots[j] = alloca(ctx, "rtmp", rets[j].type, zeroed = false)
		}
		if slots[j] != 0 do backend.graph_pin(ctx, slots[j])
	}

	spread_prc: ^Proc
	if len(d.args) == 1 && len(d.args) != len(prc.params) {
		spread_prc, _ = call_proc_of(ctx, d.args[0])
		assert(spread_prc != nil)
	}

	arg_count := spread_prc != nil ? len(spread_prc.rets) : len(d.args)
	args := make(
		[]backend.Node_ID,
		CALL_PREFIX + (arg_count + len(rets) + 1) * 2,
		tmp,
	)

	lctx: Lower_Ctx
	lctx.i = CALL_PREFIX
	lctx.ri = len(args)

	for j in rabi.srets_start ..< len(rabi.extras) {
		lower_call_arg(ctx, args, &lctx, ptr_ty, Value(slots[j]))
	}

	if spread_prc != nil {
		results := emit_call(
			ctx,
			d.args[0].derived.(^ast.Call_Expr),
			spread_prc,
			nil,
		)
		for r, j in results {
			lower_call_arg(ctx, args, &lctx, spread_prc.rets[j].type, r)
		}
	} else {
		for arg in d.args {
			ty := get_node_type(arg)
			vl := emit_nodes(ctx, {}, arg)
			lower_call_arg(ctx, args, &lctx, ty, vl)
		}
	}

	for j in 0 ..< rabi.srets_start {
		lower_call_arg(ctx, args, &lctx, ptr_ty, Value(slots[j]))
	}

	for j in 0 ..< len(rabi.extras) {
		results[j] = Value {
			id        = slots[j],
			is_lvalue = true,
		}
	}

	args[0] = ctx_ctrl(ctx)
	args[1] = ctx_mem(ctx)

	slice.reverse(args[lctx.ri:])
	copy(args[lctx.i:], args[lctx.ri:])
	ln := lctx.i + len(args) - lctx.ri

	call := backend.graph_add_call(ctx, "call", args[:ln], idx)
	cnode := backend.graph_get(ctx, call)
	cnode.input_count = u16(lctx.i)
	for arg in args[CALL_PREFIX:ln] {
		backend.graph_unpin(ctx, arg)
	}
	call_end := backend.graph_add_call_end(ctx, "calle", call)

	backend.graph_set_input(ctx, ctx.node_scope, 0, call_end)
	ctx_set_mem(ctx, backend.graph_add_mem(ctx, "cmem", call_end))

	for s in slots {
		if s != 0 do backend.graph_unpin(ctx, s)
	}

	for r in results {
		if r.id == 0 do continue
		backend.graph_expand(ctx, r.id)
	}

	for j in 0 ..< len(rabi.reg_rets) {
		res_idx := len(rabi.extras) + j

		ty := rets[res_idx].type
		dest := out_slots != nil ? out_slots[res_idx] : prop_dest
		dt := type_to_dt(ty)

		if dt == .Void {
			size := type_size(ty)
			d := dest != 0 ? dest : alloca(ctx, "sret", ty, zeroed = false)

			for i in 0 ..< (size + 7) / 8 {
				rid := u32(i)
				vl := backend.graph_add_ret(ctx, "cret", .I64, call_end, rid)
				emit_arbitrary_store(ctx, d, vl, size, i * 8)
			}

			results[res_idx] = {
				id        = d,
				is_lvalue = true,
			}
		} else {
			vl := backend.graph_add_ret(ctx, "cret", dt, call_end, 0)
			results[res_idx] = Value(vl)
		}
	}

	return results

	Lower_Ctx :: struct {
		i, ri: int,
		sm:    Abi_Sm,
	}

	lower_call_arg :: proc(
		ctx: ^Gen_Ctx,
		args: []backend.Node_ID,
		lctx: ^Lower_Ctx,
		ty: Type,
		vl: Value,
	) -> bool {
		assert(vl.id != 0)

		apa := abi_sm_add2(ctx, &lctx.sm, ty) or_return

		for dt, i in apa.dt[:(apa.size + 7) / 8] {
			assert(!apa.spilled)
			args[lctx.i] = emit_arbitrary_load(ctx, vl.id, apa.size, i * 8, dt)
			backend.graph_pin(ctx, args[lctx.i])
			lctx.i += 1
		}

		if apa.by_ptr {
			assert(vl.is_lvalue)
			args[lctx.i] = vl.id
		} else if apa.scalar {
			args[lctx.i] = to_rvalue(ctx, vl, ty)
		}

		if apa.spilled {
			slot := alloca(ctx, "aspl", ty, zeroed = false, is_arg = true)
			store_value(ctx, "ast", slot, vl, ty)
			local := backend.graph_inps(ctx, slot)[0]
			lctx.ri -= 1
			args[lctx.ri] = local
			backend.graph_pin(ctx, local)
		} else if apa.by_ptr || apa.scalar {
			backend.graph_pin(ctx, args[lctx.i])
			lctx.i += 1
		}

		return true
	}

}

emit_arbitrary_store :: proc(
	ctx: ^Gen_Ctx,
	addr: backend.Node_ID,
	value: backend.Node_ID,
	size: int,
	extra_offset := 0,
	unit: backend.Node_Datatype = .I64,
) {
	store_unit := unit
	size := min(size - extra_offset, backend.DT_SIZE[unit])
	offset: int

	if store_unit in backend.FLOAT_DTS {
		field_store(ctx, "asst", addr, offset + extra_offset, value)
		return
	}

	for offset < size {
		for backend.DT_SIZE[store_unit] + offset > size {
			store_unit = backend.Node_Datatype(u8(store_unit) - 1)
			assert(store_unit != .Void)
		}

		value := backend.graph_add_un_op(
			ctx,
			"rvl",
			.Cast,
			store_unit,
			backend.graph_add_bin_op(
				ctx,
				"stsh",
				.U_Shr,
				.I64,
				value,
				backend.graph_add_c_int(ctx, "stshoff", .I64, i64(offset * 8)),
			),
		)

		field_store(ctx, "asst", addr, offset + extra_offset, value)

		offset += backend.DT_SIZE[store_unit]
	}
}

emit_arbitrary_load :: proc(
	ctx: ^Gen_Ctx,
	addr: backend.Node_ID,
	size: int,
	extra_offset := 0,
	unit: backend.Node_Datatype = .I64,
) -> backend.Node_ID {
	load_unit := unit
	size := min(size - extra_offset, backend.DT_SIZE[unit])
	offset: int
	value: backend.Node_ID

	if load_unit in backend.FLOAT_DTS {
		return field_load(ctx, "asld", load_unit, addr, offset + extra_offset)
	}

	for offset < size {
		for backend.DT_SIZE[load_unit] + offset > size {
			assert(load_unit not_in backend.FLOAT_DTS)
			load_unit = backend.Node_Datatype(u8(load_unit) - 1)
			assert(load_unit != .Void)
		}

		load := field_load(ctx, "asld", load_unit, addr, offset + extra_offset)

		if value == 0 {
			value = load
			assert(offset == 0)
		} else {
			value = backend.graph_add_bin_op(
				ctx,
				"aor",
				.Or,
				.I64,
				value,
				backend.graph_add_bin_op(
					ctx,
					"ash",
					.Shl,
					.I64,
					load,
					backend.graph_add_c_int(
						ctx,
						"ssham",
						.I64,
						i64(offset * 8),
					),
				),
			)
		}

		offset += backend.DT_SIZE[load_unit]
	}

	return value
}
