package main

// BUG 1b - NOTE ON THE ORIGINAL CLAIM:
//
// The task described bug 1b as "passing a struct BY VALUE into an inferred poly
// param `$T` fails". That does NOT reproduce on the current JIT: a clean
// `proc(v: $T)` (or `proc(v: $T) -> T`) called with a struct value compiles and
// runs correctly, including return-by-value, forwarding to another generic, and
// taking `&v` to byte-copy the struct. So the by-value case is FIXED / works.
//
// What DOES still fail in the same area (generic-parameter procedures) is the
// case captured below: when a generic procedure has a `rawptr` parameter and is
// called with a TYPED pointer argument (`^Point`), the frontend's
// poly-instantiation path does not coerce `^Point` to `rawptr` and aborts.
// This is a FRONTEND ASSERTION FAILURE (no object emitted):
//
//   typecheck.odin(1523:6) runtime assertion: ok
//     (the `assert(ok)` after `extract_polys(...)` in the poly-inference arg loop)
//
// Notes on the boundary:
//   - `f :: proc(dst: ^Point, v: $T)`   -> OK (typed pointer param)
//   - `f :: proc(dst: rawptr,  v: $T)`  called with `f(rawptr(&o), p)` -> OK
//   - `f :: proc(dst: rawptr,  v: $T)`  called with `f(&o, p)`        -> FAILS (below)
//   The failure is the implicit ^Point -> rawptr conversion being unavailable
//   inside a generic proc's argument-inference loop; it is unrelated to whether
//   the poly param is by value or by pointer.
//
// Expected (odin reference): compiles fine (odin coerces ^Point to rawptr).
//   main returns 0.
//
// Reproduce:
//   cd /home/mlokis/personal/odin/jit && export ODIN_ROOT="$HOME/odin"
//   odin build . -out:jit -debug
//   ./jit repros/bug1b_rawptr_in_generic/main.odin -o /tmp/x.o

Point :: struct {
	x: int,
	y: int,
}

store :: proc(dst: rawptr, v: $T) {
	_ = dst
	_ = v
}

main :: proc() -> int {
	out := Point{}
	p := Point{3, 4}
	store(&out, p)
	return 0
}
