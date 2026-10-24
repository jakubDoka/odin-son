package control_flow

import "../../../bac"
import "../../../bac/ssa"
import "../../../utils/arna"
import "core:debug/trace"
import "core:mem/virtual"

@(align = 4096)
bufs: [4][4096 * 2]u8

main :: proc() {
	bac.init_custom_fmt()

	when ODIN_DEBUG {
		context.assertion_failure_proc = trace.assertion_failure_proc
	}

	temps := arna.Temps {
		arna.init_from_buffer(bufs[0][:]),
		arna.init_from_buffer(bufs[1][:]),
	}
	mem := arna.init_from_buffer(bufs[2][:])

	ref_code :: proc(n: int) -> int {
		n := n
		a := 0
		b := 1
		for {
			c := a + b
			a = b
			b = c
			if n == 0 do break
			n -= 1
		}

		return a
	}

	prc: bac.Proc

	context.logger.options = {.Terminal_Color}

	// This is for displaying nodes
	bac.current_prc = &prc
	defer bac.current_prc = nil

	rmem := ssa.start_proc(&prc, &mem, &temps)

	params: ssa.Param_Gen

	n_arg: bac.Node_ID
	// The arg gen utility can also emit struct locals and argument stores into
	// them, so we thread the memory here
	rmem, n_arg = ssa.arg_gen_next(
		&prc,
		rmem,
		&params,
		"n",
		{dt = {.I64}, scalar = true},
	)

	param_spec := ssa.arg_gen_finalize(&prc, &params)
	//defer delete(param_spec)

	zero := bac.add_c_int(&prc, "zr", .I64, 0)
	one := bac.add_c_int(&prc, "on", .I64, 1)

	scope := ssa.add_scope(&prc, "scope", prc.entry)
	// we dont push mem in this case since we have no memops, but it would be
	// part of the scope
	n := ssa.push_scope_value(&prc, scope, n_arg, "n", 0)
	a := ssa.push_scope_value(&prc, scope, zero, "a", 0)
	b := ssa.push_scope_value(&prc, scope, one, "b", 0)

	loop: ssa.Loop_State
	ssa.start_loop(&prc, scope, &loop); {
		ln := ssa.get_scope_value(&prc, scope, n)
		la := ssa.get_scope_value(&prc, scope, a)
		lb := ssa.get_scope_value(&prc, scope, b)

		c := bac.add_bin_op(&prc, "c", .Add, .I64, la, lb)

		ssa.set_scope_value(&prc, scope, b, la)
		ssa.set_scope_value(&prc, scope, a, c)

		cond := bac.add_bin_op(&prc, "cond", .Eq, .I8, ln, zero)
		if_: ssa.If_State
		ssa.start_if(&prc, scope, &if_, cond); {
			ssa.loop_control(.Break, &prc, scope, &loop)
			// important to clear the scope after terminating control flow
			scope = 0
		}; ssa.end_if(&prc, &scope, &if_)

		inc := bac.add_bin_op(&prc, "inc", .Sub, .I64, ln, one)
		ssa.set_scope_value(&prc, scope, n, inc)
	}; ssa.end_loop(&prc, &scope, &loop)

	ssa.merge_return(
		&prc,
		{
			bac.get_inputs(&prc, scope)[0],
			rmem,
			ssa.get_scope_value(&prc, scope, a),
		},
	)

	ssa.delete_scope(&prc, scope)

	code := arna.init_from_buffer(bufs[3][:])

	ctx: bac.Codegen_Emit_Ctx
	ctx.prc = &prc
	ctx.code = &code
	ctx.param_specs = param_spec

	out := ssa.compile(ctx)

	ok := virtual.protect(code.ptr, code.reserved, {.Read, .Execute})
	assert(ok)
	function := transmute(proc(_: int) -> int)code.ptr

	for i in 0 ..< 10 {
		res := function(i)
		assert(res == ref_code(i))
	}
}
