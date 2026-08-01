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
	add(&vls.b, 1)
	add(&vls.c, 1)
	add(&vls.d, 1)

	return vls.a + int(vls.b) + int(vls.c) + int(vls.d)
}

add :: proc(ptr: ^$T, v: T) -> T {
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

#### mixed 2 register op
```odin
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
```

#### scaled index sib operations
```odin
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
```

#### basic slices
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	arr := [8]int{3, 14, 25, 8, 40, 17, 55, 2}

	slc: []int = arr[:]
	sum := 0
	i := 0
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

	quick_sort(arr[:])

	i = 0
	for {
		if i >= len(arr) do break
		sum += arr[i] << uint(i)
		arr[i] = -arr[i]
		i += 1
	}

	bubble_sort(arr[:])

	i = 0
	for {
		if i >= len(arr) do break
		arr[i] = -arr[i]
		sum += arr[i] << uint(i)
		i += 1
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
```

#### basic strings
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	vl := "Edward"
	return int(vl[0]) + int(vl[1:][0]) +
	int(vl[:1][0]) + int(vl[2:4][1])
}
```

#### mutable global
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	@(static) g := 5
	g += 10
	return g
}
```

#### global peepholes
```odin
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
```

#### json validator
```odin
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
```

#### mem2reg local struct scalar promotion
```odin
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
```

#### mem2reg struct field conditional phi
```odin
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
```

#### mem2reg struct accumulator in loop
```odin
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
```

#### mem2reg nested struct promotion
```odin
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
```

#### mem2reg struct copy promotion
```odin
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
```

#### mem2reg multiple structs register pressure
```odin
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
```

#### mem2reg partially initialized struct
```odin
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
```

#### mem2reg struct returned then mutated
```odin
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
```

#### mem2reg mixed size field promotion
```odin
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
```

#### mem2reg struct feeds another struct
```odin
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
```

#### mem2reg struct field swap
```odin
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
```

#### mem2reg local pointer to struct non escaping
```odin
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
```

#### mem2reg nested struct loop with conditional
```odin
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
```

#### mem2reg conditional store no else
```odin
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
```

#### mem2reg conditional store empty then reads both
```odin
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
```

#### mem2reg conditional store cross field after merge
```odin
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
```

#### mem2reg conditional store then call reads merge
```odin
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
```

#### mem2reg loop continue carries field
```odin
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
```

#### zero initialized static aggregate
```odin
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
```

#### free list allocator
```odin
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
```

#### multi return two scalars destructured
```odin
package main

opt_level :: "none"

divmod :: proc(a: int, b: int) -> (int, int) {
	return a / b, a % b
}

main :: proc() -> int {
	q, r := divmod(47, 5)
	return q * 100 + r
}
```

#### multi return two scalars into existing vars
```odin
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
```

#### multi return four i32 fit in registers
```odin
package main

opt_level :: "none"

four32 :: proc(base: i32) -> (i32, i32, i32, i32) {
	return base + 1, base + 2, base + 3, base + 4
}

main :: proc() -> int {
	a, b, c, d := four32(10)
	return int(a) * 1000 + int(b) * 100 + int(c) * 10 + int(d)
}
```

#### multi return three ints overflow registers
```odin
package main

opt_level :: "none"

three :: proc(a: int, b: int, c: int) -> (int, int, int) {
	return a + b, b + c, a + c
}

main :: proc() -> int {
	x, y, z := three(1, 2, 3)
	return x * 100 + y * 10 + z
}
```

#### multi return four ints overflow registers
```odin
package main

opt_level :: "none"

four :: proc(a: int) -> (int, int, int, int) {
	return a, a * 2, a * 3, a * 4
}

main :: proc() -> int {
	p, q, r, s := four(5)
	return p + q + r + s
}
```

#### multi return last value large struct
```odin
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
```

#### multi return scalar and small struct
```odin
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
```

#### multi return ignore some values
```odin
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
```

#### multi return feeds directly into call
```odin
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
```

#### multi return with input params
```odin
package main

opt_level :: "none"

with_args :: proc(a: int, b: int, c: int, d: int) -> (int, int, int) {
	return a + b, c + d, a + d
}

main :: proc() -> int {
	x, y, z := with_args(1, 2, 3, 4)
	return x * 100 + y * 10 + z
}
```

#### multi return two small structs
```odin
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
```

#### multi return used in expression
```odin
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
```

#### multi return mixed sizes with large tail
```odin
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
```

#### multi pointers
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	arr: [4]int = {1, 2, 3, 4}
	ptr := raw_data(&arr)
	slc := ptr[:2]
	ptr = raw_data(slc)
	return ptr[0] + ptr[1]
}
```

#### memopt crash on indexing digits
```odin
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
```

#### basic float arithmetic
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	return int(1.5 + 2.5 * 3.0)
}
```

#### float force spill with simple addition
```odin
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
```

#### all f32 operators
```odin
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
```

#### all f64 operators
```odin
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
```

#### float ops with constants
```odin
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
```

#### float ops through pointers
```odin
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
```

#### float ops sized through pointers
```odin
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
```

#### float unary neg
```odin
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
```

#### float comparison peepholes
```odin
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
```

#### float comparison with load
```odin
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
```

#### float conversions
```odin
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
```

#### float loads and stores of different sizes
```odin
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
```

#### float variables that create register pressure
```odin
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
```

#### float variables that create even more register pressure
```odin
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
```

#### float if statement with register pressure
```odin
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
```

#### float regalloc pressure across calls
```odin
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
```

#### float args passed on stack
```odin
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
```

#### float subword conversions round trip
```odin
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
```

#### signed integer materialized compares
```odin
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
```

#### unsigned integer materialized compares
```odin
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
```

#### float materialized compares
```odin
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
```

#### integer materialized compares with immediate
```odin
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
```

#### integer materialized compares with load
```odin
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
```

#### float materialized compares with load
```odin
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
```

#### integer materialized compares with folded load
```odin
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
```

#### float materialized compares with folded load
```odin
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
```

#### crash in gcm on two loops nested in a loop
```odin
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
```

#### foreign block
```odin
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
```

#### enum basic values
```odin
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
```

#### enum explicit values
```odin
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
```

#### enum backing type
```odin
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
```

#### enum comparison
```odin
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
```

#### enum implicit selector
```odin
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
```

#### enum in struct
```odin
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
```

#### enum value switch
```odin
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
```

#### enum as param
```odin
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
```

#### union assert
```odin
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
```

#### union type switch
```odin
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
```

#### union nil check
```odin
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
```

#### union reassign variant
```odin
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
```

#### union struct member
```odin
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
```

#### union type switch default
```odin
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
```

#### generic fuctions
```odin
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
```

#### function pointers
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	return d(proc() -> int {return 10})
}

d :: proc(f: proc() -> int) -> int {
	return f()
}
```

#### BUG2 alias through pointer stored in struct field
```odin
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
```

#### parametrized structs
```odin
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
```


#### bad arg pass
```odin
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
```

#### float const
```odin
package main

opt_level :: "none"

VL :: 1.0

main :: proc() -> int {
	vl: f32
	return int(vl + VL)
}
```

#### basic simd
```odin
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
```

#### exhaustive simd accs
```odin
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
```

#### inlined trap before normal control flow
```odin
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
```

<!-- backend/builder/builder.odin:575-588 `.Ne` is listed in ZERO_IS_NEUTRAL, so `x != 0` is rewritten to `x` itself; correct only when the result is used as a branch condition, wrong when the boolean is materialized. expected 1, actual 5 -->

#### ne with zero is not identity
```odin
package main

opt_level :: "mininal"

opaque :: proc(x: int) -> int {
	return x
}

main :: proc() -> int {
	a := opaque(5)
	return int(a != 0)
}
```

<!-- backend/builder/builder.odin:811-846 store elimination only compares the *destination* of a `.Copy` user (is_noalias_ops always uses inps[2]), so a `.Copy` that READS the stored location is treated as a pure write; the store is then deleted because a later store covers it. expected 253 (5 + 6*10 + 7*100 mod 256), actual 248 (0 + 6*10 + 7*100 mod 256) -->

#### store feeding a memcpy source is wrongly dead store eliminated
```odin
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
```

<!-- backend/builder/builder.odin:430-522 the `memcpify:` loop-to-`Copy` idiom recognizer never checks that the induction phi starts at 0 (it only checks the step and the exit compare), so `for i := 2; i < n; i += 1 { dst[i] = src[i] }` becomes `copy(dst, src, n)` starting at element 0. expected 248, actual 204 -->

#### memcpify ignores the loop start index
```odin
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
```

<!-- backend/builder/builder.odin:467-490 `memcpify` takes the index scale (`factor`) from the address `Mul` and emits `Copy` of `count * factor` bytes without ever checking that `factor` equals the element size, so a strided loop `dst[i*2] = src[i*2]` is turned into a contiguous copy of 2*n bytes. expected 76, actual 204 -->

#### memcpify turns a strided loop into a contiguous copy
```odin
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
```

<!-- backend/builder/builder.odin:73-77 `fold_bin_op` evaluates `.Div`/`.Rem` (and `.U_Div`/`.U_Rem`) unconditionally, so constant folding a never-executed `1 / 0` (or `min(i64) / -1`) kills the compiler itself with SIGILL/SIGFPE. expected exit 7, actual: jit crashes while compiling -->

#### constant folding a division by zero crashes the compiler
```odin
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
```

<!-- NOT my area (memopt/SROA) but confirmed: backend/builder/memopt.odin:255 calls backend.graph_subsume with a 0 node id -> assert `id != 0` at backend/graph.odin:1608. expected exit 1, actual: jit crashes while compiling at -O:aggresive -->

#### sroa of a partially initialized struct crashes the compiler
```odin
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
```

<!-- x64.odin:2578-2581 `.X64_Mul8` emits `{0xf6, mod_sm(...)}` with no REX prefix, so an 8-bit operand in rsi/rdi/rsp/rbp is encoded as dh/bh/ah/ch (and r8-r15 lose REX.B). `imul %bh` instead of `imul %dil`. expected 63, got 0 -->

#### i8 multiply missing REX on imul r m8
```odin
package main

opt_level :: "none"

mul8 :: proc(a: i8, b: i8) -> i8 {
	return a * b
}

main :: proc() -> int {
	return int(mul8(7, 9))
}
```

<!-- x64.odin:2262-2265 indirect `.Call` emits `{0xFF, mod_sm(.Direct, 0b010, ptr)}` with no REX, so a callee-saved function pointer allocated to r8-r15 is called as the low register (`call *%rsi` instead of `call *%r14`). expected 35, got SIGSEGV -->

#### indirect call through high register missing REX B
```odin
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
```

<!-- x64.odin:2535-2541 `.Shl ..= .U_Shr` lowers to a bare `shl/shr r, cl`, which masks the count to 5/6 bits, but Odin defines a shift by >= the operand width as 0. expected 0, got 7 -->

#### shift count larger than operand width
```!odin
package main

opt_level :: "none"

sh :: proc(a: uint, n: uint) -> uint {
	return a << n
}

main :: proc() -> int {
	return int(sh(1, 64) + sh(3, 65))
}
```

<!-- x64.odin:1858-1859/2674 float Eq/Ne map straight to sete/setne (and je/jne) after ucomisd; the unordered result sets ZF=1 so `NaN == x` yields true and `NaN != x` yields false (PF is never consulted). expected 2, got 1 -->

#### float equality with NaN ignores the parity flag
```!odin
package main

opt_level :: "none"

nan :: proc(x: f64) -> f64 {
	return x / (x - x)
}

main :: proc() -> int {
	n := nan(0)
	return int(n == 1) + 2 * int(n != 1)
}
```

<!-- x64.odin:608-616 folds a constant shift amount into X64_Shl/X64_Shr without range-checking it, and x64.odin:2368/2397 emit it as a raw `shl/shr r, imm8`, which the CPU masks to 5/6 bits; Odin defines a shift by >= the operand width as 0. expected 0, got 3 -->

#### constant shift amount larger than operand width
```!odin
package main

opt_level :: "none"

shifts :: proc(x: u32) -> u32 {
	return (x << 40) + (x >> 33)
}

main :: proc() -> int {
	return int(shifts(7))
}
```

<!-- x64.odin:2687-2693 `.F_From_I` always emits the signed `cvtsi2sd`, so a u64 with bit 63 set converts to a negative double. expected 18, got 0 -->

#### u64 to f64 conversion uses signed cvtsi2sd
```!odin
package main

opt_level :: "none"

id :: proc(x: $T) -> T {return x}

main :: proc() -> int {
	c := id(u64(18446744073709551615))
	return int(f64(c) / 1e18)
}
```

<!-- x64.odin:2694-2701 `.F_To_I` always emits the signed `cvttsd2si`, so a float that does not fit the signed range of the destination yields the "integer indefinite" value instead of the unsigned result. expected 160, got 99 -->

#### f64 to u32 conversion uses signed cvttsd2si
```odin
package main

opt_level :: "none"

id :: proc(x: $T) -> T {return x}

main :: proc() -> int {
	d := id(f64(4.0e9))
	return int(u32(d) / 1000000)
}
```

<!-- x64.odin:2804 the xmm spill-to-spill move emits `pop [rsp + dst_off - 8]`, but POP with an rsp-relative destination computes the address *after* RSP is incremented, so no bias is needed (the GPR path at x64.odin:2832 correctly uses dst_off); every float spill-to-spill copy writes 8 bytes below the intended slot. expected 116, got 49 -->

#### float spill to spill move writes 8 bytes below the slot
```odin
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
```

<!-- x64.odin:2650 the memory-operand form of ucomiss/ucomisd builds its REX with `rex(lhs, bse, RAX, false)` while `emit_indirect_addr` is handed the real `idx`, so REX.X is dropped and an index register in r8-r15 is encoded as the matching low register (`ucomisd 0x0(%rbp,%rbp,8)` instead of `(%rbp,%r13,8)`). expected 4, got SIGSEGV -->

#### float compare against indexed memory drops REX X
```odin
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
```

<!-- regalloc.odin:750-752 removes `block.instrs[idx + 1]` assuming `split_after` put the new split right after `m`, but split_after (regalloc.odin:1269-1276) skips over trailing Phi/Mem instrs first; when `m` is a Phi followed by more Phis the wrong instr is unscheduled and the deleted split stays in the schedule -> `graph.odin:1621 node.rtype != DEAD_NODE_KIND`. expected exit 115, actual: compiler crash. -->
#### regalloc split cleanup removes wrong phi from schedule
```odin
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
```

<!-- regalloc.odin:30-38: with more loop-carried values than allocatable GPRs the split/recolor loop never converges and `regalloc` panics with "Ralloc took too many rounds"; loop-carried (phi) live ranges are never spilled to stack slots (straight-line code with the same pressure spills fine). expected exit 116, actual: compiler crash. -->
#### too many loop carried values panics regalloc
```odin
package main

opt_level :: "none"

main :: proc() -> int {
	v0 := 1
	v1 := 2
	v2 := 3
	v3 := 4
	v4 := 5
	v5 := 6
	v6 := 7
	v7 := 8
	v8 := 9
	v9 := 10
	v10 := 11
	v11 := 12
	v12 := 13
	v13 := 14
	v14 := 15
	i := 0
	for {
		if i == 7 do break
		i += 1
		v0 = v0 + v1
		v1 = v1 ~ v2
		v2 = v2 + v3
		v3 = v3 ~ v4
		v4 = v4 + v5
		v5 = v5 ~ v6
		v6 = v6 + v7
		v7 = v7 ~ v8
		v8 = v8 + v9
		v9 = v9 ~ v10
		v10 = v10 + v11
		v11 = v11 ~ v12
		v12 = v12 + v13
		v13 = v13 ~ v14
		v14 = v14 ~ v0
	}
	r := 0
	r += v0 * 1
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
	r += v14 * 15
	return r % 251
}
```

<!-- loop phi whose only use is after the loop collapses to its entry value (builder/ssa.odin graph_get_scope_value / lazy-phi resolution): `v4` is written but never read inside the loop, and after the loop it still reads 42. expected exit 10, actual 42 (codegen emits `mov $0x2a,%rax`). -->
#### loop variable only written inside loop keeps pre loop value
```odin
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
```

<!-- regalloc split-coalescing (backend/regalloc/regalloc.odin:523-602) merges two live ranges that are actually simultaneously live: the interference graph is missing the edge, so `unify(ilrg, inlrg)` + `graph_subsume` gives both values the same register. Disabling only that loop (`for &bb in sched.bbs { ... itype != .Split ... }`) makes the program produce the right answer at every -O level; making the coalescing heuristic maximally conservative (only `total < leeway`) does NOT help, so the interference info itself is incomplete. expected exit 147, actual 100. -->
#### regalloc coalescing merges interfering live ranges
```odin
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
```

<!-- backend/builder/ssa.odin:206-216 graph_end_loop: a break scope entry that still points at the loop Scope node (no Lazy_Phi was ever forced because the variable is never *read* inside the loop) is rewritten to init.inps[i], the loop-*entry* value, instead of the loop phi; a variable that is only written after the break site loses the write. expected 105, got 102 -->

#### loop write only variable lost on early break
```odin
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
```

<!-- gen.odin:2299-2320 (^ast.Branch_Stmt) always resolves an unlabelled `break` against ctx.loop; the enclosing switch's builder.Block_State (gen.odin:1807) is never consulted, so `break` inside a switch case exits the loop. expected 35, got 1 -->

#### break inside switch case exits the enclosing loop
```!odin
package main

opt_level :: "none"

main :: proc() -> int {
	s := 0
	i := 0
	for {
		i += 1
		if i > 3 do break
		switch i {
		case 1:
			s += 1
			break
		case:
			s += 2
		}
		s += 10
	}
	return s
}
```

<!-- backend/builder/builder.odin:48 fold_un_op .Cast masks the constant to the destination width (so i32(-8) becomes 0xFFFFFFF8), but fold_bin_op never sign-extends: .Rem (line 80), .Shr (line 91) and the signed compares .Le/.Lt/.Gt/.Ge (lines 96-103) operate on the raw i64. Only .Div sign-extends. expected 115, got 104 -->

#### signed constant folding on narrowed integers
```odin
package main

opt_level :: "mininal"

main :: proc() -> int {
	a: i64 = -8
	b := i32(a)
	r := 0
	if b < 0 do r += 1
	if b > 5 do r += 2
	if (b >> 1) == -4 do r += 16
	r += int(b % 3)
	return r + 100
}
```

<!-- backend/builder/builder.odin:51-52 fold_un_op treats .F_Demote as identity, but float constants are stored as f64 bits (gen.odin:386 emit_float_const), so f32(x) of a folded constant keeps full f64 precision instead of rounding to f32. expected 146, got 0 -->

#### f32 demotion of a constant does not round
```!odin
package main

opt_level :: "mininal"

main :: proc() -> int {
	x: f64 = 0.1
	y := f32(x)
	z := f64(y)
	return int((z - 0.1) * 1e18) % 251
}
```

<!-- backend/builder/builder.odin:1110-1121 (.Set zero-init peep) only splits the *last* merged slot down to MAX_STORE_UNIT; an earlier merged run of 32 bytes reaches builder.odin:1130-1132 where table[count_trailing_zeros(32)] = table[5] indexes the 5-element datatype table -> compiler crash "Index 5 is out of range 0..<5" -->

#### zero init slot splitting index out of range
```odin
package main

opt_level :: "moderate"

S :: struct {
	a: [4]int,
	m: int,
	b: [4]int,
}

main :: proc() -> int {
	x := S{}
	x.m = 5
	return x.a[0] + x.m + x.b[3] + 10
}
```

<!-- backend/builder/builder.odin:1096-1121 (.Set zero-init peep) merges adjacent uninitialised slots without re-splitting non-last runs, so a 24-byte run survives; builder.odin:1130-1133 then picks table[count_trailing_zeros(24)] = .I64 and emits a single 8-byte zero store for 24 bytes, leaving 16 bytes of the struct uninitialised. expected 90, got a garbage-dependent value (varies per run) -->

#### zero init only partially zeroes non power of two run
```odin
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
```

<!-- gen.odin:310-339 tok_to_binop has no entry for .Cmp_And / .Cmp_Or (and none for .Mod_Mod either), so the zero value Op_Info{.Add, ""} is used and gen.odin:1336 builds a bogus node with an empty tag; the compiler then dies in regalloc ("Index 13 is out of range 0..<4"). Any `&&`, `||` or `%%` in the source crashes the compiler instead of erroring out. -->

#### short circuit and or crashes the compiler
```!odin
package main

opt_level :: "none"

main :: proc() -> int {
	r := 3
	x := 0
	if r > 0 && r < 5 do x += 1
	return x + 10
}
```

<!-- backend/builder/builder.odin:720-727 passes the load size and the store size to `is_noalias` in the wrong order (address `cnode.inps[2]` is paired with `DT_SIZE[node.dt]`, the *load*'s size), so an overlapping store is judged non-aliasing and the load forwards past it; expected 123, got 0 at -O:moderate and above. -->
#### load_forwarding_past_overlapping_store_of_different_size
```odin
package main

opt_level :: "moderate"

main :: proc() -> int {
	arr: [16]u8
	p := transmute(^u64)&arr[0]
	p^ = 0
	arr[4] = 1
	return int(p^ % 251)
}
```

<!-- backend/builder/memopt.odin:167-190 (`collect_rename_slot`) only requires every op on a local to sit at offset 0; it never requires the ops to have the same access size, so a `u8` load at offset 0 is renamed to the `u64` value stored there; expected 52, got 142 at -O:all. -->
#### memopt renames local with mismatched access sizes
```odin
package main

opt_level :: "all"

main :: proc() -> int {
	x: u64 = 0x1234
	p := transmute(^u8)&x
	return int(p^) % 251
}
```

<!-- Same root cause (backend/builder/memopt.odin:167-190): the narrow store is treated as writing the whole slot, so the following wide load reads 3 instead of 0x1203; expected 93, got 3 at -O:all. -->
#### memopt narrow store into wide slot
```odin
package main

opt_level :: "all"

main :: proc() -> int {
	x: u64 = 0x1234
	p := transmute(^u8)&x
	p^ = 3
	return int(x % 251)
}
```

<!-- Iter-peeps fixpoint verification fails (backend/graph.odin:952): the load-forwarding peep in backend/builder/builder.odin:713-743 (`florward_loads`) only registers triggers on the final `cursor` (and its address), not on the non-aliasing stores it walked over, so the load is never re-peeped after they change; expected exit 0, got a compiler assertion at -O:moderate and above. -->
#### load forwarding does not reach a peephole fixpoint
```odin
package main

opt_level :: "moderate"

main :: proc() -> int {
	arr: [3]int
	arr[2] = arr[1]
	arr[1] = arr[0]
	return arr[2]
}
```

<!-- The `fail ...` tests below are rejected by the typechecker, so they are
never compiled by odin nor run; the golden file only holds the diagnostics.
Every one of them checks recovery too: each statement is checked independently,
so all of the mistakes have to be reported in one run. -->

#### fail type mismatches
```odin
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
```

#### fail undeclared names
```odin
package main

main :: proc() -> int {
	x := undefined_thing
	y: NotAType = 0
	z := undefined_proc(1)
	w := x + y + z
	return 0
}
```

#### fail bad control flow
```odin
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
```

#### fail bad operands
```odin
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
```

#### fail bad enums and unions
```odin
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
```

#### fail bad generics
```odin
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
```

#### fail bad returns and builtins
```odin
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
```

#### fail bad literals and types
```odin
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
```

#### fail unsupported constructs
```odin
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
```

#### fail uninferable polymorphism
```odin
package main

only_ret :: proc(a: int) -> $T {
	return 0
}

main :: proc() -> int {
	return only_ret(1)
}
```
