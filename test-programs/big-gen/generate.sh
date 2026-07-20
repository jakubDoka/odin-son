#!/usr/bin/env bash

set -euo pipefail

cd $(dirname $0)

rm *.odin || true


FILE_COUNT=10
DEPTH=5
next_id=0

generate() {
    local depth=$1
    local id=$next_id
    next_id=$((next_id + 1))

    if (( depth == DEPTH )); then
        leaves+=("$id")
        return
    fi

    local left=$((next_id))
    generate $((depth + 1))

    local right=$((next_id))
    generate $((depth + 1))

    internal+=("$id $left $right")
}

declare -a roots
declare -a internal
declare -a leaves

for i in $(seq 0 $FILE_COUNT); do
	FILE_NAME="subfile$i.odin"
	echo "package main" >  $FILE_NAME
	echo                >> $FILE_NAME

	internal=()
	leaves=()

	roots+=("$next_id")
	generate 0

	# Emit leaves first.
	for id in "${leaves[@]}"; do
		cat >> $FILE_NAME <<-EOF
			f$id :: proc() -> int {
			    return $id
			}
		EOF
	done

	# Emit internal nodes in reverse order so callees appear first.
	for ((i=${#internal[@]}-1; i>=0; --i)); do
    	read id left right <<<"${internal[$i]}"

		cat >> $FILE_NAME <<-EOF
			f$id :: proc() -> int {
			    sum := $id
			    sum += f$left()
			    sum += f$right()
			    return sum
			}
		EOF
	done
done

cat > main.odin <<-EOF 
package main

import "base:intrinsics"

main :: proc() -> int {
	i := 0
EOF

for root in "${roots[@]}"; do
	echo "i += f$root()" >> main.odin
done


cat >> main.odin <<-EOF 
	return i
}
EOF
