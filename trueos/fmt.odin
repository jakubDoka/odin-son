#+build freestanding
package fmt
import "core:io"
foreign _ {
    trueos_cabi_write :: proc "c" (stream: u32, data: rawptr, size: uintptr) ---
}
@(private="file")
write_native :: proc(data: rawptr, mode: io.Stream_Mode, p: []u8, offset: i64, whence: io.Seek_From) -> (i64, io.Error) {
    if mode == .Write { trueos_cabi_write(u32(uintptr(data)), raw_data(p), uintptr(len(p))); return i64(len(p)), nil }
    if mode == .Flush do return 0, nil
    return 0, .Unknown
}
@(private="file")
writer :: proc(stream: u32) -> io.Writer { return {write_native, rawptr(uintptr(stream))} }
print :: proc(args: ..any, sep := " ", flush := true) -> int { return wprint(writer(1), ..args, sep=sep, flush=flush) }
println :: proc(args: ..any, sep := " ", flush := true) -> int { return wprintln(writer(1), ..args, sep=sep, flush=flush) }
printf :: proc(format: string, args: ..any, flush := true) -> int { return wprintf(writer(1), format, ..args, flush=flush) }
printfln :: proc(format: string, args: ..any, flush := true) -> int { return wprintfln(writer(1), format, ..args, flush=flush) }
eprint :: proc(args: ..any, sep := " ", flush := true) -> int { return wprint(writer(2), ..args, sep=sep, flush=flush) }
eprintln :: proc(args: ..any, sep := " ", flush := true) -> int { return wprintln(writer(2), ..args, sep=sep, flush=flush) }
eprintf :: proc(format: string, args: ..any, flush := true) -> int { return wprintf(writer(2), format, ..args, flush=flush) }
eprintfln :: proc(format: string, args: ..any, flush := true) -> int { return wprintfln(writer(2), format, ..args, flush=flush) }
