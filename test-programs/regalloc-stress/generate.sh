#!/usr/bin/env bash

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

odin run "$DIR/gen" -out:"${TMPDIR:-/tmp}/jit-regalloc-stress-gen" -- "$DIR/main.odin"
