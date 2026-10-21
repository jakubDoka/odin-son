#+build freestanding
package fmt
import "core:io"
foreign _ {
    trueos_cabi_write :: proc "c" (stream: u32, data: rawptr, size: uintptr) ---
}
trueos_sink: proc(stream: u32, text: string)
trueos_write :: proc(stream: u32, text: string) {
    if trueos_sink != nil do trueos_sink(stream, text)
    trueos_cabi_write(stream, raw_data(text), uintptr(len(text)))
}
@(private="file")
write_native :: proc(data: rawptr, mode: io.Stream_Mode, p: []u8, offset: i64, whence: io.Seek_From) -> (i64, io.Error) {
    if mode == .Write { trueos_write(u32(uintptr(data)), string(p)); return i64(len(p)), nil }
    if mode == .Flush do return 0, nil
    return 0, .Unknown
}
@(private="file")
writer :: proc(stream: u32) -> io.Writer { return {write_native, rawptr(uintptr(stream))} }
@(private="file")
write_formatted :: proc(stream: u32, text: string) -> int {
    // The host prefixes each write as a log record, so formatting must finish first.
    trueos_write(stream, text)
    size := len(text)
    delete(text)
    return size
}
print :: proc(args: ..any, sep := " ", flush := true) -> int { return write_formatted(1, aprint(..args, sep=sep)) }
println :: proc(args: ..any, sep := " ", flush := true) -> int { return write_formatted(1, aprintln(..args, sep=sep)) }
printf :: proc(format: string, args: ..any, flush := true) -> int { return write_formatted(1, aprintf(format, ..args)) }
printfln :: proc(format: string, args: ..any, flush := true) -> int { return write_formatted(1, aprintfln(format, ..args)) }
eprint :: proc(args: ..any, sep := " ", flush := true) -> int { return write_formatted(2, aprint(..args, sep=sep)) }
eprintln :: proc(args: ..any, sep := " ", flush := true) -> int { return write_formatted(2, aprintln(..args, sep=sep)) }
eprintf :: proc(format: string, args: ..any, flush := true) -> int { return write_formatted(2, aprintf(format, ..args)) }
eprintfln :: proc(format: string, args: ..any, flush := true) -> int { return write_formatted(2, aprintfln(format, ..args)) }
