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
	a := 20
	b := 6
	n := 0 - 7

	r := 0

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

	// signed division/remainder
	r += a / b      // -3
	r += a % b      // 2
	r += c / b      // 1
	r += c % b      // -1

	// arithmetic right shift
	r += c >> 1     // -4
	r += b >> 1     // -3

	// signed comparisons
	if b < a  do r += 1
	if c < b  do r += 2
	if a > b  do r += 4
	if b <= c do r += 8
	if a >= b do r += 16

	return r
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
	return st.a + st.b.c + st.b.d
}
```
