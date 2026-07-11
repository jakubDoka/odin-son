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

Another category of tests we have are `test-programs`, that can be ran with
`./misc/run-programs.sh`, the scripts asserts that exit codes and stdout/err
are identical in programs compiled with each compiler.

When running tests, NEVER wait for more the 5 seconds, tests usually compile in
1s and run in matter of miliseconds.

Whenever you see `#### Part n` you should spinn up an agent with that section
as input.

When instructed to spawn an agent to do something early, dont waste context
analising the task, just pass down the instructions and let the agent figure it
out.

NEVER comment the code with what it does, only why we absolutely need it if its
handling an edgecase that is unclear.

The peephole optimizations can be found with `_peep :: proc`.

If the test segfaults use -define:NO_RUN=true to view the disassembly.

Use the fff MCP tools for all file search operations instead of default tools.
