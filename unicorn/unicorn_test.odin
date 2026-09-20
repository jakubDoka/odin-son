package unicorn

import "core:testing"

@(test)
run_arm64_arguments :: proc(t: ^testing.T) {
	code := []u8{0x00, 0x00, 0x01, 0x8b, 0xc0, 0x03, 0x5f, 0xd6}
	result, err := run_arm64(code, []u64{20, 22})

	testing.expect_value(t, err, Error.OK)
	testing.expect_value(t, result, u64(42))
}

@(test)
run_arm64_position_independent_data :: proc(t: ^testing.T) {
	code := []u8 {
		0x40,
		0x00,
		0x00,
		0x58,
		0xc0,
		0x03,
		0x5f,
		0xd6,
		0x2a,
		0x00,
		0x00,
		0x00,
		0x00,
		0x00,
		0x00,
		0x00,
	}
	result, err := run_arm64(code)

	testing.expect_value(t, err, Error.OK)
	testing.expect_value(t, result, u64(42))
}

@(test)
run_arm64_replaces_cached_code :: proc(t: ^testing.T) {
	return_one := []u8{0x20, 0x00, 0x80, 0xd2, 0xc0, 0x03, 0x5f, 0xd6}
	return_two := []u8{0x40, 0x00, 0x80, 0xd2, 0xc0, 0x03, 0x5f, 0xd6}

	result, err := run_arm64(return_one)
	testing.expect_value(t, err, Error.OK)
	testing.expect_value(t, result, u64(1))

	result, err = run_arm64(return_two)
	testing.expect_value(t, err, Error.OK)
	testing.expect_value(t, result, u64(2))
}

@(test)
run_arm64_instruction_limit :: proc(t: ^testing.T) {
	branch_to_self := []u8{0x00, 0x00, 0x00, 0x14}
	_, err := run_arm64(branch_to_self, instruction_limit = 10)

	testing.expect_value(t, err, Error.Instruction_Limit)
}
