This codebase contains a in progress implementation of the JIT compiler and a
Odin frontend to dogfood the JIT.

The tests are generated with `gen-meta` (look into `misc/profiles.fish`) and
node spec is generated with `gen-spec`, you can run tests with `run-test`.

The backend is split into `backend` (the generic engine, shared node spec, and
codegen scaffolding) plus one subpackage per architecture, e.g. `backend/x64`
and the pre-lowering IR builder `backend/builder`. Shared node kinds go into
`Ideal_Node_Type` in `backend/gen_spec.odin`; target-specific node kinds go
into that target's own enum in its own module (e.g. `X64_Node_Type` in
`backend/x64/x64.odin`, `Builder_Node_Type` in `backend/builder/builder_spec.odin`).
Adding a new architecture means adding a new `backend/<arch>` directory —
nothing in root `backend` should need editing.
If you are going to use the generated construction fuctions in the backend, or
any generated thing for that matter, they should have a stup version in that
module's own bootstrap file (`gen_spec.odin` for root, `<arch>_spec.odin` for
a submodule) or the codegen will fail.

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

It's important that whenever you work around a compiler bug, denote it in the
test code with a comment starting with `COMPILER BUG:`, you can then fff for
this when they need to be fixed. Also place the code that broke in a comment so
that the you can later uncomment it to test.

When you need to allocate memory local to a function, use `context.allocator, _
:= arna.scrath()`. If the function takes out allocator and returns a heap, then
use the `arna.scratch(allocator)`.

It's good to note that common source of memory corruption is if the allocator
was not set on a `[dynamic]T` or map or anything that grabs the allocator from
the context. So basically, grep the value and verify the allocator was properly
set. Reason this happens is becuause its common to override the main allocator
with a scoped arena. As mentioned above.
