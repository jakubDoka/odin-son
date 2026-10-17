#include "bac.h"

int main() {
	char buf[4096];

	arna_Allocator mem = {0};
	mem.ptr = buf;
	mem.reserved = sizeof(buf);
	mem.commited = sizeof(buf) + 1;

	bac_Proc proc = {0};

	bac_builder_start_proc(&proc, &mem);

	return 0;
}
