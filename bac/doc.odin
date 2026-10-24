/*
For a more convenient summary of the api, you can look into
bac/bindgen/c/bac.h, since it only shows the signatures although in c syntax.

You can find examples of the usage in the examples/bac/.

odinc/ in general is a good reference of using the backend for a real language
although it does not implement the whole Odin feature set.

Bac allows you to build, optimize and emit procedures. Most of the api is for
bilding the ssa IR. Functions that add operations are usually prefixed with
add_. The bac/ssa package also contains various state machines for emitting
common structured control flow and in general work with the ssa. To find all of
the functions intended to be used in the public api, grep for `@(tag = "api`.

The optimization passes are just functions that take required datastructures.
This makes it eazy to compose your own pass ordering. Note that passes are
cached and also need to be often times be enabled manually on the
Proc.opt_flags. You generally dont guard the passes by control flow, the passes
will be skipped internally so the usage code stays simple. Passes also return
wether they did something, which is usefull for detecting termination.

Library will not help you with packaging the compiled code, it only emits cross
format representation of the all the machine code related parameters, like
relocations, source code locations, constants, eccetra.

You can find and example of using the compilation output in odinc/elf.odin.
*/
package bac
