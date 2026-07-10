package main

// AST node definitions. Like token kinds, node kinds are integer constants.
//
// Nodes live in a growable arena and reference each other by u32 INDEX rather
// than by pointer, so the arena is free to move during a reallocation. Index 0
// is reserved as the "null" node (allocated once up front), so a child slot of
// 0 means "absent". Variable length child lists (block statements, call
// arguments, expression lists, table fields, ...) are threaded through the
// `next` field as a singly linked sibling list; the parent points at the first
// element in one of its `a`/`b`/`c`/`d` slots.

Node :: struct {
	kind:   int, // one of the NK_* constants
	op:     int, // operator token kind for NK_BINOP / NK_UNOP
	start:  int, // source offset of the associated lexeme (names/literals)
	length: int, // lexeme length
	ival:   i64, // integer value for NK_NUMBER
	a:      u32, // child slot 1
	b:      u32, // child slot 2
	c:      u32, // child slot 3
	d:      u32, // child slot 4
	next:   u32, // next sibling in a list (0 = none)
}

Node_Ptr :: ^Node

// --- node kinds -----------------------------------------------------------

// expressions
NK_NIL :: 1
NK_TRUE :: 2
NK_FALSE :: 3
NK_NUMBER :: 4 // ival / lexeme
NK_STRING :: 5 // lexeme (without quotes)
NK_NAME :: 6 // lexeme
NK_VARARG :: 7 // ...
NK_BINOP :: 8 // op, a=lhs, b=rhs
NK_UNOP :: 9 // op, a=operand
NK_INDEX :: 10 // a=obj, b=key expr        t[k]
NK_FIELD :: 11 // a=obj, lexeme=field       t.k
NK_CALL :: 12 // a=fn, b=first arg
NK_METHODCALL :: 13 // a=obj, lexeme=method, b=first arg   t:m(...)
NK_TABLE :: 14 // a=first field entry
NK_FIELD_ENTRY :: 15 // a=key(0 for array style), b=value
NK_FUNC :: 16 // a=first param, b=block, ival=1 if vararg

// statements
NK_BLOCK :: 30 // a=first stmt
NK_LOCAL :: 31 // a=first name, b=first expr
NK_ASSIGN :: 32 // a=first target, b=first value
NK_CALLSTAT :: 33 // a=call/methodcall expr
NK_IF :: 34 // a=cond, b=then block, c=else block or nested NK_IF
NK_WHILE :: 35 // a=cond, b=block
NK_NUMFOR :: 36 // lexeme=var, a=start, b=limit, c=step(0=none), d=block
NK_GENFOR :: 37 // a=first name, b=first expr, c=block
NK_REPEAT :: 38 // a=block, b=cond
NK_DO :: 39 // a=block
NK_RETURN :: 40 // a=first expr (may be 0)
NK_BREAK :: 41
NK_FUNCSTAT :: 42 // a=target expr (name/field), b=func literal, ival=1 if method

// node_stride is the byte size of a Node, measured at runtime. Set by
// strides_init before any parsing.
node_stride: int

// node_at returns a pointer to node `i` stored in arena `a`.
node_at :: proc(a: ^Arena, i: u32) -> Node_Ptr {
	return Node_Ptr(arena_ptr(a, int(i) * node_stride))
}

// node_new allocates a zeroed node of the given kind and returns its index.
node_new :: proc(a: ^Arena, kind: int) -> u32 {
	off := arena_alloc(a, node_stride, 8)
	idx := u32(off / node_stride)
	p := node_at(a, idx)
	p.kind = kind
	p.op = 0
	p.start = 0
	p.length = 0
	p.ival = 0
	p.a = 0
	p.b = 0
	p.c = 0
	p.d = 0
	p.next = 0
	return idx
}

// strides_init measures the runtime byte size of Node and Token. Must be called
// once before any lexing or parsing, because the JIT does not support size_of.
strides_init :: proc() {
	ns: [2]Node = {}
	node_stride = int(uintptr(&ns[1]) - uintptr(&ns[0]))
	ts: [2]Token = {}
	token_stride = int(uintptr(&ts[1]) - uintptr(&ts[0]))
}

// node_name returns a short label for a node kind, used by the AST pretty
// printer.
node_name :: proc(kind: int) -> string {
	if kind == NK_NIL do return "nil"
	if kind == NK_TRUE do return "true"
	if kind == NK_FALSE do return "false"
	if kind == NK_NUMBER do return "number"
	if kind == NK_STRING do return "string"
	if kind == NK_NAME do return "name"
	if kind == NK_VARARG do return "vararg"
	if kind == NK_BINOP do return "binop"
	if kind == NK_UNOP do return "unop"
	if kind == NK_INDEX do return "index"
	if kind == NK_FIELD do return "field"
	if kind == NK_CALL do return "call"
	if kind == NK_METHODCALL do return "methodcall"
	if kind == NK_TABLE do return "table"
	if kind == NK_FIELD_ENTRY do return "entry"
	if kind == NK_FUNC do return "function"
	if kind == NK_BLOCK do return "block"
	if kind == NK_LOCAL do return "local"
	if kind == NK_ASSIGN do return "assign"
	if kind == NK_CALLSTAT do return "callstat"
	if kind == NK_IF do return "if"
	if kind == NK_WHILE do return "while"
	if kind == NK_NUMFOR do return "numfor"
	if kind == NK_GENFOR do return "genfor"
	if kind == NK_REPEAT do return "repeat"
	if kind == NK_DO do return "do"
	if kind == NK_RETURN do return "return"
	if kind == NK_BREAK do return "break"
	if kind == NK_FUNCSTAT do return "funcstat"
	return "?"
}
