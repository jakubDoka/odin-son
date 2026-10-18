`arna` and `bit_arr` were migrated from
[gam](https://github.com/jakubDoka/gam)'s `util` packages. Their source is
governed by the [Mozilla Public License 2.0](https://mozilla.org/MPL/2.0/).

`arna.scrath(&temps)` and `arna.scrath(&temps, output_allocator)` use an
explicit `arna.Temps`; the latter avoids the arena used by the output allocator.
Both restore the arena position at scope exit. `arna.scrath(&temps, &arena)`
scopes an existing arena. Initialize temps from two buffers or with
`arna.init_scratch(&temps, size)` / `arna.deinit_scratch(&temps)`.

Pass temps to `bac/ssa.start_proc(&prc, &arena, &temps)`; they must outlive the
procedure and must not be used concurrently. The frontend can still use the
thread-local `arna.scratch` and the original scratch overloads. Set
`-define:ARNA_DISABLE_THREAD_LOCAL=true` to omit them. Together with
`-define:NO_FMT=true`, this also removes backend formatting TLS from the library.
C callers pass `arna_Temps *` to `bac_start_proc`; Rust callers pass
`&mut Temps` to `Proc::new` instead of installing global scratch arenas.

`fmt` provides the backend's formatting API. With `-define:NO_FMT=true`, output
is discarded, formatted panics trap, and enabled formatted assertions trap on
failure. The stubs accept up to five values without boxing them into `any`.
`-disable-assert` disables the assertions, including argument evaluation.
Graph display and node-spec reflection metadata are also disabled. Code
generators and the frontend may still use `core:fmt` directly.

```sh
odin build bac/bindgen/lib/ -build-mode:lib -out:bac/bindgen/lib/lib.a \
  -disable-assert -no-bounds-check -no-type-assert -define:NO_FMT=true -o:size
```

Tests for the formatting stubs and metadata configuration live in `utils/fmt`
and `tests/no_fmt`; run them with both values of `-define:NO_FMT` and with
`-disable-assert`.
