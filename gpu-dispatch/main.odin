#+build linux, amd64
package gpu_dispatch

import "core:fmt"
import "core:mem"
import "core:os"
import "core:strconv"
import "gpu"

usage :: proc() {
	fmt.println("Usage: gpu-dispatch [a b [render-node]]")
	fmt.println(
		"Defaults: 37 5 /dev/dri/renderD128; unsigned 32-bit addition, modulo 2^32.",
	)
	fmt.println("Each lane i computes (a + i) + b, modulo 2^32.")
	fmt.println(
		"Requires this machine's Intel 8086:46a6 GPU with the Linux i915 driver.",
	)
}

execute_add :: proc(a, b: u32, device_path: string) -> bool {
	device, err := gpu.open(device_path)
	if err != nil {
		fmt.eprintf("Cannot open GPU: %v\n", err)
		return false
	}
	defer gpu.close(&device)
	code := ADD_CODE
	kernel := gpu.Kernel {
		code            = mem.slice_data_cast([]u32, code[:]),
		parameter_count = 2,
		result_count    = 1,
	}
	parameters: [2][8]u32
	for lane in 0..<8 {
		parameters[0][lane] = a + u32(lane)
		parameters[1][lane] = b
	}
	result: [1][8]u32
	err = gpu.execute(&device, kernel, parameters[:], result[:])
	if err != nil {
		fmt.eprintf("GPU execution failed: %v\n", err)
		return false
	}
	for actual, lane in result[0] {
		expected := u32((u64(parameters[0][lane]) + u64(parameters[1][lane])) & 0xffffffff)
		if actual != expected {
			fmt.eprintf(
				"GPU verification failed in lane %d: got %d, expected %d.\n",
				lane,
				actual,
				expected,
			)
			return false
		}
	}
	fmt.printf(
		"%v + %v = %v (GPU: Intel 8086:46a6, i915, %s)\n",
		parameters[0],
		parameters[1],
		result[0],
		device_path,
	)
	return true
}

main :: proc() {
	args := os.args[1:]
	if len(args) == 1 && (args[0] == "--help" || args[0] == "-h") {
		usage()
		return
	}
	if len(args) != 0 && len(args) != 2 && len(args) != 3 {
		usage()
		os.exit(1)
	}
	a, b := u32(37), u32(5)
	device_path := "/dev/dri/renderD128"
	if len(args) >= 2 {
		left, left_ok := strconv.parse_u64(args[0])
		right, right_ok := strconv.parse_u64(args[1])
		if !left_ok || !right_ok || left > 0xffffffff || right > 0xffffffff {
			fmt.eprintln(
				"Both operands must be unsigned 32-bit integers (decimal or 0x-prefixed hex).",
			)
			os.exit(1)
		}
		a, b = u32(left), u32(right)
	}
	if len(args) == 3 do device_path = args[2]
	if !execute_add(a, b, device_path) do os.exit(1)
}
