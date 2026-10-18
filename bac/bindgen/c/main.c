#include "bac.h"

int main() {
	char buf[4096];

	arna_Allocator mem = arna_init_from_buffer(bac_slice_array(bac_u8, buf));

	bac_Proc proc = {0};

	bac_ssa_start_proc(&proc, &mem);

	return 0;
}
