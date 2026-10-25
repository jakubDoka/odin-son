#+build linux, amd64
package gpu

import "core:mem"
import "core:strings"
import "core:sys/posix"

Disassembler_Error :: struct {
	operation: string,
	status:    u32,
}

@(private)
IGA_Context_Options :: struct {
	size:     uint,
	platform: u32,
}

@(private)
IGA_Disassemble_Options :: struct {
	size, formatting, reserved0, reserved1, decoder, base_pc: u32,
}

#assert(size_of(IGA_Context_Options) == 16)
#assert(size_of(IGA_Disassemble_Options) == 24)

disassemble :: proc(
	code: []u8,
	allocator: mem.Allocator = context.allocator,
	library_path := "",
) -> (
	assembly: string,
	error: Error,
) {
	if len(code) == 0 do return "", nil
	if len(code) % 8 != 0 || len(code) > MAX_KERNEL_BYTES {
		return "", Error_Code.Invalid_Kernel
	}
	// IGA may decode a full instruction even when input_size ends halfway through it.
	for offset := 0; offset < len(code); {
		instruction_bytes := 16
		if code[offset + 3] & (1 << 5) != 0 do instruction_bytes = 8
		if len(code) - offset < instruction_bytes do return "", Error_Code.Invalid_Kernel
		offset += instruction_bytes
	}
	library: posix.Symbol_Table
	if library_path == "" {
		for name in ([?]cstring{"libiga64.so.2", "libiga64.so.1", "libiga64.so"}) {
			library = posix.dlopen(name, {.NOW})
			if library != nil do break
		}
	} else {
		path: [4096]u8
		if len(library_path) >= len(path) do return "", Error_Code.Invalid_Path
		for c in library_path {
			if c == 0 do return "", Error_Code.Invalid_Path
		}
		copy(path[:], library_path)
		library = posix.dlopen(cstring(&path[0]), {.NOW})
	}
	if library == nil do return "", Error_Code.Disassembler_Unavailable
	defer posix.dlclose(library)

	create := (proc "c" (^IGA_Context_Options, ^rawptr) -> u32)(
		posix.dlsym(library, "iga_context_create"),
	)
	release := (proc "c" (rawptr) -> u32)(
		posix.dlsym(library, "iga_context_release"),
	)
	decode := (proc "c" (
		rawptr,
		^IGA_Disassemble_Options,
		rawptr,
		u32,
		rawptr,
		rawptr,
		^cstring,
	) -> u32)(posix.dlsym(library, "iga_context_disassemble"))
	if create == nil || release == nil || decode == nil {
		return "", Error_Code.Invalid_Disassembler
	}

	options := IGA_Context_Options {
		size = size_of(IGA_Context_Options),
		// The legacy Xe-LP platform ID also works with older IGA libraries.
		platform = 12 << 16 | 1,
	}
	ctx: rawptr
	status := create(&options, &ctx)
	if status != 0 do return "", Disassembler_Error{"iga_context_create", status}
	defer release(ctx)
	decode_options := IGA_Disassemble_Options {
		size = size_of(IGA_Disassemble_Options),
	}
	text: cstring
	status = decode(ctx, &decode_options, raw_data(code), u32(len(code)), nil, nil, &text)
	if status != 0 do return "", Disassembler_Error{"iga_context_disassemble", status}
	assembly = strings.clone(string(text), allocator) or_return
	return assembly, nil
}
