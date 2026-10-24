package constant

import "../../../bac"
import "../../../bac/ssa"
import "../../../utils/arna"
import "core:mem/virtual"
import "core:os"

@(align = 4096)
bufs: [4][4096]u8

main :: proc() {
	// Init arenas, this is all of the memory the ir builder will ever use
	temps := arna.Temps {
		arna.init_from_buffer(bufs[0][:]),
		arna.init_from_buffer(bufs[1][:]),
	}
	mem := arna.init_from_buffer(bufs[2][:])

	prc: bac.Proc
	rmem := ssa.start_proc(&prc, &mem, &temps)

	cnst := bac.add_c_int(&prc, "cnst", .I64, 69)

	ssa.merge_return(&prc, {prc.entry, rmem, cnst})

	code := arna.init_from_buffer(bufs[3][:])

	ctx: bac.Codegen_Emit_Ctx
	ctx.prc = &prc
	ctx.code = &code

	out := ssa.compile(ctx)

	ok := virtual.protect(code.ptr, code.reserved, {.Read, .Execute})
	assert(ok)
	function := transmute(proc() -> int)code.ptr

	os.exit(function())
}
