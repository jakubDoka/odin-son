use bac::{
    Arena, BinOp, Builder, CodegenEmitCtx, Datatype, IfState, Lane, NodeId, NodeType, ParamSpec,
    Proc, clear_scratch, set_scratch, sys,
};
use std::panic::{AssertUnwindSafe, catch_unwind};

struct Scratch;

impl Drop for Scratch {
    fn drop(&mut self) {
        clear_scratch();
    }
}

fn with_proc(test: impl FnOnce(&mut Proc<'_>)) {
    set_scratch([Arena::new(1024 * 1024), Arena::new(1024 * 1024)]);
    let _scratch = Scratch;
    let mut arena = Arena::new(1024 * 1024);
    let mut proc = Proc::new(&mut arena);
    test(&mut proc);
}

fn constant(builder: &mut Builder<'_, '_>, value: i64) {
    let value = builder.add_c_int("value", Datatype::I64, value);
    builder.merge_returns(&[builder.entry(), builder.initial_memory(), value]);
}

fn compile(proc: &mut Proc<'_>) {
    let mut code = Arena::new(4096);
    assert!(
        !CodegenEmitCtx::new(proc, &mut code)
            .compile()
            .code
            .is_empty()
    );
}

#[test]
fn build_and_compile_constant() {
    with_proc(|proc| {
        constant(&mut proc.builder(), 69);
        compile(proc);
    });
}

#[test]
fn checked_nodes_survive_builder_recreation() {
    with_proc(|proc| {
        let value = {
            let mut builder = proc.builder();
            let value = builder.add_c_int("value", Datatype::I64, 42);
            builder.merge_returns(&[builder.entry(), builder.initial_memory(), value]);
            value
        };
        let mut builder = proc.builder();
        assert_eq!(builder.node_type(value), NodeType::CInt);
        assert_eq!(builder.datatype(value), Datatype::I64);
        let sum = builder.add_bin_op("sum", BinOp::Add, Datatype::I64, value, value, Lane::I8);
        assert_eq!(builder.inputs(sum), &[value, value]);
    });
}

#[test]
fn detached_nodes_can_be_explicitly_imported() {
    with_proc(|proc| {
        let value = proc.builder().add_c_int("value", Datatype::I64, 42);
        let mut builder = proc.builder();
        assert!(catch_unwind(AssertUnwindSafe(|| builder.node_type(value))).is_err());
        unsafe { builder.import_node(value) };
        assert_eq!(builder.node_type(value), NodeType::CInt);
    });
}

#[test]
fn rejects_arena_data_that_is_not_a_node() {
    with_proc(|proc| {
        let builder = proc.builder();
        let bad = unsafe { NodeId::from_raw(builder.entry().index() + 1) };
        assert!(catch_unwind(AssertUnwindSafe(|| builder.node_type(bad))).is_err());
        let bad = unsafe { NodeId::from_raw(u32::MAX) };
        assert!(catch_unwind(AssertUnwindSafe(|| builder.node_type(bad))).is_err());
    });
}

#[test]
fn rejects_deleted_nodes() {
    with_proc(|proc| {
        let mut builder = proc.builder();
        let value = builder.add_c_int("unused", Datatype::I64, 42);
        builder.delete_node_node_id(value);
        assert!(catch_unwind(AssertUnwindSafe(|| builder.datatype(value))).is_err());
    });
}

#[test]
fn stencil_owns_graph_and_crosses_threads() {
    let mut snapshot = None;
    with_proc(|proc| {
        let mut builder = proc.builder();
        constant(&mut builder, 69);
        snapshot = Some(builder.stencil());
        builder.add_c_int("later mutation", Datatype::I64, 99);
    });
    let stencil = snapshot.unwrap();
    fn send_sync<T: Send + Sync>(_: &T) {}
    send_sync(&stencil);
    std::thread::spawn(move || {
        with_proc(|proc| {
            proc.mount_stencil(&stencil.clone());
            let mut builder = proc.builder();
            let ret = builder.inputs(builder.end())[0];
            let value = builder.inputs(ret)[2];
            assert_eq!(builder.node_name(value), "value");
            drop(builder);
            compile(proc);
        });
    })
    .join()
    .unwrap();
}

#[test]
fn branch_helpers_track_internal_nodes() {
    with_proc(|proc| {
        let mut builder = proc.builder();
        let mut scope = builder.add_scope("scope", builder.entry());
        let mem_slot = builder.push_scope_value(scope, builder.initial_memory(), "memory", 0);
        let initial = builder.add_c_int("initial", Datatype::I64, 0);
        let slot = builder.push_scope_value(scope, initial, "value", 0);
        let condition = builder.add_c_int("condition", Datatype::I8, 1);
        let mut state = IfState::default();
        builder.start_if(scope, &mut state, condition);
        let then = builder.add_c_int("then", Datatype::I64, 69);
        builder.set_scope_value(scope, slot, then);
        builder.start_else(&mut scope, &mut state);
        let otherwise = builder.add_c_int("else", Datatype::I64, 42);
        builder.set_scope_value(scope, slot, otherwise);
        builder.end_else(&mut scope, &mut state);
        let value = builder.get_scope_value(scope, slot);
        let mem = builder.get_scope_value(scope, mem_slot);
        let ctrl = builder.inputs(scope)[0];
        builder.merge_returns(&[ctrl, mem, value]);
        builder.delete_scope(scope);
        drop(builder);
        compile(proc);
    });
}

#[test]
fn unchecked_construction_has_no_node_tracker_requirement() {
    with_proc(|proc| {
        let value = unsafe { proc.add_c_int("value", Datatype::I64, 69) };
        let entry = proc.entry();
        let (mem, found) = unsafe { proc.find_node(NodeType::Mem, entry) };
        assert!(found);
        unsafe { proc.merge_returns(&[entry, mem, value]) };
        compile(proc);
    });
}

#[test]
fn parameter_generator_borrows_builder_and_tracks_abi_nodes() {
    with_proc(|proc| {
        let mut builder = proc.builder();
        let initial_memory = builder.initial_memory();
        let mut generator = builder.param_gen();
        let abi = bac::AbiParam {
            datatypes: vec![Datatype::I64],
            size: 8,
            real_size: 8,
            spilled: false,
            scalar: false,
            copied: false,
        };
        let (mem, value) = generator.next(initial_memory, "parameter", &abi);
        let specs = generator.finalize();
        assert_eq!(builder.datatype(mem), Datatype::Mem);
        assert_eq!(builder.node_type(value), NodeType::Local_Addr);
        assert_eq!(specs.len(), 2);
        assert_eq!(specs[0].datatype, Datatype::I64);
        assert_eq!(specs[1].size, 8);
    });
}

#[test]
fn loop_helpers_track_lazy_phis_and_internal_scopes() {
    with_proc(|proc| {
        let mut builder = proc.builder();
        let mut scope = builder.add_scope("scope", builder.entry());
        let mem_slot = builder.push_scope_value(scope, builder.initial_memory(), "memory", 0);
        let initial = builder.add_c_int("initial", Datatype::I64, 3);
        let slot = builder.push_scope_value(scope, initial, "counter", 0);
        let mut loop_state = bac::LoopState::default();
        builder.start_loop(scope, &mut loop_state);
        let condition = builder.get_scope_value(scope, slot);
        let mut branch = IfState::default();
        builder.start_if(scope, &mut branch, condition);
        let one = builder.add_c_int("one", Datatype::I64, 1);
        let next = builder.add_bin_op(
            "decrement",
            BinOp::Sub,
            Datatype::I64,
            condition,
            one,
            Lane::I8,
        );
        builder.set_scope_value(scope, slot, next);
        builder.start_else(&mut scope, &mut branch);
        builder.loop_control(bac::LoopControl::Break, scope, &mut loop_state);
        scope = NodeId::NONE;
        builder.end_else(&mut scope, &mut branch);
        builder.end_loop(&mut scope, &mut loop_state);
        let ctrl = builder.inputs(scope)[0];
        let mem = builder.get_scope_value(scope, mem_slot);
        let value = builder.get_scope_value(scope, slot);
        builder.merge_returns(&[ctrl, mem, value]);
        builder.delete_scope(scope);
        drop(builder);
        compile(proc);
    });
}

#[test]
fn block_helpers_update_node_handles() {
    with_proc(|proc| {
        let mut builder = proc.builder();
        let mut scope = builder.add_scope("scope", builder.entry());
        let mut state = bac::BlockState::default();
        builder.break_block(&mut scope, &mut state);
        assert_eq!(scope, NodeId::NONE);
        builder.end_block(&mut scope, &mut state);
        let entry = builder.entry();
        assert_eq!(builder.inputs(scope), &[entry]);
    });
}

#[test]
fn inline_snapshot_replaces_call_nodes() {
    let mut snapshot = None;
    with_proc(|proc| {
        constant(&mut proc.builder(), 69);
        snapshot = Some(proc.stencil());
    });
    let stencil = snapshot.unwrap();
    with_proc(|proc| {
        let mut builder = proc.builder();
        let (ctrl, mem) = builder.make_call(
            &[builder.entry(), builder.initial_memory(), NodeId::NONE],
            bac::Call::new(1, &[Datatype::I64]),
        );
        assert_eq!(builder.node_type(ctrl), NodeType::Call_End);
        assert_eq!(builder.node_type(mem), NodeType::Mem);
        let call = builder.inputs(ctrl)[0];
        let value = builder.add_ret("result", Datatype::I64, ctrl, 0);
        builder.merge_returns(&[ctrl, mem, value]);
        builder.inline_stencil(call, &stencil);
        drop(builder);
        compile(proc);
    });
}

#[test]
fn mounting_discards_old_node_boundaries() {
    with_proc(|proc| {
        constant(&mut proc.builder(), 69);
        let stencil = proc.stencil();
        let old = proc
            .builder()
            .add_c_int("not in snapshot", Datatype::I64, 100);
        proc.mount_stencil(&stencil);
        let builder = proc.builder();
        assert!(catch_unwind(AssertUnwindSafe(|| builder.node_type(old))).is_err());
    });
}

#[test]
fn caller_storage_and_borrowed_arena_bytes() {
    #[repr(align(4096))]
    struct Aligned([u8; 4096 * 64]);
    let mut buffer = Aligned([0; 4096 * 64]);
    let buffer_ptr = buffer.0.as_ptr();
    let mut arena = Arena::from_buffer(&mut buffer.0);
    {
        let mut proc = Proc::new(&mut arena);
        constant(&mut proc.builder(), 69);
    }
    assert_eq!(arena.bytes().as_ptr(), buffer_ptr);
    assert!(!arena.bytes().is_empty());
    arena.reset();
    assert!(arena.bytes().is_empty());
    drop(arena);
    buffer.0.fill(0);
}

#[test]
fn empty_arenas_are_supported() {
    assert!(Arena::default().bytes().is_empty());
    assert!(Arena::new(0).bytes().is_empty());
    clear_scratch();
    clear_scratch();
}

#[test]
fn scratch_can_be_replaced_between_calls() {
    with_proc(|proc| {
        constant(&mut proc.builder(), 69);
        set_scratch([Arena::new(1024 * 1024), Arena::new(1024 * 1024)]);
        compile(proc);
        clear_scratch();
    });
}

#[test]
fn codegen_borrows_parameters_and_all_output_buffers() {
    with_proc(|proc| {
        constant(&mut proc.builder(), 69);
        let params = [ParamSpec {
            datatype: Datatype::I64,
            size: 0,
        }];
        let mut code = Arena::new(4096);
        let mut constants = Arena::new(4096);
        let mut relocs = Arena::new(4096);
        let mut slocs = Arena::new(4096);
        let mut cfi = Arena::new(4096);
        let mut dbg_locs = Arena::new(4096);
        let output_ptr;
        let output_len;
        {
            let mut ctx = CodegenEmitCtx::new(proc, &mut code);
            ctx.set_params(&params)
                .set_constants(&mut constants)
                .set_relocs(&mut relocs)
                .set_slocs(&mut slocs)
                .set_cfi(&mut cfi)
                .set_dbg_locs(&mut dbg_locs);
            let raw = unsafe { &*std::ptr::from_ref(&ctx).cast::<sys::bac_Codegen_Emit_Ctx>() };
            assert_eq!(
                raw.param_specs.data.cast::<ParamSpec>(),
                params.as_ptr().cast_mut()
            );
            let output = ctx.compile();
            output_ptr = output.code.as_ptr();
            output_len = output.code.len();
            assert!(output_len > 0);
            assert!(output.constants.is_empty());
            assert!(output.relocs.is_empty());
        }
        assert_eq!(output_ptr, code.bytes().as_ptr());
        assert_eq!(output_len, code.bytes().len());
        code.reset();
        constants.reset();
        relocs.reset();
        slocs.reset();
        cfi.reset();
        dbg_locs.reset();
    });
}

#[test]
fn wrapper_layouts_match_ffi() {
    fn same_layout<T, U>() {
        assert_eq!(std::mem::size_of::<T>(), std::mem::size_of::<U>());
        assert_eq!(std::mem::align_of::<T>(), std::mem::align_of::<U>());
    }
    same_layout::<Arena<'_>, sys::arna_Allocator>();
    same_layout::<Proc<'_>, sys::bac_Proc>();
    same_layout::<CodegenEmitCtx<'_, '_>, sys::bac_Codegen_Emit_Ctx>();
    same_layout::<ParamSpec, sys::bac_Param_Spec>();
    same_layout::<IfState, sys::bac_ssa_If_State>();
    same_layout::<bac::LoopState, sys::bac_ssa_Loop_State>();
    same_layout::<bac::BlockState, sys::bac_ssa_Block_State>();
}
