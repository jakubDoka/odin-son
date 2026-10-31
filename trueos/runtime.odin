#+build freestanding
#+private
package runtime
foreign _ {
    trueos_cabi_write :: proc "c" (stream: u32, bytes: rawptr, size: uintptr) ---
}
_HAS_RAND_BYTES :: false
_stderr_write :: proc "contextless" (data: []byte) -> (int, _OS_Errno) {
    trueos_cabi_write(2, raw_data(data), uintptr(len(data)))
    return len(data), 0
}
_exit :: proc "contextless" (code: int) -> ! { trap() }
