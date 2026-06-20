This codebase contains a in progress implementation of the JIT compiler and a
Odin frontend to dogfood the JIT.

The tests are generated with `gen-meta` (look into misc/profiles.fish) and node
spec is generated with `gen-spec`, you can run tests with `run-test`.

The node spec is specified mostly in the `backned/gen_spec.odin`, when adding
new nodes, they should be added to the `Ideal_Node_Type` if they are shared and
otherwise into the appropriate target specific enum (defined in the same file).
If you are going to use the generated construction fuctions in the backend, or
any generated thing for that matter, they should have a stup version in the
`gen_sepc.odin` or the codegen will fail.

A test is specified in a TESTS.md in a standard format that is parsed by
`meta.odin` and translated to `tests.odin` functions. The code snipped needs to
be compilable with odin compiler and SHOULD NEVER CONTAIN REACHABLE INFINITE
LOOP since ist ran before the actual test starts to extract the return value
that is then asserted for changes.
