package unicorn

import "../vendored/gam/util/arna"
import "base:runtime"
import "core:log"
import "core:testing"

Trace_Log :: struct {
	bytes: [256]u8,
	len:   int,
}

trace_test_logger :: proc(
	data: rawptr,
	_: log.Level,
	text: string,
	_: log.Options,
	_: runtime.Source_Code_Location = #caller_location,
) {
	trace := cast(^Trace_Log)data
	if trace.len != 0 {
		trace.bytes[trace.len] = '\n'
		trace.len += 1
	}
	copy(trace.bytes[trace.len:], transmute([]u8)text)
	trace.len += len(text)
}

@(test)
run_arm64_arguments :: proc(t: ^testing.T) {
	code: [PAGE_SIZE]u8
	copy(code[:], []u8{0x00, 0x00, 0x01, 0x8b, 0xc0, 0x03, 0x5f, 0xd6})
	result, err := run_arm64(code[:], int(PAGE_SIZE), 0, []u64{20, 22})

	testing.expect_value(t, err, Error.OK)
	testing.expect_value(t, result, u64(42))
}

@(test)
run_arm64_position_independent_data :: proc(t: ^testing.T) {
	code: [PAGE_SIZE]u8
	copy(
		code[:],
		[]u8 {
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
		},
	)
	result, err := run_arm64(code[:], int(PAGE_SIZE), 0)

	testing.expect_value(t, err, Error.OK)
	testing.expect_value(t, result, u64(42))
}

@(test)
run_arm64_replaces_cached_code :: proc(t: ^testing.T) {
	return_one: [PAGE_SIZE]u8
	return_two: [PAGE_SIZE]u8
	copy(return_one[:], []u8{0x20, 0x00, 0x80, 0xd2, 0xc0, 0x03, 0x5f, 0xd6})
	copy(return_two[:], []u8{0x40, 0x00, 0x80, 0xd2, 0xc0, 0x03, 0x5f, 0xd6})

	result, err := run_arm64(return_one[:], int(PAGE_SIZE), 0)
	testing.expect_value(t, err, Error.OK)
	testing.expect_value(t, result, u64(1))

	result, err = run_arm64(return_two[:], int(PAGE_SIZE), 0)
	testing.expect_value(t, err, Error.OK)
	testing.expect_value(t, result, u64(2))
}

@(test)
run_arm64_instruction_limit :: proc(t: ^testing.T) {
	branch_to_self: [PAGE_SIZE]u8
	copy(branch_to_self[:], []u8{0x00, 0x00, 0x00, 0x14})
	_, err := run_arm64(
		branch_to_self[:],
		int(PAGE_SIZE),
		0,
		instruction_limit = 10,
	)

	testing.expect_value(t, err, Error.Instruction_Limit)
}

@(test)
run_arm64_start_and_mutable_data :: proc(t: ^testing.T) {
	code: [PAGE_SIZE * 2]u8
	start := 16
	copy(
		code[start:],
		[]u8 {
			0x01,
			0x80,
			0x00,
			0x10,
			0x40,
			0x05,
			0x80,
			0xd2,
			0x20,
			0x00,
			0x00,
			0xf9,
			0x20,
			0x00,
			0x40,
			0xf9,
			0xc0,
			0x03,
			0x5f,
			0xd6,
		},
	)

	result, err := run_arm64(code[:], int(PAGE_SIZE), start)

	testing.expect_value(t, err, Error.OK)
	testing.expect_value(t, result, u64(42))
}

@(test)
run_arm64_trace_instrs :: proc(t: ^testing.T) {
	arna.init_scratch(1024 * 1024)
	defer arna.deinit_scratch()

	trace: Trace_Log
	context.logger = log.Logger {
		procedure    = trace_test_logger,
		data         = &trace,
		lowest_level = .Debug,
	}
	code: [PAGE_SIZE]u8
	copy(code[:], []u8{0x00, 0x00, 0x01, 0x8b, 0xc0, 0x03, 0x5f, 0xd6})
	result, err := run_arm64(
		code[:],
		int(PAGE_SIZE),
		0,
		[]u64{20, 22},
		trace_instrs = true,
	)

	testing.expect_value(t, err, Error.OK)
	testing.expect_value(t, result, u64(42))
	testing.expect_value(
		t,
		string(trace.bytes[:trace.len]),
		"0x0000000000100000: add x0, x0, x1\n" + "0x0000000000100004: ret",
	)
}
