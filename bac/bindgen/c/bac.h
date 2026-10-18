
#define bac_i8       signed char
#define bac_i16      short
#define bac_i32      int
#define bac_i64      long long

#define bac_u8       unsigned char
#define bac_u16      unsigned short
#define bac_u32      unsigned int
#define bac_u64      unsigned long long

#define bac_f16      _Float16
#define bac_f32      float
#define bac_f64      double

#define bac_int      __INTPTR_TYPE__
#define bac_uint     __UINTPTR_TYPE__
#define bac_uintptr  __UINTPTR_TYPE__

#define bac_byte     unsigned char
#define bac_rune     int
#define bac_bool     _Bool

#define bac_str(s) ((bac_String){(bac_u8 *)(s), (bac_int)(sizeof(s) - 1)})
#define bac_slice(ptr, count) { (ptr), (bac_int)(count) }
#define bac_slice_array(ty, arr) \
    (Slice_Of_##ty){ (arr), (bac_int)(sizeof(arr) / sizeof((arr)[0])) }

typedef struct {
	bac_u8* data;
	bac_int len;
} bac_String;

typedef bac_u16 bac_Un_Op;
typedef struct Slice_Of_bac_i32 Slice_Of_bac_i32;
typedef struct runtime_Raw_Dynamic_Array runtime_Raw_Dynamic_Array;
typedef struct Slice_Of_bac_int Slice_Of_bac_int;
typedef struct bac_Codegen_Emit_Buf bac_Codegen_Emit_Buf;
typedef struct Slice_Of_bac_i64 Slice_Of_bac_i64;
typedef struct Dyn_Arr_Of_bac_Basic_Block Dyn_Arr_Of_bac_Basic_Block;
typedef struct bac_Codegen_Spec bac_Codegen_Spec;
typedef struct bac_Sloc bac_Sloc;
typedef struct bac_Peep_Ctx bac_Peep_Ctx;
typedef struct bac_Lib_Call bac_Lib_Call;
typedef struct bac_ssa_Loop_State bac_ssa_Loop_State;
typedef struct bac_RM_Intern_Idx bac_RM_Intern_Idx;
typedef struct bac_Proc_Meta bac_Proc_Meta;
typedef struct bac_Node_Output bac_Node_Output;
typedef bac_int bac_Opt_Flag;
typedef bac_u32 bac_Reloc_Kind;
typedef struct Dyn_Arr_Of_bac_Dbg_Data_Def Dyn_Arr_Of_bac_Dbg_Data_Def;
typedef struct Dyn_Arr_Of_bac_i32 Dyn_Arr_Of_bac_i32;
typedef struct bac_ssa_If_State bac_ssa_If_State;
typedef struct Slice_Of_Slice_Of_bac_i64 Slice_Of_Slice_Of_bac_i64;
typedef bac_u8 bac_Bs_Class_Flag;
typedef struct bac_Stats bac_Stats;
typedef struct Dyn_Arr_Of_bac_Dbg_Data_Sym Dyn_Arr_Of_bac_Dbg_Data_Sym;
typedef bac_u8 runtime_Allocator_Mode;
typedef struct bac_Node_Spec bac_Node_Spec;
typedef bac_u16 bac_Bin_Op;
typedef struct bac_Dbg_Data bac_Dbg_Data;
typedef struct Slice_Of_bac_Dbg_Location Slice_Of_bac_Dbg_Location;
typedef bac_u16 bac_Node_Type;
typedef struct arna_Allocator arna_Allocator;
typedef struct Slice_Of_bac_Sloc Slice_Of_bac_Sloc;
typedef bac_u8 bac_Dbg_Location_Kind;
typedef struct bac_Lattice bac_Lattice;
typedef struct bac_Dbg_Sym bac_Dbg_Sym;
typedef struct bac_Reloc bac_Reloc;
typedef struct Slice_Of_bac_Reg Slice_Of_bac_Reg;
typedef struct Dyn_Arr_Of_Dyn_Arr_Of_bac_Node_ID Dyn_Arr_Of_Dyn_Arr_Of_bac_Node_ID;
typedef bac_int bac_ssa_Loop_Control;
typedef struct runtime_Source_Code_Location runtime_Source_Code_Location;
typedef bac_u32 bac_Node_ID;
typedef struct bac_Tag bac_Tag;
typedef struct bac_Expanded_Node bac_Expanded_Node;
typedef struct bac_ssa_Param_Gen bac_ssa_Param_Gen;
typedef struct Slice_Of_bac_Lattice Slice_Of_bac_Lattice;
typedef struct container_queue_Queue_T_Node_ID container_queue_Queue_T_Node_ID;
typedef struct Slice_Of_bac_Cfi_Op Slice_Of_bac_Cfi_Op;
typedef bac_u8 bac_Bs_Pass;
typedef struct Soa_Slice_Of_bac_SS_Entry_V____i64 Soa_Slice_Of_bac_SS_Entry_V____i64;
typedef struct Slice_Of_Soa_Slice_Of_bac_SS_Entry_V____i64 Slice_Of_Soa_Slice_Of_bac_SS_Entry_V____i64;
typedef struct bac_Lib_Calls bac_Lib_Calls;
typedef struct bac_Basic_Block bac_Basic_Block;
typedef struct bac_Cfi_Op bac_Cfi_Op;
typedef struct bac_Call bac_Call;
typedef struct bac_Codegen_Output_Bufs bac_Codegen_Output_Bufs;
typedef struct Slice_Of_Dyn_Arr_Of_bac_i32 Slice_Of_Dyn_Arr_Of_bac_i32;
typedef struct bac_Efficiency_Stat bac_Efficiency_Stat;
typedef struct bac_Dbg_Location bac_Dbg_Location;
typedef struct bac_Codegen_Emit_Output bac_Codegen_Emit_Output;
typedef bac_u32 bac_Reloc_Size;
typedef struct Slice_Of_bac_Param_Spec Slice_Of_bac_Param_Spec;
typedef struct Slice_Of_bac_u32 Slice_Of_bac_u32;
typedef struct bac_Regalloc_Node_Meta bac_Regalloc_Node_Meta;
typedef struct Slice_Of_Slice_Of_bac_Reg Slice_Of_Slice_Of_bac_Reg;
typedef bac_u8 runtime_Allocator_Error;
typedef struct Slice_Of_bac_RM_Intern_Idx Slice_Of_bac_RM_Intern_Idx;
typedef struct bac_ssa_Abi_Param bac_ssa_Abi_Param;
typedef struct Dyn_Arr_Of_bac_Node_ID Dyn_Arr_Of_bac_Node_ID;
typedef bac_int bac_Regalloc_Mode;
typedef bac_u64 bac_Lattice_Type;
typedef bac_u8 bac_Lane_Type;
typedef struct Slice_Of_bac_u8 Slice_Of_bac_u8;
typedef struct bac_Sym_Ref bac_Sym_Ref;
typedef bac_u16 bac_Reg_Kind;
typedef bac_u8 bac_Node_Datatype;
typedef struct runtime_Maybe_T_Node_ID runtime_Maybe_T_Node_ID;
typedef struct bac_Interner bac_Interner;
typedef struct bac_Cfi_Spec bac_Cfi_Spec;
typedef struct bac_Call_Conv bac_Call_Conv;
typedef bac_int bac_Efficiency_Stat_Kind;
typedef struct bac_Regalloc_Output bac_Regalloc_Output;
typedef struct bac_Reg bac_Reg;
typedef bac_int bac_Pass;
typedef struct bac_PS_Peep_Ctx bac_PS_Peep_Ctx;
typedef bac_u8 bac_Cfi_Kind;
typedef struct bac_Schedule bac_Schedule;
typedef struct bac_Stencil bac_Stencil;
typedef struct bac_Codegen_Output bac_Codegen_Output;
typedef struct bit_arr_Bit_Set bit_arr_Bit_Set;
typedef struct Slice_Of_bac_Node_Output Slice_Of_bac_Node_Output;
typedef struct bac_Proc bac_Proc;
typedef bac_int bac_Class_Flag;
typedef struct bac_Dbg_Data_Def bac_Dbg_Data_Def;
typedef struct bac_ssa_Block_State bac_ssa_Block_State;
typedef struct bac_Loop_Tree bac_Loop_Tree;
typedef struct bac_Dbg_Data_Sym bac_Dbg_Data_Sym;
typedef struct bac_Cfg bac_Cfg;
typedef struct bac_Regalloc_Spec bac_Regalloc_Spec;
typedef struct bac_Param_Spec bac_Param_Spec;
typedef struct Slice_Of_bac_Node_ID Slice_Of_bac_Node_ID;
typedef struct Slice_Of_bac_u16 Slice_Of_bac_u16;
typedef bac_u32 bac_Sym_Ref_Type;
typedef struct bac_Regalloc bac_Regalloc;
typedef struct Fidxe_Cap_Dyn_Arr_Of_2_bac_Node_Datatype Fidxe_Cap_Dyn_Arr_Of_2_bac_Node_Datatype;
typedef struct Slice_Of_bac_Bs_Class_Flag Slice_Of_bac_Bs_Class_Flag;
typedef bac_u8 bac_Bs_Opt_Flag;
typedef struct bac_Worklist bac_Worklist;
typedef struct bac_Node bac_Node;
typedef struct Slice_Of_bac_Regalloc_Node_Meta Slice_Of_bac_Regalloc_Node_Meta;
typedef struct Slice_Of_bac_Reloc Slice_Of_bac_Reloc;
typedef struct runtime_Allocator runtime_Allocator;
typedef struct bac_Codegen_Emit_Ctx bac_Codegen_Emit_Ctx;
typedef struct bac_RM_Interner bac_RM_Interner;
typedef runtime_Allocator_Error (*runtime_Allocator_Proc)(void *, runtime_Allocator_Mode, bac_int, bac_int, void *, bac_int, runtime_Source_Code_Location, Slice_Of_bac_u8 *);
typedef void (*bac_Pre_Regalloc_Hook)(bac_Regalloc *, bac_Proc *, bac_Schedule *);
typedef bac_Node_ID (*bac_PS_Peep_Fn)(bac_PS_Peep_Ctx, bac_Expanded_Node);
typedef bac_Lattice (*bac_Sccp_Compute_Fn)(bac_Proc *, bac_Expanded_Node);
typedef runtime_Maybe_T_Node_ID (*bac_Peep_Fn)(bac_Peep_Ctx, bac_Expanded_Node);
struct bac_Peep_Ctx {
	bac_Proc *prc;
};
struct bac_Codegen_Emit_Output {
};
struct Slice_Of_bac_i64 {
	bac_i64 *data;
	bac_int len;
};
struct Slice_Of_bac_u32 {
	bac_u32 *data;
	bac_int len;
};
struct Slice_Of_bac_int {
	bac_int *data;
	bac_int len;
};
struct Slice_Of_bac_i32 {
	bac_i32 *data;
	bac_int len;
};
struct Slice_Of_bac_u8 {
	bac_u8 *data;
	bac_int len;
};
struct Slice_Of_bac_u16 {
	bac_u16 *data;
	bac_int len;
};
enum {
	bac_Sym_Ref_Type_Func = 14,
};
struct bac_Dbg_Sym {
	bac_String name;
	bac_u64 type;
};
enum {
	bac_Dbg_Location_Kind_Register = 0,
	bac_Dbg_Location_Kind_Register_Offset = 1,
};
enum {
	bac_Class_Flag_Is_Basic_Block_Start = 0,
	bac_Class_Flag_Interned = 1,
	bac_Class_Flag_Comutes = 2,
	bac_Class_Flag_Store = 3,
	bac_Class_Flag_Load = 4,
	bac_Class_Flag_Clonable = 5,
};
enum {
	bac_Node_Type_Nil = 0,
	bac_Node_Type_Entry = 1,
	bac_Node_Type_Then = 2,
	bac_Node_Type_Else = 3,
	bac_Node_Type_Region = 4,
	bac_Node_Type_Loop = 5,
	bac_Node_Type_Call_End = 6,
	bac_Node_Type_End = 7,
	bac_Node_Type_Dbg_Sym_Decl = 8,
	bac_Node_Type_Dbg_Sym_Update = 9,
	bac_Node_Type_Dbg_Scope = 10,
	bac_Node_Type_If = 11,
	bac_Node_Type_Jump = 12,
	bac_Node_Type_Trap = 13,
	bac_Node_Type_Call = 14,
	bac_Node_Type_Always = 15,
	bac_Node_Type_Return = 16,
	bac_Node_Type_Poison = 17,
	bac_Node_Type_Mem = 18,
	bac_Node_Type_Split_Mem = 19,
	bac_Node_Type_Merge_Mem = 20,
	bac_Node_Type_Sym = 21,
	bac_Node_Type_Local = 22,
	bac_Node_Type_Global = 23,
	bac_Node_Type_Param = 24,
	bac_Node_Type_Ret = 25,
	bac_Node_Type_Phi = 26,
	bac_Node_Type_CInt = 27,
	bac_Node_Type_Add = 28,
	bac_Node_Type_Sub = 29,
	bac_Node_Type_And = 30,
	bac_Node_Type_Or = 31,
	bac_Node_Type_Xor = 32,
	bac_Node_Type_Eq = 33,
	bac_Node_Type_Ne = 34,
	bac_Node_Type_Le = 35,
	bac_Node_Type_Lt = 36,
	bac_Node_Type_Gt = 37,
	bac_Node_Type_Ge = 38,
	bac_Node_Type_U_Lt = 39,
	bac_Node_Type_U_Gt = 40,
	bac_Node_Type_U_Le = 41,
	bac_Node_Type_U_Ge = 42,
	bac_Node_Type_Shl = 43,
	bac_Node_Type_Shr = 44,
	bac_Node_Type_U_Shr = 45,
	bac_Node_Type_Mul = 46,
	bac_Node_Type_Div = 47,
	bac_Node_Type_U_Div = 48,
	bac_Node_Type_Rem = 49,
	bac_Node_Type_U_Rem = 50,
	bac_Node_Type_And_Not = 51,
	bac_Node_Type_Split = 52,
	bac_Node_Type_Local_Addr = 53,
	bac_Node_Type_Global_Addr = 54,
	bac_Node_Type_Proc_Addr = 55,
	bac_Node_Type_Copy = 56,
	bac_Node_Type_Set = 57,
	bac_Node_Type_Store = 58,
	bac_Node_Type_Load = 59,
	bac_Node_Type_Neg = 60,
	bac_Node_Type_Not = 61,
	bac_Node_Type_Cast = 62,
	bac_Node_Type_Conv = 63,
	bac_Node_Type_U_Conv = 64,
	bac_Node_Type_Splat = 65,
	bac_Node_Type_Ctz = 66,
	bac_Node_Type_Simd_Extract_Lsbs = 67,
	bac_Node_Type_Simd_Reduce_Add_Bisect = 68,
};
enum {
	runtime_Allocator_Mode_Alloc = 0,
	runtime_Allocator_Mode_Free = 1,
	runtime_Allocator_Mode_Free_All = 2,
	runtime_Allocator_Mode_Resize = 3,
	runtime_Allocator_Mode_Query_Features = 4,
	runtime_Allocator_Mode_Query_Info = 5,
	runtime_Allocator_Mode_Alloc_Non_Zeroed = 6,
	runtime_Allocator_Mode_Resize_Non_Zeroed = 7,
};
enum {
	bac_Bin_Op_Shr = 44,
	bac_Bin_Op_And_Not = 51,
	bac_Bin_Op_U_Ge = 42,
	bac_Bin_Op_Eq = 33,
	bac_Bin_Op_Ne = 34,
	bac_Bin_Op_U_Div = 48,
	bac_Bin_Op_Mul = 46,
	bac_Bin_Op_U_Gt = 40,
	bac_Bin_Op_Xor = 32,
	bac_Bin_Op_Ge = 38,
	bac_Bin_Op_Or = 31,
	bac_Bin_Op_Le = 35,
	bac_Bin_Op_Gt = 37,
	bac_Bin_Op_U_Le = 41,
	bac_Bin_Op_U_Shr = 45,
	bac_Bin_Op_U_Lt = 39,
	bac_Bin_Op_Rem = 49,
	bac_Bin_Op_U_Rem = 50,
	bac_Bin_Op_Add = 28,
	bac_Bin_Op_Sub = 29,
	bac_Bin_Op_Div = 47,
	bac_Bin_Op_Shl = 43,
	bac_Bin_Op_And = 30,
	bac_Bin_Op_Lt = 36,
};
struct Slice_Of_Slice_Of_bac_i64 {
	Slice_Of_bac_i64 *data;
	bac_int len;
};
enum {
	bac_Reloc_Kind_Text = 0,
	bac_Reloc_Kind_Got = 1,
	bac_Reloc_Kind_Global = 2,
};
enum {
	bac_Lane_Type_I8 = 0,
	bac_Lane_Type_I16 = 1,
	bac_Lane_Type_I32 = 2,
	bac_Lane_Type_I64 = 3,
	bac_Lane_Type_F32 = 4,
	bac_Lane_Type_F64 = 5,
};
enum {
	bac_Node_Datatype_Void = 0,
	bac_Node_Datatype_Mem = 1,
	bac_Node_Datatype_I8 = 2,
	bac_Node_Datatype_I16 = 3,
	bac_Node_Datatype_I32 = 4,
	bac_Node_Datatype_I64 = 5,
	bac_Node_Datatype_F32 = 6,
	bac_Node_Datatype_F64 = 7,
	bac_Node_Datatype_V128 = 8,
	bac_Node_Datatype_V256 = 9,
	bac_Node_Datatype_V512 = 10,
};
enum {
	bac_Opt_Flag_Sccp = 0,
	bac_Opt_Flag_Local_Peeps = 1,
	bac_Opt_Flag_Mem_Opt = 2,
	bac_Opt_Flag_Loop_Opt = 3,
	bac_Opt_Flag_Inline = 4,
};
struct bac_Lib_Call {
	bac_u32 id : 31;
	bac_u32 absolute : 1;
};
enum {
	bac_Pass_Peep = 0,
	bac_Pass_Sccp = 1,
	bac_Pass_Mem = 2,
	bac_Pass_Loop = 3,
};
enum {
	bac_Un_Op_Cast = 62,
	bac_Un_Op_Neg = 60,
	bac_Un_Op_Simd_Extract_Lsbs = 67,
	bac_Un_Op_Simd_Reduce_Add_Bisect = 68,
	bac_Un_Op_U_Conv = 64,
	bac_Un_Op_Splat = 65,
	bac_Un_Op_Not = 61,
	bac_Un_Op_Ctz = 66,
	bac_Un_Op_Conv = 63,
};
enum {
	bac_Efficiency_Stat_Kind_graph_waste = 0,
	bac_Efficiency_Stat_Kind_late_schedule_rounds = 1,
	bac_Efficiency_Stat_Kind_ifg_rounds = 2,
	bac_Efficiency_Stat_Kind_regalloc_rounds = 3,
	bac_Efficiency_Stat_Kind_regalloc_memory_overhead = 4,
	bac_Efficiency_Stat_Kind_regalloc_wasted_lrgs = 5,
	bac_Efficiency_Stat_Kind_peephole_rounds = 6,
	bac_Efficiency_Stat_Kind_splits_inserted = 7,
	bac_Efficiency_Stat_Kind_pressure_splits_inserted = 8,
	bac_Efficiency_Stat_Kind_fail_count_ratio = 9,
	bac_Efficiency_Stat_Kind_kill_splits_inserted = 10,
	bac_Efficiency_Stat_Kind_conflict_splits_inserted = 11,
	bac_Efficiency_Stat_Kind_clones = 12,
	bac_Efficiency_Stat_Kind_inlines = 13,
	bac_Efficiency_Stat_Kind_duplicated_nodes = 14,
	bac_Efficiency_Stat_Kind_deleted_nodes = 15,
	bac_Efficiency_Stat_Kind_immediate_deletes = 16,
	bac_Efficiency_Stat_Kind_redundant_peep = 17,
	bac_Efficiency_Stat_Kind_sroad_locals = 18,
	bac_Efficiency_Stat_Kind_sroa_slot_mismatch = 19,
};
struct bac_Cfi_Spec {
	bac_u8 cfa_reg;
	bac_u8 return_addr_reg;
	bac_u32 initial_cfa_offset;
	bac_u32 code_align;
	bac_i32 data_align;
};
enum {
	bac_Cfi_Kind_Def_Cfa_Offset = 0,
	bac_Cfi_Kind_Save_Reg = 1,
	bac_Cfi_Kind_Restore_Reg = 2,
	bac_Cfi_Kind_Remember_State = 3,
	bac_Cfi_Kind_Restore_State = 4,
};
enum {
	bac_Lattice_Type_Top = 0,
	bac_Lattice_Type_Int = 1,
	bac_Lattice_Type_Float = 2,
	bac_Lattice_Type_Ctlr = 3,
	bac_Lattice_Type_Mem = 4,
	bac_Lattice_Type_Bot = 5,
};
enum {
	bac_Regalloc_Mode_with_scan = 0,
	bac_Regalloc_Mode_with_coloring = 1,
};
struct bac_Loop_Tree {
	bac_Loop_Tree *parent;
	bac_u32 depth;
	_Bool infinite;
	_Bool already_always;
};
enum {
	bac_ssa_Loop_Control_Break = 0,
	bac_ssa_Loop_Control_Continue = 1,
};
struct runtime_Source_Code_Location {
	bac_String file_path;
	bac_i32 line;
	bac_i32 column;
	bac_String procedure;
};
struct bac_Efficiency_Stat {
	bac_int total;
	bac_int ideal;
};
enum {
	bac_Reloc_Size_r32 = 0,
	bac_Reloc_Size_r26 = 1,
	bac_Reloc_Size_r19 = 2,
	bac_Reloc_Size_r2_19 = 3,
};
enum {
	runtime_Allocator_Error_None = 0,
	runtime_Allocator_Error_Out_Of_Memory = 1,
	runtime_Allocator_Error_Invalid_Pointer = 2,
	runtime_Allocator_Error_Invalid_Argument = 3,
	runtime_Allocator_Error_Mode_Not_Implemented = 4,
};
struct bac_Cfg {
	bac_u32 idepth;
};
struct Slice_Of_bac_Node_ID {
	bac_Node_ID *data;
	bac_int len;
};
struct bac_Interner {
	bac_uintptr hash_idx;
	bac_uintptr node_idx;
	bac_int len;
	bac_int cap;
};
struct bac_Reg {
	bac_u16 index : 12;
	bac_u16 kind : 4;
};
enum {
	bac_Bs_Pass_Peep = 1 << 0,
	bac_Bs_Pass_Sccp = 1 << 1,
	bac_Bs_Pass_Mem = 1 << 2,
	bac_Bs_Pass_Loop = 1 << 3,
};
struct Soa_Slice_Of_bac_SS_Entry_V____i64 {
	bac_u8 *hash;
	bac_i64 **id;
	bac_int __len;
};
struct bac_ssa_Block_State {
	bac_Node_ID end_scope;
};
struct bac_Tag {
	bac_String name[1];
	bac_u32 stable_id[1];
} __attribute__((packed, aligned(4)));
struct arna_Allocator {
	bac_u8 *ptr;
	bac_uint pos;
	bac_uint commited;
	bac_uint reserved;
};
struct bit_arr_Bit_Set {
	bac_int *masks;
	bac_int bit_length;
};
enum {
	bac_Bs_Class_Flag_Is_Basic_Block_Start = 1 << 0,
	bac_Bs_Class_Flag_Interned = 1 << 1,
	bac_Bs_Class_Flag_Comutes = 1 << 2,
	bac_Bs_Class_Flag_Store = 1 << 3,
	bac_Bs_Class_Flag_Load = 1 << 4,
	bac_Bs_Class_Flag_Clonable = 1 << 5,
};
struct bac_Node_Output {
	bac_u32 id : 22;
	bac_u32 idx : 10;
};
struct bac_RM_Intern_Idx {
	bac_u16 index : 12;
	bac_u16 kind : 4;
};
struct bac_Sloc {
	bac_u64 file : 20;
	bac_u64 line : 20;
	bac_u64 col : 16;
	bac_u64 range : 8;
} __attribute__((packed, aligned(4)));
struct bac_Dbg_Data_Def {
	bac_Node_ID node;
};
enum {
	bac_Bs_Opt_Flag_Sccp = 1 << 0,
	bac_Bs_Opt_Flag_Local_Peeps = 1 << 1,
	bac_Bs_Opt_Flag_Mem_Opt = 1 << 2,
	bac_Bs_Opt_Flag_Loop_Opt = 1 << 3,
	bac_Bs_Opt_Flag_Inline = 1 << 4,
};
struct runtime_Maybe_T_Node_ID {
	union {
		bac_Node_ID variant_0;
		bac_u8 _payload[4];
	};
	bac_u32 tag;
};
struct Fidxe_Cap_Dyn_Arr_Of_2_bac_Node_Datatype {
	bac_Node_Datatype data[2];
	bac_u8 _padding[6];
	bac_int len;
};
struct bac_Lib_Calls {
	bac_Lib_Call copy;
	bac_Lib_Call set;
};
struct Slice_Of_Soa_Slice_Of_bac_SS_Entry_V____i64 {
	struct {
		bac_u8 *hash;
		bac_i64 **id;
		bac_int __len;
	} *data;
	bac_int len;
};
struct bac_Cfi_Op {
	bac_u32 offset;
	bac_u32 arg;
	bac_Cfi_Kind kind;
	bac_u8 reg;
};
struct Slice_Of_bac_Reg {
	bac_Reg *data;
	bac_int len;
};
struct Slice_Of_bac_Sloc {
	bac_Sloc *data;
	bac_int len;
};
struct bac_ssa_If_State {
	bac_Node_ID if_;
	union {
		bac_Node_ID else_scope;
		bac_Node_ID then_scope;
	} branch;
};
struct bac_PS_Peep_Ctx {
	bac_Proc *prc;
	Slice_Of_bac_Node_ID preds;
};
struct bac_Param_Spec {
	bac_Node_Datatype dt;
	bac_i32 size;
};
struct Slice_Of_bac_Node_Output {
	bac_Node_Output *data;
	bac_int len;
};
struct bac_Sym_Ref {
	bac_Sym_Ref_Type type;
	bac_u32 id;
	bac_Node_ID node;
};
struct Slice_Of_bac_RM_Intern_Idx {
	bac_RM_Intern_Idx *data;
	bac_int len;
};
struct Slice_Of_bac_Bs_Class_Flag {
	bac_Bs_Class_Flag *data;
	bac_int len;
};
struct bac_Dbg_Location {
	bac_Dbg_Sym sym;
	bac_u32 start;
	bac_u32 end;
	bac_u32 symbol;
	bac_i32 offset;
	bac_Reg reg;
	bac_Dbg_Location_Kind kind;
};
struct bac_Call {
	bac_Cfg _0;
	struct {
		bac_u32 ccid : 26;
		bac_u32 ret_count : 4;
		bac_u32 imported : 1;
	} flags;
	bac_u32 cid;
	bac_Node_Datatype rets[4];
};
struct Slice_Of_bac_Cfi_Op {
	bac_Cfi_Op *data;
	bac_int len;
};
struct bac_Reloc {
	bac_u32 offset;
	struct {
		bac_u32 kind : 2;
		bac_u32 size : 2;
		bac_u32 scale_pow : 2;
		bac_u32 id : 26;
	} _1;
};
struct bac_Lattice {
	bac_i64 min;
	bac_i64 max;
	struct {
		bac_u64 type : 4;
		bac_u64 is_not_nan : 1;
		bac_u64 is_not_ninf : 1;
		bac_u64 is_not_pinf : 1;
		bac_u64 is_not_zero : 1;
		bac_u64 is_nan : 1;
		bac_u64 dead : 1;
		bac_u64 widens : 3;
	} meta;
};
struct bac_ssa_Abi_Param {
	Fidxe_Cap_Dyn_Arr_Of_2_bac_Node_Datatype dt;
	bac_int size;
	bac_int real_size;
	_Bool spilled;
	_Bool scalar;
	_Bool copied;
};
struct Slice_Of_Slice_Of_bac_Reg {
	Slice_Of_bac_Reg *data;
	bac_int len;
};
struct Slice_Of_bac_Param_Spec {
	bac_Param_Spec *data;
	bac_int len;
};
struct bac_Stats {
	bac_Efficiency_Stat efficiency[20];
};
struct bac_ssa_Loop_State {
	bac_Node_ID scope;
	bac_Node_ID scopes[2];
};
struct bac_RM_Interner {
	Slice_Of_Soa_Slice_Of_bac_SS_Entry_V____i64 slots;
	Slice_Of_bac_int lens;
	bac_u32 mask_len;
};
struct bac_Regalloc_Output {
	Slice_Of_bac_Reg allocs;
	bac_Reg_Kind temp_stack_slot;
	_Bool computed;
};
struct Slice_Of_bac_Reloc {
	bac_Reloc *data;
	bac_int len;
};
struct bac_Regalloc_Node_Meta {
	Slice_Of_bac_RM_Intern_Idx masks;
	Slice_Of_bac_i64 clobbers;
	bac_RM_Intern_Idx out;
	bac_i8 in_place_slot;
	bac_u8 input_start;
};
struct runtime_Allocator {
	runtime_Allocator_Proc procedure;
	void *data;
};
struct Slice_Of_bac_Lattice {
	bac_Lattice *data;
	bac_int len;
};
struct Slice_Of_bac_Dbg_Location {
	bac_Dbg_Location *data;
	bac_int len;
};
struct bac_Codegen_Emit_Buf {
	arna_Allocator *code;
	arna_Allocator *constants;
	arna_Allocator *relocs;
	arna_Allocator *slocs;
	arna_Allocator *cfi;
	arna_Allocator *dbg_locs;
};
struct bac_Node {
	bac_Tag tag;
	struct {
		union {
			bac_Node_Type itype;
			bac_u16 rtype;
		} type;
		struct {
			bac_u16 dt : 4;
			bac_u16 is_store : 1;
			bac_u16 is_load : 1;
			bac_u16 mem_alignment_pow : 3;
			bac_u16 lane : 3;
		} meta;
	} __attribute__((packed, aligned(4))) spec;
	struct {
		bac_u32 gvn : 26;
		bac_u32 scan_split : 1;
		bac_u32 extra_dwords : 4;
	} gvn_group;
	bac_u32 input_idx;
	bac_u16 input_count;
	bac_u16 input_cap;
	bac_u32 output_idx;
	bac_u16 output_count;
	bac_u16 output_cap;
	bac_u32 extra[0];
};
struct bac_Call_Conv {
	Slice_Of_Slice_Of_bac_Reg callee_saved;
	Slice_Of_Slice_Of_bac_Reg caller_saved;
	Slice_Of_Slice_Of_bac_Reg args;
	Slice_Of_Slice_Of_bac_Reg rets;
	bac_i32 red_zone_size;
	_Bool is_syscall;
	bac_Cfi_Spec cfi_spec;
	bac_Reg stack_pointer;
};
struct Slice_Of_bac_Regalloc_Node_Meta {
	bac_Regalloc_Node_Meta *data;
	bac_int len;
};
struct bac_Codegen_Output_Bufs {
	Slice_Of_bac_u8 code;
	Slice_Of_bac_u8 constants;
	Slice_Of_bac_Reloc relocs;
	Slice_Of_bac_Sloc slocs;
	Slice_Of_bac_Cfi_Op cfi;
	Slice_Of_bac_Dbg_Location dbg_locs;
};
struct runtime_Raw_Dynamic_Array {
	void *data;
	bac_int len;
	bac_int cap;
	runtime_Allocator allocator;
};
struct Dyn_Arr_Of_bac_Node_ID {
	bac_Node_ID *data;
	bac_int len, cap;
	runtime_Allocator allocator;
};
struct bac_Expanded_Node {
	bac_Node *node;
	Slice_Of_bac_Node_ID inps;
	Slice_Of_bac_Node_Output outs;
};
struct Dyn_Arr_Of_bac_Dbg_Data_Def {
	bac_Dbg_Data_Def *data;
	bac_int len, cap;
	runtime_Allocator allocator;
};
struct Dyn_Arr_Of_bac_i32 {
	bac_i32 *data;
	bac_int len, cap;
	runtime_Allocator allocator;
};
struct bac_Codegen_Output {
	bac_Codegen_Emit_Output emit;
	bac_Codegen_Output_Bufs bufs;
};
struct Slice_Of_Dyn_Arr_Of_bac_i32 {
	Dyn_Arr_Of_bac_i32 *data;
	bac_int len;
};
struct Dyn_Arr_Of_Dyn_Arr_Of_bac_Node_ID {
	Dyn_Arr_Of_bac_Node_ID *data;
	bac_int len, cap;
	runtime_Allocator allocator;
};
struct bac_Regalloc {
	bac_Regalloc_Spec *spec;
	bac_Call_Conv *cc;
	bac_RM_Interner rms;
	Slice_Of_bac_Param_Spec param_specs;
};
struct bac_Basic_Block {
	bac_Node_ID head;
	bac_Node_ID tail;
	Dyn_Arr_Of_bac_Node_ID instrs;
	bac_u32 offset;
	bac_Loop_Tree *loop_tree;
};
struct bac_ssa_Param_Gen {
	Dyn_Arr_Of_bac_Node_ID vls;
	bac_int spill_start;
};
struct container_queue_Queue_T_Node_ID {
	Dyn_Arr_Of_bac_Node_ID data;
	bac_uint len;
	bac_uint offset;
};
struct bac_Dbg_Data_Sym {
	bac_Dbg_Sym inner;
	Dyn_Arr_Of_bac_Dbg_Data_Def defs;
};
struct Dyn_Arr_Of_bac_Dbg_Data_Sym {
	bac_Dbg_Data_Sym *data;
	bac_int len, cap;
	runtime_Allocator allocator;
};
struct Dyn_Arr_Of_bac_Basic_Block {
	bac_Basic_Block *data;
	bac_int len, cap;
	runtime_Allocator allocator;
};
struct bac_Worklist {
	container_queue_Queue_T_Node_ID queue;
	bit_arr_Bit_Set in_queue;
};
struct bac_Schedule {
	Dyn_Arr_Of_bac_Basic_Block bbs;
};
struct bac_Dbg_Data {
	Dyn_Arr_Of_bac_Dbg_Data_Sym syms;
};
struct bac_Codegen_Emit_Ctx {
	bac_Proc *prc;
	bac_Schedule *schedule;
	bac_Dbg_Data *dbg_data;
	bac_Call_Conv *abi;
	bac_Codegen_Emit_Buf buf;
	_Bool emit_got_imports;
	bac_Lib_Calls lib_calls;
	bac_Regalloc_Mode regalloc_mode;
	bac_Regalloc_Output ra_out;
	Slice_Of_bac_Param_Spec param_specs;
	Slice_Of_Dyn_Arr_Of_bac_i32 stack_param_offset;
	Slice_Of_bac_i32 spill_slot_base;
	Slice_Of_bac_i32 spill_slot_size;
	Slice_Of_bac_u32 instr_offsets;
	bac_uint code_start;
	bac_uint constants_start;
	bac_uint last_off;
	bac_Sloc sloc;
};
struct bac_Regalloc_Spec {
	bac_Reg_Kind datatype_to_reg_kind[11];
	Slice_Of_bac_int spill_boundary;
	Slice_Of_Slice_Of_bac_i64 call_clobbers;
	bac_int (*collect_meta)(bac_Proc *, bac_Regalloc *, bac_Schedule *, Slice_Of_bac_Regalloc_Node_Meta *);
};
struct bac_Codegen_Spec {
	bac_Codegen_Emit_Output (*emit_function)(bac_Codegen_Emit_Ctx);
	bac_Sccp_Compute_Fn sccp_compute;
	bac_Peep_Fn peep;
	bac_PS_Peep_Fn post_schedule_peep;
	bac_Pre_Regalloc_Hook pre_regalloc_hook;
};
struct bac_Node_Spec {
	Slice_Of_bac_u8 node_extra_sizes;
	Slice_Of_bac_u16 inheritance_table;
	Slice_Of_bac_Bs_Class_Flag node_flags;
	Slice_Of_bac_int node_extra_types;
	bac_int node_kind;
	bac_Regalloc_Spec regalloc;
	bac_Codegen_Spec codegen;
};
struct bac_Proc_Meta {
	bac_Node_Spec *last_pass_spec;
	bac_Interner interner;
	bac_int weight;
	bac_int waste;
	bac_u32 gvn;
	bac_u32 gdn;
	bac_u32 stable_id;
	bac_u32 min_idepth;
	bac_u32 max_idepth;
	_Bool has_dbg;
	struct {
		bac_Node_ID entry;
		bac_Node_ID end;
	} pinned;
	struct {
		bac_Node_ID cmem;
	} cached;
};
struct bac_Proc {
	bac_Node_Spec *node_spec;
	bac_Stats *stats;
	bac_Worklist *worklist;
	Dyn_Arr_Of_Dyn_Arr_Of_bac_Node_ID *triggers;
	arna_Allocator *mem;
	bac_Sloc curret_sloc;
	bac_Proc_Meta meta;
	_Bool dont_intern;
	_Bool dont_delete;
	bac_Bs_Pass computed_passes;
	bac_Bs_Opt_Flag opt_flags;
	Slice_Of_bac_Lattice lattices;
};
struct bac_Stencil {
	Slice_Of_bac_u8 mem;
	bac_Proc_Meta meta;
};
extern bac_Node_ID bac_add_always(bac_Proc *prc, bac_String name, Slice_Of_bac_Node_ID inputs);
extern bac_Node_ID bac_add_bin_op(bac_Proc *prc, bac_String name, bac_Bin_Op type, bac_Node_Datatype dt, bac_Node_ID lhs, bac_Node_ID rhs, bac_Lane_Type lane);
extern bac_Node_ID bac_add_c_int(bac_Proc *prc, bac_String name, bac_Node_Datatype dt, bac_i64 value);
extern bac_Node_ID bac_add_call(bac_Proc *prc, bac_String name, Slice_Of_bac_Node_ID inputs, bac_Call extra);
extern bac_Node_ID bac_add_call_end(bac_Proc *prc, bac_String name, bac_Node_ID call);
extern bac_Node_ID bac_add_copy(bac_Proc *prc, bac_String name, bac_Node_ID ctrl, bac_Node_ID mem, bac_Node_ID dst, bac_Node_ID src, bac_Node_ID size);
extern bac_Node_ID bac_add_dbg_scope(bac_Proc *prc, bac_String name, Slice_Of_bac_Node_ID inputs);
extern bac_Node_ID bac_add_dbg_sym_decl(bac_Proc *prc, bac_String name);
extern bac_Node_ID bac_add_dbg_sym_update(bac_Proc *prc, bac_String name, bac_Node_ID new_value, bac_Node_ID prev_update);
extern void bac_add_efficiency_stat(bac_Stats *stats, bac_Efficiency_Stat_Kind kind, bac_int total, bac_int ideal);
extern bac_Node_ID bac_add_else(bac_Proc *prc, bac_String name, bac_Node_ID ctrl);
extern bac_Node_ID bac_add_end(bac_Proc *prc, bac_String name, Slice_Of_bac_Node_ID inputs);
extern bac_Node_ID bac_add_entry(bac_Proc *prc, bac_String name);
extern bac_Node_ID bac_add_global(bac_Proc *prc, bac_String name, bac_u32 idx);
extern bac_Node_ID bac_add_global_addr(bac_Proc *prc, bac_String name, bac_Node_ID global);
extern bac_Node_ID bac_add_if(bac_Proc *prc, bac_String name, bac_Node_ID ctrl, bac_Node_ID cond);
extern bac_Node_ID bac_add_jump(bac_Proc *prc, bac_String name, bac_Node_ID ctrl);
extern bac_Node_ID bac_add_load(bac_Proc *prc, bac_String name, bac_Node_Datatype dt, bac_Node_ID ctrl, bac_Node_ID mem, bac_Node_ID addr);
extern bac_Node_ID bac_add_local(bac_Proc *prc, bac_String name, bac_Node_ID mem);
extern bac_Node_ID bac_add_local_addr(bac_Proc *prc, bac_String name, bac_Node_ID local);
extern bac_Node_ID bac_add_loop(bac_Proc *prc, bac_String name, bac_Node_ID ctrl);
extern bac_Node_ID bac_add_mem(bac_Proc *prc, bac_String name, bac_Node_ID ctrl);
extern bac_Node_ID bac_add_merge_mem(bac_Proc *prc, bac_String name, Slice_Of_bac_Node_ID inputs);
extern bac_Node_ID bac_add_param(bac_Proc *prc, bac_String name, bac_Node_Datatype dt, bac_Node_ID entry, bac_u32 idx);
extern bac_Node_ID bac_add_phi(bac_Proc *prc, bac_String name, bac_Node_Datatype dt, bac_Node_ID reg, bac_Node_ID lhs, bac_Node_ID rhs);
extern bac_Node_ID bac_add_poison(bac_Proc *prc, bac_String name);
extern bac_Node_ID bac_add_proc_addr(bac_Proc *prc, bac_String name, bac_u32 idx);
extern bac_Node_ID bac_add_region(bac_Proc *prc, bac_String name, Slice_Of_bac_Node_ID inputs);
extern bac_Node_ID bac_add_ret(bac_Proc *prc, bac_String name, bac_Node_Datatype dt, bac_Node_ID call_end, bac_u32 idx);
extern bac_Node_ID bac_add_return(bac_Proc *prc, bac_String name, Slice_Of_bac_Node_ID inputs);
extern bac_Node_ID bac_add_set(bac_Proc *prc, bac_String name, bac_Node_ID ctrl, bac_Node_ID mem, bac_Node_ID dst, bac_Node_ID value, bac_Node_ID size);
extern bac_Node_ID bac_add_split(bac_Proc *prc, bac_String name, bac_Node_Datatype dt, bac_Node_ID dest);
extern bac_Node_ID bac_add_split_mem(bac_Proc *prc, bac_String name, bac_Node_ID mem);
extern bac_Node_ID bac_add_store(bac_Proc *prc, bac_String name, bac_Node_ID ctrl, bac_Node_ID mem, bac_Node_ID addr, bac_Node_ID value);
extern bac_Node_ID bac_add_sym(bac_Proc *prc, bac_String name, bac_Node_ID entry);
extern bac_Node_ID bac_add_then(bac_Proc *prc, bac_String name, bac_Node_ID ctrl);
extern bac_Node_ID bac_add_trap(bac_Proc *prc, bac_String name, Slice_Of_bac_Node_ID inputs);
extern bac_Node_ID bac_add_un_op(bac_Proc *prc, bac_String name, bac_Un_Op type, bac_Node_Datatype dt, bac_Node_ID oprnd, bac_Lane_Type lane);
extern bac_Node_ID bac_apply_peep(bac_Proc *prc, bac_Node_ID id);
extern _Bool bac_apply_peeps(bac_Peep_Ctx ctx);
extern void bac_compact(bac_Proc *prc);
extern _Bool bac_compute_latices(bac_Proc *ctx, runtime_Allocator scratch);
extern bac_int bac_connect(bac_Proc *prc, bac_Node_ID use, bac_Node_ID def);
extern void bac_delete_node_node(bac_Proc *prc, bac_Node *node);
extern void bac_delete_node_node_id(bac_Proc *prc, bac_Node_ID id);
extern bac_Expanded_Node bac_expand_node(bac_Proc *prc, bac_Node_ID id);
extern _Bool bac_find_node(bac_Proc *prc, bac_Node_Type kind, bac_Node_ID on, bac_Node_ID *ret0);
extern bac_Node_ID bac_find_or_create_node(bac_Proc *prc, bac_Node_Type kind);
extern Slice_Of_bac_Node_ID bac_get_inputs_node(bac_Proc *prc, bac_Node *node);
extern Slice_Of_bac_Node_ID bac_get_inputs_node_id(bac_Proc *prc, bac_Node_ID id);
extern bac_Node * bac_get_node(bac_Proc *prc, bac_Node_ID id);
// mem is borrowed
extern bac_Stencil bac_get_stencil(bac_Proc *prc);
extern bac_int bac_get_sym_count(bac_Proc *prc, bac_Node_ID *sym);
extern void bac_init_custom_fmt();
extern _Bool bac_lane_from_dt(bac_Node_Datatype ty, bac_Lane_Type *ret0);
extern void bac_mount_stencil(bac_Proc *prc, bac_Stencil stencil);
extern void bac_pin(bac_Proc *prc, bac_Node_ID id);
extern void bac_schedule_graph(bac_Proc *prc, bac_Schedule *gs, bac_int purpose, runtime_Allocator scratch);
extern void bac_schedule_peeps(bac_Proc *prc, bac_Schedule *schedule);
extern bac_Node_ID bac_set_input(bac_Proc *prc, bac_Node_ID id, bac_int idx, bac_Node_ID value, _Bool subsume_on_intern);
extern void bac_set_local_size(bac_Proc *prc, bac_Node_ID loc, bac_i32 size);
extern bac_Sloc bac_sloc_scope(bac_Proc *prc, bac_Sloc sloc, bac_Proc **out_prc);
extern _Bool bac_sym_iter_next(bac_Proc *prc, bac_Node_ID sym, bac_int *iter, bac_Sym_Ref *res);
extern void bac_take_dbg_data(bac_Proc *prc, bac_Schedule *sched, bac_Dbg_Data *data, runtime_Allocator scratch);
extern void bac_unpin(bac_Proc *prc, bac_Node_ID id, _Bool no_delete);
extern bac_Node_Spec bac_anal_SPEC;
extern bac_Call_Conv bac_arm_CC_TABLE[1];
extern bac_Node_Spec bac_arm_SPEC;
extern bac_Regalloc_Output bac_regalloc(bac_Regalloc *ra, bac_Proc *prc, bac_Schedule *sched, bac_Regalloc_Mode mode, runtime_Allocator scratch);
extern bac_Node_Spec bac_ssa_SPEC;
extern bac_Node_ID bac_add_arbitrary_load(bac_Proc *ctx, bac_Node_ID cfg, bac_Node_ID mem, bac_Node_ID addr, bac_int rsize, bac_int extra_offset, bac_Node_Datatype unit);
extern bac_Node_ID bac_add_arbitrary_store(bac_Proc *ctx, bac_Node_ID cfg, bac_Node_ID mem, bac_Node_ID addr, bac_Node_ID rvalue, bac_int rsize, bac_int extra_offset, bac_Node_Datatype unit);
extern bac_Node_ID bac_add_field_load(bac_Proc *ctx, bac_String name, bac_Node_Datatype dt, bac_Node_ID cfg, bac_Node_ID mem, bac_Node_ID base, bac_int offset);
extern bac_Node_ID bac_add_field_offset(bac_Proc *prc, bac_Node_ID base, bac_int offset);
extern bac_Node_ID bac_add_field_store(bac_Proc *ctx, bac_String name, bac_Node_ID cfg, bac_Node_ID mem, bac_Node_ID base, bac_int offset, bac_Node_ID value);
extern bac_Node_ID bac_add_lazy_phi(bac_Proc *prc, bac_String name, bac_Node_Datatype dt, bac_Node_ID reg, bac_Node_ID lhs);
extern bac_Node_ID bac_add_scope(bac_Proc *prc, bac_String name, bac_Node_ID cfg);
extern Slice_Of_bac_Param_Spec bac_arg_gen_finalize(bac_Proc *ctx, bac_ssa_Param_Gen *gen);
extern bac_Node_ID bac_arg_gen_next(bac_Proc *ctx, bac_Node_ID mem, bac_ssa_Param_Gen *gen, bac_String name, bac_ssa_Abi_Param *apa, bac_Node_ID *omem);
extern void bac_break_block(bac_Proc *prc, bac_Node_ID *scope, bac_ssa_Block_State *state);
extern bac_Codegen_Output bac_compile(bac_Codegen_Emit_Ctx ctx);
extern bac_Node_ID bac_compute_index_offset(bac_Proc *ctx, bac_Node_ID base, bac_Node_ID index, bac_i64 stride);
extern void bac_decl_local(bac_Proc *prc, bac_Node_ID loc, bac_String name, bac_u64 type);
extern void bac_delete_scope(bac_Proc *prc, bac_Node_ID scope);
extern void bac_end_block(bac_Proc *prc, bac_Node_ID *scope, bac_ssa_Block_State *state);
extern void bac_end_else(bac_Proc *prc, bac_Node_ID *else_scope, bac_ssa_If_State *state);
extern void bac_end_if(bac_Proc *prc, bac_Node_ID *then_scope, bac_ssa_If_State *state);
extern void bac_end_loop(bac_Proc *prc, bac_Node_ID *node_scope, bac_ssa_Loop_State *state);
extern bac_Node_ID bac_get_scope_value(bac_Proc *prc, bac_Node_ID scope, bac_int idx);
extern void bac_inline_graph(bac_Proc *prc, bac_Node_ID call, bac_Proc *from);
extern void bac_inline_stencil(bac_Proc *prc, bac_Node_ID call, bac_Stencil from);
extern void bac_loop_control(bac_ssa_Loop_Control variant, bac_Proc *ctx, bac_Node_ID scope, bac_ssa_Loop_State *loop);
extern _Bool bac_loopopt(bac_Proc *prc);
extern bac_Node_ID bac_make_call(bac_Proc *prc, Slice_Of_bac_Node_ID args, bac_Call extra, bac_Node_ID *ctrl);
extern _Bool bac_memopt(bac_Proc *prc);
extern bac_Node_ID bac_merge_returns(bac_Proc *prc, Slice_Of_bac_Node_ID args);
extern bac_int bac_push_scope_value(bac_Proc *prc, bac_Node_ID scope, bac_Node_ID value, bac_String name, bac_u64 type);
extern void bac_set_scope_value(bac_Proc *prc, bac_Node_ID scope, bac_int idx, bac_Node_ID value);
extern void bac_start_block(bac_ssa_Block_State *state);
extern void bac_start_else(bac_Proc *prc, bac_Node_ID *then_scope, bac_ssa_If_State *state);
extern void bac_start_if(bac_Proc *prc, bac_Node_ID scope, bac_ssa_If_State *state, bac_Node_ID cond);
extern void bac_start_loop(bac_Proc *prc, bac_Node_ID scope, bac_ssa_Loop_State *state);
extern void bac_start_loop_increment(bac_Proc *prc, bac_Node_ID *node_scope, bac_ssa_Loop_State *state);
extern bac_Node_ID bac_start_proc(bac_Proc *prc, arna_Allocator *mem);
extern void bac_truncate_scope(bac_Proc *prc, bac_Node_ID scope, bac_int to_len);
extern bac_Call_Conv bac_wasm_CC_TABLE[1];
extern bac_Node_Spec bac_wasm_SPEC;
extern bac_Call_Conv bac_x64_CC_TABLE[2];
extern bac_Node_Spec bac_x64_SPEC;
/// This is to get the thread local arenas, since odin does not allow exporting
/// thread locals
extern arna_Allocator * arna_get_scratch();
extern arna_Allocator arna_init_from_buffer(Slice_Of_bac_u8 buf);
