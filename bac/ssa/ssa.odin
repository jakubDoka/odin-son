package bac_ssa

import bac ".."
import "../../utils/arna"
import "../../utils/fmt"
import "../arm"
import "../regalloc"
import "../wasm"
import "../x64"
import "core:mem"
import "core:slice"

Proc :: bac.Proc
get_node :: bac.get_node

btype :: #force_inline proc(node: bac.Expanded_Node) -> Node_Type {
	return Node_Type(node.rtype)
}

/// Run the platform independend optimizations. This is preconfigured simple run
/// of passes. To enable passes, you can configure them in the
/// ctx.prc.opt_flags, by default, no passes except mandatory ones are enabled.
///
/// For separate passes, grep for `apply_peeps`, `conpute_latices`, `memopt`,
/// `loopopt`. They have their own documentation.
@(tag = "api,priority=97")
opt :: proc(ctx: bac.Peep_Ctx) {
	DEBUG_OPT :: false

	for dirty, limit := true, 100; dirty; limit -= 1 {
		assert(limit > 0)

		dirty = false
		dirty_peep := bac.apply_peeps(ctx)
		when DEBUG_OPT do fmt.println("peeps:", dirty_lat)
		dirty_mem := memopt(ctx)
		when DEBUG_OPT do fmt.println("mem:", dirty_lat)

		dirty = dirty_peep | dirty_mem
	}

	when DEBUG_OPT do fmt.println("next pass")

	for dirty, limit := true, 100; dirty; limit -= 1 {
		context.allocator, _ = arna.scrath(ctx.temps)

		assert(limit > 0)
		dirty = false
		dirty_loop := loopopt(ctx)
		when DEBUG_OPT do fmt.println("loopopt:", dirty_loop)
		dirty_lat := bac.compute_latices(ctx)
		when DEBUG_OPT do fmt.println("lat:", dirty_lat)
		dirty_peep := bac.apply_peeps(ctx)
		when DEBUG_OPT do fmt.println("peeps:", dirty_peep)
		dirty_mem := memopt(ctx)
		when DEBUG_OPT do fmt.println("mem:", dirty_mem)
		dirty = dirty_lat | dirty_peep | dirty_mem | dirty_loop
	}
}

/// Compile the proc to the current node_spec. The minimal configuration of the
/// context is the `.prc` and `.buf.code`. Function will crash the program if
/// other buffers are required. This function also computes missing
/// datastructures, you can compute them your self and set the pointers if you
/// need customization. Note that all of the functions this calls are also
/// available in the API.
@(tag = "api,priority=98")
compile :: proc(ctx: bac.Codegen_Emit_Ctx) -> (res: bac.Codegen_Output) {
	ctx := ctx

	fmt.assertf(ctx.prc != nil, "codegen context needs a .prc to be set")
	context.allocator, _ = arna.scrath(ctx.prc.temps)

	if ctx.prc.node_spec == &SPEC {
		when !SPEC_NOT_PRESENT {
			when ODIN_ARCH == .amd64 {
				ctx.prc.node_spec = &x64.SPEC
			} else when ODIN_ARCH == .arm64 {
				ctx.prc.node_spec = &arm.SPEC
			} else when ODIN_ARCH == .wasm32 {
				ctx.prc.node_spec = &wasm.SPEC
			}
		}
	}

	fmt.assertf(
		ctx.prc.node_spec != nil && ctx.prc.node_spec != &SPEC,
		"target not configured, set .prc.node_spec",
	)

	fmt.assertf(ctx.buf.code != nil, "code buffer not configured, set .buf.code")

	if ctx.schedule == nil {
		bac.apply_peeps({ctx})

		gs: bac.Schedule
		bac.schedule_graph(ctx, &gs, .for_regalloc)
		ctx.schedule = &gs

		bac.schedule_peeps(ctx, &gs)
	}

	if ctx.dbg_data == nil {
		data: bac.Dbg_Data
		bac.take_dbg_data(ctx, ctx.schedule, &data)
		ctx.dbg_data = &data
	}

	if !ctx.ra_out.computed {
		ra: bac.Regalloc
		ra.spec = ctx.node_spec
		ra.cc = ctx.abi
		ra.param_specs = ctx.param_specs

		ctx.ra_out = regalloc.regalloc(
			&ra,
			ctx.prc,
			ctx.schedule,
			ctx.regalloc_mode,
		)
	}

	check := bac.buf_checkpoint(&ctx.buf)
	res.emit = ctx.prc.emit_function(ctx)
	res.bufs = bac.buf_output(ctx.buf, check)

	return
}

ssa_extra :: proc {
	ssa_extra_node,
	ssa_extra_node_id,
}

@(tag = "api")
decl_local :: proc(prc: ^Proc, loc: Node_ID, name: string, type: u64) {
	loc := loc
	if node := expand_node(prc, loc); node.itype == .Local_Addr {
		loc = node.inps[0]
	}

	if get_node(prc, loc).itype != .Local do return

	if prc.has_dbg {
		decl := bac.add_dbg_sym_decl(prc, name)
		bac.get_extra(prc, decl, bac.Dbg_Sym).name = name
		bac.get_extra(prc, decl, bac.Dbg_Sym).type = type
		bac.connect(prc, loc, decl)
	}
}

/// The args[0] needs to be a control flow, args[1] should be an end of a memory
/// thread. You have to call this at least once if the function has reachable
/// return path.
@(tag = "api,priority=99")
merge_return :: proc(prc: ^Proc, args: []Node_ID) -> Node_ID {
	ret := bac.get_inputs(prc, prc.end)[0]

	if ret == 0 {
		ret = bac.add_return(prc, "ret", args)
		bac.set_input(prc, prc.end, 0, ret)
	} else {
		// TODO: extend existing region if possible
		reg := bac.add_region(prc, "rreg", {bac.get_inputs(prc, ret)[0], args[0]})
		bac.set_input(prc, ret, 0, reg)
		for inp, i in bac.get_inputs(prc, ret)[1:] {
			bac.set_input(
				prc,
				ret,
				i + 1,
				bac.add_phi(prc, "rphy", get_node(prc, inp).dt, reg, inp, args[i + 1]),
			)
		}
	}

	return ret
}

add_load :: #force_inline proc(
	prc: ^Proc,
	name: string,
	dt: bac.Node_Datatype,
	ctrl: Node_ID,
	mem: Node_ID,
	addr: Node_ID,
) -> (
	_id: Node_ID,
) {
	ctrl := ctrl
	if bac.is_always_valid_ptr(prc, addr) {
		ctrl = 0
	}

	return bac.add_load(prc, name, dt, ctrl, mem, addr)
}

add_store :: proc(
	prc: ^Proc,
	name: string,
	ctrl: Node_ID,
	mem: Node_ID,
	addr: Node_ID,
	value: Node_ID,
) -> (
	_id: Node_ID,
) {
	ctrl := ctrl
	if bac.is_always_valid_ptr(prc, addr) {
		ctrl = 0
	}

	return bac.add_store(prc, name, ctrl, mem, addr, value)
}

ssa_extra_node :: #force_inline proc(
	prc: ^bac.Proc,
	node: ^bac.Node,
	$T: typeid,
) -> ^T {
	if prc.inheritance_table[node.rtype] & (1 << inherit_idx_of(T)) == 0 {
		return nil
	}
	return (^T)(&node.extra)
}

ssa_extra_node_id :: #force_inline proc(
	prc: ^bac.Proc,
	id: Node_ID,
	$T: typeid,
) -> ^T {
	return ssa_extra_node(prc, get_node(prc, id), T)
}

@(tag = "api")
make_call :: proc(
	prc: ^bac.Proc,
	args: []Node_ID,
	extra: bac.Call,
) -> (
	ctrl: Node_ID,
	mem: Node_ID,
) {
	assert(bac.is_cfg(prc, args[0]))
	assert(get_node(prc, args[1]).dt == .Mem)
	assert(args[2] == 0 || get_node(prc, args[2]).itype == .Sym)

	call := bac.add_call(prc, "call", args, extra)
	ctrl = bac.add_call_end(prc, "calle", call)
	mem = bac.add_mem(prc, "cmem", ctrl)
	return
}

add_call_ret :: proc(
	prc: ^bac.Proc,
	on: Node_ID,
	dt: bac.Node_Datatype,
) -> Node_ID {
	assert(get_node(prc, on).itype == .Call_End)

	call_ext := bac.get_extra(prc, bac.get_inputs(prc, on)[0], bac.Call)
	call_ext.rets[call_ext.ret_count] = dt
	call_ext.ret_count += 1

	return bac.add_ret(prc, "cret", dt, on, u32(call_ext.ret_count - 1))
}

If_State :: struct {
	if_:          Node_ID,
	using branch: struct #raw_union {
		else_scope: Node_ID,
		then_scope: Node_ID,
	},
}

@(tag = "api")
start_if :: proc(
	prc: ^bac.Proc,
	scope: Node_ID,
	state: ^If_State,
	cond: Node_ID,
) {
	snode := expand_node(prc, scope)
	state.if_ = bac.add_if(prc, "if", snode.inps[0], cond)
	state.else_scope = bac.clone(prc, scope)

	then := bac.add_then(prc, "then", state.if_)
	bac.set_input(prc, scope, 0, then)
}

@(tag = "api")
end_if :: proc(prc: ^bac.Proc, then_scope: ^Node_ID, state: ^If_State) {
	start_else(prc, then_scope, state)
	end_else(prc, then_scope, state)
}

@(tag = "api")
start_else :: proc(prc: ^bac.Proc, then_scope: ^Node_ID, state: ^If_State) {
	else_ := bac.add_else(prc, "else", state.if_)
	bac.set_input(prc, state.else_scope, 0, else_)
	then_scope^, state.then_scope = state.else_scope, then_scope^
}

@(tag = "api")
end_else :: proc(prc: ^bac.Proc, else_scope: ^Node_ID, state: ^If_State) {
	else_scope^ = merge_scopes(prc, state.then_scope, else_scope^)
}

Block_State :: struct {
	end_scope: Node_ID,
}

@(tag = "api")
start_block :: proc(state: ^Block_State) {
	state^ = {}
}

@(tag = "api")
break_block :: proc(prc: ^bac.Proc, scope: ^Node_ID, state: ^Block_State) {
	state.end_scope = merge_scopes(prc, state.end_scope, scope^)
	scope^ = 0
}

@(tag = "api")
end_block :: proc(prc: ^bac.Proc, scope: ^Node_ID, state: ^Block_State) {
	state.end_scope = merge_scopes(prc, state.end_scope, scope^)
	scope^ = state.end_scope
}

Loop_Control :: enum int {
	Break,
	Continue,
}

Loop_State :: struct {
	scope:  Node_ID,
	scopes: [Loop_Control]Node_ID,
}

@(tag = "api")
start_loop :: proc(prc: ^bac.Proc, scope: Node_ID, state: ^Loop_State) {
	snode := expand_node(prc, scope)
	loop := bac.add_loop(prc, "loop", snode.inps[0])
	bac.set_input(prc, scope, 0, loop)
	state.scope = bac.clone(prc, scope)

	bac.add_output(prc, state.scope, 0, 0)

	snode = expand_node(prc, scope)
	for i in 1 ..< snode.input_count {
		bac.set_input(prc, scope, i, state.scope)
	}
}

@(tag = "api")
start_loop_increment :: proc(
	prc: ^bac.Proc,
	node_scope: ^Node_ID,
	state: ^Loop_State,
) {
	loop_control(.Continue, prc, node_scope^, state)
	node_scope^ = state.scopes[.Continue]
	state.scopes[.Continue] = 0
}

@(tag = "api")
end_loop :: proc(prc: ^bac.Proc, node_scope: ^Node_ID, state: ^Loop_State) {
	start_loop_increment(prc, node_scope, state)

	init := expand_node(prc, state.scope)
	loop := init.inps[0]
	assert(get_node(prc, loop).itype == .Loop)

	bscope := node_scope^
	if bscope != 0 {
		context.allocator, _ = arna.scrath(prc.temps)

		backedge := expand_node(prc, bscope)
		fmt.assertf(
			init.input_count == backedge.input_count,
			"%v == %v: you should make sure the loop scopes are properly truncated, you can inspect the ",
			init,
			backedge,
		)
		for i in 1 ..< init.input_count {
			init := init.inps[i]
			inode := expand_node(prc, init)
			bnode := expand_node(prc, backedge.inps[i])
			if btype(inode) != .Lazy_Phi || inode.inps[0] != loop do continue

			for {
				scp := ssa_extra(prc, bnode, Scope)
				if scp == nil || !scp.done || bnode.inps[0] == loop do break
				bnode = expand_node(prc, bnode.inps[i])
			}

			if btype(bnode) == .Scope || inode.node == bnode.node {
				bac.subsume(prc, inode.inps[1], init)
			} else {
				bac.connect(prc, init, bac.get_node_id(prc, bnode))
				inode.itype = .Phi
				id := bac.intern(prc, init)
				if id != init {
					bac.subsume(prc, id, init)
				}
			}
		}

		assert(get_node(prc, init.inps[0]).itype == .Loop)
		bac.connect(prc, init.inps[0], backedge.inps[0])
	}

	node_scope^ = state.scopes[.Break]

	if node_scope^ != 0 {
		exit := expand_node(prc, node_scope^)
		for i in 1 ..< exit.input_count {
			enode := expand_node(prc, exit.inps[i])
			if btype(enode) == .Scope && enode.inps[0] == loop {
				bac.set_input(prc, node_scope^, i, init.inps[i])
			}
		}
	}

	ssa_extra(prc, state.scope, Scope).done = true
	bac.remove_output(prc, state.scope, {id = 0, idx = 0})

	if bscope != 0 {
		bac.delete_node(prc, bscope)
	} else {
		for out in bac.get_outputs(prc, loop) {
			onode := expand_node(prc, out.id)
			if btype(onode) == .Lazy_Phi {
				bac.subsume(prc, onode.inps[1], out.id)
			}
		}

		bac.subsume(prc, bac.get_inputs(prc, loop)[0], loop)
	}

	return
}

@(tag = "api")
loop_control :: proc(
	variant: Loop_Control,
	ctx: ^bac.Proc,
	scope: Node_ID,
	loop: ^Loop_State,
) {
	truncate_scope(ctx, scope, get_node(ctx, loop.scope).input_count)
	loop.scopes[variant] = merge_scopes(ctx, scope, loop.scopes[variant])
}

@(tag = "api")
get_scope_value :: proc(
	prc: ^bac.Proc,
	scope: Node_ID,
	#any_int idx: int,
) -> Node_ID {
	snode := get_node(prc, scope)
	fmt.assertf(Node_Type(snode.rtype) == .Scope, "%v")

	val := bac.get_inputs(prc, snode)[idx]
	vnode := expand_node(prc, val)
	loop_scope := ssa_extra(prc, vnode, Scope)
	if loop_scope != nil {
		pval := val
		val = get_scope_value(prc, val, idx)
		cvnode := expand_node(prc, val)
		if (btype(cvnode) != .Lazy_Phi || vnode.inps[0] != cvnode.inps[0]) &&
		   !loop_scope.done {
			assert(get_node(prc, vnode.inps[0]).itype == .Loop)
			val = add_lazy_phi(
				prc,
				"lphi",
				get_node(prc, val).dt,
				vnode.inps[0],
				val,
			)
			bac.set_input(prc, pval, idx, val)
		}
		bac.set_input(prc, scope, idx, val)
	}

	return val
}

should_debug_track :: proc(prc: ^bac.Proc, value: Node_ID) -> bool {
	return prc.has_dbg && get_node(prc, value).dt > .Mem
}

/// declare a scalar value or a memory thread that should have phys generated
/// based on updates done by set_scope_value and must be accessed trough
/// get_scope_value, it retunrs the index withing the scope by which you can
/// acces and modify the value.
@(tag = "api,priority=99")
push_scope_value :: proc(
	prc: ^bac.Proc,
	scope: Node_ID,
	value: Node_ID,
	name: string,
	type: u64,
) -> (
	id: int,
) {
	scope_node := get_node(prc, scope)
	assert(Node_Type(scope_node.rtype) == .Scope)
	if should_debug_track(prc, value) {
		decl := bac.add_dbg_sym_decl(prc, name)
		bac.get_extra(prc, decl, bac.Dbg_Sym).name = name
		bac.get_extra(prc, decl, bac.Dbg_Sym).type = type
		update := bac.add_dbg_sym_update(prc, "init", value, decl)
		bac.connect(prc, scope, update)
	}
	return bac.connect(prc, scope, value)
}

/// Update the scope value so it gets phys generated to express the ssa
/// changes.
@(tag = "api,priority=99")
set_scope_value :: proc(
	prc: ^bac.Proc,
	scope: Node_ID,
	#any_int idx: int,
	value: Node_ID,
) {
	prev_value := get_scope_value(prc, scope, idx)
	if should_debug_track(prc, prev_value) {
		prev_dbg := get_scope_value(prc, scope, idx - 1)
		update := bac.add_dbg_sym_update(prc, "dbgu", value, prev_dbg)
		bac.set_input(prc, scope, idx - 1, update)
	}
	bac.set_input(prc, scope, idx, value)
}

/// Delete the scope properly. This is nescessary to generate a proper debug
/// info.
@(tag = "api,priority=99")
delete_scope :: proc(prc: ^bac.Proc, scope: Node_ID) {
	truncate_scope(prc, scope, 1)
	bac.delete_node(prc, scope)
}

/// Drops value that are no loger alive from the scope, this usually should be
/// called at the end of a lexical scope.
@(tag = "api,priority=99")
truncate_scope :: proc(prc: ^bac.Proc, scope: Node_ID, #any_int to_len: int) {
	snode := expand_node(prc, scope)

	if prc.has_dbg && scope != 0 {
		context.allocator, _ = arna.scrath(prc.temps)
		vars: [dynamic]Node_ID
		append(&vars, snode.inps[0])

		for i in to_len ..< int(snode.input_count) {
			vl := get_scope_value(prc, scope, i)
			if should_debug_track(prc, vl) {
				append(&vars, get_scope_value(prc, scope, i - 1))
			}
		}

		if len(vars) > 1 {
			dbg_scope := bac.add_dbg_scope(prc, "dbgsp", vars[:])
			bac.connect(prc, prc.end, dbg_scope)
		}
	}

	bac.truncate_inputs(prc, scope, to_len)
}

merge_scopes :: proc(
	prc: ^bac.Proc,
	lctrl: Node_ID,
	rctrl: Node_ID,
) -> Node_ID {
	if lctrl == 0 do return rctrl
	if rctrl == 0 do return lctrl

	lnode := expand_node(prc, lctrl)
	assert(btype(lnode) == .Scope)
	rnode := expand_node(prc, rctrl)
	assert(btype(rnode) == .Scope)

	lcount := lnode.input_count
	rcount := rnode.input_count

	fmt.assertf(lcount == rcount, "%v == %v %v", lcount, rcount)

	region := bac.add_region(prc, "reg", {lnode.inps[0], rnode.inps[0]})

	for i in 1 ..< lcount {
		if lnode.inps[i] == rnode.inps[i] do continue
		lvalue := get_scope_value(prc, lctrl, i)
		rvalue := get_scope_value(prc, rctrl, i)
		if lvalue == rvalue do continue

		phi := bac.add_phi(
			prc,
			"phi",
			get_node(prc, lvalue).dt,
			region,
			lvalue,
			rvalue,
		)
		bac.set_input(prc, lctrl, i, phi)
	}

	bac.set_input(prc, lctrl, 0, region)
	bac.delete_node(prc, rnode)

	return lctrl
}

inline_call :: proc {
	inline_graph,
	inline_stencil,
}

/// This just expands the `from` into a graph, refer to `inline_graph` for
/// docs.
@(tag = "api,priority=95")
inline_stencil :: proc(prc: ^bac.Proc, call: Node_ID, from: bac.Stencil) {
	slot: arna.Allocator
	from_prc: bac.Proc
	from_prc.node_spec = &SPEC
	from_prc.mem = &slot
	from_prc.temps = prc.temps
	bac.mount_stencil(&from_prc, from)
	inline_graph(prc, call, &from_prc)
}

/// Grep for "inline_and_optimize ::" for an example usage.
///
/// Inline a `from` into `prc` at `call`, the from and the call node shoul
/// refer to the same function, or more precisely, the signatrue needs to be
/// compatible. This invalidates whatever passes that were computes so its
/// better to do this in bulk.
///
/// Good strategy is to optimize the `from` before inlining to maximize inline
/// performance since same code does not get copyes and reoptimized
/// redundantly.
@(tag = "api,priority=95")
inline_graph :: proc(prc: ^bac.Proc, call: Node_ID, from: ^bac.Proc) {
	assert(prc.node_spec == &SPEC)

	bac.add_efficiency_stat(prc, .inlines, 1)
	bac.add_efficiency_stat(prc, .duplicated_nodes, from.gvn)

	context.allocator, _ = arna.scrath(prc.temps)

	bac.verify(prc)

	prc.computed_passes = {}
	prc.max_idepth = max(prc.max_idepth, from.max_idepth)
	bac.invalidate_idepth(prc)

	Ctx :: struct {
		prc:            ^bac.Proc,
		from:           ^bac.Proc,
		projection:     []Node_ID,
		reached_return: bool,
	}

	proj_of :: proc(ctx: ^Ctx, id: Node_ID) -> ^bac.Node_ID {
		return &ctx.projection[get_node(ctx.from, id).gvn]
	}

	ctx: Ctx
	ctx.prc = prc
	ctx.prc.curret_sloc = {}
	ctx.from = from
	ctx.projection = make([]Node_ID, from.gvn)

	call := expand_node(prc, call)
	assert(call.itype == .Call)
	proj_of(&ctx, from.entry)^ = call.inps[0]
	proj_of(&ctx, bac.find_node(from, .Mem))^ = call.inps[1]
	proj_of(&ctx, bac.find_node(from, .Sym))^ = call.inps[2]
	proj_of(&ctx, 0)^ = 0

	bac.assert_live_pins(from)

	params, starter := bac.assemble_args(
		from,
		int(call.input_cap) - bac.CALL_PREFIX,
	)

	assert(proj_of(&ctx, starter)^ == 0)

	rmem := bac.find_node(prc, .Mem)
	for param, ai in params {
		pnode := expand_node(from, param)
		arg_idx := ai + bac.CALL_PREFIX
		arg := raw_data(call.inps)[arg_idx]
		arg_node := expand_node(prc, arg)
		if param == 0 do continue
		if arg_node.itype != .Local {
			assert(pnode.itype != .Local)
		} else {
			assert(arg_node.inps[0] == prc.entry)
			bac.set_input(prc, arg, 0, rmem)
			if pnode.itype == .Local {
				// project the addr too or we get dups
				assert(ctx.projection[pnode.gvn] == 0)
				ctx.projection[get_node(from, pnode.outs[0].id).gvn] =
					arg_node.outs[0].id
			} else {
				// reach out for the store value
				arg = arg_node.outs[0].id
				arg = bac.get_outputs(prc, arg)[0].id
				arg = bac.get_inputs(prc, arg)[3]
			}
		}
		assert(ctx.projection[pnode.gvn] == 0)
		ctx.projection[pnode.gvn] = arg
	}

	assert(proj_of(&ctx, starter)^ == 0)

	clone_along_cfg(&ctx, starter)

	call_end := expand_node(prc, call.outs[0].id)

	from_end := expand_node(from, from.end)
	for inp in from_end.inps[1:] {
		inode := expand_node(from, inp)
		end := ctx.projection[inode.gvn]
		bac.connect(prc, prc.end, end)
	}

	if ctx.reached_return {
		assert(from_end.inps[0] != 0)
		from_ret := expand_node(from, from_end.inps[0])

		for co in call_end.outs {
			coonode := expand_node(ctx.prc, co.id)
			if coonode.itype == .Mem {
				sub := get_node(from, from_ret.inps[1])
				bac.subsume(prc, ctx.projection[sub.gvn], co.id)
			}
			if coonode.itype == .Ret {
				idx := bac.get_extra(prc, coonode, bac.Tup).idx
				ret_idx := bac.RET_PREFIX + idx
				if int(ret_idx) < len(from_ret.inps) {
					sub := get_node(from, from_ret.inps[ret_idx])
					bac.subsume(prc, ctx.projection[sub.gvn], co.id)
				} else {
					psn := bac.add_poison(prc, "irps")
					bac.subsume(prc, psn, co.id)
				}
			}
		}

		bac.subsume(
			prc,
			ctx.projection[get_node(from, from_ret.inps[0]).gvn],
			call.outs[0].id,
		)

		for ri in from_ret.inps[1:] {
			rinode := get_node(from, ri)
			nd := ctx.projection[rinode.gvn]
			bac.delete_node(prc, nd)
		}
	} else {
		bac.subsume(prc, 0, call.outs[0].id)
	}

	bac.assert_live_pins(prc)

	bac.verify(prc)

	clone_along_cfg :: proc(ctx: ^Ctx, root: Node_ID) {
		rnode := expand_node(ctx.from, root)
		if ctx.projection[rnode.gvn] != 0 do return

		if rnode.itype == .Region {
			for i in rnode.inps {
				inode := expand_node(ctx.from, i)
				if ctx.projection[inode.gvn] == 0 {
					return
				}
			}

			for out in rnode.outs {
				onode := expand_node(ctx.from, out.id)
				if onode.itype == .Phi {
					for inp in onode.inps[1:] {
						clone_node(ctx, inp)
					}
				}
			}
		}

		if rnode.itype == .Loop {
			for out in rnode.outs {
				onode := expand_node(ctx.from, out.id)
				if onode.itype == .Phi {
					clone_node(ctx, onode.inps[1])
				}
			}
		}

		clone_node(ctx, root)
		nid := ctx.projection[rnode.gvn]

		for out in rnode.outs {
			onode := expand_node(ctx.from, out.id)
			if !bac.is_cfg(ctx.from, out.id) && onode.itype != .Dbg_Scope do continue

			if onode.itype == .Loop && out.idx == 1 {
				proj := ctx.projection[onode.gvn]
				bac.connect(ctx.prc, proj, nid)

				for lout in onode.outs {
					lonode := expand_node(ctx.from, lout.id)
					if lonode.itype == .Phi {
						clone_node(ctx, lonode.inps[2])
						lproj := ctx.projection[lonode.gvn]
						lpnode := get_node(ctx.prc, lproj)
						backedge := get_node(ctx.from, lonode.inps[2])
						bproj := ctx.projection[backedge.gvn]
						assert(Node_Type(lpnode.rtype) == .Lazy_Phi)
						lpnode.itype = .Phi
						bac.connect(ctx.prc, lproj, bproj)
						id := bac.intern(ctx.prc, lproj)
						if id != lproj {
							bac.subsume(ctx.prc, id, lproj)
							assert(ctx.projection[lonode.gvn] == 0)
							ctx.projection[lonode.gvn] = id
						}
					}
				}

				continue
			}

			clone_along_cfg(ctx, out.id)
		}
	}

	clone_node :: proc(ctx: ^Ctx, root: Node_ID) {
		if root == 0 do return

		prc := ctx.prc

		node := expand_node(ctx.from, root)
		if ctx.projection[node.gvn] != 0 do return

		input_cap := node.input_cap
		rtype := node.rtype
		input_cap = node.input_count

		if node.itype == .Loop {
			input_cap = 1
		}

		if node.itype == .Phi && get_node(ctx.from, node.inps[0]).itype == .Loop {
			rtype = u16(Node_Type.Lazy_Phi)
			input_cap = 2
		}

		inps := make([]Node_ID, input_cap)
		for inp, i in node.inps[:input_cap] {
			clone_node(ctx, inp)
			inps[i] = proj_of(ctx, inp)^
		}

		if node.itype == .Local {
			root_mem := bac.find_node(ctx.from, .Mem)
			if node.inps[0] == root_mem {
				inps[0] = bac.find_node(ctx.prc, .Mem)
			}

			if node.inps[0] == ctx.from.entry {
				inps[0] = prc.entry
			}
		}

		if node.itype == .Return {
			ctx.reached_return = true
			assert(node.inps[0] != 0)
			return
		}

		prev := prc.mem.pos

		new_node, id := bac.shallow_clone(prc, node)
		new_node.rtype = rtype
		bac.init_counts(prc, new_node)

		new_node.input_idx = u32(prc.mem.pos / bac.PRECISION)
		_ = arna.clone(prc.mem, inps)
		new_node.input_cap = input_cap
		new_node.input_count = min(new_node.input_count, input_cap)

		new_node.output_idx = u32(prc.mem.pos / bac.PRECISION)
		_ = arna.alloc(
			prc.mem,
			uint(node.output_cap * size_of(bac.Node_Output)),
			bac.PRECISION,
		)
		new_node.output_count = 0
		new_node.output_cap = node.output_cap

		interned := bac.intern(prc, id)
		if interned != id {
			prc.mem.pos = prev
			id = interned
		} else {
			for inp, i in inps {
				bac.add_output(prc, inp, id, i)
			}

			assert(ctx.projection[node.gvn] == 0)

			bac.on_node_creation(prc, new_node)
		}

		ctx.projection[node.gvn] = id
	}
}

ordered_remove :: proc(ctx: ^bac.Proc, node: ^bac.Expanded_Node, i: int) {
	par := bac.get_node_id(ctx, node)
	for inp, j in node.inps[i + 1:] {
		bac.add_output(ctx, inp, par, j + i)
		bac.remove_output(ctx, inp, {idx = j + i + 1, id = par})
	}
	inp := node.inps[i]
	bac.unintern(ctx, par)
	slice.rotate_left(node.inps[i:], 1)
	node.inps = node.inps[:len(node.inps) - 1]
	node.input_count -= 1
	nid := bac.intern(ctx, par)
	if nid != par do bac.subsume(ctx, nid, par)
	bac.remove_output(ctx, inp, {idx = i, id = par})
}

@(tag = "api")
compute_index_offset :: proc(
	ctx: ^bac.Proc,
	base: Node_ID,
	index: Node_ID,
	#any_int stride: i64,
) -> Node_ID {
	if stride == 0 do return base

	index := index
	if stride > 1 {
		index = bac.add_bin_op(
			ctx,
			"snoff",
			.Mul,
			.I64,
			index,
			bac.add_c_int(ctx, "sst", .I64, stride),
		)
		index = bac.apply_peep(ctx, index)
	}

	return bac.add_bin_op(ctx, "snd", .Add, .I64, base, index)
}

@(tag = "api")
add_field_offset :: proc(prc: ^Proc, base: Node_ID, offset: int) -> Node_ID {
	if offset == 0 do return base
	off := bac.add_c_int(prc, "foff", .I64, i64(offset))
	return bac.add_bin_op(prc, "fld", .Add, .I64, base, off)
}

@(tag = "api")
add_field_store :: proc(
	ctx: ^Proc,
	name: string,
	cfg: Node_ID,
	mem: Node_ID,
	base: Node_ID,
	offset: int,
	value: Node_ID,
) -> Node_ID {
	return add_store(
		ctx,
		name,
		cfg,
		mem,
		add_field_offset(ctx, base, offset),
		value,
	)
}

@(tag = "api")
add_arbitrary_store :: proc(
	ctx: ^Proc,
	cfg: Node_ID,
	mem: Node_ID,
	addr: Node_ID,
	rvalue: Node_ID,
	rsize: int,
	extra_offset := 0,
	unit: bac.Node_Datatype = .I64,
) -> (
	omem: Node_ID,
) {
	omem = mem

	store_unit := unit
	size := min(rsize - extra_offset, bac.DT_SIZE[unit])
	offset: int

	if bac.DT_SIZE[store_unit] == size {
		omem = add_field_store(
			ctx,
			"asst",
			cfg,
			omem,
			addr,
			offset + extra_offset,
			rvalue,
		)
		return
	}

	for offset < size {
		for bac.DT_SIZE[store_unit] + offset > size {
			store_unit = bac.Node_Datatype(u8(store_unit) - 1)
			assert(store_unit != .Void)
		}

		value := bac.add_un_op(
			ctx,
			"rvl",
			.U_Conv,
			store_unit,
			bac.add_bin_op(
				ctx,
				"stsh",
				.U_Shr,
				.I64,
				rvalue,
				bac.add_c_int(ctx, "stshoff", .I64, i64(offset * 8)),
			),
		)

		omem = add_field_store(
			ctx,
			"asst",
			cfg,
			omem,
			addr,
			offset + extra_offset,
			value,
		)

		offset += bac.DT_SIZE[store_unit]
	}

	return
}

@(tag = "api")
add_field_load :: proc(
	ctx: ^Proc,
	name: string,
	dt: bac.Node_Datatype,
	cfg: Node_ID,
	mem: Node_ID,
	base: Node_ID,
	offset: int = 0,
) -> Node_ID {
	return add_load(ctx, name, dt, cfg, mem, add_field_offset(ctx, base, offset))
}

@(tag = "api")
add_arbitrary_load :: proc(
	ctx: ^Proc,
	cfg: Node_ID,
	mem: Node_ID,
	addr: Node_ID,
	rsize: int,
	extra_offset := 0,
	unit: bac.Node_Datatype = .I64,
) -> Node_ID {
	load_unit := unit
	size := min(rsize - extra_offset, bac.DT_SIZE[unit])
	offset: int
	value: Node_ID

	if load_unit in bac.FLOAT_DTS {
		return add_field_load(
			ctx,
			"asld",
			load_unit,
			cfg,
			mem,
			addr,
			offset + extra_offset,
		)
	}

	for offset < size {
		for bac.DT_SIZE[load_unit] + offset > size {
			assert(load_unit not_in bac.FLOAT_DTS)
			load_unit = bac.Node_Datatype(u8(load_unit) - 1)
			assert(load_unit != .Void)
		}

		load := add_field_load(
			ctx,
			"asld",
			load_unit,
			cfg,
			mem,
			addr,
			offset + extra_offset,
		)

		if load_unit != unit {
			load = bac.add_un_op(ctx, "asxt", .U_Conv, unit, load)
		}

		if value == 0 {
			value = load
			assert(offset == 0)
		} else {
			value = bac.add_bin_op(
				ctx,
				"aor",
				.Or,
				.I64,
				value,
				bac.add_bin_op(
					ctx,
					"ash",
					.Shl,
					.I64,
					load,
					bac.add_c_int(ctx, "ssham", .I64, i64(offset * 8)),
				),
			)
		}

		offset += bac.DT_SIZE[load_unit]
	}

	return value
}

Param_Gen :: struct {
	vls:         [dynamic]Node_ID,
	spill_start: int,
}

Abi_Param :: struct {
	dt:        [dynamic; 2]bac.Node_Datatype,
	size:      int,
	real_size: int,
	spilled:   bool,
	scalar:    bool,
	copied:    bool,
}

@(tag = "api")
arg_gen_next :: proc(
	ctx: ^Proc,
	mem: Node_ID,
	gen: ^Param_Gen,
	name: string,
	apa: Abi_Param,
) -> (
	omem: Node_ID,
	value: Node_ID,
) {
	gen.vls.allocator = arna.allocator(ctx.mem)

	omem = mem
	gen.spill_start += int(!apa.spilled)

	if apa.scalar {
		dt := apa.dt[0]
		value = bac.add_param(ctx, name, dt, ctx.entry, u32(apa.spilled))
		append(&gen.vls, value)
	} else {
		nd := apa.copied ? bac.find_node(ctx, .Mem) : ctx.entry
		alloca := bac.add_local(ctx, name, nd)
		bac.get_extra(ctx, alloca, bac.Local).size = i32(apa.real_size)
		bac.get_extra(ctx, alloca, bac.Local).is_param = !apa.copied
		value = bac.add_local_addr(ctx, name, alloca)

		if !apa.copied {
			append(&gen.vls, alloca)
		}
	}

	dt := apa.dt

	for dt, j in dt[:(apa.size + 7) / 8] {
		vl := bac.add_param(ctx, name, dt, ctx.entry, 0)
		gen.spill_start += int(j == 1)
		append(&gen.vls, vl)
		omem = add_arbitrary_store(
			ctx,
			ctx.entry,
			omem,
			value,
			vl,
			apa.size,
			j * 8,
			dt,
		)
	}

	return
}

@(tag = "api")
arg_gen_finalize :: proc(ctx: ^Proc, gen: ^Param_Gen) -> []bac.Param_Spec {
	inside := arna.allocator(ctx.mem)
	if context.allocator != {} do inside = context.allocator

	arg_tys := make([]bac.Param_Spec, len(gen.vls), inside)

	j, ri: u32
	for arg in gen.vls {
		anode := get_node(ctx, arg)
		if arga := bac.get_extra(ctx, arg, bac.Tup); arga != nil {
			size: i32
			if arga.idx == 0 {
				arga.idx = j
				j += 1
			} else {
				arga.idx = u32(gen.spill_start) + ri
				size = 8
				ri += 1
			}
			arg_tys[arga.idx] = bac.Param_Spec{anode.dt, size}
		}

		if loca := bac.get_extra(ctx, arg, bac.Local); loca != nil {
			loca.size = i32(mem.align_forward_int(int(loca.size), 8))
			loca.idx = u32(gen.spill_start) + ri
			arg_tys[loca.idx] = bac.Param_Spec{.Void, loca.size}
			loca.is_param = true
			ri += 1
		}
	}
	fmt.assertf(int(j) == gen.spill_start, "%v %v", j, gen.spill_start)
	return arg_tys
}

/// Refer to examples/bac/ for a quick start.
///
/// Initialize the Proc for code emission. This returns the initial mem node
/// that should be used to advance the memory state. The starting control flow
/// node can be accessed in prc.meta.pinned.entry. Any non trivial codegen needs
/// to track control flow and initial memory in a Scope node, all of the ssa
/// builders expect the scope to have the control flow as the first input node.
@(tag = "api,priority=100")
start_proc :: proc(
	prc: ^Proc,
	mem: ^arna.Allocator,
	temps: ^arna.Temps,
) -> (
	rmem: Node_ID,
) {
	bac.ensure_init()

	assert(temps != nil)
	prc.node_spec = &SPEC
	prc.mem = mem
	prc.temps = temps
	prc.mem.pos = bac.PRECISION

	prc.gvn = 1
	prc.gdn = 1
	prc.entry = bac.add_entry(prc, "entry")
	prc.end = bac.add_end(prc, "end", {0})
	bac.pin(prc, prc.end)
	return bac.add_mem(prc, "rmem", prc.entry)
}

Builtin_Proc :: enum {
	memcpy,
	memset,
}

make_builtin_proc :: proc(prc: ^Proc, name: Builtin_Proc) {
	mem := start_proc(prc, prc.mem, prc.temps)

	scope := add_scope(prc, "scp", prc.entry)

	memv := push_scope_value(prc, scope, mem, "", 0)

	dst := bac.add_param(prc, "dst", .I64, prc.entry, 0)
	dstv := push_scope_value(prc, scope, dst, "", 0)

	val, src: Node_ID
	srcv: int
	switch name {
	case .memcpy:
		src = bac.add_param(prc, "src", .I64, prc.entry, 1)
		srcv = push_scope_value(prc, scope, src, "", 0)
	case .memset:
		val = bac.add_param(prc, "val", .I8, prc.entry, 1)
	}

	len := bac.add_param(prc, "len", .I64, prc.entry, 2)
	lenv := push_scope_value(prc, scope, len, "", 0)

	loop: Loop_State
	start_loop(prc, scope, &loop)

	if_: If_State
	cond := get_scope_value(prc, scope, lenv)
	start_if(prc, scope, &if_, cond)

	ctrl := bac.get_inputs(prc, scope)[0]
	one := bac.add_c_int(prc, "one", .I64, 1)

	mem = get_scope_value(prc, scope, memv)
	dst = get_scope_value(prc, scope, dstv)
	if src != 0 {
		src = get_scope_value(prc, scope, srcv)
		val = bac.add_load(prc, "ld", .I8, ctrl, mem, src)
	}

	mem = bac.add_store(prc, "st", ctrl, mem, dst, val)
	set_scope_value(prc, scope, memv, mem)

	add := bac.add_bin_op(prc, "add_dst", .Add, .I64, dst, one)
	set_scope_value(prc, scope, dstv, add)

	if src != 0 {
		ads := bac.add_bin_op(prc, "add_src", .Add, .I64, src, one)
		set_scope_value(prc, scope, srcv, ads)
	}

	sub := bac.add_bin_op(prc, "sub_len", .Sub, .I64, cond, one)
	set_scope_value(prc, scope, lenv, sub)

	start_else(prc, &scope, &if_)
	loop_control(.Break, prc, scope, &loop)
	scope = 0
	end_else(prc, &scope, &if_)

	end_loop(prc, &scope, &loop)

	ctrl = bac.get_inputs(prc, scope)[0]
	mem = get_scope_value(prc, scope, memv)
	merge_return(prc, {ctrl, mem})

	bac.delete_node(prc, scope)
}
