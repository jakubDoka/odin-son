package main

// A Lua lexer and parser exercised end to end. `main` runs a fixed list of Lua
// snippets through the lexer and parser, dumping the token stream and a pretty
// printed AST for each so that the output can be diffed between the reference
// Odin compiler and the JIT. The return value is a checksum over the token and
// node counts so the exit code also participates in the parity check.
//
// Everything here stays within the subset of Odin the JIT supports:
//   * integer "enums" as plain constants (no `enum`)
//   * `for { ... if cond do break }` loops only (no for-init/cond/post)
//   * `&` / `|` in place of `&&` / `||`
//   * call-form casts only, and manual char-by-char string comparison
//
// The lexer, parser, arena and IO helpers live in sibling files of the same
// `package main`.

// Each Lua snippet below is deliberately chosen to cover a different slice of
// the grammar: literals and operator precedence, locals, control flow, numeric
// and generic for loops, table constructors, function definitions and method
// calls, and recursion.

SRC_ARITH :: "local x = 1 + 2 * 3 - 4 / 2\nlocal y = (x + 1) % 3 ^ 2\nlocal z = -x + #\"hello\" .. \"!\"\n"

SRC_LOCALS :: "local a, b, c = 1, 2\nlocal flag = true and not false or nil\na, b = b, a\n"

SRC_IF :: "if x < 0 then\n  y = 0 - x\nelseif x == 0 then\n  y = 1\nelse\n  y = x\nend\n"

SRC_WHILE :: "local i = 0\nwhile i < 10 do\n  i = i + 1\n  if i == 5 then break end\nend\n"

SRC_NUMFOR :: "local sum = 0\nfor i = 1, 10, 2 do\n  sum = sum + i\nend\n"

SRC_GENFOR :: "for k, v in pairs(t) do\n  print(k, v)\nend\n"

SRC_TABLE :: "local t = { 1, 2, x = 3, [\"y\"] = 4, nested = { a = 1 } }\n"

SRC_FUNC :: "function Account.new(balance)\n  local self = {}\n  self.balance = balance\n  return self\nend\nfunction Account:deposit(amount)\n  self.balance = self.balance + amount\nend\n"

SRC_REPEAT :: "local n = 10\nrepeat\n  n = n - 1\nuntil n <= 0\n"

SRC_FACT :: "local function fact(n)\n  if n <= 1 then\n    return 1\n  end\n  return n * fact(n - 1)\nend\nlocal result = fact(5)\n"

// run_source lexes and parses one snippet, printing its tokens and AST, and
// returns a per-snippet checksum folded from the token and node counts.
run_source :: proc(name: string, src: string) -> int {
	print("=== ")
	print(name)
	print(" ===\n")
	print("--- source ---\n")
	print(src)

	l: Lexer = {}
	lexer_init(&l, src)
	lex_all(&l)

	print("--- tokens ---\n")
	dump_tokens(&l)

	p: Parser = {}
	parser_init(&p, &l)
	root := parse_chunk(&p)

	print("--- ast ---\n")
	print_ast(&p, root, 0)

	if l.ok {
		print("lex: ok\n")
	} else {
		print("lex: error\n")
	}
	if p.ok {
		print("parse: ok\n")
	} else {
		print("parse: error\n")
	}
	print("\n")

	lex_ok := 0
	if l.ok do lex_ok = 1
	parse_ok := 0
	if p.ok do parse_ok = 1

	return l.count * 7 + p.node_count * 13 + lex_ok * 3 + parse_ok * 5
}

main :: proc() -> int {
	strides_init()

	acc := 0
	acc += run_source("arith", SRC_ARITH)
	acc += run_source("locals", SRC_LOCALS)
	acc += run_source("if", SRC_IF)
	acc += run_source("while", SRC_WHILE)
	acc += run_source("numfor", SRC_NUMFOR)
	acc += run_source("genfor", SRC_GENFOR)
	acc += run_source("table", SRC_TABLE)
	acc += run_source("func", SRC_FUNC)
	acc += run_source("repeat", SRC_REPEAT)
	acc += run_source("fact", SRC_FACT)

	print("checksum = ")
	print_int(i64(acc))
	print("\n")

	return acc % 256
}
