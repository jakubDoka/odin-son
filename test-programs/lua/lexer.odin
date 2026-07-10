package main

// The Lua lexer. `lex_all` scans the whole source into `toks` (a token arena)
// terminated by a single TK_EOF token. Lexemes are stored as (offset, length)
// pairs into `src`; number literals also decode their integer value into
// Token.ival.
//
// NOTE: the body of `lex_all` is implemented in this file; the struct, the
// constructor and the token dump used by the harness are defined here too.

Lexer :: struct {
	src:   string, // the whole source text
	pos:   int, // current byte offset
	line:  int, // current 1-based line
	toks:  Arena, // token pool (see arena.odin / token.odin)
	count: int, // number of tokens produced (including the final EOF)
	ok:    bool, // false if an unexpected character was seen
}

// lexer_init prepares a lexer over `src`.
lexer_init :: proc(l: ^Lexer, src: string) {
	l.src = src
	l.pos = 0
	l.line = 1
	l.count = 0
	l.ok = true
	arena_init(&l.toks, 64 * 1024)
}

// print_slice writes the bytes [start, start+length) of `s`.
print_slice :: proc(s: string, start: int, length: int) {
	i := 0
	for {
		if i >= length do break
		print_char(s[start + i])
		i += 1
	}
}

// dump_tokens prints one line per token: line number, kind label and, for
// lexeme bearing tokens, the raw text (and decoded value for numbers).
dump_tokens :: proc(l: ^Lexer) {
	i := 0
	for {
		if i >= l.count do break
		t := tok_at(&l.toks, i)
		print("  ")
		print_int(i64(t.line))
		print(" ")
		print(token_name(t.kind))
		has_text :=
			(t.kind == TK_NAME) | (t.kind == TK_STRING) | (t.kind == TK_NUMBER)
		if has_text {
			print(" '")
			print_slice(l.src, t.start, t.length)
			print("'")
		}
		if t.kind == TK_NUMBER {
			print(" =")
			print_int(t.ival)
		}
		print("\n")
		i += 1
	}
}

// is_digit reports whether byte `c` is an ASCII decimal digit.
is_digit :: proc(c: u8) -> bool {
	if c < '0' do return false
	if c > '9' do return false
	return true
}

// is_alpha reports whether `c` may start an identifier ([A-Za-z_]).
is_alpha :: proc(c: u8) -> bool {
	if c == '_' do return true
	if c >= 'a' {
		if c <= 'z' do return true
	}
	if c >= 'A' {
		if c <= 'Z' do return true
	}
	return false
}

// is_alnum reports whether `c` may continue an identifier ([A-Za-z0-9_]).
is_alnum :: proc(c: u8) -> bool {
	if is_alpha(c) do return true
	if is_digit(c) do return true
	return false
}

// lex_all scans the entire source. IMPLEMENTED BY THE LEXER AGENT.
lex_all :: proc(l: ^Lexer) {
	src := l.src
	n := len(src)

	for {
		if l.pos >= n do break
		c := src[l.pos]

		// --- whitespace ---
		if c == ' ' {
			l.pos += 1
			continue
		}
		if c == '\t' {
			l.pos += 1
			continue
		}
		if c == '\r' {
			l.pos += 1
			continue
		}
		if c == '\n' {
			l.pos += 1
			l.line += 1
			continue
		}

		// --- line comment: -- to end of line ---
		if c == '-' {
			is_comment := false
			if l.pos + 1 < n {
				if src[l.pos + 1] == '-' do is_comment = true
			}
			if is_comment {
				l.pos += 2
				for {
					if l.pos >= n do break
					if src[l.pos] == '\n' do break
					l.pos += 1
				}
				continue
			}
		}

		start := l.pos
		line := l.line

		// --- identifiers / keywords ---
		if is_alpha(c) {
			l.pos += 1
			for {
				if l.pos >= n do break
				if is_alnum(src[l.pos]) {
					l.pos += 1
					continue
				}
				break
			}
			length := l.pos - start
			kind := keyword_kind(src, start, length)
			tok_push(&l.toks, Token{kind, start, length, line, 0})
			l.count += 1
			continue
		}

		// --- numbers (decimal integer) ---
		if is_digit(c) {
			val := i64(0)
			for {
				if l.pos >= n do break
				d := src[l.pos]
				if is_digit(d) {
					val = val * 10 + i64(int(d) - int('0'))
					l.pos += 1
					continue
				}
				break
			}
			length := l.pos - start
			tok_push(&l.toks, Token{TK_NUMBER, start, length, line, val})
			l.count += 1
			continue
		}

		// --- strings ---
		if c == '"' {
			lex_string(l, '"')
			continue
		}
		if c == '\'' {
			lex_string(l, '\'')
			continue
		}

		// --- operators / punctuation ---
		kind := TK_ERROR
		length := 1

		if c == '.' {
			// ... .. .
			length = 1
			kind = TK_DOT
			if l.pos + 1 < n {
				if src[l.pos + 1] == '.' {
					length = 2
					kind = TK_CONCAT
					if l.pos + 2 < n {
						if src[l.pos + 2] == '.' {
							length = 3
							kind = TK_ELLIPSIS
						}
					}
				}
			}
		} else if c == '=' {
			kind = TK_ASSIGN
			if l.pos + 1 < n {
				if src[l.pos + 1] == '=' {
					kind = TK_EQ
					length = 2
				}
			}
		} else if c == '~' {
			kind = TK_ERROR
			if l.pos + 1 < n {
				if src[l.pos + 1] == '=' {
					kind = TK_NE
					length = 2
				}
			}
		} else if c == '<' {
			kind = TK_LT
			if l.pos + 1 < n {
				if src[l.pos + 1] == '=' {
					kind = TK_LE
					length = 2
				}
			}
		} else if c == '>' {
			kind = TK_GT
			if l.pos + 1 < n {
				if src[l.pos + 1] == '=' {
					kind = TK_GE
					length = 2
				}
			}
		} else if c == '+' {
			kind = TK_PLUS
		} else if c == '-' {
			kind = TK_MINUS
		} else if c == '*' {
			kind = TK_STAR
		} else if c == '/' {
			kind = TK_SLASH
		} else if c == '%' {
			kind = TK_PERCENT
		} else if c == '^' {
			kind = TK_CARET
		} else if c == '#' {
			kind = TK_HASH
		} else if c == '(' {
			kind = TK_LPAREN
		} else if c == ')' {
			kind = TK_RPAREN
		} else if c == '{' {
			kind = TK_LBRACE
		} else if c == '}' {
			kind = TK_RBRACE
		} else if c == '[' {
			kind = TK_LBRACKET
		} else if c == ']' {
			kind = TK_RBRACKET
		} else if c == ';' {
			kind = TK_SEMI
		} else if c == ':' {
			kind = TK_COLON
		} else if c == ',' {
			kind = TK_COMMA
		}

		if kind == TK_ERROR do l.ok = false
		tok_push(&l.toks, Token{kind, start, length, line, 0})
		l.count += 1
		l.pos += length
	}

	// --- final EOF ---
	tok_push(&l.toks, Token{TK_EOF, n, 0, l.line, 0})
	l.count += 1
}

// lex_string scans a quoted string starting at l.pos (on the opening quote),
// pushing a TK_STRING token whose start/length span the contents WITHOUT the
// surrounding quotes. `quote` is the opening/closing quote byte.
lex_string :: proc(l: ^Lexer, quote: u8) {
	src := l.src
	n := len(src)
	line := l.line
	l.pos += 1 // skip opening quote
	start := l.pos

	for {
		if l.pos >= n do break
		c := src[l.pos]
		if c == quote do break
		if c == '\n' do l.line += 1
		if c == '\\' {
			// skip the backslash and the escaped char
			l.pos += 1
			if l.pos >= n do break
			if src[l.pos] == '\n' do l.line += 1
			l.pos += 1
			continue
		}
		l.pos += 1
	}

	length := l.pos - start
	tok_push(&l.toks, Token{TK_STRING, start, length, line, 0})
	l.count += 1

	if l.pos < n {
		// consume the closing quote
		l.pos += 1
	} else {
		l.ok = false
	}
}
