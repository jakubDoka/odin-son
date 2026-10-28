# GPU TESTS

The examples here are used to test the gpu backends. The shaders are fed random
inputs although deterministic, derived from the test name.
Comparisons include equal inputs, and float inputs include negative values and
signed zero. Division allows two ULPs of error for Xe-LP's reciprocal instruction;
other operators and boolean results are checked exactly.


#### gpu simplest
```odin
package main

main :: proc(a: f32, b: f32) -> f32 {
	return a + b
}
```

#### gpu float subtract
```odin
package main

main :: proc(a: f32, b: f32) -> f32 {
	return a - b
}
```

#### gpu float multiply
```odin
package main

main :: proc(a: f32, b: f32) -> f32 {
	return a * b
}
```

#### gpu float divide
```odin
package main

main :: proc(a: f32, b: f32) -> f32 {
	return a / b
}
```

#### gpu float negate
```odin
package main

main :: proc(a: f32) -> f32 {
	return -a
}
```

#### gpu float positive
```odin
package main

main :: proc(a: f32) -> f32 {
	// COMPILER BUG: the frontend does not accept unary plus yet.
	// return +a
	return a
}
```

#### gpu float equal
```odin
package main

main :: proc(a: f32, b: f32) -> bool {
	return a == b
}
```

#### gpu float not equal
```odin
package main

main :: proc(a: f32, b: f32) -> bool {
	return a != b
}
```

#### gpu float less
```odin
package main

main :: proc(a: f32, b: f32) -> bool {
	return a < b
}
```

#### gpu float less equal
```odin
package main

main :: proc(a: f32, b: f32) -> bool {
	return a <= b
}
```

#### gpu float greater
```odin
package main

main :: proc(a: f32, b: f32) -> bool {
	return a > b
}
```

#### gpu float greater equal
```odin
package main

main :: proc(a: f32, b: f32) -> bool {
	return a >= b
}
```

#### gpu float equal operands
```odin
package main

main :: proc(a: f32, b: f32) -> bool {
	c := a + b
	d := b + a
	return c <= d
}
```

#### gpu float arithmetic chain
```odin
package main

main :: proc(a: f32, b: f32, c: f32) -> f32 {
	return -((a - b) * (b + c) / c)
}
```

#### gpu if else
```odin
package main

main :: proc(a: f32, b: f32) -> f32 {
	result: f32
	if a < b {
		result = a - b
	} else {
		result = a + b
	}
	return result * b
}
```

#### gpu nested if
```odin
package main

main :: proc(a: f32, b: f32, c: f32) -> f32 {
	result := a
	if a < b {
		if b < c {
			result = a + c
		} else {
			result = b - c
		}
	} else if a == b {
		result = a * c
	}
	return result
}
```

#### gpu loop
```odin
package main

main :: proc(a: f32, b: f32) -> f32 {
	result := a
	// COMPILER BUG: the frontend does not lower three-clause for statements yet.
	// for i: f32 = 0; i < 4; i += 1 {
	i: f32 = 0
	for {
		if i >= 4 do break
		i += 1
		result += b
	}
	return result
}
```

#### gpu divergent loop break
```odin
package main

main :: proc(a: f32, b: f32) -> f32 {
	result := a
	// COMPILER BUG: the frontend does not lower three-clause for statements yet.
	// for i: f32 = 0; i < 4; i += 1 {
	i: f32 = 0
	for {
		if i >= 4 do break
		i += 1
		result += b
		if result > 1 {
			break
		}
	}
	return result
}
```

#### gpu loop continue
```odin
package main

main :: proc(a: f32, b: f32) -> f32 {
	result := a
	// COMPILER BUG: the frontend does not lower three-clause for statements yet.
	// for i: f32 = 0; i < 4; i += 1 {
	i: f32 = 0
	for {
		if i >= 4 do break
		iteration := i
		i += 1
		if iteration < b {
			continue
		}
		result += b
	}
	return result
}
```

#### gpu nested loops
```odin
package main

main :: proc(a: f32, b: f32) -> f32 {
	result := a
	// COMPILER BUG: the frontend does not lower three-clause for statements yet.
	// for i: f32 = 0; i < 3; i += 1 {
	i: f32 = 0
	for {
		if i >= 3 do break
		i += 1
		// COMPILER BUG: the frontend does not lower three-clause for statements yet.
		// for j: f32 = 0; j < 3; j += 1 {
		j: f32 = 0
		for {
			if j >= 3 do break
			j += 1
			if result > b {
				break
			}
			result += 0.25
		}
		result -= b
	}
	return result
}
```

#### gpu comparison flag and value
```odin
package main

main :: proc(a: f32, b: f32) -> bool {
	less := a < b
	result := a
	if less {
		result += b
	}
	return (result < b) == less
}
```

#### gpu boolean phi condition
```odin
package main

main :: proc(a: f32, b: f32, c: f32) -> f32 {
	condition := a < b
	if b < c {
		condition = a == c
	}
	result := a
	if condition {
		result += c
	}
	return result
}
```

#### gpu early return
```odin
package main

main :: proc(a: f32, b: f32) -> f32 {
	if a < b {
		return a * b
	}
	return a - b
}
```

#### gpu loop nested break continue
```odin
package main

main :: proc(a: f32, b: f32) -> f32 {
	result := a
	i: f32 = 0
	for {
		i += 1
		if i > 5 do break
		if a < b {
			result += 0.25
			if result > b do break
			continue
		}
		result -= 0.125
		if result < b {
			result += b
		}
	}
	return result
}
```

#### gpu labeled loop break
```odin
package main

main :: proc(a: f32, b: f32) -> f32 {
	result := a
	i: f32 = 0
	outer: for {
		i += 1
		if i > 3 do break
		j: f32 = 0
		for {
			j += 1
			if j > 3 do break
			result += 0.25
			if result > b do break outer
		}
		result -= 0.125
	}
	return result
}
```

#### gpu divergent loop count
```odin
package main

main :: proc(a: f32, b: f32) -> f32 {
	result := a
	i: f32 = 0
	for {
		if i > b + 2 do break
		i += 1
		result += 0.25
	}
	return result
}
```

#### gpu flag survives materialized comparison
```odin
package main

main :: proc(a: f32, b: f32) -> bool {
	condition := a < b
	value := false
	i: f32 = 0
	for {
		i += 1
		value = value == (i * 0.125 < b)
		if condition {
			if i > 4 do break
		} else {
			if i > 3 do break
		}
	}
	return value
}
```

#### gpu loop shared break value
```odin
package main

main :: proc(a: f32, b: f32) -> f32 {
	i: f32 = 0
	for {
		i += 1
		if i > 4 do break
		if i > b {
			if a < b do break
		}
	}
	return i
}
```

#### gpu loop break reconvergence
```odin
package main

main :: proc(a: f32, b: f32) -> f32 {
	i: f32 = 0
	for {
		i += 1
		if i > 4 do break
		if a < b do break
	}
	return a + b
}
```

#### gpu loop branch exits
```odin
package main

main :: proc(a: f32, b: f32) -> f32 {
	i: f32 = 0
	for {
		i += 1
		if a < b {
			if i > 4 do break
		} else {
			if i > 3 do break
		}
	}
	return i
}
```
