#!/usr/bin/env bash
set -euo pipefail
native_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
odin_bin="${ODIN:-odin}"
odin_path="$(command -v "$odin_bin")"
sdk_root="${ODIN_SDK_ROOT:-${ODIN_ROOT:-$("$odin_path" root)}}"
python3 "$native_dir/prepare.py" "$sdk_root"
ODIN_ROOT="$native_dir/build/sdk" "$odin_path" build "$native_dir/build/src" \
    -target:freestanding_amd64_sysv -build-mode:obj -no-entry-point \
    -no-thread-local -disable-red-zone -reloc-mode:pic -use-single-module \
    -define:TRUEOS=true \
    -out:"$native_dir/build/odin-son.raw.o" "$@"
cp "$native_dir/build/odin-son.raw.o" "$native_dir/build/odin-son.o"
python3 "$native_dir/package.py" "$native_dir/build/odin-son.o" "$native_dir/build/odin-son.bp"
