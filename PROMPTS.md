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

### Implement missing call configurations (DONE)

The current frontend is imssing implementation for multi value returns. We are implementing the odin cc that has following rules:

```odin
//* Large parameters (> 16 bytes) will be implicitly passed by pointer
//* Multiple return values are handled as the following
//  * If all of the return value can be passed in a register if they were
//  treated as a struct, they will
//  * If they cannot, then the values are treated separately with everything
//  but the last value being passed by pointer after the input parameters
//    * The end value is then treated as the "normal" return value according to
//    the calling conventioN
// * The `context` pointer is then the last parameter to the procedure
// arguments
```

We dont support the multiple values yet and also dont support the last value
beinge returned by stack. Note that the last value, if passed as stack, will be
stored int the first argument (rdi) but other returns are stored into pointers
appednded at the end. Do not worry about the context parameter yet, this is out
of the scope right now.

First spawn an agent to make tests that exersize the multiple return value
scenareos.

The implementation it self will require patternmatching on the call when
assigning and declaring multiple values to preeptively resolve the unbalanced
dest and src count.

This also means the typecheck should mark scalar values that are returned by
pointer from the function as Referenced so that we don't store them as ssa
values.

Test must pass, if you find bugs in the backend while implementing this, fix
them with an agent and then continue implementing. Dont stop until the new
tests pass.

Alos not that return values will affect the argument, keep that in mind.

### Implement the cli for the jit compiler to compile multifile programs (DONE)

As of right now we can only test the single file tests. This is gread but I
need to be able to write more complex programs. I have tidied up the main
package so its prepared for the compiler cli implementation.

There are few things missing:
1. Module loader that can take a file and loads all of the reachable files into
   a array of files and on top of it an array of modules that subslice the file
   array. This is to allow later to refer to a file by an index but we don't
   need it immediately.
2. Once we have all of the files loaded, lets make a pass of typechecking on
   them. This will require modifying how we search for global declarations and
   also create a need for module values (not a runtime value but a compile time
   value, same way functions work).
3. Once we typechecked, we can start emiting code. This should be simple, just
   populate the emit params on all of the procs.
4. Emit a valid ELF file that can be compiled with `zig cc`. Separete the elf
   emission to a file as it can get involved. Emit elf relocations, we
   have a setup for `.rel` right now because compiler will write the addend
   into the relocation slot.

Before you implement anything, first create a project in a
`test-programs/module-imports` and add a simple code in there that will test
the path resolution and module symbol search so that we have something to test
against wile implementing the compiler cli. Also include global variables so
that the elf emission covers that.

Also make a bash script in misc that will loop trough all files in
`test-programs`, compile them with odin and with our compiler, run them and
compare exit codes and stdout/err and log a summary of that.

Use that bach script for testing while implementing the compiler.

Note that its better to avoid implementint new features into the frontend. The
scope of this is limmited to importing code and you should not worry about
importing package collections right now. The frontend as fo right now is pretty
limmited so it would not be usefull anyway.

If you have any questions, please ask them quickly, otherwise start
implementing.

### Implement functions for formatting integers and printing them (DONE)

Extend the `test-programs/module-imports` with a module that does basic integer
formatting and parsing. Also make functions for printing thems, you can only
use the linux syscalls tho because thats the only external code that you can
call. Compiler does not implement many features of odin, you can take a look
into TESTS.md to see whats suported. The parsing/fmt should support different
integer bases.

### Implement globals, not only @(static)s (DONE)

#### Part 1

As of right now we only support the @(static) annoteated global variables in
local scopes. But since we now can compile standalone files, this should be
testable. First extend the `test-programs/module-imports` with a global
variable usage, for now just zeroed. Then implement it in the compiler.

#### Part 2

We are missing much needed `main::Type` custom formatter, as of right now the
types when logged just give back a hex address. Implement this and also a test
that checks that it works.

### Implement a lua lexer and parser (DONE)

Make a `test-programs/lua` taht will have lexer/parser implementation for lua
syntax. Note that you can import code from other tests.

Make a list of lua test code hardcoded in strings that will be lexed and
parsed. Then delcare all of the types and api functions from each component.
This also includes an arena allocator (BUT DONT IMPLEMENT THE STANDARD ODIN
INTERFACE), use linux syscalls to allocate pages for the arena. The arena
should be growable, so account for that in the type definition.

Once you have the api, implement the initial test routeen that will be called
from main, and then start implementing the components (Arena, Lexer, Parser).
Distribute this work to agents if nescessary.

After thats done, spawn an agent to debug the code and make it work propery,
using only the odin compiler.

Once you are confident the parser works, (by pretty printing the AST). Start
testing with the JIT. If you find bugs in the backend or frontend spawn an
agent to fix it. Dont stop until the odin compiler and JIT are in observable
parity.

Once you are done, spawn an agent to analyze the objdump of the jitted binary
to look for possible missed peephole optimization opportunities and list them
in a POSSIBLE_PEEPHOLES showing example assembly and the ideal assembly.

### Implement the floating point numbers (DONE)

Right now the frontend and the backend only handle the integer ops. You should
implement the floating point ops.

#### Part 1

Generate the tests that will test the floating point op as exhausively as
integer ops. The point of the tests it to test spilling and peepholes so that
the compiler emits all of the possible instructions.

#### Part 2

Add the appropriate nodes to the `Ideal_Node_Type`, the floating point ops
should not share kinds with integer ops. Do a F_Op naming scheme here. Do not
add isa specific instructions (X64_*) yet. Make sure to specify all properties
of the new nodes and regenerate the spec. Also add the `.F32` and `.F64` to the
`Node_Datatype`. These datatypes should map to new `.Vector` `Reg_Kind`. This
will require filling in many things that require to cover specification for
each Reg_Kind.

Then proceed with implementing:
1. x64 encodings for the new ops
2. frontend support for floating point numbers

#### Part 3 (depends on 1,2)

The implementation is ready to be tests so fix bugs until tests pass.

### Implement terminal rendered boids (DONE)

We now have floating point number support. Lets implement a simple boid
simulation rendered into the terminal with ansi escape codes. By default the
symulation will run for 100 iterations without sleeping. But if terminal colors
can be used, (detect it with a syscall), then use colors and sleep (with a
syscall) in a loop indefinitely so I can visually verify it works. You should
put it into `test-programs/boids`.

If you find any bugs in the frontend or backend fix them, or there is a simple
frontend feature you need, implement it. Don't stopu until the test program has
identical ouput with odin and jit compiler.

### Add floating point peepholes (DONE)

We should add floating point peepholes that are similar to what we do with
integer ops. Do not add fma yet, just optimize the loads and stores into one
op. Also, the constants are stored in global memory and loaded with X64_CLoad,
make sure this also gets inlined into opts during the post schedule peeps.

Make sure all tests pass (run-test and ./misc/run-programs.sh), then stop.

### Add tests to veryfi correct comparison spills (DONE)

We dont test the cases when the comparison ops are not optimized into direct
cmp -> jmp. Make tests that tickle all of the comparison op x type and make
sure they work and dont fold away. Use functions to obfuscake operands and
results of the ops. If you find bugs fix them, until all tests pass and
compiler emmited all possible comparison flag spills.

### Add a raylib example program

NOTE: read AGENTS.md

Add a raylib example program, implement boids. This program should be in
`./examples/` and should ahve a bash script to build+run it. The point here is
to use the foreign blocks to bind to raylib manually, use system installed
raylib when linking.
