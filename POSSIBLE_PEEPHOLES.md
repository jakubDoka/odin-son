# Missed peephole opportunities

Analysis of the JIT-generated object file for `test-programs/lua/main.odin`
(disassembled with `objdump -d -M intel`). Each finding was cross-checked
against the existing peepholes (`_peep :: proc` in `backend/x64.odin`,
`backend/builder.odin`, `backend/graph.odin`) to make sure it is genuinely
*missed* and semantically safe.

Counts below are for the single `lua` object file (~5000 disassembled
instructions); the same patterns show up in the other test programs too.

Findings are ordered by rough impact (frequency × waste per site).

---

## 1. Every integer constant is materialized with a 10-byte `movabs`

**Pattern:** a `CInt` is always emitted as `REX.W + B8 + imm64`, regardless of
the constant's magnitude. Constants that fit in 32 bits should use
`mov r32, imm32` (5 bytes, implicit zero-extend), and zero should use
`xor r32, r32` (2–3 bytes).

By far the most common waste in the whole file: **418** `movabs`
instructions, of which **415** hold a value that fits in an unsigned 32-bit
immediate, and **48** are exactly `movabs reg, 0x0`.

**Actual (from `dump_tokens`, and literally everywhere):**
```
movabs rsi,0x2            ; 48 be 02 00 00 00 00 00 00 00   (10 bytes)
...
movabs rax,0x0            ; 48 b8 00 00 00 00 00 00 00 00   (10 bytes)
...
movabs rax,0x1            ; 48 b8 01 00 00 00 00 00 00 00   (10 bytes)
```
(e.g. `is_alnum` at 0x2f7 / 0x306, the call-arg length constants throughout
`dump_tokens`, the boolean 0/1 results returned by every predicate.)

**Ideal:**
```
mov  esi,0x2              ; be 02 00 00 00                  (5 bytes)
...
xor  eax,eax             ; 31 c0                           (2 bytes)
...
mov  eax,0x1              ; b8 01 00 00 00                  (5 bytes)
```

**Why it is safe:** `mov r32, imm32` zero-extends into the full 64-bit
register, so it is bit-identical to a `movabs` of any value in `0 .. 2^32-1`.
`xor r32, r32` produces `0` (it does clobber flags — safe here because the
constant materialization is a standalone def whose flags are never consumed;
if a flag-live case ever occurs, fall back to `mov r32,0`). For negative
values that fit in `i32`, `mov r/m64, imm32` (`C7 /0`, sign-extending, 7
bytes) is still shorter than 10.

**Where to fix:** `backend/x64.odin`, the `.CInt` case of the emitter
(around line 1393):
```odin
case .CInt:
    dst := reg_of(ctx, instr)
    imm := graph_extra(ctx, node, CInt).value
    emit_single_op(ctx.code, 0xb8, dst)   // always REX.W movabs + 8 bytes
    emit_anys(ctx.code, imm)
```
Branch on `imm`: `0` → `xor`; `imm == i64(u32(imm))` → `B8+imm32` (no REX.W);
`imm == i64(i32(imm))` → `C7 /0 imm32`; else keep the `movabs`.

---

## 2. Redundant base-register copy before a memory access

**Pattern:** a value already living in a callee-saved / arg register is copied
into a scratch register purely to be used as the base of a load, when the
memory operand could name the original register directly.

The clearly-safe form `mov D, S` immediately followed by `mov D, [D+disp]`
(the load overwrites `D`, so the copy's result is dead) occurs **39** times;
the broader "copy then use as memory base" shape occurs **~210** times.

**Actual (`lex_all`, the hot lexer loop, 0x376 and 0x38e):**
```
mov  rax,r13
mov  rax,QWORD PTR [rax+0x10]      ; load lexer.pos, base r13 copied first
...
mov  rcx,r13
add  rax,QWORD PTR [rcx+0x10]      ; same base r13 copied into rcx
```
`r13` holds the `lexer` pointer for the whole loop and is read again right
after, so it is plainly still live.

**Ideal:**
```
mov  rax,QWORD PTR [r13+0x10]
...
add  rax,QWORD PTR [r13+0x10]
```

**Why it is safe:** in the `mov D,S; mov D,[D+disp]` case `D` is fully
redefined by the load, so its copied value has no other use; substituting `S`
for `D` in the base and deleting the copy is a straight copy-propagation. `S`
is provably unmodified between the two instructions (the copy is the only
thing in between).

**Where to fix:** these copies are the leftover `.Split` nodes that the
register coalescer (`backend/regalloc.odin` ~line 615, the coalescing loop —
note the "should be improved" TODO at ~759) could not merge because of
interference. Two options: (a) strengthen coalescing so a `.Split` whose
source is still live but whose destination is only consumed by a
memory-operand base is folded into that operand; or (b) add a post-regalloc
copy-propagation peep (natural home: `x64_post_schedule_peep` in
`backend/x64.odin`) that rewrites `mov D,S` + `[D+disp]` use → `[S+disp]` when
`D` is otherwise dead.

---

## 3. Redundant copy before a byte comparison (`mov rax,r15; cmp al, imm`)

**Pattern:** a byte in a register is copied to `rax`/`rcx` just so the compare
can address it as `al`/`cl`, even though `cmp` does not modify its operands
and the low byte of the source register is directly addressable.

Occurs **58** times, and clusters heavily in the `lex_all` character-dispatch
chain where the current char (`r15`) is re-copied before every single
comparison.

**Actual (`lex_all`, 0x39c … 0x4b0, one per candidate char):**
```
mov  rax,r15
cmp  al,0x20            ; 40 80 f8 20
...
mov  rax,r15
cmp  al,0x9
...
mov  rax,r15
cmp  al,0xd
...
mov  rcx,r15
cmp  cl,0x7e
```

**Ideal:**
```
cmp  r15b,0x20         ; 41 80 ff 20
cmp  r15b,0x9
cmp  r15b,0xd
cmp  r15b,0x7e
```

**Why it is safe:** `r15` is unchanged by `cmp`, and the scratch (`rax`/`rcx`)
is overwritten by the next `mov r,r15` on the following comparison, so its
value is dead. Comparing `r15b` directly is bit-identical. Saves the 3-byte
copy at each of the 58 sites.

**Where to fix:** same class as finding 2 (copy propagation into an operand).
A `x64_post_schedule_peep` rule: `mov D,S` followed by a `cmp`/`test` reading
`D` (or `Dlow`) with `D` dead afterwards → replace `D` with `S` and drop the
copy.

---

## 4. `mov`+`add` that should be a single `lea`

**Pattern:** `mov D, S; add D, X` where `S` must be preserved (so the add
cannot be done in place) is exactly `lea D, [S + X]`. This shows up for both
immediate (`+disp`, **21** sites) and register (`+index`, **30** sites)
addends.

**Actual (`lex_all`, 0x369; `S`=`r13` is live afterwards):**
```
mov  rax,r13
add  rax,0x20
mov  r14,rax            ; r14 = r13 + 0x20, r13 still needed
```
and the two-register form (`print_slice`, 0x7b):
```
mov  rax,r13
add  rax,rbx           ; rax = r13 + rbx (both live)
mov  rcx,rbp
add  rcx,rax           ; rcx = rbp + rax
```

**Ideal:**
```
lea  r14,[r13+0x20]
...
lea  rax,[r13+rbx]
lea  rcx,[rbp+rax]
```

**Why it is safe:** `lea` computes the address arithmetic without touching
flags or memory; whenever the two-operand `add` was forced to copy first
(because the destination differs from the source and the source stays live),
the three-operand `lea` is a strict win. The one caveat is that `lea` does
*not* set flags, so this only applies when the `add`'s flags are unused (true
for all address-math sites here).

**Where to fix:** the existing `indexify` block in `x64_peep`
(`backend/x64.odin` lines 419–466) already forms `lea` for `base + index*scale`,
but it deliberately bails when `ascale == 1 && !stack_base && offset == 0`
(line 454) and never handles the `base + imm` (disp-only) case. Those bail-out
conditions are correct *pre*-regalloc (a plain `add` is better when it can be
in place), so the right place is a *post*-regalloc peep that only converts to
`lea` once it is known the `add` needed a copy (destination ≠ lhs, lhs still
live).

---

## 5. `cmp reg, 0x0` should be `test reg, reg`

**Pattern:** comparing a 64-bit register against the immediate `0` is emitted
as `cmp r/m64, imm32` (`48 81 /7`, 7 bytes) instead of `test r,r`
(`48 85`, 3 bytes). At least **8** sites, several of which also carry a
foldable preceding copy (finding 2/3).

**Actual (`print_int`, 0xf85; and `parse_subexpr`/`parse_chunk` after a call):**
```
mov  rax,rbx
cmp  rax,0x0           ; 48 81 f8 00 00 00 00
...
cmp  rax,0x0           ; right after a call returning in rax
```

**Ideal:**
```
test rbx,rbx           ; (also drops the copy)
...
test rax,rax
```

**Why it is safe:** `test r,r` sets ZF/SF/PF identically to `cmp r,0` for the
subsequent `sete`/`jz`/`jnz`, and it is shorter and does not need the copy.
CF/OF differ (both cleared by `test`, both defined-as-0 by `cmp r,0` too), so
even signed follow-ups are equivalent here.

**Where to fix:** `x64_peep` in `backend/x64.odin` — the comparison path where
`rhs_const` is a 0 immediate (the `Eq ..= .U_Ge` case around line 398). Emit a
`X64_Test` form instead of `cmp reg, 0`. The codegen already knows how to emit
`test` (see `dump_tokens` 0x178), so only the peephole selection is missing.

---

## 6. Boolean compare materialized (`setcc`/`movzx`/`test`) instead of fused branch

**Pattern:** a compare whose only consumer is a branch is materialized into a
0/1 value with `setcc` + `movzx`, then re-tested with `test`+`jcc`, instead of
branching directly off the compare's flags. The existing If-fusion
(`x64_peep` `.If` case and `x64_post_schedule_peep` `Eq..U_Ge`) handles the
direct `if (a == b)` shape, but misses the case where the frontend routed the
comparison result through a `!= 0` test.

**Actual (`lex_all`, 0x3d0 — this is `if (c == '-')`):**
```
mov  rax,r15
cmp  al,0x2d
sete bl
movzx rbx,bl
test rbx,rbx
jne  3ed
jmp  44e
```

**Ideal:**
```
cmp  r15b,0x2d
jne  44e                ; (fall through to 3ed)
```
i.e. the `setcc`/`movzx`/`test` trio (5 instructions) collapses to nothing,
plus the copy from finding 3.

**Why it is safe:** `bl`/`rbx` is used only by the immediately following
`test`, so the boolean has no other consumer; branching on the flags produced
by `cmp` directly is equivalent. Related sub-case: in the OR-chains
(`dump_tokens` 0x14c–0x178, `(k==1)||(k==2)||(k==3)`) the `movzx rdx,dl` /
`movzx rax,al` that feed only `or cl, dl` / `or cl, al` are dead upper-bit
clears — only the *first* `movzx` (whose full register the final `test`
reads) is needed.

**Where to fix:** extend the compare→branch fusion in
`x64_post_schedule_peep` (`backend/x64.odin` ~line 688) to also fire when the
compare feeds an `Ne(x, 0)` / `Eq(x, 0)` that in turn feeds an `If`
(collapse the redundant `!= 0`), and drop a `movzx` whose only uses read the
low byte.

---

## Areas that are already tight

- Stack-slot spill traffic around calls looked reasonable — no obvious
  store-then-immediate-reload of the same slot was found.
- `base + index*scale + disp` address folding into a single load/store operand
  is working well (the `X64_Lea` / SIB path in `x64_peep` fires; e.g. the
  `[rsp+0xa0]` frame accesses and scaled indexing are single instructions).
- `movzx` on genuine byte loads from memory (`movzx eax, BYTE PTR [..]`) is
  correct and not redundant.
- The read-modify-write folding (`x64_peep` `.X64_Store` dest-mode path) is in
  place, so memory-destination arithmetic is already being formed.

The single highest-leverage fix by a wide margin is **finding 1** (constant
sizing): it is a localized change in one emitter case and removes ~4 KB of
dead instruction bytes across this one object file alone.
