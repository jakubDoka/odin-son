#include <stdint.h>
#include <stddef.h>
#include <unistd.h>

__AFL_FUZZ_INIT();

extern void fuzz_one(const uint8_t *data, size_t len);

void afl_fuzz_run(void) {
#ifdef __AFL_HAVE_MANUAL_CONTROL
	__AFL_INIT();
#endif

	unsigned char *buf = __AFL_FUZZ_TESTCASE_BUF;
	while (__AFL_LOOP(10000)) {
		size_t len = __AFL_FUZZ_TESTCASE_LEN;
		fuzz_one(buf, len);
	}
}
