#[cfg(all(
    target_os = "linux",
    any(target_arch = "x86_64", target_arch = "aarch64")
))]
fn main() {
    use bac::{Arena, CodegenEmitCtx, Datatype, Proc};
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

    let mut temps = [Arena::new(4096 * 128), Arena::new(4096 * 128)];
    let mut memory = Arena::new(4096 * 8);
    let mut proc = Proc::new(&mut memory, &mut temps);
    {
        let builder = proc.builder();
        let value = builder.add_c_int("mcnst", Datatype::I64, 69);
        builder.merge_returns(&[builder.entry(), builder.initial_memory(), value]);
    }
    let mut code = Arena::new(4096);
    let mut ctx = CodegenEmitCtx::new(&mut proc, &mut code);
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

    let function: unsafe extern "C" fn() -> i64 = unsafe { core::mem::transmute(page) };
    let result = unsafe { function() };
    assert_eq!(unsafe { munmap(page, 4096) }, 0);
    assert_eq!(result, 69);
    std::process::exit(result as i32);
}

#[cfg(not(all(
    target_os = "linux",
    any(target_arch = "x86_64", target_arch = "aarch64")
)))]
fn main() {
    panic!("the executable-memory example supports Linux x86-64 and AArch64");
}
