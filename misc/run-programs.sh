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

# The optimization levels mirror OPT_LEVELS in gen.odin / the unit-test harness
# in test_utils.odin. Each program is compiled once per level and every level is
# compared against the same (jit-agnostic) reference Odin binary.
LEVELS=(none mininal moderate all aggresive)

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

	# --- optional per-program generator --------------------------------
	# A program may ship a `generate.sh` that produces committed-or-throwaway
	# Odin sources before the build (e.g. the wasm program embeds compiled
	# blobs). Run it once, up front, so the reference and JIT builds compile
	# identical source. A failing generator fails the program.
	gen="$dir/generate.sh"
	if [[ -f "$gen" ]]; then
		echo "  generating..."
		if ! bash "$gen" >"$WORK/gen.log" 2>&1; then
			echo "  generate FAILED"
			cat "$WORK/gen.log" | sed 's/^/    /'
			fail=$((fail + 1))
			failed_names+=("$name (generate)")
			continue
		fi
	fi

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

	# --- our compiler, once per optimization level ---------------------
	for level in "${LEVELS[@]}"; do
		jit_obj="$WORK/$name-$level.o"
		if ! "$JIT" "$entry" -O:"$level" -o "$jit_obj" 2>"$WORK/jit-build.log"; then
			echo "  [$level] jit compile FAILED"
			cat "$WORK/jit-build.log" | sed 's/^/    /'
			fail=$((fail + 1))
			failed_names+=("$name/$level (jit compile)")
			continue
		fi

		jit_bin="$WORK/$name-$level-jit-bin"
		if ! zig cc "$jit_obj" -o "$jit_bin" 2>"$WORK/jit-link.log"; then
			echo "  [$level] zig cc link FAILED"
			cat "$WORK/jit-link.log" | sed 's/^/    /'
			fail=$((fail + 1))
			failed_names+=("$name/$level (link)")
			continue
		fi

		run_capture "$jit_bin" "$WORK/jit.out" "$WORK/jit.err"
		jit_code=$REPLY_CODE

		# --- compare -------------------------------------------------------
		ok=1
		if [[ "$odin_code" != "$jit_code" ]]; then
			echo "  [$level] exit code mismatch: odin=$odin_code jit=$jit_code"
			ok=0
		fi
		if ! diff -q "$WORK/odin.out" "$WORK/jit.out" >/dev/null; then
			echo "  [$level] stdout mismatch:"
			diff "$WORK/odin.out" "$WORK/jit.out" | sed 's/^/    /'
			ok=0
		fi
		if ! diff -q "$WORK/odin.err" "$WORK/jit.err" >/dev/null; then
			echo "  [$level] stderr mismatch:"
			diff "$WORK/odin.err" "$WORK/jit.err" | sed 's/^/    /'
			ok=0
		fi

		if [[ "$ok" == 1 ]]; then
			echo "  [$level] OK (exit=$jit_code)"
			pass=$((pass + 1))
		else
			fail=$((fail + 1))
			failed_names+=("$name/$level")
		fi
	done
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
