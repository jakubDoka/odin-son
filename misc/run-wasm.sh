#!/usr/bin/env bash
# Scoped parity check for the wasm test program only (mirrors run-programs.sh).
# Builds the jit, generates embedded blobs, builds the reference-odin binary and
# the jit binary at every opt level, and diffs stdout/stderr/exit code.
set -u
export ODIN_ROOT="$HOME/odin"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIR="$ROOT/test-programs/wasm"
JIT="$ROOT/jit"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
LEVELS=(none mininal moderate all aggresive)

echo "building jit..."
(cd "$ROOT" && odin build . -out:jit -debug) || { echo "jit build FAILED"; exit 1; }

if [[ -f "$DIR/generate.sh" ]]; then
	echo "generating..."
	bash "$DIR/generate.sh" >"$WORK/gen.log" 2>&1 || { echo "generate FAILED"; cat "$WORK/gen.log"; exit 1; }
fi

src="$WORK/odin-src"; cp -r "$DIR" "$src"
sed -i 's/^main :: proc() -> int {/_main :: proc() -> int {/' "$src/main.odin"
sed -i '0,/^package main$/s//package main\nimport __os "core:os"/' "$src/main.odin"
printf '\nmain :: proc() { __os.exit(_main()) }\n' >>"$src/main.odin"
if ! odin build "$src" -out:"$WORK/odin-bin" 2>"$WORK/ob.log"; then
	echo "odin reference build FAILED"; cat "$WORK/ob.log"; exit 1
fi
"$WORK/odin-bin" >"$WORK/odin.out" 2>"$WORK/odin.err"; ocode=$?

fail=0
for lvl in "${LEVELS[@]}"; do
	if ! "$JIT" "$DIR/" -O:"$lvl" -o "$WORK/j.o" 2>"$WORK/jc.log"; then
		echo "[$lvl] jit compile FAILED"; cat "$WORK/jc.log"; fail=1; continue
	fi
	zig cc "$WORK/j.o" -o "$WORK/j.bin" 2>"$WORK/jl.log" || { echo "[$lvl] link FAILED"; cat "$WORK/jl.log"; fail=1; continue; }
	"$WORK/j.bin" >"$WORK/j.out" 2>"$WORK/j.err"; jcode=$?
	ok=1
	[[ "$ocode" == "$jcode" ]] || { echo "[$lvl] exit mismatch odin=$ocode jit=$jcode"; ok=0; }
	diff -q "$WORK/odin.out" "$WORK/j.out" >/dev/null || { echo "[$lvl] stdout mismatch:"; diff "$WORK/odin.out" "$WORK/j.out" | head -30 | sed 's/^/    /'; ok=0; }
	diff -q "$WORK/odin.err" "$WORK/j.err" >/dev/null || { echo "[$lvl] stderr mismatch"; ok=0; }
	if [[ "$ok" == 1 ]]; then echo "[$lvl] OK (exit=$jcode)"; else fail=1; fi
done
exit $fail
