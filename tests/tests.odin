#+build !wasm32
package tests
// NOTE: this file is generated: odin run meta

import "core:testing"

import "base:intrinsics"

import main ".."

@(test) simplest :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
	return 69
}

main.run_test(t, `simplest`, `
package main

opt_level :: "none"

main :: proc() -> int {
	return 69
}
`, main_())
}
@(test) basic_arithmetic :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
	return 1 + 2 * 3
}

main.run_test(t, `basic_arithmetic`, `
package main

opt_level :: "none"

main :: proc() -> int {
	return 1 + 2 * 3
}
`, main_())
}
@(test) all_integer_operators :: proc(t: ^testing.T) {



opt_level :: "none"

batch :: proc(a: $T, b: T, n: T) -> int {
	r := 0

	r += int(a * b)
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

	return r
}

main_ :: proc() -> int {

	r := 0
	r += batch(20, 6, -7)
	r += batch(u8(20), 6, 7)
	r += batch(u16(20), 6, 7)
	r += batch(u32(20), 6, 7)
	r += batch(i8(20), 6, -7)
	r += batch(i16(20), 6, -7)
	r += batch(i32(20), 6, -7)

	return r
}

main.run_test(t, `all_integer_operators`, `
package main

opt_level :: "none"

batch :: proc(a: $T, b: T, n: T) -> int {
	r := 0

	r += int(a * b)
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

	return r
}

main :: proc() -> int {

	r := 0
	r += batch(20, 6, -7)
	r += batch(u8(20), 6, 7)
	r += batch(u16(20), 6, 7)
	r += batch(u32(20), 6, 7)
	r += batch(i8(20), 6, -7)
	r += batch(i16(20), 6, -7)
	r += batch(i32(20), 6, -7)

	return r
}
`, main_())
}
@(test) all_unsigned_integer_operators :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
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

main.run_test(t, `all_unsigned_integer_operators`, `
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
`, main_())
}
@(test) all_signed_integer_operators :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
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

main.run_test(t, `all_signed_integer_operators`, `
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
`, main_())
}
@(test) bitwise_ops_with_constants :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
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

main.run_test(t, `bitwise_ops_with_constants`, `
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
`, main_())
}
@(test) bitwise_ops_through_pointers :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
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

main.run_test(t, `bitwise_ops_through_pointers`, `
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
`, main_())
}
@(test) bitwise_ops_sized_through_pointers :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
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

main.run_test(t, `bitwise_ops_sized_through_pointers`, `
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
`, main_())
}
@(test) simple_2_adress_self_conflict :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
	return 2 + 2 * 2
}

main.run_test(t, `simple_2_adress_self_conflict`, `
package main

opt_level :: "none"

main :: proc() -> int {
	return 2 + 2 * 2
}
`, main_())
}
@(test) more_complex_2_adress_self_conflict :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
	return 2 + 2 * 2 + 2 * 2 + 2 * 2 + 2 * 2
}

main.run_test(t, `more_complex_2_adress_self_conflict`, `
package main

opt_level :: "none"

main :: proc() -> int {
	return 2 + 2 * 2 + 2 * 2 + 2 * 2 + 2 * 2
}
`, main_())
}
@(test) force_spill_with_simple_addition :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
	return ((((1 + 1) + (1 + 1)) + ((1 + 1) + (1 + 1))) +
        (((1 + 1) + (1 + 1)) + ((1 + 1) + (1 + 1)))) +
        ((((1 + 1) + (1 + 1)) + ((1 + 1) + (1 + 1))) +
        (((1 + 1) + (1 + 1)) + ((1 + 1) + (1 + 1))))
}

main.run_test(t, `force_spill_with_simple_addition`, `
package main

opt_level :: "none"

main :: proc() -> int {
	return ((((1 + 1) + (1 + 1)) + ((1 + 1) + (1 + 1))) +
        (((1 + 1) + (1 + 1)) + ((1 + 1) + (1 + 1)))) +
        ((((1 + 1) + (1 + 1)) + ((1 + 1) + (1 + 1))) +
        (((1 + 1) + (1 + 1)) + ((1 + 1) + (1 + 1))))
}
`, main_())
}
@(test) simple_varialbes :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
	a := 2
	b, c := 7, 3 * a
	return b * c
}

main.run_test(t, `simple_varialbes`, `
package main

opt_level :: "none"

main :: proc() -> int {
	a := 2
	b, c := 7, 3 * a
	return b * c
}
`, main_())
}
@(test) variables_that_create_register_pressure :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
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

main.run_test(t, `variables_that_create_register_pressure`, `
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
`, main_())
}
@(test) variables_that_create_even_more_register_pressure :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
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

main.run_test(t, `variables_that_create_even_more_register_pressure`, `
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
`, main_())
}
@(test) simple_if_statement :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
	a := 0
	if a == 0 {
		a = 100
	} else {
		a = 2
	}
	return a
}

main.run_test(t, `simple_if_statement`, `
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
`, main_())
}
@(test) if_statement_with_register_pressure :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
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

main.run_test(t, `if_statement_with_register_pressure`, `
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
`, main_())
}
@(test) if_statement_peepholes :: proc(t: ^testing.T) {



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

main_ :: proc() -> int {
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

main.run_test(t, `if_statement_peepholes`, `
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
`, main_())
}
@(test) different_shift_peeps :: proc(t: ^testing.T) {



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

main_ :: proc() -> int {
	a: int = 0 - 5
	b: uint = 20

	return test_imm_shifts(0 - 1) +
		test_imm_inplace_shifts(&a, &b) +
		test_inplace_shifts(&a, &b, 4)
}

main.run_test(t, `different_shift_peeps`, `
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
`, main_())
}
@(test) exhaustive_mem_shift_peeps :: proc(t: ^testing.T) {



opt_level :: "none"

test_mem_shifts :: proc(
	si8: ^$A,
	su8: ^$B,
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

test_mem_imm_shifts :: proc(
	si8: ^$A,
	su8: ^$B,
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

main_ :: proc() -> int {
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
		test_mem_shifts(&si8, &su8, v) +
		test_mem_shifts(&si16, &su16, v) +
		test_mem_shifts(&si32, &su32, v) +
		test_mem_shifts(&si64, &su64, v) +
		test_mem_imm_shifts(&si8, &su8) +
		test_mem_imm_shifts(&si16, &su16) +
		test_mem_imm_shifts(&si32, &su32) +
		test_mem_imm_shifts(&si64, &su64) \
	)
}

main.run_test(t, `exhaustive_mem_shift_peeps`, `
package main

opt_level :: "none"

test_mem_shifts :: proc(
	si8: ^$A,
	su8: ^$B,
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

test_mem_imm_shifts :: proc(
	si8: ^$A,
	su8: ^$B,
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
		test_mem_shifts(&si8, &su8, v) +
		test_mem_shifts(&si16, &su16, v) +
		test_mem_shifts(&si32, &su32, v) +
		test_mem_shifts(&si64, &su64, v) +
		test_mem_imm_shifts(&si8, &su8) +
		test_mem_imm_shifts(&si16, &su16) +
		test_mem_imm_shifts(&si32, &su32) +
		test_mem_imm_shifts(&si64, &su64) \
	)
}
`, main_())
}
@(test) unary_ops :: proc(t: ^testing.T) {



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

test_bitnot :: proc(x: ^$T) -> int {
	x^ = ~x^
	return int(x^)
}

test_neg_reg :: proc(x: int) -> int {
	return -x
}

test_bitnot_reg_u8 :: proc(x: u8) -> int {
	return int(~x)
}

test_neg :: proc(x: ^$T) -> int {
	x^ = -x^
	return int(x^)
}

main_ :: proc() -> int {
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
	r += test_bitnot(&a8)
	r += test_bitnot(&b8)
	r += test_bitnot(&a16)
	r += test_bitnot(&b16)
	r += test_bitnot(&a32)
	r += test_bitnot(&b32)
	r += test_bitnot(&a64)
	r += test_bitnot(&b64)

	r += test_neg_reg(7)
	r += test_neg(&a8)
	r += test_neg(&b8)
	r += test_neg(&a16)
	r += test_neg(&b16)
	r += test_neg(&a32)
	r += test_neg(&b32)
	r += test_neg(&a64)
	r += test_neg(&b64)

	return r
}

main.run_test(t, `unary_ops`, `
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

test_bitnot :: proc(x: ^$T) -> int {
	x^ = ~x^
	return int(x^)
}

test_neg_reg :: proc(x: int) -> int {
	return -x
}

test_bitnot_reg_u8 :: proc(x: u8) -> int {
	return int(~x)
}

test_neg :: proc(x: ^$T) -> int {
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
	r += test_bitnot(&a8)
	r += test_bitnot(&b8)
	r += test_bitnot(&a16)
	r += test_bitnot(&b16)
	r += test_bitnot(&a32)
	r += test_bitnot(&b32)
	r += test_bitnot(&a64)
	r += test_bitnot(&b64)

	r += test_neg_reg(7)
	r += test_neg(&a8)
	r += test_neg(&b8)
	r += test_neg(&a16)
	r += test_neg(&b16)
	r += test_neg(&a32)
	r += test_neg(&b32)
	r += test_neg(&a64)
	r += test_neg(&b64)

	return r
}
`, main_())
}
@(test) extend_reduce_integer_chain :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
	vl: i16 = -1000
	return int(u8(vl))
}

main.run_test(t, `extend_reduce_integer_chain`, `
package main

opt_level :: "none"

main :: proc() -> int {
	vl: i16 = -1000
	return int(u8(vl))
}
`, main_())
}
@(test) loops :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
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

main.run_test(t, `loops`, `
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
`, main_())
}
@(test) nested_loops :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
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

main.run_test(t, `nested_loops`, `
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
`, main_())
}
@(test) rotated_nested_loops :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
	x := 3
	sum := 0
	i := 0
	for {
		j := 0
		for {
			sum += i * j
			j += 1
			if j > x do break
		}
		i += 1
		if i > x do break
	}

	return sum
}

main.run_test(t, `rotated_nested_loops`, `
package main

opt_level :: "none"

main :: proc() -> int {
	x := 3
	sum := 0
	i := 0
	for {
		j := 0
		for {
			sum += i * j
			j += 1
			if j > x do break
		}
		i += 1
		if i > x do break
	}

	return sum
}
`, main_())
}
@(test) exemplar_affine_loop :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
	arr: [8]int
	i := 0
	for {
		if i < len(arr) {
			arr[i] = i
			i += 1
		} else do break
	}

	return 0
}

main.run_test(t, `exemplar_affine_loop`, `
package main

opt_level :: "none"

main :: proc() -> int {
	arr: [8]int
	i := 0
	for {
		if i < len(arr) {
			arr[i] = i
			i += 1
		} else do break
	}

	return 0
}
`, main_())
}
@(test) affine_loop_different_liverange_induction :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
	arr: [8]int
	i := 0
	for {
		if i < len(arr) {
			arr[i] = i
			i += 1
			if i > 4 {
				i /= 2
				i *= 2
				i += 1
			}
		} else do break
	}

	return 0
}

main.run_test(t, `affine_loop_different_liverange_induction`, `
package main

opt_level :: "none"

main :: proc() -> int {
	arr: [8]int
	i := 0
	for {
		if i < len(arr) {
			arr[i] = i
			i += 1
			if i > 4 {
				i /= 2
				i *= 2
				i += 1
			}
		} else do break
	}

	return 0
}
`, main_())
}
@(test) consecutive_loops :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
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

main.run_test(t, `consecutive_loops`, `
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
`, main_())
}
@(test) loop_edge_cases :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
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

main.run_test(t, `loop_edge_cases`, `
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
`, main_())
}
@(test) infinite_loops :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
	if false {
		i := 0
		for {
			i += 1
		}
	}

	return 0
}

main.run_test(t, `infinite_loops`, `
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
`, main_())
}
@(test) inner_loop_only_breaks_outer :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
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

main.run_test(t, `inner_loop_only_breaks_outer`, `
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
`, main_())
}
@(test) inner_loop_continues_outer :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
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

main.run_test(t, `inner_loop_continues_outer`, `
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
`, main_())
}
@(test) loop_unreachable_tail_after_labelled_break_crash :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
	sum := 0
	for {
		if sum == 2 do break
		sum += 1
	}
	return sum
}

main.run_test(t, `loop_unreachable_tail_after_labelled_break_crash`, `
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
`, main_())
}
@(test) loop_sibling_continue_outer_regalloc_blowup :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
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

main.run_test(t, `loop_sibling_continue_outer_regalloc_blowup`, `
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
`, main_())
}
@(test) nested_infinite_loop :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
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

main.run_test(t, `nested_infinite_loop`, `
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
`, main_())
}
@(test) infinite_loop_with_control_flow :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
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

main.run_test(t, `infinite_loop_with_control_flow`, `
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
`, main_())
}
@(test) functions :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
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

main.run_test(t, `functions`, `
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
`, main_())
}
@(test) regalloc_pressure_across_calls :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
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

main.run_test(t, `regalloc_pressure_across_calls`, `
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
`, main_())
}
@(test) some_nested_fuction_calls :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
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

main.run_test(t, `some_nested_fuction_calls`, `
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
`, main_())
}
@(test) multiple_returns :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
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

main.run_test(t, `multiple_returns`, `
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
`, main_())
}
@(test) pointers :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
	vl := 0
	ptr := &vl

	set(ptr)

	return vl
}

set :: proc(ptr: ^int) -> int {
	ptr^ = 1
	return ptr^
}

main.run_test(t, `pointers`, `
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
`, main_())
}
@(test) pointers_dynamic_add_opt :: proc(t: ^testing.T) {



opt_level :: "none"

Vls :: struct {
	a: int,
	b: i32,
	c: i16,
	d: i8,
}

main_ :: proc() -> int {
	vls := Vls{}

	add(&vls.a, 1)
	add(&vls.b, 1)
	add(&vls.c, 1)
	add(&vls.d, 1)

	return vls.a + int(vls.b) + int(vls.c) + int(vls.d)
}

add :: proc(ptr: ^$T, v: T) -> T {
	ptr^ = ptr^ + v
	return ptr^
}

main.run_test(t, `pointers_dynamic_add_opt`, `
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
	add(&vls.b, 1)
	add(&vls.c, 1)
	add(&vls.d, 1)

	return vls.a + int(vls.b) + int(vls.c) + int(vls.d)
}

add :: proc(ptr: ^$T, v: T) -> T {
	ptr^ = ptr^ + v
	return ptr^
}
`, main_())
}
@(test) loads_and_stores_of_different_sizes :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
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

main.run_test(t, `loads_and_stores_of_different_sizes`, `
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
`, main_())
}
@(test) structs :: proc(t: ^testing.T) {



opt_level :: "none"

Stru :: struct {
	a: int,
	b: StruB,
}

StruB :: struct {
	c: int,
	d: int,
}

main_ :: proc() -> int {
	st := Stru{b = {2, 3}}
	stcpy := st
	return stcpy.a + stcpy.b.c + stcpy.b.d
}

main.run_test(t, `structs`, `
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
`, main_())
}
@(test) structs_with_differnt_datatypes :: proc(t: ^testing.T) {



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

main_ :: proc() -> int {
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

main.run_test(t, `structs_with_differnt_datatypes`, `
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
`, main_())
}
@(test) structs_trigger_displacement_bug :: proc(t: ^testing.T) {



opt_level :: "none"

Stru :: struct {
	a: int,
	b: int,
}

main_ :: proc() -> int {
	stru := Stru{1, 2}
	stru.a = stru.b + 1
	return stru.a + stru.b
}

main.run_test(t, `structs_trigger_displacement_bug`, `
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
`, main_())
}
@(test) frontend_peepholes_on_function_args :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
	return funnel(2, 2 + 2, 2 + 2 + 2)
}

funnel :: proc(a: int, b: int, c: int) -> int {
	return a + b + c
}

main.run_test(t, `frontend_peepholes_on_function_args`, `
package main

opt_level :: "none"

main :: proc() -> int {
	return funnel(2, 2 + 2, 2 + 2 + 2)
}

funnel :: proc(a: int, b: int, c: int) -> int {
	return a + b + c
}
`, main_())
}
@(test) stress_testing_structs :: proc(t: ^testing.T) {



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

main_ :: proc() -> int {
	vl := Stru{c = {c = {0, 0}}}
	vl.a = 3
	vl.b = 2
	vl.c = {1, 1, {vl.c.a + vl.c.b, 8}}
	vl.c.c = {vl.a, vl.b}
	return vl.a + vl.b + vl.c.a + vl.c.b + vl.c.c.a + vl.c.c.b
}

main.run_test(t, `stress_testing_structs`, `
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
`, main_())
}
@(test) mixed_2_register_op :: proc(t: ^testing.T) {



opt_level :: "none"

Stru :: struct {
	v: f32,
	b: int,
}

main_ :: proc() -> int {
	return fn(ofn())
}

ofn :: proc() -> Stru {
	return {0, 1}
}

fn :: proc(s: Stru) -> int {
	return int(s.v) + s.b
}

main.run_test(t, `mixed_2_register_op`, `
package main

opt_level :: "none"

Stru :: struct {
	v: f32,
	b: int,
}

main :: proc() -> int {
	return fn(ofn())
}

ofn :: proc() -> Stru {
	return {0, 1}
}

fn :: proc(s: Stru) -> int {
	return int(s.v) + s.b
}
`, main_())
}
@(test) pass_stack_in_calls :: proc(t: ^testing.T) {



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

main_ :: proc() -> int {
	vl := 0
	vl += fortran({16, 20}, {30, 46, 50})
	vl += load_of_args(1, 2, 3, 4, 5, 6, 7, 8, 9)
	vl += brahma(1, 2, 3, 4, 5, {6, 7})
	vl += int(compose({{1, 2, 3, 4, 5, 6, 7},
		{8, 9, 10, 11, 12, 13, 14}, 15}))
	vl += return_stru(1, 2).a
	vl += int(return_stru3().f)
	vl += int(return_stru3().c)
	vl += stringa_dinga("", 1, "22", "333", 4, "55555",
		"666666", 7, "88888888", "999999999", 10)
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

stringa_dinga :: proc(
	a: string,
	l: int,
	b: string,
	c: string,
	m: int,
	d: string,
	e: string,
	z: int,
	f: string,
	g: string,
	h: int,
) -> int {
	return len(a) + 3 * l + 8 * len(b) + 12 * len(c) + 24 * m +
		50 * len(d) + 100 * len(e) + 200 * z +
		400 * len(f) + 500 * len(g) + 1000 * h
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

main.run_test(t, `pass_stack_in_calls`, `
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
	vl += stringa_dinga("", 1, "22", "333", 4, "55555",
		"666666", 7, "88888888", "999999999", 10)
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

stringa_dinga :: proc(
	a: string,
	l: int,
	b: string,
	c: string,
	m: int,
	d: string,
	e: string,
	z: int,
	f: string,
	g: string,
	h: int,
) -> int {
	return len(a) + 3 * l + 8 * len(b) + 12 * len(c) + 24 * m +
		50 * len(d) + 100 * len(e) + 200 * z +
		400 * len(f) + 500 * len(g) + 1000 * h
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
`, main_())
}
@(test) struct_passed_by_value_is_copied :: proc(t: ^testing.T) {



opt_level :: "none"

Stru :: struct {
	a: int,
	b: int,
}

main_ :: proc() -> int {
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

main.run_test(t, `struct_passed_by_value_is_copied`, `
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
`, main_())
}
@(test) nested_struct_passed_by_value :: proc(t: ^testing.T) {



opt_level :: "none"

Inner :: struct {
	x: int,
	y: int,
}

Outer :: struct {
	a: Inner,
	b: int,
}

main_ :: proc() -> int {
	o := Outer{Inner{1, 2}, 3}
	return sum(o)
}

sum :: proc(o: Outer) -> int {
	return o.a.x + o.a.y + o.b
}

main.run_test(t, `nested_struct_passed_by_value`, `
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
`, main_())
}
@(test) bool_values_stored_and_negated :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
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

main.run_test(t, `bool_values_stored_and_negated`, `
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
`, main_())
}
@(test) comparison_result_as_integer :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
	a := 5
	b := 10
	x := int(a < b)
	y := int(a > b)
	return x * 100 + y
}

main.run_test(t, `comparison_result_as_integer`, `
package main

opt_level :: "none"

main :: proc() -> int {
	a := 5
	b := 10
	x := int(a < b)
	y := int(a > b)
	return x * 100 + y
}
`, main_())
}
@(test) nested_pointer_double_deref :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
	a := 42
	p := &a
	pp := &p
	pp^^ = 100
	return a
}

main.run_test(t, `nested_pointer_double_deref`, `
package main

opt_level :: "none"

main :: proc() -> int {
	a := 42
	p := &a
	pp := &p
	pp^^ = 100
	return a
}
`, main_())
}
@(test) integer_multiplication_truncation :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
	a: i32 = 100000
	b: i32 = 100000
	c := a * b

	x: u32 = 100000
	y: u32 = 100000
	z := x * y

	return int(c) + int(z)
}

main.run_test(t, `integer_multiplication_truncation`, `
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
`, main_())
}
@(test) subword_register_multiply :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
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

main.run_test(t, `subword_register_multiply`, `
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
`, main_())
}
@(test) subword_signed_division :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
	a := opaque(0 - 100)
	b: i8 = i8(a)
	c := b / 3
	return int(c)
}

opaque :: proc(x: int) -> int {
	return x
}

main.run_test(t, `subword_signed_division`, `
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
`, main_())
}
@(test) compound_divide_and_modulo_assign :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
	a := 100
	a /= 7
	a %= 4

	b: uint = 100
	b /= 7
	b %= 4

	return a + int(b)
}

main.run_test(t, `compound_divide_and_modulo_assign`, `
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
`, main_())
}
@(test) compound_and_not_assign :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
	a := 15
	a &~= 6
	a |= 1
	a ~= 2
	a &= 254
	return a
}

main.run_test(t, `compound_and_not_assign`, `
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
`, main_())
}
@(test) unsigned_negation_wraps :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
	a := opaque(1)
	b: u16 = u16(a)
	c := -b
	return int(c)
}

opaque :: proc(x: int) -> int {
	return x
}

main.run_test(t, `unsigned_negation_wraps`, `
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
`, main_())
}
@(test) unsigned_cast_wraps_to_max :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
	a: i32 = 0 - 1
	return int(u32(a))
}

main.run_test(t, `unsigned_cast_wraps_to_max`, `
package main

opt_level :: "none"

main :: proc() -> int {
	a: i32 = 0 - 1
	return int(u32(a))
}
`, main_())
}
@(test) subword_return_values :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
	return int(get8()) + int(get16())
}

get8 :: proc() -> i8 {
	return 0 - 10
}

get16 :: proc() -> i16 {
	return 0 - 1000
}

main.run_test(t, `subword_return_values`, `
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
`, main_())
}
@(test) signed_subword_division_widening_bug :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
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

main.run_test(t, `signed_subword_division_widening_bug`, `
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
`, main_())
}
@(test) signed_widening_cast_bug :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
	x: i16 = 0 - 1000
	y: i8 = 0 - 50
	return int(x) + int(y)
}

main.run_test(t, `signed_widening_cast_bug`, `
package main

opt_level :: "none"

main :: proc() -> int {
	x: i16 = 0 - 1000
	y: i8 = 0 - 50
	return int(x) + int(y)
}
`, main_())
}
@(test) signed_cast_through_truncation_bug :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
	b: u8 = 200
	c: u64 = 0
	c -= 1
	return int(i8(b)) + int(i32(c))
}

main.run_test(t, `signed_cast_through_truncation_bug`, `
package main

opt_level :: "none"

main :: proc() -> int {
	b: u8 = 200
	c: u64 = 0
	c -= 1
	return int(i8(b)) + int(i32(c))
}
`, main_())
}
@(test) signed_subword_multiply_widening_bug :: proc(t: ^testing.T) {



opt_level :: "none"

Stru :: struct {
	b: i16,
}

main_ :: proc() -> int {
	s := Stru{0 - 1000}
	return int(s.b * 2)
}

main.run_test(t, `signed_subword_multiply_widening_bug`, `
package main

opt_level :: "none"

Stru :: struct {
	b: i16,
}

main :: proc() -> int {
	s := Stru{0 - 1000}
	return int(s.b * 2)
}
`, main_())
}
@(test) parallel_assignment_swap_bug :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
	a := 3
	b := 7
	a, b = b, a
	return a * 10 + b
}

main.run_test(t, `parallel_assignment_swap_bug`, `
package main

opt_level :: "none"

main :: proc() -> int {
	a := 3
	b := 7
	a, b = b, a
	return a * 10 + b
}
`, main_())
}
@(test) eight_bit_register_multiply_crash :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
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

main.run_test(t, `eight_bit_register_multiply_crash`, `
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
`, main_())
}
@(test) signed_i8_division_needs_cbw_not_cqo :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
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

main.run_test(t, `signed_i8_division_needs_cbw_not_cqo`, `
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
`, main_())
}
@(test) signed_i32_division_needs_cdq_not_cqo :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
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

main.run_test(t, `signed_i32_division_needs_cdq_not_cqo`, `
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
`, main_())
}
@(test) comparison_ge_gt_not_commutative :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
	x := opaque(3)
	return int(5 >= x)
}

opaque :: proc(x: int) -> int {
	return x
}

main.run_test(t, `comparison_ge_gt_not_commutative`, `
package main

opt_level :: "none"

main :: proc() -> int {
	x := opaque(3)
	return int(5 >= x)
}

opaque :: proc(x: int) -> int {
	return x
}
`, main_())
}
@(test) load_must_not_sink_past_aliasing_store :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
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

main.run_test(t, `load_must_not_sink_past_aliasing_store`, `
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
`, main_())
}
@(test) narrowing_cast_leaves_dirty_upper_bits :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
	a := opaque(511)
	b: u8 = u8(a)
	c := b / 2
	return int(c)
}

opaque :: proc(x: int) -> int {
	return x
}

main.run_test(t, `narrowing_cast_leaves_dirty_upper_bits`, `
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
`, main_())
}
@(test) two_register_struct_arg_fuel_accounting :: proc(t: ^testing.T) {



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

main_ :: proc() -> int {
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

main.run_test(t, `two_register_struct_arg_fuel_accounting`, `
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
`, main_())
}
@(test) eliminate_phi_with_direct_cycle :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
	i := 0
	b := 0
	j := 0
	for {
		i += b
		j += 1
		if j >= 3 do break
	}

	return j
}

main.run_test(t, `eliminate_phi_with_direct_cycle`, `
package main

opt_level :: "none"

main :: proc() -> int {
	i := 0
	b := 0
	j := 0
	for {
		i += b
		j += 1
		if j >= 3 do break
	}

	return j
}
`, main_())
}
@(test) proper_stack_alignemnt :: proc(t: ^testing.T) {



opt_level :: "none"

Stru :: struct {
	a: u8,
}

main_ :: proc() -> int {
	a: Stru = {}
	b: Stru = {}

	copy(&a, &b)

	return 0
}

copy :: proc(a: ^Stru, b: ^Stru) -> int {
	a^ = b^
	return 0
}

main.run_test(t, `proper_stack_alignemnt`, `
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
`, main_())
}
@(test) trigger_comparison_with_load :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
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

main.run_test(t, `trigger_comparison_with_load`, `
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
`, main_())
}
@(test) basic_arrays :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
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

	d: [3][3]int = {}

	i = 0
	for {
		if i >= len(d) do break
		j = 0
		for {
			if j >= len(d) do break
			d[i][j] = i * j
			j += 1
		}
		i += 1
	}

	i = 0
	for {
		if i >= len(d) do break
		j = 0
		for {
			if j >= len(d) do break
			sum += d[i][j]
			j += 1
		}
		i += 1
	}

	return sum
}

main.run_test(t, `basic_arrays`, `
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

	d: [3][3]int = {}

	i = 0
	for {
		if i >= len(d) do break
		j = 0
		for {
			if j >= len(d) do break
			d[i][j] = i * j
			j += 1
		}
		i += 1
	}

	i = 0
	for {
		if i >= len(d) do break
		j = 0
		for {
			if j >= len(d) do break
			sum += d[i][j]
			j += 1
		}
		i += 1
	}

	return sum
}
`, main_())
}
@(test) scaled_index_sib_operations :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
	arr := [8]int{3, 14, 25, 8, 40, 17, 55, 2}

	cnt := 0
	i := 0
	for {
		if i >= len(arr) do break
		if arr[i] > 20 do cnt += 1
		i += 1
	}

	i = 0
	for {
		if i >= len(arr) do break
		arr[i] = -arr[i]
		i += 1
	}

	i = 0
	for {
		if i >= len(arr) do break
		arr[i] = ~arr[i]
		i += 1
	}

	i = 0
	for {
		if i >= len(arr) do break
		arr[i] += 7
		i += 1
	}

	i = 0
	for {
		if i >= len(arr) do break
		if i & 1 == 0 do arr[i] = 100
		i += 1
	}

	sum := 0
	i = 0
	for {
		if i >= len(arr) do break
		sum += arr[i]
		i += 1
	}

	return sum + cnt
}

main.run_test(t, `scaled_index_sib_operations`, `
package main

opt_level :: "none"

main :: proc() -> int {
	arr := [8]int{3, 14, 25, 8, 40, 17, 55, 2}

	cnt := 0
	i := 0
	for {
		if i >= len(arr) do break
		if arr[i] > 20 do cnt += 1
		i += 1
	}

	i = 0
	for {
		if i >= len(arr) do break
		arr[i] = -arr[i]
		i += 1
	}

	i = 0
	for {
		if i >= len(arr) do break
		arr[i] = ~arr[i]
		i += 1
	}

	i = 0
	for {
		if i >= len(arr) do break
		arr[i] += 7
		i += 1
	}

	i = 0
	for {
		if i >= len(arr) do break
		if i & 1 == 0 do arr[i] = 100
		i += 1
	}

	sum := 0
	i = 0
	for {
		if i >= len(arr) do break
		sum += arr[i]
		i += 1
	}

	return sum + cnt
}
`, main_())
}
@(test) basic_slices :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
	arr := [8]int{3, 14, 25, 8, 40, 17, 55, 2}
	sum := 0
	i := 0

if false {
	slc: []int = arr[:]
	for {
		if i >= len(slc) do break
		sum += slc[i]
		i += 1
	}

	slc = slc[1:]
	i = 0
	for {
		if i >= len(slc) do break
		sum += slc[i]
		i += 1
	}

	slc = slc[:5]
	i = 0
	for {
		if i >= len(slc) do break
		sum += slc[i]
		i += 1
	}

	slc = slc[1:3]
	i = 0
	for {
		if i >= len(slc) do break
		sum += slc[i]
		i += 1
	}

	arra := [4]int{0, 1, 2, 3}
	slc = arra[4 - 4:]
	i = 0
	for {
		if i >= len(slc) do break
		sum += slc[i]
		i += 1
	}
}

	//quick_sort(arr[:])

	i = 0
	for {
		if i >= len(arr) do break
		sum += arr[i] << uint(i)
		arr[i] = -arr[i]
		i += 1
	}

	bubble_sort(arr[:])

if false {
	i = 0
	for {
		if i >= len(arr) do break
		arr[i] = -arr[i]
		sum += arr[i] << uint(i)
		i += 1
	}
}

	return sum
}


bubble_sort :: proc(array: []int) -> int {
	count := len(array)

	init_j, last_j := 0, count - 1

	for {
		init_swap, prev_swap := -1, -1

		j := init_j
		for {
			if j >= last_j do break

			if array[j] > array[j + 1] {
				tmp := array[j + 1]
				array[j + 1] = array[j]
				array[j] = tmp
				prev_swap = j
				if init_swap == -1 {
					init_swap = j
				}
			}

			j += 1
		}

		if prev_swap == -1 {
			return 0
		}

		init_j = init_swap - 1
		if init_j < 0 do init_j = 0
		last_j = prev_swap
	}
}

quick_sort :: proc(array: []int) -> int {
	a := array
	n := len(a)
	if n < 2 {
		return 0
	}

	p := a[n / 2]
	i, j := 0, n - 1

	loop: for {
		for {if a[i] >= p do break; i += 1}
		for {if p >= a[j] do break; j -= 1}

		if i >= j {
			break loop
		}
		
		tmp := a[j]
		a[j] = a[i]
		a[i] = tmp

		i += 1
		j -= 1
	}

	quick_sort(a[0:i])
	quick_sort(a[i:n])

	return 0
}

main.run_test(t, `basic_slices`, `
package main

opt_level :: "none"

main :: proc() -> int {
	arr := [8]int{3, 14, 25, 8, 40, 17, 55, 2}
	sum := 0
	i := 0

if false {
	slc: []int = arr[:]
	for {
		if i >= len(slc) do break
		sum += slc[i]
		i += 1
	}

	slc = slc[1:]
	i = 0
	for {
		if i >= len(slc) do break
		sum += slc[i]
		i += 1
	}

	slc = slc[:5]
	i = 0
	for {
		if i >= len(slc) do break
		sum += slc[i]
		i += 1
	}

	slc = slc[1:3]
	i = 0
	for {
		if i >= len(slc) do break
		sum += slc[i]
		i += 1
	}

	arra := [4]int{0, 1, 2, 3}
	slc = arra[4 - 4:]
	i = 0
	for {
		if i >= len(slc) do break
		sum += slc[i]
		i += 1
	}
}

	//quick_sort(arr[:])

	i = 0
	for {
		if i >= len(arr) do break
		sum += arr[i] << uint(i)
		arr[i] = -arr[i]
		i += 1
	}

	bubble_sort(arr[:])

if false {
	i = 0
	for {
		if i >= len(arr) do break
		arr[i] = -arr[i]
		sum += arr[i] << uint(i)
		i += 1
	}
}

	return sum
}


bubble_sort :: proc(array: []int) -> int {
	count := len(array)

	init_j, last_j := 0, count - 1

	for {
		init_swap, prev_swap := -1, -1

		j := init_j
		for {
			if j >= last_j do break

			if array[j] > array[j + 1] {
				tmp := array[j + 1]
				array[j + 1] = array[j]
				array[j] = tmp
				prev_swap = j
				if init_swap == -1 {
					init_swap = j
				}
			}

			j += 1
		}

		if prev_swap == -1 {
			return 0
		}

		init_j = init_swap - 1
		if init_j < 0 do init_j = 0
		last_j = prev_swap
	}
}

quick_sort :: proc(array: []int) -> int {
	a := array
	n := len(a)
	if n < 2 {
		return 0
	}

	p := a[n / 2]
	i, j := 0, n - 1

	loop: for {
		for {if a[i] >= p do break; i += 1}
		for {if p >= a[j] do break; j -= 1}

		if i >= j {
			break loop
		}
		
		tmp := a[j]
		a[j] = a[i]
		a[i] = tmp

		i += 1
		j -= 1
	}

	quick_sort(a[0:i])
	quick_sort(a[i:n])

	return 0
}
`, main_())
}
@(test) basic_strings :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
	vl := "Edward"
	return int(vl[0]) + int(vl[1:][0]) +
	int(vl[:1][0]) + int(vl[2:4][1])
}

main.run_test(t, `basic_strings`, `
package main

opt_level :: "none"

main :: proc() -> int {
	vl := "Edward"
	return int(vl[0]) + int(vl[1:][0]) +
	int(vl[:1][0]) + int(vl[2:4][1])
}
`, main_())
}
@(test) mutable_global :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
	@(static) g := 5
	g += 10
	return g
}

main.run_test(t, `mutable_global`, `
package main

opt_level :: "none"

main :: proc() -> int {
	@(static) g := 5
	g += 10
	return g
}
`, main_())
}
@(test) global_peepholes :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
	@(static) acc := 40
	@(static) cnt := 0
	@(static) flag := 0

	if acc == 40 do cnt += 1
	acc = -acc
	acc = ~acc
	acc += 3
	flag = 9

	return acc + cnt + flag
}

main.run_test(t, `global_peepholes`, `
package main

opt_level :: "none"

main :: proc() -> int {
	@(static) acc := 40
	@(static) cnt := 0
	@(static) flag := 0

	if acc == 40 do cnt += 1
	acc = -acc
	acc = ~acc
	acc += 3
	flag = 9

	return acc + cnt + flag
}
`, main_())
}
@(test) json_validator :: proc(t: ^testing.T) {



opt_level :: "none"

Parser :: struct {
	data: string,
	pos:  int,
}

peek :: proc(p: ^Parser) -> u8 {
	if p.pos >= len(p.data) do return 0
	return p.data[p.pos]
}

advance :: proc(p: ^Parser) -> u8 {
	c := peek(p)
	p.pos += 1
	return c
}

is_digit :: proc(c: u8) -> bool {
	if (c >= '0') & (c <= '9') do return true
	return false
}

is_hex :: proc(c: u8) -> bool {
	if (c >= '0') & (c <= '9') do return true
	if (c >= 'a') & (c <= 'f') do return true
	if (c >= 'A') & (c <= 'F') do return true
	return false
}

skip_ws :: proc(p: ^Parser) -> bool {
	for {
		c := peek(p)
		if (c == ' ') | (c == '\t') | (c == '\n') | (c == '\r') {
			p.pos += 1
		} else {
			break
		}
	}
	return true
}

parse_lit :: proc(p: ^Parser, lit: string) -> bool {
	i := 0
	for {
		if i >= len(lit) do break
		if peek(p) != lit[i] do return false
		p.pos += 1
		i += 1
	}
	return true
}

parse_string :: proc(p: ^Parser) -> bool {
	if advance(p) != '"' do return false
	for {
		c := advance(p)
		if c == '"' do return true
		if c == 0 do return false
		if c == '\\' {
			e := advance(p)
			if e == '"' do continue
			if e == '\\' do continue
			if e == '/' do continue
			if e == 'b' do continue
			if e == 'f' do continue
			if e == 'n' do continue
			if e == 'r' do continue
			if e == 't' do continue
			if e == 'u' {
				j := 0
				for {
					if j >= 4 do break
					if !is_hex(advance(p)) do return false
					j += 1
				}
				continue
			}
			return false
		}
		if c < 0x20 do return false
	}
}

parse_number :: proc(p: ^Parser) -> bool {
	if peek(p) == '-' do p.pos += 1
	c := peek(p)
	if c == '0' {
		p.pos += 1
	} else if (c >= '1') & (c <= '9') {
		p.pos += 1
		for {
			if !is_digit(peek(p)) do break
			p.pos += 1
		}
	} else {
		return false
	}
	if peek(p) == '.' {
		p.pos += 1
		if !is_digit(peek(p)) do return false
		for {
			if !is_digit(peek(p)) do break
			p.pos += 1
		}
	}
	c = peek(p)
	if (c == 'e') | (c == 'E') {
		p.pos += 1
		c = peek(p)
		if (c == '+') | (c == '-') do p.pos += 1
		if !is_digit(peek(p)) do return false
		for {
			if !is_digit(peek(p)) do break
			p.pos += 1
		}
	}
	return true
}

parse_array :: proc(p: ^Parser) -> bool {
	if advance(p) != '[' do return false
	skip_ws(p)
	if peek(p) == ']' {
		p.pos += 1
		return true
	}
	for {
		if !parse_value(p) do return false
		skip_ws(p)
		c := advance(p)
		if c == ']' do return true
		if c != ',' do return false
	}
}

parse_object :: proc(p: ^Parser) -> bool {
	if advance(p) != '{' do return false
	skip_ws(p)
	if peek(p) == '}' {
		p.pos += 1
		return true
	}
	for {
		skip_ws(p)
		if peek(p) != '"' do return false
		if !parse_string(p) do return false
		skip_ws(p)
		if advance(p) != ':' do return false
		if !parse_value(p) do return false
		skip_ws(p)
		c := advance(p)
		if c == '}' do return true
		if c != ',' do return false
	}
}

parse_value :: proc(p: ^Parser) -> bool {
	skip_ws(p)
	c := peek(p)
	if c == '{' do return parse_object(p)
	if c == '[' do return parse_array(p)
	if c == '"' do return parse_string(p)
	if c == 't' do return parse_lit(p, "true")
	if c == 'f' do return parse_lit(p, "false")
	if c == 'n' do return parse_lit(p, "null")
	if (c == '-') | is_digit(c) do return parse_number(p)
	return false
}

validate :: proc(input: string) -> bool {
	p := Parser{data = input, pos = 0}
	skip_ws(&p)
	if !parse_value(&p) do return false
	skip_ws(&p)
	if p.pos != len(p.data) do return false
	return true
}

main_ :: proc() -> int {
	score := 0

	if validate("true") do score += 1
	if validate("false") do score += 2
	if validate("null") do score += 4
	if validate("123") do score += 8
	if validate("-0.5e10") do score += 16
	if validate("\"hello\"") do score += 32
	if validate("[1, 2, 3]") do score += 64
	if validate("{\"a\": 1, \"b\": [true, null]}") do score += 128
	if validate("  {  }  ") do score += 256
	if validate("[]") do score += 512

	if !validate("") do score += 1024
	if !validate("{") do score += 2048
	if !validate("[1,]") do score += 4096
	if !validate("truex") do score += 8192
	if !validate("01") do score += 16384
	if !validate("\"un\\x\"") do score += 32768
	if !validate("{\"a\" 1}") do score += 65536
	if !validate("nul") do score += 131072

	return score
}

main.run_test(t, `json_validator`, `
package main

opt_level :: "none"

Parser :: struct {
	data: string,
	pos:  int,
}

peek :: proc(p: ^Parser) -> u8 {
	if p.pos >= len(p.data) do return 0
	return p.data[p.pos]
}

advance :: proc(p: ^Parser) -> u8 {
	c := peek(p)
	p.pos += 1
	return c
}

is_digit :: proc(c: u8) -> bool {
	if (c >= '0') & (c <= '9') do return true
	return false
}

is_hex :: proc(c: u8) -> bool {
	if (c >= '0') & (c <= '9') do return true
	if (c >= 'a') & (c <= 'f') do return true
	if (c >= 'A') & (c <= 'F') do return true
	return false
}

skip_ws :: proc(p: ^Parser) -> bool {
	for {
		c := peek(p)
		if (c == ' ') | (c == '\t') | (c == '\n') | (c == '\r') {
			p.pos += 1
		} else {
			break
		}
	}
	return true
}

parse_lit :: proc(p: ^Parser, lit: string) -> bool {
	i := 0
	for {
		if i >= len(lit) do break
		if peek(p) != lit[i] do return false
		p.pos += 1
		i += 1
	}
	return true
}

parse_string :: proc(p: ^Parser) -> bool {
	if advance(p) != '"' do return false
	for {
		c := advance(p)
		if c == '"' do return true
		if c == 0 do return false
		if c == '\\' {
			e := advance(p)
			if e == '"' do continue
			if e == '\\' do continue
			if e == '/' do continue
			if e == 'b' do continue
			if e == 'f' do continue
			if e == 'n' do continue
			if e == 'r' do continue
			if e == 't' do continue
			if e == 'u' {
				j := 0
				for {
					if j >= 4 do break
					if !is_hex(advance(p)) do return false
					j += 1
				}
				continue
			}
			return false
		}
		if c < 0x20 do return false
	}
}

parse_number :: proc(p: ^Parser) -> bool {
	if peek(p) == '-' do p.pos += 1
	c := peek(p)
	if c == '0' {
		p.pos += 1
	} else if (c >= '1') & (c <= '9') {
		p.pos += 1
		for {
			if !is_digit(peek(p)) do break
			p.pos += 1
		}
	} else {
		return false
	}
	if peek(p) == '.' {
		p.pos += 1
		if !is_digit(peek(p)) do return false
		for {
			if !is_digit(peek(p)) do break
			p.pos += 1
		}
	}
	c = peek(p)
	if (c == 'e') | (c == 'E') {
		p.pos += 1
		c = peek(p)
		if (c == '+') | (c == '-') do p.pos += 1
		if !is_digit(peek(p)) do return false
		for {
			if !is_digit(peek(p)) do break
			p.pos += 1
		}
	}
	return true
}

parse_array :: proc(p: ^Parser) -> bool {
	if advance(p) != '[' do return false
	skip_ws(p)
	if peek(p) == ']' {
		p.pos += 1
		return true
	}
	for {
		if !parse_value(p) do return false
		skip_ws(p)
		c := advance(p)
		if c == ']' do return true
		if c != ',' do return false
	}
}

parse_object :: proc(p: ^Parser) -> bool {
	if advance(p) != '{' do return false
	skip_ws(p)
	if peek(p) == '}' {
		p.pos += 1
		return true
	}
	for {
		skip_ws(p)
		if peek(p) != '"' do return false
		if !parse_string(p) do return false
		skip_ws(p)
		if advance(p) != ':' do return false
		if !parse_value(p) do return false
		skip_ws(p)
		c := advance(p)
		if c == '}' do return true
		if c != ',' do return false
	}
}

parse_value :: proc(p: ^Parser) -> bool {
	skip_ws(p)
	c := peek(p)
	if c == '{' do return parse_object(p)
	if c == '[' do return parse_array(p)
	if c == '"' do return parse_string(p)
	if c == 't' do return parse_lit(p, "true")
	if c == 'f' do return parse_lit(p, "false")
	if c == 'n' do return parse_lit(p, "null")
	if (c == '-') | is_digit(c) do return parse_number(p)
	return false
}

validate :: proc(input: string) -> bool {
	p := Parser{data = input, pos = 0}
	skip_ws(&p)
	if !parse_value(&p) do return false
	skip_ws(&p)
	if p.pos != len(p.data) do return false
	return true
}

main :: proc() -> int {
	score := 0

	if validate("true") do score += 1
	if validate("false") do score += 2
	if validate("null") do score += 4
	if validate("123") do score += 8
	if validate("-0.5e10") do score += 16
	if validate("\"hello\"") do score += 32
	if validate("[1, 2, 3]") do score += 64
	if validate("{\"a\": 1, \"b\": [true, null]}") do score += 128
	if validate("  {  }  ") do score += 256
	if validate("[]") do score += 512

	if !validate("") do score += 1024
	if !validate("{") do score += 2048
	if !validate("[1,]") do score += 4096
	if !validate("truex") do score += 8192
	if !validate("01") do score += 16384
	if !validate("\"un\\x\"") do score += 32768
	if !validate("{\"a\" 1}") do score += 65536
	if !validate("nul") do score += 131072

	return score
}
`, main_())
}
@(test) mem2reg_local_struct_scalar_promotion :: proc(t: ^testing.T) {



opt_level :: "none"

Vec3 :: struct {
	x: int,
	y: int,
	z: int,
}

opaque :: proc(x: int) -> int {
	return x
}

main_ :: proc() -> int {
	s := Vec3{opaque(10), opaque(20), opaque(30)}
	s.x = s.x + s.y
	s.z = s.z + s.x
	return s.x + s.y + s.z
}

main.run_test(t, `mem2reg_local_struct_scalar_promotion`, `
package main

opt_level :: "none"

Vec3 :: struct {
	x: int,
	y: int,
	z: int,
}

opaque :: proc(x: int) -> int {
	return x
}

main :: proc() -> int {
	s := Vec3{opaque(10), opaque(20), opaque(30)}
	s.x = s.x + s.y
	s.z = s.z + s.x
	return s.x + s.y + s.z
}
`, main_())
}
@(test) mem2reg_struct_field_conditional_phi :: proc(t: ^testing.T) {



opt_level :: "none"

Vec2 :: struct {
	x: int,
	y: int,
}

opaque :: proc(x: int) -> int {
	return x
}

main_ :: proc() -> int {
	s := Vec2{opaque(5), opaque(7)}
	if opaque(1) > 0 {
		s.x = s.x + 100
	} else {
		s.x = s.x - 100
	}
	return s.x + s.y
}

main.run_test(t, `mem2reg_struct_field_conditional_phi`, `
package main

opt_level :: "none"

Vec2 :: struct {
	x: int,
	y: int,
}

opaque :: proc(x: int) -> int {
	return x
}

main :: proc() -> int {
	s := Vec2{opaque(5), opaque(7)}
	if opaque(1) > 0 {
		s.x = s.x + 100
	} else {
		s.x = s.x - 100
	}
	return s.x + s.y
}
`, main_())
}
@(test) mem2reg_struct_accumulator_in_loop :: proc(t: ^testing.T) {



opt_level :: "none"

Vec2 :: struct {
	x: int,
	y: int,
}

opaque :: proc(x: int) -> int {
	return x
}

main_ :: proc() -> int {
	acc := Vec2{0, 0}
	i := 0
	n := opaque(5)
	for {
		if i >= n do break
		acc.x = acc.x + i
		acc.y = acc.y + 1
		i += 1
	}
	return acc.x * 100 + acc.y
}

main.run_test(t, `mem2reg_struct_accumulator_in_loop`, `
package main

opt_level :: "none"

Vec2 :: struct {
	x: int,
	y: int,
}

opaque :: proc(x: int) -> int {
	return x
}

main :: proc() -> int {
	acc := Vec2{0, 0}
	i := 0
	n := opaque(5)
	for {
		if i >= n do break
		acc.x = acc.x + i
		acc.y = acc.y + 1
		i += 1
	}
	return acc.x * 100 + acc.y
}
`, main_())
}
@(test) mem2reg_nested_struct_promotion :: proc(t: ^testing.T) {



opt_level :: "none"

Inner :: struct {
	x: int,
	y: int,
}

Outer :: struct {
	p: Inner,
	q: Inner,
}

opaque :: proc(x: int) -> int {
	return x
}

main_ :: proc() -> int {
	o := Outer{Inner{opaque(1), opaque(2)}, Inner{opaque(3), opaque(4)}}
	o.p.x = o.q.y
	o.q.x = o.p.y
	return o.p.x * 1000 + o.p.y * 100 + o.q.x * 10 + o.q.y
}

main.run_test(t, `mem2reg_nested_struct_promotion`, `
package main

opt_level :: "none"

Inner :: struct {
	x: int,
	y: int,
}

Outer :: struct {
	p: Inner,
	q: Inner,
}

opaque :: proc(x: int) -> int {
	return x
}

main :: proc() -> int {
	o := Outer{Inner{opaque(1), opaque(2)}, Inner{opaque(3), opaque(4)}}
	o.p.x = o.q.y
	o.q.x = o.p.y
	return o.p.x * 1000 + o.p.y * 100 + o.q.x * 10 + o.q.y
}
`, main_())
}
@(test) mem2reg_struct_copy_promotion :: proc(t: ^testing.T) {



opt_level :: "none"

Vec2 :: struct {
	x: int,
	y: int,
}

opaque :: proc(x: int) -> int {
	return x
}

main_ :: proc() -> int {
	s := Vec2{opaque(3), opaque(4)}
	t := s
	t.x = t.x + 1
	t.y = t.y + 1
	return s.x * 1000 + s.y * 100 + t.x * 10 + t.y
}

main.run_test(t, `mem2reg_struct_copy_promotion`, `
package main

opt_level :: "none"

Vec2 :: struct {
	x: int,
	y: int,
}

opaque :: proc(x: int) -> int {
	return x
}

main :: proc() -> int {
	s := Vec2{opaque(3), opaque(4)}
	t := s
	t.x = t.x + 1
	t.y = t.y + 1
	return s.x * 1000 + s.y * 100 + t.x * 10 + t.y
}
`, main_())
}
@(test) mem2reg_multiple_structs_register_pressure :: proc(t: ^testing.T) {



opt_level :: "none"

Vec2 :: struct {
	x: int,
	y: int,
}

opaque :: proc(x: int) -> int {
	return x
}

main_ :: proc() -> int {
	a := Vec2{opaque(1), opaque(2)}
	b := Vec2{opaque(3), opaque(4)}
	c := Vec2{opaque(5), opaque(6)}
	d := Vec2{opaque(7), opaque(8)}
	a.x = a.x + b.x + c.x + d.x
	b.y = b.y + c.y + d.y + a.y
	return a.x * 100 + b.y + c.x + d.y
}

main.run_test(t, `mem2reg_multiple_structs_register_pressure`, `
package main

opt_level :: "none"

Vec2 :: struct {
	x: int,
	y: int,
}

opaque :: proc(x: int) -> int {
	return x
}

main :: proc() -> int {
	a := Vec2{opaque(1), opaque(2)}
	b := Vec2{opaque(3), opaque(4)}
	c := Vec2{opaque(5), opaque(6)}
	d := Vec2{opaque(7), opaque(8)}
	a.x = a.x + b.x + c.x + d.x
	b.y = b.y + c.y + d.y + a.y
	return a.x * 100 + b.y + c.x + d.y
}
`, main_())
}
@(test) mem2reg_partially_initialized_struct :: proc(t: ^testing.T) {



opt_level :: "none"

Vec3 :: struct {
	x: int,
	y: int,
	z: int,
}

opaque :: proc(x: int) -> int {
	return x
}

main_ :: proc() -> int {
	s := Vec3{}
	s.y = opaque(42)
	return s.x + s.y + s.z
}

main.run_test(t, `mem2reg_partially_initialized_struct`, `
package main

opt_level :: "none"

Vec3 :: struct {
	x: int,
	y: int,
	z: int,
}

opaque :: proc(x: int) -> int {
	return x
}

main :: proc() -> int {
	s := Vec3{}
	s.y = opaque(42)
	return s.x + s.y + s.z
}
`, main_())
}
@(test) mem2reg_struct_returned_then_mutated :: proc(t: ^testing.T) {



opt_level :: "none"

Vec2 :: struct {
	x: int,
	y: int,
}

opaque :: proc(x: int) -> int {
	return x
}

mk :: proc(a: int, b: int) -> Vec2 {
	return {a, b}
}

main_ :: proc() -> int {
	s := mk(opaque(6), opaque(9))
	s.x = s.x + s.y
	return s.x * 100 + s.y
}

main.run_test(t, `mem2reg_struct_returned_then_mutated`, `
package main

opt_level :: "none"

Vec2 :: struct {
	x: int,
	y: int,
}

opaque :: proc(x: int) -> int {
	return x
}

mk :: proc(a: int, b: int) -> Vec2 {
	return {a, b}
}

main :: proc() -> int {
	s := mk(opaque(6), opaque(9))
	s.x = s.x + s.y
	return s.x * 100 + s.y
}
`, main_())
}
@(test) mem2reg_mixed_size_field_promotion :: proc(t: ^testing.T) {



opt_level :: "none"

Mixed :: struct {
	a: u8,
	b: u16,
	c: u32,
	d: i64,
}

opaque :: proc(x: int) -> int {
	return x
}

main_ :: proc() -> int {
	m := Mixed {
		u8(opaque(100)),
		u16(opaque(300)),
		u32(opaque(70000)),
		i64(opaque(500)),
	}
	m.a = m.a + 1
	m.b = m.b + 2
	m.c = m.c + 3
	m.d = m.d + 4
	return int(u64(m.a) + u64(m.b) + u64(m.c) + u64(m.d))
}

main.run_test(t, `mem2reg_mixed_size_field_promotion`, `
package main

opt_level :: "none"

Mixed :: struct {
	a: u8,
	b: u16,
	c: u32,
	d: i64,
}

opaque :: proc(x: int) -> int {
	return x
}

main :: proc() -> int {
	m := Mixed {
		u8(opaque(100)),
		u16(opaque(300)),
		u32(opaque(70000)),
		i64(opaque(500)),
	}
	m.a = m.a + 1
	m.b = m.b + 2
	m.c = m.c + 3
	m.d = m.d + 4
	return int(u64(m.a) + u64(m.b) + u64(m.c) + u64(m.d))
}
`, main_())
}
@(test) mem2reg_struct_feeds_another_struct :: proc(t: ^testing.T) {



opt_level :: "none"

Vec3 :: struct {
	x: int,
	y: int,
	z: int,
}

opaque :: proc(x: int) -> int {
	return x
}

main_ :: proc() -> int {
	s := Vec3{opaque(2), opaque(3), opaque(4)}
	t := Vec3{s.x + s.y, s.y + s.z, s.z + s.x}
	s.x = t.x + t.z
	return s.x * 100 + t.y * 10 + t.x
}

main.run_test(t, `mem2reg_struct_feeds_another_struct`, `
package main

opt_level :: "none"

Vec3 :: struct {
	x: int,
	y: int,
	z: int,
}

opaque :: proc(x: int) -> int {
	return x
}

main :: proc() -> int {
	s := Vec3{opaque(2), opaque(3), opaque(4)}
	t := Vec3{s.x + s.y, s.y + s.z, s.z + s.x}
	s.x = t.x + t.z
	return s.x * 100 + t.y * 10 + t.x
}
`, main_())
}
@(test) mem2reg_struct_field_swap :: proc(t: ^testing.T) {



opt_level :: "none"

Vec2 :: struct {
	x: int,
	y: int,
}

opaque :: proc(x: int) -> int {
	return x
}

main_ :: proc() -> int {
	s := Vec2{opaque(3), opaque(8)}
	s.x, s.y = s.y, s.x
	return s.x * 100 + s.y
}

main.run_test(t, `mem2reg_struct_field_swap`, `
package main

opt_level :: "none"

Vec2 :: struct {
	x: int,
	y: int,
}

opaque :: proc(x: int) -> int {
	return x
}

main :: proc() -> int {
	s := Vec2{opaque(3), opaque(8)}
	s.x, s.y = s.y, s.x
	return s.x * 100 + s.y
}
`, main_())
}
@(test) mem2reg_local_pointer_to_struct_non_escaping :: proc(t: ^testing.T) {



opt_level :: "none"

Vec3 :: struct {
	x: int,
	y: int,
	z: int,
}

opaque :: proc(x: int) -> int {
	return x
}

main_ :: proc() -> int {
	s := Vec3{opaque(1), opaque(2), opaque(3)}
	ptr := &s
	ptr.x = ptr.x + ptr.y
	ptr.z = ptr.z + ptr.x
	return s.x + s.y + s.z
}

main.run_test(t, `mem2reg_local_pointer_to_struct_non_escaping`, `
package main

opt_level :: "none"

Vec3 :: struct {
	x: int,
	y: int,
	z: int,
}

opaque :: proc(x: int) -> int {
	return x
}

main :: proc() -> int {
	s := Vec3{opaque(1), opaque(2), opaque(3)}
	ptr := &s
	ptr.x = ptr.x + ptr.y
	ptr.z = ptr.z + ptr.x
	return s.x + s.y + s.z
}
`, main_())
}
@(test) mem2reg_nested_struct_loop_with_conditional :: proc(t: ^testing.T) {



opt_level :: "none"

Vec2 :: struct {
	x: int,
	y: int,
}

Particle :: struct {
	pos: Vec2,
	vel: Vec2,
}

opaque :: proc(x: int) -> int {
	return x
}

main_ :: proc() -> int {
	p := Particle{Vec2{opaque(0), opaque(0)}, Vec2{opaque(1), opaque(2)}}
	i := 0
	for {
		if i >= 10 do break
		p.pos.x = p.pos.x + p.vel.x
		p.pos.y = p.pos.y + p.vel.y
		if p.pos.x > 5 {
			p.vel.x = p.vel.x + 1
		}
		i += 1
	}
	return p.pos.x * 1000 + p.pos.y
}

main.run_test(t, `mem2reg_nested_struct_loop_with_conditional`, `
package main

opt_level :: "none"

Vec2 :: struct {
	x: int,
	y: int,
}

Particle :: struct {
	pos: Vec2,
	vel: Vec2,
}

opaque :: proc(x: int) -> int {
	return x
}

main :: proc() -> int {
	p := Particle{Vec2{opaque(0), opaque(0)}, Vec2{opaque(1), opaque(2)}}
	i := 0
	for {
		if i >= 10 do break
		p.pos.x = p.pos.x + p.vel.x
		p.pos.y = p.pos.y + p.vel.y
		if p.pos.x > 5 {
			p.vel.x = p.vel.x + 1
		}
		i += 1
	}
	return p.pos.x * 1000 + p.pos.y
}
`, main_())
}
@(test) mem2reg_conditional_store_no_else :: proc(t: ^testing.T) {



opt_level :: "none"

Vec2 :: struct {
	x: int,
	y: int,
}

opaque :: proc(x: int) -> int {
	return x
}

main_ :: proc() -> int {
	s := Vec2{opaque(3), opaque(5)}
	if opaque(1) > 0 {
	} else {
		s.x = 100
	}
	return s.x
}

main.run_test(t, `mem2reg_conditional_store_no_else`, `
package main

opt_level :: "none"

Vec2 :: struct {
	x: int,
	y: int,
}

opaque :: proc(x: int) -> int {
	return x
}

main :: proc() -> int {
	s := Vec2{opaque(3), opaque(5)}
	if opaque(1) > 0 {
	} else {
		s.x = 100
	}
	return s.x
}
`, main_())
}
@(test) mem2reg_conditional_store_empty_then_reads_both :: proc(t: ^testing.T) {



opt_level :: "none"

Vec2 :: struct {
	x: int,
	y: int,
}

opaque :: proc(x: int) -> int {
	return x
}

main_ :: proc() -> int {
	s := Vec2{opaque(5), opaque(7)}
	if opaque(1) > 0 {
	} else {
		s.x = opaque(10)
	}
	return s.x * 100 + s.y
}

main.run_test(t, `mem2reg_conditional_store_empty_then_reads_both`, `
package main

opt_level :: "none"

Vec2 :: struct {
	x: int,
	y: int,
}

opaque :: proc(x: int) -> int {
	return x
}

main :: proc() -> int {
	s := Vec2{opaque(5), opaque(7)}
	if opaque(1) > 0 {
	} else {
		s.x = opaque(10)
	}
	return s.x * 100 + s.y
}
`, main_())
}
@(test) mem2reg_conditional_store_cross_field_after_merge :: proc(t: ^testing.T) {



opt_level :: "none"

Vec2 :: struct {
	x: int,
	y: int,
}

opaque :: proc(x: int) -> int {
	return x
}

main_ :: proc() -> int {
	s := Vec2{opaque(3), opaque(4)}
	if opaque(1) == 1 {
		s.x = opaque(10)
	}
	s.y = s.x + s.y
	return s.x + s.y
}

main.run_test(t, `mem2reg_conditional_store_cross_field_after_merge`, `
package main

opt_level :: "none"

Vec2 :: struct {
	x: int,
	y: int,
}

opaque :: proc(x: int) -> int {
	return x
}

main :: proc() -> int {
	s := Vec2{opaque(3), opaque(4)}
	if opaque(1) == 1 {
		s.x = opaque(10)
	}
	s.y = s.x + s.y
	return s.x + s.y
}
`, main_())
}
@(test) mem2reg_conditional_store_then_call_reads_merge :: proc(t: ^testing.T) {



opt_level :: "none"

Vec2 :: struct {
	x: int,
	y: int,
}

opaque :: proc(x: int) -> int {
	return x
}

main_ :: proc() -> int {
	s := Vec2{opaque(3), opaque(4)}
	if opaque(1) == 1 {
		s.x = opaque(10)
	}
	a := opaque(s.x)
	return s.x + s.y + a
}

main.run_test(t, `mem2reg_conditional_store_then_call_reads_merge`, `
package main

opt_level :: "none"

Vec2 :: struct {
	x: int,
	y: int,
}

opaque :: proc(x: int) -> int {
	return x
}

main :: proc() -> int {
	s := Vec2{opaque(3), opaque(4)}
	if opaque(1) == 1 {
		s.x = opaque(10)
	}
	a := opaque(s.x)
	return s.x + s.y + a
}
`, main_())
}
@(test) mem2reg_loop_continue_carries_field :: proc(t: ^testing.T) {



opt_level :: "none"

S :: struct {
	a: int,
	b: int,
}

opaque :: proc(x: int) -> int {
	return x
}

main_ :: proc() -> int {
	s := S{opaque(1), opaque(0)}
	i := 0
	n := opaque(9)
	for {
		if i >= n do break
		i += 1
		s.a = s.a + 1
		if s.a % 2 == 0 {
			continue
		}
		s.b = s.b + s.a
	}
	return s.a * 100 + s.b
}

main.run_test(t, `mem2reg_loop_continue_carries_field`, `
package main

opt_level :: "none"

S :: struct {
	a: int,
	b: int,
}

opaque :: proc(x: int) -> int {
	return x
}

main :: proc() -> int {
	s := S{opaque(1), opaque(0)}
	i := 0
	n := opaque(9)
	for {
		if i >= n do break
		i += 1
		s.a = s.a + 1
		if s.a % 2 == 0 {
			continue
		}
		s.b = s.b + s.a
	}
	return s.a * 100 + s.b
}
`, main_())
}
@(test) zero_initialized_static_aggregate :: proc(t: ^testing.T) {



opt_level :: "none"

Counters :: struct {
	hits:   int,
	misses: int,
}

main_ :: proc() -> int {
	@(static) buf := [16]u8{}
	@(static) c := Counters{}
	@(static) scale := 3

	i := 0
	for {
		if i >= 16 do break
		buf[i] = u8(i)
		i += 1
	}

	sum := 0
	j := 0
	for {
		if j >= 16 do break
		sum += int(buf[j])
		j += 1
	}

	c.hits = 7
	c.misses = 2

	return sum * scale + c.hits - c.misses
}

main.run_test(t, `zero_initialized_static_aggregate`, `
package main

opt_level :: "none"

Counters :: struct {
	hits:   int,
	misses: int,
}

main :: proc() -> int {
	@(static) buf := [16]u8{}
	@(static) c := Counters{}
	@(static) scale := 3

	i := 0
	for {
		if i >= 16 do break
		buf[i] = u8(i)
		i += 1
	}

	sum := 0
	j := 0
	for {
		if j >= 16 do break
		sum += int(buf[j])
		j += 1
	}

	c.hits = 7
	c.misses = 2

	return sum * scale + c.hits - c.misses
}
`, main_())
}
@(test) free_list_allocator :: proc(t: ^testing.T) {



opt_level :: "none"

MAX_BLOCKS :: 64

Block :: struct {
	offset: int,
	size:   int,
	free:   bool,
}

Allocator :: struct {
	buf:    []u8,
	blocks: [MAX_BLOCKS]Block,
	count:  int,
}

alloc_init :: proc(a: ^Allocator, buf: []u8) {
	a.buf = buf
	a.count = 1
	a.blocks[0] = Block{offset = 0, size = len(buf), free = true}
}

align_up :: proc(x: int, align: int) -> int {
	return (x + align - 1) &~ (align - 1)
}

alloc_off :: proc(a: ^Allocator, size: int, align: int) -> int {
	if size <= 0 do return -1

	i := 0
	for {
		if i >= a.count do break
		b := a.blocks[i]
		if b.free {
			aligned := align_up(b.offset, align)
			pad := aligned - b.offset
			total := pad + size
			if b.size >= total {
				rem := b.size - total

				parts := [3]Block{}
				n := 0
				if pad > 0 {
					parts[n] = Block{offset = b.offset, size = pad, free = true}
					n += 1
				}
				parts[n] = Block{offset = aligned, size = size, free = false}
				n += 1
				if rem > 0 {
					parts[n] = Block {
						offset = aligned + size,
						size   = rem,
						free   = true,
					}
					n += 1
				}

				splice(a, i, n, parts)
				return aligned
			}
		}
		i += 1
	}

	return -1
}

splice :: proc(a: ^Allocator, idx: int, n: int, parts: [3]Block) {
	added := n - 1
	if added > 0 {
		j := a.count - 1
		for {
			if j <= idx do break
			a.blocks[j + added] = a.blocks[j]
			j -= 1
		}
	}
	k := 0
	for {
		if k >= n do break
		a.blocks[idx + k] = parts[k]
		k += 1
	}
	a.count += added
}

alloc_free :: proc(a: ^Allocator, offset: int) -> bool {
	i := 0
	for {
		if i >= a.count do break
		if (a.blocks[i].offset == offset) & (!a.blocks[i].free) {
			a.blocks[i].free = true
			coalesce(a)
			return true
		}
		i += 1
	}
	return false
}

coalesce :: proc(a: ^Allocator) {
	if a.count == 0 do return
	w := 0
	r := 1
	for {
		if r >= a.count do break
		if a.blocks[w].free & a.blocks[r].free {
			a.blocks[w].size += a.blocks[r].size
		} else {
			w += 1
			a.blocks[w] = a.blocks[r]
		}
		r += 1
	}
	a.count = w + 1
}

write_pattern :: proc(s: []u8, seed: u8) {
	i := 0
	for {
		if i >= len(s) do break
		s[i] = u8(int(seed) + i)
		i += 1
	}
}

check_pattern :: proc(s: []u8, seed: u8) -> bool {
	i := 0
	for {
		if i >= len(s) do break
		if s[i] != u8(int(seed) + i) do return false
		i += 1
	}
	return true
}

free_block_count :: proc(a: ^Allocator) -> int {
	c := 0
	i := 0
	for {
		if i >= a.count do break
		if a.blocks[i].free do c += 1
		i += 1
	}
	return c
}

test_coalesce :: proc(buf: []u8) -> bool {
	a: Allocator = {}
	alloc_init(&a, buf)

	x := alloc_off(&a, 100, 1)
	y := alloc_off(&a, 100, 1)
	z := alloc_off(&a, 100, 1)
	if (x != 0) | (y != 100) | (z != 200) do return false

	alloc_free(&a, x)
	alloc_free(&a, z)
	if free_block_count(&a) != 2 do return false

	alloc_free(&a, y)
	if free_block_count(&a) != 1 do return false

	whole := alloc_off(&a, len(buf), 1)
	return whole == 0
}

main_ :: proc() -> int {
	@(static) backing := [1024]u8{}
	@(static) coalesce_buf := [512]u8{}

	a: Allocator = {}
	alloc_init(&a, backing[:])

	score := 0

	o1 := alloc_off(&a, 100, 8)
	o2 := alloc_off(&a, 40, 16)
	o3 := alloc_off(&a, 7, 1)
	o4 := alloc_off(&a, 200, 32)

	if o1 >= 0 do score += 1
	if o2 >= 0 do score += 2
	if o3 >= 0 do score += 4
	if o4 >= 0 do score += 8

	if o2 & 15 == 0 do score += 16
	if o4 & 31 == 0 do score += 32

	s1 := backing[o1:o1 + 100]
	s2 := backing[o2:o2 + 40]
	s3 := backing[o3:o3 + 7]
	s4 := backing[o4:o4 + 200]

	write_pattern(s1, 1)
	write_pattern(s2, 50)
	write_pattern(s3, 100)
	write_pattern(s4, 7)

	if check_pattern(s1, 1) do score += 64
	if check_pattern(s2, 50) do score += 128
	if check_pattern(s3, 100) do score += 256
	if check_pattern(s4, 7) do score += 512

	alloc_free(&a, o2)
	alloc_free(&a, o3)

	if test_coalesce(coalesce_buf[:]) do score += 1024

	o5 := alloc_off(&a, 45, 8)
	if o5 >= 0 do score += 2048
	s5 := backing[o5:o5 + 45]
	write_pattern(s5, 200)
	if check_pattern(s5, 200) do score += 4096

	if check_pattern(s1, 1) do score += 8192

	if alloc_off(&a, 100000, 8) < 0 do score += 16384

	return score
}

main.run_test(t, `free_list_allocator`, `
package main

opt_level :: "none"

MAX_BLOCKS :: 64

Block :: struct {
	offset: int,
	size:   int,
	free:   bool,
}

Allocator :: struct {
	buf:    []u8,
	blocks: [MAX_BLOCKS]Block,
	count:  int,
}

alloc_init :: proc(a: ^Allocator, buf: []u8) {
	a.buf = buf
	a.count = 1
	a.blocks[0] = Block{offset = 0, size = len(buf), free = true}
}

align_up :: proc(x: int, align: int) -> int {
	return (x + align - 1) &~ (align - 1)
}

alloc_off :: proc(a: ^Allocator, size: int, align: int) -> int {
	if size <= 0 do return -1

	i := 0
	for {
		if i >= a.count do break
		b := a.blocks[i]
		if b.free {
			aligned := align_up(b.offset, align)
			pad := aligned - b.offset
			total := pad + size
			if b.size >= total {
				rem := b.size - total

				parts := [3]Block{}
				n := 0
				if pad > 0 {
					parts[n] = Block{offset = b.offset, size = pad, free = true}
					n += 1
				}
				parts[n] = Block{offset = aligned, size = size, free = false}
				n += 1
				if rem > 0 {
					parts[n] = Block {
						offset = aligned + size,
						size   = rem,
						free   = true,
					}
					n += 1
				}

				splice(a, i, n, parts)
				return aligned
			}
		}
		i += 1
	}

	return -1
}

splice :: proc(a: ^Allocator, idx: int, n: int, parts: [3]Block) {
	added := n - 1
	if added > 0 {
		j := a.count - 1
		for {
			if j <= idx do break
			a.blocks[j + added] = a.blocks[j]
			j -= 1
		}
	}
	k := 0
	for {
		if k >= n do break
		a.blocks[idx + k] = parts[k]
		k += 1
	}
	a.count += added
}

alloc_free :: proc(a: ^Allocator, offset: int) -> bool {
	i := 0
	for {
		if i >= a.count do break
		if (a.blocks[i].offset == offset) & (!a.blocks[i].free) {
			a.blocks[i].free = true
			coalesce(a)
			return true
		}
		i += 1
	}
	return false
}

coalesce :: proc(a: ^Allocator) {
	if a.count == 0 do return
	w := 0
	r := 1
	for {
		if r >= a.count do break
		if a.blocks[w].free & a.blocks[r].free {
			a.blocks[w].size += a.blocks[r].size
		} else {
			w += 1
			a.blocks[w] = a.blocks[r]
		}
		r += 1
	}
	a.count = w + 1
}

write_pattern :: proc(s: []u8, seed: u8) {
	i := 0
	for {
		if i >= len(s) do break
		s[i] = u8(int(seed) + i)
		i += 1
	}
}

check_pattern :: proc(s: []u8, seed: u8) -> bool {
	i := 0
	for {
		if i >= len(s) do break
		if s[i] != u8(int(seed) + i) do return false
		i += 1
	}
	return true
}

free_block_count :: proc(a: ^Allocator) -> int {
	c := 0
	i := 0
	for {
		if i >= a.count do break
		if a.blocks[i].free do c += 1
		i += 1
	}
	return c
}

test_coalesce :: proc(buf: []u8) -> bool {
	a: Allocator = {}
	alloc_init(&a, buf)

	x := alloc_off(&a, 100, 1)
	y := alloc_off(&a, 100, 1)
	z := alloc_off(&a, 100, 1)
	if (x != 0) | (y != 100) | (z != 200) do return false

	alloc_free(&a, x)
	alloc_free(&a, z)
	if free_block_count(&a) != 2 do return false

	alloc_free(&a, y)
	if free_block_count(&a) != 1 do return false

	whole := alloc_off(&a, len(buf), 1)
	return whole == 0
}

main :: proc() -> int {
	@(static) backing := [1024]u8{}
	@(static) coalesce_buf := [512]u8{}

	a: Allocator = {}
	alloc_init(&a, backing[:])

	score := 0

	o1 := alloc_off(&a, 100, 8)
	o2 := alloc_off(&a, 40, 16)
	o3 := alloc_off(&a, 7, 1)
	o4 := alloc_off(&a, 200, 32)

	if o1 >= 0 do score += 1
	if o2 >= 0 do score += 2
	if o3 >= 0 do score += 4
	if o4 >= 0 do score += 8

	if o2 & 15 == 0 do score += 16
	if o4 & 31 == 0 do score += 32

	s1 := backing[o1:o1 + 100]
	s2 := backing[o2:o2 + 40]
	s3 := backing[o3:o3 + 7]
	s4 := backing[o4:o4 + 200]

	write_pattern(s1, 1)
	write_pattern(s2, 50)
	write_pattern(s3, 100)
	write_pattern(s4, 7)

	if check_pattern(s1, 1) do score += 64
	if check_pattern(s2, 50) do score += 128
	if check_pattern(s3, 100) do score += 256
	if check_pattern(s4, 7) do score += 512

	alloc_free(&a, o2)
	alloc_free(&a, o3)

	if test_coalesce(coalesce_buf[:]) do score += 1024

	o5 := alloc_off(&a, 45, 8)
	if o5 >= 0 do score += 2048
	s5 := backing[o5:o5 + 45]
	write_pattern(s5, 200)
	if check_pattern(s5, 200) do score += 4096

	if check_pattern(s1, 1) do score += 8192

	if alloc_off(&a, 100000, 8) < 0 do score += 16384

	return score
}
`, main_())
}
@(test) multi_return_two_scalars_destructured :: proc(t: ^testing.T) {



opt_level :: "none"

divmod :: proc(a: int, b: int) -> (int, int) {
	return a / b, a % b
}

main_ :: proc() -> int {
	q, r := divmod(47, 5)
	return q * 100 + r
}

main.run_test(t, `multi_return_two_scalars_destructured`, `
package main

opt_level :: "none"

divmod :: proc(a: int, b: int) -> (int, int) {
	return a / b, a % b
}

main :: proc() -> int {
	q, r := divmod(47, 5)
	return q * 100 + r
}
`, main_())
}
@(test) multi_return_two_scalars_into_existing_vars :: proc(t: ^testing.T) {



opt_level :: "none"

swap2 :: proc(a: int, b: int) -> (int, int) {
	return b, a
}

main_ :: proc() -> int {
	x := 3
	y := 7
	x, y = swap2(x, y)
	return x * 100 + y
}

main.run_test(t, `multi_return_two_scalars_into_existing_vars`, `
package main

opt_level :: "none"

swap2 :: proc(a: int, b: int) -> (int, int) {
	return b, a
}

main :: proc() -> int {
	x := 3
	y := 7
	x, y = swap2(x, y)
	return x * 100 + y
}
`, main_())
}
@(test) multi_return_four_i32_fit_in_registers :: proc(t: ^testing.T) {



opt_level :: "none"

four32 :: proc(base: i32) -> (i32, i32, i32, i32) {
	return base + 1, base + 2, base + 3, base + 4
}

main_ :: proc() -> int {
	a, b, c, d := four32(10)
	return int(a) * 1000 + int(b) * 100 + int(c) * 10 + int(d)
}

main.run_test(t, `multi_return_four_i32_fit_in_registers`, `
package main

opt_level :: "none"

four32 :: proc(base: i32) -> (i32, i32, i32, i32) {
	return base + 1, base + 2, base + 3, base + 4
}

main :: proc() -> int {
	a, b, c, d := four32(10)
	return int(a) * 1000 + int(b) * 100 + int(c) * 10 + int(d)
}
`, main_())
}
@(test) multi_return_three_ints_overflow_registers :: proc(t: ^testing.T) {



opt_level :: "none"

three :: proc(a: int, b: int, c: int) -> (int, int, int) {
	return a + b, b + c, a + c
}

main_ :: proc() -> int {
	x, y, z := three(1, 2, 3)
	return x * 100 + y * 10 + z
}

main.run_test(t, `multi_return_three_ints_overflow_registers`, `
package main

opt_level :: "none"

three :: proc(a: int, b: int, c: int) -> (int, int, int) {
	return a + b, b + c, a + c
}

main :: proc() -> int {
	x, y, z := three(1, 2, 3)
	return x * 100 + y * 10 + z
}
`, main_())
}
@(test) multi_return_four_ints_overflow_registers :: proc(t: ^testing.T) {



opt_level :: "none"

four :: proc(a: int) -> (int, int, int, int) {
	return a, a * 2, a * 3, a * 4
}

main_ :: proc() -> int {
	p, q, r, s := four(5)
	return p + q + r + s
}

main.run_test(t, `multi_return_four_ints_overflow_registers`, `
package main

opt_level :: "none"

four :: proc(a: int) -> (int, int, int, int) {
	return a, a * 2, a * 3, a * 4
}

main :: proc() -> int {
	p, q, r, s := four(5)
	return p + q + r + s
}
`, main_())
}
@(test) multi_return_last_value_large_struct :: proc(t: ^testing.T) {



opt_level :: "none"

Big :: struct {
	a: int,
	b: int,
	c: int,
	d: int,
}

split :: proc(seed: int) -> (int, int, Big) {
	return seed + 1, seed + 2, Big{seed + 3, seed + 4, seed + 5, seed + 6}
}

main_ :: proc() -> int {
	first, second, big := split(10)
	return first * 1000 + second * 100 + big.a + big.b + big.c + big.d
}

main.run_test(t, `multi_return_last_value_large_struct`, `
package main

opt_level :: "none"

Big :: struct {
	a: int,
	b: int,
	c: int,
	d: int,
}

split :: proc(seed: int) -> (int, int, Big) {
	return seed + 1, seed + 2, Big{seed + 3, seed + 4, seed + 5, seed + 6}
}

main :: proc() -> int {
	first, second, big := split(10)
	return first * 1000 + second * 100 + big.a + big.b + big.c + big.d
}
`, main_())
}
@(test) multi_return_scalar_and_small_struct :: proc(t: ^testing.T) {



opt_level :: "none"

Pair :: struct {
	x: i32,
	y: i32,
}

mix :: proc(n: int) -> (int, Pair) {
	return n * 2, Pair{i32(n), i32(n + 1)}
}

main_ :: proc() -> int {
	scalar, pair := mix(7)
	return scalar * 100 + int(pair.x) * 10 + int(pair.y)
}

main.run_test(t, `multi_return_scalar_and_small_struct`, `
package main

opt_level :: "none"

Pair :: struct {
	x: i32,
	y: i32,
}

mix :: proc(n: int) -> (int, Pair) {
	return n * 2, Pair{i32(n), i32(n + 1)}
}

main :: proc() -> int {
	scalar, pair := mix(7)
	return scalar * 100 + int(pair.x) * 10 + int(pair.y)
}
`, main_())
}
@(test) multi_return_ignore_some_values :: proc(t: ^testing.T) {



opt_level :: "none"

stats :: proc(a: int, b: int, c: int) -> (int, int, int) {
	return a + b + c, a * b * c, a - b - c
}

main_ :: proc() -> int {
	sum, _, _ := stats(2, 3, 4)
	_, prod, _ := stats(2, 3, 4)
	return sum * 100 + prod
}

main.run_test(t, `multi_return_ignore_some_values`, `
package main

opt_level :: "none"

stats :: proc(a: int, b: int, c: int) -> (int, int, int) {
	return a + b + c, a * b * c, a - b - c
}

main :: proc() -> int {
	sum, _, _ := stats(2, 3, 4)
	_, prod, _ := stats(2, 3, 4)
	return sum * 100 + prod
}
`, main_())
}
@(test) multi_return_feeds_directly_into_call :: proc(t: ^testing.T) {



opt_level :: "none"

produce :: proc(seed: int) -> (int, int, int) {
	return seed, seed + 1, seed + 2
}

consume :: proc(a: int, b: int, c: int) -> int {
	return a * 100 + b * 10 + c
}

main_ :: proc() -> int {
	return consume(produce(4))
}

main.run_test(t, `multi_return_feeds_directly_into_call`, `
package main

opt_level :: "none"

produce :: proc(seed: int) -> (int, int, int) {
	return seed, seed + 1, seed + 2
}

consume :: proc(a: int, b: int, c: int) -> int {
	return a * 100 + b * 10 + c
}

main :: proc() -> int {
	return consume(produce(4))
}
`, main_())
}
@(test) multi_return_with_input_params :: proc(t: ^testing.T) {



opt_level :: "none"

with_args :: proc(a: int, b: int, c: int, d: int) -> (int, int, int) {
	return a + b, c + d, a + d
}

main_ :: proc() -> int {
	x, y, z := with_args(1, 2, 3, 4)
	return x * 100 + y * 10 + z
}

main.run_test(t, `multi_return_with_input_params`, `
package main

opt_level :: "none"

with_args :: proc(a: int, b: int, c: int, d: int) -> (int, int, int) {
	return a + b, c + d, a + d
}

main :: proc() -> int {
	x, y, z := with_args(1, 2, 3, 4)
	return x * 100 + y * 10 + z
}
`, main_())
}
@(test) multi_return_two_small_structs :: proc(t: ^testing.T) {



opt_level :: "none"

Small :: struct {
	a: i32,
	b: i32,
}

two_small :: proc(n: i32) -> (Small, Small) {
	return Small{n, n + 1}, Small{n + 2, n + 3}
}

main_ :: proc() -> int {
	p, q := two_small(10)
	return int(p.a) * 1000 + int(p.b) * 100 + int(q.a) * 10 + int(q.b)
}

main.run_test(t, `multi_return_two_small_structs`, `
package main

opt_level :: "none"

Small :: struct {
	a: i32,
	b: i32,
}

two_small :: proc(n: i32) -> (Small, Small) {
	return Small{n, n + 1}, Small{n + 2, n + 3}
}

main :: proc() -> int {
	p, q := two_small(10)
	return int(p.a) * 1000 + int(p.b) * 100 + int(q.a) * 10 + int(q.b)
}
`, main_())
}
@(test) multi_return_used_in_expression :: proc(t: ^testing.T) {



opt_level :: "none"

opaque :: proc(x: int) -> int {
	return x
}

minmax :: proc(a: int, b: int) -> (int, int) {
	if a < b do return a, b
	return b, a
}

main_ :: proc() -> int {
	lo, hi := minmax(opaque(9), opaque(4))
	span := (hi - lo) * 2 + lo
	return span
}

main.run_test(t, `multi_return_used_in_expression`, `
package main

opt_level :: "none"

opaque :: proc(x: int) -> int {
	return x
}

minmax :: proc(a: int, b: int) -> (int, int) {
	if a < b do return a, b
	return b, a
}

main :: proc() -> int {
	lo, hi := minmax(opaque(9), opaque(4))
	span := (hi - lo) * 2 + lo
	return span
}
`, main_())
}
@(test) multi_return_mixed_sizes_with_large_tail :: proc(t: ^testing.T) {



opt_level :: "none"

Big :: struct {
	a: int,
	b: int,
	c: int,
}

many :: proc(base: int, extra: int) -> (int, i32, Big) {
	return base + extra, i32(base), Big{base, base + 1, extra}
}

main_ :: proc() -> int {
	first, second, big := many(5, 100)
	return first + int(second) * 10 + big.a + big.b + big.c
}

main.run_test(t, `multi_return_mixed_sizes_with_large_tail`, `
package main

opt_level :: "none"

Big :: struct {
	a: int,
	b: int,
	c: int,
}

many :: proc(base: int, extra: int) -> (int, i32, Big) {
	return base + extra, i32(base), Big{base, base + 1, extra}
}

main :: proc() -> int {
	first, second, big := many(5, 100)
	return first + int(second) * 10 + big.a + big.b + big.c
}
`, main_())
}
@(test) multi_pointers :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
	arr: [4]int = {1, 2, 3, 4}
	ptr := raw_data(&arr)
	slc := ptr[:2]
	ptr = raw_data(slc)
	return ptr[0] + ptr[1]
}

main.run_test(t, `multi_pointers`, `
package main

opt_level :: "none"

main :: proc() -> int {
	arr: [4]int = {1, 2, 3, 4}
	ptr := raw_data(&arr)
	slc := ptr[:2]
	ptr = raw_data(slc)
	return ptr[0] + ptr[1]
}
`, main_())
}
@(test) memopt_crash_on_indexing_digits :: proc(t: ^testing.T) {



opt_level :: "none"

f :: proc(buf: []u8, value: u64, base: int) -> int {
	digits := "0123456789abcdefghijklmnopqrstuvxyz"

	b := u64(base)
	tmp: [65]u8 = {}
	v := value
	n := 0
	for {
		if v == 0 do break
		d := v % b
		tmp[n] = digits[int(d)]
		v /= b
		n += 1
	}
	i := 0
	for {
		if i >= n do break
		buf[i] = tmp[n - 1 - i]
		i += 1
	}
	return n
}

main_ :: proc() -> int {
	buf: [65]u8 = {}
	n := f(buf[:], 255, 16)
	return int(buf[0]) + int(buf[1]) + n  // 'f'+'f'+2 = 102+102+2=206
}

main.run_test(t, `memopt_crash_on_indexing_digits`, `
package main

opt_level :: "none"

f :: proc(buf: []u8, value: u64, base: int) -> int {
	digits := "0123456789abcdefghijklmnopqrstuvxyz"

	b := u64(base)
	tmp: [65]u8 = {}
	v := value
	n := 0
	for {
		if v == 0 do break
		d := v % b
		tmp[n] = digits[int(d)]
		v /= b
		n += 1
	}
	i := 0
	for {
		if i >= n do break
		buf[i] = tmp[n - 1 - i]
		i += 1
	}
	return n
}

main :: proc() -> int {
	buf: [65]u8 = {}
	n := f(buf[:], 255, 16)
	return int(buf[0]) + int(buf[1]) + n  // 'f'+'f'+2 = 102+102+2=206
}
`, main_())
}
@(test) basic_float_arithmetic :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
	return int(1.5 + 2.5 * 3.0)
}

main.run_test(t, `basic_float_arithmetic`, `
package main

opt_level :: "none"

main :: proc() -> int {
	return int(1.5 + 2.5 * 3.0)
}
`, main_())
}
@(test) float_force_spill_with_simple_addition :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
	x: f64 = 1
	return int(
		((((x + x) + (x + x)) + ((x + x) + (x + x))) +
		(((x + x) + (x + x)) + ((x + x) + (x + x)))) +
		((((x + x) + (x + x)) + ((x + x) + (x + x))) +
		(((x + x) + (x + x)) + ((x + x) + (x + x)))),
	)
}

main.run_test(t, `float_force_spill_with_simple_addition`, `
package main

opt_level :: "none"

main :: proc() -> int {
	x: f64 = 1
	return int(
		((((x + x) + (x + x)) + ((x + x) + (x + x))) +
		(((x + x) + (x + x)) + ((x + x) + (x + x)))) +
		((((x + x) + (x + x)) + ((x + x) + (x + x))) +
		(((x + x) + (x + x)) + ((x + x) + (x + x)))),
	)
}
`, main_())
}
@(test) all_f32_operators :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
	r: f32 = 0

	a: f32 = 20
	b: f32 = 6
	n: f32 = 0 - 7

	r += a + b
	r += a - b
	r += a * b
	r += a / b
	r += n / b
	r += n * b
	r += -a
	r += -n

	if a > b do r += 1
	if b < a do r += 2
	if a >= b do r += 4
	if a <= b do r += 8
	if a == a do r += 16
	if a != b do r += 32
	if n < b do r += 64
	if n <= n do r += 128

	return int(r)
}

main.run_test(t, `all_f32_operators`, `
package main

opt_level :: "none"

main :: proc() -> int {
	r: f32 = 0

	a: f32 = 20
	b: f32 = 6
	n: f32 = 0 - 7

	r += a + b
	r += a - b
	r += a * b
	r += a / b
	r += n / b
	r += n * b
	r += -a
	r += -n

	if a > b do r += 1
	if b < a do r += 2
	if a >= b do r += 4
	if a <= b do r += 8
	if a == a do r += 16
	if a != b do r += 32
	if n < b do r += 64
	if n <= n do r += 128

	return int(r)
}
`, main_())
}
@(test) all_f64_operators :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
	r: f64 = 0

	a: f64 = 20
	b: f64 = 6
	n: f64 = 0 - 7

	r += a + b
	r += a - b
	r += a * b
	r += a / b
	r += n / b
	r += n * b
	r += -a
	r += -n

	if a > b do r += 1
	if b < a do r += 2
	if a >= b do r += 4
	if a <= b do r += 8
	if a == a do r += 16
	if a != b do r += 32
	if n < b do r += 64
	if n <= n do r += 128

	return int(r)
}

main.run_test(t, `all_f64_operators`, `
package main

opt_level :: "none"

main :: proc() -> int {
	r: f64 = 0

	a: f64 = 20
	b: f64 = 6
	n: f64 = 0 - 7

	r += a + b
	r += a - b
	r += a * b
	r += a / b
	r += n / b
	r += n * b
	r += -a
	r += -n

	if a > b do r += 1
	if b < a do r += 2
	if a >= b do r += 4
	if a <= b do r += 8
	if a == a do r += 16
	if a != b do r += 32
	if n < b do r += 64
	if n <= n do r += 128

	return int(r)
}
`, main_())
}
@(test) float_ops_with_constants :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
	a := opaque(12)

	r: f32 = 0

	r += a * 2.0
	r += a + 3.0
	r += a - 1.5
	r += a / 4.0

	return int(r)
}

opaque :: proc(i: f32) -> f32 {
	return i
}

main.run_test(t, `float_ops_with_constants`, `
package main

opt_level :: "none"

main :: proc() -> int {
	a := opaque(12)

	r: f32 = 0

	r += a * 2.0
	r += a + 3.0
	r += a - 1.5
	r += a / 4.0

	return int(r)
}

opaque :: proc(i: f32) -> f32 {
	return i
}
`, main_())
}
@(test) float_ops_through_pointers :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
	a: f32 = 12
	pa := &a
	pa^ = pa^ * 2.0

	b: f64 = 10
	c: f64 = 6

	add_into(&b, 5.0)
	mul_into(&c, 3.0)

	return int(a + f32(b) + f32(c))
}

add_into :: proc(ptr: ^f64, v: f64) -> f64 {
	ptr^ = ptr^ + v
	return ptr^
}

mul_into :: proc(ptr: ^f64, v: f64) -> f64 {
	ptr^ = ptr^ * v
	return ptr^
}

main.run_test(t, `float_ops_through_pointers`, `
package main

opt_level :: "none"

main :: proc() -> int {
	a: f32 = 12
	pa := &a
	pa^ = pa^ * 2.0

	b: f64 = 10
	c: f64 = 6

	add_into(&b, 5.0)
	mul_into(&c, 3.0)

	return int(a + f32(b) + f32(c))
}

add_into :: proc(ptr: ^f64, v: f64) -> f64 {
	ptr^ = ptr^ + v
	return ptr^
}

mul_into :: proc(ptr: ^f64, v: f64) -> f64 {
	ptr^ = ptr^ * v
	return ptr^
}
`, main_())
}
@(test) float_ops_sized_through_pointers :: proc(t: ^testing.T) {



opt_level :: "none"

add32 :: proc(ptr: ^f32, v: f32) -> f32 {
	ptr^ = ptr^ + v
	return ptr^
}

sub32 :: proc(ptr: ^f32, v: f32) -> f32 {
	ptr^ = ptr^ - v
	return ptr^
}

mul32 :: proc(ptr: ^f32, v: f32) -> f32 {
	ptr^ = ptr^ * v
	return ptr^
}

div32 :: proc(ptr: ^f32, v: f32) -> f32 {
	ptr^ = ptr^ / v
	return ptr^
}

add64 :: proc(ptr: ^f64, v: f64) -> f64 {
	ptr^ = ptr^ + v
	return ptr^
}

sub64 :: proc(ptr: ^f64, v: f64) -> f64 {
	ptr^ = ptr^ - v
	return ptr^
}

mul64 :: proc(ptr: ^f64, v: f64) -> f64 {
	ptr^ = ptr^ * v
	return ptr^
}

div64 :: proc(ptr: ^f64, v: f64) -> f64 {
	ptr^ = ptr^ / v
	return ptr^
}

main_ :: proc() -> int {
	a: f32 = 8
	add32(&a, 4)
	sub32(&a, 2)
	mul32(&a, 3)
	div32(&a, 5)

	b: f64 = 100
	add64(&b, 20)
	sub64(&b, 40)
	mul64(&b, 2)
	div64(&b, 4)

	return int(a + f32(b))
}

main.run_test(t, `float_ops_sized_through_pointers`, `
package main

opt_level :: "none"

add32 :: proc(ptr: ^f32, v: f32) -> f32 {
	ptr^ = ptr^ + v
	return ptr^
}

sub32 :: proc(ptr: ^f32, v: f32) -> f32 {
	ptr^ = ptr^ - v
	return ptr^
}

mul32 :: proc(ptr: ^f32, v: f32) -> f32 {
	ptr^ = ptr^ * v
	return ptr^
}

div32 :: proc(ptr: ^f32, v: f32) -> f32 {
	ptr^ = ptr^ / v
	return ptr^
}

add64 :: proc(ptr: ^f64, v: f64) -> f64 {
	ptr^ = ptr^ + v
	return ptr^
}

sub64 :: proc(ptr: ^f64, v: f64) -> f64 {
	ptr^ = ptr^ - v
	return ptr^
}

mul64 :: proc(ptr: ^f64, v: f64) -> f64 {
	ptr^ = ptr^ * v
	return ptr^
}

div64 :: proc(ptr: ^f64, v: f64) -> f64 {
	ptr^ = ptr^ / v
	return ptr^
}

main :: proc() -> int {
	a: f32 = 8
	add32(&a, 4)
	sub32(&a, 2)
	mul32(&a, 3)
	div32(&a, 5)

	b: f64 = 100
	add64(&b, 20)
	sub64(&b, 40)
	mul64(&b, 2)
	div64(&b, 4)

	return int(a + f32(b))
}
`, main_())
}
@(test) float_unary_neg :: proc(t: ^testing.T) {



opt_level :: "none"

neg32_reg :: proc(x: f32) -> f32 {
	return -x
}

neg64_reg :: proc(x: f64) -> f64 {
	return -x
}

neg32 :: proc(x: ^f32) -> f32 {
	x^ = -x^
	return x^
}

neg64 :: proc(x: ^f64) -> f64 {
	x^ = -x^
	return x^
}

main_ :: proc() -> int {
	a: f32 = 5.5
	b: f64 = 10.25

	r: f64 = 0

	r += f64(neg32_reg(7.5))
	r += neg64_reg(3.25)
	r += f64(neg32(&a))
	r += neg64(&b)
	r += f64(a)
	r += b

	return int(r)
}

main.run_test(t, `float_unary_neg`, `
package main

opt_level :: "none"

neg32_reg :: proc(x: f32) -> f32 {
	return -x
}

neg64_reg :: proc(x: f64) -> f64 {
	return -x
}

neg32 :: proc(x: ^f32) -> f32 {
	x^ = -x^
	return x^
}

neg64 :: proc(x: ^f64) -> f64 {
	x^ = -x^
	return x^
}

main :: proc() -> int {
	a: f32 = 5.5
	b: f64 = 10.25

	r: f64 = 0

	r += f64(neg32_reg(7.5))
	r += neg64_reg(3.25)
	r += f64(neg32(&a))
	r += neg64(&b)
	r += f64(a)
	r += b

	return int(r)
}
`, main_())
}
@(test) float_comparison_peepholes :: proc(t: ^testing.T) {



opt_level :: "none"

opaque32 :: proc(x: f32) -> f32 {
	return x
}

test_f32 :: proc(a: f32, b: f32) -> int {
	if a == b do return 1
	if a != b do return 2

	if a < b do return 3
	if a >= b do return 4

	if a > b do return 5
	if a <= b do return 6

	return 0
}

test_f64 :: proc(a: f64, b: f64) -> int {
	if a == b do return 10
	if a != b do return 20

	if a < b do return 30
	if a >= b do return 40

	if a > b do return 50
	if a <= b do return 60

	return 0
}

test_mixed_patterns :: proc(x: f32) -> int {
	a := opaque32(x)
	b := opaque32(x + 1)

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

main_ :: proc() -> int {
	r := 0

	r += test_f32(10, 20)
	r += test_f32(20, 20)
	r += test_f32(30, 10)

	r += test_f64(10, 20)
	r += test_f64(20, 20)
	r += test_f64(30, 10)

	r += test_mixed_patterns(42)

	return r
}

main.run_test(t, `float_comparison_peepholes`, `
package main

opt_level :: "none"

opaque32 :: proc(x: f32) -> f32 {
	return x
}

test_f32 :: proc(a: f32, b: f32) -> int {
	if a == b do return 1
	if a != b do return 2

	if a < b do return 3
	if a >= b do return 4

	if a > b do return 5
	if a <= b do return 6

	return 0
}

test_f64 :: proc(a: f64, b: f64) -> int {
	if a == b do return 10
	if a != b do return 20

	if a < b do return 30
	if a >= b do return 40

	if a > b do return 50
	if a <= b do return 60

	return 0
}

test_mixed_patterns :: proc(x: f32) -> int {
	a := opaque32(x)
	b := opaque32(x + 1)

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

	r += test_f32(10, 20)
	r += test_f32(20, 20)
	r += test_f32(30, 10)

	r += test_f64(10, 20)
	r += test_f64(20, 20)
	r += test_f64(30, 10)

	r += test_mixed_patterns(42)

	return r
}
`, main_())
}
@(test) float_comparison_with_load :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
	v: f32 = 1
	c: f32 = 0 - 1
	return cmps(0 - 1, &v) + cmps(1, &v) +
		cmps(0 - 1, &c) + cmps(1, &c) +
		imm_cmps(&v) + imm_cmps(&c)
}

imm_cmps :: proc(b: ^f32) -> int {
	r := 0

	if 0 == b^ do r += 1
	if 0 != b^ do r += 2
	if 0 >= b^ do r += 4
	if 0 <= b^ do r += 8
	if 0 > b^ do r += 16
	if 0 < b^ do r += 32

	return r
}

cmps :: proc(a: f32, b: ^f32) -> int {
	r := 0

	if a == b^ do r += 1
	if a != b^ do r += 2
	if a >= b^ do r += 4
	if a <= b^ do r += 8
	if a > b^ do r += 16
	if a < b^ do r += 32

	return r
}

main.run_test(t, `float_comparison_with_load`, `
package main

opt_level :: "none"

main :: proc() -> int {
	v: f32 = 1
	c: f32 = 0 - 1
	return cmps(0 - 1, &v) + cmps(1, &v) +
		cmps(0 - 1, &c) + cmps(1, &c) +
		imm_cmps(&v) + imm_cmps(&c)
}

imm_cmps :: proc(b: ^f32) -> int {
	r := 0

	if 0 == b^ do r += 1
	if 0 != b^ do r += 2
	if 0 >= b^ do r += 4
	if 0 <= b^ do r += 8
	if 0 > b^ do r += 16
	if 0 < b^ do r += 32

	return r
}

cmps :: proc(a: f32, b: ^f32) -> int {
	r := 0

	if a == b^ do r += 1
	if a != b^ do r += 2
	if a >= b^ do r += 4
	if a <= b^ do r += 8
	if a > b^ do r += 16
	if a < b^ do r += 32

	return r
}
`, main_())
}
@(test) float_conversions :: proc(t: ^testing.T) {



opt_level :: "none"

opaque :: proc(x: int) -> int {
	return x
}

main_ :: proc() -> int {
	r := 0

	{
		a: f32 = 3.5
		b: f64 = f64(a)
		c: f32 = f32(b + 2.5)
		r += int(c)
	}

	{
		i8v: i8 = i8(opaque(0 - 100))
		i16v: i16 = i16(opaque(0 - 3000))
		i32v: i32 = i32(opaque(0 - 70000))
		i64v: i64 = i64(opaque(0 - 5000000))

		r += int(f32(i8v))
		r += int(f64(i8v))
		r += int(f32(i16v))
		r += int(f64(i16v))
		r += int(f32(i32v))
		r += int(f64(i32v))
		r += int(f32(i64v))
		r += int(f64(i64v))
	}

	{
		u8v: u8 = u8(opaque(200))
		u16v: u16 = u16(opaque(60000))
		u32v: u32 = u32(opaque(4000000))
		u64v: u64 = u64(opaque(7000000))

		r += int(f32(u8v))
		r += int(f64(u8v))
		r += int(f32(u16v))
		r += int(f64(u16v))
		r += int(f32(u32v))
		r += int(f64(u32v))
		r += int(f32(u64v))
		r += int(f64(u64v))
	}

	{
		a: f32 = 7.9
		b: f64 = 0 - 12.7
		r += int(i32(a))
		r += int(i64(a))
		r += int(i32(b))
		r += int(i64(b))
	}

	{
		a: f64 = 250.6
		b: f32 = 65000.0
		r += int(u8(a))
		r += int(u16(b))
		r += int(u32(a))
		r += int(u64(a))
	}

	return r
}

main.run_test(t, `float_conversions`, `
package main

opt_level :: "none"

opaque :: proc(x: int) -> int {
	return x
}

main :: proc() -> int {
	r := 0

	{
		a: f32 = 3.5
		b: f64 = f64(a)
		c: f32 = f32(b + 2.5)
		r += int(c)
	}

	{
		i8v: i8 = i8(opaque(0 - 100))
		i16v: i16 = i16(opaque(0 - 3000))
		i32v: i32 = i32(opaque(0 - 70000))
		i64v: i64 = i64(opaque(0 - 5000000))

		r += int(f32(i8v))
		r += int(f64(i8v))
		r += int(f32(i16v))
		r += int(f64(i16v))
		r += int(f32(i32v))
		r += int(f64(i32v))
		r += int(f32(i64v))
		r += int(f64(i64v))
	}

	{
		u8v: u8 = u8(opaque(200))
		u16v: u16 = u16(opaque(60000))
		u32v: u32 = u32(opaque(4000000))
		u64v: u64 = u64(opaque(7000000))

		r += int(f32(u8v))
		r += int(f64(u8v))
		r += int(f32(u16v))
		r += int(f64(u16v))
		r += int(f32(u32v))
		r += int(f64(u32v))
		r += int(f32(u64v))
		r += int(f64(u64v))
	}

	{
		a: f32 = 7.9
		b: f64 = 0 - 12.7
		r += int(i32(a))
		r += int(i64(a))
		r += int(i32(b))
		r += int(i64(b))
	}

	{
		a: f64 = 250.6
		b: f32 = 65000.0
		r += int(u8(a))
		r += int(u16(b))
		r += int(u32(a))
		r += int(u64(a))
	}

	return r
}
`, main_())
}
@(test) float_loads_and_stores_of_different_sizes :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
	{
		vl: f32 = 0
		ptr := &vl
		ptr^ = 1.5
		if ptr^ != 1.5 do return 1
	}

	{
		vl: f64 = 0
		ptr := &vl
		ptr^ = 2.25
		if ptr^ != 2.25 do return 2
	}

	{
		vl: f32 = 0
		ptr := &vl
		ptr^ = 0 - 3.5
		if ptr^ != 0 - 3.5 do return 3
	}

	{
		vl: f64 = 0
		ptr := &vl
		ptr^ = 0 - 4.75
		if ptr^ != 0 - 4.75 do return 4
	}

	return 0
}

main.run_test(t, `float_loads_and_stores_of_different_sizes`, `
package main

opt_level :: "none"

main :: proc() -> int {
	{
		vl: f32 = 0
		ptr := &vl
		ptr^ = 1.5
		if ptr^ != 1.5 do return 1
	}

	{
		vl: f64 = 0
		ptr := &vl
		ptr^ = 2.25
		if ptr^ != 2.25 do return 2
	}

	{
		vl: f32 = 0
		ptr := &vl
		ptr^ = 0 - 3.5
		if ptr^ != 0 - 3.5 do return 3
	}

	{
		vl: f64 = 0
		ptr := &vl
		ptr^ = 0 - 4.75
		if ptr^ != 0 - 4.75 do return 4
	}

	return 0
}
`, main_())
}
@(test) float_variables_that_create_register_pressure :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
	x: f64 = 0

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

	b0 := (a0  + a15) * 0.5 + a1
	b1 := (a1  + a14) * 0.5 + a2
	b2 := (a2  + a13) * 0.5 + a3
	b3 := (a3  + a12) * 0.5 + a4
	b4 := (a4  + a11) * 0.5 + a5
	b5 := (a5  + a10) * 0.5 + a6
	b6 := (a6  + a9 ) * 0.5 + a7
	b7 := (a7  + a8 ) * 0.5 + a0

	c0 := (b0 + b4) * 0.5 + b1
	c1 := (b1 + b5) * 0.5 + b2
	c2 := (b2 + b6) * 0.5 + b3
	c3 := (b3 + b7) * 0.5 + b0

	d0 := (c0 + c2) * 0.5 + c1
	d1 := (c1 + c3) * 0.5 + c2

	e0 := (d0 + d1) * 0.5 + c3

	return int(e0 +
		a0 + a1 + a2 + a3 +
		a4 + a5 + a6 + a7 +
		a8 + a9 + a10 + a11 +
		a12 + a13 + a14 + a15)
}

main.run_test(t, `float_variables_that_create_register_pressure`, `
package main

opt_level :: "none"

main :: proc() -> int {
	x: f64 = 0

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

	b0 := (a0  + a15) * 0.5 + a1
	b1 := (a1  + a14) * 0.5 + a2
	b2 := (a2  + a13) * 0.5 + a3
	b3 := (a3  + a12) * 0.5 + a4
	b4 := (a4  + a11) * 0.5 + a5
	b5 := (a5  + a10) * 0.5 + a6
	b6 := (a6  + a9 ) * 0.5 + a7
	b7 := (a7  + a8 ) * 0.5 + a0

	c0 := (b0 + b4) * 0.5 + b1
	c1 := (b1 + b5) * 0.5 + b2
	c2 := (b2 + b6) * 0.5 + b3
	c3 := (b3 + b7) * 0.5 + b0

	d0 := (c0 + c2) * 0.5 + c1
	d1 := (c1 + c3) * 0.5 + c2

	e0 := (d0 + d1) * 0.5 + c3

	return int(e0 +
		a0 + a1 + a2 + a3 +
		a4 + a5 + a6 + a7 +
		a8 + a9 + a10 + a11 +
		a12 + a13 + a14 + a15)
}
`, main_())
}
@(test) float_variables_that_create_even_more_register_pressure :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
	x: f64 = 0
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

	b0 := (a0 + a10 + a19) * 0.5
	b1 := (a1 + a11 + a18) * 0.5
	b2 := (a2 + a12 + a17) * 0.5
	b3 := (a3 + a13 + a16) * 0.5
	b4 := (a4 + a14 + a15) * 0.5
	b5 := (a5 + a15 + a14) * 0.5
	b6 := (a6 + a16 + a13) * 0.5
	b7 := (a7 + a17 + a12) * 0.5
	b8 := (a8 + a18 + a11) * 0.5
	b9 := (a9 + a19 + a10) * 0.5

	c0 := (b0 + b5 + a0 + a19) * 0.5
	c1 := (b1 + b6 + a1 + a18) * 0.5
	c2 := (b2 + b7 + a2 + a17) * 0.5
	c3 := (b3 + b8 + a3 + a16) * 0.5
	c4 := (b4 + b9 + a4 + a15) * 0.5

	return int(
		a0+a1+a2+a3+a4+a5+a6+a7+a8+a9+
		a10+a11+a12+a13+a14+a15+a16+a17+a18+a19+
		b0+b1+b2+b3+b4+b5+b6+b7+b8+b9+
		c0+c1+c2+c3+c4\
	)
}

main.run_test(t, `float_variables_that_create_even_more_register_pressure`, `
package main

opt_level :: "none"

main :: proc() -> int {
	x: f64 = 0
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

	b0 := (a0 + a10 + a19) * 0.5
	b1 := (a1 + a11 + a18) * 0.5
	b2 := (a2 + a12 + a17) * 0.5
	b3 := (a3 + a13 + a16) * 0.5
	b4 := (a4 + a14 + a15) * 0.5
	b5 := (a5 + a15 + a14) * 0.5
	b6 := (a6 + a16 + a13) * 0.5
	b7 := (a7 + a17 + a12) * 0.5
	b8 := (a8 + a18 + a11) * 0.5
	b9 := (a9 + a19 + a10) * 0.5

	c0 := (b0 + b5 + a0 + a19) * 0.5
	c1 := (b1 + b6 + a1 + a18) * 0.5
	c2 := (b2 + b7 + a2 + a17) * 0.5
	c3 := (b3 + b8 + a3 + a16) * 0.5
	c4 := (b4 + b9 + a4 + a15) * 0.5

	return int(
		a0+a1+a2+a3+a4+a5+a6+a7+a8+a9+
		a10+a11+a12+a13+a14+a15+a16+a17+a18+a19+
		b0+b1+b2+b3+b4+b5+b6+b7+b8+b9+
		c0+c1+c2+c3+c4\
	)
}
`, main_())
}
@(test) float_if_statement_with_register_pressure :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
	x: f64 = 0
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

	b0 := (a0 + a8 ) * 0.5 + a15
	b1 := (a1 + a9 ) * 0.5 + a14
	b2 := (a2 + a10) * 0.5 + a13
	b3 := (a3 + a11) * 0.5 + a12
	b4 := (a4 + a12) * 0.5 + a11
	b5 := (a5 + a13) * 0.5 + a10
	b6 := (a6 + a14) * 0.5 + a9
	b7 := (a7 + a15) * 0.5 + a8

	c0 := b0 + b4
	c1 := b1 + b5
	c2 := b2 + b6
	c3 := b3 + b7

	d0 := c0
	d1 := c1
	d2 := c2
	d3 := c3

	if x == x {
		d0 = (d0 + a0) * 0.5 + a15
		d1 = (d1 + a1) * 0.5 + a14
		d2 = (d2 + a2) * 0.5 + a13
		d3 = (d3 + a3) * 0.5 + a12
	}

	e0 := (d0 + d1) * 0.5 + b0 + b1
	e1 := (d2 + d3) * 0.5 + b2 + b3
	e2 := (d0 + d2) * 0.5 + b4 + b5
	e3 := (d1 + d3) * 0.5 + b6 + b7

	f0 := e0
	f1 := e1
	f2 := e2
	f3 := e3

	if a0 == a0 {
		f0 = (f0 + a4) * 0.5 + a11
		f1 = (f1 + a5) * 0.5 + a10
		f2 = (f2 + a6) * 0.5 + a9
		f3 = (f3 + a7) * 0.5 + a8
	}

	return int(a0+a1+a2+a3+a4+a5+a6+a7+
		a8+a9+a10+a11+a12+a13+a14+a15+
		b0+b1+b2+b3+b4+b5+b6+b7+
		c0+c1+c2+c3+
		d0+d1+d2+d3+
		e0+e1+e2+e3+
		f0+f1+f2+f3)
}

main.run_test(t, `float_if_statement_with_register_pressure`, `
package main

opt_level :: "none"

main :: proc() -> int {
	x: f64 = 0
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

	b0 := (a0 + a8 ) * 0.5 + a15
	b1 := (a1 + a9 ) * 0.5 + a14
	b2 := (a2 + a10) * 0.5 + a13
	b3 := (a3 + a11) * 0.5 + a12
	b4 := (a4 + a12) * 0.5 + a11
	b5 := (a5 + a13) * 0.5 + a10
	b6 := (a6 + a14) * 0.5 + a9
	b7 := (a7 + a15) * 0.5 + a8

	c0 := b0 + b4
	c1 := b1 + b5
	c2 := b2 + b6
	c3 := b3 + b7

	d0 := c0
	d1 := c1
	d2 := c2
	d3 := c3

	if x == x {
		d0 = (d0 + a0) * 0.5 + a15
		d1 = (d1 + a1) * 0.5 + a14
		d2 = (d2 + a2) * 0.5 + a13
		d3 = (d3 + a3) * 0.5 + a12
	}

	e0 := (d0 + d1) * 0.5 + b0 + b1
	e1 := (d2 + d3) * 0.5 + b2 + b3
	e2 := (d0 + d2) * 0.5 + b4 + b5
	e3 := (d1 + d3) * 0.5 + b6 + b7

	f0 := e0
	f1 := e1
	f2 := e2
	f3 := e3

	if a0 == a0 {
		f0 = (f0 + a4) * 0.5 + a11
		f1 = (f1 + a5) * 0.5 + a10
		f2 = (f2 + a6) * 0.5 + a9
		f3 = (f3 + a7) * 0.5 + a8
	}

	return int(a0+a1+a2+a3+a4+a5+a6+a7+
		a8+a9+a10+a11+a12+a13+a14+a15+
		b0+b1+b2+b3+b4+b5+b6+b7+
		c0+c1+c2+c3+
		d0+d1+d2+d3+
		e0+e1+e2+e3+
		f0+f1+f2+f3)
}
`, main_())
}
@(test) float_regalloc_pressure_across_calls :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
	x: f64 = 0

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

	b0 := (a0  + a15) * 0.5 + a1
	b1 := (a1  + a14) * 0.5 + a2
	b2 := (a2  + a13) * 0.5 + a3
	b3 := (a3  + a12) * 0.5 + a4
	b4 := (a4  + a11) * 0.5 + a5
	b5 := (a5  + a10) * 0.5 + a6
	b6 := (a6  + a9 ) * 0.5 + a7
	b7 := (a7  + a8 ) * 0.5 + a0

	call(b7)

	c0 := (b0 + b4) * 0.5 + b1
	c1 := (b1 + b5) * 0.5 + b2
	c2 := (b2 + b6) * 0.5 + b3
	c3 := (b3 + b7) * 0.5 + b0

	call(c3)

	d0 := (c0 + c2) * 0.5 + c1
	d1 := (c1 + c3) * 0.5 + c2

	call(d1)

	e0 := (d0 + d1) * 0.5 + c3

	call(e0)

	return int(e0 +
		a0 + a1 + a2 + a3 +
		a4 + a5 + a6 + a7 +
		a8 + a9 + a10 + a11 +
		a12 + a13 + a14 + a15)
}

call :: proc(vl: f64) -> f64 {
	return vl
}

main.run_test(t, `float_regalloc_pressure_across_calls`, `
package main

opt_level :: "none"

main :: proc() -> int {
	x: f64 = 0

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

	b0 := (a0  + a15) * 0.5 + a1
	b1 := (a1  + a14) * 0.5 + a2
	b2 := (a2  + a13) * 0.5 + a3
	b3 := (a3  + a12) * 0.5 + a4
	b4 := (a4  + a11) * 0.5 + a5
	b5 := (a5  + a10) * 0.5 + a6
	b6 := (a6  + a9 ) * 0.5 + a7
	b7 := (a7  + a8 ) * 0.5 + a0

	call(b7)

	c0 := (b0 + b4) * 0.5 + b1
	c1 := (b1 + b5) * 0.5 + b2
	c2 := (b2 + b6) * 0.5 + b3
	c3 := (b3 + b7) * 0.5 + b0

	call(c3)

	d0 := (c0 + c2) * 0.5 + c1
	d1 := (c1 + c3) * 0.5 + c2

	call(d1)

	e0 := (d0 + d1) * 0.5 + c3

	call(e0)

	return int(e0 +
		a0 + a1 + a2 + a3 +
		a4 + a5 + a6 + a7 +
		a8 + a9 + a10 + a11 +
		a12 + a13 + a14 + a15)
}

call :: proc(vl: f64) -> f64 {
	return vl
}
`, main_())
}
@(test) float_args_passed_on_stack :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
	vl: f64 = 0
	vl += load_of_args(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)
	vl += mixed(1, 2.0, 3, 4.0, 5, 6.0, 7, 8.0, 9, 10.0)
	return int(vl)
}

load_of_args :: proc(
	a: f64,
	b: f64,
	c: f64,
	d: f64,
	e: f64,
	f: f64,
	g: f64,
	h: f64,
	i: f64,
	j: f64,
) -> f64 {
	return a + b + c + d + e + f + g + h + i + j
}

mixed :: proc(
	a: int,
	b: f64,
	c: int,
	d: f64,
	e: int,
	f: f64,
	g: int,
	h: f64,
	i: int,
	j: f64,
) -> f64 {
	return f64(a) + b + f64(c) + d + f64(e) + f + f64(g) + h + f64(i) + j
}

main.run_test(t, `float_args_passed_on_stack`, `
package main

opt_level :: "none"

main :: proc() -> int {
	vl: f64 = 0
	vl += load_of_args(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)
	vl += mixed(1, 2.0, 3, 4.0, 5, 6.0, 7, 8.0, 9, 10.0)
	return int(vl)
}

load_of_args :: proc(
	a: f64,
	b: f64,
	c: f64,
	d: f64,
	e: f64,
	f: f64,
	g: f64,
	h: f64,
	i: f64,
	j: f64,
) -> f64 {
	return a + b + c + d + e + f + g + h + i + j
}

mixed :: proc(
	a: int,
	b: f64,
	c: int,
	d: f64,
	e: int,
	f: f64,
	g: int,
	h: f64,
	i: int,
	j: f64,
) -> f64 {
	return f64(a) + b + f64(c) + d + f64(e) + f + f64(g) + h + f64(i) + j
}
`, main_())
}
@(test) float_subword_conversions_round_trip :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
	r := 0

	{
		a: f32 = 100.5
		b := f64(a)
		c := f32(b)
		r += int(c)
	}

	{
		a: f64 = 0 - 250.75
		b := f32(a)
		c := f64(b)
		r += int(c)
	}

	{
		i := opaque(0 - 42)
		fa := f32(i)
		fb := f64(i)
		r += int(fa) + int(fb)
	}

	{
		f: f64 = 123.9
		r += int(i8(f))
		r += int(i16(f))
		r += int(i32(f))
		r += int(i64(f))
	}

	return r
}

opaque :: proc(x: int) -> int {
	return x
}

main.run_test(t, `float_subword_conversions_round_trip`, `
package main

opt_level :: "none"

main :: proc() -> int {
	r := 0

	{
		a: f32 = 100.5
		b := f64(a)
		c := f32(b)
		r += int(c)
	}

	{
		a: f64 = 0 - 250.75
		b := f32(a)
		c := f64(b)
		r += int(c)
	}

	{
		i := opaque(0 - 42)
		fa := f32(i)
		fb := f64(i)
		r += int(fa) + int(fb)
	}

	{
		f: f64 = 123.9
		r += int(i8(f))
		r += int(i16(f))
		r += int(i32(f))
		r += int(i64(f))
	}

	return r
}

opaque :: proc(x: int) -> int {
	return x
}
`, main_())
}
@(test) signed_integer_materialized_compares :: proc(t: ^testing.T) {



opt_level :: "none"

s8 :: proc(a: i8, b: i8) -> int {
	r := 0
	r += int(a == b)
	r += int(a != b) * 2
	r += int(a < b) * 4
	r += int(a <= b) * 8
	r += int(a > b) * 16
	r += int(a >= b) * 32
	return r
}

s16 :: proc(a: i16, b: i16) -> int {
	r := 0
	r += int(a == b)
	r += int(a != b) * 2
	r += int(a < b) * 4
	r += int(a <= b) * 8
	r += int(a > b) * 16
	r += int(a >= b) * 32
	return r
}

s32 :: proc(a: i32, b: i32) -> int {
	r := 0
	r += int(a == b)
	r += int(a != b) * 2
	r += int(a < b) * 4
	r += int(a <= b) * 8
	r += int(a > b) * 16
	r += int(a >= b) * 32
	return r
}

s64 :: proc(a: i64, b: i64) -> int {
	r := 0
	r += int(a == b)
	r += int(a != b) * 2
	r += int(a < b) * 4
	r += int(a <= b) * 8
	r += int(a > b) * 16
	r += int(a >= b) * 32
	return r
}

sint :: proc(a: int, b: int) -> int {
	r := 0
	r += int(a == b)
	r += int(a != b) * 2
	r += int(a < b) * 4
	r += int(a <= b) * 8
	r += int(a > b) * 16
	r += int(a >= b) * 32
	return r
}

main_ :: proc() -> int {
	r := 0

	r += s8(0 - 1, 1) + s8(5, 5) + s8(7, 0 - 3)
	r += s16(0 - 1, 1) + s16(5, 5) + s16(7, 0 - 3)
	r += s32(0 - 1, 1) + s32(5, 5) + s32(7, 0 - 3)
	r += s64(0 - 1, 1) + s64(5, 5) + s64(7, 0 - 3)
	r += sint(0 - 1, 1) + sint(5, 5) + sint(7, 0 - 3)

	return r
}

main.run_test(t, `signed_integer_materialized_compares`, `
package main

opt_level :: "none"

s8 :: proc(a: i8, b: i8) -> int {
	r := 0
	r += int(a == b)
	r += int(a != b) * 2
	r += int(a < b) * 4
	r += int(a <= b) * 8
	r += int(a > b) * 16
	r += int(a >= b) * 32
	return r
}

s16 :: proc(a: i16, b: i16) -> int {
	r := 0
	r += int(a == b)
	r += int(a != b) * 2
	r += int(a < b) * 4
	r += int(a <= b) * 8
	r += int(a > b) * 16
	r += int(a >= b) * 32
	return r
}

s32 :: proc(a: i32, b: i32) -> int {
	r := 0
	r += int(a == b)
	r += int(a != b) * 2
	r += int(a < b) * 4
	r += int(a <= b) * 8
	r += int(a > b) * 16
	r += int(a >= b) * 32
	return r
}

s64 :: proc(a: i64, b: i64) -> int {
	r := 0
	r += int(a == b)
	r += int(a != b) * 2
	r += int(a < b) * 4
	r += int(a <= b) * 8
	r += int(a > b) * 16
	r += int(a >= b) * 32
	return r
}

sint :: proc(a: int, b: int) -> int {
	r := 0
	r += int(a == b)
	r += int(a != b) * 2
	r += int(a < b) * 4
	r += int(a <= b) * 8
	r += int(a > b) * 16
	r += int(a >= b) * 32
	return r
}

main :: proc() -> int {
	r := 0

	r += s8(0 - 1, 1) + s8(5, 5) + s8(7, 0 - 3)
	r += s16(0 - 1, 1) + s16(5, 5) + s16(7, 0 - 3)
	r += s32(0 - 1, 1) + s32(5, 5) + s32(7, 0 - 3)
	r += s64(0 - 1, 1) + s64(5, 5) + s64(7, 0 - 3)
	r += sint(0 - 1, 1) + sint(5, 5) + sint(7, 0 - 3)

	return r
}
`, main_())
}
@(test) unsigned_integer_materialized_compares :: proc(t: ^testing.T) {



opt_level :: "none"

u8c :: proc(a: u8, b: u8) -> int {
	r := 0
	r += int(a == b)
	r += int(a != b) * 2
	r += int(a < b) * 4
	r += int(a <= b) * 8
	r += int(a > b) * 16
	r += int(a >= b) * 32
	return r
}

u16c :: proc(a: u16, b: u16) -> int {
	r := 0
	r += int(a == b)
	r += int(a != b) * 2
	r += int(a < b) * 4
	r += int(a <= b) * 8
	r += int(a > b) * 16
	r += int(a >= b) * 32
	return r
}

u32c :: proc(a: u32, b: u32) -> int {
	r := 0
	r += int(a == b)
	r += int(a != b) * 2
	r += int(a < b) * 4
	r += int(a <= b) * 8
	r += int(a > b) * 16
	r += int(a >= b) * 32
	return r
}

u64c :: proc(a: u64, b: u64) -> int {
	r := 0
	r += int(a == b)
	r += int(a != b) * 2
	r += int(a < b) * 4
	r += int(a <= b) * 8
	r += int(a > b) * 16
	r += int(a >= b) * 32
	return r
}

uintc :: proc(a: uint, b: uint) -> int {
	r := 0
	r += int(a == b)
	r += int(a != b) * 2
	r += int(a < b) * 4
	r += int(a <= b) * 8
	r += int(a > b) * 16
	r += int(a >= b) * 32
	return r
}

main_ :: proc() -> int {
	r := 0

	// high bit set operands so a signed comparison would give a different answer
	r += u8c(200, 5) + u8c(100, 100) + u8c(5, 200)
	r += u16c(50000, 5) + u16c(100, 100) + u16c(5, 50000)
	r += u32c(4000000000, 5) + u32c(100, 100) + u32c(5, 4000000000)
	r += u64c(10000000000000000000, 5) + u64c(100, 100) + u64c(5, 10000000000000000000)
	r += uintc(10000000000000000000, 5) + uintc(100, 100) + uintc(5, 10000000000000000000)

	return r
}

main.run_test(t, `unsigned_integer_materialized_compares`, `
package main

opt_level :: "none"

u8c :: proc(a: u8, b: u8) -> int {
	r := 0
	r += int(a == b)
	r += int(a != b) * 2
	r += int(a < b) * 4
	r += int(a <= b) * 8
	r += int(a > b) * 16
	r += int(a >= b) * 32
	return r
}

u16c :: proc(a: u16, b: u16) -> int {
	r := 0
	r += int(a == b)
	r += int(a != b) * 2
	r += int(a < b) * 4
	r += int(a <= b) * 8
	r += int(a > b) * 16
	r += int(a >= b) * 32
	return r
}

u32c :: proc(a: u32, b: u32) -> int {
	r := 0
	r += int(a == b)
	r += int(a != b) * 2
	r += int(a < b) * 4
	r += int(a <= b) * 8
	r += int(a > b) * 16
	r += int(a >= b) * 32
	return r
}

u64c :: proc(a: u64, b: u64) -> int {
	r := 0
	r += int(a == b)
	r += int(a != b) * 2
	r += int(a < b) * 4
	r += int(a <= b) * 8
	r += int(a > b) * 16
	r += int(a >= b) * 32
	return r
}

uintc :: proc(a: uint, b: uint) -> int {
	r := 0
	r += int(a == b)
	r += int(a != b) * 2
	r += int(a < b) * 4
	r += int(a <= b) * 8
	r += int(a > b) * 16
	r += int(a >= b) * 32
	return r
}

main :: proc() -> int {
	r := 0

	// high bit set operands so a signed comparison would give a different answer
	r += u8c(200, 5) + u8c(100, 100) + u8c(5, 200)
	r += u16c(50000, 5) + u16c(100, 100) + u16c(5, 50000)
	r += u32c(4000000000, 5) + u32c(100, 100) + u32c(5, 4000000000)
	r += u64c(10000000000000000000, 5) + u64c(100, 100) + u64c(5, 10000000000000000000)
	r += uintc(10000000000000000000, 5) + uintc(100, 100) + uintc(5, 10000000000000000000)

	return r
}
`, main_())
}
@(test) float_materialized_compares :: proc(t: ^testing.T) {



opt_level :: "none"

f32c :: proc(a: f32, b: f32) -> int {
	r := 0
	r += int(a == b)
	r += int(a != b) * 2
	r += int(a < b) * 4
	r += int(a <= b) * 8
	r += int(a > b) * 16
	r += int(a >= b) * 32
	return r
}

f64c :: proc(a: f64, b: f64) -> int {
	r := 0
	r += int(a == b)
	r += int(a != b) * 2
	r += int(a < b) * 4
	r += int(a <= b) * 8
	r += int(a > b) * 16
	r += int(a >= b) * 32
	return r
}

main_ :: proc() -> int {
	r := 0

	r += f32c(1, 2) + f32c(2, 2) + f32c(3, 2)
	r += f64c(1, 2) + f64c(2, 2) + f64c(3, 2)

	return r
}

main.run_test(t, `float_materialized_compares`, `
package main

opt_level :: "none"

f32c :: proc(a: f32, b: f32) -> int {
	r := 0
	r += int(a == b)
	r += int(a != b) * 2
	r += int(a < b) * 4
	r += int(a <= b) * 8
	r += int(a > b) * 16
	r += int(a >= b) * 32
	return r
}

f64c :: proc(a: f64, b: f64) -> int {
	r := 0
	r += int(a == b)
	r += int(a != b) * 2
	r += int(a < b) * 4
	r += int(a <= b) * 8
	r += int(a > b) * 16
	r += int(a >= b) * 32
	return r
}

main :: proc() -> int {
	r := 0

	r += f32c(1, 2) + f32c(2, 2) + f32c(3, 2)
	r += f64c(1, 2) + f64c(2, 2) + f64c(3, 2)

	return r
}
`, main_())
}
@(test) integer_materialized_compares_with_immediate :: proc(t: ^testing.T) {



opt_level :: "none"

si :: proc(a: i32) -> int {
	r := 0
	r += int(a == 7)
	r += int(a != 7) * 2
	r += int(a < 7) * 4
	r += int(a <= 7) * 8
	r += int(a > 7) * 16
	r += int(a >= 7) * 32
	return r
}

sil :: proc(a: i64) -> int {
	r := 0
	r += int(a == 7)
	r += int(a != 7) * 2
	r += int(a < 7) * 4
	r += int(a <= 7) * 8
	r += int(a > 7) * 16
	r += int(a >= 7) * 32
	return r
}

ui :: proc(a: u32) -> int {
	r := 0
	r += int(a == 7)
	r += int(a != 7) * 2
	r += int(a < 7) * 4
	r += int(a <= 7) * 8
	r += int(a > 7) * 16
	r += int(a >= 7) * 32
	return r
}

uil :: proc(a: u64) -> int {
	r := 0
	r += int(a == 7)
	r += int(a != 7) * 2
	r += int(a < 7) * 4
	r += int(a <= 7) * 8
	r += int(a > 7) * 16
	r += int(a >= 7) * 32
	return r
}

main_ :: proc() -> int {
	r := 0

	r += si(3) + si(7) + si(0 - 3)
	r += sil(3) + sil(7) + sil(0 - 3)
	r += ui(3) + ui(7) + ui(4000000000)
	r += uil(3) + uil(7) + uil(10000000000000000000)

	return r
}

main.run_test(t, `integer_materialized_compares_with_immediate`, `
package main

opt_level :: "none"

si :: proc(a: i32) -> int {
	r := 0
	r += int(a == 7)
	r += int(a != 7) * 2
	r += int(a < 7) * 4
	r += int(a <= 7) * 8
	r += int(a > 7) * 16
	r += int(a >= 7) * 32
	return r
}

sil :: proc(a: i64) -> int {
	r := 0
	r += int(a == 7)
	r += int(a != 7) * 2
	r += int(a < 7) * 4
	r += int(a <= 7) * 8
	r += int(a > 7) * 16
	r += int(a >= 7) * 32
	return r
}

ui :: proc(a: u32) -> int {
	r := 0
	r += int(a == 7)
	r += int(a != 7) * 2
	r += int(a < 7) * 4
	r += int(a <= 7) * 8
	r += int(a > 7) * 16
	r += int(a >= 7) * 32
	return r
}

uil :: proc(a: u64) -> int {
	r := 0
	r += int(a == 7)
	r += int(a != 7) * 2
	r += int(a < 7) * 4
	r += int(a <= 7) * 8
	r += int(a > 7) * 16
	r += int(a >= 7) * 32
	return r
}

main :: proc() -> int {
	r := 0

	r += si(3) + si(7) + si(0 - 3)
	r += sil(3) + sil(7) + sil(0 - 3)
	r += ui(3) + ui(7) + ui(4000000000)
	r += uil(3) + uil(7) + uil(10000000000000000000)

	return r
}
`, main_())
}
@(test) integer_materialized_compares_with_load :: proc(t: ^testing.T) {



opt_level :: "none"

sld :: proc(a: i32, p: ^i32) -> int {
	r := 0
	r += int(a == p^)
	r += int(a != p^) * 2
	r += int(a < p^) * 4
	r += int(a <= p^) * 8
	r += int(a > p^) * 16
	r += int(a >= p^) * 32
	return r
}

uld :: proc(a: u32, p: ^u32) -> int {
	r := 0
	r += int(a == p^)
	r += int(a != p^) * 2
	r += int(a < p^) * 4
	r += int(a <= p^) * 8
	r += int(a > p^) * 16
	r += int(a >= p^) * 32
	return r
}

main_ :: proc() -> int {
	r := 0

	sv: i32 = 5
	r += sld(3, &sv) + sld(5, &sv) + sld(9, &sv)

	uv: u32 = 4000000000
	r += uld(5, &uv) + uld(4000000000, &uv) + uld(4000000001, &uv)

	return r
}

main.run_test(t, `integer_materialized_compares_with_load`, `
package main

opt_level :: "none"

sld :: proc(a: i32, p: ^i32) -> int {
	r := 0
	r += int(a == p^)
	r += int(a != p^) * 2
	r += int(a < p^) * 4
	r += int(a <= p^) * 8
	r += int(a > p^) * 16
	r += int(a >= p^) * 32
	return r
}

uld :: proc(a: u32, p: ^u32) -> int {
	r := 0
	r += int(a == p^)
	r += int(a != p^) * 2
	r += int(a < p^) * 4
	r += int(a <= p^) * 8
	r += int(a > p^) * 16
	r += int(a >= p^) * 32
	return r
}

main :: proc() -> int {
	r := 0

	sv: i32 = 5
	r += sld(3, &sv) + sld(5, &sv) + sld(9, &sv)

	uv: u32 = 4000000000
	r += uld(5, &uv) + uld(4000000000, &uv) + uld(4000000001, &uv)

	return r
}
`, main_())
}
@(test) float_materialized_compares_with_load :: proc(t: ^testing.T) {



opt_level :: "none"

fld32 :: proc(a: f32, p: ^f32) -> int {
	r := 0
	r += int(a == p^)
	r += int(a != p^) * 2
	r += int(a < p^) * 4
	r += int(a <= p^) * 8
	r += int(a > p^) * 16
	r += int(a >= p^) * 32
	return r
}

fld64 :: proc(a: f64, p: ^f64) -> int {
	r := 0
	r += int(a == p^)
	r += int(a != p^) * 2
	r += int(a < p^) * 4
	r += int(a <= p^) * 8
	r += int(a > p^) * 16
	r += int(a >= p^) * 32
	return r
}

main_ :: proc() -> int {
	r := 0

	v32: f32 = 2
	r += fld32(1, &v32) + fld32(2, &v32) + fld32(3, &v32)

	v64: f64 = 2
	r += fld64(1, &v64) + fld64(2, &v64) + fld64(3, &v64)

	return r
}

main.run_test(t, `float_materialized_compares_with_load`, `
package main

opt_level :: "none"

fld32 :: proc(a: f32, p: ^f32) -> int {
	r := 0
	r += int(a == p^)
	r += int(a != p^) * 2
	r += int(a < p^) * 4
	r += int(a <= p^) * 8
	r += int(a > p^) * 16
	r += int(a >= p^) * 32
	return r
}

fld64 :: proc(a: f64, p: ^f64) -> int {
	r := 0
	r += int(a == p^)
	r += int(a != p^) * 2
	r += int(a < p^) * 4
	r += int(a <= p^) * 8
	r += int(a > p^) * 16
	r += int(a >= p^) * 32
	return r
}

main :: proc() -> int {
	r := 0

	v32: f32 = 2
	r += fld32(1, &v32) + fld32(2, &v32) + fld32(3, &v32)

	v64: f64 = 2
	r += fld64(1, &v64) + fld64(2, &v64) + fld64(3, &v64)

	return r
}
`, main_())
}
@(test) integer_materialized_compares_with_folded_load :: proc(t: ^testing.T) {



opt_level :: "none"

Si6 :: struct {
	a: i32,
	b: i32,
	c: i32,
	d: i32,
	e: i32,
	f: i32,
}

Ui6 :: struct {
	a: u32,
	b: u32,
	c: u32,
	d: u32,
	e: u32,
	f: u32,
}

// each field is a distinct single use load so it folds into the cmp's memory operand
msrc :: proc(a: i32, p: ^Si6) -> int {
	r := 0
	r += int(a == p.a)
	r += int(a != p.b) * 2
	r += int(a < p.c) * 4
	r += int(a <= p.d) * 8
	r += int(a > p.e) * 16
	r += int(a >= p.f) * 32
	return r
}

usrc :: proc(a: u32, p: ^Ui6) -> int {
	r := 0
	r += int(a == p.a)
	r += int(a != p.b) * 2
	r += int(a < p.c) * 4
	r += int(a <= p.d) * 8
	r += int(a > p.e) * 16
	r += int(a >= p.f) * 32
	return r
}

mdst :: proc(p: ^Si6) -> int {
	r := 0
	r += int(p.a == 7)
	r += int(p.b != 7) * 2
	r += int(p.c < 7) * 4
	r += int(p.d <= 7) * 8
	r += int(p.e > 7) * 16
	r += int(p.f >= 7) * 32
	return r
}

udst :: proc(p: ^Ui6) -> int {
	r := 0
	r += int(p.a == 7)
	r += int(p.b != 7) * 2
	r += int(p.c < 7) * 4
	r += int(p.d <= 7) * 8
	r += int(p.e > 7) * 16
	r += int(p.f >= 7) * 32
	return r
}

main_ :: proc() -> int {
	r := 0

	si := Si6{0 - 5, 0 - 5, 0 - 5, 0 - 5, 0 - 5, 0 - 5}
	r += msrc(0 - 9, &si) + msrc(0 - 5, &si) + msrc(3, &si)

	ui := Ui6{4000000000, 4000000000, 4000000000, 4000000000, 4000000000, 4000000000}
	r += usrc(5, &ui) + usrc(4000000000, &ui) + usrc(4000000001, &ui)

	di := Si6{3, 3, 3, 3, 3, 3}
	r += mdst(&di)
	dj := Si6{9, 9, 9, 9, 9, 9}
	r += mdst(&dj)

	du := Ui6{3, 3, 3, 3, 3, 3}
	r += udst(&du)
	dv := Ui6{4000000000, 4000000000, 4000000000, 4000000000, 4000000000, 4000000000}
	r += udst(&dv)

	return r
}

main.run_test(t, `integer_materialized_compares_with_folded_load`, `
package main

opt_level :: "none"

Si6 :: struct {
	a: i32,
	b: i32,
	c: i32,
	d: i32,
	e: i32,
	f: i32,
}

Ui6 :: struct {
	a: u32,
	b: u32,
	c: u32,
	d: u32,
	e: u32,
	f: u32,
}

// each field is a distinct single use load so it folds into the cmp's memory operand
msrc :: proc(a: i32, p: ^Si6) -> int {
	r := 0
	r += int(a == p.a)
	r += int(a != p.b) * 2
	r += int(a < p.c) * 4
	r += int(a <= p.d) * 8
	r += int(a > p.e) * 16
	r += int(a >= p.f) * 32
	return r
}

usrc :: proc(a: u32, p: ^Ui6) -> int {
	r := 0
	r += int(a == p.a)
	r += int(a != p.b) * 2
	r += int(a < p.c) * 4
	r += int(a <= p.d) * 8
	r += int(a > p.e) * 16
	r += int(a >= p.f) * 32
	return r
}

mdst :: proc(p: ^Si6) -> int {
	r := 0
	r += int(p.a == 7)
	r += int(p.b != 7) * 2
	r += int(p.c < 7) * 4
	r += int(p.d <= 7) * 8
	r += int(p.e > 7) * 16
	r += int(p.f >= 7) * 32
	return r
}

udst :: proc(p: ^Ui6) -> int {
	r := 0
	r += int(p.a == 7)
	r += int(p.b != 7) * 2
	r += int(p.c < 7) * 4
	r += int(p.d <= 7) * 8
	r += int(p.e > 7) * 16
	r += int(p.f >= 7) * 32
	return r
}

main :: proc() -> int {
	r := 0

	si := Si6{0 - 5, 0 - 5, 0 - 5, 0 - 5, 0 - 5, 0 - 5}
	r += msrc(0 - 9, &si) + msrc(0 - 5, &si) + msrc(3, &si)

	ui := Ui6{4000000000, 4000000000, 4000000000, 4000000000, 4000000000, 4000000000}
	r += usrc(5, &ui) + usrc(4000000000, &ui) + usrc(4000000001, &ui)

	di := Si6{3, 3, 3, 3, 3, 3}
	r += mdst(&di)
	dj := Si6{9, 9, 9, 9, 9, 9}
	r += mdst(&dj)

	du := Ui6{3, 3, 3, 3, 3, 3}
	r += udst(&du)
	dv := Ui6{4000000000, 4000000000, 4000000000, 4000000000, 4000000000, 4000000000}
	r += udst(&dv)

	return r
}
`, main_())
}
@(test) float_materialized_compares_with_folded_load :: proc(t: ^testing.T) {



opt_level :: "none"

F32x6 :: struct {
	a: f32,
	b: f32,
	c: f32,
	d: f32,
	e: f32,
	f: f32,
}

F64x6 :: struct {
	a: f64,
	b: f64,
	c: f64,
	d: f64,
	e: f64,
	f: f64,
}

fsrc32 :: proc(a: f32, p: ^F32x6) -> int {
	r := 0
	r += int(a == p.a)
	r += int(a != p.b) * 2
	r += int(a < p.c) * 4
	r += int(a <= p.d) * 8
	r += int(a > p.e) * 16
	r += int(a >= p.f) * 32
	return r
}

fsrc64 :: proc(a: f64, p: ^F64x6) -> int {
	r := 0
	r += int(a == p.a)
	r += int(a != p.b) * 2
	r += int(a < p.c) * 4
	r += int(a <= p.d) * 8
	r += int(a > p.e) * 16
	r += int(a >= p.f) * 32
	return r
}

main_ :: proc() -> int {
	r := 0

	a32 := F32x6{2, 2, 2, 2, 2, 2}
	r += fsrc32(1, &a32) + fsrc32(2, &a32) + fsrc32(3, &a32)

	a64 := F64x6{2, 2, 2, 2, 2, 2}
	r += fsrc64(1, &a64) + fsrc64(2, &a64) + fsrc64(3, &a64)

	return r
}

main.run_test(t, `float_materialized_compares_with_folded_load`, `
package main

opt_level :: "none"

F32x6 :: struct {
	a: f32,
	b: f32,
	c: f32,
	d: f32,
	e: f32,
	f: f32,
}

F64x6 :: struct {
	a: f64,
	b: f64,
	c: f64,
	d: f64,
	e: f64,
	f: f64,
}

fsrc32 :: proc(a: f32, p: ^F32x6) -> int {
	r := 0
	r += int(a == p.a)
	r += int(a != p.b) * 2
	r += int(a < p.c) * 4
	r += int(a <= p.d) * 8
	r += int(a > p.e) * 16
	r += int(a >= p.f) * 32
	return r
}

fsrc64 :: proc(a: f64, p: ^F64x6) -> int {
	r := 0
	r += int(a == p.a)
	r += int(a != p.b) * 2
	r += int(a < p.c) * 4
	r += int(a <= p.d) * 8
	r += int(a > p.e) * 16
	r += int(a >= p.f) * 32
	return r
}

main :: proc() -> int {
	r := 0

	a32 := F32x6{2, 2, 2, 2, 2, 2}
	r += fsrc32(1, &a32) + fsrc32(2, &a32) + fsrc32(3, &a32)

	a64 := F64x6{2, 2, 2, 2, 2, 2}
	r += fsrc64(1, &a64) + fsrc64(2, &a64) + fsrc64(3, &a64)

	return r
}
`, main_())
}
@(test) crash_in_gcm_on_two_loops_nested_in_a_loop :: proc(t: ^testing.T) {



main_ :: proc() -> int {
	i := 0
	total := 0
	for {
		if i >= 4 do break

		a := 0
		j := 0
		for {
			if j >= 4 do break
			a += j
			j += 1
		}

		b := 0
		k := 0
		for {
			if k >= 4 do break
			b += k * 2
			k += 1
		}

		total += a + b
		i += 1
	}
	return total % 251
}

main.run_test(t, `crash_in_gcm_on_two_loops_nested_in_a_loop`, `
package main

main :: proc() -> int {
	i := 0
	total := 0
	for {
		if i >= 4 do break

		a := 0
		j := 0
		for {
			if j >= 4 do break
			a += j
			j += 1
		}

		b := 0
		k := 0
		for {
			if k >= 4 do break
			b += k * 2
			k += 1
		}

		total += a + b
		i += 1
	}
	return total % 251
}
`, main_())
}
@(test) foreign_block :: proc(t: ^testing.T) {



foreign {
	malloc :: proc(size: int) -> rawptr ---
	free :: proc(size: rawptr) ---
}

main_ :: proc() -> int {
	slt := (^int)(malloc(8))
	slt^ = 0
	vl := slt^
	free(rawptr(slt))
	return vl
}

main.run_test(t, `foreign_block`, `
package main

foreign {
	malloc :: proc(size: int) -> rawptr ---
	free :: proc(size: rawptr) ---
}

main :: proc() -> int {
	slt := (^int)(malloc(8))
	slt^ = 0
	vl := slt^
	free(rawptr(slt))
	return vl
}
`, main_())
}
@(test) enum_basic_values :: proc(t: ^testing.T) {



opt_level :: "none"

Color :: enum {
	Red,
	Green,
	Blue,
}

main_ :: proc() -> int {
	c := Color.Green
	return int(c)
}

main.run_test(t, `enum_basic_values`, `
package main

opt_level :: "none"

Color :: enum {
	Red,
	Green,
	Blue,
}

main :: proc() -> int {
	c := Color.Green
	return int(c)
}
`, main_())
}
@(test) enum_explicit_values :: proc(t: ^testing.T) {



opt_level :: "none"

Code :: enum {
	A = 3,
	B,
	C = 10,
}

main_ :: proc() -> int {
	return int(Code.B) + int(Code.C)
}

main.run_test(t, `enum_explicit_values`, `
package main

opt_level :: "none"

Code :: enum {
	A = 3,
	B,
	C = 10,
}

main :: proc() -> int {
	return int(Code.B) + int(Code.C)
}
`, main_())
}
@(test) enum_backing_type :: proc(t: ^testing.T) {



opt_level :: "none"

Flag :: enum u8 {
	X = 200,
	Y,
}

main_ :: proc() -> int {
	f := Flag.Y
	return int(f)
}

main.run_test(t, `enum_backing_type`, `
package main

opt_level :: "none"

Flag :: enum u8 {
	X = 200,
	Y,
}

main :: proc() -> int {
	f := Flag.Y
	return int(f)
}
`, main_())
}
@(test) enum_comparison :: proc(t: ^testing.T) {



opt_level :: "none"

Dir :: enum {
	N,
	E,
	S,
	W,
}

main_ :: proc() -> int {
	d := Dir.S
	r := 0
	if d == Dir.S do r += 1
	if d != Dir.N do r += 2
	return r
}

main.run_test(t, `enum_comparison`, `
package main

opt_level :: "none"

Dir :: enum {
	N,
	E,
	S,
	W,
}

main :: proc() -> int {
	d := Dir.S
	r := 0
	if d == Dir.S do r += 1
	if d != Dir.N do r += 2
	return r
}
`, main_())
}
@(test) enum_implicit_selector :: proc(t: ^testing.T) {



opt_level :: "none"

State :: enum {
	Off,
	On,
}

main_ :: proc() -> int {
	s: State = .On
	if s == .On do return 5
	return 0
}

main.run_test(t, `enum_implicit_selector`, `
package main

opt_level :: "none"

State :: enum {
	Off,
	On,
}

main :: proc() -> int {
	s: State = .On
	if s == .On do return 5
	return 0
}
`, main_())
}
@(test) enum_in_struct :: proc(t: ^testing.T) {



opt_level :: "none"

Kind :: enum {
	A,
	B,
}

Box :: struct {
	k: Kind,
	n: int,
}

main_ :: proc() -> int {
	b := Box{k = Kind.B, n = 7}
	return int(b.k) + b.n
}

main.run_test(t, `enum_in_struct`, `
package main

opt_level :: "none"

Kind :: enum {
	A,
	B,
}

Box :: struct {
	k: Kind,
	n: int,
}

main :: proc() -> int {
	b := Box{k = Kind.B, n = 7}
	return int(b.k) + b.n
}
`, main_())
}
@(test) enum_value_switch :: proc(t: ^testing.T) {



opt_level :: "none"

Op :: enum {
	Add,
	Sub,
	Mul,
}

main_ :: proc() -> int {
	o := Op.Mul
	r := 0
	switch o {
	case .Add:
		r = 1
	case .Sub:
		r = 2
	case .Mul:
		r = 3
	}
	return r
}

main.run_test(t, `enum_value_switch`, `
package main

opt_level :: "none"

Op :: enum {
	Add,
	Sub,
	Mul,
}

main :: proc() -> int {
	o := Op.Mul
	r := 0
	switch o {
	case .Add:
		r = 1
	case .Sub:
		r = 2
	case .Mul:
		r = 3
	}
	return r
}
`, main_())
}
@(test) enum_as_param :: proc(t: ^testing.T) {



opt_level :: "none"

Sign :: enum {
	Pos,
	Neg,
}

apply :: proc(s: Sign, x: int) -> int {
	if s == .Neg do return 100 - x
	return x
}

main_ :: proc() -> int {
	return apply(.Neg, 9)
}

main.run_test(t, `enum_as_param`, `
package main

opt_level :: "none"

Sign :: enum {
	Pos,
	Neg,
}

apply :: proc(s: Sign, x: int) -> int {
	if s == .Neg do return 100 - x
	return x
}

main :: proc() -> int {
	return apply(.Neg, 9)
}
`, main_())
}
@(test) union_assert :: proc(t: ^testing.T) {



opt_level :: "none"

V :: union {
	int,
	f32,
}

main_ :: proc() -> int {
	v: V = 42
	return v.(int)
}

main.run_test(t, `union_assert`, `
package main

opt_level :: "none"

V :: union {
	int,
	f32,
}

main :: proc() -> int {
	v: V = 42
	return v.(int)
}
`, main_())
}
@(test) union_type_switch :: proc(t: ^testing.T) {



opt_level :: "none"

V :: union {
	int,
	bool,
}

main_ :: proc() -> int {
	v: V = 7
	r := 0
	switch x in v {
	case int:
		r = x
	case bool:
		if x do r = 100
	}
	return r
}

main.run_test(t, `union_type_switch`, `
package main

opt_level :: "none"

V :: union {
	int,
	bool,
}

main :: proc() -> int {
	v: V = 7
	r := 0
	switch x in v {
	case int:
		r = x
	case bool:
		if x do r = 100
	}
	return r
}
`, main_())
}
@(test) union_nil_check :: proc(t: ^testing.T) {



opt_level :: "none"

V :: union {
	int,
}

main_ :: proc() -> int {
	v: V
	r := 0
	if v == nil do r += 1
	v = 5
	if v != nil do r += 2
	return r
}

main.run_test(t, `union_nil_check`, `
package main

opt_level :: "none"

V :: union {
	int,
}

main :: proc() -> int {
	v: V
	r := 0
	if v == nil do r += 1
	v = 5
	if v != nil do r += 2
	return r
}
`, main_())
}
@(test) union_reassign_variant :: proc(t: ^testing.T) {



opt_level :: "none"

V :: union {
	int,
	i32,
}

main_ :: proc() -> int {
	v: V = int(3)
	v = i32(9)
	return int(v.(i32))
}

main.run_test(t, `union_reassign_variant`, `
package main

opt_level :: "none"

V :: union {
	int,
	i32,
}

main :: proc() -> int {
	v: V = int(3)
	v = i32(9)
	return int(v.(i32))
}
`, main_())
}
@(test) union_struct_member :: proc(t: ^testing.T) {



opt_level :: "none"

P :: struct {
	x: int,
	y: int,
}

V :: union {
	int,
	P,
}

main_ :: proc() -> int {
	v: V = P{x = 4, y = 5}
	p := v.(P)
	return p.x + p.y
}

main.run_test(t, `union_struct_member`, `
package main

opt_level :: "none"

P :: struct {
	x: int,
	y: int,
}

V :: union {
	int,
	P,
}

main :: proc() -> int {
	v: V = P{x = 4, y = 5}
	p := v.(P)
	return p.x + p.y
}
`, main_())
}
@(test) union_type_switch_default :: proc(t: ^testing.T) {



opt_level :: "none"

V :: union {
	int,
	bool,
}

main_ :: proc() -> int {
	v: V = true
	r := 0
	#partial switch x in v {
	case int:
		r = 1
	case:
		r = 2
	}
	return r
}

main.run_test(t, `union_type_switch_default`, `
package main

opt_level :: "none"

V :: union {
	int,
	bool,
}

main :: proc() -> int {
	v: V = true
	r := 0
	#partial switch x in v {
	case int:
		r = 1
	case:
		r = 2
	}
	return r
}
`, main_())
}
@(test) generic_fuctions :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
	return int(fib(i32(10))) + fib(10)
}

fib :: proc(x: $T) -> T {
	if x <= 2 {
		return 1
	}
	return fib(x - 1) + fib(x - 2)
}

main.run_test(t, `generic_fuctions`, `
package main

opt_level :: "none"

main :: proc() -> int {
	return int(fib(i32(10))) + fib(10)
}

fib :: proc(x: $T) -> T {
	if x <= 2 {
		return 1
	}
	return fib(x - 1) + fib(x - 2)
}
`, main_())
}
@(test) function_pointers :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
	return d(proc() -> int {return 10})
}

d :: proc(f: proc() -> int) -> int {
	return f()
}

main.run_test(t, `function_pointers`, `
package main

opt_level :: "none"

main :: proc() -> int {
	return d(proc() -> int {return 10})
}

d :: proc(f: proc() -> int) -> int {
	return f()
}
`, main_())
}
@(test) BUG2_alias_through_pointer_stored_in_struct_field :: proc(t: ^testing.T) {



opt_level :: "none"

Inner :: struct {
	x: int,
}

Holder :: struct {
	p: ^Inner,
}

main_ :: proc() -> int {
	local := Inner{1}
	h: Holder
	h.p = &local
	h.p.x = 42
	return local.x
}

main.run_test(t, `BUG2_alias_through_pointer_stored_in_struct_field`, `
package main

opt_level :: "none"

Inner :: struct {
	x: int,
}

Holder :: struct {
	p: ^Inner,
}

main :: proc() -> int {
	local := Inner{1}
	h: Holder
	h.p = &local
	h.p.x = 42
	return local.x
}
`, main_())
}
@(test) parametrized_structs :: proc(t: ^testing.T) {



opt_level :: "none"

Vec :: struct($T: typeid) {
	data: [^]T,
	len:  int,
}

Pair :: struct {
	a: int,
	b: int,
}

vec_push :: proc(v: ^Vec($T), x: ^T) {
	v.data[v.len] = x^
	v.len += 1
}

vec_at :: proc(v: ^Vec($T), i: int) -> ^T {
	return &v.data[i]
}

sum_ints :: proc(v: ^Vec(int)) -> int {
	s := 0
	i := 0
	for {
		if i >= v.len do break
		s += vec_at(v, i)^
		i += 1
	}
	return s
}

main_ :: proc() -> int {
	ibuf: [8]int = {}
	pbuf: [8]Pair = {}

	iv: Vec(int) = {}
	iv.data = raw_data(ibuf[:])
	a := 11
	b := 31
	vec_push(&iv, &a)
	vec_push(&iv, &b)

	pv: Vec(Pair) = {}
	pv.data = raw_data(pbuf[:])
	p := Pair{3, 4}
	vec_push(&pv, &p)

	q := vec_at(&pv, 0)
	return sum_ints(&iv) + q.a + q.b + iv.len + pv.len
}

main.run_test(t, `parametrized_structs`, `
package main

opt_level :: "none"

Vec :: struct($T: typeid) {
	data: [^]T,
	len:  int,
}

Pair :: struct {
	a: int,
	b: int,
}

vec_push :: proc(v: ^Vec($T), x: ^T) {
	v.data[v.len] = x^
	v.len += 1
}

vec_at :: proc(v: ^Vec($T), i: int) -> ^T {
	return &v.data[i]
}

sum_ints :: proc(v: ^Vec(int)) -> int {
	s := 0
	i := 0
	for {
		if i >= v.len do break
		s += vec_at(v, i)^
		i += 1
	}
	return s
}

main :: proc() -> int {
	ibuf: [8]int = {}
	pbuf: [8]Pair = {}

	iv: Vec(int) = {}
	iv.data = raw_data(ibuf[:])
	a := 11
	b := 31
	vec_push(&iv, &a)
	vec_push(&iv, &b)

	pv: Vec(Pair) = {}
	pv.data = raw_data(pbuf[:])
	p := Pair{3, 4}
	vec_push(&pv, &p)

	q := vec_at(&pv, 0)
	return sum_ints(&iv) + q.a + q.b + iv.len + pv.len
}
`, main_())
}
@(test) bad_arg_pass :: proc(t: ^testing.T) {



opt_level :: "none"

@(static)
f := 0

w_call :: proc(
	a: int,
	m: int,
	data: string,
	name: string,
	a0: int,
	a1: int,
	nargs: int,
) -> int {
	fidx := w_find_func(a, m, data, name)
	if fidx < 0 {
		print("<no export>\n")
		return 0
	}
	if nargs >= 1 do wpush(a0)
	if nargs >= 2 do wpush(a1)
	return w_finish(a, m, fidx)
}

print :: proc(s: string) {}

w_find_func :: proc(a: int, b: int, c: string, d: string) -> int {
	return 10
}

wpush :: proc(i: int) {
	f += i
	f <<= 10
}

w_finish :: proc(a: int, b: int, c: int) -> int {
	return a + b * c
}

main_ :: proc() -> int {
	f = 0
	return w_call(0, 1, "", "", 2, 3, 4) + f
}

main.run_test(t, `bad_arg_pass`, `
package main

opt_level :: "none"

@(static)
f := 0

w_call :: proc(
	a: int,
	m: int,
	data: string,
	name: string,
	a0: int,
	a1: int,
	nargs: int,
) -> int {
	fidx := w_find_func(a, m, data, name)
	if fidx < 0 {
		print("<no export>\n")
		return 0
	}
	if nargs >= 1 do wpush(a0)
	if nargs >= 2 do wpush(a1)
	return w_finish(a, m, fidx)
}

print :: proc(s: string) {}

w_find_func :: proc(a: int, b: int, c: string, d: string) -> int {
	return 10
}

wpush :: proc(i: int) {
	f += i
	f <<= 10
}

w_finish :: proc(a: int, b: int, c: int) -> int {
	return a + b * c
}

main :: proc() -> int {
	f = 0
	return w_call(0, 1, "", "", 2, 3, 4) + f
}
`, main_())
}
@(test) float_const :: proc(t: ^testing.T) {



opt_level :: "none"

VL :: 1.0

main_ :: proc() -> int {
	vl: f32
	return int(vl + VL)
}

main.run_test(t, `float_const`, `
package main

opt_level :: "none"

VL :: 1.0

main :: proc() -> int {
	vl: f32
	return int(vl + VL)
}
`, main_())
}
@(test) basic_simd :: proc(t: ^testing.T) {



opt_level :: "none"

LANES :: 16

T :: u8

from_slice :: proc(slice: []$E) -> #simd[LANES]E {
	array: [LANES]E
	i := 0
	#no_bounds_check for {
		if i >= LANES do break
		array[i] = slice[i]
		i += 1
	}
	return transmute(#simd[LANES]E)array
}


linear_search :: proc (array: []$T, key: T) -> (index: int, found: bool) {
	for x, i in array {
		if x == key {
			return i, true
		}
	}
	return -1, false
}

simd_search :: proc(haistack: []$T, needle: T) -> (int, bool) {
	//LANES :: 16 / size_of(T)

	i := 0
	for {
		if i >= len(haistack) / LANES do break
		chunk := from_slice(haistack[i * LANES:][:LANES])
		mask := intrinsics.simd_lanes_eq(chunk, (#simd[LANES]T)(needle))
		bits := transmute(u16)intrinsics.simd_extract_lsbs(mask)
		if bits != 0 {
			return i * LANES +
				int(intrinsics.count_trailing_zeros(bits)), true
		}
		i += 1
	}

	idx, _ := linear_search(
		haistack[len(haistack) / LANES * LANES:],
		needle,
	)
	if idx < 0 do return -1, false
	return len(haistack) / LANES * LANES + idx, true
}

sum :: proc(slc: []u8) -> u8 {
	acc: #simd[LANES]u8

	i := 0
	for {
		if i + LANES >= len(slc) do break
		acc += from_slice(slc[i:i + LANES])
		i += LANES
	}

	sacc: u8
	for el in slc {
		sacc += el
	}

	return intrinsics.simd_reduce_add_bisect(acc) + sacc
}

main_ :: proc() -> int {
	haystack := "0123456789abcdefghijklmnopqrstuvxyz"
	res, _ := simd_search(transmute([]u8)haystack, 'z')
	res2, _ := simd_search(transmute([]u8)haystack, 'a')
	res3 := sum(transmute([]u8)haystack)
	return res + res2 * 10 + int(res3) * 100
}

main.run_test(t, `basic_simd`, `
package main

opt_level :: "none"

LANES :: 16

T :: u8

from_slice :: proc(slice: []$E) -> #simd[LANES]E {
	array: [LANES]E
	i := 0
	#no_bounds_check for {
		if i >= LANES do break
		array[i] = slice[i]
		i += 1
	}
	return transmute(#simd[LANES]E)array
}


linear_search :: proc (array: []$T, key: T) -> (index: int, found: bool) {
	for x, i in array {
		if x == key {
			return i, true
		}
	}
	return -1, false
}

simd_search :: proc(haistack: []$T, needle: T) -> (int, bool) {
	//LANES :: 16 / size_of(T)

	i := 0
	for {
		if i >= len(haistack) / LANES do break
		chunk := from_slice(haistack[i * LANES:][:LANES])
		mask := intrinsics.simd_lanes_eq(chunk, (#simd[LANES]T)(needle))
		bits := transmute(u16)intrinsics.simd_extract_lsbs(mask)
		if bits != 0 {
			return i * LANES +
				int(intrinsics.count_trailing_zeros(bits)), true
		}
		i += 1
	}

	idx, _ := linear_search(
		haistack[len(haistack) / LANES * LANES:],
		needle,
	)
	if idx < 0 do return -1, false
	return len(haistack) / LANES * LANES + idx, true
}

sum :: proc(slc: []u8) -> u8 {
	acc: #simd[LANES]u8

	i := 0
	for {
		if i + LANES >= len(slc) do break
		acc += from_slice(slc[i:i + LANES])
		i += LANES
	}

	sacc: u8
	for el in slc {
		sacc += el
	}

	return intrinsics.simd_reduce_add_bisect(acc) + sacc
}

main :: proc() -> int {
	haystack := "0123456789abcdefghijklmnopqrstuvxyz"
	res, _ := simd_search(transmute([]u8)haystack, 'z')
	res2, _ := simd_search(transmute([]u8)haystack, 'a')
	res3 := sum(transmute([]u8)haystack)
	return res + res2 * 10 + int(res3) * 100
}
`, main_())
}
@(test) exhaustive_simd_accs :: proc(t: ^testing.T) {



from_slice :: proc($LANES: int, slice: []$E) -> #simd[LANES]E {
	array: [LANES]E
	i := 0
	#no_bounds_check for {
		if i >= LANES do break
		array[i] = slice[i]
		i += 1
	}
	return transmute(#simd[LANES]E)array
}

simd_fold :: proc(slc: []$T) -> T {
	LANES :: 16 / size_of(T)
	acc: #simd[LANES]T

	i := 0
	for {
		if i + LANES >= len(slc) do break
		acc += from_slice(LANES, slc[i:i + LANES])
		acc &= from_slice(LANES, slc[i:i + LANES])
		acc ~= from_slice(LANES, slc[i:i + LANES])
		acc |= from_slice(LANES, slc[i:i + LANES])
		acc -= from_slice(LANES, slc[i:i + LANES])
		i += LANES
	}

	sacc: T
	for el in slc[i:] {
		sacc += el
		sacc &= el
		sacc ~= el
		sacc |= el
		sacc -= el
	}

	return intrinsics.simd_reduce_add_bisect(acc) + sacc
}

init_inc :: proc(slc: []$T) {
	for &v, i in slc {
		v = T(i)
	}
}

main_ :: proc() -> int {
	vu8: [33]u8
	init_inc(vu8[:])
	vu16: [17]u16
	init_inc(vu16[:])
	vu32: [9]u32
	init_inc(vu16[:])
	vu64: [5]u64

	res := 0
	res += int(simd_fold(vu8[:]))
	res += int(simd_fold(vu16[:]))
	res += int(simd_fold(vu32[:]))
	res += int(simd_fold(vu64[:]))

	return res
}

main.run_test(t, `exhaustive_simd_accs`, `
package main

from_slice :: proc($LANES: int, slice: []$E) -> #simd[LANES]E {
	array: [LANES]E
	i := 0
	#no_bounds_check for {
		if i >= LANES do break
		array[i] = slice[i]
		i += 1
	}
	return transmute(#simd[LANES]E)array
}

simd_fold :: proc(slc: []$T) -> T {
	LANES :: 16 / size_of(T)
	acc: #simd[LANES]T

	i := 0
	for {
		if i + LANES >= len(slc) do break
		acc += from_slice(LANES, slc[i:i + LANES])
		acc &= from_slice(LANES, slc[i:i + LANES])
		acc ~= from_slice(LANES, slc[i:i + LANES])
		acc |= from_slice(LANES, slc[i:i + LANES])
		acc -= from_slice(LANES, slc[i:i + LANES])
		i += LANES
	}

	sacc: T
	for el in slc[i:] {
		sacc += el
		sacc &= el
		sacc ~= el
		sacc |= el
		sacc -= el
	}

	return intrinsics.simd_reduce_add_bisect(acc) + sacc
}

init_inc :: proc(slc: []$T) {
	for &v, i in slc {
		v = T(i)
	}
}

main :: proc() -> int {
	vu8: [33]u8
	init_inc(vu8[:])
	vu16: [17]u16
	init_inc(vu16[:])
	vu32: [9]u32
	init_inc(vu16[:])
	vu64: [5]u64

	res := 0
	res += int(simd_fold(vu8[:]))
	res += int(simd_fold(vu16[:]))
	res += int(simd_fold(vu32[:]))
	res += int(simd_fold(vu64[:]))

	return res
}
`, main_())
}
@(test) inlined_trap_before_normal_control_flow :: proc(t: ^testing.T) {



opt_level :: "none"


main_ :: proc() -> int {
	@(static)
	c := 0
	if c != 0 {
		foo()
		
		@(static)
		g := 0

		if g == 0 {
			return 1
		} else {
			return 0
		}
	}

	return 0
}

foo :: proc() {
	intrinsics.trap()
}

main.run_test(t, `inlined_trap_before_normal_control_flow`, `
package main

opt_level :: "none"


main :: proc() -> int {
	@(static)
	c := 0
	if c != 0 {
		foo()
		
		@(static)
		g := 0

		if g == 0 {
			return 1
		} else {
			return 0
		}
	}

	return 0
}

foo :: proc() {
	intrinsics.trap()
}
`, main_())
}
@(test) ne_with_zero_is_not_identity :: proc(t: ^testing.T) {



opt_level :: "mininal"

opaque :: proc(x: int) -> int {
	return x
}

main_ :: proc() -> int {
	a := opaque(5)
	return int(a != 0)
}

main.run_test(t, `ne_with_zero_is_not_identity`, `
package main

opt_level :: "mininal"

opaque :: proc(x: int) -> int {
	return x
}

main :: proc() -> int {
	a := opaque(5)
	return int(a != 0)
}
`, main_())
}
@(test) store_feeding_a_memcpy_source_is_wrongly_dead_store_eliminated :: proc(t: ^testing.T) {



opt_level :: "moderate"

V :: struct {
	a: i64,
	b: i64,
}

Pair :: struct {
	x: V,
	y: V,
}

ident :: proc(p: ^Pair) -> ^Pair {
	return p
}

main_ :: proc() -> int {
	pr: Pair
	p := ident(&pr)
	p.x.a = 5
	p.x.b = 6
	p.y = p.x
	p.x.a = 7
	return int(p.y.a) + int(p.y.b) * 10 + int(p.x.a) * 100
}

main.run_test(t, `store_feeding_a_memcpy_source_is_wrongly_dead_store_eliminated`, `
package main

opt_level :: "moderate"

V :: struct {
	a: i64,
	b: i64,
}

Pair :: struct {
	x: V,
	y: V,
}

ident :: proc(p: ^Pair) -> ^Pair {
	return p
}

main :: proc() -> int {
	pr: Pair
	p := ident(&pr)
	p.x.a = 5
	p.x.b = 6
	p.y = p.x
	p.x.a = 7
	return int(p.y.a) + int(p.y.b) * 10 + int(p.x.a) * 100
}
`, main_())
}
@(test) memcpify_ignores_the_loop_start_index :: proc(t: ^testing.T) {



opt_level :: "moderate"

cpy :: proc(dst: [^]u8, src: [^]u8, n: int) {
	i := 2
	for {
		if i >= n do break
		dst[i] = src[i]
		i += 1
	}
}

main_ :: proc() -> int {
	a: [8]u8
	b: [8]u8
	i := 0
	for {
		if i >= 8 do break
		a[i] = u8(i + 1)
		b[i] = 100
		i += 1
	}
	cpy(([^]u8)(&b[0]), ([^]u8)(&a[0]), 8)
	r := 0
	i = 0
	for {
		if i >= 8 do break
		r += int(b[i]) * (i + 1)
		i += 1
	}
	return r % 251
}

main.run_test(t, `memcpify_ignores_the_loop_start_index`, `
package main

opt_level :: "moderate"

cpy :: proc(dst: [^]u8, src: [^]u8, n: int) {
	i := 2
	for {
		if i >= n do break
		dst[i] = src[i]
		i += 1
	}
}

main :: proc() -> int {
	a: [8]u8
	b: [8]u8
	i := 0
	for {
		if i >= 8 do break
		a[i] = u8(i + 1)
		b[i] = 100
		i += 1
	}
	cpy(([^]u8)(&b[0]), ([^]u8)(&a[0]), 8)
	r := 0
	i = 0
	for {
		if i >= 8 do break
		r += int(b[i]) * (i + 1)
		i += 1
	}
	return r % 251
}
`, main_())
}
@(test) memcpify_turns_a_strided_loop_into_a_contiguous_copy :: proc(t: ^testing.T) {



opt_level :: "moderate"

cpy :: proc(dst: [^]u8, src: [^]u8, n: int) {
	i := 0
	for {
		if i >= n do break
		dst[i * 2] = src[i * 2]
		i += 1
	}
}

main_ :: proc() -> int {
	a: [8]u8
	b: [8]u8
	i := 0
	for {
		if i >= 8 do break
		a[i] = u8(i + 1)
		b[i] = 100
		i += 1
	}
	cpy(([^]u8)(&b[0]), ([^]u8)(&a[0]), 4)
	r := 0
	i = 0
	for {
		if i >= 8 do break
		r += int(b[i]) * (i + 1)
		i += 1
	}
	return r % 251
}

main.run_test(t, `memcpify_turns_a_strided_loop_into_a_contiguous_copy`, `
package main

opt_level :: "moderate"

cpy :: proc(dst: [^]u8, src: [^]u8, n: int) {
	i := 0
	for {
		if i >= n do break
		dst[i * 2] = src[i * 2]
		i += 1
	}
}

main :: proc() -> int {
	a: [8]u8
	b: [8]u8
	i := 0
	for {
		if i >= 8 do break
		a[i] = u8(i + 1)
		b[i] = 100
		i += 1
	}
	cpy(([^]u8)(&b[0]), ([^]u8)(&a[0]), 4)
	r := 0
	i = 0
	for {
		if i >= 8 do break
		r += int(b[i]) * (i + 1)
		i += 1
	}
	return r % 251
}
`, main_())
}
@(test) constant_folding_a_division_by_zero_crashes_the_compiler :: proc(t: ^testing.T) {



opt_level :: "aggresive"

dv :: proc(a: int, b: int) -> int {
	return a / b
}

pick :: proc(x: int) -> int {
	return x
}

main_ :: proc() -> int {
	n := pick(3)
	if n > 100 {
		return dv(1, 0)
	}
	return 7
}

main.run_test(t, `constant_folding_a_division_by_zero_crashes_the_compiler`, `
package main

opt_level :: "aggresive"

dv :: proc(a: int, b: int) -> int {
	return a / b
}

pick :: proc(x: int) -> int {
	return x
}

main :: proc() -> int {
	n := pick(3)
	if n > 100 {
		return dv(1, 0)
	}
	return 7
}
`, main_())
}
@(test) sroa_of_a_partially_initialized_struct_crashes_the_compiler :: proc(t: ^testing.T) {



opt_level :: "aggresive"

S :: struct {
	a: u8,
	c: u16,
}

sink :: proc(p: ^S) -> int {
	return int(p.a) + int(p.c) * 4
}

main_ :: proc() -> int {
	s: S
	s.a = 1
	return sink(&s)
}

main.run_test(t, `sroa_of_a_partially_initialized_struct_crashes_the_compiler`, `
package main

opt_level :: "aggresive"

S :: struct {
	a: u8,
	c: u16,
}

sink :: proc(p: ^S) -> int {
	return int(p.a) + int(p.c) * 4
}

main :: proc() -> int {
	s: S
	s.a = 1
	return sink(&s)
}
`, main_())
}
@(test) i8_multiply_missing_REX_on_imul_r_m8 :: proc(t: ^testing.T) {



opt_level :: "none"

mul8 :: proc(a: i8, b: i8) -> i8 {
	return a * b
}

main_ :: proc() -> int {
	return int(mul8(7, 9))
}

main.run_test(t, `i8_multiply_missing_REX_on_imul_r_m8`, `
package main

opt_level :: "none"

mul8 :: proc(a: i8, b: i8) -> i8 {
	return a * b
}

main :: proc() -> int {
	return int(mul8(7, 9))
}
`, main_())
}
@(test) indirect_call_through_high_register_missing_REX_B :: proc(t: ^testing.T) {



opt_level :: "none"

d :: proc(a: int, b: int, c: int, e: int, f: proc() -> int) -> int {
	r := f()
	r += a
	r += b
	r += c
	r += e
	r += f()
	return r
}

main_ :: proc() -> int {
	return d(1, 2, 4, 8, proc() -> int {return 10})
}

main.run_test(t, `indirect_call_through_high_register_missing_REX_B`, `
package main

opt_level :: "none"

d :: proc(a: int, b: int, c: int, e: int, f: proc() -> int) -> int {
	r := f()
	r += a
	r += b
	r += c
	r += e
	r += f()
	return r
}

main :: proc() -> int {
	return d(1, 2, 4, 8, proc() -> int {return 10})
}
`, main_())
}
@(test) float_spill_to_spill_move_writes_8_bytes_below_the_slot :: proc(t: ^testing.T) {



opt_level :: "none"

src :: proc(x: f64) -> f64 {
	return x * 1.5 + 1.0
}

main_ :: proc() -> int {
	a := src(1)
	b := src(2)
	c := src(3)
	d := src(4)
	e := src(5)
	f := src(6)
	g := src(7)
	h := src(8)
	i := src(9)
	j := src(10)
	k := src(11)
	l := src(12)
	m := src(13)
	n := src(14)
	o := src(15)
	p := src(16)
	q := 0
	for {
		if q == 2 do break
		t := a
		a = b; b = c; c = d; d = e; e = f; f = g; g = h; h = i
		i = j; j = k; k = l; l = m; m = n; n = o; o = p; p = t
		q += 1
	}
	return int(a + b*2 + c*3 + d*4 + e*5 + f*6 + g*7 + h*8 + i*9 + j*10 + k*11 + l*12 + m*13 + n*14 + o*15 + p*16) % 241
}

main.run_test(t, `float_spill_to_spill_move_writes_8_bytes_below_the_slot`, `
package main

opt_level :: "none"

src :: proc(x: f64) -> f64 {
	return x * 1.5 + 1.0
}

main :: proc() -> int {
	a := src(1)
	b := src(2)
	c := src(3)
	d := src(4)
	e := src(5)
	f := src(6)
	g := src(7)
	h := src(8)
	i := src(9)
	j := src(10)
	k := src(11)
	l := src(12)
	m := src(13)
	n := src(14)
	o := src(15)
	p := src(16)
	q := 0
	for {
		if q == 2 do break
		t := a
		a = b; b = c; c = d; d = e; e = f; f = g; g = h; h = i
		i = j; j = k; k = l; l = m; m = n; n = o; o = p; p = t
		q += 1
	}
	return int(a + b*2 + c*3 + d*4 + e*5 + f*6 + g*7 + h*8 + i*9 + j*10 + k*11 + l*12 + m*13 + n*14 + o*15 + p*16) % 241
}
`, main_())
}
@(test) float_compare_against_indexed_memory_drops_REX_X :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
	@(static)
	garr: [8]f64
	@(static)
	gi: [12]int

	i := 0
	for {
		if i == 8 do break
		garr[i] = f64(i)
		i += 1
	}
	a0 := gi[0]
	a1 := gi[1]
	a2 := gi[2]
	a3 := gi[3]
	a4 := gi[4]
	a5 := gi[5]
	a6 := gi[6]
	a7 := gi[7]
	a8 := gi[8]
	a9 := gi[9]
	x := f64(3.5)
	r := 0
	j := 0
	for {
		if j == 8 do break
		if x > garr[j] do r += 1
		j += 1
	}
	return r + a0 + a1 + a2 + a3 + a4 + a5 + a6 + a7 + a8 + a9
}

main.run_test(t, `float_compare_against_indexed_memory_drops_REX_X`, `
package main

opt_level :: "none"

main :: proc() -> int {
	@(static)
	garr: [8]f64
	@(static)
	gi: [12]int

	i := 0
	for {
		if i == 8 do break
		garr[i] = f64(i)
		i += 1
	}
	a0 := gi[0]
	a1 := gi[1]
	a2 := gi[2]
	a3 := gi[3]
	a4 := gi[4]
	a5 := gi[5]
	a6 := gi[6]
	a7 := gi[7]
	a8 := gi[8]
	a9 := gi[9]
	x := f64(3.5)
	r := 0
	j := 0
	for {
		if j == 8 do break
		if x > garr[j] do r += 1
		j += 1
	}
	return r + a0 + a1 + a2 + a3 + a4 + a5 + a6 + a7 + a8 + a9
}
`, main_())
}
@(test) regalloc_split_cleanup_removes_wrong_phi_from_schedule :: proc(t: ^testing.T) {



opt_level :: "none"

opaque :: proc(x: int) -> int {
	return x * 3 + 1
}

main_ :: proc() -> int {
	v0 := 1
	v1 := 2
	v2 := 3
	v3 := 4
	v4 := 5
	v5 := 6
	v6 := 7
	v7 := 8
	i := 0
	for {
		if i == 5 do break
		i += 1
		t := opaque(v0 + i)
		v0 = v0 + v1 + t
		v1 = v1 + v2 + t
		v2 = v2 + v3 + t
		v3 = v3 + v4 + t
		v4 = v4 + v5 + t
		v5 = v5 + v6 + t
		v6 = v6 + v7 + t
		v7 = v7 + v0 + t
	}
	return (v0 + v1 * 2 + v2 * 3 + v3 * 4 + v4 * 5 + v5 * 6 + v6 * 7 + v7 * 8) % 251
}

main.run_test(t, `regalloc_split_cleanup_removes_wrong_phi_from_schedule`, `
package main

opt_level :: "none"

opaque :: proc(x: int) -> int {
	return x * 3 + 1
}

main :: proc() -> int {
	v0 := 1
	v1 := 2
	v2 := 3
	v3 := 4
	v4 := 5
	v5 := 6
	v6 := 7
	v7 := 8
	i := 0
	for {
		if i == 5 do break
		i += 1
		t := opaque(v0 + i)
		v0 = v0 + v1 + t
		v1 = v1 + v2 + t
		v2 = v2 + v3 + t
		v3 = v3 + v4 + t
		v4 = v4 + v5 + t
		v5 = v5 + v6 + t
		v6 = v6 + v7 + t
		v7 = v7 + v0 + t
	}
	return (v0 + v1 * 2 + v2 * 3 + v3 * 4 + v4 * 5 + v5 * 6 + v6 * 7 + v7 * 8) % 251
}
`, main_())
}
@(test) too_many_loop_carried_values_panics_regalloc :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
	v1 := 1
	v2 := 2
	v3 := 3
	v4 := 4
	v5 := 5
	v6 := 6
	v7 := 7
	v8 := 8
	v9 := 9
	v10 := 10
	v11 := 11
	v12 := 12
	v13 := 13
	v14 := 14
	v15 := 15
	i := 0
	for {
		if i == 7 do break
		i += 1
		v1 = v1 + v2
		v2 = v2 ~ v3
		v3 = v3 + v4
		v4 = v4 ~ v5
		v5 = v5 + v6
		v6 = v6 ~ v7
		v7 = v7 + v8
		v8 = v8 ~ v9
		v9 = v9 + v10
		v10 = v10 ~ v11
		v11 = v11 + v12
		v12 = v12 ~ v13
		v13 = v13 + v14
		v14 = v14 ~ v15
		v15 = v15 ~ v1
	}
	r := 0
	r += v1 * 1
	r += v2 * 2
	r += v3 * 3
	r += v4 * 4
	r += v5 * 5
	r += v6 * 6
	r += v7 * 7
	r += v8 * 8
	r += v9 * 9
	r += v10 * 10
	r += v11 * 11
	r += v12 * 12
	r += v13 * 13
	r += v14 * 14
	r += v15 * 15
	return r % 251
}

main.run_test(t, `too_many_loop_carried_values_panics_regalloc`, `
package main

opt_level :: "none"

main :: proc() -> int {
	v1 := 1
	v2 := 2
	v3 := 3
	v4 := 4
	v5 := 5
	v6 := 6
	v7 := 7
	v8 := 8
	v9 := 9
	v10 := 10
	v11 := 11
	v12 := 12
	v13 := 13
	v14 := 14
	v15 := 15
	i := 0
	for {
		if i == 7 do break
		i += 1
		v1 = v1 + v2
		v2 = v2 ~ v3
		v3 = v3 + v4
		v4 = v4 ~ v5
		v5 = v5 + v6
		v6 = v6 ~ v7
		v7 = v7 + v8
		v8 = v8 ~ v9
		v9 = v9 + v10
		v10 = v10 ~ v11
		v11 = v11 + v12
		v12 = v12 ~ v13
		v13 = v13 + v14
		v14 = v14 ~ v15
		v15 = v15 ~ v1
	}
	r := 0
	r += v1 * 1
	r += v2 * 2
	r += v3 * 3
	r += v4 * 4
	r += v5 * 5
	r += v6 * 6
	r += v7 * 7
	r += v8 * 8
	r += v9 * 9
	r += v10 * 10
	r += v11 * 11
	r += v12 * 12
	r += v13 * 13
	r += v14 * 14
	r += v15 * 15
	return r % 251
}
`, main_())
}
@(test) loop_variable_only_written_inside_loop_keeps_pre_loop_value :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
	v4 := 42
	c := 0
	for {
		if c == 3 do break
		c += 1
		v4 = c + 7
	}
	return v4
}

main.run_test(t, `loop_variable_only_written_inside_loop_keeps_pre_loop_value`, `
package main

opt_level :: "none"

main :: proc() -> int {
	v4 := 42
	c := 0
	for {
		if c == 3 do break
		c += 1
		v4 = c + 7
	}
	return v4
}
`, main_())
}
@(test) regalloc_coalescing_merges_interfering_live_ranges :: proc(t: ^testing.T) {



opt_level :: "moderate"
opaque :: proc(x: int, y: int) -> int {
	return (x * 3 + y * 5 + 1) & 0xffff
}
main_ :: proc() -> int {
	v0 := 25
	v1 := 49
	v2 := 33
	v3 := 22
	v4 := 34
	v5 := 13
	v6 := 6
	v7 := 19
	v8 := 16
	v9 := 23
	v10 := 1
	v11 := 25
	v12 := 41
	v13 := 13
	c1 := 0
	for {
		if c1 == 5 do break
		c1 += 1
		v2, v4, v13, v5, v6, v3 = v4, v13, v5, v6, v3, v2
		v6 = (v6 * ((v13 | v1))) & 0xffff
		v6, v1, v7 = v1, v7, v6
	}
	c2 := 0
	for {
		if c2 == 5 do break
		c2 += 1
		v6 = (v6 * ((v0 - v5))) & 0xffff
		c3 := 0
		for {
			if c3 == 2 do break
			c3 += 1
			v10, v1, v5, v11, v4, v13 = v1, v5, v11, v4, v13, v10
			v4 = (v4 - ((v7 << uint(v0 & 7)))) & 0xffff
		}
		v12, v1, v8, v4, v13 = v1, v8, v4, v13, v12
		v13 = (v13 * ((v13 - v10))) & 0xffff
		v6 = (v6 & ((v8 >> uint(v9 & 7)))) & 0xffff
	}
	v5 = (v5 + ((v5 / (v1 & 7 + 1)))) & 0xffff
	r := 0
	r += v1 * 2
	r += v2 * 3
	r += v3 * 4
	r += v4 * 5
	r += v5 * 6
	r += v6 * 7
	r += v7 * 8
	r += v8 * 9
	r += v9 * 10
	r += v10 * 11
	r += v11 * 12
	r += v12 * 13
	r += v13 * 14
	return r % 251
}

main.run_test(t, `regalloc_coalescing_merges_interfering_live_ranges`, `
package main

opt_level :: "moderate"
opaque :: proc(x: int, y: int) -> int {
	return (x * 3 + y * 5 + 1) & 0xffff
}
main :: proc() -> int {
	v0 := 25
	v1 := 49
	v2 := 33
	v3 := 22
	v4 := 34
	v5 := 13
	v6 := 6
	v7 := 19
	v8 := 16
	v9 := 23
	v10 := 1
	v11 := 25
	v12 := 41
	v13 := 13
	c1 := 0
	for {
		if c1 == 5 do break
		c1 += 1
		v2, v4, v13, v5, v6, v3 = v4, v13, v5, v6, v3, v2
		v6 = (v6 * ((v13 | v1))) & 0xffff
		v6, v1, v7 = v1, v7, v6
	}
	c2 := 0
	for {
		if c2 == 5 do break
		c2 += 1
		v6 = (v6 * ((v0 - v5))) & 0xffff
		c3 := 0
		for {
			if c3 == 2 do break
			c3 += 1
			v10, v1, v5, v11, v4, v13 = v1, v5, v11, v4, v13, v10
			v4 = (v4 - ((v7 << uint(v0 & 7)))) & 0xffff
		}
		v12, v1, v8, v4, v13 = v1, v8, v4, v13, v12
		v13 = (v13 * ((v13 - v10))) & 0xffff
		v6 = (v6 & ((v8 >> uint(v9 & 7)))) & 0xffff
	}
	v5 = (v5 + ((v5 / (v1 & 7 + 1)))) & 0xffff
	r := 0
	r += v1 * 2
	r += v2 * 3
	r += v3 * 4
	r += v4 * 5
	r += v5 * 6
	r += v6 * 7
	r += v7 * 8
	r += v8 * 9
	r += v9 * 10
	r += v10 * 11
	r += v11 * 12
	r += v12 * 13
	r += v13 * 14
	return r % 251
}
`, main_())
}
@(test) loop_write_only_variable_lost_on_early_break :: proc(t: ^testing.T) {



opt_level :: "none"

main_ :: proc() -> int {
	b := 2
	i := 0
	for {
		i += 1
		if i > 1 do break
		b = 5
	}
	return b + 100
}

main.run_test(t, `loop_write_only_variable_lost_on_early_break`, `
package main

opt_level :: "none"

main :: proc() -> int {
	b := 2
	i := 0
	for {
		i += 1
		if i > 1 do break
		b = 5
	}
	return b + 100
}
`, main_())
}
@(test) zero_init_only_partially_zeroes_non_power_of_two_run :: proc(t: ^testing.T) {



opt_level :: "aggresive"

S :: struct {
	a: [3]int,
	m: int,
	b: [2]int,
}

dirty :: proc() -> int {
	junk: [64]int
	i := 0
	for {
		if i >= 64 do break
		junk[i] = 0x55
		i += 1
	}
	return junk[3]
}

main_ :: proc() -> int {
	d := dirty()
	x := S{}
	x.m = 5
	s := x.a[0] + x.a[1] + x.a[2] + x.m + x.b[0] + x.b[1]
	return (s + d) % 251
}

main.run_test(t, `zero_init_only_partially_zeroes_non_power_of_two_run`, `
package main

opt_level :: "aggresive"

S :: struct {
	a: [3]int,
	m: int,
	b: [2]int,
}

dirty :: proc() -> int {
	junk: [64]int
	i := 0
	for {
		if i >= 64 do break
		junk[i] = 0x55
		i += 1
	}
	return junk[3]
}

main :: proc() -> int {
	d := dirty()
	x := S{}
	x.m = 5
	s := x.a[0] + x.a[1] + x.a[2] + x.m + x.b[0] + x.b[1]
	return (s + d) % 251
}
`, main_())
}
@(test) memopt_renames_local_with_mismatched_access_sizes :: proc(t: ^testing.T) {



opt_level :: "all"

main_ :: proc() -> int {
	x: u64 = 0x1234
	p := transmute(^u8)&x
	return int(p^) % 251
}

main.run_test(t, `memopt_renames_local_with_mismatched_access_sizes`, `
package main

opt_level :: "all"

main :: proc() -> int {
	x: u64 = 0x1234
	p := transmute(^u8)&x
	return int(p^) % 251
}
`, main_())
}
@(test) memopt_narrow_store_into_wide_slot :: proc(t: ^testing.T) {



opt_level :: "all"

main_ :: proc() -> int {
	x: u64 = 0x1234
	p := transmute(^u8)&x
	p^ = 3
	return int(x % 251)
}

main.run_test(t, `memopt_narrow_store_into_wide_slot`, `
package main

opt_level :: "all"

main :: proc() -> int {
	x: u64 = 0x1234
	p := transmute(^u8)&x
	p^ = 3
	return int(x % 251)
}
`, main_())
}
@(test) load_forwarding_does_not_reach_a_peephole_fixpoint :: proc(t: ^testing.T) {



opt_level :: "moderate"

main_ :: proc() -> int {
	arr: [3]int
	arr[2] = arr[1]
	arr[1] = arr[0]
	return arr[2]
}

main.run_test(t, `load_forwarding_does_not_reach_a_peephole_fixpoint`, `
package main

opt_level :: "moderate"

main :: proc() -> int {
	arr: [3]int
	arr[2] = arr[1]
	arr[1] = arr[0]
	return arr[2]
}
`, main_())
}
@(test) fail_type_mismatches :: proc(t: ^testing.T) {
main.run_test(t, `fail_type_mismatches`, `
package main

Foo :: struct {
	a: int,
	b: f32,
}

takes_int :: proc(a: int) -> int {
	return a
}

main :: proc() -> int {
	a: int = "hello"
	b: f32 = takes_int(1)
	c := takes_int("nope")
	d := takes_int()
	e := takes_int(1, 2)
	f: Foo = {a = "x", c = 1}
	g := f.missing
	return b
}
`, 0)
}
@(test) fail_undeclared_names :: proc(t: ^testing.T) {
main.run_test(t, `fail_undeclared_names`, `
package main

main :: proc() -> int {
	x := undefined_thing
	y: NotAType = 0
	z := undefined_proc(1)
	w := x + y + z
	return 0
}
`, 0)
}
@(test) fail_bad_control_flow :: proc(t: ^testing.T) {
main.run_test(t, `fail_bad_control_flow`, `
package main

main :: proc() -> int {
	s := "not a bool"
	if s {
	}

	n := 1
	for v in n {
	}

	for i := 0; i < 10; i += 1 {
	}

	return 0
}
`, 0)
}
@(test) fail_bad_operands :: proc(t: ^testing.T) {
main.run_test(t, `fail_bad_operands`, `
package main

main :: proc() -> int {
	a := 1
	b := a[0]
	c := a[1:2]
	d := a^
	e := transmute(i32)a
	f := !a
	g := a + "str"
	return 0
}
`, 0)
}
@(test) fail_bad_enums_and_unions :: proc(t: ^testing.T) {
main.run_test(t, `fail_bad_enums_and_unions`, `
package main

En :: enum {
	A,
	B,
}

Un :: union {
	int,
	f32,
}

main :: proc() -> int {
	e := En.C
	f: En = .D
	u: Un = "str"
	v := u.(bool)
	w := 1
	switch x in w {
	case int:
	}
	switch y in u {
	case bool:
	}
	return 0
}
`, 0)
}
@(test) fail_bad_generics :: proc(t: ^testing.T) {
main.run_test(t, `fail_bad_generics`, `
package main

Vec :: struct($T: typeid) {
	x: T,
}

sum :: proc(a: $T, b: T) -> T {
	return a + b
}

main :: proc() -> int {
	v: Vec(int, f32)
	s := sum(1, "two")
	t := sum(1)
	return 0
}
`, 0)
}
@(test) fail_bad_returns_and_builtins :: proc(t: ^testing.T) {
main.run_test(t, `fail_bad_returns_and_builtins`, `
package main

pair :: proc() -> (int, int) {
	return 1, 2
}

main :: proc() -> int {
	return 1, 2
}

other :: proc() -> int {
	a := len(1)
	b := raw_data(1)
	c := size_of()
	d, e, f := pair()
	g := 1(2)
	return 0
}
`, 0)
}
@(test) fail_bad_literals_and_types :: proc(t: ^testing.T) {
main.run_test(t, `fail_bad_literals_and_types`, `
package main

En :: enum {
	A = "no",
}

main :: proc() -> int {
	a: bool = 1.5
	b: string = 'c'
	c: [4]u8 = {1, 2, 3, 4, 5}
	d: #simd[3]u8
	e: #simd[2]u8
	f := nil
	g: ^int = nil
	h := g == nil
	i := En.A
	return 0
}
`, 0)
}
@(test) fail_unsupported_constructs :: proc(t: ^testing.T) {
main.run_test(t, `fail_unsupported_constructs`, `
package main

Bad :: struct {
	a, b: int,
}

two_names :: proc(a, b: int) -> int {
	return a
}

main :: proc() -> int {
	x := intrinsics.nonexistent(1)
	y := intrinsics(1)
	s := "str"
	z := s[s]
	w := cast(int)1
	v := +s
	if q := 1; q > 0 {
	}
	switch r := 1; 2 {
	case:
	}
	return 0
}
`, 0)
}
@(test) fail_uninferable_polymorphism :: proc(t: ^testing.T) {
main.run_test(t, `fail_uninferable_polymorphism`, `
package main

only_ret :: proc(a: int) -> $T {
	return 0
}

main :: proc() -> int {
	return only_ret(1)
}
`, 0)
}
@(test) fuzz_0092546c2ab7b49f :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_0092546c2ab7b49f", string(#load("../fuzz/crashes/0092546c2ab7b49f.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_00f1be4a1ea4c499 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_00f1be4a1ea4c499", string(#load("../fuzz/crashes/00f1be4a1ea4c499.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_0203aad88c140351 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_0203aad88c140351", string(#load("../fuzz/crashes/0203aad88c140351.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_020e7d7b509381a0 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_020e7d7b509381a0", string(#load("../fuzz/crashes/020e7d7b509381a0.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_0300bc5a94ebd3af :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_0300bc5a94ebd3af", string(#load("../fuzz/crashes/0300bc5a94ebd3af.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_048509bec2ef3bb9 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_048509bec2ef3bb9", string(#load("../fuzz/crashes/048509bec2ef3bb9.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_0639bf08564343ff :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_0639bf08564343ff", string(#load("../fuzz/crashes/0639bf08564343ff.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_068fc5df76c88f61 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_068fc5df76c88f61", string(#load("../fuzz/crashes/068fc5df76c88f61.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_069a251c71fc3043 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_069a251c71fc3043", string(#load("../fuzz/crashes/069a251c71fc3043.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_0721e65acd7c7baa :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_0721e65acd7c7baa", string(#load("../fuzz/crashes/0721e65acd7c7baa.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_081d97c336cd27bb :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_081d97c336cd27bb", string(#load("../fuzz/crashes/081d97c336cd27bb.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_088773ea2bbe5965 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_088773ea2bbe5965", string(#load("../fuzz/crashes/088773ea2bbe5965.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_088bf8698eb2da5a :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_088bf8698eb2da5a", string(#load("../fuzz/crashes/088bf8698eb2da5a.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_09a19b37d950fc2e :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_09a19b37d950fc2e", string(#load("../fuzz/crashes/09a19b37d950fc2e.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_0a3c7f02d65f8033 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_0a3c7f02d65f8033", string(#load("../fuzz/crashes/0a3c7f02d65f8033.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_0c008bb460b13098 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_0c008bb460b13098", string(#load("../fuzz/crashes/0c008bb460b13098.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_0c29003c756e499f :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_0c29003c756e499f", string(#load("../fuzz/crashes/0c29003c756e499f.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_0da73fc427a77604 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_0da73fc427a77604", string(#load("../fuzz/crashes/0da73fc427a77604.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_0e9da6ef50b197b9 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_0e9da6ef50b197b9", string(#load("../fuzz/crashes/0e9da6ef50b197b9.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_0f85d4dd001b9431 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_0f85d4dd001b9431", string(#load("../fuzz/crashes/0f85d4dd001b9431.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_0fb906ca568cdee0 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_0fb906ca568cdee0", string(#load("../fuzz/crashes/0fb906ca568cdee0.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_0fd938d1b418c758 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_0fd938d1b418c758", string(#load("../fuzz/crashes/0fd938d1b418c758.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_1128e8299edbd793 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_1128e8299edbd793", string(#load("../fuzz/crashes/1128e8299edbd793.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_1165d2dfb8a513a3 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_1165d2dfb8a513a3", string(#load("../fuzz/crashes/1165d2dfb8a513a3.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_12a994b2014ac1cd :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_12a994b2014ac1cd", string(#load("../fuzz/crashes/12a994b2014ac1cd.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_138174df7dd90a57 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_138174df7dd90a57", string(#load("../fuzz/crashes/138174df7dd90a57.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_13b6eff7bae728c5 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_13b6eff7bae728c5", string(#load("../fuzz/crashes/13b6eff7bae728c5.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_143ba6c4d15b7e71 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_143ba6c4d15b7e71", string(#load("../fuzz/crashes/143ba6c4d15b7e71.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_15d35511bb00b118 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_15d35511bb00b118", string(#load("../fuzz/crashes/15d35511bb00b118.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_16007f507fa7313c :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_16007f507fa7313c", string(#load("../fuzz/crashes/16007f507fa7313c.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_1618cdf5939ed310 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_1618cdf5939ed310", string(#load("../fuzz/crashes/1618cdf5939ed310.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_19ed1211a3af552b :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_19ed1211a3af552b", string(#load("../fuzz/crashes/19ed1211a3af552b.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_1a283fe9c6771942 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_1a283fe9c6771942", string(#load("../fuzz/crashes/1a283fe9c6771942.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_1a78995eb6d569de :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_1a78995eb6d569de", string(#load("../fuzz/crashes/1a78995eb6d569de.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_1b80b8ed7c18cc63 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_1b80b8ed7c18cc63", string(#load("../fuzz/crashes/1b80b8ed7c18cc63.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_1b9796c125f9c23c :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_1b9796c125f9c23c", string(#load("../fuzz/crashes/1b9796c125f9c23c.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_1b990e07ea5f40a9 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_1b990e07ea5f40a9", string(#load("../fuzz/crashes/1b990e07ea5f40a9.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_1c0d080360e500fa :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_1c0d080360e500fa", string(#load("../fuzz/crashes/1c0d080360e500fa.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_1c6e8391c36411bb :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_1c6e8391c36411bb", string(#load("../fuzz/crashes/1c6e8391c36411bb.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_1d2d301480f63b51 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_1d2d301480f63b51", string(#load("../fuzz/crashes/1d2d301480f63b51.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_1db67484c727f010 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_1db67484c727f010", string(#load("../fuzz/crashes/1db67484c727f010.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_1e13b7033be8b60d :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_1e13b7033be8b60d", string(#load("../fuzz/crashes/1e13b7033be8b60d.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_1e92fe38344efb51 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_1e92fe38344efb51", string(#load("../fuzz/crashes/1e92fe38344efb51.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_1eacbfeb5cf75727 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_1eacbfeb5cf75727", string(#load("../fuzz/crashes/1eacbfeb5cf75727.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_1ee069b9a37f28bd :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_1ee069b9a37f28bd", string(#load("../fuzz/crashes/1ee069b9a37f28bd.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_1fb209daadec6826 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_1fb209daadec6826", string(#load("../fuzz/crashes/1fb209daadec6826.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_1fc74b88d64644e5 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_1fc74b88d64644e5", string(#load("../fuzz/crashes/1fc74b88d64644e5.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_2117fcce8bd2b93a :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_2117fcce8bd2b93a", string(#load("../fuzz/crashes/2117fcce8bd2b93a.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_21e7b1c4e9fe9be9 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_21e7b1c4e9fe9be9", string(#load("../fuzz/crashes/21e7b1c4e9fe9be9.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_21ef248e190e758a :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_21ef248e190e758a", string(#load("../fuzz/crashes/21ef248e190e758a.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_22a8cf775f123a89 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_22a8cf775f123a89", string(#load("../fuzz/crashes/22a8cf775f123a89.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_230f522f6aecda3f :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_230f522f6aecda3f", string(#load("../fuzz/crashes/230f522f6aecda3f.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_23110c58f5712061 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_23110c58f5712061", string(#load("../fuzz/crashes/23110c58f5712061.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_239d268ed3d47b00 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_239d268ed3d47b00", string(#load("../fuzz/crashes/239d268ed3d47b00.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_2445bb70534299d3 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_2445bb70534299d3", string(#load("../fuzz/crashes/2445bb70534299d3.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_249b0ac791d5b057 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_249b0ac791d5b057", string(#load("../fuzz/crashes/249b0ac791d5b057.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_249ce1e746c14e61 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_249ce1e746c14e61", string(#load("../fuzz/crashes/249ce1e746c14e61.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_24b8480a09b4802d :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_24b8480a09b4802d", string(#load("../fuzz/crashes/24b8480a09b4802d.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_25e5f177ed580c1e :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_25e5f177ed580c1e", string(#load("../fuzz/crashes/25e5f177ed580c1e.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_26dcbdc912b96b8c :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_26dcbdc912b96b8c", string(#load("../fuzz/crashes/26dcbdc912b96b8c.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_27dd55a810f5fd1a :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_27dd55a810f5fd1a", string(#load("../fuzz/crashes/27dd55a810f5fd1a.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_280ceaf20119fbbe :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_280ceaf20119fbbe", string(#load("../fuzz/crashes/280ceaf20119fbbe.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_28bb3ccdb42d53f4 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_28bb3ccdb42d53f4", string(#load("../fuzz/crashes/28bb3ccdb42d53f4.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_2915d05b950657f9 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_2915d05b950657f9", string(#load("../fuzz/crashes/2915d05b950657f9.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_29fba7ecfb5edbb4 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_29fba7ecfb5edbb4", string(#load("../fuzz/crashes/29fba7ecfb5edbb4.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_2af086ae67895e5b :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_2af086ae67895e5b", string(#load("../fuzz/crashes/2af086ae67895e5b.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_2b03b533ea8e11c3 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_2b03b533ea8e11c3", string(#load("../fuzz/crashes/2b03b533ea8e11c3.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_2bbac7f57028c127 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_2bbac7f57028c127", string(#load("../fuzz/crashes/2bbac7f57028c127.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_2c701dbd10c82f30 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_2c701dbd10c82f30", string(#load("../fuzz/crashes/2c701dbd10c82f30.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_2d70765ec813fbda :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_2d70765ec813fbda", string(#load("../fuzz/crashes/2d70765ec813fbda.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_2d92e1c8947b7ef5 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_2d92e1c8947b7ef5", string(#load("../fuzz/crashes/2d92e1c8947b7ef5.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_2ddb05ec4c680ea0 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_2ddb05ec4c680ea0", string(#load("../fuzz/crashes/2ddb05ec4c680ea0.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_2e17ddfd8d478784 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_2e17ddfd8d478784", string(#load("../fuzz/crashes/2e17ddfd8d478784.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_2fad23e9030f5586 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_2fad23e9030f5586", string(#load("../fuzz/crashes/2fad23e9030f5586.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_30ca0993dc9f6db2 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_30ca0993dc9f6db2", string(#load("../fuzz/crashes/30ca0993dc9f6db2.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_326fadd3736dc694 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_326fadd3736dc694", string(#load("../fuzz/crashes/326fadd3736dc694.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_35306c83802798aa :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_35306c83802798aa", string(#load("../fuzz/crashes/35306c83802798aa.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_3694d612238b7386 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_3694d612238b7386", string(#load("../fuzz/crashes/3694d612238b7386.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_3695c625229fd001 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_3695c625229fd001", string(#load("../fuzz/crashes/3695c625229fd001.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_3803231e08409fc2 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_3803231e08409fc2", string(#load("../fuzz/crashes/3803231e08409fc2.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_381d75b8095cc524 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_381d75b8095cc524", string(#load("../fuzz/crashes/381d75b8095cc524.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_38a20d655454e587 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_38a20d655454e587", string(#load("../fuzz/crashes/38a20d655454e587.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_38ba14359fb7afac :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_38ba14359fb7afac", string(#load("../fuzz/crashes/38ba14359fb7afac.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_38fe5865904d7b82 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_38fe5865904d7b82", string(#load("../fuzz/crashes/38fe5865904d7b82.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_39c4666c970103c1 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_39c4666c970103c1", string(#load("../fuzz/crashes/39c4666c970103c1.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_3a7d87cfa469724c :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_3a7d87cfa469724c", string(#load("../fuzz/crashes/3a7d87cfa469724c.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_3adeef555cffaa37 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_3adeef555cffaa37", string(#load("../fuzz/crashes/3adeef555cffaa37.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_3af9528b9ce7cb0b :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_3af9528b9ce7cb0b", string(#load("../fuzz/crashes/3af9528b9ce7cb0b.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_3b58882c836ff6fb :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_3b58882c836ff6fb", string(#load("../fuzz/crashes/3b58882c836ff6fb.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_3c4e76e6f0f02506 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_3c4e76e6f0f02506", string(#load("../fuzz/crashes/3c4e76e6f0f02506.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_3d64d7eb5f6b9335 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_3d64d7eb5f6b9335", string(#load("../fuzz/crashes/3d64d7eb5f6b9335.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_3d770803ed79939d :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_3d770803ed79939d", string(#load("../fuzz/crashes/3d770803ed79939d.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_3e3050d7cd2b15e9 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_3e3050d7cd2b15e9", string(#load("../fuzz/crashes/3e3050d7cd2b15e9.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_3edba3e2b0bc9681 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_3edba3e2b0bc9681", string(#load("../fuzz/crashes/3edba3e2b0bc9681.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_3f7c88eb2c7a7fd8 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_3f7c88eb2c7a7fd8", string(#load("../fuzz/crashes/3f7c88eb2c7a7fd8.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_3fd1d1e8d47643ac :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_3fd1d1e8d47643ac", string(#load("../fuzz/crashes/3fd1d1e8d47643ac.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_405a628c1c0b8ed6 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_405a628c1c0b8ed6", string(#load("../fuzz/crashes/405a628c1c0b8ed6.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_40affc6de18ecd36 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_40affc6de18ecd36", string(#load("../fuzz/crashes/40affc6de18ecd36.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_40bd31b0c24b08fc :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_40bd31b0c24b08fc", string(#load("../fuzz/crashes/40bd31b0c24b08fc.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_417892a93d85da25 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_417892a93d85da25", string(#load("../fuzz/crashes/417892a93d85da25.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_4218fb108a4b7066 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_4218fb108a4b7066", string(#load("../fuzz/crashes/4218fb108a4b7066.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_42d391c83249c4b5 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_42d391c83249c4b5", string(#load("../fuzz/crashes/42d391c83249c4b5.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_44e67e02ec76d835 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_44e67e02ec76d835", string(#load("../fuzz/crashes/44e67e02ec76d835.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_452be132408e7ca3 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_452be132408e7ca3", string(#load("../fuzz/crashes/452be132408e7ca3.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_45304486798098df :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_45304486798098df", string(#load("../fuzz/crashes/45304486798098df.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_4575111653a305f0 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_4575111653a305f0", string(#load("../fuzz/crashes/4575111653a305f0.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_460039c96c6a5c7f :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_460039c96c6a5c7f", string(#load("../fuzz/crashes/460039c96c6a5c7f.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_460659a4dfc0f365 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_460659a4dfc0f365", string(#load("../fuzz/crashes/460659a4dfc0f365.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_470207f2655715f6 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_470207f2655715f6", string(#load("../fuzz/crashes/470207f2655715f6.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_48764a68702cdeef :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_48764a68702cdeef", string(#load("../fuzz/crashes/48764a68702cdeef.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_491a3ef3d1338b50 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_491a3ef3d1338b50", string(#load("../fuzz/crashes/491a3ef3d1338b50.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_4a34eeedb271c985 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_4a34eeedb271c985", string(#load("../fuzz/crashes/4a34eeedb271c985.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_4afc2a59d454f384 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_4afc2a59d454f384", string(#load("../fuzz/crashes/4afc2a59d454f384.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_4b0077f8373bf5f2 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_4b0077f8373bf5f2", string(#load("../fuzz/crashes/4b0077f8373bf5f2.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_4b032e8fba38315b :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_4b032e8fba38315b", string(#load("../fuzz/crashes/4b032e8fba38315b.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_4b6164d028fc95ee :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_4b6164d028fc95ee", string(#load("../fuzz/crashes/4b6164d028fc95ee.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_4b64ac357600a6c9 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_4b64ac357600a6c9", string(#load("../fuzz/crashes/4b64ac357600a6c9.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_4bb848413363b221 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_4bb848413363b221", string(#load("../fuzz/crashes/4bb848413363b221.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_4c3f41acb4d28e26 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_4c3f41acb4d28e26", string(#load("../fuzz/crashes/4c3f41acb4d28e26.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_4c97ce05daec0e0b :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_4c97ce05daec0e0b", string(#load("../fuzz/crashes/4c97ce05daec0e0b.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_4cd81617d34c8bbd :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_4cd81617d34c8bbd", string(#load("../fuzz/crashes/4cd81617d34c8bbd.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_4d66871ae5ce9558 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_4d66871ae5ce9558", string(#load("../fuzz/crashes/4d66871ae5ce9558.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_4ea5de0da090777d :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_4ea5de0da090777d", string(#load("../fuzz/crashes/4ea5de0da090777d.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_4eb78b4440de8e76 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_4eb78b4440de8e76", string(#load("../fuzz/crashes/4eb78b4440de8e76.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_4efb0edab9b1cfe1 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_4efb0edab9b1cfe1", string(#load("../fuzz/crashes/4efb0edab9b1cfe1.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_4ff67888e732768d :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_4ff67888e732768d", string(#load("../fuzz/crashes/4ff67888e732768d.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_50993f42196b8123 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_50993f42196b8123", string(#load("../fuzz/crashes/50993f42196b8123.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_517bc3714f1680fd :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_517bc3714f1680fd", string(#load("../fuzz/crashes/517bc3714f1680fd.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_545f27c8e429b07a :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_545f27c8e429b07a", string(#load("../fuzz/crashes/545f27c8e429b07a.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_548b0b164a585630 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_548b0b164a585630", string(#load("../fuzz/crashes/548b0b164a585630.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_5548ff415bcc962a :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_5548ff415bcc962a", string(#load("../fuzz/crashes/5548ff415bcc962a.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_5550031bfa15fd73 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_5550031bfa15fd73", string(#load("../fuzz/crashes/5550031bfa15fd73.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_56c9b37c378020c3 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_56c9b37c378020c3", string(#load("../fuzz/crashes/56c9b37c378020c3.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_57ed050ce842d3d9 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_57ed050ce842d3d9", string(#load("../fuzz/crashes/57ed050ce842d3d9.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_58138253e0fbcf01 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_58138253e0fbcf01", string(#load("../fuzz/crashes/58138253e0fbcf01.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_583bdae3ebb07ccb :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_583bdae3ebb07ccb", string(#load("../fuzz/crashes/583bdae3ebb07ccb.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_5a3cc60282a7ceb7 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_5a3cc60282a7ceb7", string(#load("../fuzz/crashes/5a3cc60282a7ceb7.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_5aaf244ff7ba6a61 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_5aaf244ff7ba6a61", string(#load("../fuzz/crashes/5aaf244ff7ba6a61.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_5adc0761d1b5d5fb :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_5adc0761d1b5d5fb", string(#load("../fuzz/crashes/5adc0761d1b5d5fb.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_5bb5d90d19412b98 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_5bb5d90d19412b98", string(#load("../fuzz/crashes/5bb5d90d19412b98.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_5c2db720e498b777 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_5c2db720e498b777", string(#load("../fuzz/crashes/5c2db720e498b777.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_5cddd212dc714a98 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_5cddd212dc714a98", string(#load("../fuzz/crashes/5cddd212dc714a98.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_5e66f501c1ca8a38 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_5e66f501c1ca8a38", string(#load("../fuzz/crashes/5e66f501c1ca8a38.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_5e827ebb0a4fb9ae :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_5e827ebb0a4fb9ae", string(#load("../fuzz/crashes/5e827ebb0a4fb9ae.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_5f99aa3ed1eca8d7 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_5f99aa3ed1eca8d7", string(#load("../fuzz/crashes/5f99aa3ed1eca8d7.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_5fbd68babed33315 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_5fbd68babed33315", string(#load("../fuzz/crashes/5fbd68babed33315.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_5fc14a55ff58a080 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_5fc14a55ff58a080", string(#load("../fuzz/crashes/5fc14a55ff58a080.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_6069c4c3375a242b :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_6069c4c3375a242b", string(#load("../fuzz/crashes/6069c4c3375a242b.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_60c0f6e637d06ea6 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_60c0f6e637d06ea6", string(#load("../fuzz/crashes/60c0f6e637d06ea6.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_6134f434691cc1de :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_6134f434691cc1de", string(#load("../fuzz/crashes/6134f434691cc1de.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_61b129a0f6184749 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_61b129a0f6184749", string(#load("../fuzz/crashes/61b129a0f6184749.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_63ec86085f114052 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_63ec86085f114052", string(#load("../fuzz/crashes/63ec86085f114052.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_63f5f663b19dc6bd :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_63f5f663b19dc6bd", string(#load("../fuzz/crashes/63f5f663b19dc6bd.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_642e1fe1201fdefd :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_642e1fe1201fdefd", string(#load("../fuzz/crashes/642e1fe1201fdefd.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_64c42df6eb6c1d9a :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_64c42df6eb6c1d9a", string(#load("../fuzz/crashes/64c42df6eb6c1d9a.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_67370eada956f876 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_67370eada956f876", string(#load("../fuzz/crashes/67370eada956f876.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_6804b64ee0c79299 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_6804b64ee0c79299", string(#load("../fuzz/crashes/6804b64ee0c79299.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_6a0f4bdd81a92b71 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_6a0f4bdd81a92b71", string(#load("../fuzz/crashes/6a0f4bdd81a92b71.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_6b88fb018f1555d4 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_6b88fb018f1555d4", string(#load("../fuzz/crashes/6b88fb018f1555d4.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_6bf96799eae2e2ff :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_6bf96799eae2e2ff", string(#load("../fuzz/crashes/6bf96799eae2e2ff.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_6ca1dc1325565c32 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_6ca1dc1325565c32", string(#load("../fuzz/crashes/6ca1dc1325565c32.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_6cc8d6b79cdf929b :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_6cc8d6b79cdf929b", string(#load("../fuzz/crashes/6cc8d6b79cdf929b.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_6d45aa83b67e183f :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_6d45aa83b67e183f", string(#load("../fuzz/crashes/6d45aa83b67e183f.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_6e095db8e71d7dae :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_6e095db8e71d7dae", string(#load("../fuzz/crashes/6e095db8e71d7dae.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_6f0a1ecc7b3b8fc9 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_6f0a1ecc7b3b8fc9", string(#load("../fuzz/crashes/6f0a1ecc7b3b8fc9.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_6fb466a2a015ca51 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_6fb466a2a015ca51", string(#load("../fuzz/crashes/6fb466a2a015ca51.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_6fead3d00de19a0c :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_6fead3d00de19a0c", string(#load("../fuzz/crashes/6fead3d00de19a0c.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_706e77973e3c3dec :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_706e77973e3c3dec", string(#load("../fuzz/crashes/706e77973e3c3dec.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_707fcf00cb971bba :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_707fcf00cb971bba", string(#load("../fuzz/crashes/707fcf00cb971bba.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_71c25f004d4563d6 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_71c25f004d4563d6", string(#load("../fuzz/crashes/71c25f004d4563d6.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_722c698b882de32e :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_722c698b882de32e", string(#load("../fuzz/crashes/722c698b882de32e.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_72473105c3e4c555 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_72473105c3e4c555", string(#load("../fuzz/crashes/72473105c3e4c555.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_725439d16b44056b :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_725439d16b44056b", string(#load("../fuzz/crashes/725439d16b44056b.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_735d851c185d40c5 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_735d851c185d40c5", string(#load("../fuzz/crashes/735d851c185d40c5.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_77a7dc0e448981bf :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_77a7dc0e448981bf", string(#load("../fuzz/crashes/77a7dc0e448981bf.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_78605c532de962b3 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_78605c532de962b3", string(#load("../fuzz/crashes/78605c532de962b3.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_7927dc0a94ee3164 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_7927dc0a94ee3164", string(#load("../fuzz/crashes/7927dc0a94ee3164.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_7944b1e820d86ce9 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_7944b1e820d86ce9", string(#load("../fuzz/crashes/7944b1e820d86ce9.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_7b636e7734c2b4a2 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_7b636e7734c2b4a2", string(#load("../fuzz/crashes/7b636e7734c2b4a2.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_7c273592f5d50f65 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_7c273592f5d50f65", string(#load("../fuzz/crashes/7c273592f5d50f65.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_7c6463154d91a3b4 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_7c6463154d91a3b4", string(#load("../fuzz/crashes/7c6463154d91a3b4.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_7d7901ea81980500 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_7d7901ea81980500", string(#load("../fuzz/crashes/7d7901ea81980500.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_7dc40d58a2522572 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_7dc40d58a2522572", string(#load("../fuzz/crashes/7dc40d58a2522572.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_7e0442e8e9b88ece :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_7e0442e8e9b88ece", string(#load("../fuzz/crashes/7e0442e8e9b88ece.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_7e843b94a774720d :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_7e843b94a774720d", string(#load("../fuzz/crashes/7e843b94a774720d.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_7f4cce536a7a51ce :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_7f4cce536a7a51ce", string(#load("../fuzz/crashes/7f4cce536a7a51ce.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_80042fa7ee761fda :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_80042fa7ee761fda", string(#load("../fuzz/crashes/80042fa7ee761fda.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_8009e3779fb87e3c :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_8009e3779fb87e3c", string(#load("../fuzz/crashes/8009e3779fb87e3c.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_80c6049b0e0e7895 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_80c6049b0e0e7895", string(#load("../fuzz/crashes/80c6049b0e0e7895.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_8507b15ab03cecb7 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_8507b15ab03cecb7", string(#load("../fuzz/crashes/8507b15ab03cecb7.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_8568bca44b2b44e9 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_8568bca44b2b44e9", string(#load("../fuzz/crashes/8568bca44b2b44e9.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_87665ff3ff8f1443 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_87665ff3ff8f1443", string(#load("../fuzz/crashes/87665ff3ff8f1443.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_89eff21a6ad4b645 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_89eff21a6ad4b645", string(#load("../fuzz/crashes/89eff21a6ad4b645.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_8aa863b2e1d9d59b :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_8aa863b2e1d9d59b", string(#load("../fuzz/crashes/8aa863b2e1d9d59b.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_8accac92a8efcb8b :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_8accac92a8efcb8b", string(#load("../fuzz/crashes/8accac92a8efcb8b.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_8af43123f3b798a0 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_8af43123f3b798a0", string(#load("../fuzz/crashes/8af43123f3b798a0.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_8b66bf9a2399ad32 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_8b66bf9a2399ad32", string(#load("../fuzz/crashes/8b66bf9a2399ad32.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_8c20a31d0c96cf4c :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_8c20a31d0c96cf4c", string(#load("../fuzz/crashes/8c20a31d0c96cf4c.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_8c9085f0b8f40963 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_8c9085f0b8f40963", string(#load("../fuzz/crashes/8c9085f0b8f40963.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_8ce7fcfddfd1f168 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_8ce7fcfddfd1f168", string(#load("../fuzz/crashes/8ce7fcfddfd1f168.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_8d02688eedadc9ba :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_8d02688eedadc9ba", string(#load("../fuzz/crashes/8d02688eedadc9ba.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_8d645f424162a9b7 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_8d645f424162a9b7", string(#load("../fuzz/crashes/8d645f424162a9b7.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_8da68f3f1084091f :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_8da68f3f1084091f", string(#load("../fuzz/crashes/8da68f3f1084091f.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_8e7adf24c72ed700 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_8e7adf24c72ed700", string(#load("../fuzz/crashes/8e7adf24c72ed700.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_8faeef21704268cf :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_8faeef21704268cf", string(#load("../fuzz/crashes/8faeef21704268cf.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_90fa93de6d007eb3 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_90fa93de6d007eb3", string(#load("../fuzz/crashes/90fa93de6d007eb3.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_9115484d44c722df :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_9115484d44c722df", string(#load("../fuzz/crashes/9115484d44c722df.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_917e1314776fedd6 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_917e1314776fedd6", string(#load("../fuzz/crashes/917e1314776fedd6.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_91d990f04a81e2e8 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_91d990f04a81e2e8", string(#load("../fuzz/crashes/91d990f04a81e2e8.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_924e995f1998bc23 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_924e995f1998bc23", string(#load("../fuzz/crashes/924e995f1998bc23.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_9282598c7f5c620e :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_9282598c7f5c620e", string(#load("../fuzz/crashes/9282598c7f5c620e.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_93a52c762ce83861 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_93a52c762ce83861", string(#load("../fuzz/crashes/93a52c762ce83861.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_93e30f0e59337a33 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_93e30f0e59337a33", string(#load("../fuzz/crashes/93e30f0e59337a33.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_9488f608cdc5b1e4 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_9488f608cdc5b1e4", string(#load("../fuzz/crashes/9488f608cdc5b1e4.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_95726bd66f2aec21 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_95726bd66f2aec21", string(#load("../fuzz/crashes/95726bd66f2aec21.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_95c899471dc3037f :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_95c899471dc3037f", string(#load("../fuzz/crashes/95c899471dc3037f.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_96a3c1d927d6ee5e :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_96a3c1d927d6ee5e", string(#load("../fuzz/crashes/96a3c1d927d6ee5e.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_974a8f7be9387890 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_974a8f7be9387890", string(#load("../fuzz/crashes/974a8f7be9387890.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_98f10333f52e869d :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_98f10333f52e869d", string(#load("../fuzz/crashes/98f10333f52e869d.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_98fe50aa29548290 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_98fe50aa29548290", string(#load("../fuzz/crashes/98fe50aa29548290.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_994094487cc5227c :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_994094487cc5227c", string(#load("../fuzz/crashes/994094487cc5227c.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_99b020bebb52f46d :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_99b020bebb52f46d", string(#load("../fuzz/crashes/99b020bebb52f46d.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_9a1c839e37124141 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_9a1c839e37124141", string(#load("../fuzz/crashes/9a1c839e37124141.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_9b8f5b72fd34bd97 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_9b8f5b72fd34bd97", string(#load("../fuzz/crashes/9b8f5b72fd34bd97.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_9bd189c149839efe :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_9bd189c149839efe", string(#load("../fuzz/crashes/9bd189c149839efe.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_9d123cf5a99514de :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_9d123cf5a99514de", string(#load("../fuzz/crashes/9d123cf5a99514de.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_9d4d5f4f78d0a648 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_9d4d5f4f78d0a648", string(#load("../fuzz/crashes/9d4d5f4f78d0a648.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_9dccdd62c52fbeae :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_9dccdd62c52fbeae", string(#load("../fuzz/crashes/9dccdd62c52fbeae.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_9f9194380b1709b8 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_9f9194380b1709b8", string(#load("../fuzz/crashes/9f9194380b1709b8.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_a2d0e3e918825b8f :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_a2d0e3e918825b8f", string(#load("../fuzz/crashes/a2d0e3e918825b8f.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_a36ac16665f69210 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_a36ac16665f69210", string(#load("../fuzz/crashes/a36ac16665f69210.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_a3ef5ed25b542d9c :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_a3ef5ed25b542d9c", string(#load("../fuzz/crashes/a3ef5ed25b542d9c.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_a55313ed17ebaee2 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_a55313ed17ebaee2", string(#load("../fuzz/crashes/a55313ed17ebaee2.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_a727fc8ea03e906c :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_a727fc8ea03e906c", string(#load("../fuzz/crashes/a727fc8ea03e906c.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_a73fcadf68c872c6 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_a73fcadf68c872c6", string(#load("../fuzz/crashes/a73fcadf68c872c6.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_a9422986dd614f75 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_a9422986dd614f75", string(#load("../fuzz/crashes/a9422986dd614f75.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_ac2b7b7753b87469 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_ac2b7b7753b87469", string(#load("../fuzz/crashes/ac2b7b7753b87469.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_acc2e4aa72367b6e :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_acc2e4aa72367b6e", string(#load("../fuzz/crashes/acc2e4aa72367b6e.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_acde951ece530f20 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_acde951ece530f20", string(#load("../fuzz/crashes/acde951ece530f20.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_ad74c3dace87a3f5 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_ad74c3dace87a3f5", string(#load("../fuzz/crashes/ad74c3dace87a3f5.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_aedab8f30ffabea7 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_aedab8f30ffabea7", string(#load("../fuzz/crashes/aedab8f30ffabea7.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_af5db22cd162f162 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_af5db22cd162f162", string(#load("../fuzz/crashes/af5db22cd162f162.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_b00d8f97d74ec39b :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_b00d8f97d74ec39b", string(#load("../fuzz/crashes/b00d8f97d74ec39b.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_b043053bf06bec8d :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_b043053bf06bec8d", string(#load("../fuzz/crashes/b043053bf06bec8d.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_b0ded71d46eaf18a :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_b0ded71d46eaf18a", string(#load("../fuzz/crashes/b0ded71d46eaf18a.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_b13ce60d8c1c678d :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_b13ce60d8c1c678d", string(#load("../fuzz/crashes/b13ce60d8c1c678d.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_b3cd0ca461d38b69 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_b3cd0ca461d38b69", string(#load("../fuzz/crashes/b3cd0ca461d38b69.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_b49cfe9645c11ec8 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_b49cfe9645c11ec8", string(#load("../fuzz/crashes/b49cfe9645c11ec8.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_b73ac5f02a10fb25 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_b73ac5f02a10fb25", string(#load("../fuzz/crashes/b73ac5f02a10fb25.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_b866701a7cd788b6 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_b866701a7cd788b6", string(#load("../fuzz/crashes/b866701a7cd788b6.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_b9eb46765a26b5e3 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_b9eb46765a26b5e3", string(#load("../fuzz/crashes/b9eb46765a26b5e3.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_ba2f517f1932aa02 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_ba2f517f1932aa02", string(#load("../fuzz/crashes/ba2f517f1932aa02.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_bad95fc637825862 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_bad95fc637825862", string(#load("../fuzz/crashes/bad95fc637825862.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_bb0c9af0d8d881aa :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_bb0c9af0d8d881aa", string(#load("../fuzz/crashes/bb0c9af0d8d881aa.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_bc04d4970fae3ee1 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_bc04d4970fae3ee1", string(#load("../fuzz/crashes/bc04d4970fae3ee1.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_bc22ab2bb9993674 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_bc22ab2bb9993674", string(#load("../fuzz/crashes/bc22ab2bb9993674.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_bcea93632dfba648 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_bcea93632dfba648", string(#load("../fuzz/crashes/bcea93632dfba648.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_bd1fc6166433ba24 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_bd1fc6166433ba24", string(#load("../fuzz/crashes/bd1fc6166433ba24.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_bd2b626142b501d2 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_bd2b626142b501d2", string(#load("../fuzz/crashes/bd2b626142b501d2.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_bd3b43f3f2392971 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_bd3b43f3f2392971", string(#load("../fuzz/crashes/bd3b43f3f2392971.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_bdde1d3fa0594177 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_bdde1d3fa0594177", string(#load("../fuzz/crashes/bdde1d3fa0594177.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_be2975afc69253ad :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_be2975afc69253ad", string(#load("../fuzz/crashes/be2975afc69253ad.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_bf4e22cd4d209240 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_bf4e22cd4d209240", string(#load("../fuzz/crashes/bf4e22cd4d209240.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_c06dda413ce7ba25 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_c06dda413ce7ba25", string(#load("../fuzz/crashes/c06dda413ce7ba25.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_c090b7953da1f4fb :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_c090b7953da1f4fb", string(#load("../fuzz/crashes/c090b7953da1f4fb.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_c129c12d2884540a :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_c129c12d2884540a", string(#load("../fuzz/crashes/c129c12d2884540a.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_c1e7b611bfd6fce8 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_c1e7b611bfd6fce8", string(#load("../fuzz/crashes/c1e7b611bfd6fce8.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_c2e168b560def363 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_c2e168b560def363", string(#load("../fuzz/crashes/c2e168b560def363.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_c3d7e368e0c8fcb1 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_c3d7e368e0c8fcb1", string(#load("../fuzz/crashes/c3d7e368e0c8fcb1.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_c3ed70ba68c6b76a :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_c3ed70ba68c6b76a", string(#load("../fuzz/crashes/c3ed70ba68c6b76a.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_c5c4f7e949792e16 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_c5c4f7e949792e16", string(#load("../fuzz/crashes/c5c4f7e949792e16.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_c63bf3c83306196f :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_c63bf3c83306196f", string(#load("../fuzz/crashes/c63bf3c83306196f.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_c767196d5f4fa9b5 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_c767196d5f4fa9b5", string(#load("../fuzz/crashes/c767196d5f4fa9b5.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_c82a9a4e80e2cb24 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_c82a9a4e80e2cb24", string(#load("../fuzz/crashes/c82a9a4e80e2cb24.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_c88b9c5155543d67 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_c88b9c5155543d67", string(#load("../fuzz/crashes/c88b9c5155543d67.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_c8df2a6263c56e3d :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_c8df2a6263c56e3d", string(#load("../fuzz/crashes/c8df2a6263c56e3d.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_c9a56471e2f6761e :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_c9a56471e2f6761e", string(#load("../fuzz/crashes/c9a56471e2f6761e.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_c9ddac9381eb506c :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_c9ddac9381eb506c", string(#load("../fuzz/crashes/c9ddac9381eb506c.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_cabc65bbec5e50c5 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_cabc65bbec5e50c5", string(#load("../fuzz/crashes/cabc65bbec5e50c5.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_cb45d5fed93f0bf1 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_cb45d5fed93f0bf1", string(#load("../fuzz/crashes/cb45d5fed93f0bf1.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_cb8dea2ed1fe4209 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_cb8dea2ed1fe4209", string(#load("../fuzz/crashes/cb8dea2ed1fe4209.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_cd38ccd3eec386e9 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_cd38ccd3eec386e9", string(#load("../fuzz/crashes/cd38ccd3eec386e9.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_cd9e76ff5d4ccb08 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_cd9e76ff5d4ccb08", string(#load("../fuzz/crashes/cd9e76ff5d4ccb08.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_cde1b58350dba290 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_cde1b58350dba290", string(#load("../fuzz/crashes/cde1b58350dba290.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_ce5e146810c2a4eb :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_ce5e146810c2a4eb", string(#load("../fuzz/crashes/ce5e146810c2a4eb.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_ce850b6fc6aa74f1 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_ce850b6fc6aa74f1", string(#load("../fuzz/crashes/ce850b6fc6aa74f1.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_ce93d6680b2917fe :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_ce93d6680b2917fe", string(#load("../fuzz/crashes/ce93d6680b2917fe.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_d0df1afc43f8f7ab :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_d0df1afc43f8f7ab", string(#load("../fuzz/crashes/d0df1afc43f8f7ab.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_d1475af90d064241 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_d1475af90d064241", string(#load("../fuzz/crashes/d1475af90d064241.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_d14a3c5e2154af44 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_d14a3c5e2154af44", string(#load("../fuzz/crashes/d14a3c5e2154af44.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_d161160fa4c6303f :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_d161160fa4c6303f", string(#load("../fuzz/crashes/d161160fa4c6303f.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_d164fd17ac21c8ea :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_d164fd17ac21c8ea", string(#load("../fuzz/crashes/d164fd17ac21c8ea.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_d18ae924631ef2d6 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_d18ae924631ef2d6", string(#load("../fuzz/crashes/d18ae924631ef2d6.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_d2521611869c67b6 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_d2521611869c67b6", string(#load("../fuzz/crashes/d2521611869c67b6.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_d28f2e934a0decea :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_d28f2e934a0decea", string(#load("../fuzz/crashes/d28f2e934a0decea.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_d2c71f5cbd55aedd :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_d2c71f5cbd55aedd", string(#load("../fuzz/crashes/d2c71f5cbd55aedd.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_d2daef927e060d10 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_d2daef927e060d10", string(#load("../fuzz/crashes/d2daef927e060d10.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_d36b5f0a7fbd433f :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_d36b5f0a7fbd433f", string(#load("../fuzz/crashes/d36b5f0a7fbd433f.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_d3fe01054a47d6e5 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_d3fe01054a47d6e5", string(#load("../fuzz/crashes/d3fe01054a47d6e5.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_d47316af2a62c2db :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_d47316af2a62c2db", string(#load("../fuzz/crashes/d47316af2a62c2db.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_d67bd4eb54293ee7 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_d67bd4eb54293ee7", string(#load("../fuzz/crashes/d67bd4eb54293ee7.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_d6880499ad8ac698 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_d6880499ad8ac698", string(#load("../fuzz/crashes/d6880499ad8ac698.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_d6ac7f3312a5dda3 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_d6ac7f3312a5dda3", string(#load("../fuzz/crashes/d6ac7f3312a5dda3.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_d784407fd6e86720 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_d784407fd6e86720", string(#load("../fuzz/crashes/d784407fd6e86720.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_d9da63bf78d87fc8 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_d9da63bf78d87fc8", string(#load("../fuzz/crashes/d9da63bf78d87fc8.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_da06348f37ddaaed :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_da06348f37ddaaed", string(#load("../fuzz/crashes/da06348f37ddaaed.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_daf713e04d17a412 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_daf713e04d17a412", string(#load("../fuzz/crashes/daf713e04d17a412.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_daf9a84b15161174 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_daf9a84b15161174", string(#load("../fuzz/crashes/daf9a84b15161174.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_de1f4c01961b4e38 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_de1f4c01961b4e38", string(#load("../fuzz/crashes/de1f4c01961b4e38.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_de50705907fab825 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_de50705907fab825", string(#load("../fuzz/crashes/de50705907fab825.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_de8dfc348cc54b01 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_de8dfc348cc54b01", string(#load("../fuzz/crashes/de8dfc348cc54b01.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_ded5db472e604e9e :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_ded5db472e604e9e", string(#load("../fuzz/crashes/ded5db472e604e9e.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_df1b699c04e1092b :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_df1b699c04e1092b", string(#load("../fuzz/crashes/df1b699c04e1092b.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_dfe5b139345145eb :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_dfe5b139345145eb", string(#load("../fuzz/crashes/dfe5b139345145eb.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_e0033262afdd1459 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_e0033262afdd1459", string(#load("../fuzz/crashes/e0033262afdd1459.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_e09cf40d2f2ccca4 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_e09cf40d2f2ccca4", string(#load("../fuzz/crashes/e09cf40d2f2ccca4.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_e16451be2c9f0469 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_e16451be2c9f0469", string(#load("../fuzz/crashes/e16451be2c9f0469.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_e2cab6afc8c8c58a :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_e2cab6afc8c8c58a", string(#load("../fuzz/crashes/e2cab6afc8c8c58a.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_e3579f2009d3104f :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_e3579f2009d3104f", string(#load("../fuzz/crashes/e3579f2009d3104f.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_e4259a16e0a55908 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_e4259a16e0a55908", string(#load("../fuzz/crashes/e4259a16e0a55908.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_e445d0cbe28cae4f :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_e445d0cbe28cae4f", string(#load("../fuzz/crashes/e445d0cbe28cae4f.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_e4d8d1e9a7531ae0 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_e4d8d1e9a7531ae0", string(#load("../fuzz/crashes/e4d8d1e9a7531ae0.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_e6c46ad38d1a2e01 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_e6c46ad38d1a2e01", string(#load("../fuzz/crashes/e6c46ad38d1a2e01.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_e727bac22e0958c3 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_e727bac22e0958c3", string(#load("../fuzz/crashes/e727bac22e0958c3.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_e79e99ebe4f65338 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_e79e99ebe4f65338", string(#load("../fuzz/crashes/e79e99ebe4f65338.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_e919bc00358b8fbc :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_e919bc00358b8fbc", string(#load("../fuzz/crashes/e919bc00358b8fbc.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_ea16c567a4848a3c :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_ea16c567a4848a3c", string(#load("../fuzz/crashes/ea16c567a4848a3c.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_ec9fd134c59b3d75 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_ec9fd134c59b3d75", string(#load("../fuzz/crashes/ec9fd134c59b3d75.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_eea748a29c1ddeda :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_eea748a29c1ddeda", string(#load("../fuzz/crashes/eea748a29c1ddeda.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_f0700017d0e6c576 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_f0700017d0e6c576", string(#load("../fuzz/crashes/f0700017d0e6c576.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_f1cc9941ece725c4 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_f1cc9941ece725c4", string(#load("../fuzz/crashes/f1cc9941ece725c4.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_f2c49606aabf7050 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_f2c49606aabf7050", string(#load("../fuzz/crashes/f2c49606aabf7050.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_f2feb10670f573df :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_f2feb10670f573df", string(#load("../fuzz/crashes/f2feb10670f573df.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_f3123c4720031b71 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_f3123c4720031b71", string(#load("../fuzz/crashes/f3123c4720031b71.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_f39adef3b23bf31b :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_f39adef3b23bf31b", string(#load("../fuzz/crashes/f39adef3b23bf31b.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_f4f60aff3b537bae :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_f4f60aff3b537bae", string(#load("../fuzz/crashes/f4f60aff3b537bae.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_f4f7251704b1d446 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_f4f7251704b1d446", string(#load("../fuzz/crashes/f4f7251704b1d446.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_f6968e0ce0abe6cd :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_f6968e0ce0abe6cd", string(#load("../fuzz/crashes/f6968e0ce0abe6cd.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_f7bee4971d7a92b2 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_f7bee4971d7a92b2", string(#load("../fuzz/crashes/f7bee4971d7a92b2.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_f7f5c532581bc10d :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_f7f5c532581bc10d", string(#load("../fuzz/crashes/f7f5c532581bc10d.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_f80407ce532d78e3 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_f80407ce532d78e3", string(#load("../fuzz/crashes/f80407ce532d78e3.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_f833b39a3f4dbf42 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_f833b39a3f4dbf42", string(#load("../fuzz/crashes/f833b39a3f4dbf42.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_f86737812d889468 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_f86737812d889468", string(#load("../fuzz/crashes/f86737812d889468.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_f9b02badc3fda32f :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_f9b02badc3fda32f", string(#load("../fuzz/crashes/f9b02badc3fda32f.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_faad85b0d958695d :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_faad85b0d958695d", string(#load("../fuzz/crashes/faad85b0d958695d.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_fb70e0058412a6b0 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_fb70e0058412a6b0", string(#load("../fuzz/crashes/fb70e0058412a6b0.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_fbbd9582254d67ea :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_fbbd9582254d67ea", string(#load("../fuzz/crashes/fbbd9582254d67ea.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_fc4d3b41b2747e89 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_fc4d3b41b2747e89", string(#load("../fuzz/crashes/fc4d3b41b2747e89.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_fd36a89532b7151f :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_fd36a89532b7151f", string(#load("../fuzz/crashes/fd36a89532b7151f.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_fdd8fed95438fd67 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_fdd8fed95438fd67", string(#load("../fuzz/crashes/fdd8fed95438fd67.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_fe3ce23eb31cc8b0 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_fe3ce23eb31cc8b0", string(#load("../fuzz/crashes/fe3ce23eb31cc8b0.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_ff337c38918e4111 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_ff337c38918e4111", string(#load("../fuzz/crashes/ff337c38918e4111.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_ff353183407ba29c :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_ff353183407ba29c", string(#load("../fuzz/crashes/ff353183407ba29c.odin")), 0,
				diff = false, no_run = true)
}
@(test) fuzz_ffd3458647088ce1 :: proc(t: ^testing.T) {
main.run_test(t, "fuzz_ffd3458647088ce1", string(#load("../fuzz/crashes/ffd3458647088ce1.odin")), 0,
				diff = false, no_run = true)
}
