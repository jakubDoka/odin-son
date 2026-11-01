package tests

import "core:testing"

@(test)
comptime_config_overrides :: proc(t: ^testing.T) {
	configs := make(map[string]string, context.allocator)
	defer delete(configs)
	configs["TEST_COUNT"] = "(0x10 << 1)"
	configs["TEST_ENABLED"] = "!false"
	configs["TEST_DISABLED"] = "false"
	configs["TEST_TEXT"] = "\"a\\\"b\\\\c\\nλ\""
	configs["TEST_EMPTY"] = ""
	configs["TEST_ZERO"] = "0"
	configs["TEST_NEGATIVE"] = "-7"
	configs["TEST_UNSIGNED"] = "0xffff_ffff_ffff_ffff"
	configs["TEST_FLOAT"] = "1.5"
	configs["TEST_NARROW"] = "0xff"
	configs["TEST_SHARED"] = "123"
	configs["TEST_MINIMUM"] = "-0x8000_0000_0000_0000"
	configs["TEST_RAW_TEXT"] = "`raw\\text`"
	configs["TEST_UNUSED"] = "\"unterminated"

	source := `package main
COUNT :: #config(TEST_COUNT, 1)
TEXT :: #config(TEST_TEXT, "default")
FLOAT :: #config(TEST_FLOAT, 0.0)
NARROW :: #config(TEST_NARROW, u8(0))
NEGATIVE :: #config(TEST_NEGATIVE, 0)
#assert(COUNT == 0x20)
#assert(TEXT == "a\"b\\c\nλ")
#assert(#config(TEST_TEXT, "another default") == TEXT)
#assert(!#config(TEST_DISABLED, true))
#assert(#config(TEST_EMPTY, "fallback") == "")
#assert(#config(TEST_ZERO, 17) == 0)
#assert(#config(TEST_UNSIGNED, u64(0)) == 0xffff_ffff_ffff_ffff)
#assert(FLOAT == 1.5)
#assert(NARROW == 0xff)
#assert(NEGATIVE == -7)
#assert(#config(TEST_MISSING, 23) == 23)
#assert(#config(TEST_SHARED, 0) == 123)
#assert(#config(TEST_SHARED, 0.0) == 123.0)
#assert(#config(TEST_SHARED, "fallback") == "123")
#assert(#config(TEST_DISABLED, "fallback") == "false")
#assert(#config(TEST_FLOAT, "fallback") == "1.5")
#assert(#config(TEST_COUNT, "fallback") == "(0x10 << 1)")
#assert(#config(TEST_MINIMUM, 0) == -0x8000_0000_0000_0000)
#assert(#config(TEST_RAW_TEXT, "fallback") == "raw\\text")
when #config(TEST_ENABLED, false) {
	LENGTH :: COUNT + 1
} else {
	#panic("configuration override was ignored")
}
global: int = #config(TEST_COUNT, 0)
get_text :: proc() -> string { return TEXT }
main :: proc() -> int {
	a: [LENGTH]int
	s := get_text()
	f := FLOAT
	return len(a) + global + len(s) + int(f) + int(NARROW) + NEGATIVE
}`
	run_test(
		t,
		"comptime_config_overrides",
		source,
		33 + 32 + len("a\"b\\c\nλ") + 1 + 0xff - 7,
		diff = false,
		configs = configs,
	)
	run_test(
		t,
		"comptime_config_defaults",
		`package main
main :: proc() -> int { return #config(TEST_COUNT, 17) }`,
		17,
		diff = false,
	)
}
