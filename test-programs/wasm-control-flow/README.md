# Generated control-flow programs

The program runner generates 512 bounded control-flow cases in
`.tmp/build/generated/wasm-control-flow/`, using `main.odin` as their template.
Each case is a separate subtest in the runner's program array and uses the same
reference-build/JIT-build/execute/compare loop as other test programs.

Run the corpus:

```sh
odin run script -- run-programs wasm-control-flow
```

Run one seed:

```sh
odin run script -- run-programs wasm-control-flow/117
```

`STRESS_START` and `STRESS_COUNT` select a seed range (defaults: 0 and 512).
The original seed streams are preserved. Seeds 117, 501, and 508 previously
exposed register-allocation failures; other targets/optimization levels also
have known compiler failures, so a failing run is not necessarily a runner bug.

The template prints the full checksum so exit-code truncation cannot hide
incorrect results. The reference result is also checked against the generator's
independent interpreter. The program runner currently executes the native JIT
target; the Wasm backend's focused regressions remain in `tests/TESTS.md`.
