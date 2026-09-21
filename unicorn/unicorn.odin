package unicorn

import "base:runtime"
import "core:c"

@(private)
UNICORN_LIBRARY :: "../vendored/unicorn-engine/build/libunicorn.a"

when !#exists(UNICORN_LIBRARY) {
	#panic("Unicorn is not built; run `build-unicorn` from misc/profiles.fish")
}

when ODIN_OS == .Linux {
	foreign import uc {UNICORN_LIBRARY, "system:atomic"}
} else {
	foreign import uc {UNICORN_LIBRARY}
}

Error :: enum i32 {
	OK,
	No_Memory,
	Unsupported_Architecture,
	Invalid_Handle,
	Invalid_Mode,
	Version,
	Read_Unmapped,
	Write_Unmapped,
	Fetch_Unmapped,
	Hook,
	Invalid_Instruction,
	Map,
	Write_Protected,
	Read_Protected,
	Fetch_Protected,
	Invalid_Argument,
	Read_Unaligned,
	Write_Unaligned,
	Fetch_Unaligned,
	Hook_Exists,
	Resource,
	Exception,
	Overflow,
	Invalid_Code = 100,
	Too_Many_Arguments,
	Code_Too_Large,
	Instruction_Limit,
}

DEFAULT_INSTRUCTION_LIMIT :: 1_000_000

Engine :: struct {}

Context :: struct {}

VM_State :: struct {
	engine:      ^Engine,
	initial:     ^Context,
	mapped_size: u64,
	data_start:  u64,
}

@(thread_local)
thread_vm: VM_State

@(init)
init_thread_vm_cleaner :: proc "contextless" () {
	runtime.add_thread_local_cleaner(close_thread_vm)
}

close_thread_vm :: proc "contextless" () {
	if thread_vm.initial != nil {
		uc_context_free(thread_vm.initial)
	}
	if thread_vm.engine != nil {
		uc_close(thread_vm.engine)
	}
	thread_vm = {}
}

Architecture :: enum i32 {
	ARM = 1,
	ARM64,
}

Protection :: enum u32 {
	None,
	Read,
	Write,
	Execute = 4,
}

foreign uc {
	uc_open :: proc "c" (architecture: Architecture, mode: i32, engine: ^^Engine) -> Error ---
	uc_close :: proc "c" (engine: ^Engine) -> Error ---
	uc_strerror :: proc "c" (err: Error) -> cstring ---
	uc_reg_write :: proc "c" (engine: ^Engine, register: c.int, value: rawptr) -> Error ---
	uc_reg_read :: proc "c" (engine: ^Engine, register: c.int, value: rawptr) -> Error ---
	uc_mem_write :: proc "c" (engine: ^Engine, address: u64, bytes: rawptr, size: u64) -> Error ---
	uc_mem_map :: proc "c" (engine: ^Engine, address, size: u64, permissions: u32) -> Error ---
	uc_mem_unmap :: proc "c" (engine: ^Engine, address, size: u64) -> Error ---
	uc_emu_start :: proc "c" (engine: ^Engine, begin, until, timeout: u64, count: uintptr) -> Error ---
	uc_context_alloc :: proc "c" (engine: ^Engine, state: ^^Context) -> Error ---
	uc_context_save :: proc "c" (engine: ^Engine, state: ^Context) -> Error ---
	uc_context_restore :: proc "c" (engine: ^Engine, state: ^Context) -> Error ---
	uc_context_free :: proc "c" (state: ^Context) -> Error ---
	uc_ctl :: proc "c" (engine: ^Engine, control: u32, #c_vararg args: ..any) -> Error ---
}

PAGE_SIZE :: u64(4096)
CODE_ADDRESS :: u64(0x10_0000)
STACK_ADDRESS :: u64(0x4000_0000)
STACK_SIZE :: u64(1024 * 1024)

ARM64_SP :: c.int(4)
ARM64_LR :: c.int(2)
ARM64_X0 :: c.int(199)
ARM64_PC :: c.int(260)
REMOVE_CODE_CACHE :: u32(9 | (2 << 26) | (1 << 30))

acquire_thread_vm :: proc(
	mapped_size, data_start: u64,
) -> (
	engine: ^Engine,
	err: Error,
) {
	if thread_vm.engine == nil {
		if err = uc_open(.ARM64, 0, &engine); err != .OK {
			return
		}
		if err = uc_mem_map(
			engine,
			STACK_ADDRESS,
			STACK_SIZE,
			u32(Protection.Read) | u32(Protection.Write),
		); err != .OK {
			uc_close(engine)
			return nil, err
		}

		initial: ^Context
		if err = uc_context_alloc(engine, &initial); err != .OK {
			uc_close(engine)
			return nil, err
		}
		if err = uc_context_save(engine, initial); err != .OK {
			uc_context_free(initial)
			uc_close(engine)
			return nil, err
		}
		thread_vm.engine = engine
		thread_vm.initial = initial
	}

	engine = thread_vm.engine
	if mapped_size > thread_vm.mapped_size ||
	   data_start != thread_vm.data_start {
		if thread_vm.mapped_size != 0 {
			if err = uc_mem_unmap(engine, CODE_ADDRESS, thread_vm.mapped_size);
			   err != .OK {
				return
			}
			thread_vm.mapped_size = 0
			thread_vm.data_start = 0
		}
		if err = uc_mem_map(
			engine,
			CODE_ADDRESS,
			data_start,
			u32(Protection.Read) | u32(Protection.Execute),
		); err != .OK {
			return
		}
		if data_start < mapped_size {
			if err = uc_mem_map(
				engine,
				CODE_ADDRESS + data_start,
				mapped_size - data_start,
				u32(Protection.Read) | u32(Protection.Write),
			); err != .OK {
				uc_mem_unmap(engine, CODE_ADDRESS, data_start)
				return
			}
		}
		thread_vm.mapped_size = mapped_size
		thread_vm.data_start = data_start
	}
	return engine, .OK
}

run_arm64 :: proc(
	code: []u8,
	data_start: int,
	start: int,
	arguments: []u64 = nil,
	instruction_limit: uint = DEFAULT_INSTRUCTION_LIMIT,
) -> (
	result: u64,
	err: Error,
) {
	if len(code) == 0 ||
	   data_start <= 0 ||
	   data_start > len(code) ||
	   data_start % int(PAGE_SIZE) != 0 ||
	   start < 0 ||
	   start >= data_start ||
	   start % 4 != 0 ||
	   instruction_limit == 0 {
		return 0, .Invalid_Code
	}
	if len(arguments) > 8 {
		return 0, .Too_Many_Arguments
	}

	mapped_size := (u64(len(code)) + PAGE_SIZE - 1) & ~(PAGE_SIZE - 1)
	if mapped_size > STACK_ADDRESS - CODE_ADDRESS {
		return 0, .Code_Too_Large
	}

	engine: ^Engine
	if engine, err = acquire_thread_vm(mapped_size, u64(data_start));
	   err != .OK {
		return
	}
	if err = uc_context_restore(engine, thread_vm.initial); err != .OK {
		return
	}
	if err = uc_mem_write(
		engine,
		CODE_ADDRESS,
		raw_data(code),
		u64(len(code)),
	); err != .OK {
		return
	}
	if err = uc_ctl(
		engine,
		REMOVE_CODE_CACHE,
		CODE_ADDRESS,
		CODE_ADDRESS + u64(len(code)) - 1,
	); err != .OK {
		return
	}

	stack_pointer := STACK_ADDRESS + STACK_SIZE
	return_address := CODE_ADDRESS + u64(data_start)
	if err = uc_reg_write(engine, ARM64_SP, &stack_pointer); err != .OK {
		return
	}
	if err = uc_reg_write(engine, ARM64_LR, &return_address); err != .OK {
		return
	}
	for &argument, index in arguments {
		if err = uc_reg_write(engine, ARM64_X0 + c.int(index), &argument);
		   err != .OK {
			return
		}
	}

	if err = uc_emu_start(
		engine,
		CODE_ADDRESS + u64(start),
		return_address,
		0,
		uintptr(instruction_limit),
	); err != .OK {
		return
	}

	program_counter: u64
	if err = uc_reg_read(engine, ARM64_PC, &program_counter); err != .OK {
		return
	}
	if program_counter != return_address {
		return 0, .Instruction_Limit
	}
	if err = uc_reg_read(engine, ARM64_X0, &result); err != .OK {
		return
	}
	return result, .OK
}

error_string :: proc(err: Error) -> cstring {
	#partial switch err {
	case .Invalid_Code:
		return "ARM64 code layout or entry offset is invalid"
	case .Too_Many_Arguments:
		return "ARM64 calls support at most eight register arguments"
	case .Code_Too_Large:
		return "ARM64 code buffer is too large"
	case .Instruction_Limit:
		return "ARM64 code exceeded the instruction limit"
	case:
		return uc_strerror(err)
	}
}
