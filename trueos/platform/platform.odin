package platform
import "core:io"
foreign _ { trueos_cabi_write :: proc "c" (stream: u32, data: rawptr, size: uintptr) --- }
stderr :: u32(2)
to_writer :: proc(stream: u32) -> io.Writer { return {writer, rawptr(uintptr(stream))} }
writer :: proc(data: rawptr, mode: io.Stream_Mode, p: []u8, offset: i64, whence: io.Seek_From) -> (i64, io.Error) {
    if mode != .Write do return 0, nil
    trueos_cabi_write(u32(uintptr(data)), raw_data(p), uintptr(len(p)))
    return i64(len(p)), nil
}

import "core:strings"

foreign _ {
    trueos_cabi_async_fs_read_start :: proc "c" (path: rawptr, len: uintptr) -> i32 ---
    trueos_cabi_async_fs_stat_start :: proc "c" (path: rawptr, len: uintptr) -> i32 ---
    trueos_cabi_async_fs_typed_list_dir_start :: proc "c" (path: rawptr, len: uintptr) -> i32 ---
    trueos_cabi_async_fs_write_begin :: proc "c" (path: rawptr, len, size: uintptr) -> i32 ---
    trueos_cabi_async_fs_write_chunk :: proc "c" (id: u32, offset: uintptr, data: rawptr, size: uintptr) -> i32 ---
    trueos_cabi_async_fs_write_commit :: proc "c" (id: u32) -> i32 ---
    trueos_cabi_async_fs_status :: proc "c" (id: u32) -> i32 ---
    trueos_cabi_async_fs_result_len :: proc "c" (id: u32) -> int ---
    trueos_cabi_async_fs_result_read :: proc "c" (id: u32, offset: uintptr, out: rawptr, cap: uintptr) -> int ---
    trueos_cabi_async_fs_discard :: proc "c" (id: u32) -> i32 ---
    trueos_cabi_poll_once :: proc "c" () ---
}

wait_ready :: proc(id: u32) -> Error {
    // Match trueos::async_fs::block_on: pending work yields the Hull lane.
    for {
        switch trueos_cabi_async_fs_status(id) {
        case 0: trueos_cabi_poll_once()
        case 1: return nil
        case: return .IO
        }
    }
}

take_result :: proc(start: i32, limit: int, allocator := context.allocator) -> ([]u8, Error) {
    if start <= 0 do return nil, .IO
    id := u32(start)
    defer trueos_cabi_async_fs_discard(id)
    if wait_ready(id) != nil do return nil, .IO
    size := trueos_cabi_async_fs_result_len(id)
    if size < 0 do return nil, .IO
    if size > limit do return nil, .Too_Large
    data := make([]u8, size, allocator)
    offset := 0
    for offset < size {
        cap := min(size-offset, 65536)
        got := trueos_cabi_async_fs_result_read(id, uintptr(offset), raw_data(data[offset:]), uintptr(cap))
        if got <= 0 || got > cap { delete(data, allocator); return nil, .IO }
        offset += got
    }
    return data, nil
}
Error :: enum { None, IO, Bad_Path, Too_Large }
File_Type :: enum { File, Directory }
Entry :: struct { type: File_Type, name, fullpath: string }
Info :: struct { kind: u32, size: u64 }

stat :: proc(path: string, allocator := context.allocator) -> (Info, Error) {
    data, err := take_result(trueos_cabi_async_fs_stat_start(raw_data(path), uintptr(len(path))), 12, allocator)
    if err != nil do return {}, err
    defer delete(data, allocator)
    if len(data) != 12 do return {}, .IO
    kind := u32(data[0]) | u32(data[1])<<8 | u32(data[2])<<16 | u32(data[3])<<24
    if kind != 1 && kind != 2 do return {}, .IO
    size: u64
    for i in 0..<8 { size |= u64(data[4+i]) << u64(i*8) }
    return {kind, size}, nil
}
open :: proc(path: string) -> (string, Error) {
    _, err := stat(path)
    return path, err
}
close :: proc(path: string) {}
abs :: proc(path: string, allocator := context.allocator) -> (string, Error) {
    parts: [dynamic]string
    defer delete(parts)
    cursor := path
    for part in strings.split_iterator(&cursor, "/") {
        if part == "" || part == "." do continue
        if part == ".." {
            if len(parts) == 0 do return "", .Bad_Path
            resize(&parts, len(parts)-1)
        } else { append(&parts, part) }
    }
    rooted := strings.has_prefix(path, "/")
    if len(parts) == 0 {
        if rooted do return "/", nil
        return ".", nil
    }
    result := strings.join(parts[:], "/", allocator)
    if rooted do result = strings.concatenate({"/", result}, allocator)
    return result, nil
}
join_path :: proc(parts: []string, allocator := context.allocator) -> (string, Error) {
    return abs(strings.join(parts, "/", context.temp_allocator), allocator)
}
join :: join_path
split_path :: proc(path: string) -> (string, string) {
    for i := len(path)-1; i >= 0; i -= 1 { if path[i] == '/' do return path[:i], path[i+1:] }
    return "", path
}
dir :: proc(path: string) -> string { d, _ := split_path(path); return d }
base :: proc(path: string) -> string { _, b := split_path(path); return b }
split_filename_all :: proc(path: string) -> (string, string) {
    for i, j in path { if i == '.' do return path[:j], path[j:] }
    return path, ""
}
read_entire_file :: proc(path: string, allocator := context.allocator) -> ([]u8, Error) {
    return take_result(trueos_cabi_async_fs_read_start(raw_data(path), uintptr(len(path))), 16*1024*1024, allocator)
}
read_dir :: proc(path: string, count: int, allocator := context.allocator) -> ([]Entry, Error) {
    bytes, err := take_result(trueos_cabi_async_fs_typed_list_dir_start(raw_data(path), uintptr(len(path))), 1024*1024, context.temp_allocator)
    if err != nil do return nil, err
    defer delete(bytes, context.temp_allocator)
    size := len(bytes)
    if size < 12 do return nil, .IO
    if string(bytes[:4]) != "TDL2" || bytes[4] != 0 do return nil, .IO
    n := u32(bytes[8]) | u32(bytes[9])<<8 | u32(bytes[10])<<16 | u32(bytes[11])<<24
    entries: [dynamic]Entry
    entries.allocator = allocator
    offset := 12
    for _ in 0..<n {
        if offset+8 > size do return nil, .IO
        kind := bytes[offset]
        name_size := int(bytes[offset+2]) | int(bytes[offset+3])<<8
        offset += 8
        if offset+name_size > size do return nil, .IO
        name := strings.clone(string(bytes[offset:offset+name_size]), allocator)
        fullpath, err := join_path({path, name}, allocator)
        if err != nil do return nil, err
        type := File_Type.File
        if kind == 2 do type = .Directory
        append(&entries, Entry{type, name, fullpath})
        offset += name_size
    }
    return entries[:], nil
}
write_entire_file :: proc(path: string, data: []u8) -> Error {
    start := trueos_cabi_async_fs_write_begin(raw_data(path), uintptr(len(path)), uintptr(len(data)))
    if start <= 0 do return .IO
    id := u32(start)
    defer trueos_cabi_async_fs_discard(id)
    offset := 0
    for offset < len(data) {
        end := min(offset+65536, len(data))
        if trueos_cabi_async_fs_write_chunk(id, uintptr(offset), raw_data(data[offset:end]), uintptr(end-offset)) != 0 do return .IO
        offset = end
    }
    if trueos_cabi_async_fs_write_commit(id) != 0 do return .IO
    return wait_ready(id)
}
