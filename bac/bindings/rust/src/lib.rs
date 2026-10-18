#![no_std]
#![deny(unsafe_op_in_unsafe_fn)]
#![allow(clippy::missing_safety_doc)]

// AMEND CODEGEN:
//  - Generate better names for the anon types, use the parent struct name + field name
//  - Generate better formatting
//  - Generate generic version of fixed size array FixedCapDynArray<LEN, T>

extern crate alloc;

use alloc::{
    alloc::{Layout, alloc_zeroed, dealloc, handle_alloc_error},
    vec::Vec,
};
use core::{marker::PhantomData, ptr};

#[rustfmt::skip]
pub mod sys;
#[rustfmt::skip]
mod generated;
pub use generated::*;

const PAGE_ALIGN: usize = 4096;

#[repr(transparent)]
pub struct Arena<'a> {
    raw: sys::arna_Allocator,
    _borrow: PhantomData<&'a mut [u8]>,
}

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
            buffer.as_ptr() as usize % PAGE_ALIGN,
            0,
            "arena buffer must be page aligned"
        );
        Self {
            raw: arena_raw(buffer.as_mut_ptr(), buffer.len()),
            _borrow: PhantomData,
        }
    }

    pub fn bytes(&self) -> &[u8] {
        unsafe { raw_slice(self.raw.ptr, self.raw.pos) }
    }

    pub fn reset(&mut self) {
        self.raw.pos = 0;
    }
}

impl Default for Arena<'_> {
    fn default() -> Self {
        Self {
            raw: unsafe { core::mem::zeroed() },
            _borrow: PhantomData,
        }
    }
}

impl Drop for Arena<'_> {
    fn drop(&mut self) {
        if self.raw.commited == self.raw.reserved + 2 {
            unsafe { dealloc(self.raw.ptr, arena_layout(self.raw.reserved)) };
        }
    }
}

fn arena_layout(capacity: usize) -> Layout {
    assert!(capacity < isize::MAX as usize);
    Layout::from_size_align(capacity.max(1), PAGE_ALIGN).expect("invalid arena capacity")
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
pub struct Proc<'a> {
    raw: sys::bac_Proc,
    _arena: PhantomData<(&'a mut Arena<'a>, &'a mut Temps<'a>)>,
}

impl<'a> Proc<'a> {
    pub fn new(arena: &'a mut Arena<'_>, temps: &'a mut Temps<'_>) -> Self {
        let mut raw = unsafe { core::mem::zeroed() };
        unsafe { sys::bac_start_proc(&mut raw, &mut arena.raw, ptr::from_mut(temps).cast()) };
        Self {
            raw,
            _arena: PhantomData,
        }
    }

    pub fn builder(&mut self) -> Builder<'_, 'a> {
        let mut builder = Builder {
            proc: self,
            nodes: Vec::new(),
        };
        builder.seed();
        builder
    }

    pub fn entry(&self) -> NodeId {
        NodeId(self.raw.meta.pinned.entry)
    }

    pub fn set_target(&mut self, spec: &'static NodeSpec) {
        self.raw.node_spec = spec.as_ptr();
    }

    pub fn stencil(&self) -> Stencil {
        let raw = unsafe { sys::bac_get_stencil(self.raw_ptr()) };
        Stencil {
            arena: Arena::copy(unsafe { raw_slice(raw.mem.data, raw.mem.len as usize) }),
            meta: raw.meta,
            spec: self.raw.node_spec,
        }
    }

    pub fn mount_stencil(&mut self, stencil: &Stencil) {
        self.raw.node_spec = stencil.spec;
        unsafe { sys::bac_mount_stencil(&mut self.raw, stencil.raw()) };
    }

    fn raw_ptr(&self) -> *mut sys::bac_Proc {
        ptr::from_ref(&self.raw).cast_mut()
    }

    pub unsafe fn as_raw(&mut self) -> *mut sys::bac_Proc {
        &mut self.raw
    }

    pub unsafe fn compact(&mut self) {
        unsafe { sys::bac_compact(&mut self.raw) };
    }
}

pub struct Builder<'p, 'a> {
    proc: &'p mut Proc<'a>,
    nodes: Vec<u64>,
}

impl Builder<'_, '_> {
    fn register(&mut self, id: NodeId) {
        if id == NodeId::NONE {
            return;
        }
        let index = id.0 as usize;
        let used = unsafe { (*self.proc.raw.mem).pos };
        assert!(
            index
                .checked_mul(4)
                .and_then(|offset| offset.checked_add(core::mem::size_of::<sys::bac_Node>()))
                .is_some_and(|end| end <= used),
            "BAC returned an out-of-bounds node"
        );
        if self.nodes.len() <= index / 64 {
            self.nodes.resize(index / 64 + 1, 0);
        }
        self.nodes[index / 64] |= 1 << (index % 64);
    }

    fn check(&self, id: NodeId) {
        if id == NodeId::NONE {
            return;
        }
        let index = id.0 as usize;
        assert!(
            self.nodes
                .get(index / 64)
                .is_some_and(|word| word & (1 << (index % 64)) != 0),
            "index does not address a known node: {}",
            id.0
        );
        let node = unsafe { sys::bac_get_node(self.proc.raw_ptr(), id.0).read() };
        assert_ne!(
            unsafe { node.spec.r#type.rtype },
            u16::MAX,
            "node has been deleted: {}",
            id.0
        );
    }

    fn seed(&mut self) {
        let mut pending = alloc::vec![self.entry(), self.end()];
        while let Some(id) = pending.pop() {
            if id == NodeId::NONE {
                continue;
            }
            let index = id.0 as usize;
            if self
                .nodes
                .get(index / 64)
                .is_some_and(|word| word & (1 << (index % 64)) != 0)
            {
                continue;
            }
            self.register(id);
            let node = unsafe { sys::bac_expand_node(self.proc.raw_ptr(), id.0) };
            pending.extend(
                unsafe { raw_slice(node.inps.data, node.inps.len as usize) }
                    .iter()
                    .copied()
                    .map(NodeId),
            );
            pending.extend(
                unsafe { raw_slice(node.outs.data, node.outs.len as usize) }
                    .iter()
                    .map(|out| NodeId(out.id() as u32)),
            );
        }
    }

    pub fn entry(&self) -> NodeId {
        self.proc.entry()
    }

    pub fn end(&self) -> NodeId {
        NodeId(self.proc.raw.meta.pinned.end)
    }

    pub fn initial_memory(&self) -> NodeId {
        let mut id = 0;
        unsafe {
            sys::bac_find_node(
                self.proc.raw_ptr(),
                NodeType::Mem.0,
                self.entry().0,
                &mut id,
            )
        };
        let id = NodeId(id);
        self.check(id);
        id
    }

    pub fn inputs(&mut self, id: NodeId) -> &[NodeId] {
        self.check(id);
        let inputs = unsafe { sys::bac_get_inputs_node_id(&mut self.proc.raw, id.0) };
        let result = unsafe { raw_slice(inputs.data.cast::<NodeId>(), inputs.len as usize) };
        for &id in result {
            self.register(id);
        }
        result
    }

    pub fn node_type(&self, id: NodeId) -> NodeType {
        self.check(id);
        NodeType(unsafe {
            (*sys::bac_get_node(self.proc.raw_ptr(), id.0))
                .spec
                .r#type
                .rtype
        })
    }

    pub fn datatype(&self, id: NodeId) -> Datatype {
        self.check(id);
        Datatype(unsafe {
            (*sys::bac_get_node(self.proc.raw_ptr(), id.0))
                .spec
                .meta
                .dt() as u8
        })
    }

    pub fn node_name(&self, id: NodeId) -> &str {
        self.check(id);
        let names = unsafe { (*sys::bac_get_node(self.proc.raw_ptr(), id.0)).tag.name };
        let Some(name) = names.first() else {
            return "";
        };
        core::str::from_utf8(unsafe { raw_slice(name.data, name.len as usize) })
            .expect("node name is not UTF-8")
    }

    pub fn stencil(&self) -> Stencil {
        self.proc.stencil()
    }

    pub unsafe fn import_node(&mut self, id: NodeId) -> NodeId {
        self.register(id);
        self.check(id);
        id
    }

    fn check_state(&self, state: &impl State) {
        for id in state.ids() {
            self.check(id);
        }
    }

    fn register_state(&mut self, state: &impl State) {
        for id in state.ids() {
            self.register(id);
        }
    }

    pub fn loop_control(&mut self, variant: LoopControl, scope: NodeId, state: &mut LoopState) {
        self.check(scope);
        self.check_state(state);
        unsafe { self.proc.loop_control(variant, scope, state) };
        self.register_state(state);
    }

    pub fn inline_stencil(&mut self, call: NodeId, from: &Stencil) {
        self.check(call);
        unsafe { self.proc.inline_stencil(call, from) };
    }

    pub fn inline_graph(&mut self, call: NodeId, from: &Proc<'_>) {
        self.check(call);
        unsafe { self.proc.inline_graph(call, from) };
    }
}

trait State {
    fn ids(&self) -> [NodeId; 3];
}

macro_rules! state {
    ($name:ident, $raw:ty) => {
        #[repr(transparent)]
        pub struct $name {
            raw: $raw,
        }
        impl Default for $name {
            fn default() -> Self {
                Self {
                    raw: unsafe { core::mem::zeroed() },
                }
            }
        }
    };
}

state!(IfState, sys::bac_ssa_If_State);
state!(LoopState, sys::bac_ssa_Loop_State);
state!(BlockState, sys::bac_ssa_Block_State);

impl State for IfState {
    fn ids(&self) -> [NodeId; 3] {
        [
            NodeId(self.raw.if_),
            NodeId(unsafe { self.raw.branch.else_scope }),
            NodeId::NONE,
        ]
    }
}
impl State for LoopState {
    fn ids(&self) -> [NodeId; 3] {
        [
            NodeId(self.raw.scope),
            NodeId(self.raw.scopes[0]),
            NodeId(self.raw.scopes[1]),
        ]
    }
}
impl State for BlockState {
    fn ids(&self) -> [NodeId; 3] {
        [NodeId(self.raw.end_scope), NodeId::NONE, NodeId::NONE]
    }
}

#[repr(transparent)]
#[derive(Clone, Copy)]
pub struct Call(sys::bac_Call);

impl Call {
    pub fn new(id: u32, returns: &[Datatype]) -> Self {
        assert!(returns.len() <= 4);
        let mut raw: sys::bac_Call = unsafe { core::mem::zeroed() };
        raw.cid = id;
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
    meta: sys::bac_Proc_Meta,
    spec: *mut sys::bac_Node_Spec,
}

// Graph bytes are frozen; embedded pointers refer only to static names and BAC globals.
unsafe impl Send for Stencil {}
unsafe impl Sync for Stencil {}

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

    fn raw(&self) -> sys::bac_Stencil {
        sys::bac_Stencil {
            mem: sys::Slice {
                data: self.arena.raw.ptr,
                len: self.len() as isize,
            },
            meta: self.meta,
        }
    }
}

#[repr(transparent)]
pub struct NodeSpec(sys::bac_Node_Spec);
#[repr(transparent)]
pub struct CallConv(sys::bac_Call_Conv);

// These wrappers are constructed only from the exported read-only globals.
unsafe impl Sync for NodeSpec {}
unsafe impl Sync for CallConv {}

impl NodeSpec {
    fn as_ptr(&self) -> *mut sys::bac_Node_Spec {
        ptr::from_ref(self).cast_mut().cast()
    }
}
impl CallConv {
    fn as_ptr(&self) -> *mut sys::bac_Call_Conv {
        ptr::from_ref(self).cast_mut().cast()
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
    unsafe {
        raw_slice(
            sys::bac_x64_CC_TABLE.as_ptr().cast(),
            sys::bac_x64_CC_TABLE.len(),
        )
    }
}
pub fn arm_call_conventions() -> &'static [CallConv] {
    unsafe {
        raw_slice(
            sys::bac_arm_CC_TABLE.as_ptr().cast(),
            sys::bac_arm_CC_TABLE.len(),
        )
    }
}
pub fn wasm_call_conventions() -> &'static [CallConv] {
    unsafe {
        raw_slice(
            sys::bac_wasm_CC_TABLE.as_ptr().cast(),
            sys::bac_wasm_CC_TABLE.len(),
        )
    }
}

#[repr(transparent)]
pub struct CodegenEmitCtx<'p, 'a> {
    raw: sys::bac_Codegen_Emit_Ctx,
    _borrow: PhantomData<(&'p mut Proc<'a>, &'p mut Arena<'p>, &'p [ParamSpec])>,
}

impl<'p, 'a> CodegenEmitCtx<'p, 'a> {
    pub fn new(proc: &'p mut Proc<'a>, code: &'p mut Arena<'_>) -> Self {
        let mut raw: sys::bac_Codegen_Emit_Ctx = unsafe { core::mem::zeroed() };
        raw.prc = &mut proc.raw;
        raw.buf.code = &mut code.raw;
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
        self.raw.param_specs = sys::Slice {
            data: specs.as_ptr().cast_mut().cast(),
            len: specs.len() as isize,
        };
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
            code: unsafe { raw_slice(raw.bufs.code.data, raw.bufs.code.len as usize) },
            constants: unsafe {
                raw_slice(raw.bufs.constants.data, raw.bufs.constants.len as usize)
            },
            relocs: unsafe { raw_slice(raw.bufs.relocs.data, raw.bufs.relocs.len as usize) },
            slocs: unsafe { raw_slice(raw.bufs.slocs.data, raw.bufs.slocs.len as usize) },
            cfi: unsafe { raw_slice(raw.bufs.cfi.data, raw.bufs.cfi.len as usize) },
            dbg_locs: unsafe { raw_slice(raw.bufs.dbg_locs.data, raw.bufs.dbg_locs.len as usize) },
        }
    }
}

pub struct CodegenOutput<'a> {
    pub code: &'a [u8],
    pub constants: &'a [u8],
    pub relocs: &'a [sys::bac_Reloc],
    pub slocs: &'a [sys::bac_Sloc],
    pub cfi: &'a [sys::bac_Cfi_Op],
    pub dbg_locs: &'a [sys::bac_Dbg_Location],
}

unsafe fn raw_slice<'a, T>(data: *const T, len: usize) -> &'a [T] {
    if len == 0 {
        &[]
    } else {
        unsafe { core::slice::from_raw_parts(data, len) }
    }
}

fn raw_string(text: &str) -> sys::String {
    sys::String {
        data: text.as_ptr().cast_mut(),
        len: text.len() as isize,
    }
}

impl Proc<'_> {
    pub unsafe fn loop_control(
        &mut self,
        variant: LoopControl,
        scope: NodeId,
        state: &mut LoopState,
    ) {
        unsafe { sys::bac_loop_control(variant.0, &mut self.raw, scope.0, &mut state.raw) };
    }

    pub unsafe fn inline_stencil(&mut self, call: NodeId, from: &Stencil) {
        unsafe { sys::bac_inline_stencil(&mut self.raw, call.0, from.raw()) };
    }

    pub unsafe fn inline_graph(&mut self, call: NodeId, from: &Proc<'_>) {
        unsafe { sys::bac_inline_graph(&mut self.raw, call.0, from.raw_ptr()) };
    }

    pub unsafe fn arg_gen_next(
        &mut self,
        mem: NodeId,
        generator: &mut sys::bac_ssa_Param_Gen,
        name: &str,
        abi: &mut sys::bac_ssa_Abi_Param,
    ) -> (NodeId, NodeId) {
        let mut out_mem = 0;
        let value = unsafe {
            sys::bac_arg_gen_next(
                &mut self.raw,
                mem.0,
                generator,
                raw_string(name),
                abi,
                &mut out_mem,
            )
        };
        (NodeId(out_mem), NodeId(value))
    }

    pub unsafe fn arg_gen_finalize(
        &mut self,
        generator: &mut sys::bac_ssa_Param_Gen,
    ) -> Vec<ParamSpec> {
        let specs = unsafe { sys::bac_arg_gen_finalize(&mut self.raw, generator) };
        unsafe { raw_slice(specs.data.cast::<ParamSpec>(), specs.len as usize) }.to_vec()
    }
}

#[repr(C)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct ParamSpec {
    pub datatype: Datatype,
    pub size: i32,
}

const _: () = {
    assert!(core::mem::size_of::<ParamSpec>() == core::mem::size_of::<sys::bac_Param_Spec>());
    assert!(core::mem::align_of::<ParamSpec>() == core::mem::align_of::<sys::bac_Param_Spec>());
    assert!(
        core::mem::offset_of!(ParamSpec, datatype)
            == core::mem::offset_of!(sys::bac_Param_Spec, dt)
    );
    assert!(
        core::mem::offset_of!(ParamSpec, size) == core::mem::offset_of!(sys::bac_Param_Spec, size)
    );
};

// AMEND: make a proper rust counterpart to [dynamic; LEN]T, and use the native AbiParam for
// this.
pub struct AbiParam {
    pub datatypes: Vec<Datatype>,
    pub size: isize,
    pub real_size: isize,
    pub spilled: bool,
    pub scalar: bool,
    pub copied: bool,
}

impl AbiParam {
    fn raw(&self) -> sys::bac_ssa_Abi_Param {
        assert!(self.datatypes.len() <= 2);
        let mut raw: sys::bac_ssa_Abi_Param = unsafe { core::mem::zeroed() };
        for (slot, dt) in raw.dt.data.iter_mut().zip(&self.datatypes) {
            *slot = dt.0;
        }
        raw.dt.len = self.datatypes.len() as isize;
        raw.size = self.size;
        raw.real_size = self.real_size;
        raw.spilled = self.spilled;
        raw.scalar = self.scalar;
        raw.copied = self.copied;
        raw
    }
}

pub struct ParamGen<'b, 'p, 'a> {
    builder: &'b mut Builder<'p, 'a>,
    values: Vec<u32>,
    spill_start: isize,
}

impl<'p, 'a> Builder<'p, 'a> {
    pub fn param_gen<'b>(&'b mut self) -> ParamGen<'b, 'p, 'a> {
        ParamGen {
            builder: self,
            values: Vec::new(),
            spill_start: 0,
        }
    }
}

impl<'p, 'a> ParamGen<'_, 'p, 'a> {
    fn with<T>(
        &mut self,
        extra: usize,
        call: impl FnOnce(&mut Builder<'p, 'a>, &mut sys::bac_ssa_Param_Gen) -> T,
    ) -> T {
        for &id in &self.values {
            self.builder.check(NodeId(id));
        }
        self.values.reserve(extra);
        let mut raw: sys::bac_ssa_Param_Gen = unsafe { core::mem::zeroed() };
        raw.vls.data = self.values.as_mut_ptr();
        raw.vls.len = self.values.len() as isize;
        raw.vls.cap = self.values.capacity() as isize;
        raw.spill_start = self.spill_start;
        let result = call(self.builder, &mut raw);
        assert!(raw.vls.len >= 0 && raw.vls.len as usize <= self.values.capacity());
        unsafe { self.values.set_len(raw.vls.len as usize) };
        for &id in &self.values {
            self.builder.register(NodeId(id));
        }
        self.spill_start = raw.spill_start;
        result
    }

    pub fn next(&mut self, mem: NodeId, name: &'static str, abi: &AbiParam) -> (NodeId, NodeId) {
        self.builder.check(mem);
        let mut abi = abi.raw();
        let result = self.with(3, |builder, raw| unsafe {
            builder.proc.arg_gen_next(mem, raw, name, &mut abi)
        });
        self.builder.register(result.0);
        self.builder.register(result.1);
        result
    }

    pub fn finalize(mut self) -> Vec<ParamSpec> {
        self.with(0, |builder, raw| unsafe {
            builder.proc.arg_gen_finalize(raw)
        })
    }
}
