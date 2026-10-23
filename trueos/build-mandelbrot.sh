#!/usr/bin/env bash
set -euo pipefail
native_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$native_dir/build.sh" -define:TRUEOS_MANDELBROT_VERIFY_DEFAULT=true "$@"
cp "$native_dir/build/odin-son.o" "$native_dir/build/odin-mandelbrot.o"
cp "$native_dir/build/odin-son.bp" "$native_dir/build/odin-mandelbrot.bp"
bash "$native_dir/build.sh" "$@"
printf '%s\n' "$native_dir/build/odin-mandelbrot.bp"
