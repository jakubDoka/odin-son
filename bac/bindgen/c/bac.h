
#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>

typedef struct {
	char* data;
	size_t len;
} bac_String;

typedef uint8_t runtime_Allocator_Mode;
typedef struct bac_Lib_Calls bac_Lib_Calls;
typedef struct Slice_Of_bac_RM_Intern_Idx Slice_Of_bac_RM_Intern_Idx;
typedef struct Dyn_Arr_Of_bac_Dbg_Data_Def Dyn_Arr_Of_bac_Dbg_Data_Def;
typedef struct bac_Codegen_Output bac_Codegen_Output;
typedef struct bac_Peep_Ctx bac_Peep_Ctx;
typedef struct bac_Cfg bac_Cfg;
typedef struct bac_Param_Spec bac_Param_Spec;
typedef struct Dyn_Arr_Of_int32_t Dyn_Arr_Of_int32_t;
typedef struct bac_PS_Peep_Ctx bac_PS_Peep_Ctx;
typedef struct bac_Tag bac_Tag;
typedef struct bac_Node_Spec bac_Node_Spec;
typedef int64_t bac_Efficiency_Stat_Kind;
typedef uint8_t bac_Cfi_Kind;
typedef struct bac_Codegen_Emit_Buf bac_Codegen_Emit_Buf;
typedef struct Slice_Of_int64_t Slice_Of_int64_t;
typedef uint32_t bac_Reloc_Kind;
typedef int64_t bac_regalloc_Mode;
typedef struct Slice_Of_bac_Reloc Slice_Of_bac_Reloc;
typedef struct Slice_Of_uint8_t Slice_Of_uint8_t;
typedef uint8_t runtime_Allocator_Error;
typedef struct bac_Lattice bac_Lattice;
typedef struct Slice_Of_bac_Sloc Slice_Of_bac_Sloc;
typedef struct bac_Stats bac_Stats;
typedef struct Slice_Of_bac_Lattice Slice_Of_bac_Lattice;
typedef struct bac_Dbg_Location bac_Dbg_Location;
typedef struct bac_Regalloc_Node_Meta bac_Regalloc_Node_Meta;
typedef struct Slice_Of_bac_Param_Spec Slice_Of_bac_Param_Spec;
typedef struct Slice_Of_bac_Call_Conv Slice_Of_bac_Call_Conv;
typedef struct Slice_Of_bac_Regalloc_Node_Meta Slice_Of_bac_Regalloc_Node_Meta;
typedef int64_t bac_builder_Loop_Control;
typedef struct bac_Dbg_Data bac_Dbg_Data;
typedef uint8_t bac_Dbg_Location_Kind;
typedef struct bac_builder_Block_State bac_builder_Block_State;
typedef struct bac_Lib_Call bac_Lib_Call;
typedef uint8_t bac_Node_Datatype;
typedef struct bac_Stencil bac_Stencil;
typedef uint8_t bac_Lane_Type;
typedef struct bac_RM_Interner bac_RM_Interner;
typedef struct Slice_Of_bac_Dbg_Location Slice_Of_bac_Dbg_Location;
typedef struct Slice_Of_int32_t Slice_Of_int32_t;
typedef struct bac_Reloc bac_Reloc;
typedef struct bac_Basic_Block bac_Basic_Block;
typedef struct bit_arr_Bit_Set bit_arr_Bit_Set;
typedef struct bac_Proc_Meta bac_Proc_Meta;
typedef struct bac_Interner bac_Interner;
typedef struct Dyn_Arr_Of_Dyn_Arr_Of_bac_Node_ID Dyn_Arr_Of_Dyn_Arr_Of_bac_Node_ID;
typedef struct bac_Dbg_Sym bac_Dbg_Sym;
typedef struct bac_Expanded_Node bac_Expanded_Node;
typedef struct Slice_Of_Soa_Slice_Of_bac_SS_Entry_V____i64 Slice_Of_Soa_Slice_Of_bac_SS_Entry_V____i64;
typedef struct bac_Loop_Tree bac_Loop_Tree;
typedef struct Fidxe_Cap_Dyn_Arr_Of_2_bac_Node_Datatype Fidxe_Cap_Dyn_Arr_Of_2_bac_Node_Datatype;
typedef struct bac_Worklist bac_Worklist;
typedef uint8_t Bit_Set_Of_bac_Opt_Flag_8;
typedef struct bac_Node_Output bac_Node_Output;
typedef struct runtime_Allocator runtime_Allocator;
typedef struct bac_Regalloc_Output bac_Regalloc_Output;
typedef uint64_t bac_Lattice_Type;
typedef struct Dyn_Arr_Of_bac_Dbg_Data_Sym Dyn_Arr_Of_bac_Dbg_Data_Sym;
typedef struct bac_builder_If_State bac_builder_If_State;
typedef int64_t bac_Opt_Flag;
typedef struct Slice_Of_bac_Node_ID Slice_Of_bac_Node_ID;
typedef struct bac_Sym_Ref bac_Sym_Ref;
typedef struct Slice_Of_uint16_t Slice_Of_uint16_t;
typedef struct Slice_Of_Bit_Set_Of_bac_Class_Flag_8 Slice_Of_Bit_Set_Of_bac_Class_Flag_8;
typedef struct Slice_Of_Dyn_Arr_Of_int32_t Slice_Of_Dyn_Arr_Of_int32_t;
typedef struct arna_Allocator arna_Allocator;
typedef struct bac_Cfi_Op bac_Cfi_Op;
typedef struct bac_Cfi_Spec bac_Cfi_Spec;
typedef struct bac_Sloc bac_Sloc;
typedef struct bac_Efficiency_Stat bac_Efficiency_Stat;
typedef struct Slice_Of_Slice_Of_bac_Reg Slice_Of_Slice_Of_bac_Reg;
typedef struct bac_Dbg_Data_Sym bac_Dbg_Data_Sym;
typedef struct bac_builder_Loop_State bac_builder_Loop_State;
typedef struct Slice_Of_bac_Node_Output Slice_Of_bac_Node_Output;
typedef struct bac_Codegen_Spec bac_Codegen_Spec;
typedef struct runtime_Raw_Dynamic_Array runtime_Raw_Dynamic_Array;
typedef struct bac_Codegen_Emit_Ctx bac_Codegen_Emit_Ctx;
typedef struct bac_Call bac_Call;
typedef struct bac_Regalloc bac_Regalloc;
typedef struct bac_RM_Intern_Idx bac_RM_Intern_Idx;
typedef uint16_t bac_Bin_Op;
typedef struct Soa_Slice_Of_bac_SS_Entry_V____i64 Soa_Slice_Of_bac_SS_Entry_V____i64;
typedef struct Dyn_Arr_Of_bac_Basic_Block Dyn_Arr_Of_bac_Basic_Block;
typedef int64_t bac_Class_Flag;
typedef uint16_t bac_Node_Type;
typedef struct runtime_Source_Code_Location runtime_Source_Code_Location;
typedef uint16_t bac_Reg_Kind;
typedef struct Dyn_Arr_Of_bac_Node_ID Dyn_Arr_Of_bac_Node_ID;
typedef struct bac_Dbg_Data_Def bac_Dbg_Data_Def;
typedef uint32_t bac_Sym_Ref_Type;
typedef struct bac_Schedule bac_Schedule;
typedef struct Slice_Of_uintptr_t Slice_Of_uintptr_t;
typedef struct bac_builder_Param_Gen bac_builder_Param_Gen;
typedef struct runtime_Maybe_T_Node_ID runtime_Maybe_T_Node_ID;
typedef struct bac_Proc bac_Proc;
typedef struct bac_Node bac_Node;
typedef struct container_queue_Queue_T_Node_ID container_queue_Queue_T_Node_ID;
typedef struct bac_Codegen_Emit_Output bac_Codegen_Emit_Output;
typedef struct bac_Call_Conv bac_Call_Conv;
typedef uint8_t Bit_Set_Of_bac_Pass_8;
typedef struct bac_builder_Abi_Param bac_builder_Abi_Param;
typedef struct bac_Regalloc_Spec bac_Regalloc_Spec;
typedef uint16_t bac_Un_Op;
typedef struct bac_Codegen_Output_Bufs bac_Codegen_Output_Bufs;
typedef struct Slice_Of_bac_Reg Slice_Of_bac_Reg;
typedef struct bac_Reg bac_Reg;
typedef struct Slice_Of_Slice_Of_int64_t Slice_Of_Slice_Of_int64_t;
typedef uint32_t bac_Reloc_Size;
typedef uint32_t bac_Node_ID;
typedef struct Slice_Of_uint32_t Slice_Of_uint32_t;
typedef struct Slice_Of_bac_Cfi_Op Slice_Of_bac_Cfi_Op;
typedef uint8_t Bit_Set_Of_bac_Class_Flag_8;
typedef int64_t bac_Pass;
typedef bac_Lattice(*bac_Sccp_Compute_Fn)(bac_Proc *, bac_Expanded_Node);
typedef bac_Node_ID(*bac_PS_Peep_Fn)(bac_PS_Peep_Ctx, bac_Expanded_Node);
typedef runtime_Maybe_T_Node_ID(*bac_Peep_Fn)(bac_Peep_Ctx, bac_Expanded_Node);
typedef runtime_Allocator_Error(*runtime_Allocator_Proc)(void *, runtime_Allocator_Mode, int64_t, int64_t, void *, int64_t, runtime_Source_Code_Location, Slice_Of_uint8_t *);
typedef void (*bac_Pre_Regalloc_Hook)(bac_Regalloc *, bac_Proc *, bac_Schedule *);
;
struct Slice_Of_int64_t {
	int64_t *data;
	size_t len;
};
;
struct bac_Peep_Ctx {
	bac_Proc *graph;
};
struct Slice_Of_uint8_t {
	uint8_t *data;
	size_t len;
};
;
struct Slice_Of_uint32_t {
	uint32_t *data;
	size_t len;
};
;
;
struct Slice_Of_int32_t {
	int32_t *data;
	size_t len;
};
;
struct bac_Codegen_Emit_Output {
};
struct Slice_Of_uintptr_t {
	uintptr_t *data;
	size_t len;
};
;
struct Slice_Of_uint16_t {
	uint16_t *data;
	size_t len;
};
;
enum {
	bac_builder_Loop_Control_Break = 0,
	bac_builder_Loop_Control_Continue = 1,
};
enum {
	bac_Pass_Peep = 0,
	bac_Pass_Sccp = 1,
	bac_Pass_Mem = 2,
	bac_Pass_Loop = 3,
};
enum {
	bac_Reloc_Size_r32 = 0,
	bac_Reloc_Size_r26 = 1,
	bac_Reloc_Size_r19 = 2,
	bac_Reloc_Size_r2_19 = 3,
};
enum {
	bac_regalloc_Mode_with_scan = 0,
	bac_regalloc_Mode_with_coloring = 1,
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
enum {
	bac_Cfi_Kind_Def_Cfa_Offset = 0,
	bac_Cfi_Kind_Save_Reg = 1,
	bac_Cfi_Kind_Restore_Reg = 2,
	bac_Cfi_Kind_Remember_State = 3,
	bac_Cfi_Kind_Restore_State = 4,
};
enum {
	bac_Reloc_Kind_Text = 0,
	bac_Reloc_Kind_Got = 1,
	bac_Reloc_Kind_Global = 2,
};
enum {
	runtime_Allocator_Error_None = 0,
	runtime_Allocator_Error_Out_Of_Memory = 1,
	runtime_Allocator_Error_Invalid_Pointer = 2,
	runtime_Allocator_Error_Invalid_Argument = 3,
	runtime_Allocator_Error_Mode_Not_Implemented = 4,
};
struct Slice_Of_Slice_Of_int64_t {
	Slice_Of_int64_t *data;
	size_t len;
};
;
struct runtime_Source_Code_Location {
	bac_String file_path;
	int32_t line;
	int32_t column;
	bac_String procedure;
};
enum {
	bac_Class_Flag_Is_Basic_Block_Start = 0,
	bac_Class_Flag_Interned = 1,
	bac_Class_Flag_Comutes = 2,
	bac_Class_Flag_Store = 3,
	bac_Class_Flag_Load = 4,
	bac_Class_Flag_Clonable = 5,
};
struct bac_Efficiency_Stat {
	int64_t total;
	int64_t ideal;
};
struct bac_Cfg {
	uint32_t idepth;
};
enum {
	bac_Bin_Op_Gt = 37,
	bac_Bin_Op_Lt = 36,
	bac_Bin_Op_U_Lt = 39,
	bac_Bin_Op_Ge = 38,
	bac_Bin_Op_Eq = 33,
	bac_Bin_Op_Xor = 32,
	bac_Bin_Op_Le = 35,
	bac_Bin_Op_Ne = 34,
	bac_Bin_Op_U_Shr = 45,
	bac_Bin_Op_Shr = 44,
	bac_Bin_Op_Div = 47,
	bac_Bin_Op_Mul = 46,
	bac_Bin_Op_U_Le = 41,
	bac_Bin_Op_U_Gt = 40,
	bac_Bin_Op_Shl = 43,
	bac_Bin_Op_U_Ge = 42,
	bac_Bin_Op_Rem = 49,
	bac_Bin_Op_U_Div = 48,
	bac_Bin_Op_And_Not = 51,
	bac_Bin_Op_U_Rem = 50,
	bac_Bin_Op_Sub = 29,
	bac_Bin_Op_Add = 28,
	bac_Bin_Op_Or = 31,
	bac_Bin_Op_And = 30,
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
struct bac_Interner {
	uint64_t hash_idx;
	uint64_t node_idx;
	int64_t len;
	int64_t cap;
};
enum {
	bac_Opt_Flag_Sccp = 0,
	bac_Opt_Flag_Local_Peeps = 1,
	bac_Opt_Flag_Mem_Opt = 2,
	bac_Opt_Flag_Loop_Opt = 3,
	bac_Opt_Flag_Inline = 4,
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
struct bac_Lib_Call {
	uint32_t id : 31;
	uint32_t absolute : 1;
};
enum {
	bac_Dbg_Location_Kind_Register = 0,
	bac_Dbg_Location_Kind_Register_Offset = 1,
};
struct bac_Loop_Tree {
	bac_Loop_Tree *parent;
	uint32_t depth;
	bool infinite;
	bool already_always;
};
enum {
	bac_Lattice_Type_Top = 0,
	bac_Lattice_Type_Int = 1,
	bac_Lattice_Type_Float = 2,
	bac_Lattice_Type_Ctlr = 3,
	bac_Lattice_Type_Mem = 4,
	bac_Lattice_Type_Bot = 5,
};
struct bac_Dbg_Sym {
	bac_String name;
	uint64_t type;
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
struct Slice_Of_bac_Node_ID {
	bac_Node_ID *data;
	size_t len;
};
;
enum {
	bac_Un_Op_Simd_Reduce_Add_Bisect = 68,
	bac_Un_Op_Splat = 65,
	bac_Un_Op_U_Conv = 64,
	bac_Un_Op_Simd_Extract_Lsbs = 67,
	bac_Un_Op_Ctz = 66,
	bac_Un_Op_Not = 61,
	bac_Un_Op_Neg = 60,
	bac_Un_Op_Conv = 63,
	bac_Un_Op_Cast = 62,
};
enum {
	bac_Sym_Ref_Type_Func = 14,
};
struct bac_Cfi_Spec {
	uint8_t cfa_reg;
	uint8_t return_addr_reg;
	uint32_t initial_cfa_offset;
	uint32_t code_align;
	int32_t data_align;
};
struct bac_Node_Output {
	uint32_t id : 22;
	uint32_t idx : 10;
};
;
struct Fidxe_Cap_Dyn_Arr_Of_2_bac_Node_Datatype {
	bac_Node_Datatype data[2];
	uint8_t _padding[6];
	intptr_t len;
};
struct runtime_Maybe_T_Node_ID {
	union {
		bac_Node_ID variant_0;
		uint8_t _payload[4];
	};
	uint32_t tag;
};
struct bit_arr_Bit_Set {
	int64_t *masks;
	int64_t bit_length;
};
struct bac_builder_Block_State {
	bac_Node_ID end_scope;
};
;
;
struct bac_RM_Intern_Idx {
	uint16_t index : 12;
	uint16_t kind : 4;
};
struct bac_Tag {
	bac_String name[1];
	uint32_t stable_id[1];
} __attribute__((packed, aligned(4)));
struct bac_Dbg_Data_Def {
	bac_Node_ID node;
};
struct bac_Reg {
	uint16_t index : 12;
	uint16_t kind : 4;
};
struct Soa_Slice_Of_bac_SS_Entry_V____i64 {
	uint8_t *hash;
	int64_t **id;
	int64_t __len;
};
struct arna_Allocator {
	uint8_t *ptr;
	uint64_t pos;
	uint64_t commited;
	uint64_t reserved;
};
struct bac_Sloc {
	uint64_t file : 20;
	uint64_t line : 20;
	uint64_t col : 16;
	uint64_t range : 8;
} __attribute__((packed, aligned(4)));
struct Slice_Of_Soa_Slice_Of_bac_SS_Entry_V____i64 {
	struct {
		uint8_t *hash;
		int64_t **id;
		int64_t __len;
	} *data;
	size_t len;
};
;
struct bac_Proc_Meta {
	bac_Interner interner;
	int64_t weight;
	int64_t waste;
	uint32_t gvn;
	uint32_t gdn;
	uint32_t stable_id;
	uint32_t min_idepth;
	uint32_t max_idepth;
	bool has_dbg;
	struct {
		bac_Node_ID entry;
		bac_Node_ID end;
	} pinned;
	struct {
		bac_Node_ID cmem;
	} cached;
};
struct Slice_Of_bac_Sloc {
	bac_Sloc *data;
	size_t len;
};
;
struct bac_PS_Peep_Ctx {
	bac_Proc *graph;
	Slice_Of_bac_Node_ID preds;
};
struct bac_Param_Spec {
	bac_Node_Datatype dt;
	int32_t size;
};
struct bac_builder_If_State {
	bac_Node_ID if_;
	union {
		bac_Node_ID else_scope;
		bac_Node_ID then_scope;
	} branch;
};
struct Slice_Of_bac_RM_Intern_Idx {
	bac_RM_Intern_Idx *data;
	size_t len;
};
;
struct bac_Lib_Calls {
	bac_Lib_Call copy;
	bac_Lib_Call set;
};
struct Slice_Of_bac_Reg {
	bac_Reg *data;
	size_t len;
};
;
struct Slice_Of_bac_Node_Output {
	bac_Node_Output *data;
	size_t len;
};
;
struct bac_Cfi_Op {
	uint32_t offset;
	uint32_t arg;
	bac_Cfi_Kind kind;
	uint8_t reg;
};
struct Slice_Of_Bit_Set_Of_bac_Class_Flag_8 {
	uint8_t *data;
	size_t len;
};
;
struct bac_Sym_Ref {
	bac_Sym_Ref_Type type;
	uint32_t id;
	bac_Node_ID node;
};
;
struct bac_builder_Abi_Param {
	Fidxe_Cap_Dyn_Arr_Of_2_bac_Node_Datatype dt;
	int64_t size;
	int64_t real_size;
	bool spilled;
	bool scalar;
	bool copied;
};
struct bac_builder_Loop_State {
	bac_Node_ID scope;
	bac_Node_ID scopes[2];
};
struct Slice_Of_Slice_Of_bac_Reg {
	Slice_Of_bac_Reg *data;
	size_t len;
};
;
struct bac_Call {
	bac_Cfg _0;
	struct {
		uint32_t ccid : 26;
		uint32_t ret_count : 4;
		uint32_t imported : 1;
	} _1;
	uint32_t cid;
	bac_Node_Datatype rets[4];
};
struct bac_Reloc {
	uint32_t offset;
	struct {
		uint32_t kind : 2;
		uint32_t size : 2;
		uint32_t scale_pow : 2;
		uint32_t id : 26;
	} _2;
};
struct Slice_Of_bac_Cfi_Op {
	bac_Cfi_Op *data;
	size_t len;
};
;
struct Slice_Of_bac_Param_Spec {
	bac_Param_Spec *data;
	size_t len;
};
;
struct bac_Dbg_Location {
	bac_Dbg_Sym sym;
	uint32_t start;
	uint32_t end;
	uint32_t symbol;
	int32_t offset;
	bac_Reg reg;
	bac_Dbg_Location_Kind kind;
};
struct bac_Lattice {
	int64_t min;
	int64_t max;
	struct {
		uint64_t type : 4;
		uint64_t is_not_nan : 1;
		uint64_t is_not_ninf : 1;
		uint64_t is_not_pinf : 1;
		uint64_t is_not_zero : 1;
		uint64_t is_nan : 1;
		uint64_t dead : 1;
		uint64_t widens : 3;
	} meta;
};
struct bac_Stats {
	bac_Efficiency_Stat efficiency[20];
};
struct runtime_Allocator {
	runtime_Allocator_Proc procedure;
	void *data;
};
struct bac_Regalloc_Output {
	Slice_Of_bac_Reg allocs;
	bac_Reg_Kind temp_stack_slot;
};
struct Slice_Of_bac_Dbg_Location {
	bac_Dbg_Location *data;
	size_t len;
};
;
struct bac_Stencil {
	Slice_Of_uint8_t mem;
	bac_Proc_Meta meta;
};
struct bac_RM_Interner {
	Slice_Of_Soa_Slice_Of_bac_SS_Entry_V____i64 slots;
	Slice_Of_int64_t lens;
	uint32_t mask_len;
};
struct bac_Regalloc_Node_Meta {
	Slice_Of_bac_RM_Intern_Idx masks;
	Slice_Of_int64_t clobbers;
	bac_RM_Intern_Idx out;
	int8_t in_place_slot;
	uint8_t input_start;
};
struct Slice_Of_bac_Lattice {
	bac_Lattice *data;
	size_t len;
};
;
struct Slice_Of_bac_Reloc {
	bac_Reloc *data;
	size_t len;
};
;
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
			uint16_t rtype;
		} type;
		struct {
			uint16_t dt : 4;
			uint16_t is_store : 1;
			uint16_t is_load : 1;
			uint16_t mem_alignment_pow : 3;
			uint16_t lane : 3;
		} meta;
	} __attribute__((packed, aligned(4))) spec;
	struct {
		uint32_t gvn : 26;
		uint32_t scan_split : 1;
		uint32_t extra_dwords : 4;
	} gvn_group;
	uint32_t input_idx;
	uint16_t input_count;
	uint16_t input_cap;
	uint32_t output_idx;
	uint16_t output_count;
	uint16_t output_cap;
	uint32_t extra[0];
};
struct Slice_Of_bac_Regalloc_Node_Meta {
	bac_Regalloc_Node_Meta *data;
	size_t len;
};
;
struct bac_Call_Conv {
	bac_String name;
	Slice_Of_Slice_Of_bac_Reg callee_saved;
	Slice_Of_Slice_Of_bac_Reg caller_saved;
	Slice_Of_Slice_Of_bac_Reg args;
	Slice_Of_Slice_Of_bac_Reg rets;
	int32_t red_zone_size;
	bool is_syscall;
	bac_Cfi_Spec cfi_spec;
	bac_Reg stack_pointer;
};
struct bac_Codegen_Output_Bufs {
	Slice_Of_uint8_t code;
	Slice_Of_uint8_t constants;
	Slice_Of_bac_Reloc relocs;
	Slice_Of_bac_Sloc slocs;
	Slice_Of_bac_Cfi_Op cfi;
	Slice_Of_bac_Dbg_Location dbg_locs;
};
struct runtime_Raw_Dynamic_Array {
	void *data;
	int64_t len;
	int64_t cap;
	runtime_Allocator allocator;
};
struct Slice_Of_bac_Call_Conv {
	bac_Call_Conv *data;
	size_t len;
};
;
struct Dyn_Arr_Of_bac_Node_ID {
	bac_Node_ID *data;
	size_t len, cap;
	runtime_Allocator allocator;
};
;
struct bac_Expanded_Node {
	bac_Node *node;
	Slice_Of_bac_Node_ID inps;
	Slice_Of_bac_Node_Output outs;
};
struct Dyn_Arr_Of_int32_t {
	int32_t *data;
	size_t len, cap;
	runtime_Allocator allocator;
};
;
struct Dyn_Arr_Of_bac_Dbg_Data_Def {
	bac_Dbg_Data_Def *data;
	size_t len, cap;
	runtime_Allocator allocator;
};
;
struct bac_Regalloc {
	bac_Regalloc_Spec *spec;
	bac_Call_Conv *cc;
	bac_RM_Interner rms;
	Slice_Of_bac_Param_Spec param_specs;
};
struct Slice_Of_Dyn_Arr_Of_int32_t {
	Dyn_Arr_Of_int32_t *data;
	size_t len;
};
;
struct Dyn_Arr_Of_Dyn_Arr_Of_bac_Node_ID {
	Dyn_Arr_Of_bac_Node_ID *data;
	size_t len, cap;
	runtime_Allocator allocator;
};
;
struct bac_Codegen_Output {
	bac_Codegen_Emit_Output emit;
	bac_Codegen_Output_Bufs bufs;
};
struct bac_builder_Param_Gen {
	Dyn_Arr_Of_bac_Node_ID vls;
	int64_t spill_start;
};
struct bac_Dbg_Data_Sym {
	bac_Dbg_Sym inner;
	Dyn_Arr_Of_bac_Dbg_Data_Def defs;
};
struct bac_Basic_Block {
	bac_Node_ID head;
	bac_Node_ID tail;
	Dyn_Arr_Of_bac_Node_ID instrs;
	uint32_t offset;
	bac_Loop_Tree *loop_tree;
};
;
;
struct container_queue_Queue_T_Node_ID {
	Dyn_Arr_Of_bac_Node_ID data;
	uint64_t len;
	uint64_t offset;
};
;
struct Dyn_Arr_Of_bac_Basic_Block {
	bac_Basic_Block *data;
	size_t len, cap;
	runtime_Allocator allocator;
};
;
struct Dyn_Arr_Of_bac_Dbg_Data_Sym {
	bac_Dbg_Data_Sym *data;
	size_t len, cap;
	runtime_Allocator allocator;
};
;
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
;
struct bac_Codegen_Emit_Ctx {
	bac_Proc *graph;
	bac_Schedule *schedule;
	bac_Dbg_Data *dbg_data;
	bac_Call_Conv *abi;
	bac_Codegen_Emit_Buf buf;
	bool emit_got_imports;
	bac_Lib_Calls lib_calls;
	bac_Regalloc_Output ra_out;
	Slice_Of_bac_Param_Spec param_specs;
	Slice_Of_Dyn_Arr_Of_int32_t stack_param_offset;
	Slice_Of_int32_t spill_slot_base;
	Slice_Of_int32_t spill_slot_size;
	Slice_Of_uint32_t instr_offsets;
	uint64_t code_start;
	uint64_t constants_start;
	uint64_t last_off;
	bac_Sloc sloc;
};
struct bac_Regalloc_Spec {
	bac_Reg_Kind datatype_to_reg_kind[11];
	Slice_Of_int64_t spill_boundary;
	Slice_Of_bac_Call_Conv cc_table;
	Slice_Of_Slice_Of_int64_t call_clobbers;
	int64_t(*collect_meta)(bac_Proc *, bac_Regalloc *, bac_Schedule *, Slice_Of_bac_Regalloc_Node_Meta *);
};
struct bac_Codegen_Spec {
	bac_Codegen_Emit_Output(*emit_function)(bac_Codegen_Emit_Ctx);
	bac_Sccp_Compute_Fn sccp_compute;
	bac_Peep_Fn peep;
	bac_PS_Peep_Fn post_schedule_peep;
	bac_Pre_Regalloc_Hook pre_regalloc_hook;
};
struct bac_Node_Spec {
	Slice_Of_uint8_t node_extra_sizes;
	Slice_Of_uint16_t inheritance_table;
	Slice_Of_Bit_Set_Of_bac_Class_Flag_8 node_flags;
	Slice_Of_uintptr_t node_extra_types;
	uintptr_t node_kind;
	bac_Regalloc_Spec regalloc;
	bac_Codegen_Spec codegen;
};
struct bac_Proc {
	bac_Node_Spec *node_spec;
	bac_Stats *stats;
	bac_Worklist *worklist;
	Dyn_Arr_Of_Dyn_Arr_Of_bac_Node_ID *triggers;
	arna_Allocator *mem;
	bac_Sloc curret_sloc;
	bac_Proc_Meta meta;
	bool dont_intern;
	bool dont_delete;
	uint8_t computed_passes;
	uint8_t opt_flags;
	Slice_Of_bac_Lattice lattices;
};
bac_Node_ID bac_add_bin_op(bac_Proc *graph, bac_String name, bac_Bin_Op type, bac_Node_Datatype dt, bac_Node_ID lhs, bac_Node_ID rhs, bac_Lane_Type lane);
bac_Node_ID bac_add_c_int(bac_Proc *graph, bac_String name, bac_Node_Datatype dt, int64_t value);
bac_Node_ID bac_add_call(bac_Proc *graph, bac_String name, Slice_Of_bac_Node_ID inputs, bac_Call extra);
bac_Node_ID bac_add_call_end(bac_Proc *graph, bac_String name, bac_Node_ID call);
bac_Node_ID bac_add_copy(bac_Proc *graph, bac_String name, bac_Node_ID ctrl, bac_Node_ID mem, bac_Node_ID dst, bac_Node_ID src, bac_Node_ID size);
void  bac_add_efficiency_stat(bac_Stats *stats, bac_Efficiency_Stat_Kind kind, int64_t total, int64_t ideal);
bac_Node_ID bac_add_global(bac_Proc *graph, bac_String name, uint32_t idx);
bac_Node_ID bac_add_global_addr(bac_Proc *graph, bac_String name, bac_Node_ID global);
bac_Node_ID bac_add_local(bac_Proc *graph, bac_String name, bac_Node_ID mem);
bac_Node_ID bac_add_local_addr(bac_Proc *graph, bac_String name, bac_Node_ID local);
bac_Node_ID bac_add_mem(bac_Proc *graph, bac_String name, bac_Node_ID ctrl);
bac_Node_ID bac_add_proc_addr(bac_Proc *graph, bac_String name, uint32_t idx);
bac_Node_ID bac_add_ret(bac_Proc *graph, bac_String name, bac_Node_Datatype dt, bac_Node_ID call_end, uint32_t idx);
bac_Node_ID bac_add_set(bac_Proc *graph, bac_String name, bac_Node_ID ctrl, bac_Node_ID mem, bac_Node_ID dst, bac_Node_ID value, bac_Node_ID size);
bac_Node_ID bac_add_trap(bac_Proc *graph, bac_String name, Slice_Of_bac_Node_ID inputs);
bac_Node_ID bac_add_un_op(bac_Proc *graph, bac_String name, bac_Un_Op type, bac_Node_Datatype dt, bac_Node_ID oprnd, bac_Lane_Type lane);
bac_Node_ID bac_apply_peep(bac_Proc *graph, bac_Node_ID id);
bool bac_apply_peeps(bac_Peep_Ctx ctx);
void  bac_compact(bac_Proc *graph);
bool bac_compute_latices(bac_Proc *ctx, runtime_Allocator scratch);
int64_t bac_connect(bac_Proc *graph, bac_Node_ID use, bac_Node_ID def);
void  bac_delete_node_node(bac_Proc *graph, bac_Node *node);
void  bac_delete_node_node_id(bac_Proc *graph, bac_Node_ID id);
bac_Codegen_Output bac_emit_function(bac_Codegen_Emit_Ctx ctx);
bac_Expanded_Node bac_expand_node(bac_Proc *graph, bac_Node_ID id);
bool bac_find_node(bac_Proc *graph, bac_Node_Type kind, bac_Node_ID on, bac_Node_ID *ret0);
bac_Node_ID bac_find_or_create_node(bac_Proc *graph, bac_Node_Type kind);
Slice_Of_bac_Node_ID bac_get_inputs_node(bac_Proc *graph, bac_Node *node);
Slice_Of_bac_Node_ID bac_get_inputs_node_id(bac_Proc *graph, bac_Node_ID id);
bac_Node * bac_get_node(bac_Proc *graph, bac_Node_ID id);
bac_Stencil bac_get_stencil(bac_Proc *graph);
int64_t bac_get_sym_count(bac_Proc *graph, bac_Node_ID *sym);
void  bac_init_custom_fmt();
bool bac_lane_from_dt(bac_Node_Datatype ty, bac_Lane_Type *ret0);
void  bac_mount_stencil(bac_Proc *graph, bac_Stencil stencil);
void  bac_pin(bac_Proc *graph, bac_Node_ID id);
void  bac_schedule_graph(bac_Proc *graph, bac_Schedule *gs, int64_t purpose, runtime_Allocator scratch);
void  bac_schedule_peeps(bac_Proc *graph, bac_Schedule *schedule);
bac_Node_ID bac_set_input(bac_Proc *graph, bac_Node_ID id, int64_t idx, bac_Node_ID value, bool subsume_on_intern);
void  bac_set_local_size(bac_Proc *graph, bac_Node_ID loc, int32_t size);
bac_Sloc bac_sloc_scope(bac_Proc *graph, bac_Sloc sloc, bac_Proc **agraph);
bool bac_sym_iter_next(bac_Proc *graph, bac_Node_ID sym, int64_t *iter, bac_Sym_Ref *res);
void  bac_take_dbg_data(bac_Proc *graph, bac_Schedule *sched, bac_Dbg_Data *data, runtime_Allocator scratch);
void  bac_unpin(bac_Proc *graph, bac_Node_ID id, bool no_delete);
bac_Node_ID bac_builder_add_arbitrary_load(bac_Proc *ctx, bac_Node_ID cfg, bac_Node_ID mem, bac_Node_ID addr, int64_t rsize, int64_t extra_offset, bac_Node_Datatype unit);
bac_Node_ID bac_builder_add_arbitrary_store(bac_Proc *ctx, bac_Node_ID cfg, bac_Node_ID mem, bac_Node_ID addr, bac_Node_ID rvalue, int64_t rsize, int64_t extra_offset, bac_Node_Datatype unit);
bac_Node_ID bac_builder_add_call(bac_Proc *graph, Slice_Of_bac_Node_ID args, bac_Call extra, bac_Node_ID *ctrl);
bac_Node_ID bac_builder_add_field_load(bac_Proc *ctx, bac_String name, bac_Node_Datatype dt, bac_Node_ID cfg, bac_Node_ID mem, bac_Node_ID base, int64_t offset);
bac_Node_ID bac_builder_add_field_offset(bac_Proc *graph, bac_Node_ID base, int64_t offset);
bac_Node_ID bac_builder_add_field_store(bac_Proc *ctx, bac_String name, bac_Node_ID cfg, bac_Node_ID mem, bac_Node_ID base, int64_t offset, bac_Node_ID value);
bac_Node_ID bac_builder_add_scope(bac_Proc *graph, bac_String name, bac_Node_ID cfg);
Slice_Of_bac_Param_Spec bac_builder_arg_gen_finalize(bac_Proc *ctx, bac_builder_Param_Gen *gen);
bac_Node_ID bac_builder_arg_gen_next(bac_Proc *ctx, bac_Node_ID mem, bac_builder_Param_Gen *gen, bac_String name, bac_builder_Abi_Param *apa, bac_Node_ID *omem);
void  bac_builder_break_block(bac_Proc *graph, bac_Node_ID *scope, bac_builder_Block_State *state);
bac_Node_ID bac_builder_compute_index_offset(bac_Proc *ctx, bac_Node_ID base, bac_Node_ID index, int64_t stride);
void  bac_builder_decl_local(bac_Proc *graph, bac_Node_ID loc, bac_String name, uint64_t type);
void  bac_builder_delete_scope(bac_Proc *graph, bac_Node_ID scope);
void  bac_builder_end_block(bac_Proc *graph, bac_Node_ID *scope, bac_builder_Block_State *state);
void  bac_builder_end_else(bac_Proc *graph, bac_Node_ID *else_scope, bac_builder_If_State *state);
void  bac_builder_end_if(bac_Proc *graph, bac_Node_ID *then_scope, bac_builder_If_State *state);
void  bac_builder_end_loop(bac_Proc *graph, bac_Node_ID *node_scope, bac_builder_Loop_State *state);
bac_Node_ID bac_builder_get_scope_value(bac_Proc *graph, bac_Node_ID scope, int64_t idx);
bac_Node_ID bac_builder_init_graph(bac_Proc *graph);
void  bac_builder_inline_graph(bac_Proc *graph, bac_Node_ID call, bac_Proc *from);
void  bac_builder_inline_stencil(bac_Proc *graph, bac_Node_ID call, bac_Stencil from);
void  bac_builder_loop_control(bac_builder_Loop_Control variant, bac_Proc *ctx, bac_Node_ID scope, bac_builder_Loop_State *loop);
bool bac_builder_loopopt(bac_Proc *graph);
bool bac_builder_memopt(bac_Proc *graph);
bac_Node_ID bac_builder_merge_returns(bac_Proc *graph, Slice_Of_bac_Node_ID args);
int64_t bac_builder_push_scope_value(bac_Proc *graph, bac_Node_ID scope, bac_Node_ID value, bac_String name, uint64_t type);
void  bac_builder_set_scope_value(bac_Proc *graph, bac_Node_ID scope, int64_t idx, bac_Node_ID value);
void  bac_builder_start_block(bac_builder_Block_State *state);
void  bac_builder_start_else(bac_Proc *graph, bac_Node_ID *then_scope, bac_builder_If_State *state);
void  bac_builder_start_if(bac_Proc *graph, bac_Node_ID scope, bac_builder_If_State *state, bac_Node_ID cond);
void  bac_builder_start_loop(bac_Proc *graph, bac_Node_ID scope, bac_builder_Loop_State *state);
void  bac_builder_start_loop_increment(bac_Proc *graph, bac_Node_ID *node_scope, bac_builder_Loop_State *state);
void  bac_builder_truncate_scope(bac_Proc *graph, bac_Node_ID scope, int64_t to_len);
bac_Regalloc_Output bac_regalloc_regalloc(bac_Regalloc *ra, bac_Proc *graph, bac_Schedule *sched, bac_regalloc_Mode mode, runtime_Allocator scratch);
