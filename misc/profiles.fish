# regenerates bac's own node_specs.odin, then every bac/<arch>
# submodule that has a gen_<arch>.odin (its own spec generator) — so adding a
# new architecture directory is enough on its own, no edit needed here
function gen-spec
	rm -f bac/node_specs.odin
	rm -f bac/*/node_specs.odin

	odin run bac/meta
	odin run bac/meta2
end

# regenerate the tests and overloads
alias gen-meta 'odin run meta -o:none'

set acc '-define:ACCEPT=true'
set rlg '-define:REGLOGS=true'
set dff '-define:DIFF=false'
 
alias run-test 'odin test tests -keep-executable -debug -define:ODIN_TEST_FANCY=false'

# ./misc/fuzz.sh [-t <secs>] [-j <jobs>] [--until-crash] [--skip-build]
alias fuzz './misc/fuzz.sh'

function build-wabt
	bash misc/build-wabt.sh
end

function build-unicorn
	bash misc/build-unicorn.sh
end


function build-wasm-debug
	odin build wasm -target:freestanding_wasm32 -no-entry-point \
		-disable-assert -no-bounds-check -no-type-assert \
		-extra-linker-flags:"-z stack-size=8388608 --export=source_buffer --export=output_buffer --export=__stack_pointer" $argv
	mv wasm.wasm mini-odin
end

function build-wasm
	odin build wasm -target:freestanding_wasm32 -no-entry-point -o:size \
		-disable-assert -no-bounds-check -no-type-assert \
		-extra-linker-flags:"-z stack-size=8388608 --export=source_buffer --export=output_buffer --export=__stack_pointer" $argv
	wasm-opt -Oz wasm.wasm -o wasm.wasm
	mv wasm.wasm mini-odin
end

alias rel-files 'rg --files --glob "!*.git/" --glob "!vendored" --glob \
"!print-tests" --glob "!TESTS.md" --glob "!tests.odin" --glob \
"!bac/**/node_specs.odin" --glob "!*meta_overloads.odin" \
--glob "!test-programs" --glob "!examples" --glob "!fuzz/crashes/*" \
--glob "!*.wasm"'

alias measure 'rel-files | xargs wc -l | sort -n'

function run-test-program
	odin build . -debug $argv[2..]
	export ODIN_ROOT=$HOME/odin/
	./jit test-programs/$argv[1]/
	gcc a.o
	./a.out
end

function dump-test-program
	odin build . -debug $argv[2..]
	set ODIN_ROOT $HOME/odin/
	./jit test-programs/$argv[1]/
	objdump -d --no-show-raw-insn "a.o" | perl -p -e 's/^\s+(\S+):\t//'
end

alias deploy-mini-odin 'scp -r mini-odin root@95.217.156.80:/var/www/'
