#include "bac.h"

#define EACH(i, from, to) (int i = (from); i < (to); i++)
#define make_arna(buf) arna_init_from_buffer(bac_slice_array(bac_u8, (buf)))

#define SYS_mprotect 10
#define PROT_READ    1
#define PROT_WRITE   2
#define PROT_EXEC    4

static inline long raw_mprotect(void *addr, unsigned long len, int prot) {
	long result;
	__asm__ volatile (
		"syscall"
		: "=a"(result)
		: "a"((long)SYS_mprotect),
		  "D"(addr),
		  "S"(len),
		  "d"((long)prot)
		: "rcx", "r11", "memory"
	);
	return result;
}

bac_u8 local_buf[2][4096 * 128];
bac_u8 proc_mem[4096 * 8];
_Alignas(4096) bac_u8 code_mem[4096];

int main() {
	arna_Temps temps;
	for EACH(i, 0, 2) {
		temps[i] = make_arna(local_buf[i]);
	}
	
	bac_Proc proc = {0};
	
	arna_Allocator mem = make_arna(proc_mem);
	bac_Node_ID rmem = bac_start_proc(&proc, &mem, &temps);
	
	bac_Node_ID value = bac_add_c_int(&proc, bac_str("mcnst"), bac_Node_Datatype_I64, 69);
	
	bac_Node_ID rets[] = {proc.meta.pinned.entry, rmem, value};
	bac_merge_return(&proc, bac_slice_array(bac_Node_ID, rets));
	
	arna_Allocator code = make_arna(code_mem);
	
	bac_Codegen_Emit_Ctx ctx = {0};
	ctx.prc = &proc;
	ctx.buf.code = &code;
	
	bac_compile(ctx);
	
	if (raw_mprotect(code_mem, sizeof(code_mem), PROT_READ | PROT_EXEC) < 0) {
		return 1;
	}
	
	bac_i64 (*jit_fn)(void) = (bac_i64 (*)(void))code_mem;
	bac_i64 result = jit_fn();
	
	return (int)result;
}
