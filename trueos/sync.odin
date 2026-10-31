package sync
import "core:time"
_current_thread_id :: proc "contextless" () -> int { return 1 }
_futex_wait :: proc "contextless" (f: ^Futex, expected: u32) -> bool {
    assert_contextless(u32(f^) != expected, "contended lock in single-threaded compiler")
    return true
}
_futex_wait_with_timeout :: proc "contextless" (f: ^Futex, expected: u32, duration: time.Duration) -> bool {
    return _futex_wait(f, expected)
}
_futex_signal :: proc "contextless" (f: ^Futex) {}
_futex_broadcast :: proc "contextless" (f: ^Futex) {}
