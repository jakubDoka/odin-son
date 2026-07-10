package main

// The Lua parser. It consumes the token stream produced by the lexer and builds
// an AST in a growable node arena (see ast.odin), returning the index of the
// root NK_BLOCK node. `print_ast` walks the tree and pretty prints it.
//
// NOTE: the bodies of `parse_chunk` and `print_ast` are implemented by the
// PARSER AGENT; the struct and constructor are defined here.

Parser :: struct {
	src:        string, // source text (for lexeme printing)
	toks:       ^Arena, // token pool owned by the lexer
	count:      int, // number of tokens
	pos:        int, // current token index
	nodes:      Arena, // node pool
	root:       u32, // root block node index
	node_count: int, // number of nodes allocated (set at end of parse_chunk)
	ok:         bool, // false if a syntax error was seen
}

// parser_init prepares a parser over the tokens a lexer already produced.
parser_init :: proc(p: ^Parser, l: ^Lexer) {
	p.src = l.src
	p.toks = &l.toks
	p.count = l.count
	p.pos = 0
	p.root = 0
	p.node_count = 0
	p.ok = true
	arena_init(&p.nodes, 256 * 1024)
	// Reserve index 0 as the null node so a child slot of 0 means "absent".
	_ = node_new(&p.nodes, NK_NIL)
}

// UNARY_PRIORITY is the binding power on the operand of a unary operator. It
// sits between the multiplicative operators (7) and `^` (10) so that `-x^2`
// parses as `-(x^2)` while `-x*y` parses as `(-x)*y`.
UNARY_PRIORITY :: 8

// --- token helpers ---------------------------------------------------------

// p_kind returns the kind of the current token (TK_EOF past the end).
p_kind :: proc(p: ^Parser) -> int {
	if p.pos >= p.count do return TK_EOF
	return tok_at(p.toks, p.pos).kind
}

// p_advance moves to the next token, clamping at the final EOF token.
p_advance :: proc(p: ^Parser) {
	if p.pos < p.count - 1 {
		p.pos += 1
	}
}

// p_expect consumes the current token if it has the given kind, otherwise flags
// a syntax error.
p_expect :: proc(p: ^Parser, kind: int) -> bool {
	if p_kind(p) == kind {
		p_advance(p)
		return true
	}
	p.ok = false
	return false
}

// is_block_end reports whether token kind `k` terminates a block.
is_block_end :: proc(k: int) -> bool {
	if k == TK_END do return true
	if k == TK_ELSE do return true
	if k == TK_ELSEIF do return true
	if k == TK_UNTIL do return true
	if k == TK_EOF do return true
	return false
}

// list_append threads `node` onto the singly linked sibling list whose head and
// tail indices are held in `first`/`last`.
list_append :: proc(p: ^Parser, first: ^u32, last: ^u32, node: u32) {
	if first^ == 0 {
		first^ = node
		last^ = node
	} else {
		node_at(&p.nodes, last^).next = node
		last^ = node
	}
}

// leaf_cur allocates a leaf node of `kind` capturing the current token's lexeme
// and integer value, then advances past that token.
leaf_cur :: proc(p: ^Parser, kind: int) -> u32 {
	t := tok_at(p.toks, p.pos)
	start := t.start
	length := t.length
	ival := t.ival
	idx := node_new(&p.nodes, kind)
	n := node_at(&p.nodes, idx)
	n.start = start
	n.length = length
	n.ival = ival
	p_advance(p)
	return idx
}

// --- operator precedence ---------------------------------------------------

// binop_lprec returns the left binding power of a binary operator, or 0 when
// `op` is not a binary operator.
binop_lprec :: proc(op: int) -> int {
	if op == TK_OR do return 1
	if op == TK_AND do return 2
	if op == TK_LT do return 3
	if op == TK_GT do return 3
	if op == TK_LE do return 3
	if op == TK_GE do return 3
	if op == TK_NE do return 3
	if op == TK_EQ do return 3
	if op == TK_CONCAT do return 5
	if op == TK_PLUS do return 6
	if op == TK_MINUS do return 6
	if op == TK_STAR do return 7
	if op == TK_SLASH do return 7
	if op == TK_PERCENT do return 7
	if op == TK_CARET do return 10
	return 0
}

// binop_rprec returns the right binding power; `..` and `^` are right
// associative so their right power is one below their left power.
binop_rprec :: proc(op: int) -> int {
	if op == TK_CONCAT do return 4
	if op == TK_CARET do return 9
	return binop_lprec(op)
}

// --- expression parsing ----------------------------------------------------

// parse_expr parses a full expression.
parse_expr :: proc(p: ^Parser) -> u32 {
	return parse_subexpr(p, 0)
}

// parse_subexpr parses an expression using precedence climbing, only accepting
// binary operators whose left binding power exceeds `limit`.
parse_subexpr :: proc(p: ^Parser, limit: int) -> u32 {
	left: u32 = 0
	k := p_kind(p)
	if (k == TK_NOT) | (k == TK_HASH) | (k == TK_MINUS) {
		op := k
		p_advance(p)
		operand := parse_subexpr(p, UNARY_PRIORITY)
		idx := node_new(&p.nodes, NK_UNOP)
		n := node_at(&p.nodes, idx)
		n.op = op
		n.a = operand
		left = idx
	} else {
		left = parse_simple(p)
	}
	if left == 0 do return 0

	for {
		op := p_kind(p)
		lp := binop_lprec(op)
		if lp == 0 do break
		if lp <= limit do break
		p_advance(p)
		right := parse_subexpr(p, binop_rprec(op))
		if right == 0 {
			p.ok = false
			break
		}
		idx := node_new(&p.nodes, NK_BINOP)
		n := node_at(&p.nodes, idx)
		n.op = op
		n.a = left
		n.b = right
		left = idx
	}
	return left
}

// parse_simple parses a simple expression: a literal, vararg, table or function
// constructor, or a prefix expression with suffixes.
parse_simple :: proc(p: ^Parser) -> u32 {
	k := p_kind(p)
	if k == TK_NIL do return leaf_cur(p, NK_NIL)
	if k == TK_TRUE do return leaf_cur(p, NK_TRUE)
	if k == TK_FALSE do return leaf_cur(p, NK_FALSE)
	if k == TK_NUMBER do return leaf_cur(p, NK_NUMBER)
	if k == TK_STRING do return leaf_cur(p, NK_STRING)
	if k == TK_ELLIPSIS do return leaf_cur(p, NK_VARARG)
	if k == TK_LBRACE do return parse_table(p)
	if k == TK_FUNCTION {
		p_advance(p)
		return parse_func_body(p)
	}
	return parse_suffixed(p)
}

// parse_suffixed parses a prefix expression (a name or a parenthesized
// expression) followed by any number of field/index/call/method suffixes.
parse_suffixed :: proc(p: ^Parser) -> u32 {
	base: u32 = 0
	k := p_kind(p)
	if k == TK_NAME {
		base = leaf_cur(p, NK_NAME)
	} else if k == TK_LPAREN {
		p_advance(p)
		base = parse_expr(p)
		p_expect(p, TK_RPAREN)
	} else {
		p.ok = false
		return 0
	}
	if base == 0 do return 0

	for {
		kk := p_kind(p)
		if kk == TK_DOT {
			p_advance(p)
			if p_kind(p) != TK_NAME {
				p.ok = false
				break
			}
			t := tok_at(p.toks, p.pos)
			fs := t.start
			fl := t.length
			p_advance(p)
			idx := node_new(&p.nodes, NK_FIELD)
			n := node_at(&p.nodes, idx)
			n.a = base
			n.start = fs
			n.length = fl
			base = idx
			continue
		}
		if kk == TK_LBRACKET {
			p_advance(p)
			key := parse_expr(p)
			p_expect(p, TK_RBRACKET)
			idx := node_new(&p.nodes, NK_INDEX)
			n := node_at(&p.nodes, idx)
			n.a = base
			n.b = key
			base = idx
			continue
		}
		if (kk == TK_LPAREN) | (kk == TK_STRING) | (kk == TK_LBRACE) {
			args := parse_args(p)
			idx := node_new(&p.nodes, NK_CALL)
			n := node_at(&p.nodes, idx)
			n.a = base
			n.b = args
			base = idx
			continue
		}
		if kk == TK_COLON {
			p_advance(p)
			if p_kind(p) != TK_NAME {
				p.ok = false
				break
			}
			t := tok_at(p.toks, p.pos)
			ms := t.start
			ml := t.length
			p_advance(p)
			args := parse_args(p)
			idx := node_new(&p.nodes, NK_METHODCALL)
			n := node_at(&p.nodes, idx)
			n.a = base
			n.start = ms
			n.length = ml
			n.b = args
			base = idx
			continue
		}
		break
	}
	return base
}

// parse_args parses a call argument list, returning the first argument index (0
// when empty). Accepts `(exprlist)`, a single string, or a single table.
parse_args :: proc(p: ^Parser) -> u32 {
	k := p_kind(p)
	if k == TK_STRING do return leaf_cur(p, NK_STRING)
	if k == TK_LBRACE do return parse_table(p)
	p_expect(p, TK_LPAREN)
	if p_kind(p) == TK_RPAREN {
		p_advance(p)
		return 0
	}
	first := parse_exprlist(p)
	p_expect(p, TK_RPAREN)
	return first
}

// parse_exprlist parses one or more comma separated expressions and returns the
// first, chained via `next`.
parse_exprlist :: proc(p: ^Parser) -> u32 {
	first: u32 = 0
	last: u32 = 0
	for {
		e := parse_expr(p)
		if e == 0 {
			p.ok = false
			break
		}
		list_append(p, &first, &last, e)
		if p_kind(p) == TK_COMMA {
			p_advance(p)
			continue
		}
		break
	}
	return first
}

// parse_table parses a `{ ... }` table constructor into an NK_TABLE holding
// NK_FIELD_ENTRY children.
parse_table :: proc(p: ^Parser) -> u32 {
	p_expect(p, TK_LBRACE)
	idx := node_new(&p.nodes, NK_TABLE)
	first: u32 = 0
	last: u32 = 0
	for {
		if p_kind(p) == TK_RBRACE do break
		entry := parse_field(p)
		if entry == 0 {
			p.ok = false
			break
		}
		list_append(p, &first, &last, entry)
		k := p_kind(p)
		if (k == TK_COMMA) | (k == TK_SEMI) {
			p_advance(p)
			continue
		}
		break
	}
	p_expect(p, TK_RBRACE)
	n := node_at(&p.nodes, idx)
	n.a = first
	return idx
}

// parse_field parses a single table field: `[key] = value`, `Name = value`, or
// a positional `value`.
parse_field :: proc(p: ^Parser) -> u32 {
	k := p_kind(p)
	if k == TK_LBRACKET {
		p_advance(p)
		key := parse_expr(p)
		p_expect(p, TK_RBRACKET)
		p_expect(p, TK_ASSIGN)
		val := parse_expr(p)
		idx := node_new(&p.nodes, NK_FIELD_ENTRY)
		n := node_at(&p.nodes, idx)
		n.a = key
		n.b = val
		return idx
	}
	if k == TK_NAME {
		if p.pos + 1 < p.count {
			nk := tok_at(p.toks, p.pos + 1).kind
			if nk == TK_ASSIGN {
				key := leaf_cur(p, NK_NAME)
				p_expect(p, TK_ASSIGN)
				val := parse_expr(p)
				idx := node_new(&p.nodes, NK_FIELD_ENTRY)
				n := node_at(&p.nodes, idx)
				n.a = key
				n.b = val
				return idx
			}
		}
	}
	val := parse_expr(p)
	if val == 0 do return 0
	idx := node_new(&p.nodes, NK_FIELD_ENTRY)
	n := node_at(&p.nodes, idx)
	n.a = 0
	n.b = val
	return idx
}

// --- function bodies -------------------------------------------------------

// parse_func_body parses `( params ) block end` starting on the opening paren
// and returns an NK_FUNC node.
parse_func_body :: proc(p: ^Parser) -> u32 {
	p_expect(p, TK_LPAREN)
	pfirst: u32 = 0
	plast: u32 = 0
	vararg := false
	if p_kind(p) != TK_RPAREN {
		for {
			if p_kind(p) == TK_ELLIPSIS {
				p_advance(p)
				vararg = true
				break
			}
			if p_kind(p) != TK_NAME {
				p.ok = false
				break
			}
			pn := leaf_cur(p, NK_NAME)
			list_append(p, &pfirst, &plast, pn)
			if p_kind(p) == TK_COMMA {
				p_advance(p)
				continue
			}
			break
		}
	}
	p_expect(p, TK_RPAREN)
	body := parse_block(p)
	p_expect(p, TK_END)
	idx := node_new(&p.nodes, NK_FUNC)
	n := node_at(&p.nodes, idx)
	n.a = pfirst
	n.b = body
	if vararg do n.ival = 1
	return idx
}

// --- statements ------------------------------------------------------------

// parse_block parses statements until a block terminator and returns an
// NK_BLOCK node whose `a` slot heads the statement list.
parse_block :: proc(p: ^Parser) -> u32 {
	idx := node_new(&p.nodes, NK_BLOCK)
	first: u32 = 0
	last: u32 = 0
	for {
		k := p_kind(p)
		if is_block_end(k) do break
		if k == TK_SEMI {
			p_advance(p)
			continue
		}
		start := p.pos
		st := parse_statement(p)
		if st == 0 {
			p.ok = false
			// guarantee progress so the loop always terminates
			if p.pos == start do p_advance(p)
			break
		}
		list_append(p, &first, &last, st)
		if p.pos == start {
			p.ok = false
			break
		}
	}
	n := node_at(&p.nodes, idx)
	n.a = first
	return idx
}

// parse_statement dispatches on the leading token to the matching statement
// parser.
parse_statement :: proc(p: ^Parser) -> u32 {
	k := p_kind(p)
	if k == TK_LOCAL do return parse_local(p)
	if k == TK_IF do return parse_if(p)
	if k == TK_WHILE do return parse_while(p)
	if k == TK_FOR do return parse_for(p)
	if k == TK_REPEAT do return parse_repeat(p)
	if k == TK_DO do return parse_do(p)
	if k == TK_FUNCTION do return parse_funcstat(p)
	if k == TK_RETURN do return parse_return(p)
	if k == TK_BREAK {
		p_advance(p)
		return node_new(&p.nodes, NK_BREAK)
	}
	return parse_expr_statement(p)
}

// parse_local parses `local namelist [= exprlist]` and `local function ...`.
parse_local :: proc(p: ^Parser) -> u32 {
	p_advance(p) // local
	if p_kind(p) == TK_FUNCTION {
		p_advance(p) // function
		if p_kind(p) != TK_NAME {
			p.ok = false
			return 0
		}
		name := leaf_cur(p, NK_NAME)
		func := parse_func_body(p)
		idx := node_new(&p.nodes, NK_LOCAL)
		n := node_at(&p.nodes, idx)
		n.a = name
		n.b = func
		return idx
	}
	first: u32 = 0
	last: u32 = 0
	for {
		if p_kind(p) != TK_NAME {
			p.ok = false
			break
		}
		nm := leaf_cur(p, NK_NAME)
		list_append(p, &first, &last, nm)
		if p_kind(p) == TK_COMMA {
			p_advance(p)
			continue
		}
		break
	}
	vals: u32 = 0
	if p_kind(p) == TK_ASSIGN {
		p_advance(p)
		vals = parse_exprlist(p)
	}
	idx := node_new(&p.nodes, NK_LOCAL)
	n := node_at(&p.nodes, idx)
	n.a = first
	n.b = vals
	return idx
}

// parse_if consumes the leading `if` and parses the whole if/elseif/else chain.
parse_if :: proc(p: ^Parser) -> u32 {
	p_advance(p) // if
	return parse_if_rest(p)
}

// parse_if_rest parses `cond then block <continuation>` after the leading
// `if`/`elseif` keyword has been consumed. Exactly one `end` closes the chain.
parse_if_rest :: proc(p: ^Parser) -> u32 {
	cond := parse_expr(p)
	p_expect(p, TK_THEN)
	thenb := parse_block(p)
	elsec: u32 = 0
	k := p_kind(p)
	if k == TK_ELSEIF {
		p_advance(p)
		elsec = parse_if_rest(p)
	} else if k == TK_ELSE {
		p_advance(p)
		elsec = parse_block(p)
		p_expect(p, TK_END)
	} else {
		p_expect(p, TK_END)
	}
	idx := node_new(&p.nodes, NK_IF)
	n := node_at(&p.nodes, idx)
	n.a = cond
	n.b = thenb
	n.c = elsec
	return idx
}

// parse_while parses `while exp do block end`.
parse_while :: proc(p: ^Parser) -> u32 {
	p_advance(p) // while
	cond := parse_expr(p)
	p_expect(p, TK_DO)
	body := parse_block(p)
	p_expect(p, TK_END)
	idx := node_new(&p.nodes, NK_WHILE)
	n := node_at(&p.nodes, idx)
	n.a = cond
	n.b = body
	return idx
}

// parse_for parses both the numeric and generic `for` forms.
parse_for :: proc(p: ^Parser) -> u32 {
	p_advance(p) // for
	if p_kind(p) != TK_NAME {
		p.ok = false
		return 0
	}
	t := tok_at(p.toks, p.pos)
	name_start := t.start
	name_len := t.length
	nextk := TK_EOF
	if p.pos + 1 < p.count {
		nextk = tok_at(p.toks, p.pos + 1).kind
	}
	if nextk == TK_ASSIGN {
		// numeric for
		p_advance(p) // name
		p_advance(p) // =
		starte := parse_expr(p)
		p_expect(p, TK_COMMA)
		limite := parse_expr(p)
		stepe: u32 = 0
		if p_kind(p) == TK_COMMA {
			p_advance(p)
			stepe = parse_expr(p)
		}
		p_expect(p, TK_DO)
		body := parse_block(p)
		p_expect(p, TK_END)
		idx := node_new(&p.nodes, NK_NUMFOR)
		n := node_at(&p.nodes, idx)
		n.start = name_start
		n.length = name_len
		n.a = starte
		n.b = limite
		n.c = stepe
		n.d = body
		return idx
	}
	// generic for
	first: u32 = 0
	last: u32 = 0
	for {
		if p_kind(p) != TK_NAME {
			p.ok = false
			break
		}
		nm := leaf_cur(p, NK_NAME)
		list_append(p, &first, &last, nm)
		if p_kind(p) == TK_COMMA {
			p_advance(p)
			continue
		}
		break
	}
	p_expect(p, TK_IN)
	exprs := parse_exprlist(p)
	p_expect(p, TK_DO)
	body := parse_block(p)
	p_expect(p, TK_END)
	idx := node_new(&p.nodes, NK_GENFOR)
	n := node_at(&p.nodes, idx)
	n.a = first
	n.b = exprs
	n.c = body
	return idx
}

// parse_repeat parses `repeat block until exp`.
parse_repeat :: proc(p: ^Parser) -> u32 {
	p_advance(p) // repeat
	body := parse_block(p)
	p_expect(p, TK_UNTIL)
	cond := parse_expr(p)
	idx := node_new(&p.nodes, NK_REPEAT)
	n := node_at(&p.nodes, idx)
	n.a = body
	n.b = cond
	return idx
}

// parse_do parses `do block end`.
parse_do :: proc(p: ^Parser) -> u32 {
	p_advance(p) // do
	body := parse_block(p)
	p_expect(p, TK_END)
	idx := node_new(&p.nodes, NK_DO)
	n := node_at(&p.nodes, idx)
	n.a = body
	return idx
}

// parse_return parses `return [exprlist]`.
parse_return :: proc(p: ^Parser) -> u32 {
	p_advance(p) // return
	exprs: u32 = 0
	k := p_kind(p)
	if is_block_end(k) | (k == TK_SEMI) {
		// no return values
	} else {
		exprs = parse_exprlist(p)
	}
	idx := node_new(&p.nodes, NK_RETURN)
	n := node_at(&p.nodes, idx)
	n.a = exprs
	return idx
}

// parse_funcstat parses `function funcname(params) block end`, including the
// method form `function Name:method(...)`.
parse_funcstat :: proc(p: ^Parser) -> u32 {
	p_advance(p) // function
	if p_kind(p) != TK_NAME {
		p.ok = false
		return 0
	}
	target := leaf_cur(p, NK_NAME)
	is_method := false
	for {
		if p_kind(p) == TK_DOT {
			p_advance(p)
			if p_kind(p) != TK_NAME {
				p.ok = false
				break
			}
			t := tok_at(p.toks, p.pos)
			fs := t.start
			fl := t.length
			p_advance(p)
			idx := node_new(&p.nodes, NK_FIELD)
			n := node_at(&p.nodes, idx)
			n.a = target
			n.start = fs
			n.length = fl
			target = idx
			continue
		}
		break
	}
	if p_kind(p) == TK_COLON {
		p_advance(p)
		if p_kind(p) == TK_NAME {
			t := tok_at(p.toks, p.pos)
			fs := t.start
			fl := t.length
			p_advance(p)
			idx := node_new(&p.nodes, NK_FIELD)
			n := node_at(&p.nodes, idx)
			n.a = target
			n.start = fs
			n.length = fl
			target = idx
			is_method = true
		} else {
			p.ok = false
		}
	}
	func := parse_func_body(p)
	idx := node_new(&p.nodes, NK_FUNCSTAT)
	n := node_at(&p.nodes, idx)
	n.a = target
	n.b = func
	if is_method do n.ival = 1
	return idx
}

// parse_expr_statement parses an assignment (`varlist = exprlist`) or a bare
// function/method call statement.
parse_expr_statement :: proc(p: ^Parser) -> u32 {
	first := parse_suffixed(p)
	if first == 0 {
		p.ok = false
		return 0
	}
	k := p_kind(p)
	if (k == TK_ASSIGN) | (k == TK_COMMA) {
		tfirst := first
		tlast := first
		for {
			if p_kind(p) == TK_COMMA {
				p_advance(p)
				tgt := parse_suffixed(p)
				if tgt == 0 {
					p.ok = false
					break
				}
				list_append(p, &tfirst, &tlast, tgt)
				continue
			}
			break
		}
		p_expect(p, TK_ASSIGN)
		vals := parse_exprlist(p)
		idx := node_new(&p.nodes, NK_ASSIGN)
		n := node_at(&p.nodes, idx)
		n.a = tfirst
		n.b = vals
		return idx
	}
	idx := node_new(&p.nodes, NK_CALLSTAT)
	n := node_at(&p.nodes, idx)
	n.a = first
	return idx
}

// parse_chunk parses the whole token stream as a Lua block and returns the root
// node index.
parse_chunk :: proc(p: ^Parser) -> u32 {
	root := parse_block(p)
	if p_kind(p) != TK_EOF do p.ok = false
	p.root = root
	p.node_count = p.nodes.used / node_stride
	return root
}

// --- pretty printer --------------------------------------------------------

// print_label prints an indented `name:` header used to introduce a child slot.
print_label :: proc(depth: int, s: string) {
	print_indent(depth)
	print(s)
	print(":\n")
}

// print_ast_list prints every node in a `next` chain at the given depth.
print_ast_list :: proc(p: ^Parser, head: u32, depth: int) {
	cur := head
	for {
		if cur == 0 do break
		print_ast(p, cur, depth)
		cur = node_at(&p.nodes, cur).next
	}
}

// print_ast pretty prints the subtree rooted at `node` at the given depth. It
// prints exactly one node (plus its structural children); sibling `next` chains
// are walked by the parent via print_ast_list.
print_ast :: proc(p: ^Parser, node: u32, depth: int) {
	if node == 0 do return
	n := node_at(&p.nodes, node)
	kind := n.kind

	print_indent(depth)
	print(node_name(kind))

	// distinguishing payload
	if kind == NK_NUMBER {
		print(" '")
		print_slice(p.src, n.start, n.length)
		print("' =")
		print_int(n.ival)
	} else if kind == NK_STRING {
		print(" '")
		print_slice(p.src, n.start, n.length)
		print("'")
	} else if kind == NK_NAME {
		print(" '")
		print_slice(p.src, n.start, n.length)
		print("'")
	} else if kind == NK_FIELD {
		print(" .")
		print_slice(p.src, n.start, n.length)
	} else if kind == NK_METHODCALL {
		print(" :")
		print_slice(p.src, n.start, n.length)
	} else if kind == NK_NUMFOR {
		print(" '")
		print_slice(p.src, n.start, n.length)
		print("'")
	} else if (kind == NK_BINOP) | (kind == NK_UNOP) {
		print(" ")
		print(token_name(n.op))
	} else if kind == NK_FUNCSTAT {
		if n.ival == 1 do print(" method")
	} else if kind == NK_FUNC {
		if n.ival == 1 do print(" vararg")
	}
	print("\n")

	// children
	if kind == NK_BLOCK {
		print_ast_list(p, n.a, depth + 1)
	} else if kind == NK_LOCAL {
		print_label(depth + 1, "names")
		print_ast_list(p, n.a, depth + 2)
		if n.b != 0 {
			print_label(depth + 1, "values")
			print_ast_list(p, n.b, depth + 2)
		}
	} else if kind == NK_ASSIGN {
		print_label(depth + 1, "targets")
		print_ast_list(p, n.a, depth + 2)
		print_label(depth + 1, "values")
		print_ast_list(p, n.b, depth + 2)
	} else if kind == NK_CALLSTAT {
		print_ast(p, n.a, depth + 1)
	} else if kind == NK_IF {
		print_label(depth + 1, "cond")
		print_ast(p, n.a, depth + 2)
		print_label(depth + 1, "then")
		print_ast(p, n.b, depth + 2)
		if n.c != 0 {
			print_label(depth + 1, "else")
			print_ast(p, n.c, depth + 2)
		}
	} else if kind == NK_WHILE {
		print_label(depth + 1, "cond")
		print_ast(p, n.a, depth + 2)
		print_label(depth + 1, "body")
		print_ast(p, n.b, depth + 2)
	} else if kind == NK_NUMFOR {
		print_label(depth + 1, "start")
		print_ast(p, n.a, depth + 2)
		print_label(depth + 1, "limit")
		print_ast(p, n.b, depth + 2)
		if n.c != 0 {
			print_label(depth + 1, "step")
			print_ast(p, n.c, depth + 2)
		}
		print_label(depth + 1, "body")
		print_ast(p, n.d, depth + 2)
	} else if kind == NK_GENFOR {
		print_label(depth + 1, "names")
		print_ast_list(p, n.a, depth + 2)
		print_label(depth + 1, "exprs")
		print_ast_list(p, n.b, depth + 2)
		print_label(depth + 1, "body")
		print_ast(p, n.c, depth + 2)
	} else if kind == NK_REPEAT {
		print_label(depth + 1, "body")
		print_ast(p, n.a, depth + 2)
		print_label(depth + 1, "until")
		print_ast(p, n.b, depth + 2)
	} else if kind == NK_DO {
		print_ast(p, n.a, depth + 1)
	} else if kind == NK_RETURN {
		print_ast_list(p, n.a, depth + 1)
	} else if kind == NK_FUNCSTAT {
		print_label(depth + 1, "target")
		print_ast(p, n.a, depth + 2)
		print_label(depth + 1, "func")
		print_ast(p, n.b, depth + 2)
	} else if kind == NK_FUNC {
		if n.a != 0 {
			print_label(depth + 1, "params")
			print_ast_list(p, n.a, depth + 2)
		}
		print_label(depth + 1, "body")
		print_ast(p, n.b, depth + 2)
	} else if kind == NK_BINOP {
		print_ast(p, n.a, depth + 1)
		print_ast(p, n.b, depth + 1)
	} else if kind == NK_UNOP {
		print_ast(p, n.a, depth + 1)
	} else if kind == NK_INDEX {
		print_ast(p, n.a, depth + 1)
		print_ast(p, n.b, depth + 1)
	} else if kind == NK_FIELD {
		print_ast(p, n.a, depth + 1)
	} else if kind == NK_CALL {
		print_label(depth + 1, "fn")
		print_ast(p, n.a, depth + 2)
		if n.b != 0 {
			print_label(depth + 1, "args")
			print_ast_list(p, n.b, depth + 2)
		}
	} else if kind == NK_METHODCALL {
		print_label(depth + 1, "obj")
		print_ast(p, n.a, depth + 2)
		if n.b != 0 {
			print_label(depth + 1, "args")
			print_ast_list(p, n.b, depth + 2)
		}
	} else if kind == NK_TABLE {
		print_ast_list(p, n.a, depth + 1)
	} else if kind == NK_FIELD_ENTRY {
		if n.a != 0 {
			print_label(depth + 1, "key")
			print_ast(p, n.a, depth + 2)
		}
		print_label(depth + 1, "value")
		print_ast(p, n.b, depth + 2)
	}
}
