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
