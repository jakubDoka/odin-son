#!/usr/bin/env bash
#
# Compile every program under test-programs/ with both the reference Odin
# compiler and our JIT compiler, run the resulting binaries and compare their
# exit codes and stdout/stderr.
#
# A "program" is any directory directly under test-programs/ that contains a
# `main.odin` file defining `main :: proc() -> int` (the same entry convention
# the unit tests use). Because the real Odin compiler insists on
# `main :: proc()`, we transform a throw-away copy of the entry file into an
# `os.exit(_main())` wrapper before building the reference binary.

set -u

export ODIN_ROOT="$HOME/odin"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROGRAMS_DIR="$ROOT/test-programs"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

JIT="$ROOT/jit"

# Build the compiler unless one was already provided.
echo "building jit compiler..."
(cd "$ROOT" && odin build . -out:jit -debug) || {
	echo "failed to build jit compiler"
	exit 1
}

pass=0
fail=0
failed_names=()

run_capture() {
	# $1 = binary, writes exit code to REPLY_CODE, stdout/stderr to files
	local bin="$1" out="$2" err="$3"
	"$bin" >"$out" 2>"$err"
	REPLY_CODE=$?
}

for dir in "$PROGRAMS_DIR"/*/; do
	name="$(basename "$dir")"
	entry="$dir/main.odin"
	if [[ ! -f "$entry" ]]; then
		continue
	fi
	#if [ "$name" != "lua" ]; then
	#	continue
	#fi

	echo "=== $name ==="

	# --- reference build with odin -------------------------------------
	odin_src="$WORK/$name-odin"
	rm -rf "$odin_src"
	cp -r "$dir" "$odin_src"

	# Rename `main :: proc() -> int` to `_main` and inject an os.exit wrapper.
	sed -i 's/^main :: proc() -> int {/_main :: proc() -> int {/' \
		"$odin_src/main.odin"
	sed -i '0,/^package main$/s//package main\nimport __os "core:os"/' \
		"$odin_src/main.odin"
	printf '\nmain :: proc() { __os.exit(_main()) }\n' >>"$odin_src/main.odin"

	odin_bin="$WORK/$name-odin-bin"
	if ! odin build "$odin_src" -out:"$odin_bin" 2>"$WORK/odin-build.log"; then
		echo "  odin build FAILED"
		cat "$WORK/odin-build.log" | sed 's/^/    /'
		fail=$((fail + 1))
		failed_names+=("$name (odin build)")
		continue
	fi

	run_capture "$odin_bin" "$WORK/odin.out" "$WORK/odin.err"
	odin_code=$REPLY_CODE

	# --- our compiler --------------------------------------------------
	jit_obj="$WORK/$name.o"
	if ! "$JIT" "$entry" -o "$jit_obj" 2>"$WORK/jit-build.log"; then
		echo "  jit compile FAILED"
		cat "$WORK/jit-build.log" | sed 's/^/    /'
		fail=$((fail + 1))
		failed_names+=("$name (jit compile)")
		continue
	fi

	jit_bin="$WORK/$name-jit-bin"
	if ! zig cc "$jit_obj" -o "$jit_bin" 2>"$WORK/jit-link.log"; then
		echo "  zig cc link FAILED"
		cat "$WORK/jit-link.log" | sed 's/^/    /'
		fail=$((fail + 1))
		failed_names+=("$name (link)")
		continue
	fi

	run_capture "$jit_bin" "$WORK/jit.out" "$WORK/jit.err"
	jit_code=$REPLY_CODE

	# --- compare -------------------------------------------------------
	ok=1
	if [[ "$odin_code" != "$jit_code" ]]; then
		echo "  exit code mismatch: odin=$odin_code jit=$jit_code"
		ok=0
	fi
	if ! diff -q "$WORK/odin.out" "$WORK/jit.out" >/dev/null; then
		echo "  stdout mismatch:"
		diff "$WORK/odin.out" "$WORK/jit.out" | sed 's/^/    /'
		ok=0
	fi
	if ! diff -q "$WORK/odin.err" "$WORK/jit.err" >/dev/null; then
		echo "  stderr mismatch:"
		diff "$WORK/odin.err" "$WORK/jit.err" | sed 's/^/    /'
		ok=0
	fi

	if [[ "$ok" == 1 ]]; then
		echo "  OK (exit=$jit_code)"
		pass=$((pass + 1))
	else
		fail=$((fail + 1))
		failed_names+=("$name")
	fi
done

echo
echo "======================================"
echo "passed: $pass  failed: $fail"
if [[ "$fail" != 0 ]]; then
	echo "failures:"
	for n in "${failed_names[@]}"; do
		echo "  - $n"
	done
	exit 1
fi
