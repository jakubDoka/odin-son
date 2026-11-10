function run-if-changed --argument-names deps
    set -l cmd $argv[2..]
    set -l dir ~/.cache/run-if-changed
    mkdir -p $dir
    set -l stamp $dir/(string join \n -- $argv | sha1sum | string split -f1 ' ')

    if test -e $stamp; and test -z "$(find (string split -n ' ' -- $deps) -newer $stamp -print -quit)"
        return 0
    end

    touch $stamp.tmp
    $cmd
    set -l code $status
    test $code -eq 0; and mv $stamp.tmp $stamp
    return $code
end

function script
    run-if-changed './script' odin build script -out:script.bin
    ./script.bin $argv
end

function script-alias
    alias $argv[1] "script $argv"
end

alias rel-files 'rg --files --glob "!*.git/" --glob "!vendored" --glob \
"!print-tests" --glob "!TESTS.md" --glob "!tests.odin" --glob \
"!bac/**/node_specs.odin" --glob "!*meta_overloads.odin" \
--glob "!test-programs" --glob "!examples" --glob "!fuzz/crashes/*" \
--glob "!*.wasm" --glob "!*.o" --glob "!bac/bindgen/lib/" --glob "!bac/bindgen/api.odin"'

### codegen

script-alias gen-spec

### testing

set acc '-define:ACCEPT=true'
set rlg '-define:REGLOGS=true'
set dff '-define:DIFF=false'
set nrn '-define:NO_RUN=true'

alias gen-meta 'odin run bac/tag-gen'
alias run-test 'odin test tests -keep-executable -debug -define:ODIN_TEST_FANCY=false'

script-alias run-programs

### before commit

alias fmt-files 'rel-files | rg ".*odin\$"'
alias fmt 'fmt-files | xargs -I{} odinfmt -w {}'

### building releases

script-alias build-unicorn
script-alias build-wabt
script-alias build-wasm
script-alias prebuild-libs

### unimportant

alias measure 'rel-files | xargs wc -l | sort -n'
alias deploy-mini-odin 'scp -r odinc/mini root@95.217.156.80:/var/www/'
