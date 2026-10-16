#+build freestanding
#+private
package mem_virtual
import "core:mem"
foreign _ {
    sys_alloc_aligned :: proc "c" (size, align: uintptr) -> rawptr ---
    trueos_cabi_free :: proc "c" (ptr: rawptr) ---
}
_reserve :: proc "contextless" (size: uint, address_hint: uintptr) -> ([]byte, Allocator_Error) {
    p := sys_alloc_aligned(uintptr(size), 4096)
    if p == nil do return nil, .Out_Of_Memory
    bytes := ([^]u8)(p)[:size]
    mem.zero_slice(bytes)
    return bytes, nil
}
_commit :: proc "contextless" (data: rawptr, size: uint) -> Allocator_Error { return nil }
_decommit :: proc "contextless" (data: rawptr, size: uint) {}
_release :: proc "contextless" (data: rawptr, size: uint) { trueos_cabi_free(data) }
_protect :: proc "contextless" (data: rawptr, size: uint, flags: Protect_Flags) -> bool { return false }
_map_file :: proc "contextless" (f: any, size: i64, flags: Map_File_Flags) -> ([]byte, Map_File_Error) { return nil, .Map_Failure }
_unmap_file :: proc "contextless" (data: []byte) {}
