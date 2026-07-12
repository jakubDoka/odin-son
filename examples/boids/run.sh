#!/usr/bin/env bash
#
# Build the JIT compiler, compile examples/boids with it into a relocatable
# object, then link that object against the system-installed raylib and run it.
#
# raylib is bound by hand in main.odin via a `foreign` block; here we just tell
# the linker where to find its symbols (-lraylib and the libs it needs).

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"

JIT="$ROOT/jit"
OBJ="$HERE/boids.o"
BIN="$HERE/boids"

export ODIN_ROOT=$HOME/odin/

# Build the compiler (fast; skip with JIT_SKIP_BUILD=1 once it is built).
if [[ "${JIT_SKIP_BUILD:-0}" != "1" ]]; then
	echo "building jit compiler..."
	(cd "$ROOT" && odin build . -out:jit)
fi

echo "compiling boids with jit..."
"$JIT" "$HERE/main.odin" -o "$OBJ"

# Prefer pkg-config for the exact link flags; fall back to a plain -lraylib.
RAYLIB_LIBS="$(pkg-config --libs raylib 2>/dev/null || echo -lraylib)"

echo "linking against system raylib..."
zig cc "$OBJ" -o "$BIN" $RAYLIB_LIBS -lm -lpthread -ldl

echo "running..."
exec "$BIN"
