#!/usr/bin/env bash
set -euo pipefail
native_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
python3 "$native_dir/prepare_gpu_demo.py"
if [[ -n "${ODIN_SON:-}" ]]; then
    compiler="$(command -v "$ODIN_SON")"
else
    python3 "$native_dir/build_host_compiler.py"
    compiler="$native_dir/build/odin-son-host"
fi
# The host frontend checks these collection directories even for import-free code.
collections="$native_dir/build/empty-collections"
mkdir -p "$collections/base" "$collections/core" "$collections/vendor"
ODIN_ROOT="$collections" "$compiler" "$native_dir/gpu-demo/main.odin" \
    -o "$native_dir/build/odin-son-gpu.raw.o" "$@"
objcopy --strip-debug "$native_dir/build/odin-son-gpu.raw.o" "$native_dir/build/odin-son-gpu.o"
python3 "$native_dir/package_gpu_demo.py" --compiler "$compiler"
