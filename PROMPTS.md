### add missing integer ops

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
