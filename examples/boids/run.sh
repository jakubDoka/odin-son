#!/usr/bin/env bash

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"

JIT="$ROOT/jit"
OBJ="$HERE/boids.o"
BIN="$HERE/boids"

export ODIN_ROOT=$HOME/odin/

if [[ "${JIT_SKIP_BUILD:-0}" != "1" ]]; then
	echo "building jit compiler..."
	(cd "$ROOT" && odin build . -out:jit)
fi

echo "compiling boids with jit..."
"$JIT" "$HERE/main.odin" -out:"$OBJ"

RAYLIB_LIBS="$(pkg-config --libs raylib 2>/dev/null || echo -lraylib)"

echo "linking against system raylib..."
gcc "$OBJ" -o "$BIN" $RAYLIB_LIBS -lm -lpthread -ldl

echo "running..."
exec "$BIN"
