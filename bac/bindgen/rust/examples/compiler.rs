use bac::{
    Arena, BinOp, CodegenEmitCtx, Datatype, IfState, Lane, LoopControl, LoopState, Node, Proc,
};

use core::{iter::Peekable, str::SplitWhitespace};

const PROGRAM: &str = "
    let i = 0 ;
    let total = 0 ;
    loop outer {
        i = ( i + 1 ) ;
        total = ( i * 3 ) ;
        if ( i == 5 ) {
            break outer ;
        } 
    }
    return total ;
";

struct Compiler<'s, 'p, 'a> {
    proc: &'p Proc<'a>,
    tokens: Peekable<SplitWhitespace<'s>>,
    scope: &'p Node,
    variables: Vec<(&'s str, isize)>,
    loops: Vec<(Option<&'s str>, LoopState<'p, 'a>)>,
}

impl<'s, 'p, 'a> Compiler<'s, 'p, 'a> {
    fn next(&mut self) -> &'s str {
        self.tokens.next().unwrap()
    }

    fn find_var(&self, name: &str) -> isize {
        self.variables
            .iter()
            .find(|&&(n, _)| n == name)
            .map(|&(_, v)| v)
            .unwrap()
    }

    fn expression(&mut self) -> &'p Node {
        let builder = self.proc.builder();
        match self.next() {
            "(" => {
                let left = self.expression();
                let op = match self.next() {
                    "+" => BinOp::Add,
                    "-" => BinOp::Sub,
                    "*" => BinOp::Mul,
                    "==" => BinOp::Eq,
                    "<" => BinOp::Lt,
                    _ => unreachable!(),
                };
                let right = self.expression();
                self.next();
                builder.add_bin_op("binary", op, Datatype::I64, left, right, Lane::I8)
            }
            token => match token.parse::<i64>() {
                Ok(value) => builder.add_c_int("number", Datatype::I64, value),
                Err(_) => builder.get_scope_value(self.scope, self.find_var(token)),
            },
        }
    }

    fn block(&mut self) {
        self.next();
        while self.tokens.peek() != Some(&"}") {
            self.statement();
        }
        self.next();
    }

    fn statement(&mut self) {
        let builder = self.proc.builder();
        match self.next() {
            "let" => {
                let name = self.next();
                self.next();
                let value = self.expression();
                self.next();
                let slot = builder.push_scope_value(self.scope, value, "variable", 0);
                self.variables.push((name, slot));
            }
            "loop" => {
                let label = (self.tokens.peek() != Some(&"{")).then(|| self.next());
                let mut state = LoopState::new(self.proc);
                state.start_loop(self.scope);
                self.loops.push((label, state));
                self.block();
                let (_, mut state) = self.loops.pop().unwrap();
                state.end_loop(&mut self.scope);
            }
            "if" => {
                let condition = self.expression();
                let mut state = IfState::new(self.proc);
                state.start_if(self.scope, condition);
                self.block();
                state.end_if(&mut self.scope);
            }
            keyword @ ("break" | "continue") => {
                let label = (self.tokens.peek() != Some(&";")).then(|| self.next());
                self.next();
                let (_, state) = self
                    .loops
                    .iter_mut()
                    .rfind(|(name, _)| label.is_none() || *name == label)
                    .unwrap();
                let control = if keyword == "break" {
                    LoopControl::Break
                } else {
                    LoopControl::Continue
                };
                state.loop_control(control, self.scope);
                self.scope = Node::NONE;
            }
            "return" => {
                let value = self.expression();
                self.next();
                let control = builder.inputs(self.scope).next().unwrap();
                builder.merge_return(&[control, builder.initial_memory(), value]);
                builder.delete_scope(self.scope);
                self.scope = Node::NONE;
            }
            name => {
                self.next();
                let value = self.expression();
                self.next();
                builder.set_scope_value(self.scope, self.find_var(name), value);
            }
        }
    }
}

#[cfg(all(
    target_os = "linux",
    any(target_arch = "x86_64", target_arch = "aarch64")
))]
fn run(source: &str) -> i64 {
    use core::{ffi::c_void, ptr};

    use bac::MinAligned;

    let MinAligned([temp1, temp2, memory, code]) = &mut MinAligned([[0u8; 4096 * 4]; 4]);

    let mut temps = [Arena::from_buffer(temp1), Arena::from_buffer(temp2)];
    let mut memory = Arena::from_buffer(memory);
    let mut proc = Proc::new(&mut memory, &mut temps);
    {
        let builder = proc.builder();
        let mut compiler = Compiler {
            proc: &proc,
            tokens: source.split_whitespace().peekable(),
            scope: builder.add_scope("scope", builder.entry()),
            variables: Vec::new(),
            loops: Vec::new(),
        };
        while compiler.tokens.peek().is_some() {
            compiler.statement();
        }
    }
    let mut code = Arena::from_buffer(code);
    let mut ctx = CodegenEmitCtx::new(&mut proc, &mut code);
    let output = ctx.compile().code;
    assert!(!output.is_empty() && output.len() <= 4096);

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

    let page = unsafe { mmap(ptr::null_mut(), 4096, 1 | 2, 2 | 0x20, -1, 0) };
    assert_ne!(page as isize, -1);
    unsafe { ptr::copy_nonoverlapping(output.as_ptr(), page.cast(), output.len()) };
    assert_eq!(unsafe { mprotect(page, 4096, 1 | 4) }, 0);

    #[cfg(target_arch = "aarch64")]
    unsafe {
        unsafe extern "C" {
            fn __clear_cache(begin: *mut c_void, end: *mut c_void);
        }
        __clear_cache(page, page.add(output.len()));
    }

    let function: unsafe extern "C" fn() -> i64 = unsafe { core::mem::transmute(page) };
    let result = unsafe { function() };
    assert_eq!(unsafe { munmap(page, 4096) }, 0);
    result
}

#[cfg(all(
    target_os = "linux",
    any(target_arch = "x86_64", target_arch = "aarch64")
))]
fn main() {
    let result = run(PROGRAM);

    println!("result = {result}");
}

#[cfg(not(all(
    target_os = "linux",
    any(target_arch = "x86_64", target_arch = "aarch64")
)))]
fn main() {
    panic!("the executable-memory example supports Linux x86-64 and AArch64");
}
