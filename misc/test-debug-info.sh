#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$ROOT/test-programs/debug-info/main.odin"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

export ODIN_ROOT="${ODIN_ROOT:-$HOME/odin}"

if [ "$#" -gt 0 ]; then
	LEVELS=("$@")
else
	LEVELS=(none-quick none moderate-quick moderate all aggresive)
fi

for tool in odin zig gdb readelf objdump; do
	if ! command -v "$tool" >/dev/null; then
		echo "missing required tool: $tool" >&2
		exit 1
	fi
done

if [ -n "${JIT:-}" ]; then
	echo "using jit compiler: $JIT"
else
	JIT="$WORK/jit"
	echo "building jit compiler..."
	odin build "$ROOT" -out:"$JIT" -debug
fi

LOOP_LINE="$(awk '/v0 \+=/ {print NR; exit}' "$SOURCE")"
if [ -z "$LOOP_LINE" ]; then
	echo "debug checkpoint is missing from $SOURCE" >&2
	exit 1
fi

ODIN_SOURCE="$WORK/odin-source"
mkdir "$ODIN_SOURCE"
cp "$SOURCE" "$ODIN_SOURCE/main.odin"
sed -i 's/^main :: proc() -> int {/_main :: proc() -> int {/' "$ODIN_SOURCE/main.odin"
sed -i '0,/^package main$/s//package main\nimport __os "core:os"/' "$ODIN_SOURCE/main.odin"
printf '\nmain :: proc() { __os.exit(_main()) }\n' >>"$ODIN_SOURCE/main.odin"

ODIN_BIN="$WORK/odin-bin"
odin build "$ODIN_SOURCE" -out:"$ODIN_BIN" -debug -o:none

GDB_COMMANDS="$WORK/debug.gdb"
cat >"$GDB_COMMANDS" <<EOF
set pagination off
set confirm off
set debuginfod enabled off
set disable-randomization off
rbreak observe$
commands \$bpnum
silent
up-silently
printf "PARSE %lld %lld %lld\\n", parse_acc, parse_count, parse_i
down-silently
continue
end
break main.odin:$LOOP_LINE
commands
silent
if i < 4
printf "STATE %lld %lld %lld %lld %lld %lld\\n", i, total, v0, v5, v11, v16
end
continue
end
run
EOF

run_gdb() {
	local binary="$1"
	local output="$2"
	local raw="$output.raw"

	if ! gdb -q -nx -batch -x "$GDB_COMMANDS" "$binary" >"$raw" 2>&1; then
		cat "$raw" >&2
		return 1
	fi
	sed -n -e '/^PARSE /p' -e '/^STATE /p' "$raw" >"$output"
	if [ "$(wc -l <"$output")" -ne 8 ]; then
		echo "expected four parser and four pressure-loop GDB snapshots from $binary" >&2
		cat "$raw" >&2
		return 1
	fi
}

check_edge_locations() {
	local binary="$1"
	local spill_pc clobber_pc commands raw

	spill_pc="$(
		objdump -d --disassemble=main "$binary" |
		awk '!found && /push.*\(%rsp\)/ { getline; sub(/:/, "", $1); print $1; found = 1 }'
	)"
	clobber_pc="$(
		objdump -d --disassemble=digit_value "$binary" |
		awk '!found && /mov.*\$0xffffffffffffffff,%rax/ { getline; sub(/:/, "", $1); print $1; found = 1 }'
	)"
	if [ -z "$spill_pc" ] || [ -z "$clobber_pc" ]; then
		echo "expected spill copy and branch clobber instructions in $binary" >&2
		return 1
	fi

	commands="$WORK/edge-locations.gdb"
	raw="$WORK/edge-locations.raw"
	cat >"$commands" <<EOF
set pagination off
set confirm off
set debuginfod enabled off
set disable-randomization off
break *0x$spill_pc
run
printf "SPILL %lld\\n", v4
EOF
	if ! gdb -q -nx -batch -x "$commands" "$binary" >"$raw" 2>&1; then
		cat "$raw" >&2
		return 1
	fi
	if ! gdb -q -nx -batch \
		-ex 'set pagination off' \
		-ex 'set debuginfod enabled off' \
		-ex "break *0x$clobber_pc" \
		-ex start \
		-ex 'call (long) digit_value(11)' \
		-ex 'print c' \
		"$binary" >>"$raw" 2>&1; then
		cat "$raw" >&2
		return 1
	fi
	if ! grep -q '^SPILL 5$' "$raw" || ! grep -q '= <optimized out>$' "$raw"; then
		echo "spill or branch-edge location is incorrect in $binary" >&2
		cat "$raw" >&2
		return 1
	fi
}

EXPECTED="$WORK/odin.states"
run_gdb "$ODIN_BIN" "$EXPECTED"

for level in "${LEVELS[@]}"; do
	obj="$WORK/jit-$level.o"
	bin="$WORK/jit-$level"
	actual="$WORK/jit-$level.states"
	dwarf="$WORK/jit-$level.dwarf"

	"$JIT" "$SOURCE" -g "-o:$level" -o "$obj"
	zig cc "$obj" -o "$bin"
	readelf --debug-dump=loc "$obj" >"$dwarf"
	if ! grep -q 'DW_OP_reg' "$dwarf" || ! grep -q 'DW_OP_breg' "$dwarf"; then
		echo "[$level] expected register and spill location ranges" >&2
		exit 1
	fi

	run_gdb "$bin" "$actual"
	if [ "$level" = none ]; then
		check_edge_locations "$bin"
	fi
	if ! diff -u "$EXPECTED" "$actual"; then
		echo "[$level] GDB state differs from Odin" >&2
		exit 1
	fi
	echo "[$level] OK"
done
