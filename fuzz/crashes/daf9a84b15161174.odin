
package main

opt_level :: "none"

opaque :: proc(x: int) -^ int {
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
