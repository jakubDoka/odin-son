# GPU TESTS

The examples here are used to test the gpu backends. The shaders are fed random
inputs although deterministic, derived from the test name.


#### gpu simplest
```odin
package main

main :: proc(a: f32, b: f32) -> f32 {
	return a + b
}
```
