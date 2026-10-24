#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

odin_bin="${ODIN:-odin}"
export ODIN_ROOT="${ODIN_ROOT:-$(dirname "$(readlink -f "$(command -v "$odin_bin")")")}"
jit="${JIT:-$work_dir/jit}"

if [[ -z "${JIT:-}" ]]; then
	"$odin_bin" build "$repo_root/odinc" -out:"$jit"
fi

mkdir "$work_dir/foreign-call"
cat > "$work_dir/foreign-call/main.odin" <<'EOF'
package main

foreign _ {
	abs :: proc(value: i32) -> i32 ---
}

main :: proc() -> int {
	return int(abs(-42))
}
EOF

capture() {
	local status=0
	timeout 12 "$1" > "$2.stdout" 2> "$2.stderr" || status=$?
	if (( status == 124 )); then
		printf 'Program timed out: %s\n' "$1" >&2
		exit 1
	fi
	printf '%s\n' "$status" > "$2.status"
}

for program in arithmetic struct-copy foreign-call; do
	source_dir="$repo_root/test-programs/$program"
	if [[ "$program" == foreign-call ]]; then
		source_dir="$work_dir/foreign-call"
	fi

	ref_dir="$work_dir/reference-$program"
	mkdir "$ref_dir"
	cp "$source_dir/main.odin" "$ref_dir/main.odin"
	sed -i 's/^main :: proc() -> int {/_main :: proc() -> int {/' "$ref_dir/main.odin"
	sed -i '/^package main$/a import __os "core:os"' "$ref_dir/main.odin"
	printf '\nmain :: proc() { __os.exit(_main()) }\n' >> "$ref_dir/main.odin"
	"$odin_bin" build "$ref_dir" -out:"$ref_dir/bin" -o:none
	capture "$ref_dir/bin" "$ref_dir/result"

	for level in none-quick none moderate-quick moderate all aggresive; do
		obj="$work_dir/$program-$level.o"
		timeout 12 "$jit" "$source_dir/main.odin" -o:"$level" -debug -o "$obj"
		readelf --symbols --wide "$obj" | awk '
			$5 == "GLOBAL" && $7 == "UND" && NF == 7 { bad = 1 }
			END { exit bad }
		'
		for linker in gcc clang; do
			bin="$work_dir/$program-$level-$linker"
			"$linker" -pie "$obj" -o "$bin"
			capture "$bin" "$bin"
			for part in status stdout stderr; do
				cmp "$ref_dir/result.$part" "$bin.$part"
			done
		done
		printf 'PASS %s (%s, GCC and Clang)\n' "$program" "$level"
	done
done
