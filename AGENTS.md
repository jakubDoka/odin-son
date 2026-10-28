This codebase contains a in progress implementation of the JIT compiler and a
Odin frontend to dogfood the JIT.

The tests are generated with `gen-meta` (look into `misc/profiles.fish`) and
node spec is generated with `gen-spec`, you can run tests with `run-test`.

The backend is split into `bac` (the generic engine, shared node spec, and
codegen scaffolding) plus one subpackage per architecture, e.g. `bac/x64` and
the pre-lowering SSA IR `bac/ssa`. Shared node kinds are in
`Node_Type` in `bac/graph.odin`; target-specific node kinds go into that
target's own enum in its own module (e.g. `Node_Type` in `bac/x64/x64.odin`,
`Node_Type` in `bac/ssa/ssa_spec.odin`). Adding a new architecture
means adding a new `bac/<arch>` directory — nothing in root `bac` should need
editing. If you are going to use the generated construction fuctions in the
backend, or any generated thing for that matter, they should have a stub
version in that module's own bootstrap file (`bac/meta/meta.odin` for root,
`bac/meta2/meta2.odin` for generating the submodules) or the codegen will fail.

A test is specified in a `tests/TESTS.md` in a standard format that is parsed
by `meta.odin` and translated to `tests/tests.odin` functions. The code snipped
needs to be compilable with odin compiler and SHOULD NEVER CONTAIN REACHABLE
INFINITE LOOP since ist ran before the actual test starts to extract the return
value that is then asserted for changes.

The `tests/TESTS.md` snippets double as the corpus for the AFL++ fuzzer, run it
with `./misc/fuzz.sh` (`--help` for the flags). It only compiles, never runs
the generated code. `gen-meta` imports whatever crashed into `fuzz/crashes/`
and turns each one into a test.

Another category of tests we have are `test-programs`, that can be ran with
`./misc/run-programs.sh`, the scripts asserts that exit codes and stdout/err
are identical in programs compiled with each compiler.

When running tests, NEVER wait for more the 20 seconds, tests usually compile in
1s and run in matter of miliseconds.

NEVER comment the code with what it does, only why we absolutely need it if its
handling an edgecase that is unclear.

The peephole optimizations can be found with `peep :: proc`.

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

Its preffered to use static tables over big swich statements that just select a
value if that saves code. Of course if the table would be prohibitively big,
compared to what entryes are actualy populated dont do this.

DONT try to obtain registers/local/slot in the instruction encoding stage
(emit_functions/emit_instr). If you need temporaries, lower the node into
multiple in a target specific peephole and, if required, add new instructions
to the target. I dont want to see any hacks like spilling random register to
stack or adding a wasm local, only exception is mem2mem split and that is rare
case, no instructions should quarantee spills.

DONT keep tests in the repo unless instructed otherwise, you can write tests as
a intermediary step in sloving something but dont keep them, unless instructed
to write tests.

Its better wo write constants as hex in tests if it makes it more obvious what
is happening.

When hardcoding instructions encodings, it is adamant that you add a comment
with the parametrized assembly to make it clear what is being encoded.

When you declare local functions put them at the end of the scope or after they
are used.

Debug with gdb when appropriate, eg segfaults.
