#!/usr/bin/env bash
# Builds an AFL++ instrumented compiler and fuzzes it with the TESTS.md corpus.
#
#   ./misc/fuzz.sh [-t <secs>] [-j <jobs>] [--until-crash] [--skip-build]
#
# Odin has no AFL frontend, so the build goes through LLVM IR: odin emits one
# .ll per package and afl-clang-fast instruments them on the way to the binary.
set -euo pipefail

cd "$(dirname "$0")/.."

DURATION=60
JOBS=1
UNTIL_CRASH=0
SKIP_BUILD=0

BUILD_DIR=fuzz/build
TARGET=fuzz/jit-fuzz
CORPUS=fuzz/corpus
OUT=fuzz/out

usage() {
	sed -n '2,7p' "$0" | sed 's/^# \?//'
	exit "${1:-0}"
}

while [ $# -gt 0 ]; do
	case "$1" in
	-t | --time)
		DURATION="$2"
		shift 2
		;;
	-j | --jobs)
		JOBS="$2"
		shift 2
		;;
	--until-crash) UNTIL_CRASH=1; shift ;;
	--skip-build)  SKIP_BUILD=1;  shift ;;
	-h | --help)   usage 0 ;;
	*)
		echo "unknown flag: $1" >&2
		usage 1
		;;
	esac
done

if [ ! -d "$CORPUS" ] || [ -z "$(ls -A "$CORPUS" 2>/dev/null)" ]; then
	echo ">> generating corpus (odin run meta)"
	odin run meta -o:none
fi

if [ "$SKIP_BUILD" -eq 0 ]; then
	rm -rf "$BUILD_DIR"
	mkdir -p "$BUILD_DIR"

	# -o:speed with bounds checks and asserts left in: a tripped safety check
	# traps, which is exactly the signal afl-fuzz is looking for
	echo ">> emitting llvm ir"
	odin build . -build-mode:llvm-ir -out:"$BUILD_DIR" -o:speed \
		-define:FUZZ=true -define:NO_RUN=true -define:DIFF=false

	echo ">> instrumenting"
	afl-clang-fast -O2 $(find "$BUILD_DIR" -name "*.ll") -o "$TARGET" \
		-lm -lpthread -ldl
fi

if [ ! -x "$TARGET" ]; then
	echo "$TARGET is missing, drop --skip-build" >&2
	exit 1
fi

mkdir -p "$OUT"

export AFL_SKIP_CPUFREQ=1
export AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1
export AFL_NO_AFFINITY=1
if [ "$UNTIL_CRASH" -eq 1 ]; then
	export AFL_BENCH_UNTIL_CRASH=1
fi

pids=()
cleanup() {
	for pid in "${pids[@]:-}"; do
		kill "$pid" 2>/dev/null || true
	done
}
trap cleanup EXIT INT TERM

for i in $(seq 1 "$JOBS"); do
	if [ "$i" -eq 1 ]; then
		# a lone fuzzer needs no role, and -M would force the (slow)
		# deterministic stage on it for no reason
		[ "$JOBS" -eq 1 ] && role=() || role=(-M main)
		log=/dev/stdout
	else
		role=(-S "worker$i")
		log="$OUT/worker$i.log"
	fi

	AFL_NO_UI=1 timeout --foreground -s INT "$DURATION" \
		afl-fuzz -i "$CORPUS" -o "$OUT" -t 500+ "${role[@]}" \
		-- "$TARGET" @@ >"$log" 2>&1 &
	pids+=($!)
done

wait || true
trap - EXIT INT TERM

echo
crashes=$(find "$OUT" -path '*/crashes/id:*' 2>/dev/null | wc -l)
echo ">> $crashes crashing input(s) in $OUT"
if [ "$crashes" -gt 0 ]; then
	echo ">> run 'odin run meta -o:none' to turn them into tests"
fi
