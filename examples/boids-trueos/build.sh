#!/usr/bin/env bash
set -euo pipefail

app_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$app_dir/../.." && pwd)"
build_dir="$app_dir/build"
mkdir -p "$build_dir"

if [[ -z "${ODIN_ROOT:-}" || -z "${JIT:-}" ]]; then
	odin_bin="${ODIN:-odin}"
	odin_path="$(command -v "$odin_bin")"
	export ODIN_ROOT="${ODIN_ROOT:-$(dirname "$(readlink -f "$odin_path")")}"
fi
if [[ -z "${JIT:-}" ]]; then
	"$odin_bin" build "$repo_root" -out:"$build_dir/odin-son"
	JIT="$build_dir/odin-son"
fi

"$JIT" "$app_dir/main.odin" -o "$build_dir/boids.o"
python3 "$app_dir/package.py" "$build_dir/boids.o" "$build_dir/boids.bp"
