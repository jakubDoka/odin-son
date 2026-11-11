(module
  (type (;0;) (func (result i64)))
  (func $sum (type 0) (param f64) (result f64)
    (local i64 f32 f32)
    global.get 0
    i64.const 8
    i64.sub
    global.set 0
    global.get 0
    i64.const 0
    i64.add
    local.tee 1
    local.get 0
    f64.store align=1
    global.get 0
    f32.load offset=4 align=1
    local.set 3
    global.get 0
    f32.load align=1
    local.set 2
    local.get 1
    local.get 3
    local.get 2
    f32.add
    f32.store offset=4 align=1
    global.get 0
    i64.load align=1
    local.set 1
    local.get 1
    global.get 0
    i64.const 8
    i64.add
    global.set 0
    return
  )
  (func $main (type 1) (result i64)
    (local i64 f64 f32)
    global.get 0
    i64.const 16
    i64.sub
    global.set 0
    global.get 0
    i64.const 0
    i64.add
    local.tee 0
    f32.const +1
    f32.store align=1
    local.get 0
    f32.const +2
    f32.store offset=4 align=1
    global.get 0
    f64.load align=1
    local.set 1
    local.get 1
    call $sum
    local.set 0
    global.get 0
    i64.const 8
    i64.add
    local.get 0
    i64.store align=1
    global.get 0
    f32.load offset=12 align=1
    local.set 2
    i64.const 1
    i64.const 0
    local.get 2
    f32.const +3
    f32.eq
    select
    global.get 0
    i64.const 16
    i64.add
    global.set 0
    return
  )
  (table (;0;) 1 1 funcref)
  (memory (;0;) i64 16)
  (global (;0;) (mut i64)   i64.const 1048576)
  (export "main" (func 0))
  (export "__stack_pointer" (global 0))
  (export "memory" (memory 0))
  (elem (;0;)   (i32.const 1) func)
  (data (;0;)   (i64.const 1048576) "")
)
