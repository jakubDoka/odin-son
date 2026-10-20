#[cfg(all(
    target_os = "linux",
    any(target_arch = "x86_64", target_arch = "aarch64")
))]
fn main() {
    use bac::{Arena, BinOp, CodegenEmitCtx, Datatype, Lane, MinAligned, ParamSpec, Proc};
    use core::{ffi::c_void, ptr};

    unsafe extern "C" {
        fn mmap(
            addr: *mut c_void,
            len: usize,
            prot: i32,
            flags: i32,
            fd: i32,
            offset: isize,
        ) -> *mut c_void;
        fn mprotect(addr: *mut c_void, len: usize, prot: i32) -> i32;
        fn munmap(addr: *mut c_void, len: usize) -> i32;
    }

    let MinAligned([temp1, temp2, memory, code]) = &mut MinAligned([[0u8; 4096]; 4]);

    let mut temps = [Arena::from_buffer(temp1), Arena::from_buffer(temp2)];
    let mut memory = Arena::from_buffer(memory);
    let mut proc = Proc::new(&mut memory, &mut temps);
    let mut param_specs = [ParamSpec::default(); 2];
    {
        let builder = proc.builder();
        let mut memory = builder.initial_memory();

        let mut params = builder.param_gen();

        // TODO: this needs better documentation
        let mut int_spec = bac::AbiParam::new(&[Datatype::I64]);
        int_spec.scalar = true;

        let left = params.next(&mut memory, "left", &int_spec);
        let right = params.next(&mut memory, "right", &int_spec);
        param_specs.copy_from_slice(params.finalize());

        let sum = builder.add_bin_op("sum", BinOp::Add, Datatype::I64, left, right, Lane::I8);
        builder.merge_returns(&[builder.entry(), memory, sum]);
    }

    let mut code = Arena::from_buffer(code);
    let mut ctx = CodegenEmitCtx::new(&mut proc, &mut code);
    ctx.set_params(&param_specs);
    let output = ctx.compile();
    assert!(!output.code.is_empty() && output.code.len() <= 4096);

    let page = unsafe { mmap(ptr::null_mut(), 4096, 1 | 2, 2 | 0x20, -1, 0) };
    assert_ne!(page as isize, -1);
    unsafe { ptr::copy_nonoverlapping(output.code.as_ptr(), page.cast(), output.code.len()) };
    assert_eq!(unsafe { mprotect(page, 4096, 1 | 4) }, 0);

    #[cfg(target_arch = "aarch64")]
    unsafe {
        unsafe extern "C" {
            fn __clear_cache(begin: *mut c_void, end: *mut c_void);
        }
        __clear_cache(page, page.add(output.code.len()));
    }

    let sum: unsafe extern "C" fn(i64, i64) -> i64 = unsafe { core::mem::transmute(page) };
    for (left, right) in [(27, 42), (-10, 3), (0, 0), (1 << 40, 9)] {
        let result = unsafe { sum(left, right) };
        assert_eq!(result, left + right);
        println!("{left} + {right} = {result}");
    }
    assert_eq!(unsafe { munmap(page, 4096) }, 0);
}

#[cfg(not(all(
    target_os = "linux",
    any(target_arch = "x86_64", target_arch = "aarch64")
)))]
fn main() {
    panic!("the executable-memory example supports Linux x86-64 and AArch64");
}
