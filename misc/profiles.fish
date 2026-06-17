alias gen-spec 'rm backend/node_specs.odin;\
	odin run backend -define:GEN_SPEC=true;\
	odin check backend -define:GEN_SPEC=false -no-entry-point'

# regenerate the tests and overloads
alias gen-meta 'odin run meta'

alias run-test 'odin test . -keep-executable -debug'
