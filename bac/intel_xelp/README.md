# Intel Xe-LP backend

This backend emits SIMD8 kernels for scalar `f32`
addition, subtraction, multiplication, negation, and comparisons. Division
lowers to a target-specific reciprocal node followed by multiplication, so it
is approximate rather than correctly rounded. Comparisons return canonical
zero-or-one booleans when used as values, and allocated flag registers when
used by control flow. Instruction templates live in the `FLOAT_OPS` node-type
table, with register fields filled after allocation.

Control flow uses a flat table indexed by scheduled basic block, independently
of Wasm's `bac.Cfg_Blocks`. A forward pass recognizes simple diamonds for
`if`/`else`/`endif`, marks forward destinations for `goto`/`join`, and identifies
loop backedges and direct exits for `while`/`break`. A backward pass links the
reconvergence points without sorting or reordering blocks. Branch offsets are
patched after emission. Phi transfers execute under the active lane mask.

Arguments use `r1` through `r8`, and results use `r120` through `r127` before
being written to the output surface. Shader uniforms are packed into argument
registers; target-specific `Extract_Lane` nodes splat individual words.
Shared `Thread_Id` and `Lane_Id` nodes represent GPU builtins and are unreachable
in CPU backends. Xe-LP interprets them as walker X group ID and SIMD8 lane index.

The backend also supports 32-bit integer addition/subtraction, multiplication,
bitwise operations, shifts, unsigned comparisons/division/remainder, and scalar
integer/float conversions. Multiplication lowers to two word-source products;
division/remainder use integer math messages with explicit completion waits.

Uniform pointer loads remain 64-bit in SSA, then lower to two word splats.
Pointer addition/scaling is split into low/high arithmetic with carry. A64
32-bit scattered stores pack eight interleaved addresses into the contiguous
`r116:r117` payload pair, constrained before allocation and excluded from
ordinary GRF masks. Each send is followed by a scoreboard source-read wait so
the allocator can safely reuse both address and value registers. No temporaries
are allocated during encoding. Arbitrary memory loads, spills, general 64-bit
arithmetic, and non-32-bit stores remain unimplemented.

See [`examples/mandelbrot`](../../examples/mandelbrot/README.md) for a complete
shader and interactive runner.

The common allocation mask reserves `r112..r119` and `r121..r127` for the
native full-frame renderer; `r120` remains the single pixel result register.
For `main :: proc(f32, f32) -> f32`, TRUEOS can validate the complete kernel,
retain its arithmetic and relative branches, and replace the scalar-dispatch
header/store/EOT with its own SIMD8 grid-stride framebuffer envelope. Ordinary
eight-result scalar dispatch remains supported. The driver validates every
body register access before admitting it to the framebuffer path.

Regenerate its spec through `gen-spec`, or run `odin run bac/meta2` from the
repository root when `node_specs.odin` is absent. Check the package with:

```sh
odin check bac/intel_xelp -no-entry-point
```

## Encoding helpers

`Op` is an uncompressed 128-bit Xe-LP EU instruction, represented by four
`u32`s. `emit_op` writes it in little-endian order. These are field packers,
not an assembler or a complete instruction validator. They do not allocate
registers, choose instructions, or schedule dependencies.

The syntax below is IGA's Xe-LP syntax (`iga64 -p=12p1`). Snippets assume
they are inside this package and `code` is a `^arna.Allocator`.

### Instruction controls

| Helper/input | IGA spelling |
| --- | --- |
| `eu_control(.Mov, 8)` | `mov (8\|M0)` |
| `eu_control(.Add, 16)` | `add (16\|M0)` |
| `eu_control(.Send, 16)` | `send (16\|M0)`; select `.dc1`/`.ts` separately |
| `mask_offset = 8` | `M8` in `(lanes\|M8)` |
| `no_mask = true` | `(W)` before the mnemonic, e.g. `(W) mov (8\|M0)` |
| `swsb = eu_swsb_*()` | Dependency annotations inside `{...}` |

`lanes` is 1, 2, 4, 8, 16, or 32. `mask_offset` is a multiple of four from
0 to 28; the selected lanes must fit within 32 channels. `(W)` disables
execution-mask checking; it does not change the execution width or introduce
a flag predicate. `eu_predicate(flag, negate)` packs normal flag predication;
`eu_flag(flag)` selects the flag subregister for comparisons.

### Registers, regions, and types

An ordinary IGA destination is `rN.S<H>:type`; a source is
`rN.S<V;W,H>:type`. `N` is the register number, `S` the typed element index,
`H` the horizontal stride, `V` the vertical stride, and `W` the region width.
These strides are in elements, not bytes.

| Helper | Assembly part |
| --- | --- |
| `eu_subreg(S, dt)` | Convert `.S:type` to the byte offset used by the operand packers |
| `eu_dst(Reg(N), eu_subreg(S, dt), dt, H)` | Entire destination `rN.S<H>:type` |
| `eu_src(Reg(N), eu_subreg(S, dt), V, W, H)` | Source `rN.S<V;W,H>`, **without** its type or modifier |
| `eu_src0_type(dt)` / `eu_src1_type(dt)` | `:type` on the corresponding source |
| `eu_reg_number(Reg(N), file)` | Low-level extraction of the register number, without packing its file or position |
| `eu_stride(stride, limit)` | Low-level stride encoding; operand packers call it internally |

`file = .GRF` is the default and selects `rN`. `.ARF` selects the architectural
register file and requires its raw register encoding, not an IGA register
name. In particular, `Reg(0), .ARF` selects `null` for send operands.

For example, `eu_subreg(1, .UD)` is byte offset 4, while
`eu_subreg(1, .UW)` is byte offset 2. Each GRF contains 32 bytes. Source
region `<0;1,0>` broadcasts one element; `<8;8,1>` reads consecutive elements
in rows of eight. Destination `<1>` writes consecutive elements.

Pass the assembly's numeric strides and widths, not their binary encodings:

- Destination `H`: 1, 2, or 4; defaults to 1.
- Source `V`: 0, 1, 2, 4, 8, 16, or 32.
- Source `W`: 1, 2, 4, 8, or 16.
- Source `H`: 0, 1, 2, or 4.

`eu_stride` encodes 0 as 0 and positive strides as `1 + log2(stride)`.
Region widths and execution widths instead use `log2(width)`. The packers
check field ranges, not every instruction-specific regioning restriction.

| `Data_Type` | IGA suffix | Element size |
| --- | --- | --- |
| `.UB` / `.B` | `:ub` / `:b` (unsigned/signed integer) | 1 byte |
| `.UW` / `.W` | `:uw` / `:w` (unsigned/signed integer) | 2 bytes |
| `.UD` / `.D` | `:ud` / `:d` (unsigned/signed integer) | 4 bytes |
| `.HF` | `:hf` (floating point) | 2 bytes |
| `.F` | `:f` (floating point) | 4 bytes |

### Assembling an ALU instruction

Source types and modifiers are not stored alongside their register/region
fields, so OR each fragment into the word indicated here:

| Fields | Word |
| --- | --- |
| `eu_control` | 0 |
| `eu_dst`, `eu_src0_type`, `eu_src0_mod` | 1 |
| `EU_SRC0_IMMEDIATE`, `EU_SRC1_IMMEDIATE` | 1 |
| `eu_src` for source 0, `eu_src1_type` | 2 |
| `eu_src` for source 1, `eu_src1_mod`, or immediate bits | 3 |

```odin
// add (16|M0) r5.0<1>:ud r1.0<0;1,0>:ud r1.1<0;1,0>:ud
emit_op(code, {
	eu_control(.Add, 16),
	eu_dst(Reg(5), 0, .UD) | eu_src0_type(.UD),
	eu_src(Reg(1), 0, 0, 1, 0) | eu_src1_type(.UD),
	eu_src(Reg(1), eu_subreg(1, .UD), 0, 1, 0),
})
```

Both `eu_src0_mod(negate, absolute)` and `eu_src1_mod(negate, absolute)` use
these IGA prefixes, where supported by the instruction:

| `negate`, `absolute` | Prefix before the source register |
| --- | --- |
| `false, false` | None |
| `true, false` | `-` for arithmetic; `~` for bitwise operations |
| `false, true` | `(abs)` |
| `true, true` | `-(abs)` |

For example, OR `eu_src0_mod(true, true)` into word 1 to modify source 0 to
`-(abs)r1.0<0;1,0>:f`. Its register/region remains in word 2.

### Immediate operands

For the supported 32-bit immediate form, put the raw value in word 3 instead
of a source-register fragment. The type helper supplies the IGA suffix; the
immediate flag selects an immediate rather than a register operand.

```odin
// mov (1|M0) r4.2<1>:ud 0x3:ud
emit_op(code, {
	eu_control(.Mov, 1),
	eu_dst(Reg(4), eu_subreg(2, .UD), .UD) |
		eu_src0_type(.UD) | EU_SRC0_IMMEDIATE,
	0,
	0x3,
})
```

For a binary instruction whose **source 1** is immediate, OR
`EU_SRC1_IMMEDIATE` into **word 1**, keep `eu_src1_type(dt)` in word 2, and
put the value in word 3. Do not also pack source-1 register/region/modifier
bits there. Floating-point immediates require their bit representation, not
a numeric conversion to `u32`. Byte and packed-vector immediate forms are
not covered by this type interface.

### Dependency annotations

Pass the result of one of these helpers as `eu_control(..., swsb = value)`.
They encode annotations; the compiler must decide which dependencies exist.

| Helper | IGA option |
| --- | --- |
| `eu_swsb_regdist(1)` | `{@1}` |
| `eu_swsb_regdist(0)` | No dependency annotation |
| `eu_swsb_sbid(0, .Set)` | `{$0}`: allocate scoreboard token 0 |
| `eu_swsb_sbid(0, .Wait_Src)` | `{$0.src}`: wait until its source reads complete |
| `eu_swsb_sbid(0, .Wait_Dst)` | `{$0.dst}`: wait until its destination writes complete |
| `eu_swsb_combined(1, 0)` on `send` | `{@1,$0}` |

Register distances are 0 through 7; token IDs are 0 through 15. The combined
form requires a nonzero distance. Its token mode is implied by the instruction
class: allocation for `send`, destination wait for an applicable in-order
instruction (`{@1,$0.dst}`). It cannot select an independent source wait.

### Send messages

IGA's raw send form is:

```asm
send.sfid (lanes|Moffset) dst payload0 payload1 ex_desc desc {options}
```

Send operands have no ordinary ALU types or regions. Use these packers instead:

| Helper | IGA part | Word |
| --- | --- | --- |
| `eu_send_target(.DC1)` / `eu_send_target(.TS)` | `.dc1` / `.ts` suffix | 2 |
| `eu_send_dst(Reg(N))` | Destination `rN` | 1 |
| `eu_send_dst(Reg(0), .ARF)` | Destination `null` | 1 |
| `eu_send_dst(..., eot = true)` | Also adds `{EOT}` | 1 |
| `eu_send_src(Reg(N))` | Payload base register `rN` | 2 for payload 0; 3 for payload 1 |
| `eu_send_src(Reg(0), .ARF)` | Payload `null` | Same as above |
| `eu_send_ex_desc(ex_desc)` | First immediate after the payloads | Returns fragments for words 1, 2, 3 |
| `eu_send_desc(desc)` | Second immediate after the payloads | Returns fragments for words 1, 2, 3 |

The descriptor immediates are **logical descriptors**, not individual machine
words. Each descriptor helper scatters its input into three fragments; OR
those into the corresponding words. `eu_send_ex_desc` requires its input's
low six bits to be zero. EOT and SFID are separate fields, not part of these
logical descriptors.

`eu_message_desc(function_control, message_grfs, response_grfs, header)`
builds the logical `desc`: function control occupies bits 18:0, header-present
bit 19, response length bits 24:20, and message length bits 28:25. Lengths
are in 32-byte GRFs, not SIMD lanes or bytes; `header` defaults to false.

`eu_dc1_desc(message_type, control, binding_table_index, message_grfs, ...)`
specializes the function-control bits to DC1: message type in bits 18:14,
control in bits 13:8, and binding-table index in bits 7:0. It defaults to
zero response GRFs and a present header. The message type and control are
raw numeric fields; for example, type `0xa` is a media-block write.

```odin
// send.dc1 (16|M0) null r4 null 0x0 0x040A8000 {@1,$0}
desc := eu_dc1_desc(0xa, 0, 0, 2)
d1, d2, d3 := eu_send_desc(desc)
e1, e2, e3 := eu_send_ex_desc(0)
emit_op(code, {
	eu_control(.Send, 16, swsb = eu_swsb_combined(1, 0)),
	eu_send_dst(Reg(0), .ARF) | d1 | e1,
	eu_send_target(.DC1) | eu_send_src(Reg(4)) | d2 | e2,
	eu_send_src(Reg(0), .ARF) | d3 | e3,
})
```

This describes a two-GRF message starting at `r4`, with a header and no
response. Preparing the header/data in `r4`/`r5` is separate from encoding
the send instruction.

```odin
// send.ts (16|M0) null r112 null 0x10000000 0x02000010 {EOT,@1,$1}
d1, d2, d3 = eu_send_desc(eu_message_desc(0x10, 1, 0))
e1, e2, e3 = eu_send_ex_desc(0x10000000)
emit_op(code, {
	eu_control(.Send, 16, swsb = eu_swsb_combined(1, 1)),
	eu_send_dst(Reg(0), .ARF, eot = true) | d1 | e1,
	eu_send_target(.TS) | eu_send_src(Reg(112)) | d2 | e2,
	eu_send_src(Reg(0), .ARF) | d3 | e3,
})
```

### Scope

The current helpers cover direct-register one-/two-source ALU forms and raw
sends with immediate descriptors, flag predicates, and structured branches.
There are no packers yet for indirect
addressing, saturation, general condition modifiers,
three-source instructions, or compaction. An encodable field combination is
not necessarily a legal instruction; instruction selection and scheduling
must still respect Xe-LP's operation-specific restrictions.
