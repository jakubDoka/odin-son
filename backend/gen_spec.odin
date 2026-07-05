
package backend

GEN_SPEC :: #config(GEN_SPEC, false)

COMMAND :: "odin run backend -define:GEN_SPEC=true"

SIMPLE_BINOP_CLASS :: Class_Spec {
	args  = {"lhs", "rhs"},
	group = "Bin_Op",
	flags = {.Comutes, .Interned},
}

@(rodata)
IDEAL_CLASSES := [Ideal_Node_Type]Class_Spec {
	.Start = {id = Cfg, default_type = .Void},
	.Entry = {
		id = Cfg,
		args = {"start"},
		flags = {.Is_Basic_Block_Start},
		default_type = .Void,
	},
	.Poison = {default_type = .Void, flags = {.Interned}},
	// TODO: maybe its better to introduce a flag: Schedule_Early
	.Arg = {id = Tup, args = {"entry"}, extra_args = {"idx"}},
	.CInt = {
		id = CInt,
		extra_args = {"value"},
		flags = {.Interned, .Clonable},
	},
	.Add = SIMPLE_BINOP_CLASS,
	.Sub = {args = {"lhs", "rhs"}, group = "Bin_Op", flags = {.Interned}},
	.Mul = SIMPLE_BINOP_CLASS,
	.Eq = SIMPLE_BINOP_CLASS,
	.Ne = SIMPLE_BINOP_CLASS,
	.Le = {args = {"lhs", "rhs"}, group = "Bin_Op", flags = {.Interned}},
	.Lt = {args = {"lhs", "rhs"}, group = "Bin_Op", flags = {.Interned}},
	.Gt = {args = {"lhs", "rhs"}, group = "Bin_Op", flags = {.Interned}},
	.Ge = {args = {"lhs", "rhs"}, group = "Bin_Op", flags = {.Interned}},
	.Div = {args = {"lhs", "rhs"}, group = "Bin_Op", flags = {.Interned}},
	.Rem = {args = {"lhs", "rhs"}, group = "Bin_Op", flags = {.Interned}},
	.And = SIMPLE_BINOP_CLASS,
	.Or = SIMPLE_BINOP_CLASS,
	.Xor = SIMPLE_BINOP_CLASS,
	.And_Not = {args = {"lhs", "rhs"}, group = "Bin_Op", flags = {.Interned}},
	.Neg = {args = {"oprnd"}, group = "Un_Op", flags = {.Interned}},
	.Not = {args = {"oprnd"}, group = "Un_Op", flags = {.Interned}},
	.Sext = {args = {"oprnd"}, group = "Un_Op", flags = {.Interned}},
	.Uext = {args = {"oprnd"}, group = "Un_Op", flags = {.Interned}},
	.Cast = {args = {"oprnd"}, group = "Un_Op", flags = {.Interned}},
	.Shl = {args = {"lhs", "rhs"}, group = "Bin_Op", flags = {.Interned}},
	.Shr = {args = {"lhs", "rhs"}, group = "Bin_Op", flags = {.Interned}},
	.U_Lt = {args = {"lhs", "rhs"}, group = "Bin_Op", flags = {.Interned}},
	.U_Gt = {args = {"lhs", "rhs"}, group = "Bin_Op", flags = {.Interned}},
	.U_Le = {args = {"lhs", "rhs"}, group = "Bin_Op", flags = {.Interned}},
	.U_Ge = {args = {"lhs", "rhs"}, group = "Bin_Op", flags = {.Interned}},
	.U_Div = {args = {"lhs", "rhs"}, group = "Bin_Op", flags = {.Interned}},
	.U_Rem = {args = {"lhs", "rhs"}, group = "Bin_Op", flags = {.Interned}},
	.U_Shr = {args = {"lhs", "rhs"}, group = "Bin_Op", flags = {.Interned}},
	.Mem = {args = {"ctrl"}, default_type = .Void, flags = {.Store}},
	.Local = {id = Local, args = {"mem"}, default_type = .Void},
	.Local_Addr = {args = {"local"}, default_type = .I64, flags = {.Clonable}},
	.Global = {id = Tup, default_type = .Void},
	.Global_Addr = {
		args = {"global"},
		default_type = .I64,
		flags = {.Clonable, .Interned},
	},
	.Load = {
		id = Mem_Op,
		args = {"ctrl", "mem", "addr"},
		flags = {.Interned, .Load},
	},
	.Load_S = {
		id = Mem_Op,
		args = {"ctrl", "mem", "addr"},
		flags = {.Interned, .Load},
	},
	.Store = {
		id = Mem_Op,
		args = {"ctrl", "mem", "addr", "value"},
		default_type = .Void,
		flags = {.Store},
	},
	.Copy = {
		id = Mem_Op,
		args = {"ctrl", "mem", "dst", "src", "size"},
		default_type = .Void,
		flags = {.Store},
	},
	.Set = {
		id = Mem_Op,
		args = {"ctrl", "mem", "dst", "value", "size"},
		default_type = .Void,
		flags = {.Store},
	},
	.Split = {args = {"dest"}},
	.Phi = {args = {"reg", "lhs", "rhs"}, flags = {.Interned}},
	.If = {id = Cfg, args = {"ctrl", "cond"}, default_type = .Void},
	.Then = {
		id = Cfg,
		args = {"ctrl"},
		default_type = .Void,
		flags = {.Is_Basic_Block_Start},
	},
	.Else = {
		id = Cfg,
		args = {"ctrl"},
		default_type = .Void,
		flags = {.Is_Basic_Block_Start},
	},
	.Jump = {id = Cfg, args = {"ctrl"}, default_type = .Void},
	.Region = {
		id = Region,
		varargs = true,
		default_type = .Void,
		flags = {.Is_Basic_Block_Start},
	},
	.Loop = {
		id = Cfg,
		args = {"ctrl"},
		default_type = .Void,
		flags = {.Is_Basic_Block_Start},
		extra_capacity = 1,
	},
	.Always = {id = Cfg, args = {"ctrl"}, default_type = .Void},
	.Call = {
		id = Call,
		varargs = true,
		default_type = .Void,
		extra_args = {"cid"},
	},
	.Call_End = {
		id = Cfg,
		args = {"call"},
		flags = {.Is_Basic_Block_Start},
		default_type = .Void,
	},
	.Ret = {id = Tup, args = {"call_end"}, extra_args = {"idx"}},
	.Return = {
		id = Cfg,
		varargs = true,
		default_type = .Void,
		flags = {.Immortal},
	},
}

@(rodata)
IDEAL_REG_CLASSES := [Ideal_Node_Type]Reg_Class_Spec{}

@(rodata)
BUILDER_REG_CLASSES := [Builder_Node_Type]Reg_Class_Spec{}

Inherit_Table_Elem :: u16
Mask_Intern_Key :: u8

Class_Array :: struct {
	enm:  typeid,
	ids:  []Class_Spec,
	regs: []Reg_Class_Spec,
}

Peep_Fn :: proc(_: Peep_Ctx, _: Expanded_Node) -> Node_ID

Class_Spec :: struct {
	id:             typeid,
	args:           []string,
	extra_args:     []string,
	group:          string,
	varargs:        bool,
	default_type:   Maybe(Node_Datatype),
	flags:          Class_Flags,
	extra_capacity: int,
	no_ctor:        bool,
}

Reg_Class_Spec :: struct {
	inplace_slot_idx: Maybe(int),
	input_start_idx:  int,
	clobbers:         [Reg_Kind]int,
	reg_masks:        [Reg_Kind][][]int,
}

SPEC_NOT_PRESENT :: (#load("node_specs.odin", string) or_else "") == ""

when SPEC_NOT_PRESENT {
	@(rodata)
	SPECS := [Node_Spec_Name]Node_Spec{}

	Builder_Node_Type :: enum u16 {
		Scope,
		Lazy_Phi,
		Dead,
	}

	@(rodata)
	BUILDER_CLASSES := [Builder_Node_Type]Class_Spec {
		.Scope = {id = Scope, args = {"cfg"}, default_type = .Void},
		.Lazy_Phi = {args = {"reg", "lhs"}, extra_capacity = 1},
		.Dead = {default_type = .Void},
	}

	inherit_idx_of :: proc($T: typeid) -> u8 {return 0}

	graph_add_split :: proc(
		graph: ^Graph,
		name: string,
		dt: Node_Datatype,
		src: Node_ID,
	) -> Node_ID {return 0}

	graph_add_phi :: proc(
		graph: ^Graph,
		name: string,
		dt: Node_Datatype,
		region: Node_ID,
		lhs: Node_ID,
		rhs: Node_ID,
	) -> Node_ID {return 0}

	graph_add_lazy_phi :: proc(
		graph: ^Graph,
		name: string,
		dt: Node_Datatype,
		region: Node_ID,
		lhs: Node_ID,
	) -> Node_ID {return 0}

	graph_add_return :: proc(
		graph: ^Graph,
		name: string,
		inputs: []Node_ID,
	) -> Node_ID {return 0}

	graph_add_region :: proc(
		graph: ^Graph,
		name: string,
		ctrls: []Node_ID,
	) -> Node_ID {return 0}
	graph_add_if :: proc(
		graph: ^Graph,
		name: string,
		ctrl: Node_ID,
		cond: Node_ID,
	) -> Node_ID {return 0}

	graph_add_jump :: proc(
		graph: ^Graph,
		name: string,
		ctrl: Node_ID,
	) -> Node_ID {return 0}
	graph_add_loop :: graph_add_jump
	graph_add_always :: graph_add_jump
	graph_add_then :: graph_add_jump
	graph_add_else :: graph_add_jump

	graph_add_poison :: proc(graph: ^Graph, name: string) -> Node_ID {return 0}

	when !GEN_SPEC {
		#panic("Missing generated files, run `" + COMMAND + "`")
	}
} else {
	@(rodata)
	BUILDER_CLASSES := [Builder_Node_Type]Class_Spec{}
	@(rodata)
	X64_CLASSES := [X64_Node_Type]Class_Spec{}
}

when GEN_SPEC {
	main :: proc() {
		generate_specs()
	}
}
