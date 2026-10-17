`arna` and `bit_arr` were migrated from
[gam](https://github.com/jakubDoka/gam)'s `util` packages. Their source is
governed by the [Mozilla Public License 2.0](https://mozilla.org/MPL/2.0/).

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
