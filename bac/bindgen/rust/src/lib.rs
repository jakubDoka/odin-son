#![no_std]
#![deny(unsafe_op_in_unsafe_fn)]
#![allow(clippy::missing_safety_doc)]

#[cfg(feature = "alloc")]
extern crate alloc;

#[cfg(feature = "alloc")]
use alloc::alloc::{alloc_zeroed, dealloc, handle_alloc_error};

#[cfg(feature = "alloc")]
use core::alloc::Layout;

use core::{
    cell::UnsafeCell,
    fmt,
    marker::PhantomData,
    ops::{Deref, DerefMut},
    ptr,
};

mod fixed_cap_dyn_array;
pub use fixed_cap_dyn_array::FixedCapDynArray;

mod generated;
pub mod sys;
mod sys_ext;
pub use generated::*;
pub use sys::ssa_Abi_Param as AbiParam;

const MIN_ALIGN: usize = 4096;

#[repr(align(4096))]
pub struct MinAligned<T>(pub T);

impl<T> DerefMut for MinAligned<T> {
    fn deref_mut(&mut self) -> &mut Self::Target {
        &mut self.0
    }
}

impl<T> Deref for MinAligned<T> {
    type Target = T;

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

#[repr(transparent)]
#[derive(Default)]
pub struct Arena<'a> {
    raw: sys::arna_Allocator,
    _borrow: PhantomData<&'a mut [u8]>,
}

#[cfg(feature = "alloc")]
impl Arena<'static> {
    pub fn new(capacity: usize) -> Self {
        let layout = arena_layout(capacity);
        let data = unsafe { alloc_zeroed(layout) };
        if data.is_null() {
            handle_alloc_error(layout);
        }
        let mut raw = arena_raw(data, capacity);
        // Odin uses reserved + 1 for borrowed buffers; + 2 marks Rust-owned storage.
        raw.commited = capacity + 2;
        Self {
            raw,
            _borrow: PhantomData,
        }
    }

    fn copy(bytes: &[u8]) -> Self {
        let mut arena = Self::new(bytes.len());
        unsafe { ptr::copy_nonoverlapping(bytes.as_ptr(), arena.raw.ptr, bytes.len()) };
        arena.raw.pos = bytes.len();
        arena
    }
}

impl<'a> Arena<'a> {
    pub fn from_buffer(buffer: &'a mut [u8]) -> Self {
        assert_eq!(
            buffer.as_ptr() as usize % MIN_ALIGN,
            0,
            "arena buffer must be page aligned"
        );
        Self {
            raw: arena_raw(buffer.as_mut_ptr(), buffer.len()),
            _borrow: PhantomData,
        }
    }

    pub fn bytes(&self) -> &[u8] {
        if self.raw.pos == 0 {
            &[]
        } else {
            unsafe { core::slice::from_raw_parts(self.raw.ptr, self.raw.pos) }
        }
    }

    pub fn reset(&mut self) {
        self.raw.pos = 0;
    }
}

#[cfg(feature = "alloc")]
impl Drop for Arena<'_> {
    fn drop(&mut self) {
        if self.raw.commited == self.raw.reserved + 2 {
            unsafe { dealloc(self.raw.ptr, arena_layout(self.raw.reserved)) };
        }
    }
}

#[cfg(feature = "alloc")]
fn arena_layout(capacity: usize) -> Layout {
    assert!(capacity < isize::MAX as usize);
    Layout::from_size_align(capacity.max(1), MIN_ALIGN).expect("invalid arena capacity")
}

fn arena_raw(data: *mut u8, len: usize) -> sys::arna_Allocator {
    assert!(len < isize::MAX as usize);
    unsafe {
        sys::arna_init_from_buffer(sys::Slice {
            data,
            len: len as isize,
        })
    }
}

pub type Temps<'a> = [Arena<'a>; 2];

#[repr(transparent)]
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Hash)]
pub struct NodeId(u32);

impl NodeId {
    pub const NONE: Self = Self(0);
    pub fn index(self) -> u32 {
        self.0
    }

    pub const unsafe fn from_raw(index: u32) -> Self {
        Self(index)
    }
}

#[repr(transparent)]
pub struct Node {
    raw: UnsafeCell<sys::Node>,
}

impl Node {
    pub const NONE: &'static Self = unsafe { &*ptr::addr_of!(sys::bac_NIL_NODE).cast() };

    fn snapshot(&self) -> sys::Node {
        unsafe { self.raw.get().read() }
    }

    pub fn is_dead(&self) -> bool {
        unsafe { self.snapshot().spec.r#type.rtype == u16::MAX }
    }
}

impl PartialEq for Node {
    fn eq(&self, other: &Self) -> bool {
        ptr::eq(self, other)
    }
}

impl Eq for Node {}

impl fmt::Debug for Node {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        fmt::Pointer::fmt(&ptr::from_ref(self), f)
    }
}

#[repr(transparent)]
pub struct Proc<'a> {
    raw: UnsafeCell<sys::Proc>,
    _arena: PhantomData<(&'a mut Arena<'a>, &'a mut Temps<'a>)>,
}

impl<'a> Proc<'a> {
    pub fn new(arena: &'a mut Arena<'_>, temps: &'a mut Temps<'_>) -> Self {
        let mut raw = sys::Proc::default();
        unsafe { sys::bac_start_proc(&mut raw, &mut arena.raw, ptr::from_mut(temps).cast()) };
        Self {
            raw: UnsafeCell::new(raw),
            _arena: PhantomData,
        }
    }

    pub fn builder(&self) -> &Builder<'a> {
        unsafe { &*ptr::from_ref(self).cast() }
    }

    pub fn entry(&self) -> &Node {
        unsafe { self.get_node(NodeId((*self.raw_ptr()).meta.pinned.entry)) }
    }

    pub fn end(&self) -> &Node {
        unsafe { self.get_node(NodeId((*self.raw_ptr()).meta.pinned.end)) }
    }

    pub unsafe fn get_node(&self, id: NodeId) -> &Node {
        if id == NodeId::NONE {
            return Node::NONE;
        }
        let used = unsafe { (*(*self.raw_ptr()).mem).pos };
        assert!(
            (id.0 as usize)
                .checked_mul(4)
                .and_then(|offset| offset.checked_add(core::mem::size_of::<Node>()))
                .is_some_and(|end| end <= used),
            "node index is out of bounds: {}",
            id.0
        );
        unsafe { &*sys::bac_get_node(self.raw_ptr(), id.0).cast() }
    }

    pub fn node_id(&self, node: &Node) -> NodeId {
        if ptr::eq(node, Node::NONE) {
            return NodeId::NONE;
        }
        let arena = unsafe { &*(*self.raw_ptr()).mem };
        let offset = (ptr::from_ref(node) as usize).checked_sub(arena.ptr as usize);
        assert!(
            offset.is_some_and(|offset| {
                offset % 4 == 0
                    && offset
                        .checked_add(core::mem::size_of::<Node>())
                        .is_some_and(|end| end <= arena.pos)
                    && offset / 4 <= u32::MAX as usize
            }),
            "node does not belong to this proc's arena"
        );
        NodeId((offset.unwrap() / 4) as u32)
    }

    fn check(&self, node: &Node) -> NodeId {
        let id = self.node_id(node);
        assert!(!node.is_dead(), "node has been deleted: {}", id.0);
        id
    }

    pub unsafe fn set_target(&mut self, spec: &'static NodeSpec) {
        self.raw.get_mut().node_spec = spec.as_ptr();
    }

    pub fn apply_peeps(&mut self) -> bool {
        unsafe {
            sys::bac_apply_peeps(sys::Peep_Ctx {
                prc: self.raw_ptr(),
            })
        }
    }

    pub fn opt(&mut self) {
        unsafe {
            sys::bac_opt(sys::Peep_Ctx {
                prc: self.raw_ptr(),
            });
        }
    }

    #[cfg(feature = "alloc")]
    pub fn stencil(&self) -> Stencil {
        let raw = unsafe { sys::bac_get_stencil(self.raw_ptr()) };
        Stencil {
            arena: Arena::copy(unsafe { raw.mem.as_slice() }),
            meta: raw.meta,
            spec: unsafe { (*self.raw_ptr()).node_spec },
        }
    }

    pub fn mount_stencil(&mut self, stencil: &Stencil) {
        self.raw.get_mut().node_spec = stencil.spec;
        unsafe { sys::bac_mount_stencil(self.raw.get_mut(), stencil.raw()) };
    }

    fn raw_ptr(&self) -> *mut sys::Proc {
        self.raw.get()
    }

    pub fn as_raw(&mut self) -> *mut sys::Proc {
        self.raw.get_mut()
    }

    pub fn compact(&mut self) {
        unsafe { sys::bac_compact(self.raw.get_mut()) };
    }

    fn with_node_ids<R>(&self, nodes: &[&Node], f: impl FnOnce(&[NodeId]) -> R) -> R {
        if nodes.is_empty() {
            return f(&[]);
        }
        let arena = unsafe { ptr::addr_of_mut!((*(*self.raw_ptr()).temps)[0]) };
        let pos = unsafe { (*arena).pos };
        let start = pos.checked_add(3).expect("node inputs overflow") & !3;
        let end = nodes
            .len()
            .checked_mul(core::mem::size_of::<NodeId>())
            .and_then(|size| start.checked_add(size))
            .expect("node inputs overflow");
        assert!(
            end <= unsafe { (*arena).reserved },
            "temporary arena is full"
        );
        let data = unsafe { (*arena).ptr.add(start).cast::<NodeId>() };
        for (index, node) in nodes.iter().enumerate() {
            unsafe { data.add(index).write(self.check(node)) };
        }
        unsafe { (*arena).pos = end };
        let _reset = TempNodes { arena, pos };
        f(unsafe { core::slice::from_raw_parts(data, nodes.len()) })
    }
}

struct TempNodes {
    arena: *mut sys::arna_Allocator,
    pos: usize,
}

impl Drop for TempNodes {
    fn drop(&mut self) {
        unsafe { (*self.arena).pos = self.pos };
    }
}

#[repr(transparent)]
pub struct Builder<'a> {
    proc: Proc<'a>,
}

impl<'a> Builder<'a> {
    fn check(&self, node: &Node) -> NodeId {
        self.proc.check(node)
    }

    pub fn entry(&self) -> &Node {
        self.proc.entry()
    }

    pub fn end(&self) -> &Node {
        self.proc.end()
    }

    pub fn initial_memory(&self) -> &Node {
        let mut id = 0;
        unsafe {
            sys::bac_find_node(
                self.proc.raw_ptr(),
                NodeType::Mem.0,
                self.check(self.entry()).0,
                &mut id,
            )
        };
        unsafe { self.proc.get_node(NodeId(id)) }
    }

    pub fn inputs(&self, node: &Node) -> NodeInputs<'_, 'a> {
        let id = self.check(node);
        let inputs = unsafe { sys::bac_get_inputs_node_id(self.proc.raw_ptr(), id.0) };
        NodeInputs {
            proc: &self.proc,
            data: inputs.data,
            len: inputs.len as usize,
        }
    }

    pub fn node_type(&self, node: &Node) -> NodeType {
        self.check(node);
        NodeType(unsafe { node.snapshot().spec.r#type.rtype })
    }

    pub fn datatype(&self, node: &Node) -> Datatype {
        self.check(node);
        Datatype(node.snapshot().spec.meta.dt() as u8)
    }

    #[cfg(feature = "alloc")]
    pub fn stencil(&self) -> Stencil {
        self.proc.stencil()
    }

    pub fn inline_stencil(&self, call: &Node, from: &Stencil) {
        let call = self.check(call);
        unsafe { self.proc.inline_stencil(call, from) };
    }

    pub fn inline_graph(&self, call: &Node, from: &Proc<'_>) {
        assert_ne!(
            self.proc.raw_ptr(),
            from.raw_ptr(),
            "cannot inline a proc into itself"
        );
        let call = self.check(call);
        unsafe { self.proc.inline_graph(call, from) };
    }
}

pub struct NodeInputs<'p, 'a> {
    proc: &'p Proc<'a>,
    data: *mut sys::Node_ID,
    len: usize,
}

impl<'p> Iterator for NodeInputs<'p, '_> {
    type Item = &'p Node;

    fn next(&mut self) -> Option<Self::Item> {
        if self.len == 0 {
            return None;
        }
        let id = unsafe { self.data.read() };
        self.data = unsafe { self.data.add(1) };
        self.len -= 1;
        Some(unsafe { self.proc.get_node(NodeId(id)) })
    }

    fn size_hint(&self) -> (usize, Option<usize>) {
        (self.len, Some(self.len))
    }
}

impl ExactSizeIterator for NodeInputs<'_, '_> {}
impl core::iter::FusedIterator for NodeInputs<'_, '_> {}

macro_rules! state {
    ($name:ident, $raw:ty) => {
        pub struct $name<'p, 'a> {
            proc: &'p Proc<'a>,
            raw: $raw,
        }

        impl<'p, 'a> $name<'p, 'a> {
            pub fn new(proc: &'p Proc<'a>) -> Self {
                Self {
                    proc,
                    raw: Default::default(),
                }
            }
        }
    };
}

state!(IfState, sys::ssa_If_State);
state!(LoopState, sys::ssa_Loop_State);
state!(BlockState, sys::ssa_Block_State);

impl LoopState<'_, '_> {
    pub fn loop_control(&mut self, variant: LoopControl, scope: &Node) {
        let scope = self.proc.check(scope);
        unsafe { self.proc.loop_control(variant, scope, &mut self.raw) };
    }
}

#[repr(transparent)]
#[derive(Clone, Copy, Default)]
pub struct Call(sys::Call);

impl Call {
    pub fn new(id: u32, returns: &[Datatype]) -> Self {
        assert!(returns.len() <= 4);
        let mut raw = sys::Call {
            cid: id,
            ..Default::default()
        };
        for (slot, dt) in raw.rets.iter_mut().zip(returns) {
            *slot = dt.0;
        }
        raw.flags.set_ret_count(returns.len() as u64);
        Self(raw)
    }

    pub fn with_call_conv(mut self, id: u32) -> Self {
        self.0.flags.set_ccid(id as u64);
        self
    }

    pub fn imported(mut self, imported: bool) -> Self {
        self.0.flags.set_imported(imported as u64);
        self
    }
}

pub struct Stencil {
    arena: Arena<'static>,
    meta: sys::Proc_Meta,
    spec: *mut sys::Node_Spec,
}

// Graph bytes are frozen; embedded pointers refer only to static names and BAC globals.
unsafe impl Send for Stencil {}
unsafe impl Sync for Stencil {}

#[cfg(feature = "alloc")]
impl Clone for Stencil {
    fn clone(&self) -> Self {
        Self {
            arena: Arena::copy(self.arena.bytes()),
            meta: self.meta,
            spec: self.spec,
        }
    }
}

impl Stencil {
    pub fn len(&self) -> usize {
        self.arena.bytes().len()
    }

    pub fn is_empty(&self) -> bool {
        self.arena.bytes().is_empty()
    }

    fn raw(&self) -> sys::Stencil {
        sys::Stencil {
            mem: self.arena.bytes().into(),
            meta: self.meta,
        }
    }
}

#[repr(transparent)]
pub struct NodeSpec(sys::Node_Spec);
#[repr(transparent)]
pub struct CallConv(sys::Call_Conv);

// These wrappers are constructed only from the exported read-only globals.
unsafe impl Sync for NodeSpec {}
unsafe impl Sync for CallConv {}

impl NodeSpec {
    fn as_ptr(&self) -> *mut sys::Node_Spec {
        ptr::from_ref(self).cast_mut().cast()
    }
}
impl CallConv {
    fn as_ptr(&self) -> *mut sys::Call_Conv {
        ptr::from_ref(self).cast_mut().cast()
    }

    fn from_raw_slice(raw: &'static [sys::Call_Conv]) -> &'static [Self] {
        unsafe { &*(ptr::from_ref(raw) as *const [Self]) }
    }
}

pub fn ssa_spec() -> &'static NodeSpec {
    unsafe { &*ptr::addr_of!(sys::bac_ssa_SPEC).cast() }
}
pub fn anal_spec() -> &'static NodeSpec {
    unsafe { &*ptr::addr_of!(sys::bac_anal_SPEC).cast() }
}
pub fn x64_spec() -> &'static NodeSpec {
    unsafe { &*ptr::addr_of!(sys::bac_x64_SPEC).cast() }
}
pub fn arm_spec() -> &'static NodeSpec {
    unsafe { &*ptr::addr_of!(sys::bac_arm_SPEC).cast() }
}
pub fn wasm_spec() -> &'static NodeSpec {
    unsafe { &*ptr::addr_of!(sys::bac_wasm_SPEC).cast() }
}
pub fn x64_call_conventions() -> &'static [CallConv] {
    CallConv::from_raw_slice(unsafe { &sys::bac_x64_CC_TABLE })
}
pub fn arm_call_conventions() -> &'static [CallConv] {
    CallConv::from_raw_slice(unsafe { &sys::bac_arm_CC_TABLE })
}
pub fn wasm_call_conventions() -> &'static [CallConv] {
    CallConv::from_raw_slice(unsafe { &sys::bac_wasm_CC_TABLE })
}

#[repr(transparent)]
pub struct CodegenEmitCtx<'p, 'a> {
    raw: sys::Codegen_Emit_Ctx,
    _borrow: PhantomData<(&'p mut Proc<'a>, &'p mut Arena<'p>, &'p [ParamSpec])>,
}

impl<'p, 'a> CodegenEmitCtx<'p, 'a> {
    pub fn new(proc: &'p mut Proc<'a>, code: &'p mut Arena<'_>) -> Self {
        let raw = sys::Codegen_Emit_Ctx {
            prc: proc.raw.get_mut(),
            buf: sys::Codegen_Emit_Buf {
                code: &mut code.raw,
                ..Default::default()
            },
            ..Default::default()
        };
        Self {
            raw,
            _borrow: PhantomData,
        }
    }

    pub fn set_call_conv(&mut self, abi: &'static CallConv) -> &mut Self {
        self.raw.abi = abi.as_ptr();
        self
    }

    pub fn set_regalloc_mode(&mut self, mode: RegallocMode) -> &mut Self {
        self.raw.regalloc_mode = mode.0;
        self
    }

    pub fn set_params(&mut self, specs: &'p [ParamSpec]) -> &mut Self {
        self.raw.param_specs = sys::Slice::from(specs).cast();
        self
    }

    pub fn set_constants(&mut self, arena: &'p mut Arena<'_>) -> &mut Self {
        self.raw.buf.constants = &mut arena.raw;
        self
    }

    pub fn set_relocs(&mut self, arena: &'p mut Arena<'_>) -> &mut Self {
        self.raw.buf.relocs = &mut arena.raw;
        self
    }

    pub fn set_slocs(&mut self, arena: &'p mut Arena<'_>) -> &mut Self {
        self.raw.buf.slocs = &mut arena.raw;
        self
    }

    pub fn set_cfi(&mut self, arena: &'p mut Arena<'_>) -> &mut Self {
        self.raw.buf.cfi = &mut arena.raw;
        self
    }

    pub fn set_dbg_locs(&mut self, arena: &'p mut Arena<'_>) -> &mut Self {
        self.raw.buf.dbg_locs = &mut arena.raw;
        self
    }

    pub fn compile(&mut self) -> CodegenOutput<'_> {
        let raw = unsafe { sys::bac_compile(self.raw) };
        CodegenOutput {
            code: unsafe { raw.bufs.code.as_slice() },
            constants: unsafe { raw.bufs.constants.as_slice() },
            relocs: unsafe { raw.bufs.relocs.as_slice() },
            slocs: unsafe { raw.bufs.slocs.as_slice() },
            cfi: unsafe { raw.bufs.cfi.as_slice() },
            dbg_locs: unsafe { raw.bufs.dbg_locs.as_slice() },
        }
    }
}

pub struct CodegenOutput<'a> {
    pub code: &'a [u8],
    pub constants: &'a [u8],
    pub relocs: &'a [sys::Reloc],
    pub slocs: &'a [sys::Sloc],
    pub cfi: &'a [sys::Cfi_Op],
    pub dbg_locs: &'a [sys::Dbg_Location],
}

impl Proc<'_> {
    pub unsafe fn loop_control(
        &self,
        variant: LoopControl,
        scope: NodeId,
        state: &mut sys::ssa_Loop_State,
    ) {
        unsafe { sys::bac_loop_control(variant.0, self.raw_ptr(), scope.0, state) };
    }

    pub unsafe fn inline_stencil(&self, call: NodeId, from: &Stencil) {
        unsafe { sys::bac_inline_stencil(self.raw_ptr(), call.0, from.raw()) };
    }

    pub unsafe fn inline_graph(&self, call: NodeId, from: &Proc<'_>) {
        unsafe { sys::bac_inline_graph(self.raw_ptr(), call.0, from.raw_ptr()) };
    }

    pub unsafe fn arg_gen_next(
        &self,
        mem: NodeId,
        generator: &mut sys::ssa_Param_Gen,
        name: &str,
        abi: &mut sys::ssa_Abi_Param,
    ) -> (NodeId, NodeId) {
        let mut out_mem = 0;
        let value = unsafe {
            sys::bac_arg_gen_next(
                self.raw_ptr(),
                mem.0,
                generator,
                name.into(),
                abi,
                &mut out_mem,
            )
        };
        (NodeId(out_mem), NodeId(value))
    }

    #[allow(
        clippy::mut_from_ref,
        reason = "each call allocates a disjoint arena slice"
    )]
    pub unsafe fn arg_gen_finalize(&self, generator: &mut sys::ssa_Param_Gen) -> &mut [ParamSpec] {
        let specs = unsafe { sys::bac_arg_gen_finalize(self.raw_ptr(), generator) };
        unsafe { specs.cast::<ParamSpec>().as_mut_slice() }
    }
}

#[repr(C)]
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct ParamSpec {
    pub datatype: Datatype,
    pub size: i32,
}

const _: () = {
    assert!(core::mem::size_of::<ParamSpec>() == core::mem::size_of::<sys::Param_Spec>());
    assert!(core::mem::align_of::<ParamSpec>() == core::mem::align_of::<sys::Param_Spec>());
    assert!(
        core::mem::offset_of!(ParamSpec, datatype) == core::mem::offset_of!(sys::Param_Spec, dt)
    );
    assert!(core::mem::offset_of!(ParamSpec, size) == core::mem::offset_of!(sys::Param_Spec, size));
};

impl AbiParam {
    pub fn new(datatypes: &[Datatype]) -> Self {
        let mut dt = FixedCapDynArray::new();
        for datatype in datatypes {
            dt.push(datatype.0);
        }
        Self {
            dt,
            ..Default::default()
        }
    }
}

pub struct ParamGen<'p, 'a> {
    proc: &'p Proc<'a>,
    raw: sys::ssa_Param_Gen,
}

impl<'a> Builder<'a> {
    pub fn param_gen(&self) -> ParamGen<'_, 'a> {
        ParamGen {
            proc: &self.proc,
            raw: Default::default(),
        }
    }
}

impl<'p, 'a> ParamGen<'p, 'a> {
    pub fn next(&mut self, mem: &mut &'p Node, name: &'static str, abi: &AbiParam) -> &'p Node {
        let id = self.proc.check(mem);
        let mut abi = *abi;
        let result = unsafe { self.proc.arg_gen_next(id, &mut self.raw, name, &mut abi) };
        *mem = unsafe { self.proc.get_node(result.0) };
        unsafe { self.proc.get_node(result.1) }
    }

    pub fn finalize(mut self) -> &'p mut [ParamSpec] {
        unsafe { self.proc.arg_gen_finalize(&mut self.raw) }
    }
}
