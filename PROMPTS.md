### add missing integer ops (DONE)

The current code has all the parts designed to add more integer ops into it.
The extension should be simple enough but ist tedious to add them all. Your
task is to:

1. Add a test that goes trough all supported integer operators in odin and
   tests that thay have correct results. (don't forget to regenerate the tests)
2. Add the node kinds to the ideal nodes to suport thes ops in the backend.
3. Fix errors produced by the odin compiler when trying to run tests.
4. Add the emission code to the main.odin so that the new test gets properly
   typechecked and nodes get emitted.
5. Fix bugs until the test passes.

Don't worry about duplicating code, just keep the patterns already established
by the current code. we will compress this later on. Some of these ops will
emit floating point ops, or even vector ops in the future, this will depend on
the `Node_Datatype` so dont generate names specific to the integer variant but
right now we only care about the `int` variant of the instructions.

If you are uncertain about something, please ask questions. Otherwise just
execute the steps.

### add missing unsigned integer ops (DONE)

The datatype of a node does not express signedness, to fix this we should add a
`U_x` variants of ops that differ when unsigned. Otherwise the steps are the same.

Note that you need to modify the `tok_to_binop` to account for the type of the
operations. Also make sure to add a new test for unsigned ops. The current ops
test is fine, but we need a complementary test that verifyes the signed
integers are handled correctly.

### add X64 versions of .And, .Or, .Xor (DONE)

Thus far we have the X64_Add and X64_Sub, the pattern is established and now its just a boilerplate to add the remining nodes, so do that.

### extend tests for .X64_And, .X64_Or, .X64_Xor (DONE)

The tests that we have right now dont really cover all of the configurations of
these ops. This includes `op [addr], $imm`, `op [addr], reg`, `op reg, $imm`,
the ops with store then firther branch on the operand size. Please add tests
and verify they emit these instructions.

### add more tests to expose bugs in backend (DONE)

Right now there is a wider range of things that we already support and I am not
confident they are tested properly. Try to add more tests to cover gaps in the
current tests and, better yet, try to find tests that expose bugs. If the test
is breaking in the frontend because something is not implemented yet, don't
include that test. But otherwise if frontend crashes on unexpected assert/ioob
etcetera.

### rewiew the codebase and look for bugs, then write tests that reproduce them (DONE)

You should spinn up agents that will search for bugs by randomly reviewing
code, each agent should upon finding a bug, make a test that reproduces it,
verifyes it in deed does, the test should be named universaly uniuely during
verification, once bug is verified, agent should stop and give you the test,
you will then clean up the test name and add it to the test list. If an agent
generates invalid odin code, it should immediately remove it as it can block
others.

### Implement arrays in the frontend code (DONE)

The frontend, as of right now is only handling structs, ints, and basic pointer
types. I have added a example that should force implementing at lease a part to
the frontend implementation for the array handling. Make sure the test passes
(#### basic arrays). You should follow the patterns already established by the
existing code. I dont thing there are any backend changes required, if so, stop
and let me know.

### Implemment missing peephole discovery related to index/scale params (DONE)

The was just extended with better sib byte utilizations, but not all codepahts
are implemented yet. I added asserts in places that if reached will signal
unhandled index/scale code. All of the important code is located in the
`backend/x64`.

1. Spinn up the agent that will find all the important places that will need
   modifications.
2. Spinn up an agent that will, given the interesting areas, generate tests
   that will reach these asserts (bigger tests are preferrable that cover
   multiple asserts).
3. Fix the asserts and make sure the emitted code is correct.

This will not require running agents in parallel, Its just to save context for
implementing the actual thing.

### Implement slices in the frontend code (DONE)

We recently implemented array types, lets proceed with implementing slices.
There is a test to exscercise them (#### basic slices). The `backend` package
should remain unchanged. Follow the patterns already established, only
`main.odin` and `typecheck.odin` should require modifications.

### Finish the implementation of globals (DONE)

Spinn up an agent for each part

#### Part 1

I have added (in the last commit) some setup for global variables. I want this
to be tested with strings (#### basic strings). You should implement the
frontend to pass the test.

You likely don't need to change the backend unless something fundamental is
missing or there is a bug. Otherwise just finish implementing the frontend
part. Note that global variable management is not in place and the compiled
code needs to be marked for execution so you probably should copy the globals
into the code arena aligned to the next page boundary. And do relocations from
there.

The backend emits relocations that you should juts use, good to note that the
global id is arbitrary and it would be good if its a index into linear table
but that is a frontend concern.


#### Part 2

Now that we have strings and globals, add a test that will use mutable globals,
use `@(static)` so that this works in the test suite. THIS DOES NOT INCLUDE
`::` constants, these have completely different semantics.

Also write a test that will excercise the future global variable peepholes.
This is almost the same as specializing on stack allocations. I already added
facilities to emit this.

#### Part 3

Implement the global variables in the frontend until the test passes. THIS DOES
NOT INCLUDE nested globals.

#### Part 4

Implement the appropriate peepholes for the x64 backend, the whole point is to
use the RIP directly in the CISC instructions, same way we do for
`.Local_Addr`.

### Make more complicated tests (DONE)

The tests we have are great and all but we need more complicated ones. Could
you please write a JSON validator, make sure it works in odin as expected.
(Make a test in the `main.odin`). If you need some simple frontend features
like character literals, implement them. Then proceed with porting the code to
be a valid test case. If you find bugs in the compiler fix them.

### Prepare for memopt pass (DONE)

The point of the mem opt pass is to split locals into scalar parts and then do
a renaming into registers. Before we do that tho, I need a good set of tests
that will offer many opportunities to optimize that can not be optimized yet.
Create the tests based on whta is already supported in other tests, but use
structs since these are put on stack by the frontend. I will write the mem2reg
pass, just focus on adding good tests, if you encounter any bugs in the
process, fix them.

### Find bugs in the memopt pass (DONE)

The current tests for memopts are good, but I am not very confident about the
implementation. There appear to be some edgecases I had to deal with and I feel
like I did not structure the code correctly. Could you please review
`backend/mem2reg.odin` and look for bugs? Try to create tests that reporduce
them. For each bug you are suspecting, spawn an agent to make thetest for it.
Once you thing you can't find anymore. Once that is done, spawn an agent to fix
the bugs, only one agent though because multiple would stop over each other.

### Implementing more complicated tests (DONE)

NOTE: read AGENST.md

Could you spawn an agent that implements a zero initialized statics of any
type? Don't waste your context just pass this to him.

After the agent is done, read the TESTS.md and add a test that implements a
custom allocator based on free lists that can accept a buffer and allocate
bytes based on a size and alighment returning slice of bytes, it should also
try to coalesce free slots. Then make a few allocations. Write to them, read
from them, free some, read write and so on, just to test it works. While you
are implementing this, also spawn an agent whenever you need some feature on
the frontend that is not implemented yet, same way as described above. You
should first develop the allocator in a separate module and then port it to a
test once it works. If you find any bugs in the backend, let an agent fix it.
Once the test is implemented and it passes, stop.
