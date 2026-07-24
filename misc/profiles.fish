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
 
alias run-test 'odin test tests -keep-executable -debug -define:ODIN_TEST_FANCY=false -o:none'

alias measure 'rg --files --glob "!*.git/" --glob "!vendored" --glob \
"!print-tests" --glob "!TESTS.md" --glob "!tests.odin" --glob \
"!backend/**/node_specs.odin" --glob "!test-programs" --glob "!examples" | xargs \
wc -l | sort -n'

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
