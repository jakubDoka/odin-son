#!/bin/bash

targets=(windows_amd64 linux_amd64 linux_arm64 darwin_arm64)

for target in "${targets[@]}"; do
    echo "building $target"

    release_flags=(
        -source-code-locations:none
        -disable-assert
        -no-bounds-check
        -no-type-assert
        -define:NO_FMT=true
        -default-to-nil-allocator
        -define:ARNA_DISABLE_VIRTUAL=true
        -define:ARNA_DISABLE_THREAD_LOCAL=true
        -define:NO_DEFAULT_RANDOM_GENERATOR=true
        -disable-init-fini
        -define:INIT_FINI=false
        -define:NODE_NAMES=false
    )

    base_flags=(
        bac/bindgen/lib
        -build-mode:obj
        -no-entry-point
        -use-single-module
        "-target:$target"
    )

    echo " building debug"
    odin build "${base_flags[@]}" -debug "-out:bac/bindgen/lib/${target}_libdebug.o"
    echo " building release"
    odin build "${base_flags[@]}" "${release_flags[@]}"\
        "-out:bac/bindgen/lib/${target}_lib.o"
done
