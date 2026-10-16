#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_dir="$repo_root/vendored/unicorn-engine"
build_dir="$source_dir/build"

if [[ ! -f "$source_dir/CMakeLists.txt" ]]; then
	printf '%s\n' 'Unicorn sources are missing. Run: git submodule update --init --recursive' >&2
	exit 1
fi

cmake -S "$source_dir" -B "$build_dir" \
	-DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF \
	-DUNICORN_ARCH=aarch64 -DUNICORN_BUILD_TESTS=OFF \
	-DUNICORN_INSTALL=OFF -DUNICORN_LEGACY_STATIC_ARCHIVE=ON
cmake --build "$build_dir" --target unicorn_archive --parallel "${JOBS:-$(nproc)}"
