#+build freestanding
#+private
package runtime
foreign _ {
    trueos_cabi_alloc :: proc "c" (size: uintptr) -> rawptr ---
    trueos_cabi_calloc :: proc "c" (count, size: uintptr) -> rawptr ---
    trueos_cabi_realloc :: proc "c" (ptr: rawptr, size: uintptr) -> rawptr ---
    trueos_cabi_free :: proc "c" (ptr: rawptr) ---
}
_heap_alloc :: proc "contextless" (size: int, zero_memory := true) -> rawptr {
    if zero_memory do return trueos_cabi_calloc(1, uintptr(size))
    return trueos_cabi_alloc(uintptr(size))
}
_heap_resize :: proc "contextless" (ptr: rawptr, new_size: int) -> rawptr {
    return trueos_cabi_realloc(ptr, uintptr(new_size))
}
_heap_free :: proc "contextless" (ptr: rawptr) { trueos_cabi_free(ptr) }
