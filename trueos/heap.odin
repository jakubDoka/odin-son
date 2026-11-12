#+build freestanding
#+private
package runtime
foreign _ {
    sys_alloc_aligned :: proc "c" (size, align: uintptr) -> rawptr ---
    sys_dealloc :: proc "c" (ptr: rawptr) ---
}

// The SDK's heap_resize omits the old size; retain it locally so native
// allocation failure can leave the original allocation and its bytes intact.
_Trueos_Heap_Header :: struct #align(16) {
    size: int,
}

_heap_alloc :: proc "contextless" (size: int, zero_memory := true) -> rawptr {
    prefix :: size_of(_Trueos_Heap_Header)
    if size < 0 || size > max(int)-prefix do return nil
    base := sys_alloc_aligned(uintptr(max(size, 1)+prefix), align_of(_Trueos_Heap_Header))
    if base == nil do return nil
    (^_Trueos_Heap_Header)(base).size = size
    data := rawptr(uintptr(base)+prefix)
    if zero_memory do conditional_mem_zero(data, size)
    return data
}

_heap_resize :: proc "contextless" (ptr: rawptr, new_size: int) -> rawptr {
    if ptr == nil do return _heap_alloc(new_size, false)
    if new_size == 0 {
        _heap_free(ptr)
        return nil
    }
    next := _heap_alloc(new_size, false)
    if next == nil do return nil
    header := (^_Trueos_Heap_Header)(rawptr(uintptr(ptr)-size_of(_Trueos_Heap_Header)))
    mem_copy_non_overlapping(next, ptr, min(header.size, new_size))
    _heap_free(ptr)
    return next
}

_heap_free :: proc "contextless" (ptr: rawptr) {
    if ptr != nil do sys_dealloc(rawptr(uintptr(ptr)-size_of(_Trueos_Heap_Header)))
}
