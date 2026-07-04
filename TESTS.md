# Tests

The file contains unit tests, this file is read by `odin run meta` and
turned into a unit test file. Hope you can infer what each test should look
like, making an example is too much for me.

#### simplest
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	return 69
}
```

#### basic arithmetic
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	return 1 + 2 * 3
}
```

#### all integer operators
```odin
package main

opt_level :: "none"

main :: proc() -> int {

	r := 0
	{
		a := 20
		b := 6
		n := 0 - 7

		r += a / b
		r += a % b
		r += n / b
		r += n % b
		r += a & b
		r += a | b
		r += a ~ b
		r += a &~ b
		r += a << 2
		r += a >> 2
		r += n >> 2

		if a > b do r += 1
		if b < a do r += 2
		if a >= b do r += 4
		if a <= b do r += 8
		if a == a do r += 16
		if a != b do r += 32
		if n < b do r += 64
	}

	{
		a: u8 = 20
		b: u8 = 6
		n: u8 = 7

		r += int(a / b)
		r += int(a % b)
		r += int(n / b)
		r += int(n % b)
		r += int(a & b)
		r += int(a | b)
		r += int(a ~ b)
		r += int(a &~ b)
		r += int(a << 2)
		r += int(a >> 2)
		r += int(n >> 2)

		if a > b do r += 1
		if b < a do r += 2
		if a >= b do r += 4
		if a <= b do r += 8
		if a == a do r += 16
		if a != b do r += 32
		if n < b do r += 64
	}

	{
		a: u16 = 20
		b: u16 = 6
		n: u16 = 7

		r += int(a / b)
		r += int(a % b)
		r += int(n / b)
		r += int(n % b)
		r += int(a & b)
		r += int(a | b)
		r += int(a ~ b)
		r += int(a &~ b)
		r += int(a << 2)
		r += int(a >> 2)
		r += int(n >> 2)

		if a > b do r += 1
		if b < a do r += 2
		if a >= b do r += 4
		if a <= b do r += 8
		if a == a do r += 16
		if a != b do r += 32
		if n < b do r += 64
	}

	{
		a: u32 = 20
		b: u32 = 6
		n: u32 = 7

		r += int(a / b)
		r += int(a % b)
		r += int(n / b)
		r += int(n % b)
		r += int(a & b)
		r += int(a | b)
		r += int(a ~ b)
		r += int(a &~ b)
		r += int(a << 2)
		r += int(a >> 2)
		r += int(n >> 2)

		if a > b do r += 1
		if b < a do r += 2
		if a >= b do r += 4
		if a <= b do r += 8
		if a == a do r += 16
		if a != b do r += 32
		if n < b do r += 64
	}

	{
		a: i8 = 20
		b: i8 = 6
		n: i8 = 0 - 7

		r += int(a / b)
		r += int(a % b)
		r += int(n / b)
		r += int(n % b)
		r += int(a & b)
		r += int(a | b)
		r += int(a ~ b)
		r += int(a &~ b)
		r += int(a << 2)
		r += int(a >> 2)
		r += int(n >> 2)

		if a > b do r += 1
		if b < a do r += 2
		if a >= b do r += 4
		if a <= b do r += 8
		if a == a do r += 16
		if a != b do r += 32
		if n < b do r += 64
	}

	{
		a: i16 = 20
		b: i16 = 6
		n: i16 = 0 - 7

		r += int(a / b)
		r += int(a % b)
		r += int(n / b)
		r += int(n % b)
		r += int(a & b)
		r += int(a | b)
		r += int(a ~ b)
		r += int(a &~ b)
		r += int(a << 2)
		r += int(a >> 2)
		r += int(n >> 2)

		if a > b do r += 1
		if b < a do r += 2
		if a >= b do r += 4
		if a <= b do r += 8
		if a == a do r += 16
		if a != b do r += 32
		if n < b do r += 64
	}

	{
		a: i32 = 20
		b: i32 = 6
		n: i32 = 0 - 7

		r += int(a / b)
		r += int(a % b)
		r += int(n / b)
		r += int(n % b)
		r += int(a & b)
		r += int(a | b)
		r += int(a ~ b)
		r += int(a &~ b)
		r += int(a << 2)
		r += int(a >> 2)
		r += int(n >> 2)

		if a > b do r += 1
		if b < a do r += 2
		if a >= b do r += 4
		if a <= b do r += 8
		if a == a do r += 16
		if a != b do r += 32
		if n < b do r += 64
	}

	return r
}
```

#### all unsigned integer operators
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	a: uint = 20
	b: uint = 6
	n: uint = 0
	n -= 7 // huge unsigned value (2^64 - 7)

	r := 0

	if a / b == 3 do r += 1
	if a % b == 2 do r += 2
	if n / b > a do r += 4
	if n % b == 3 do r += 8
	if n >> 60 == 15 do r += 16
	if a >> 2 == 5 do r += 32
	if n > b do r += 64
	if n >= a do r += 128
	if b < n do r += 256
	if b <= n do r += 512
	if a < n do r += 1024

	return r
}
```

#### all signed integer operators
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	a := 20
	b := 0 - 6
	c := 0 - 7

	r := 0

	r += a / b
	r += a % b
	r += c / b
	r += c % b

	r += c >> 1
	r += b >> 1

	if b < a  do r += 1
	if c < b  do r += 2
	if a > b  do r += 4
	if b <= c do r += 8
	if a >= b do r += 16

	return r
}
```

#### bitwise ops with constants
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	a := opaqe(12)

	r := opaqe(0)

	r += a & 10
	r += a | 3 
	r += a ~ 6 

	return r
}

opaqe :: proc(i: int) -> int {
	return i
}
```

#### bitwise ops through pointers
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	a := 12
	ptr := &a
	ptr^ = ptr^ & 10

	b := 10
	c := 6

	or_into(&b, 5)
	xor_into(&c, 3)

	return a + b + c
}

or_into :: proc(ptr: ^int, v: int) -> int {
	ptr^ = ptr^ | v
	return ptr^
}

xor_into :: proc(ptr: ^int, v: int) -> int {
	ptr^ = ptr^ ~ v
	return ptr^
}
```

#### bitwise ops sized through pointers
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	a8: i8 = 12
	a16: i16 = 12
	a32: i32 = 13

	pa8 := &a8
	pa16 := &a16
	pa32 := &a32

	pa8^ = pa8^ & 10
	pa16^ = pa16^ | 3
	pa32^ = pa32^ ~ 6

	b8: i8 = 10
	b16: i16 = 15
	b32: i32 = 11

	or8(&b8, 5)
	xor16(&b16, 6)
	and32(&b32, 6)

	return int(a8) + int(a16) + int(a32) + int(b8) + int(b16) + int(b32)
}

or8 :: proc(ptr: ^i8, v: i8) -> i8 {
	ptr^ = ptr^ | v
	return ptr^
}

xor16 :: proc(ptr: ^i16, v: i16) -> i16 {
	ptr^ = ptr^ ~ v
	return ptr^
}

and32 :: proc(ptr: ^i32, v: i32) -> i32 {
	ptr^ = ptr^ & v
	return ptr^
}
```

#### simple 2 adress self conflict
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	return 2 + 2 * 2
}
```

#### more complex 2 adress self conflict
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	return 2 + 2 * 2 + 2 * 2 + 2 * 2 + 2 * 2
}
```

#### force spill with simple addition
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	return ((((1 + 1) + (1 + 1)) + ((1 + 1) + (1 + 1))) +
        (((1 + 1) + (1 + 1)) + ((1 + 1) + (1 + 1)))) +
        ((((1 + 1) + (1 + 1)) + ((1 + 1) + (1 + 1))) +
        (((1 + 1) + (1 + 1)) + ((1 + 1) + (1 + 1))))
}
```

#### simple varialbes
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	a := 2
	b, c := 7, 3 * a
	return b * c
}
```

#### variables that create register pressure
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	x := 0

	a0  := x + 1
	a1  := x + 2
	a2  := x + 3
	a3  := x + 4
	a4  := x + 5
	a5  := x + 6
	a6  := x + 7
	a7  := x + 8
	a8  := x + 9
	a9  := x + 10
	a10 := x + 11
	a11 := x + 12
	a12 := x + 13
	a13 := x + 14
	a14 := x + 15
	a15 := x + 16

	b0 := a0  * a15 + a1
	b1 := a1  * a14 + a2
	b2 := a2  * a13 + a3
	b3 := a3  * a12 + a4
	b4 := a4  * a11 + a5
	b5 := a5  * a10 + a6
	b6 := a6  * a9  + a7
	b7 := a7  * a8  + a0

	c0 := b0 * b4 + b1
	c1 := b1 * b5 + b2
	c2 := b2 * b6 + b3
	c3 := b3 * b7 + b0

	d0 := c0 * c2 + c1
	d1 := c1 * c3 + c2

	e0 := d0 * d1 + c3

	return e0 +
		a0 + a1 + a2 + a3 +
		a4 + a5 + a6 + a7 +
		a8 + a9 + a10 + a11 +
		a12 + a13 + a14 + a15
}
```

#### variables that create even more register pressure
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	x := 0
	a0  := x + 1
	a1  := x + 2
	a2  := x + 3
	a3  := x + 4
	a4  := x + 5
	a5  := x + 6
	a6  := x + 7
	a7  := x + 8
	a8  := x + 9
	a9  := x + 10
	a10 := x + 11
	a11 := x + 12
	a12 := x + 13
	a13 := x + 14
	a14 := x + 15
	a15 := x + 16
	a16 := x + 17
	a17 := x + 18
	a18 := x + 19
	a19 := x + 20

	b0 := a0*a10 + a19
	b1 := a1*a11 + a18
	b2 := a2*a12 + a17
	b3 := a3*a13 + a16
	b4 := a4*a14 + a15
	b5 := a5*a15 + a14
	b6 := a6*a16 + a13
	b7 := a7*a17 + a12
	b8 := a8*a18 + a11
	b9 := a9*a19 + a10

	c0 := b0*b5 + a0 + a19
	c1 := b1*b6 + a1 + a18
	c2 := b2*b7 + a2 + a17
	c3 := b3*b8 + a3 + a16
	c4 := b4*b9 + a4 + a15

	return (
		a0+a1+a2+a3+a4+a5+a6+a7+a8+a9+
		a10+a11+a12+a13+a14+a15+a16+a17+a18+a19+
		b0+b1+b2+b3+b4+b5+b6+b7+b8+b9+
		c0+c1+c2+c3+c4\
	)
}
```

#### simple if statement
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	a := 0
	if a == 0 {
		a = 100
	} else {
		a = 2
	}
	return a
}
```

#### if statement with register pressure
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	x := 0
	a0  := x + 1
	a1  := x + 2
	a2  := x + 3
	a3  := x + 4
	a4  := x + 5
	a5  := x + 6
	a6  := x + 7
	a7  := x + 8
	a8  := x + 9
	a9  := x + 10
	a10 := x + 11
	a11 := x + 12
	a12 := x + 13
	a13 := x + 14
	a14 := x + 15
	a15 := x + 16

	b0 := a0*a8  + a15
	b1 := a1*a9  + a14
	b2 := a2*a10 + a13
	b3 := a3*a11 + a12
	b4 := a4*a12 + a11
	b5 := a5*a13 + a10
	b6 := a6*a14 + a9
	b7 := a7*a15 + a8

	c0 := b0 + b4
	c1 := b1 + b5
	c2 := b2 + b6
	c3 := b3 + b7

	d0 := c0
	d1 := c1
	d2 := c2
	d3 := c3

	if x == x {
		d0 = d0*a0 + a15
		d1 = d1*a1 + a14
		d2 = d2*a2 + a13
		d3 = d3*a3 + a12
	}

	e0 := d0*d1 + b0 + b1
	e1 := d2*d3 + b2 + b3
	e2 := d0*d2 + b4 + b5
	e3 := d1*d3 + b6 + b7

	f0 := e0
	f1 := e1
	f2 := e2
	f3 := e3

	if a0 == a0 {
		f0 = f0*a4 + a11
		f1 = f1*a5 + a10
		f2 = f2*a6 + a9
		f3 = f3*a7 + a8
	}

	return a0+a1+a2+a3+a4+a5+a6+a7+
		a8+a9+a10+a11+a12+a13+a14+a15+
		b0+b1+b2+b3+b4+b5+b6+b7+
		c0+c1+c2+c3+
		d0+d1+d2+d3+
		e0+e1+e2+e3+
		f0+f1+f2+f3
}
```

#### if statement peepholes
```odin
package main

opt_level :: "none"

opaques :: proc(x: int) -> int {
	return x
}

test_signed :: proc(a: int, b: int) -> int {
	if a == b do return 1
	if a != b do return 2

	if a < b do return 3
	if a >= b do return 4

	if a > b do return 5
	if a <= b do return 6

	return 0
}

test_unsigned :: proc(a: uint, b: uint) -> uint {
	if a == b do return 10
	if a != b do return 20

	if a < b do return 30
	if a >= b do return 40

	if a > b do return 50
	if a <= b do return 60

	return 0
}

test_mixed_patterns :: proc(x: int) -> int {
	a := opaques(x)
	b := opaques(x + 1)

	if a < b {
		if a <= b {
			if a != b {
				return 100
			}
		}
	}

	if a > b {
		if a >= b {
			if a == b {
				return 200
			}
		}
	}

	return 0
}

main :: proc() -> int {
	r := 0

	r += test_signed(10, 20)
	r += test_signed(20, 20)
	r += test_signed(30, 10)

	r += int(test_unsigned(10, 20))
	r += int(test_unsigned(20, 20))
	r += int(test_unsigned(30, 10))

	r += test_mixed_patterns(42)

	return r
}
```

#### different shift peeps
```odin
package main

opt_level :: "none"

test_imm_shifts :: proc(a: int) -> int {
	return a << 3 + a >> 3 + int(u64(a) >> 5)
}

test_imm_inplace_shifts :: proc(a: ^int, b: ^uint) -> int {
	a^ = a^ << 2
	a^ = a^ >> 5
	b^ = b^ >> 4
	return a^ + int(b^)
}

test_inplace_shifts :: proc(a: ^int, b: ^uint, v: uint) -> int {
	a^ = a^ << v
	a^ = a^ >> v
	b^ = b^ >> v
	return a^ + int(b^)
}

main :: proc() -> int {
	a: int = 0 - 5
	b: uint = 20

	return test_imm_shifts(0 - 1) +
		test_imm_inplace_shifts(&a, &b) +
		test_inplace_shifts(&a, &b, 4)
}
```

#### exhaustive mem shift peeps
```odin
package main

opt_level :: "none"

test_mem_shifts_i8_u8 :: proc(
	si8: ^i8,
	su8: ^u8,
	v: uint,
) -> int {
	r := 0

	si8^ = si8^ << v
	si8^ = si8^ >> v
	r += int(si8^)

	su8^ = su8^ >> v
	su8^ = su8^ << v
	r += int(su8^)

	return r
}

test_mem_shifts_i16_u16 :: proc(
	si16: ^i16,
	su16: ^u16,
	v: uint,
) -> int {
	r := 0

	si16^ = si16^ << v
	si16^ = si16^ >> v
	r += int(si16^)

	su16^ = su16^ >> v
	su16^ = su16^ << v
	r += int(su16^)

	return r
}

test_mem_shifts_i32_u32 :: proc(
	si32: ^i32,
	su32: ^u32,
	v: uint,
) -> int {
	r := 0

	si32^ = si32^ << v
	si32^ = si32^ >> v
	r += int(si32^)

	su32^ = su32^ >> v
	su32^ = su32^ << v
	r += int(su32^)

	return r
}

test_mem_shifts_i64_u64 :: proc(
	si64: ^i64,
	su64: ^u64,
	v: uint,
) -> int {
	r := 0

	si64^ = si64^ << v
	si64^ = si64^ >> v
	r += int(si64^)

	su64^ = su64^ >> v
	su64^ = su64^ << v
	r += int(su64^)

	return r
}

test_mem_imm_shifts_i8_u8 :: proc(
	si8: ^i8,
	su8: ^u8,
) -> int {
	r := 0

	si8^ = si8^ << 3
	si8^ = si8^ >> 3
	r += int(si8^)

	su8^ = su8^ >> 2
	su8^ = su8^ << 2
	r += int(su8^)

	return r
}

test_mem_imm_shifts_i16_u16 :: proc(
	si16: ^i16,
	su16: ^u16,
) -> int {
	r := 0

	si16^ = si16^ << 4
	si16^ = si16^ >> 4
	r += int(si16^)

	su16^ = su16^ >> 5
	su16^ = su16^ << 5
	r += int(su16^)

	return r
}

test_mem_imm_shifts_i32_u32 :: proc(
	si32: ^i32,
	su32: ^u32,
) -> int {
	r := 0

	si32^ = si32^ << 6
	si32^ = si32^ >> 6
	r += int(si32^)

	su32^ = su32^ >> 7
	su32^ = su32^ << 7
	r += int(su32^)

	return r
}

test_mem_imm_shifts_i64_u64 :: proc(
	si64: ^i64,
	su64: ^u64,
) -> int {
	r := 0

	si64^ = si64^ << 8
	si64^ = si64^ >> 8
	r += int(si64^)

	su64^ = su64^ >> 9
	su64^ = su64^ << 9
	r += int(su64^)

	return r
}

main :: proc() -> int {
	si8: i8 = 0-33
	su8: u8 = 201

	si16: i16 = 0-1234
	su16: u16 = 54321

	si32: i32 = 0-123456
	su32: u32 = 123456

	si64: i64 = 0-123456789
	su64: u64 = 123456789

	v := uint(3)

	return (
		test_mem_shifts_i8_u8(&si8, &su8, v) +
		test_mem_shifts_i16_u16(&si16, &su16, v) +
		test_mem_shifts_i32_u32(&si32, &su32, v) +
		test_mem_shifts_i64_u64(&si64, &su64, v) +
		test_mem_imm_shifts_i8_u8(&si8, &su8) +
		test_mem_imm_shifts_i16_u16(&si16, &su16) +
		test_mem_imm_shifts_i32_u32(&si32, &su32) +
		test_mem_imm_shifts_i64_u64(&si64, &su64) \
	)
}
```

#### unary ops
```odin
package main

opt_level :: "none"

test_not_reg :: proc(x: bool) -> bool {
	return !x
}

test_not_i8 :: proc(x: ^bool) -> bool {
	x^ = !x^
	return x^
}

test_bitnot_reg :: proc(x: int) -> int {
	return ~x
}

test_bitnot_i8 :: proc(x: ^i8) -> int {
	x^ = ~x^
	return int(x^)
}

test_bitnot_u8 :: proc(x: ^u8) -> int {
	x^ = ~x^
	return int(x^)
}

test_bitnot_i16 :: proc(x: ^i16) -> int {
	x^ = ~x^
	return int(x^)
}

test_bitnot_u16 :: proc(x: ^u16) -> int {
	x^ = ~x^
	return int(x^)
}

test_bitnot_i32 :: proc(x: ^i32) -> int {
	x^ = ~x^
	return int(x^)
}

test_bitnot_u32 :: proc(x: ^u32) -> int {
	x^ = ~x^
	return int(x^)
}

test_bitnot_i64 :: proc(x: ^i64) -> int {
	x^ = ~x^
	return int(x^)
}

test_bitnot_u64 :: proc(x: ^u64) -> int {
	x^ = ~x^
	return int(x^)
}

test_neg_reg :: proc(x: int) -> int {
	return -x
}

test_bitnot_reg_u8 :: proc(x: u8) -> int {
	return int(~x)
}

test_neg_i8 :: proc(x: ^i8) -> int {
	x^ = -x^
	return int(x^)
}

test_neg_u8 :: proc(x: ^u8) -> int {
	x^ = -x^
	return int(x^)
}

test_neg_i16 :: proc(x: ^i16) -> int {
	x^ = -x^
	return int(x^)
}

test_neg_u16 :: proc(x: ^u16) -> int {
	x^ = -x^
	return int(x^)
}

test_neg_i32 :: proc(x: ^i32) -> int {
	x^ = -x^
	return int(x^)
}

test_neg_u32 :: proc(x: ^u32) -> int {
	x^ = -x^
	return int(x^)
}

test_neg_i64 :: proc(x: ^i64) -> int {
	x^ = -x^
	return int(x^)
}

test_neg_u64 :: proc(x: ^u64) -> int {
	x^ = -x^
	return int(x^)
}

main :: proc() -> int {
	a8: i8 = -5
	b8: u8 = 200

	a16: i16 = -1000
	b16: u16 = 40000

	a32: i32 = -100000
	b32: u32 = 100000

	a64: i64 = -100000000
	b64: u64 = 100000000

	r := 0

	r += int(test_not_reg(false))
	r += int(test_not_reg(true))

	r += test_bitnot_reg(123)
	r += test_bitnot_reg_u8(123)
	r += test_bitnot_i8(&a8)
	r += test_bitnot_u8(&b8)
	r += test_bitnot_i16(&a16)
	r += test_bitnot_u16(&b16)
	r += test_bitnot_i32(&a32)
	r += test_bitnot_u32(&b32)
	r += test_bitnot_i64(&a64)
	r += test_bitnot_u64(&b64)

	r += test_neg_reg(7)
	r += test_neg_i8(&a8)
	r += test_neg_u8(&b8)
	r += test_neg_i16(&a16)
	r += test_neg_u16(&b16)
	r += test_neg_i32(&a32)
	r += test_neg_u32(&b32)
	r += test_neg_i64(&a64)
	r += test_neg_u64(&b64)

	return r
}
```

#### extend reduce integer chain
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	vl: i16 = -1000
	return int(u8(vl))
}
```


#### loops
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	n := 10
	a := 0
	b := 1
	for {
		c := a + b
		a = b
		b = c
		if n == 0 do break
		n -= 1
	}

	return a
}
```

#### nested loops
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	x := 3
	sum := 0
	i := 0
	for {
		if i == x do break
		j := 0
		for {
			if j == x do break
			sum += i * j
			j += 1
		}
		i += 1
	}

	return sum
}
```

#### consecutive loops
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	i := 0

	if false {
		i = 0
		for {
			i += 1
			if i == 1 {
				break
			}
		}
	}

	i = 0
	outher: for {
		i += 1
		if i == 3 {
			break
		}

		j := 0
		for {
			j += 1
			if j == 3 {
				break
			}
		}

		j = 0
		for {
			j += 1
			if j == 2 {
				break outher
			}
			if j == 3 {
				continue outher
			}
		}
	}

	return 0
}
```

#### loop edge cases
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	for {
		break
	}

	r := 0

	i := 0
	for {
		i += 1
		if i == 2 {
			break
		}
		if i == 1 {
			continue
		}
		i += 1
		r = 1
	}

	if r == 0 {
		i = 0
		for {
			i += 1
			if i == 3 {
				break
			}
			if i == 2 {
				continue
			}
			if i == 1 {
				continue
			}
			i += 1
			r = 2
		}
	}

	if r != 0 {
		i = 0
		for {
			i += 1
			if i == 3 {
				r = 1
				break
			}
			i += 1
			if i == 4 {
				r = 3
				break
			}
		}
	}

	return r
}
```

#### infinite loops
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	if false {
		i := 0
		for {
			i += 1
		}
	}

	return 0
}
```

#### inner loop only breaks outer
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	sum := 0
	i := 0
	outer: for {
		i += 1
		if i == 4 do break
		j := 0
		for {
			j += 1
			if j == 4 do break
			if j == 2 {
				k := 0
				for {
					k += 1
					sum += 1
					if k == 5 do break outer
				}
			}
		}
	}
	return sum
}
```

#### inner loop continues outer
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	sum := 0
	i := 0
	outer: for {
		i += 1
		if i == 5 do break
		j := 0
		for {
			j += 1
			if j == 5 do break
			k := 0
			for {
				k += 1
				sum += 1
				if k == 2 do continue outer
			}
		}
	}
	return sum
}
```

#### loop unreachable tail after labelled break crash
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	sum := 0
	for {
		if sum == 2 do break
		sum += 1
	}
	return sum
}
```

#### loop sibling continue outer regalloc blowup
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	sum := 0
	i := 0
	A: for {
		i += 1
		if i == 8 do break
		j := 0
		for {
			j += 1
			if j == 5 do break
			if j == 2 do continue A
			sum += 1
		}
		k := 0
		for {
			k += 1
			if k == 5 do break
			if k == 3 do continue A
			sum += 2
		}
		sum += 100
	}
	return sum
}
```

#### nested infinite loop
```odin
package main

opt_level :: "none"

main :: proc() -> int {
      sum := 0; i := 0
      A: for {
              i += 1
              if i == 2 do break
	      // infinite inner; tail below is unreachable
              if i == 3 { for { sum += 1 } }
              sum += 10
      }
      return sum
}
```

#### infinite loop with control flow
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	if false {
		i := 0
		for {
			if false {
				i -= 1
			}
		}
	}
	return 0
}
```

#### functions
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	return fib(10)
}

fib :: proc(x: int) -> int {
	x := x
	if x <= 2 {
		x = 1
	} else {
		x = fib(x - 1) + fib(x - 2)
	}
	return x
}
```

#### regalloc pressure across calls
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	x := 0

	a0  := x + 1
	a1  := x + 2
	a2  := x + 3
	a3  := x + 4
	a4  := x + 5
	a5  := x + 6
	a6  := x + 7
	a7  := x + 8
	a8  := x + 9
	a9  := x + 10
	a10 := x + 11
	a11 := x + 12
	a12 := x + 13
	a13 := x + 14
	a14 := x + 15
	a15 := x + 16

	call(a15)

	b0 := a0  * a15 + a1
	b1 := a1  * a14 + a2
	b2 := a2  * a13 + a3
	b3 := a3  * a12 + a4
	b4 := a4  * a11 + a5
	b5 := a5  * a10 + a6
	b6 := a6  * a9  + a7
	b7 := a7  * a8  + a0

	call(b7)

	c0 := b0 * b4 + b1
	c1 := b1 * b5 + b2
	c2 := b2 * b6 + b3
	c3 := b3 * b7 + b0

	call(c3)

	d0 := c0 * c2 + c1
	d1 := c1 * c3 + c2

	call(d1)

	e0 := d0 * d1 + c3

	call(e0)

	return e0 +
		a0 + a1 + a2 + a3 +
		a4 + a5 + a6 + a7 +
		a8 + a9 + a10 + a11 +
		a12 + a13 + a14 + a15
}

call :: proc(vl: int) -> int {
	return vl
}
```

#### some nested fuction calls
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	return a(1, 2)
}

a :: proc(u: int, v: int) -> int {
	return b(u) + c(v)
}

b :: proc(u: int) -> int {
	return u * 2
}

c :: proc(v: int) -> int {
	return v * 3
}
```

#### multiple returns
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	return a(1, 2)
}

a :: proc(u: int, v: int) -> int {
	if u == 0 do return 0
	if v == 2 do return v * 6
	if u == 1 do return b(u) + c(v * 2)
	return b(u) + c(v)
}

b :: proc(u: int) -> int {
	return u * 2
}

c :: proc(v: int) -> int {
	return v * 3
}
```

#### pointers
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	vl := 0
	ptr := &vl

	set(ptr)

	return vl
}

set :: proc(ptr: ^int) -> int {
	ptr^ = 1
	return ptr^
}
```

#### pointers dynamic add opt
```odin
package main

opt_level :: "none"

Vls :: struct {
	a: int,
	b: i32,
	c: i16,
	d: i8,
}

main :: proc() -> int {
	vls := Vls{}

	add(&vls.a, 1)
	add_32(&vls.b, 1)
	add_16(&vls.c, 1)
	add_8(&vls.d, 1)

	return vls.a + int(vls.b) + int(vls.c) + int(vls.d)
}

add :: proc(ptr: ^int, v: int) -> int {
	ptr^ = ptr^ + v
	return ptr^
}

add_32 :: proc(ptr: ^i32, v: i32) -> i32 {
	ptr^ = ptr^ + v
	return ptr^
}

add_16 :: proc(ptr: ^i16, v: i16) -> i16 {
	ptr^ = ptr^ + v
	return ptr^
}

add_8 :: proc(ptr: ^i8, v: i8) -> i8 {
	ptr^ = ptr^ + v
	return ptr^
}
```

#### loads and stores of different sizes
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	{
		vl: u8 = 0 
		ptr := &vl
		ptr^ = 1
		if ptr^ != 1 do return 1
	}

	{
		vl: u16 = 0
		ptr := &vl
		ptr^ = 1
		if ptr^ != 1 do return 2
	}

	{
		vl: u32 = 0
		ptr := &vl
		ptr^ = 1
		if ptr^ != 1 do return 3
	}

	{
		vl: u64 = 0
		ptr := &vl
		ptr^ = 1
		if ptr^ != 1 do return 4
	}

	{
		vl: i8 = 0 
		ptr := &vl
		ptr^ = 0 - 1
		if ptr^ != 0 - 1 do return 5
	}

	{
		vl: i16 = 0
		ptr := &vl
		ptr^ = 0 - 1
		if ptr^ != 0 - 1 do return 6
	}

	{
		vl: i32 = 0
		ptr := &vl
		ptr^ = 0 - 1
		if ptr^ != 0 - 1 do return 7
	}

	{
		vl: i64 = 0
		ptr := &vl
		ptr^ = 0 - 1
		if ptr^ != 0 - 1 do return 8
	}

	return 0
}
```

#### structs
```odin
package main

opt_level :: "none"

Stru :: struct {
	a: int,
	b: StruB,
}

StruB :: struct {
	c: int,
	d: int,
}

main :: proc() -> int {
	st := Stru{b = {2, 3}}
	stcpy := st
	return stcpy.a + stcpy.b.c + stcpy.b.d
}
```

#### structs with differnt datatypes
```odin
package main

opt_level :: "none"

Inner :: struct {
	u8v:  u8,
	u16v: u16,
	i8v:  i8,
	i16v: i16,
}

Outer :: struct {
	u32v: u32,
	u64v: u64,
	i32v: i32,
	i64v: i64,
	inner: Inner,
}

main :: proc() -> int {
	st := Outer{
		u32v  = 10,
		u64v  = 20,
		i32v  = 0 - 30,
		i64v  = 0 - 40,
		inner = {
			1,
			2,
			0 - 3,
			0 - 4,
		},
	}

	ptr := &st

	ptr.u32v = ptr.u32v + 1
	ptr.u64v = ptr.u64v + 2
	ptr.i32v = ptr.i32v - 3
	ptr.i64v = ptr.i64v - 4

	ptr.inner.u8v  = ptr.inner.u8v + 5
	ptr.inner.u16v = ptr.inner.u16v + 6
	ptr.inner.i8v  = ptr.inner.i8v - 7
	ptr.inner.i16v = ptr.inner.i16v - 8

	stcpy := st

	return int(
		u64(stcpy.u32v) +
		u64(stcpy.u64v) +
		u64(stcpy.i32v) +
		u64(stcpy.i64v) +
		u64(stcpy.inner.u8v) +
		u64(stcpy.inner.u16v) +
		u64(stcpy.inner.i8v) +
		u64(stcpy.inner.i16v),
	)
}
```

#### structs trigger displacement bug
```odin
package main

opt_level :: "none"

Stru :: struct {
	a: int,
	b: int,
}

main :: proc() -> int {
	stru := Stru{1, 2}
	stru.a = stru.b + 1
	return stru.a + stru.b
}
```

#### frontend peepholes on function args
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	return funnel(2, 2 + 2, 2 + 2 + 2)
}

funnel :: proc(a: int, b: int, c: int) -> int {
	return a + b + c
}
```

#### stress testing structs
```odin
package main

opt_level :: "none"

Stru :: struct {
	a: int,
	b: int,
	c: C,
}

C :: struct {
	a: int,
	b: int,
	c: D,
}

D :: struct {
	a: int,
	b: int,
}

main :: proc() -> int {
	vl := Stru{c = {c = {0, 0}}}
	vl.a = 3
	vl.b = 2
	vl.c = {1, 1, {vl.c.a + vl.c.b, 8}}
	vl.c.c = {vl.a, vl.b}
	return vl.a + vl.b + vl.c.a + vl.c.b + vl.c.c.a + vl.c.c.b
}
```

#### pass stack in calls
```odin
package main

opt_level :: "none"

Stru :: struct {
	a: int,
	b: int,
}

Stru2 :: struct {
	a: int,
	b: int,
	c: int,
}

Stru3 :: struct {
	a: u8,
	b: u8,
	c: u8,
	d: u8,
	e: u8,
	f: u8,
	g: u8,
}

Stru4 :: struct {
	a: Stru3,
	b: Stru3,
	c: u8,
}

main :: proc() -> int {
	vl := 0
	vl += fortran({16, 20}, {30, 46, 50})
	vl += load_of_args(1, 2, 3, 4, 5, 6, 7, 8, 9)
	vl += brahma(1, 2, 3, 4, 5, {6, 7})
	vl += int(compose({{1, 2, 3, 4, 5, 6, 7},
		{8, 9, 10, 11, 12, 13, 14}, 15}))
	vl += return_stru(1, 2).a
	vl += int(return_stru3().f)
	vl += int(return_stru3().c)
	return vl
}

compose :: proc(a: Stru4) -> u8 {
	return kentus(a.a) + kentus(a.b) + a.c
}

kentus :: proc(a: Stru3) -> u8 {
	return a.a + a.b + a.c + a.d + a.e + a.f + a.g
}

fortran :: proc(a: Stru, b: Stru2) -> int {
	return a.a + a.b + b.a + b.b + b.c
}

brahma :: proc(a: int, b: int, c: int, d: int, e: int, f: Stru) -> int {
	return a + b + c + d + e + f.a + f.b
}

load_of_args :: proc(
	a: int,
	b: int,
	c: int,
	d: int,
	e: int,
	f: int,
	g: int,
	h: int,
	i: int,
) -> int {
	return a + b + c + d + e + f + g + h + i
}

return_stru :: proc(a: int, b: int) -> Stru {
	return {a, b}
}

return_stru3 :: proc() -> Stru3 {
	return {1, 2, 3, 4, 5, 6, 7}
}

return_stru4 :: proc() -> Stru4 {
	return {return_stru3(), return_stru3(), 70}
}
```


#### struct passed by value is copied
```odin
package main

opt_level :: "none"

Stru :: struct {
	a: int,
	b: int,
}

main :: proc() -> int {
	s := Stru{1, 2}
	mutate(s)
	return s.a + s.b
}

mutate :: proc(s: Stru) -> int {
	s := s
	s.a = 100
	s.b = 200
	return s.a + s.b
}
```

#### nested struct passed by value
```odin
package main

opt_level :: "none"

Inner :: struct {
	x: int,
	y: int,
}

Outer :: struct {
	a: Inner,
	b: int,
}

main :: proc() -> int {
	o := Outer{Inner{1, 2}, 3}
	return sum(o)
}

sum :: proc(o: Outer) -> int {
	return o.a.x + o.a.y + o.b
}
```

#### bool values stored and negated
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	a := 5
	b := 10
	x := a < b
	y := a == b
	r := 0
	if x do r += 1
	if !y do r += 2
	z := !x
	if z do r += 4
	return r
}
```

#### comparison result as integer
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	a := 5
	b := 10
	x := int(a < b)
	y := int(a > b)
	return x * 100 + y
}
```

#### nested pointer double deref
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	a := 42
	p := &a
	pp := &p
	pp^^ = 100
	return a
}
```

#### integer multiplication truncation
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	a: i32 = 100000
	b: i32 = 100000
	c := a * b

	x: u32 = 100000
	y: u32 = 100000
	z := x * y

	return int(c) + int(z)
}
```

#### subword register multiply
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	a := opaque(0 - 5)
	b: i16 = i16(a)
	c := b * 3

	d: i32 = i32(a)
	e := d * 3

	return int(c) + int(e)
}

opaque :: proc(x: int) -> int {
	return x
}
```

#### subword signed division
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	a := opaque(0 - 100)
	b: i8 = i8(a)
	c := b / 3
	return int(c)
}

opaque :: proc(x: int) -> int {
	return x
}
```

#### compound divide and modulo assign
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	a := 100
	a /= 7
	a %= 4

	b: uint = 100
	b /= 7
	b %= 4

	return a + int(b)
}
```

#### compound and not assign
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	a := 15
	a &~= 6
	a |= 1
	a ~= 2
	a &= 254
	return a
}
```

#### unsigned negation wraps
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	a := opaque(1)
	b: u16 = u16(a)
	c := -b
	return int(c)
}

opaque :: proc(x: int) -> int {
	return x
}
```

#### unsigned cast wraps to max
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	a: i32 = 0 - 1
	return int(u32(a))
}
```

#### subword return values
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	return int(get8()) + int(get16())
}

get8 :: proc() -> i8 {
	return 0 - 10
}

get16 :: proc() -> i16 {
	return 0 - 1000
}
```

#### signed subword division widening bug
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	a: i32 = 0 - 100
	b: i32 = 7
	r := 0
	r += int(a / b)
	r += int(a % b)

	c: i16 = 0 - 100
	d: i16 = 7
	r += int(c / d)
	r += int(c % d)

	return r
}
```

#### signed widening cast bug
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	x: i16 = 0 - 1000
	y: i8 = 0 - 50
	return int(x) + int(y)
}
```

#### signed cast through truncation bug
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	b: u8 = 200
	c: u64 = 0
	c -= 1
	return int(i8(b)) + int(i32(c))
}
```

#### signed subword multiply widening bug
```odin
package main

opt_level :: "none"

Stru :: struct {
	b: i16,
}

main :: proc() -> int {
	s := Stru{0 - 1000}
	return int(s.b * 2)
}
```

#### parallel assignment swap bug
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	a := 3
	b := 7
	a, b = b, a
	return a * 10 + b
}
```

#### eight bit register multiply crash
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	a: i8 = 0 - 5
	b := a * 2

	c := opaque(20)
	d: u8 = u8(c)
	e := d * 3

	return int(b) + int(e)
}

opaque :: proc(x: int) -> int {
	return x
}
```

#### signed i8 division needs cbw not cqo
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	a := opaque(200)
	b: i8 = i8(a)
	d := opaque(3)
	e: i8 = i8(d)
	c := b / e
	return int(c)
}

opaque :: proc(x: int) -> int {
	return x
}
```

#### signed i32 division needs cdq not cqo
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	x := i32(opaque(10))
	y := i32(opaque(30))
	b := x - y
	c := i32(opaque(3))
	d := b / c
	return int(d)
}

opaque :: proc(x: int) -> int {
	return x
}
```

#### comparison ge gt not commutative
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	x := opaque(3)
	return int(5 >= x)
}

opaque :: proc(x: int) -> int {
	return x
}
```

#### load must not sink past aliasing store
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	a := opaque(10)
	p := opaque_ptr(&a)
	x := p^
	a = 99
	if opaque(1) == 1 {
		return x
	}
	return 0
}

opaque_ptr :: proc(p: ^int) -> ^int {
	return p
}

opaque :: proc(x: int) -> int {
	return x
}
```

#### narrowing cast leaves dirty upper bits
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	a := opaque(511)
	b: u8 = u8(a)
	c := b / 2
	return int(c)
}

opaque :: proc(x: int) -> int {
	return x
}
```

#### two register struct arg fuel accounting
```odin
package main

opt_level :: "none"

Vec :: struct {
	x: int,
	y: int,
}

opaque :: proc(x: int) -> int {
	return x
}

consume :: proc(s: Vec, a: int, b: int, c: int, d: int, e: int, f: int) -> int {
	return s.x + s.y + a + b + c + d + e + f
}

main :: proc() -> int {
	v := Vec{opaque(10), opaque(20)}
	return consume(
		v,
		opaque(1),
		opaque(2),
		opaque(3),
		opaque(4),
		opaque(5),
		opaque(6),
	)
}
```

#### eliminate phi with direct cycle
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	i := 0
	b := 0
	j := 0
	for {
		i += b
		j += 1
		if j == 3 do break
	}

	return 0
}
```

#### proper stack alignemnt
```odin
package main

opt_level :: "none"

Stru :: struct {
	a: u8,
}

main :: proc() -> int {
	a: Stru = {}
	b: Stru = {}

	copy(&a, &b)

	return 0
}

copy :: proc(a: ^Stru, b: ^Stru) -> int {
	a^ = b^
	return 0
}
```

#### trigger comparison with load
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	v := 1
	c := -1
	return cmps(-1, &v) + cmps(1, &v) +
		cmps(-1, &c) + cmps(1, &c) +
		imm_cmps(&v) + imm_cmps(&v) +
		imm_cmps(&c) + imm_cmps(&c)
}

imm_cmps :: proc(b: ^int) -> int {
	r := 0

	if 0 == b^ do r += 1
	if 0 != b^ do r += 2
	if 0 >= b^ do r += 4
	if 0 <= b^ do r += 8
	if 0 > b^ do r += 16
	if 0 < b^ do r += 32

	return r
}

cmps :: proc(a: int, b: ^int) -> int {
	r := 0

	if a == b^ do r += 1
	if a != b^ do r += 2
	if a >= b^ do r += 4
	if a <= b^ do r += 8
	if a > b^ do r += 16
	if a < b^ do r += 32

	return r
}
```

#### basic arrays
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	arr: [32]u8 = {}

	i := 0
	for {
		if i >= len(arr) do break
		arr[i] = u8(i)
		i += 1
	}

	i = 0
	sum := 0
	for {
		if i >= len(arr) do break
		sum += int(arr[i])
		i += 1
	}

	sarr := [4]int{16, 25, 31, 64}

	i = 0
	for {
		if i >= len(sarr) do break
		sarr[i] += i
		i += 1
	}

	i = 0
	for {
		if i >= len(sarr) do break
		sarr[i] += 1
		i += 1
	}

	j := 1
	i = 0
	for {
		if j >= len(sarr) do break
		sarr[i] = sarr[j] + 1
		i += 1
		j += 1
	}

	i = 0
	for {
		if i >= len(sarr) do break
		sum += sarr[i]
		i += 1
	}

	return sum
}
```

#### scaled index sib operations
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	arr := [8]int{3, 14, 25, 8, 40, 17, 55, 2}

	// comparison against a scaled-index load: cmp [base + idx*8], imm
	cnt := 0
	i := 0
	for {
		if i >= len(arr) do break
		if arr[i] > 20 do cnt += 1
		i += 1
	}

	// negate in place: neg [base + idx*8]
	i = 0
	for {
		if i >= len(arr) do break
		arr[i] = -arr[i]
		i += 1
	}

	// bitwise not in place: not [base + idx*8]
	i = 0
	for {
		if i >= len(arr) do break
		arr[i] = ~arr[i]
		i += 1
	}

	// compound add in place: add [base + idx*8], imm
	i = 0
	for {
		if i >= len(arr) do break
		arr[i] += 7
		i += 1
	}

	// store a constant through a scaled index: mov [base + idx*8], imm
	i = 0
	for {
		if i >= len(arr) do break
		if i & 1 == 0 do arr[i] = 100
		i += 1
	}

	// reduce with a scaled-index load: mov reg, [base + idx*8]
	sum := 0
	i = 0
	for {
		if i >= len(arr) do break
		sum += arr[i]
		i += 1
	}

	return sum + cnt
}
```
