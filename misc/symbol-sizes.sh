#!/usr/bin/env bash

set -euo pipefail
export LC_ALL=C

usage() {
	printf 'Usage: %s <library.a>\n' "${0##*/}"
	printf 'List defined symbols with recorded sizes, largest first (bytes).\n'
}

if [[ $# -eq 1 && ( "$1" == -h || "$1" == --help ) ]]; then
	usage
	exit 0
fi

if [[ $# -ne 1 ]]; then
	usage >&2
	exit 1
fi

if [[ ! -f "$1" ]]; then
	printf 'Library not found: %s\n' "$1" >&2
	exit 1
fi

for tool in nm awk sort; do
	if ! command -v "$tool" >/dev/null; then
		printf 'Missing required tool: %s\n' "$tool" >&2
		exit 1
	fi
done

symbols="$(
	nm --format=bsd --defined-only --print-size --radix=d --no-sort -- "$1" |
		awk '
			$1 ~ /^[0-9]+$/ && $2 ~ /^[0-9]+$/ {
				size = $2
				sub(/^[[:space:]]*[0-9]+[[:space:]]+[0-9]+[[:space:]]+[^[:space:]]+[[:space:]]+/, "")
				printf "%.0f\t%s\n", size, $0
			}
		' |
		sort -k1,1nr -k2
)"

if [[ -z "$symbols" ]]; then
	printf 'No sized symbols found in %s; the library may be stripped.\n' "$1" >&2
	exit 1
fi

printf '%12s  %s\n' 'SIZE (bytes)' 'SYMBOL'
printf '%s\n' "$symbols" |
	awk '{ size = $1; sub(/^[^\t]*\t/, ""); printf "%12.0f  %s\n", size, $0 }'
