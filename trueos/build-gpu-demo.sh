#!/usr/bin/env bash
set -euo pipefail
native_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$native_dir/build.sh" \
  -define:TRUEOS_GPU_BOIDS_DEFAULT=true \
  -define:TRUEOS_GPU_BOIDS_AUTORUN=true \
  -define:TRUEOS_GPU_BOIDS_BATCH=false \
  "$@"
