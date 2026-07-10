package main

// Token kinds and the token pool. Token kinds are plain integer constants
// because the JIT frontend does not support `enum`. A Token stores a slice of
// the source as an (offset, length) pair rather than a copied string so no
// extra allocation is needed for lexemes.

Token :: struct {
	kind:   int, // one of the TK_* constants
	start:  int, // byte offset of the lexeme into the source
	length: int, // lexeme length in bytes
	line:   int, // 1-based line number the lexeme starts on
	ival:   i64, // decoded integer value for TK_NUMBER (0 otherwise)
}

Token_Ptr :: ^Token

// --- token kinds ----------------------------------------------------------

TK_EOF :: 0
TK_NAME :: 1
TK_NUMBER :: 2
TK_STRING :: 3

// keywords
TK_AND :: 10
TK_BREAK :: 11
TK_DO :: 12
TK_ELSE :: 13
TK_ELSEIF :: 14
TK_END :: 15
TK_FALSE :: 16
TK_FOR :: 17
TK_FUNCTION :: 18
TK_IF :: 19
TK_IN :: 20
TK_LOCAL :: 21
TK_NIL :: 22
TK_NOT :: 23
TK_OR :: 24
TK_REPEAT :: 25
TK_RETURN :: 26
TK_THEN :: 27
TK_TRUE :: 28
TK_UNTIL :: 29
TK_WHILE :: 30

// symbols / operators
TK_PLUS :: 40 // +
TK_MINUS :: 41 // -
TK_STAR :: 42 // *
TK_SLASH :: 43 // /
TK_PERCENT :: 44 // %
TK_CARET :: 45 // ^
TK_HASH :: 46 // #
TK_EQ :: 47 // ==
TK_NE :: 48 // ~=
TK_LE :: 49 // <=
TK_GE :: 50 // >=
TK_LT :: 51 // <
TK_GT :: 52 // >
TK_ASSIGN :: 53 // =
TK_LPAREN :: 54 // (
TK_RPAREN :: 55 // )
TK_LBRACE :: 56 // {
TK_RBRACE :: 57 // }
TK_LBRACKET :: 58 // [
TK_RBRACKET :: 59 // ]
TK_SEMI :: 60 // ;
TK_COLON :: 61 // :
TK_COMMA :: 62 // ,
TK_DOT :: 63 // .
TK_CONCAT :: 64 // ..
TK_ELLIPSIS :: 65 // ...

TK_ERROR :: 99 // an unexpected character

// token_stride is the byte size of a Token, measured at runtime (the JIT does
// not support `size_of`). Set by strides_init before any lexing.
token_stride: int

// tok_at returns a pointer to the i-th token stored in arena `a`.
tok_at :: proc(a: ^Arena, i: int) -> Token_Ptr {
	return Token_Ptr(arena_ptr(a, i * token_stride))
}

// tok_push appends a token to arena `a` and returns its index.
tok_push :: proc(a: ^Arena, t: Token) -> int {
	off := arena_alloc(a, token_stride, 8)
	idx := off / token_stride
	p := tok_at(a, idx)
	p^ = t
	return idx
}

// bytes_eq reports whether the `length` bytes of `s` starting at `start` equal
// the literal string `lit`. Used instead of `==` on strings, which the JIT
// frontend does not support.
bytes_eq :: proc(s: string, start: int, length: int, lit: string) -> bool {
	if length != len(lit) do return false
	i := 0
	for {
		if i >= length do break
		if s[start + i] != lit[i] do return false
		i += 1
	}
	return true
}

// keyword_kind maps the lexeme [start, start+length) of `s` to a keyword token
// kind, or TK_NAME when it is an ordinary identifier.
keyword_kind :: proc(s: string, start: int, length: int) -> int {
	if bytes_eq(s, start, length, "and") do return TK_AND
	if bytes_eq(s, start, length, "break") do return TK_BREAK
	if bytes_eq(s, start, length, "do") do return TK_DO
	if bytes_eq(s, start, length, "elseif") do return TK_ELSEIF
	if bytes_eq(s, start, length, "else") do return TK_ELSE
	if bytes_eq(s, start, length, "end") do return TK_END
	if bytes_eq(s, start, length, "false") do return TK_FALSE
	if bytes_eq(s, start, length, "for") do return TK_FOR
	if bytes_eq(s, start, length, "function") do return TK_FUNCTION
	if bytes_eq(s, start, length, "if") do return TK_IF
	if bytes_eq(s, start, length, "in") do return TK_IN
	if bytes_eq(s, start, length, "local") do return TK_LOCAL
	if bytes_eq(s, start, length, "nil") do return TK_NIL
	if bytes_eq(s, start, length, "not") do return TK_NOT
	if bytes_eq(s, start, length, "or") do return TK_OR
	if bytes_eq(s, start, length, "repeat") do return TK_REPEAT
	if bytes_eq(s, start, length, "return") do return TK_RETURN
	if bytes_eq(s, start, length, "then") do return TK_THEN
	if bytes_eq(s, start, length, "true") do return TK_TRUE
	if bytes_eq(s, start, length, "until") do return TK_UNTIL
	if bytes_eq(s, start, length, "while") do return TK_WHILE
	return TK_NAME
}

// token_name returns a short, stable label for a token kind, used by the token
// dump in the test harness.
token_name :: proc(kind: int) -> string {
	if kind == TK_EOF do return "eof"
	if kind == TK_NAME do return "name"
	if kind == TK_NUMBER do return "number"
	if kind == TK_STRING do return "string"
	if kind == TK_AND do return "and"
	if kind == TK_BREAK do return "break"
	if kind == TK_DO do return "do"
	if kind == TK_ELSE do return "else"
	if kind == TK_ELSEIF do return "elseif"
	if kind == TK_END do return "end"
	if kind == TK_FALSE do return "false"
	if kind == TK_FOR do return "for"
	if kind == TK_FUNCTION do return "function"
	if kind == TK_IF do return "if"
	if kind == TK_IN do return "in"
	if kind == TK_LOCAL do return "local"
	if kind == TK_NIL do return "nil"
	if kind == TK_NOT do return "not"
	if kind == TK_OR do return "or"
	if kind == TK_REPEAT do return "repeat"
	if kind == TK_RETURN do return "return"
	if kind == TK_THEN do return "then"
	if kind == TK_TRUE do return "true"
	if kind == TK_UNTIL do return "until"
	if kind == TK_WHILE do return "while"
	if kind == TK_PLUS do return "+"
	if kind == TK_MINUS do return "-"
	if kind == TK_STAR do return "*"
	if kind == TK_SLASH do return "/"
	if kind == TK_PERCENT do return "%"
	if kind == TK_CARET do return "^"
	if kind == TK_HASH do return "#"
	if kind == TK_EQ do return "=="
	if kind == TK_NE do return "~="
	if kind == TK_LE do return "<="
	if kind == TK_GE do return ">="
	if kind == TK_LT do return "<"
	if kind == TK_GT do return ">"
	if kind == TK_ASSIGN do return "="
	if kind == TK_LPAREN do return "("
	if kind == TK_RPAREN do return ")"
	if kind == TK_LBRACE do return "{"
	if kind == TK_RBRACE do return "}"
	if kind == TK_LBRACKET do return "["
	if kind == TK_RBRACKET do return "]"
	if kind == TK_SEMI do return ";"
	if kind == TK_COLON do return ":"
	if kind == TK_COMMA do return ","
	if kind == TK_DOT do return "."
	if kind == TK_CONCAT do return ".."
	if kind == TK_ELLIPSIS do return "..."
	return "error"
}
