package main

import "backend"
import "backend/builder"
import "backend/regalloc"
import "backend/x64"
import "base:runtime"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:odin/ast"
import "core:odin/tokenizer"
import "core:slice"
import "core:strconv"
import "typecheck"
import "vendored/gam/util/arna"

CALL_PREFIX :: backend.CALL_PREFIX

Gen_Ctx :: typecheck.Gen_Ctx
Type :: typecheck.Type

Opt_Level :: struct {
	name:  string,
	flags: backend.Graph_Opt_Flags,
}

OPT_LEVELS :: [?]Opt_Level {
	{"none", {}},
	{"mininal", {.Local_Peeps}},
	{"moderate", {.Iter_Peeps, .Local_Peeps}},
	{"all", {.Iter_Peeps, .Local_Peeps, .Mem_Opt}},
	{"aggresive", {.Iter_Peeps, .Local_Peeps, .Mem_Opt, .Inline}},
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

	size := typecheck.type_size(ty)

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
		mem.is_aligned(
			rawptr(uintptr(offset)),
			typecheck.type_align(ty),
		) or_return

		#partial switch t in typecheck.unpack_type(ty) {

		case typecheck.Pointer, ^typecheck.Proc_Type, typecheck.Multi_Pointer:
			slots[offset / 8] = .Integer
			return true
		case ^typecheck.Slice:
			slots[offset / 8] = .Integer
			slots[offset / 8 + 1] = .Integer
			return true
		case ^typecheck.Struct:
			for f, i in t.fields {
				classify(f.ty, slots, offset + f.offset) or_return

				// NOTE: better save then sorry, but we should optimize in the
				// future
				next_offset := t.size
				if i + 1 < len(t.fields) {
					next_offset = t.fields[i + 1].offset
				}
				field_end := f.offset + typecheck.type_size(f.ty)
				for i in field_end ..< next_offset {
					classify(.I8, slots, offset + i)
				}
			}
			return true
		case ^typecheck.Array:
			step := typecheck.type_size(t.elem)
			for i in 0 ..< t.len {
				classify(t.elem, slots, offset + i * step) or_return
			}
			return true
		case ^typecheck.Enum:
			classify(t.backing, slots, offset) or_return
			return true
		case ^typecheck.Union:
			for f in t.variants {
				classify(f, slots, offset) or_return
			}
			classify(t.tag_ty, slots, t.tag_offset)
			return true
		case ^typecheck.Poly_Data:
			fmt.panicf("POLY TODO: %v", ty)
		}

		@(static, rodata)
		TYPE_TO_REGLCASS := #partial [Type]X86_Reg_Class {
			.Void   = .No_Class,
			.Typeid = .Integer,
			.Bool ..= .Rawptr        = .Integer,
			.String = .Integer,
			.F32    = .Sse_32,
			.F64    = .Sse,
		}

		if slots[offset / 8] == .Sse_32 do slots[offset / 8] = .Sse
		slots[offset / 8] = max(slots[offset / 8], TYPE_TO_REGLCASS[ty])
		if ty == .String do slots[offset / 8 + 1] = .Integer

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

	par.size = typecheck.type_size(ty)
	forced_stack := typecheck.type_to_dt(ty) == .Void
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
		rk := ctx.target_spec.datatype_to_reg_kind[p]
		par.spilled |= sm.used_regs[rk] >= len(ctx.cc.args[rk])
		sm.used_regs[rk] += 1
	}

	if par.spilled {
		for p in cata {
			rk := ctx.target_spec.datatype_to_reg_kind[p]
			sm.used_regs[rk] -= 1
		}
	}

	par.copied |= len(par.dt) > 1 && !par.spilled
	par.copied |= len(par.dt) == 1 && forced_stack

	ok = len(par.dt) != 0
	if !par.copied do par.size = 0
	if par.scalar do par.dt = {typecheck.type_to_dt(ty)}
	return
}

Propagation :: struct {
	dest: backend.Node_ID,
}

ctx_ctrl :: proc(ctx: ^Gen_Ctx) -> backend.Node_ID {
	return backend.graph_inps(ctx, ctx.node_scope)[0]
}

ctx_mem :: proc(ctx: ^Gen_Ctx) -> backend.Node_ID {
	return builder.graph_get_scope_value(ctx, ctx.node_scope, ctx.mem_slot)
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
	dt := typecheck.type_to_dt(ty)
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
	return to_rvalue(ctx, value, typecheck.get_node_type(node))
}

is_signed_subword :: proc(ty: Type) -> bool {
	if !typecheck.is_builtin(ty) do return false
	return(
		ty in typecheck.SIGNED_TYPES &&
		backend.DT_SIZE[typecheck.type_to_dt(ty)] < 8 \
	)
}

tok_to_binop :: proc(
	ty: Type,
	tok: tokenizer.Token_Kind,
) -> (
	kind: backend.Bin_Op,
	name: string,
) {
	ty := ty
	if e, ok := typecheck.unpack_type(ty).(^typecheck.Enum); ok do ty = e.backing

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

	if ty in typecheck.FLOAT_TYPES {
		finfo := FLOAT_TABLE[tok]
		return finfo.kind, finfo.name
	}

	info := SIGNED_TABLE[tok]
	uinfo := UNSIGNED_TABLE[tok]
	if ty in typecheck.UNSIGNED_TYPES && uinfo.kind != {} do info = uinfo
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

emit_lvalue :: proc(ctx: ^Gen_Ctx, expr: ^ast.Node) -> Sym {
	meta := typecheck.get_node_meta(expr)
	if id, ok := expr.derived.(^ast.Ident); ok {
		#reverse for var in ctx.scope {
			fmt.assertf(var.name != "", "%#v", ctx.scope[:])
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
		case "nil":
			#partial switch t in typecheck.unpack_type(meta.type) {
			case ^typecheck.Slice:
				return Value {
					id = alloca(ctx, "nilslc", meta.type),
					is_lvalue = true,
				}
			case:
				fmt.panicf("TODO: %v", meta.type)
			}
		}

		if gv, ok := typecheck.find_module_decl(ctx, ctx.module, id.name); ok {
			if gv.is_mutable {
				g := backend.graph_add_global(ctx, gv.name)
				backend.graph_extra(ctx, g, backend.Tup).idx = gv.global_idx
				ptr := backend.graph_add_global_addr(ctx, gv.name, g)
				return Value{id = ptr, is_lvalue = true}
			} else {
				if blit, is_lit := gv.value.derived.(^ast.Basic_Lit); is_lit {
					tmp, _ := arna.scrath()
					blita := new_clone(blit^, tmp)
					typecheck.set_node_data(blita, meta)
					return emit_nodes(ctx, {}, blita)
				}
			}
		}

		fmt.panicf("TODO: undefined variable: %v %#v", id.name, expr.derived)
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
	store_value(ctx, name, ptr, value, typecheck.get_node_type(node))
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

	if typecheck.type_to_dt(ty) == .Void {
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
					i64(typecheck.type_size(ty)),
				),
			),
		)
	} else {
		field_store(ctx, name, ptr, 0, to_rvalue(ctx, value, ty))
	}
}

store_union :: proc(
	ctx: ^Gen_Ctx,
	dest: backend.Node_ID,
	member_val: Value,
	u: ^typecheck.Union,
	member_ty: Type,
) {
	idx, ok := typecheck.union_variant_index(u, member_ty)
	assert(ok)
	store_value(ctx, "unionv", dest, member_val, member_ty)
	tag := backend.graph_add_c_int(
		ctx,
		"utag",
		typecheck.type_to_dt(u.tag_ty),
		i64(idx + 1),
	)
	field_store(ctx, "utagst", dest, u.tag_offset, tag)
}

alloca :: proc(
	ctx: ^Gen_Ctx,
	name: string,
	ty: Type,
	zeroed := true,
	is_arg := false,
	is_param := false,
) -> backend.Node_ID {
	root := is_arg ? ctx.entry : ctx.root_mem
	alloca := backend.graph_add_local(ctx, name, root)

	backend.graph_extra(ctx, alloca, backend.Local).size = i32(
		typecheck.type_size(ty),
	)
	ptr := backend.graph_add_local_addr(ctx, name, alloca)

	if zeroed {
		zero := backend.graph_add_c_int(ctx, "zero", .I8, 0)
		size := backend.graph_add_c_int(
			ctx,
			"size",
			.I32,
			i64(typecheck.type_size(ty)),
		)
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

inline_and_optimize :: proc(
	ctx: ^Gen_Ctx,
	emit_ctx: ^backend.Codegen_Emit_Ctx,
) -> bool {
	perm := context.allocator
	context.allocator, _ = arna.scrath()

	S_Ctx :: struct {
		caller_to_callee: [][]u32,
		callee_to_caller: [][]u32,
		scc_asoc:         []SCC_Asoc,
		sccs:             [dynamic]SCC,
		stack:            [dynamic]u32,
		index:            int,
	}

	scc_order: [dynamic]int

	sctx: S_Ctx
	sctx.caller_to_callee = make([][]u32, len(ctx.procs))

	for prc, i in ctx.procs {
		if len(prc.stencil.mem) == 0 do continue

		slot: arna.Allocator
		graph: backend.Graph
		graph.node_spec = &builder.SPEC
		graph.mem = &slot
		backend.graph_mount_stencil(&graph, prc.stencil)

		sc := backend.graph_sym_count(&graph)
		sctx.caller_to_callee[i] = make([]u32, sc)
		for j := sc; sr in backend.graph_sym_iter_next(&graph, &j) {
			assert(sr.type == .Func)
			sctx.caller_to_callee[i][j] = sr.id
		}
	}

	sctx.callee_to_caller = make([][]u32, len(ctx.procs))

	for egs in sctx.caller_to_callee {
		for e in egs {
			slt := &sctx.callee_to_caller[e]
			slt^ = raw_data(slt^)[:len(slt^) + 1]
		}
	}

	for &egs in sctx.callee_to_caller {
		egs = make([]u32, len(egs))
		egs = egs[:0]
	}

	for egs, i in sctx.caller_to_callee {
		for e in egs {
			slt := &sctx.callee_to_caller[e]
			slt^ = raw_data(slt^)[:len(slt^) + 1]
			slt^[len(slt^) - 1] = u32(i)
		}
	}

	SCC :: struct {
		members: []u32,
		rc:      int,
	}

	SCC_Asoc :: struct {
		index, lowlink: int,
		scc_id:         int,
		on_stack:       bool,
	}

	sctx.scc_asoc = make([]SCC_Asoc, len(ctx.procs))

	for &scc, i in sctx.scc_asoc {
		if scc.index == 0 {
			strong_connect(&sctx, u32(i))
		}
	}

	strong_connect :: proc(sctx: ^S_Ctx, caller: u32) {
		stack_mark := len(sctx.stack)
		sctx.index += 1
		sctx.scc_asoc[caller].index = sctx.index
		sctx.scc_asoc[caller].lowlink = sctx.index
		sctx.scc_asoc[caller].on_stack = true
		append(&sctx.stack, caller)

		for callee in sctx.caller_to_callee[caller] {
			if sctx.scc_asoc[callee].index == 0 {
				strong_connect(sctx, callee)
				sctx.scc_asoc[caller].lowlink = min(
					sctx.scc_asoc[caller].lowlink,
					sctx.scc_asoc[callee].lowlink,
				)
			} else if sctx.scc_asoc[callee].on_stack {
				sctx.scc_asoc[caller].lowlink = min(
					sctx.scc_asoc[caller].lowlink,
					sctx.scc_asoc[callee].index,
				)
			}
		}

		if sctx.scc_asoc[caller].index == sctx.scc_asoc[caller].lowlink {
			for n in sctx.stack[stack_mark:] {
				sctx.scc_asoc[n].scc_id = len(sctx.sccs)
				sctx.scc_asoc[n].on_stack = false
			}
			scc: SCC
			scc.members = slice.clone(sctx.stack[stack_mark:])
			resize(&sctx.stack, stack_mark)
			append(&sctx.sccs, scc)
		}
	}

	for &scc, i in sctx.sccs {
		for m in scc.members {
			for edg in sctx.callee_to_caller[m] {
				id := sctx.scc_asoc[edg].scc_id
				oscc := &sctx.sccs[id]
				oscc.rc += int(id != i)
			}
		}
	}

	for scc, i in sctx.sccs {
		if scc.rc == 0 {
			append(&scc_order, i)
		}
	}

	for i := 0; i < len(scc_order); i += 1 {
		scc := &sctx.sccs[scc_order[i]]
		assert(scc.rc == 0)

		for m in scc.members {
			for edg in sctx.callee_to_caller[m] {
				id := sctx.scc_asoc[edg].scc_id
				oscc := &sctx.sccs[id]
				oscc.rc -= 1
				if oscc.rc == 0 do append(&scc_order, id)
			}
		}
	}

	Weight_Category :: enum {
		Light,
		Light_Medium,
		Medium,
		Medium_Heavy,
		Heavy,
	}

	weight_cata :: proc(weight: int) -> Weight_Category {
		switch weight {
		case 0 ..< 10:
			return .Light
		case 10 ..< 30:
			return .Light_Medium
		case 30 ..< 50:
			return .Medium
		case 50 ..< 100:
			return .Medium_Heavy
		case:
			return .Heavy
		}
	}

	weight_cata_can_merge :: proc(caller, callee: Weight_Category) -> bool {
		if caller < .Medium && callee > .Medium do return false
		return callee < .Medium || (caller == callee && caller == .Medium)
	}

	inline_count := 0
	for si in scc_order do for m in sctx.sccs[si].members {
		caller := &ctx.procs[m]
		if len(caller.stencil.mem) == 0 do continue
		backend.graph_mount_stencil(ctx, caller.stencil)

		caller_wct := weight_cata(ctx.weight)

		sc := backend.graph_sym_count(ctx)
		for j := sc; sim in backend.graph_sym_iter_next(ctx, &j) {
			assert(sim.type == .Func)
			callee := &ctx.procs[sim.id]
			if len(callee.stencil.mem) == 0 do continue

			if sctx.scc_asoc[sim.id].scc_id == sctx.scc_asoc[m].scc_id {
				continue
			}

			slt := &sctx.callee_to_caller[sim.id]

			if callee.stencil.weight > 1000 do continue

			callee_wct := weight_cata(callee.stencil.weight * len(slt))
			if !weight_cata_can_merge(caller_wct, callee_wct) && len(slt) > 1 {
				continue
			}

			builder.graph_inline(ctx, sim.node, callee.stencil)
			inline_count += 1

			slt^ = slt^[:len(slt^) - 1]
			if len(slt) == 0 {
				delete(callee.stencil.mem, perm)
				backend.add_efficiency_stat(ctx, .duplicated_nodes, -int(callee.stencil.gvn))
				callee.stencil = {}
			}
		}

		backend.graph_iter_peeps({graph = ctx})
		builder.memopt(ctx)
		backend.graph_iter_peeps({graph = ctx})
		backend.graph_compact(ctx)

		delete(caller.stencil.mem, perm)
		caller.stencil = backend.graph_stencil(ctx)
		caller.stencil.mem = slice.clone(caller.stencil.mem, perm)
	}

	for &prc in ctx.procs {
		if len(prc.stencil.mem) == 0 do continue
		backend.graph_mount_stencil(ctx, prc.stencil)
		emit_proc_code(ctx, emit_ctx, &prc)
	}

	return inline_count != 0
}

emit_proc :: proc(
	ctx: ^Gen_Ctx,
	i: int,
	level: Opt_Level,
	emit_ctx: ^backend.Codegen_Emit_Ctx,
) {
	prc := &ctx.procs[i]
	if prc.lit.body == nil do return

	ctx.prc = auto_cast i
	ctx.module = prc.module
	ctx.file = prc.file
	ctx.file_id = prc.file_id
	ctx.graph = {}
	ctx.node_spec = &builder.SPEC
	ctx.mem = &ctx.mems.graph
	ctx.mem.pos = backend.PRECISION
	ctx.opt_flags = level.flags
	ctx.stats = &ctx.tstats

	backend.current_graph = ctx

	ctx.mems.scratch.pos = 0
	ctx.scope = make(
		[dynamic]typecheck.Variable,
		arna.allocator(&ctx.mems.scratch),
	)

	clear(&ctx.poly_types)
	assert(len(prc.poly_names) == len(prc.poly_values))
	for j in 0 ..< len(prc.poly_names) {
		append(
			&ctx.poly_types,
			typecheck.Poly_Entry{prc.poly_names[j], prc.poly_values[j]},
		)
	}

	ctx.start = backend.graph_add_start(ctx, "start")
	ctx.entry = backend.graph_add_entry(ctx, "entry", ctx.start)
	ctx.root_mem = backend.graph_add_mem(ctx, "emem", ctx.entry)
	ctx.sym = backend.graph_add_sym(ctx, "sym", ctx.entry)

	ctx.node_scope = builder.graph_add_scope(ctx, "scope", ctx.entry)
	ctx.mem_slot = builder.graph_push_scope_value(
		ctx,
		ctx.node_scope,
		ctx.root_mem,
	)

	rabi := typecheck.ret_abi(prc.rets[:])
	ctx.ret_ptrs = nil

	sm: Abi_Sm

	ctx.ret_ptrs = make(
		[]backend.Node_ID,
		len(rabi.extras),
		context.temp_allocator,
	)

	arg_vls := make([dynamic]backend.Node_ID, context.temp_allocator)
	spill_start := 0

	for j in rabi.srets_start ..< len(rabi.extras) {
		ctx.ret_ptrs[j] = backend.graph_add_arg(
			ctx,
			"sret",
			.I64,
			ctx.entry,
			0,
		)
		append(&arg_vls, ctx.ret_ptrs[j])
		spill_start += 1
		backend.graph_pin(ctx, ctx.ret_ptrs[j])
		apa := abi_sm_add2(ctx, &sm, .I64) or_else panic("")
		assert(!apa.spilled && !apa.by_ptr)
	}

	for par, i in prc.params {
		name := prc.param_names[i]
		apa := abi_sm_add2(ctx, &sm, par) or_continue
		spill_start += int(!apa.spilled)

		value: backend.Node_ID
		if apa.scalar {
			dt := apa.dt[0]
			value = backend.graph_add_arg(
				ctx,
				"arg",
				dt,
				ctx.entry,
				u32(apa.spilled),
			)
			append(&arg_vls, value)
		} else {
			value = alloca(
				ctx,
				"sarg",
				par,
				zeroed = false,
				is_arg = !apa.copied,
				is_param = !apa.copied,
			)
			if !apa.copied {
				append(&arg_vls, backend.graph_inps(ctx, value)[0])
			}
		}

		for dt, j in apa.dt[:(apa.size + 7) / 8] {
			vl := backend.graph_add_arg(ctx, "arg", dt, ctx.entry, 0)
			spill_start += int(j == 1)
			append(&arg_vls, vl)
			emit_arbitrary_store(ctx, value, vl, apa.size, j * 8, dt)
		}

		value_idx: typecheck.Varuable_Idx
		if apa.scalar && !apa.by_ptr {
			value_idx = builder.graph_push_scope_value(
				ctx,
				ctx.node_scope,
				value,
			)
		} else {
			value_idx = value
		}

		append(&ctx.scope, typecheck.Variable{name, value_idx, par, nil, {}})
	}

	for j in 0 ..< rabi.srets_start {
		apa := abi_sm_add2(ctx, &sm, .I64) or_else panic("")
		spill_start += int(!apa.spilled)
		ctx.ret_ptrs[j] = backend.graph_add_arg(
			ctx,
			"retp",
			.I64,
			ctx.entry,
			u32(apa.spilled),
		)
		append(&arg_vls, ctx.ret_ptrs[j])
		backend.graph_pin(ctx, ctx.ret_ptrs[j])
	}

	arg_tys := make([dynamic]backend.Node_Datatype, ctx.types.allocator)

	j, ri: u32
	for arg in arg_vls {
		anode := backend.graph_get(ctx, arg)
		if arga := backend.graph_extra(ctx, arg, backend.Tup); arga != nil {
			append(&arg_tys, anode.dt)
			if arga.idx == 0 {
				arga.idx = j
				j += 1
			} else {
				arga.idx = u32(spill_start) + ri
				ri += 1
			}
		}

		if loca := backend.graph_extra(ctx, arg, backend.Local); loca != nil {
			loca.idx = u32(spill_start) + ri
			ri += 1
		}
	}
	prc.param_types = arg_tys[:]
	fmt.assertf(int(j) == spill_start, "%v %v", j, spill_start)

	emit_nodes(ctx, {}, prc.lit.body)
	prc = &ctx.procs[i]

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

	peep_ctx: backend.Peep_Ctx
	peep_ctx.graph = ctx

	backend.graph_iter_peeps(peep_ctx)
	builder.memopt(ctx)

	backend.graph_iter_peeps(peep_ctx)

	if .Inline in level.flags {
		backend.graph_compact(ctx)
		prc.stencil = backend.graph_stencil(ctx)
		prc.stencil.mem = slice.clone(prc.stencil.mem)
		return
	}

	emit_proc_code(ctx, emit_ctx, prc)
}

emit_proc_code :: proc(
	ctx: ^Gen_Ctx,
	emit_ctx: ^backend.Codegen_Emit_Ctx,
	prc: ^typecheck.Proc,
) {
	spec := &x64.SPEC
	ctx.node_spec = spec

	peep_ctx: backend.Peep_Ctx
	peep_ctx.graph = ctx

	backend.graph_iter_peeps(peep_ctx)

	backend.graph_compact(ctx)

	schedule: backend.Graph_Schedule
	backend.graph_schedule(ctx, &schedule, arna.allocator(&ctx.mems.scratch))

	backend.graph_schedule_peeps(ctx, &schedule)

	ra: backend.Regalloc
	ra.spec = spec
	ra.cc = &x64.X64_SYSTEMV_CC
	ra.param_types = prc.param_types

	regs := regalloc.regalloc(
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

Scope_Base :: struct {
	gen:  int,
	node: u16,
}

ctx_scope_base :: proc(ctx: ^Gen_Ctx) -> Scope_Base {
	return {len(ctx.scope), backend.graph_get(ctx, ctx.node_scope).input_count}
}

emit_stmts :: proc(
	ctx: ^Gen_Ctx,
	stmts: []^ast.Stmt,
	scope_base_override: Maybe(Scope_Base) = nil,
) {
	base := scope_base_override.? or_else ctx_scope_base(ctx)
	for stmt in stmts {
		emit_nodes(ctx, {}, stmt)
		if ctx.node_scope == 0 do break
	}
	for v in ctx.scope[base.gen:] {
		if n, ok := v.idx.(backend.Node_ID); ok {
			backend.graph_unpin(ctx, n)
		}
	}
	assert(base.gen <= len(ctx.scope))
	resize(&ctx.scope, base.gen)
	builder.graph_truncate_scope(ctx, ctx.node_scope, base.node)
}

emit_nodes :: proc(
	ctx: ^Gen_Ctx,
	prop: Propagation,
	node: ^ast.Node,
) -> Value {
	if node == nil do return {}

	ty := typecheck.get_node_type(node)
	dt := typecheck.type_to_dt(ty)

	res: backend.Node_ID
	lvalue: bool

	unpack :: proc(vl: Value) -> (backend.Node_ID, bool) {
		return vl.id, vl.is_lvalue
	}

	tmp, _ := arna.scrath(context.temp_allocator)

	#partial match: switch d in node.derived {
	case ^ast.Block_Stmt:
		emit_stmts(ctx, d.stmts)
	case ^ast.Expr_Stmt:
		node := emit_nodes(ctx, {}, d.expr)
		if node.id != 0 {
			backend.graph_delete(ctx, node.id)
		}
	case ^ast.Assign_Stmt:
		if len(d.rhs) == 1 && len(d.lhs) > 1 {
			assert(d.op.kind == .Eq)
			prc_id, ok := call_proc_of(ctx, d.rhs[0])
			prc := ctx.procs[prc_id]
			assert(ok)
			assert(len(prc.rets) == len(d.lhs))
			rabi := typecheck.ret_abi(prc.rets[:])

			syms := make([]Sym, len(d.lhs), tmp)
			out_slots := make([]backend.Node_ID, len(d.lhs), tmp)
			for lhs, i in d.lhs {
				if id, iok := lhs.derived.(^ast.Ident); iok && id.name == "_" {
					continue
				}
				syms[i] = emit_lvalue(ctx, lhs)
				if v, vok := syms[i].(Value);
				   vok && typecheck.ret_is_by_pointer(rabi, i) {
					out_slots[i] = v.id
				}
			}

			results := emit_call(
				ctx,
				d.rhs[0].derived.(^ast.Call_Expr),
				nil,
				prc_id,
				0,
				out_slots,
			)

			for r, i in results {
				if id, iok := d.lhs[i].derived.(^ast.Ident);
				   iok && id.name == "_" {
					continue
				}
				vty := prc.rets[i]
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
			sym := emit_lvalue(ctx, lhs)
			switch sym in sym {
			case int:
				value := to_rvalue(
					ctx,
					emit_nodes(ctx, {}, rhs),
					typecheck.get_node_type(rhs),
				)
				if d.op.kind != .Eq {
					op, name := tok_to_binop(
						typecheck.get_node_type(rhs),
						d.op.kind,
					)
					value = auto_cast backend.graph_add_bin_op(
						ctx,
						name,
						op,
						typecheck.type_to_dt(typecheck.get_node_type(lhs)),
						builder.graph_get_scope_value(
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
				lhs_ty := typecheck.get_node_type(lhs)
				if u, uok := typecheck.unpack_type(lhs_ty).(^typecheck.Union);
				   uok &&
				   d.op.kind == .Eq &&
				   typecheck.get_node_type(rhs) != lhs_ty {
					value := emit_nodes(ctx, {dest = sym.id}, rhs)
					store_union(
						ctx,
						sym.id,
						value,
						u,
						typecheck.get_node_type(rhs),
					)
					continue
				}
				if d.op.kind == .Eq {
					if len(d.lhs) == 1 {
						fmt.assertf(
							typecheck.get_node_type(lhs) ==
							typecheck.get_node_type(rhs),
							"%v %v",
							typecheck.get_node_type(lhs),
							typecheck.get_node_type(rhs),
						)
						value := emit_nodes(ctx, {dest = sym.id}, rhs)
						store_value(ctx, "asss", sym.id, value, lhs)
					} else {
						value := to_rvalue(
							ctx,
							emit_nodes(ctx, {}, rhs),
							typecheck.get_node_type(rhs),
						)
						backend.graph_pin(ctx, value)
						append(&mem_stores, Mem_Store{sym.id, value, lhs})
					}
				} else {
					op, name := tok_to_binop(
						typecheck.get_node_type(rhs),
						d.op.kind,
					)
					vl := to_rvalue(ctx, sym, rhs)
					backend.graph_pin(ctx, vl)
					value := backend.graph_add_bin_op(
						ctx,
						name,
						op,
						typecheck.type_to_dt(typecheck.get_node_type(lhs)),
						vl,
						to_rvalue(
							ctx,
							emit_nodes(ctx, {}, rhs),
							typecheck.get_node_type(rhs),
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
		if typecheck.is_nil_lit(d.left) || typecheck.is_nil_lit(d.right) {
			union_expr := typecheck.is_nil_lit(d.left) ? d.right : d.left
			u := typecheck.unpack_type(
				typecheck.get_node_type(union_expr),
			).(^typecheck.Union)
			uv := emit_nodes(ctx, {}, union_expr)
			assert(uv.is_lvalue)
			tag_dt := typecheck.type_to_dt(u.tag_ty)
			tag := field_load(ctx, "ntag", tag_dt, uv.id, u.tag_offset)
			zero := backend.graph_add_c_int(ctx, "nzero", tag_dt, 0)
			op: backend.Bin_Op = d.op.kind == .Cmp_Eq ? .Eq : .Ne
			res = backend.graph_add_bin_op(ctx, "ncmp", op, dt, tag, zero)
			break
		}

		lhsv := emit_nodes(ctx, {}, d.left)
		backend.graph_pin(ctx, lhsv.id)
		rhsv := emit_nodes(ctx, {}, d.right)
		lhs, rhs := to_rvalue(ctx, lhsv, d.left), to_rvalue(ctx, rhsv, d.right)
		kind, name := tok_to_binop(typecheck.get_node_type(d.left), d.op.kind)
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
			oty := typecheck.get_node_type(d.expr)
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
		rabi := typecheck.ret_abi(rets)

		values := make([]backend.Node_ID, 4, tmp)
		i := 2

		emit_reg_ret :: proc(
			ctx: ^Gen_Ctx,
			values: []backend.Node_ID,
			i: ^int,
			r: ^ast.Node,
		) {
			ty := typecheck.get_node_type(r)
			vl := emit_nodes(ctx, {}, r)
			if typecheck.type_to_dt(ty) == .Void {
				assert(vl.is_lvalue)
				size := typecheck.type_size(ty)
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
			store_value(ctx, "rpst", ptr, vl, typecheck.get_node_type(r))
		}

		for j in 0 ..< len(rabi.reg_rets) {
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

			idx := typecheck.add_global(ctx, transmute([]u8)str, 1)
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
			prc_id, ok := call_proc_of(ctx, d.values[0])
			assert(ok)
			assert(len(ctx.procs[prc_id].rets) == len(d.names))

			results := emit_call(
				ctx,
				d.values[0].derived.(^ast.Call_Expr),
				nil,
				prc_id,
				0,
				nil,
			)

			for r, i in results {
				name := typecheck.src_of(ctx.file^, d.names[i])
				if name == "_" do continue
				flags := typecheck.get_node_vflags(d.names[i])
				vty := ctx.procs[prc_id].rets[i]

				if r.is_lvalue {
					backend.graph_pin(ctx, r.id)
					append(
						&ctx.scope,
						typecheck.Variable{name, r.id, vty, d.names[i], flags},
					)
				} else {
					backend.graph_set_name(ctx, r.id, name)
					idx := builder.graph_push_scope_value(
						ctx,
						ctx.node_scope,
						r.id,
					)
					append(
						&ctx.scope,
						typecheck.Variable{name, idx, vty, d.names[i], flags},
					)
				}
			}
			break
		}

		if len(d.values) == 0 {
			decl_ty := typecheck.emit_type(ctx, d.type)
			for i in 0 ..< len(d.names) {
				name := typecheck.src_of(ctx.file^, d.names[i])
				flags := typecheck.get_node_vflags(d.names[i])
				ptr := alloca(ctx, name, decl_ty, zeroed = true)
				backend.graph_pin(ctx, ptr)
				append(
					&ctx.scope,
					typecheck.Variable{name, ptr, decl_ty, d.names[i], flags},
				)
			}
			break
		}

		assert(len(d.names) == len(d.values))
		for i in 0 ..< len(d.names) {
			name := typecheck.src_of(ctx.file^, d.names[i])
			assert(name != "")
			decl_ty := typecheck.emit_type(ctx, d.type)
			vty :=
				decl_ty != .Void ? decl_ty : typecheck.get_node_type(d.values[i])
			flags := typecheck.get_node_vflags(d.names[i])

			if is_static(d) {
				size := typecheck.type_size(vty)
				bytes := make([]u8, size, ctx.globals.allocator)

				if typecheck.type_to_dt(vty) != .Void {
					value, cok := typecheck.const_eval_int(d.values[i])
					if !cok {
						fmt.panicf(
							"TODO: non-constant static initializer: %v",
							name,
						)
					}
					val_bytes := transmute([8]u8)value
					copy(bytes, val_bytes[:size])
				}

				idx := typecheck.add_global(
					ctx,
					bytes,
					typecheck.type_align(vty),
				)
				g := backend.graph_add_global(ctx, name)
				backend.graph_extra(ctx, g, backend.Tup).idx = idx
				ptr := backend.graph_add_global_addr(ctx, name, g)
				backend.graph_pin(ctx, ptr)

				append(
					&ctx.scope,
					typecheck.Variable{name, ptr, vty, d.names[i], flags},
				)
			} else if .Referenced in flags ||
			   typecheck.type_to_dt(vty) == .Void {
				ptr := alloca(
					ctx,
					name,
					vty,
					zeroed = typecheck.type_to_dt(vty) == .Void,
				)
				backend.graph_pin(ctx, ptr)

				value := emit_nodes(ctx, {dest = ptr}, d.values[i])
				if u, uok := typecheck.unpack_type(vty).(^typecheck.Union);
				   uok && typecheck.get_node_type(d.values[i]) != vty {
					store_union(
						ctx,
						ptr,
						value,
						u,
						typecheck.get_node_type(d.values[i]),
					)
				} else {
					store_value(ctx, "init", ptr, value, vty)
				}

				append(
					&ctx.scope,
					typecheck.Variable{name, ptr, vty, d.names[i], flags},
				)
			} else {
				value := to_rvalue(
					ctx,
					emit_nodes(ctx, {}, d.values[i]),
					d.values[i],
				)
				backend.graph_set_name(ctx, value, name)
				idx := builder.graph_push_scope_value(
					ctx,
					ctx.node_scope,
					value,
				)
				append(
					&ctx.scope,
					typecheck.Variable{name, idx, vty, d.names[i], flags},
				)
			}
		}
	case ^ast.Comp_Lit:
		dest := prop.dest != 0 ? prop.dest : alloca(ctx, "comp", ty)

		#partial switch t in typecheck.unpack_type(ty) {
		case ^typecheck.Struct:
			for elem, i in d.elems {
				offset: int
				ast_value: ^ast.Node
				#partial switch e in elem.derived {
				case ^ast.Field_Value:
					offset = typecheck.get_node_data(e.field, int)
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
		case ^typecheck.Array:
			stride := typecheck.array_elem_stride(t.elem)
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
		if typecheck.is_of(
			typecheck.get_node_meta(d.expr).lit.typeida,
			^typecheck.Enum,
		) {
			val := typecheck.get_node_data(d.field, int)
			res = backend.graph_add_c_int(ctx, "enumv", dt, i64(val))
			break
		}
		base := emit_nodes(ctx, {}, d.expr)
		base_ty := typecheck.unpack_type(typecheck.get_node_type(d.expr))
		#partial switch f in d.field.derived {
		case ^ast.Ident:
			if pty, ok := base_ty.(typecheck.Pointer); ok {
				base.id = to_rvalue(ctx, base, typecheck.pack_type(base_ty))
				base_ty = typecheck.unpack_type(pty^)
				base.is_lvalue = true
			}

			#partial switch t in base_ty {
			case ^typecheck.Struct:
				assert(base.is_lvalue)
				offset := typecheck.get_node_data(d.field, int)
				field_ptr := field_offset(ctx, base.id, offset)
				res, lvalue = field_ptr, true
			case:
				fmt.panicf("TODO: %#v", t)
			}
		case:
			fmt.panicf("TODO: %#v", d.field.derived)
		}
	case ^ast.Implicit_Selector_Expr:
		val := typecheck.get_node_data(d.field, int)
		res = backend.graph_add_c_int(ctx, "enumv", dt, i64(val))
	case ^ast.Type_Assertion:
		base := emit_nodes(ctx, {}, d.expr)
		assert(base.is_lvalue)
		res, lvalue = base.id, true
	case ^ast.Index_Expr:
		base := emit_nodes(ctx, {}, d.expr)

		if typecheck.is_of(
			typecheck.get_node_type(d.expr),
			typecheck.Multi_Pointer,
		) {
			base = Value(to_rvalue(ctx, base, d.expr))
		} else {
			assert(base.is_lvalue)
		}

		base_ptr := base.id
		if typecheck.is_of(
			   typecheck.get_node_type(d.expr),
			   ^typecheck.Slice,
		   ) ||
		   typecheck.get_node_type(d.expr) == .String {
			base_ptr = field_load(ctx, "sdata", .I64, base.id)
		}

		idx := to_rvalue(ctx, emit_nodes(ctx, {}, d.index), d.index)

		stride := typecheck.array_elem_stride(ty)
		res = index_offset(ctx, base_ptr, idx, stride)
		lvalue = true
	case ^ast.Slice_Expr:
		base := emit_nodes(ctx, {}, d.expr)

		stride: int
		#partial switch t in typecheck.unpack_type(ty) {
		case ^typecheck.Slice:
			stride = typecheck.array_elem_stride(t.elem)
		case typecheck.String_Type:
			stride = 1
		case:
			fmt.panicf("TODO: slice result %#v", t)
		}

		base_ptr: backend.Node_ID
		src_len: backend.Node_ID
		#partial switch t in typecheck.unpack_type(
			typecheck.get_node_type(d.expr),
		) {
		case typecheck.Pointer:
			#partial switch nt in typecheck.unpack_type(t^) {
			case ^typecheck.Array:
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
		case ^typecheck.Array:
			base_ptr = base.id
			src_len = backend.graph_add_c_int(ctx, "alen", .I64, i64(t.len))
		case typecheck.String_Type:
			assert(base.is_lvalue)
			base_ptr = field_load(ctx, "sdata", .I64, base.id)
			src_len = field_load(ctx, "slen", .I64, base.id, 8)
		case ^typecheck.Slice:
			assert(base.is_lvalue)
			base_ptr = field_load(ctx, "sdata", .I64, base.id)
			src_len = field_load(ctx, "slen", .I64, base.id, 8)
		case typecheck.Multi_Pointer:
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
		sym := emit_lvalue(ctx, d)
		switch sym in sym {
		case int:
			res = builder.graph_get_scope_value(ctx, ctx.node_scope, sym)
			assert(
				builder.Builder_Node_Type(backend.graph_get(ctx, res).rtype) !=
				.Scope,
			)
		case Value:
			res, lvalue = unpack(sym)
		}
	case ^ast.Paren_Expr:
		res, lvalue = unpack(emit_nodes(ctx, prop, d.expr))
	case ^ast.If_Stmt:
		cond := to_rvalue(ctx, emit_nodes(ctx, {}, d.cond), d.cond)

		if_state: builder.If_State
		builder.graph_start_if(ctx, ctx.node_scope, &if_state, cond)
		emit_nodes(ctx, {}, d.body)
		builder.graph_start_else(ctx, &ctx.node_scope, &if_state)
		emit_nodes(ctx, {}, d.else_stmt)
		builder.graph_end_else(ctx, &ctx.node_scope, &if_state)
	case ^ast.Switch_Stmt:
		condv := to_rvalue(ctx, emit_nodes(ctx, {}, d.cond), d.cond)
		backend.graph_pin(ctx, condv)

		body := d.body.derived.(^ast.Block_Stmt)
		sw: builder.Block_State
		builder.graph_start_block(&sw)
		default_clause: ^ast.Case_Clause
		for clause_node in body.stmts {
			clause := clause_node.derived.(^ast.Case_Clause)
			if len(clause.list) == 0 {
				default_clause = clause
				continue
			}

			cond: backend.Node_ID
			for v in clause.list {
				cv := to_rvalue(ctx, emit_nodes(ctx, {}, v), v)
				eq := backend.graph_add_bin_op(ctx, "seq", .Eq, .I8, condv, cv)
				cond =
					cond == 0 ? eq : backend.graph_add_bin_op(ctx, "sor", .Or, .I8, cond, eq)
			}

			arm: builder.If_State
			builder.graph_start_if(ctx, ctx.node_scope, &arm, cond)
			emit_stmts(ctx, clause.body)
			builder.graph_break_block(ctx, &ctx.node_scope, &sw)
			builder.graph_start_else(ctx, &ctx.node_scope, &arm)
			builder.graph_end_else(ctx, &ctx.node_scope, &arm)
		}

		if default_clause != nil {
			emit_stmts(ctx, default_clause.body)
		}

		builder.graph_end_block(ctx, &ctx.node_scope, &sw)

		backend.graph_unpin(ctx, condv)
	case ^ast.Type_Switch_Stmt:
		tag := d.tag.derived.(^ast.Assign_Stmt)
		binding := typecheck.src_of(ctx.file^, tag.lhs[0])
		u := typecheck.unpack_type(
			typecheck.get_node_type(tag.rhs[0]),
		).(^typecheck.Union)

		uv := emit_nodes(ctx, {}, tag.rhs[0])
		assert(uv.is_lvalue)
		ptr := uv.id
		backend.graph_pin(ctx, ptr)

		tag_dt := typecheck.type_to_dt(u.tag_ty)
		tagv := field_load(ctx, "tstag", tag_dt, ptr, u.tag_offset)
		backend.graph_pin(ctx, tagv)

		body := d.body.derived.(^ast.Block_Stmt)
		sw: builder.Block_State
		builder.graph_start_block(&sw)
		default_clause: ^ast.Case_Clause
		for clause_node in body.stmts {
			clause := clause_node.derived.(^ast.Case_Clause)
			if len(clause.list) == 0 {
				default_clause = clause
				continue
			}

			case_ty := typecheck.emit_type(ctx, clause.list[0])
			idx, _ := typecheck.union_variant_index(u, case_ty)
			cval := backend.graph_add_c_int(ctx, "tsc", tag_dt, i64(idx + 1))
			cond := backend.graph_add_bin_op(ctx, "tseq", .Eq, .I8, tagv, cval)

			arm: builder.If_State
			builder.graph_start_if(ctx, ctx.node_scope, &arm, cond)
			{
				base := ctx_scope_base(ctx)
				backend.graph_pin(ctx, ptr)
				append(
					&ctx.scope,
					typecheck.Variable {
						binding,
						ptr,
						case_ty,
						tag.lhs[0],
						{.Referenced},
					},
				)
				emit_stmts(ctx, clause.body, base)
				builder.graph_break_block(ctx, &ctx.node_scope, &sw)
			}
			builder.graph_start_else(ctx, &ctx.node_scope, &arm)
			builder.graph_end_else(ctx, &ctx.node_scope, &arm)
		}

		if default_clause != nil {
			base := ctx_scope_base(ctx)
			backend.graph_pin(ctx, ptr)
			append(
				&ctx.scope,
				typecheck.Variable {
					binding,
					ptr,
					typecheck.get_node_type(tag.rhs[0]),
					tag.lhs[0],
					{.Referenced},
				},
			)
			emit_stmts(ctx, default_clause.body, base)
		}

		builder.graph_end_block(ctx, &ctx.node_scope, &sw)

		backend.graph_unpin(ctx, tagv)
		backend.graph_unpin(ctx, ptr)
	case ^ast.For_Stmt:
		assert(d.init == nil)
		assert(d.cond == nil)
		assert(d.post == nil)

		loop_state: typecheck.Loop_State
		loop_state.label = typecheck.src_of(ctx.file^, d.label)
		loop_state.parent = ctx.loop
		ctx.loop = &loop_state

		builder.graph_start_loop(ctx, ctx.node_scope, &loop_state.bstate)
		emit_nodes(ctx, {}, d.body)

		builder.graph_end_loop(ctx, &ctx.node_scope, &loop_state.bstate)

		ctx.loop = ctx.loop.parent
	case ^ast.Call_Expr:
		switch typecheck.get_builtin_proc(d.expr) {
		case .nil:
		case .len:
			#partial switch t in typecheck.unpack_type(
				typecheck.get_node_type(d.args[0]),
			) {
			case ^typecheck.Array:
				res = backend.graph_add_c_int(ctx, "len", dt, i64(t.len))
			case ^typecheck.Slice:
				slc := emit_nodes(ctx, {}, d.args[0])
				assert(slc.is_lvalue)
				res = field_load(ctx, "slen", dt, slc.id, 8)
			case typecheck.String_Type:
				slc := emit_nodes(ctx, {}, d.args[0])
				assert(slc.is_lvalue)
				res = field_load(ctx, "slen", dt, slc.id, 8)
			case typecheck.Pointer:
				#partial switch nt in typecheck.unpack_type(t^) {
				case ^typecheck.Array:
					res = backend.graph_add_c_int(ctx, "len", dt, i64(nt.len))
				case:
					fmt.panicf("TODO: index ptr to type of %#v", t)
				}
			case:
				fmt.panicf("TODO: len of %#v", t)
			}
			break match
		case .raw_data:
			#partial switch t in typecheck.unpack_type(
				typecheck.get_node_type(d.args[0]),
			) {
			case ^typecheck.Array:
				slc := emit_nodes(ctx, {}, d.args[0])
				assert(slc.is_lvalue)
				res = slc.id
			case ^typecheck.Slice:
				slc := emit_nodes(ctx, {}, d.args[0])
				assert(slc.is_lvalue)
				res = field_load(ctx, "slen", dt, slc.id, 0)
			case typecheck.String_Type:
				slc := emit_nodes(ctx, {}, d.args[0])
				assert(slc.is_lvalue)
				res = field_load(ctx, "slen", dt, slc.id, 0)
			case typecheck.Pointer:
				#partial switch nt in typecheck.unpack_type(t^) {
				case ^typecheck.Array:
					slc := emit_nodes(ctx, {}, d.args[0])
					res = to_rvalue(ctx, slc, d.args[0])
				case:
					fmt.panicf("TODO: index ptr to type of %#v", t)
				}
			case:
				fmt.panicf("TODO: raw_data of %#v", t)
			}
			break match
		case .size_of:
			res = backend.graph_add_c_int(
				ctx,
				"cnst",
				dt,
				i64(
					typecheck.type_size(
						typecheck.get_node_meta(d.args[0]).lit.typeida,
					),
				),
			)
			break match
		case .align_of:
			res = backend.graph_add_c_int(
				ctx,
				"cnst",
				dt,
				i64(
					typecheck.type_align(
						typecheck.get_node_meta(d.args[0]).lit.typeida,
					),
				),
			)
			break match
		}

		base_meta := typecheck.get_node_meta(d.expr)
		base_ty := base_meta.type

		switch {
		case typecheck.is_of(base_ty, ^typecheck.Proc_Type):
			prc := base_meta.lit.procid
			fptr: backend.Node_ID
			siga: ^typecheck.Proc_Type
			if base_meta.lit.procid == 0 {
				fptr = to_rvalue(ctx, emit_nodes(ctx, {}, d.expr), d.expr)
				siga = typecheck.unpack_type(base_ty).(^typecheck.Proc_Type)
			}

			results := emit_call(ctx, d, siga, prc, fptr, nil, prop.dest)
			if len(results) > 0 {
				last := results[len(results) - 1]
				res, lvalue = last.id, last.is_lvalue
			}
		case base_ty == .Intrinsic:
			switch base_meta.lit.intrinsic {
			case .syscall:
				args := make([]backend.Node_ID, CALL_PREFIX + len(d.args), tmp)
				for arg, i in d.args {
					vl := emit_nodes(ctx, {}, arg)
					args[CALL_PREFIX + i] = to_rvalue(ctx, vl, arg)
					backend.graph_pin(ctx, args[CALL_PREFIX + i])
				}

				args[0] = ctx_ctrl(ctx)
				args[1] = ctx_mem(ctx)
				args[2] = ctx.start

				call := backend.graph_add_call(ctx, "call", args, ~u32(0))
				backend.graph_extra(ctx, call, backend.Call).ccid = 1
				for arg in args[CALL_PREFIX:] {
					backend.graph_unpin(ctx, arg)
				}
				call_end := backend.graph_add_call_end(ctx, "calle", call)

				backend.graph_set_input(ctx, ctx.node_scope, 0, call_end)
				ctx_set_mem(ctx, backend.graph_add_mem(ctx, "cmem", call_end))

				res = backend.graph_add_ret(ctx, "cret", .I64, call_end, 0)

				break match
			}
		case base_ty == .Module:
			panic("calling a module?")
		case base_ty == .Typeid:
			dest_dt := typecheck.type_to_dt(base_meta.lit.typeida)
			src_ty := typecheck.get_node_type(d.args[0])
			src_dt := typecheck.type_to_dt(src_ty)
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
					wop: backend.Un_Op =
						src_ty in typecheck.SIGNED_TYPES ? .Sext : .Uext
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
			case dest_dt != src_dt:
				op: backend.Un_Op = .Uext
				if src_ty in typecheck.SIGNED_TYPES {
					op = .Sext
				}
				if typecheck.type_size(src_ty) >
				   typecheck.type_size(base_meta.lit.typeida) {
					op = .Cast
				}
				res = backend.graph_add_un_op(ctx, "cst", op, dest_dt, arg)
			case:
				res = arg
			}
		case:
			fmt.panicf("TODO: %v %v", base_ty, node)
		}
	case ^ast.Branch_Stmt:
		label := typecheck.src_of(ctx.file^, d.label)

		loop := ctx.loop
		for ; loop != nil; loop = loop.parent {
			if loop.label == label || label == "" {
				break
			}
		}
		assert(loop != nil)

		variant := builder.Loop_Control(-1)
		#partial switch d.tok.kind {
		case .Break:
			variant = .Break
		case .Continue:
			variant = .Continue
		case:
			fmt.panicf("TODO: %#v", node.derived)
		}

		builder.graph_loop_control(variant, ctx, ctx.node_scope, &loop.bstate)
		ctx.node_scope = 0
	case ^ast.Proc_Lit:
		meta := typecheck.get_node_meta(node)
		res = backend.graph_add_proc_addr(ctx, "fptr")
		backend.graph_extra(ctx, res, backend.Tup).idx = u32(meta.lit.procid)
	case:
		fmt.panicf("TODO: %#v", node.derived)
	}

	res = backend.graph_peep(ctx, res)

	return {id = res, is_lvalue = lvalue}
}

call_proc_of :: proc(
	ctx: ^Gen_Ctx,
	node: ^ast.Node,
) -> (
	typecheck.Proc_ID,
	bool,
) {
	call, cok := node.derived.(^ast.Call_Expr)
	if !cok do return {}, false
	m := typecheck.get_node_meta(call.expr)
	if !typecheck.is_of(m.type, ^typecheck.Proc_Type) do return {}, false
	return m.lit.procid, m.lit.procid != 0
}

emit_call :: proc(
	ctx: ^Gen_Ctx,
	d: ^ast.Call_Expr,
	sig: ^typecheck.Proc_Type,
	prc_id: typecheck.Proc_ID,
	ptr: backend.Node_ID,
	out_slots: []backend.Node_ID,
	prop_dest: backend.Node_ID = 0,
) -> []Value {
	context.allocator, _ = arna.scrath()
	sig := sig

	imported := ctx.procs[prc_id].lit.body == nil
	if prc_id != 0 do sig = ctx.procs[prc_id].sig

	rets := sig.rets
	rabi := typecheck.ret_abi(rets)

	results := make([]Value, len(rets), context.temp_allocator)

	slots := make([]backend.Node_ID, len(rets))
	for j in 0 ..< len(rets) {
		if out_slots != nil && out_slots[j] != 0 {
			slots[j] = out_slots[j]
		}
		if typecheck.ret_is_by_pointer(rabi, j) && slots[j] == 0 {
			slots[j] = alloca(ctx, "rtmp", rets[j], zeroed = false)
		}
		if slots[j] != 0 do backend.graph_pin(ctx, slots[j])
	}

	arg_count := len(d.args)
	spread_prc: typecheck.Proc_ID
	if len(d.args) == 1 && len(d.args) != len(sig.params) {
		spread_prc = call_proc_of(ctx, d.args[0]) or_else panic("")
		arg_count = len(ctx.procs[spread_prc].rets)
	}

	backend.graph_pin(ctx, ptr)

	args := make(
		[]backend.Node_ID,
		CALL_PREFIX + (arg_count + len(rets) + 1) * 2 + int(ptr != 0),
	)

	lctx: Lower_Ctx
	lctx.i = CALL_PREFIX
	lctx.ri = len(args)
	if imported do lctx.sm.type = .C

	for j in rabi.srets_start ..< len(rabi.extras) {
		lower_call_arg(ctx, args, &lctx, .I64, Value(slots[j]))
	}

	if spread_prc != 0 {
		results := emit_call(
			ctx,
			d.args[0].derived.(^ast.Call_Expr),
			nil,
			spread_prc,
			0,
			nil,
		)
		for r, j in results {
			lower_call_arg(ctx, args, &lctx, ctx.procs[spread_prc].rets[j], r)
		}
	} else {
		for arg in d.args {
			ty := typecheck.get_node_type(arg)
			vl := emit_nodes(ctx, {}, arg)
			lower_call_arg(ctx, args, &lctx, ty, vl)
		}
	}

	if ptr != 0 do lower_call_arg(ctx, args, &lctx, .I64, Value(ptr))
	backend.graph_unpin(ctx, ptr)

	for j in 0 ..< rabi.srets_start {
		lower_call_arg(ctx, args, &lctx, .I64, Value(slots[j]))
	}

	for j in 0 ..< len(rabi.extras) {
		results[j] = Value {
			id        = slots[j],
			is_lvalue = true,
		}
	}

	args[0] = ctx_ctrl(ctx)
	args[1] = ctx_mem(ctx)
	args[2] = ctx.sym
	if ptr != 0 do args[2] = ctx.start

	slice.reverse(args[lctx.ri:])
	copy(args[lctx.i:], args[lctx.ri:])
	ln := lctx.i + len(args) - lctx.ri

	call := backend.graph_add_call(ctx, "call", args[:ln], u32(prc_id))
	backend.graph_extra(ctx, call, backend.Call).imported = imported
	backend.graph_extra(ctx, call, backend.Call).indirect = prc_id == 0
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

		ty := rets[res_idx]
		dest := out_slots != nil ? out_slots[res_idx] : prop_dest
		dt := typecheck.type_to_dt(ty)

		if dt == .Void {
			size := typecheck.type_size(ty)
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
