#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

"${CXX:-g++}" -std=c++17 -O2 -c "$repo_root/wabt/run.cc" -o "$work_dir/run.o"
ar rcs "$work_dir/libwabt_runner.a" "$work_dir/run.o"
mv "$work_dir/libwabt_runner.a" "$repo_root/wabt/libwabt_runner.a"
