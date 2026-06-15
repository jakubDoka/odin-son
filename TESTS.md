# Tests

The file contains unit tests, this file is read by `odin run meta` and
turned into a unit test file. Hope you can infer what each test should look
like, making an example is too much for me.

#### simplest
```odin
package main

return_value :: 69

main :: proc() -> int {
	return 69
}
```

#### basic arithmetic
```odin
package main

return_value :: 7
opt_level :: "none"

main :: proc() -> int {
	return 1 + 2 * 3
}
```

#### simple 2 adress self conflict
```odin
package main

return_value :: 6
opt_level :: "none"

main :: proc() -> int {
	return 2 + 2 * 2
}
```

#### more complex 2 adress self conflict
```odin
package main

return_value :: 18
opt_level :: "none"

main :: proc() -> int {
	return 2 + 2 * 2 + 2 * 2 + 2 * 2 + 2 * 2
}
```

#### force spill with simple addition
```odin
package main

return_value :: 32
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

return_value :: 42
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

return_value :: 45701539774315
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

return_value :: 52074
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

return_value :: 100
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

return_value :: 5484395
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
