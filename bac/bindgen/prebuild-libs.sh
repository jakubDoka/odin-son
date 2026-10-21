#!/bin/bash

set -e

REAL_ODIN_ROOT=$(oding root)

TEMP_ODIN_ROOT=$(mktemp -d /tmp/odin.XXXXX)

cp -r $REAL_ODIN_ROOT/. $TEMP_ODIN_ROOT/

export ODIN_ROOT=$TEMP_ODIN_ROOT

to_comment_out=(
    'query_page_size_init :: proc "contextless" '
    'temp_allocator_fini :: proc "contextless" '
    'init_std_files :: proc "contextless" '
    'delete_args :: proc "contextless" '
    'init_standard_stream_status :: proc "contextless" '
    'init_terminal :: proc "contextless" '
    'init_thread_local_cleaner :: proc "contextless" '
    'fini_terminal :: proc "contextless" '
    '_standard_stream_init :: proc "contextless" '
)

for pattern in "${to_comment_out[@]}"; do
    rg -l -F "$pattern" $TEMP_ODIN_ROOT | while IFS= read -r file; do
        sed -i 's/@(init/\/\/@(init/g' $file
        sed -i 's/@(fini/\/\/@(fini/g' $file
        sed -i 's/@init/\/\/@init/g' $file
    done
done

targets=(windows_amd64 linux_amd64 linux_arm64 darwin_arm64)

release_flags=(
    -source-code-locations:none
    -disable-assert
    -no-bounds-check
    -no-type-assert
    -define:NO_FMT=true
    -default-to-nil-allocator
    -define:ARNA_DISABLE_VIRTUAL=true
    -define:ARNA_DISABLE_THREAD_LOCAL=true
    -disable-init-fini
    -define:NODE_NAMES=false
    -disable-non-constant-globals
)

base_flags=(
    bac/bindgen/lib
    -build-mode:obj
    -no-entry-point
    -use-single-module
)

for target in "${targets[@]}"; do
    echo "building $target"

    echo " building debug"
    odin build "${base_flags[@]}" "-target:$target" -debug \
        "-out:bac/bindgen/lib/${target}_libdebug.o"
    echo " building release"
    odin build "${base_flags[@]}" -o:size "-target:$target" "${release_flags[@]}"\
        "-out:bac/bindgen/lib/${target}_lib.o"

    if [[ "$target" == windows_amd64 ]]; then
        echo " building GNU objects"
        for lib in libdebug lib; do
            "${OBJCOPY:-x86_64-w64-mingw32-objcopy}" \
                --redefine-sym __chkstk=___chkstk_ms \
                "bac/bindgen/lib/${target}_${lib}.o" \
                "bac/bindgen/lib/${target}_gnu_${lib}.o"
        done
    fi
done

cp bac/bindgen/lib/*.o bac/bindgen/rust/lib/

