package main

// BUG 1a - an explicit polymorphic parameter `$T: typeid` panics the JIT
// frontend. This is a FRONTEND PANIC (compile aborts, no object emitted).
//
// Expected (odin reference): compiles fine; `sized` returns the size the caller
// asks for via an explicit type argument.  main returns 8.
//
// Actual (JIT): the frontend panics while emitting the type of the explicit
// `$T: typeid` parameter (never reaches the body / codegen):
//
//   typecheck.odin(686:3) panic: TODO: &Typeid_Type{ ... tok = "Typeid" ... }
//   trace: typecheck.odin:686 <- 1766 <- 1787 <- 1719 <- 1848  (main.odin:94)
//
// The `^$T` (pointer-inferred) form of generics works; only the explicit
// `$T: typeid` parameter form panics.
//
// Reproduce:
//   cd /home/mlokis/personal/odin/jit && export ODIN_ROOT="$HOME/odin"
//   odin build . -out:jit -debug
//   ./jit repros/bug1a_explicit_poly/main.odin -o /tmp/x.o

sized :: proc($T: typeid) -> int {
	v: T
	return size_of(v)
}

main :: proc() -> int {
	return sized(i64)
}
