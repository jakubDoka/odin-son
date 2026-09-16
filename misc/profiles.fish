# regenerates backend's own node_specs.odin, then every backend/<arch>
# submodule that has a gen_<arch>.odin (its own spec generator) — so adding a
# new architecture directory is enough on its own, no edit needed here
function gen-spec
	rm -f backend/node_specs.odin
	odin run backend -define:GEN_SPEC=true
	or return 1
	odin check backend -define:GEN_SPEC=false -no-entry-point
	or return 1

	for dir in backend/*/
		set -l name (basename $dir)
		set -l gen_file "$dir"gen_$name.odin
		if test -e $gen_file
			set -l define (string upper $name)_GEN_SPEC
			rm -f "$dir"node_specs.odin
			odin run $dir -define:$define=true
			or return 1
			odin check $dir -define:$define=false -no-entry-point
			or return 1
		end
	end
end

# regenerate the tests and overloads
alias gen-meta 'odin run meta -o:none'

set acc '-define:ACCEPT=true'
set rlg '-define:REGLOGS=true'
set dff '-define:DIFF=false'
 
alias run-test 'odin test tests -keep-executable -debug -define:ODIN_TEST_FANCY=false'

# ./misc/fuzz.sh [-t <secs>] [-j <jobs>] [--until-crash] [--skip-build]
alias fuzz './misc/fuzz.sh'

function build-wamr
	set -l source vendored/wasm-micro-runtime/wamr-compiler
	set -l build vendored/wasm-micro-runtime/build-aot
	set -l llvm_dir (llvm-config --cmakedir)

	cmake -S $source -B $build -DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ \
		-DLLVM_DIR=$llvm_dir -DLLVM_LINK_LLVM_DYLIB=ON -DWAMR_BUILD_SIMD=1
	or return 1
	cmake --build $build --target vmlib aotclib --parallel
	or return 1
	cp $build/libvmlib.a $build/libaotclib.a wamr/
	or return 1

	clang -std=c11 -O2 -Ivendored/wasm-micro-runtime/core/iwasm/include \
		-c wamr/run.c -o wamr/run.o
	or return 1
	clang -std=c11 -O2 -D_GNU_SOURCE -include wamr/aot_config.h \
		-Ivendored/wasm-micro-runtime/core/iwasm/include \
		-Ivendored/wasm-micro-runtime/core/iwasm/aot \
		-Ivendored/wasm-micro-runtime/core/iwasm/aot/arch \
		-Ivendored/wasm-micro-runtime/core/iwasm/common \
		-Ivendored/wasm-micro-runtime/core/iwasm/common/gc \
		-Ivendored/wasm-micro-runtime/core/iwasm/common/gc/stringref \
		-Ivendored/wasm-micro-runtime/core/iwasm/compilation \
		-Ivendored/wasm-micro-runtime/core/iwasm/interpreter \
		-Ivendored/wasm-micro-runtime/core/iwasm/libraries/libc-wasi/sandboxed-system-primitives/src \
		-Ivendored/wasm-micro-runtime/core/shared/include \
		-Ivendored/wasm-micro-runtime/core/shared/platform/include \
		-Ivendored/wasm-micro-runtime/core/shared/platform/linux \
		-Ivendored/wasm-micro-runtime/core/shared/utils \
		-c vendored/wasm-micro-runtime/core/iwasm/aot/arch/aot_reloc_x86_64.c \
		-o wamr/aot_reloc.o
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
"!backend/**/node_specs.odin" --glob "!*meta_overloads.odin" \
--glob "!test-programs" --glob "!examples" --glob "!fuzz/crashes/*" \
--glob "!*.wasm"'

alias measure 'rel-files | xargs wc -l | sort -n'

function run-test-program
	odin build . -debug $argv[2..]
	export ODIN_ROOT=$HOME/odin/
	./jit test-programs/$argv[1]/
	zig cc a.o
	./a.out
end

function dump-test-program
	odin build . -debug $argv[2..]
	set ODIN_ROOT $HOME/odin/
	./jit test-programs/$argv[1]/
	objdump -d --no-show-raw-insn "a.o" | perl -p -e 's/^\s+(\S+):\t//'
end

alias deploy-mini-odin 'scp -r mini-odin root@95.217.156.80:/var/www/'
