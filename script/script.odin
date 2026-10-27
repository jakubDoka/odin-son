package script

import "core:fmt"
import "core:math/bits"
import "core:os"
import "core:slice"
import "core:strconv"
import "core:strings"

TEMP_DIR :: ".tmp/build"

main :: proc() {
	context.allocator = context.temp_allocator

	args := os.args

	root := cmd("odin", "root").stdout
	root_env := fmt.tprintf("ODIN_ROOT=%v", root)

	rmdir(TEMP_DIR)

	Program_Test :: struct {
		name:            string,
		directory:       string,
		expected_stdout: string,
	}

	tests: [dynamic]Program_Test
	tests.allocator = context.allocator
	selected := len(args) > 2 ? args[2] : ""

	gen_wasm_control_flow: {
		GENERATED_PROGRAM :: "wasm-control-flow"

		if len(args) <= 2 || !strings.starts_with(args[2], GENERATED_PROGRAM) {
			break gen_wasm_control_flow
		}

		count := nenv("STRESS_COUNT") or_else 512
		first_seed := nenv("STRESS_START") or_else 0
		assert(
			count > 0 && first_seed >= 0 && first_seed + count - 1 <= 0xffff_ffff,
		)

		template := cat(
			join("test-programs", GENERATED_PROGRAM, "main-template.odin"),
		)
		for seed in first_seed ..< first_seed + count {
			name := fmt.tprintf("%v/%v", GENERATED_PROGRAM, seed)
			if selected != "" && selected != GENERATED_PROGRAM && selected != name {
				continue
			}
			// Preserve the Python generator's seed streams so existing failures stay reproducible.
			random := Random {
				index = 624,
			}
			random.words[0] = 19650218
			for i in 1 ..< len(random.words) {
				prev := random.words[i - 1]
				random.words[i] = 1812433253 * (prev ~ (prev >> 30)) + u32(i)
			}
			index := 1
			MULTIPLIERS := [2]u32{1664525, 1566083941}
			for multiplier, phase in MULTIPLIERS {
				for _ in 0 ..< 624 - phase {
					prev := random.words[index - 1]
					addend := phase == 0 ? u32(seed) : 0 - u32(index)
					random.words[index] =
						(random.words[index] ~ ((prev ~ (prev >> 30)) * multiplier)) +
						addend
					index += 1
					if index == 624 {
						random.words[0] = random.words[623]
						index = 1
					}
				}
			}
			random.words[0] = 0x8000_0000
			nodes := sequence(&random, 3)
			result := 0
			for bits in 0 ..< 16 {
				state := 0
				flow := evaluate(nodes, &state, bits)
				assert(flow == .None || flow == .Return)
				result = (result * 0x101 + state) & 0x7fff_ffff
			}
			source, replaced := strings.replace_all(
				template,
				"\treturn p^\n",
				fmt.tprintf("%v\n\treturn p^\n", render(nodes)),
				context.allocator,
			)
			assert(replaced)
			directory := join(TEMP_DIR, "generated", name)
			mkdir(directory)
			write(join(directory, "main.odin"), source)
			append(
				&tests,
				Program_Test{name, directory, fmt.tprintf("%v\n", result)},
			)
		}

		Random :: struct {
			words: [624]u32,
			index: int,
		}

		pick :: proc(random: ^Random, limit: int) -> int {
			width := 32 - bits.count_leading_zeros(u32(limit))
			for {
				if random.index == len(random.words) {
					for &word, i in random.words {
						y :=
							(word & 0x8000_0000) |
							(random.words[(i + 1) % 624] & 0x7fff_ffff)
						word = random.words[(i + 397) % 624] ~ (y >> 1)
						if y & 1 != 0 do word ~= 0x9908_b0df
					}
					random.index = 0
				}
				y := random.words[random.index]
				random.index += 1
				y ~= y >> 11
				y ~= (y << 7) & 0x9d2c_5680
				y ~= (y << 15) & 0xefc6_0000
				y ~= y >> 18
				value := int(y >> (32 - width))
				if value < limit do return value
			}
		}

		Kind :: enum {
			Store,
			If,
			Loop,
			Break,
			Continue,
			Return,
		}

		Node :: struct {
			kind:       Kind,
			value:      int,
			comparison: int,
			left:       []Node,
			right:      []Node,
		}

		sequence :: proc(random: ^Random, depth: int, in_loop := false) -> []Node {
			nodes: [dynamic]Node
			nodes.allocator = context.allocator
			KINDS := [4]Kind{.Store, .Store, .If, .Loop}
			count := 2 + pick(random, 3)
			for _ in 0 ..< count {
				node := Node {
					kind = KINDS[pick(random, depth > 0 ? 4 : 1)],
				}
				switch node.kind {
				case .If:
					node.value = 1 + pick(random, 15)
					node.comparison = pick(random, 2)
					node.left = sequence(random, depth - 1, in_loop)
					node.right = sequence(random, depth - 1, in_loop)
				case .Loop:
					node.value = 1 + pick(random, 3)
					node.left = sequence(random, depth - 1, true)
				case .Store:
					node.value = 1 + pick(random, 127)
				case .Break, .Continue, .Return:
					unreachable()
				}
				append(&nodes, node)
				if in_loop && pick(random, 4) == 0 {
					EXITS := [2]Kind{.Break, .Continue}
					kind := EXITS[pick(random, 2)]
					append(&nodes, Node{kind = kind, value = 1 + pick(random, 15)})
				}
				if pick(random, 12) == 0 {
					append(&nodes, Node{kind = .Return, value = 1 + pick(random, 15)})
				}
			}
			return nodes[:]
		}

		render :: proc(nodes: []Node, level := 0) -> string {
			lines: [dynamic]string
			lines.allocator = context.allocator
			for node in nodes {
				switch node.kind {
				case .Store:
					append(
						&lines,
						fmt.tprintf("p^ = (p^ * 3 + %v) & 0xffff", node.value),
					)
				case .If:
					append(
						&lines,
						fmt.tprintf(
							"if (bits + p^) & %v != %v {{",
							node.value,
							node.comparison,
						),
						render(node.left, level + 1),
						"} else {",
						render(node.right, level + 1),
						"}",
					)
				case .Loop:
					name := fmt.tprintf("i%v_%v", level, len(lines))
					append(
						&lines,
						"{",
						fmt.tprintf("%v := -1", name),
						"for {",
						fmt.tprintf("%v += 1", name),
						fmt.tprintf("if %v >= %v do break", name, node.value),
						render(node.left, level + 1),
						"}",
						"}",
					)
				case .Break, .Continue, .Return:
					EXITS := #partial [Kind]string {
						.Break    = "break",
						.Continue = "continue",
						.Return   = "return p^",
					}
					append(
						&lines,
						fmt.tprintf(
							"if (bits + p^) & %v == 0 do %v",
							node.value,
							EXITS[node.kind],
						),
					)
				}
			}
			return strings.join(lines[:], "\n")
		}

		Flow :: enum {
			None,
			Break,
			Continue,
			Return,
		}

		evaluate :: proc(nodes: []Node, state: ^int, bits: int) -> Flow {
			for node in nodes {
				switch node.kind {
				case .Store:
					state^ = (state^ * 3 + node.value) & 0xffff
				case .If:
					branch :=
						(bits + state^) & node.value != node.comparison ? node.left : node.right
					flow := evaluate(branch, state, bits)
					if flow != .None do return flow
				case .Loop:
					loop: for _ in 0 ..< node.value {
						switch evaluate(node.left, state, bits) {
						case .None, .Continue:
						case .Break:
							break loop
						case .Return:
							return .Return
						}
					}
				case .Break, .Continue, .Return:
					if (bits + state^) & node.value == 0 {
						EXITS := #partial [Kind]Flow {
							.Break    = .Break,
							.Continue = .Continue,
							.Return   = .Return,
						}
						return EXITS[node.kind]
					}
				}
			}
			return .None
		}
	}

	gen_gen_big: {
		file_count := nenv("FILE_COUNT") or_else 10
		depth := nenv("DEPTH") or_else 5

		Fn :: struct {
			left, right: int,
		}

		fns: [dynamic]Fn
		roots: [dynamic]int

		for i in 0 ..< file_count {
			genned: strings.Builder

			append(&genned.buf, "package main\n")

			start := len(fns)

			generate :: proc(fns: ^[dynamic]Fn, max_depth: int, depht := 0) {
				id := len(fns)
				append(fns, Fn{})

				if depht == max_depth {
					return
				}

				left := len(fns)
				generate(fns, max_depth, depht + 1)
				right := len(fns)
				generate(fns, max_depth, depht + 1)

				fns[id] = {left, right}
			}

			append(&roots, len(fns))
			generate(&fns, depth)

			for i in start ..< len(fns) {
				fn := fns[i]
				if fn == {} {
					fmt.sbprintfln(&genned, "f%v :: proc() -> int {{return %v}}", i, i)
				} else {
					fmt.sbprintfln(
						&genned,
						`
f%v :: proc() -> int {{
    sum := %v
    sum += f%v()
    sum += f%v()
    return sum
}}
`,
						i,
						i,
						fn.left,
						fn.right,
					)
				}
			}

			write(
				join("test-programs", "big-gen", fmt.tprintf("subfile%v.odin", i)),
				strings.to_string(genned),
			)
		}

		genned: strings.Builder
		append(
			&genned.buf,
			`
package main

import "base:intrinsics"

main :: proc() -> int {
    i := 0
`,
		)

		for root in roots {
			fmt.sbprintfln(&genned, "   i += f%v()", root)
		}

		append(&genned.buf, `
  return i
}
`)

		write(
			join("test-programs", "big-gen", "main.odin"),
			strings.to_string(genned),
		)
	}

	gen_wasm_blobs: {
		genned: strings.Builder
		append(
			&genned.buf,
			`
package main // generated

run_generated :: proc() -> int {
  acc := 0
`,
		)

		SUBDIR :: ".tmp/wasm-gen/"

		mkdir(SUBDIR)

		for file in list_dir(join("test-programs", "wasm", "programs")) {
			path := join(SUBDIR, fmt.tprintf("%v.wasm", file.name))
			res := cmd(
				"odin",
				"build",
				file.fullpath,
				"-file",
				"-target:freestanding_wasm32",
				"-no-entry-point",
				"-no-bounds-check",
				"-disable-assert",
				"-o:none",
				fmt.tprintf("-out:%v", path),
			)

			if res.exit_code != 0 {
				continue
			}

			wasm := cat(path)

			encoded: strings.Builder
			for b in transmute([]u8)wasm {
				fmt.sbprintf(&encoded, "\\x%02x", b)
			}

			cname := strings.to_upper(file.name)
			fmt.sbprintf(
				&genned,
				`
  %v :: "%v"
  acc += run_module_auto("%v", %v)
`,
				cname[:len(cname) - 5],
				strings.to_string(encoded),
				file.name,
				cname[:len(cname) - 5],
			)
		}

		append(&genned.buf, `
  return acc
}`)

		write(
			join("test-programs", "wasm", "generated.odin"),
			strings.to_string(genned),
		)
	}

	gen_regalloc_stress: {
		genned: strings.Builder
		FUNCTION_COUNT :: 4
		BLOCK_COUNT :: 100
		VALUE_COUNT :: 24
		MASK :: 0xffff

		state := u64(0x4d595df4d0f33173)

		next_random :: proc(state: ^u64) -> u64 {
			x := state^
			x = x ~ (x << 13)
			x = x ~ (x >> 7)
			x = x ~ (x << 17)
			state^ = x
			return x
		}

		pick_value :: proc(state: ^u64) -> int {
			return int(next_random(state) % VALUE_COUNT)
		}

		pick_distinct :: proc(state: ^u64, avoid: int) -> int {
			value := pick_value(state)
			if value == avoid {
				value = (value + 1) % VALUE_COUNT
			}
			return value
		}

		fmt.sbprintln(&genned, "package main")
		fmt.sbprintln(&genned)

		fmt.sbprintln(
			&genned,
			"// COMPILER BUG: grouped parameters are counted as one parameter by the JIT frontend.",
		)
		fmt.sbprintln(&genned, "// stir :: proc(a, b, c, d, k0, k1: int) -> int {")
		fmt.sbprintln(
			&genned,
			"stir :: proc(a: int, b: int, c: int, d: int, k0: int, k1: int) -> int {",
		)
		fmt.sbprintfln(
			&genned,
			"\treturn ((a + b * k0) ~ (c + d * k1)) & %v",
			MASK,
		)
		fmt.sbprintln(&genned, "}")
		fmt.sbprintln(&genned)

		for function_id in 0 ..< FUNCTION_COUNT {
			fmt.sbprintfln(
				&genned,
				"stress_%v :: proc(seed: int) -> int {{",
				function_id,
			)

			for i in 0 ..< VALUE_COUNT {
				constant := int(next_random(&state) % 251) + 1
				fmt.sbprintfln(&genned, "\tv%v := (seed + %v) & %v", i, constant, MASK)
			}
			fmt.sbprintln(&genned)

			for block_id in 0 ..< BLOCK_COUNT {
				id := function_id * BLOCK_COUNT + block_id

				a := pick_value(&state)
				b := pick_distinct(&state, a)
				c := pick_distinct(&state, b)
				d := pick_distinct(&state, c)
				k0 := int(next_random(&state) % 13) + 3
				k1 := int(next_random(&state) % 251) + 1

				switch next_random(&state) % 6 {
				case 0:
					fmt.sbprintfln(
						&genned,
						"\tv%v = (v%v + v%v * %v + %v) & %v",
						a,
						b,
						c,
						k0,
						k1,
						MASK,
					)
					fmt.sbprintfln(&genned, "\tv%v = (v%v ~ v%v) & %v", d, d, a, MASK)
					fmt.sbprintfln(
						&genned,
						"\tv%v = (v%v + v%v + %v) & %v",
						b,
						b,
						d,
						k0,
						MASK,
					)

				case 1:
					fmt.sbprintfln(&genned, "\tif (v%v & 1) == 0 {{", a)
					fmt.sbprintfln(
						&genned,
						"\t\tv%v = (v%v + v%v * %v) & %v",
						b,
						b,
						c,
						k0,
						MASK,
					)
					fmt.sbprintfln(&genned, "\t\tv%v = (v%v ~ v%v) & %v", d, d, b, MASK)
					fmt.sbprintln(&genned, "\t} else {")
					fmt.sbprintfln(
						&genned,
						"\t\tv%v = (v%v + v%v + %v) & %v",
						b,
						b,
						d,
						k1,
						MASK,
					)
					fmt.sbprintfln(
						&genned,
						"\t\tv%v = (v%v * %v + v%v) & %v",
						d,
						d,
						k0,
						c,
						MASK,
					)
					fmt.sbprintln(&genned, "\t}")

				case 2:
					fmt.sbprintfln(
						&genned,
						"\tt%v := (v%v * %v + v%v) & %v",
						id,
						a,
						k0,
						b,
						MASK,
					)
					fmt.sbprintfln(&genned, "\tv%v = (v%v + v%v) & %v", c, c, d, MASK)
					fmt.sbprintfln(&genned, "\tv%v = (v%v ~ t%v) & %v", a, a, id, MASK)
					fmt.sbprintfln(
						&genned,
						"\tv%v = (v%v + t%v + %v) & %v",
						d,
						d,
						id,
						k1,
						MASK,
					)

				case 3:
					shift := int(next_random(&state) % 5) + 1
					fmt.sbprintfln(
						&genned,
						"\tv%v = ((v%v << %v) ~ v%v) & %v",
						a,
						b,
						shift,
						c,
						MASK,
					)
					fmt.sbprintfln(
						&genned,
						"\tv%v = ((v%v >> %v) + v%v + %v) & %v",
						d,
						a,
						shift,
						d,
						k1,
						MASK,
					)
					fmt.sbprintfln(
						&genned,
						"\tv%v = (v%v + v%v * %v) & %v",
						c,
						c,
						d,
						k0,
						MASK,
					)

				case 4:
					fmt.sbprintfln(
						&genned,
						"\tt%v := stir(v%v, v%v, v%v, v%v, %v, %v)",
						id,
						a,
						b,
						c,
						d,
						k0,
						k1,
					)
					fmt.sbprintfln(&genned, "\tv%v = (v%v + t%v) & %v", a, a, id, MASK)
					fmt.sbprintfln(&genned, "\tv%v = (v%v ~ t%v) & %v", c, c, id, MASK)

				case:
					fmt.sbprintfln(&genned, "\tif v%v < v%v {{", a, b)
					fmt.sbprintfln(&genned, "\t\tv%v = (v%v + %v) & %v", c, c, k1, MASK)
					fmt.sbprintfln(&genned, "\t} else if (v%v & 3) == 1 {{", d)
					fmt.sbprintfln(
						&genned,
						"\t\tv%v = (v%v * %v + v%v) & %v",
						c,
						c,
						k0,
						a,
						MASK,
					)
					fmt.sbprintln(&genned, "\t} else {")
					fmt.sbprintfln(
						&genned,
						"\t\tv%v = (v%v ~ v%v ~ %v) & %v",
						c,
						c,
						b,
						k1,
						MASK,
					)
					fmt.sbprintln(&genned, "\t}")
					fmt.sbprintfln(
						&genned,
						"\tv%v = (v%v + v%v + %v) & %v",
						d,
						d,
						c,
						k0,
						MASK,
					)
				}
			}

			fmt.sbprintf(&genned, "\treturn (")
			for i in 0 ..< VALUE_COUNT {
				if i != 0 {
					fmt.sbprintf(&genned, " + ")
				}
				fmt.sbprintf(&genned, "v%v", i)
			}
			fmt.sbprintln(&genned, ") & 0xff")
			fmt.sbprintln(&genned, "}")
			fmt.sbprintln(&genned)
		}

		fmt.sbprintln(&genned, "main :: proc() -> int {")
		fmt.sbprintln(&genned, "\tresult := 0")

		for function_id in 0 ..< FUNCTION_COUNT {
			fmt.sbprintfln(
				&genned,
				"\tresult = (result + stress_%v(result + %v)) & 0xff",
				function_id,
				function_id + 1,
			)
		}

		fmt.sbprintln(&genned, "\treturn result")
		fmt.sbprintln(&genned, "}")

		write(
			join("test-programs", "regalloc-stress", "main.odin"),
			strings.to_string(genned),
		)
	}

	switch args[1] {
	case "gen-spec":
		rm("bac/node_specs.odin")
		for file in list_dir("bac") {
			rm(join(file.fullpath, "node_specs.odin"))
		}

		cmd("odin", "run", "bac/meta")
		cmd("odin", "run", "bac/meta2")
		cmd("odin", "run", "bac/tag-gen")
		cmd("odin", "run", "bac/bindgen")
	case "build-wasm":
		cmd(
			"odin",
			"build",
			"wasm",
			"-target:freestanding_wasm32",
			"-no-entry-point",
			"-o:size",
			"-disable-assert",
			"-no-bounds-check",
			"-no-type-assert",
			`-extra-linker-flags:"-z stack-size=8388608 --export=source_buffer
       --export=output_buffer --export=__stack_pointer"`,
		)
		cmd("wasm-opt", "-Oz", "wasm.wasm", "-o", "wasm.wasm")
		cmd("mv", "wasm.wasm", "mini-odin")
	case "build-unicorn":
		cmd(
			"cmake",
			"-S",
			"vendored/unicorn-engine",
			"-B",
			"vendored/unicorn-engine/build",
			"-DCMAKE_BUILD_TYPE=Release",
			"-DBUILD_SHARED_LIBS=OFF",
			"-DUNICORN_ARCH=aarch64",
			"-DUNICORN_BUILD_TESTS=OFF",
			"-DUNICORN_INSTALL=OFF",
			"-DUNICORN_LEGACY_STATIC_ARCHIVE=ON",
		)
		cmd(
			"cmake",
			"--build",
			"vendored/unicorn-engine/build",
			"--target",
			"unicorn_archive",
			"--parallel",
		)
	case "build-wabt":
		cmd(
			"g++",
			"-std=c++17",
			"-O2",
			"-fPIC",
			"-shared",
			"utils/wabt/run.cc",
			"/usr/lib/libwabt.a",
			"-lcrypto",
			"-Wl,--no-undefined",
			"-o",
			"uitls/wabt/libwabt_runner.so",
		)
	case "run-programs":
		failures := 0
		jit_path := env("JIT")
		if jit_path == "" {
			cmd(
				"odin",
				"build",
				"odinc",
				"-out:jit",
				"-debug",
				extras = args[min(len(args), 3):],
			)
			jit_path = "./jit"
		}

		PROGRAMS_DIR :: "test-programs"

		MOD_DIR :: TEMP_DIR + "/patched-tests"

		mkdir(MOD_DIR)

		for item in list_dir(PROGRAMS_DIR) {
			name := item.name

			if 2 < len(args) && args[2] != strings.split(name, "/")[0] {
				continue
			}

			subdir := join(MOD_DIR, name)
			mkdir(subdir)

			if exists(join(item.fullpath, "main.odin")) {
				append(&tests, Program_Test{name = name, directory = item.fullpath})
			}
		}

		if len(tests) == 0 {
			fmt.eprintfln("no program tests matched %v", selected)
			os.exit(1)
		}
		for test in tests {
			name := test.name
			fmt.println("===", name, "===")
			subdir := join(MOD_DIR, name)
			mkdir(subdir)
			entry := join(test.directory, "main.odin")
			file_name, _ := strings.replace_all(name, "/", "_", context.allocator)

			if !exists(entry) do continue

			cp(test.directory, subdir)

			content := cat(entry)

			builder: strings.Builder
			append(&builder.buf, content)

			strings.builder_replace(
				&builder,
				"main :: proc() -> int {",
				"_main :: proc() -> int {",
				1,
			)
			strings.builder_replace(
				&builder,
				"package main",
				"package main\nimport __os \"core:os\"\n",
				1,
			)
			append(&builder.buf, "\nmain :: proc() { __os.exit(_main()) }\n")

			dest := join(MOD_DIR, name, "main.odin")

			write(dest, strings.to_string(builder))

			odin_bin := join(MOD_DIR, name, "ref-bin.bin")
			if cmd("odin", "build", subdir, fmt.tprintf("-out:%v", odin_bin)).exit_code !=
			   0 {
				failures += 1
				continue
			}

			ref_res := cmd(odin_bin)
			if test.expected_stdout != "" && ref_res.stdout != test.expected_stdout {
				fmt.eprintfln(
					" [%v] reference result differs from the generator oracle",
					name,
				)
				failures += 1
				continue
			}

			LEVELS := []string {
				"moderate-quick",
				"none",
				"none-quick",
				"moderate",
				"all",
				"aggresive",
			}

			for level in LEVELS {
				res_obj := join(
					MOD_DIR,
					name,
					fmt.tprintf("%v-%v.o", file_name, level),
				)

				res := cmd(
					jit_path,
					entry,
					fmt.tprintf("-o:%v", level),
					"-o",
					res_obj,
					env_map = {root_env},
				)
				fmt.print(res.stdout)
				if res.exit_code != 0 {
					fmt.eprintfln(
						" [%v] compilation failed for %v (exit=%v)",
						level,
						name,
						res.exit_code,
					)
					failures += 1
					continue
				}

				res_bin := join(
					MOD_DIR,
					name,
					fmt.tprintf("%v-%v-bin", file_name, level),
				)

				if cmd("gcc", res_obj, "-o", res_bin).exit_code != 0 {
					failures += 1
					continue
				}

				prog_res := cmd(res_bin)

				ok := true
				if ref_res.exit_code != prog_res.exit_code {
					fmt.printfln(
						" [%v] exit code mismatch: %v != %v",
						level,
						ref_res.exit_code,
						prog_res.exit_code,
					)
					ok = false
				}

				if ref_res.stdout != prog_res.stdout {
					fmt.printfln(" [%v] stdout mismatch", level)

					if cmd_exists("diff") {
						write(join(subdir, "a"), prog_res.stdout)
						write(join(subdir, "b"), ref_res.stdout)
						res := cmd("diff", join(subdir, "b"), join(subdir, "a"))
						fmt.println(res.stdout)
					}
					ok = false
				}

				if ref_res.stderr != prog_res.stderr {
					fmt.printfln(" [%v] stderr mismatch", level)

					if cmd_exists("diff") {
						write(join(subdir, "a"), prog_res.stderr)
						write(join(subdir, "b"), ref_res.stderr)
						res := cmd("diff", join(subdir, "b"), join(subdir, "a"))
						fmt.println(res.stderr)
					}

					ok = false
				}

				if ok {
					fmt.printfln(" [%v] OK (exit=%v)", level, prog_res.exit_code)
				} else {
					failures += 1
				}
			}
		}
		if failures != 0 {
			fmt.eprintfln("%v program checks failed", failures)
			os.exit(1)
		}
	case "prebuild-libs":
		TO_COMMENT_OUT :: []string {
			"\n" + `query_page_size_init :: proc "contextless" `,
			"\n" + `temp_allocator_fini :: proc "contextless" `,
			"\n" + `init_std_files :: proc "contextless" `,
			"\n" + `delete_args :: proc "contextless" `,
			"\n" + `init_standard_stream_status :: proc "contextless" `,
			"\n" + `init_terminal :: proc "contextless" `,
			"\n" + `init_thread_local_cleaner :: proc "contextless" `,
			"\n" + `fini_terminal :: proc "contextless" `,
			"\n" + `_standard_stream_init :: proc "contextless" `,
		}

		TO_REPLACE :: []string{`@(init`, `@(fini`, `@init`}

		ODIN_MOD :: TEMP_DIR + "/patched-odin"

		mkdir(ODIN_MOD)
		cp(root, ODIN_MOD)

		paths := collect_paths(ODIN_MOD)
		for path in paths {
			if strings.ends_with(path, ".odin") {
				content := cat(path)

				contains := false
				for tc in TO_COMMENT_OUT {
					contains ||= strings.contains(content, tc)
				}

				if contains {
					builder: strings.Builder
					append(&builder.buf, content)
					reps := 0
					for tr in TO_REPLACE {
						rps, _ := strings.builder_replace_all(
							&builder,
							tr,
							strings.concatenate({"//", tr}),
						)
						reps += rps
					}
					assert(reps != 0)
					write(path, strings.to_string(builder))
				}
			}
		}

		TARGETS :: []string {
			"windows_amd64",
			"linux_amd64",
			"linux_arm64",
			"darwin_arm64",
		}

		RELEASE_FLAGS :: []string {
			"-source-code-locations:none",
			"-disable-assert",
			"-disable-non-constant-globals",
			"-disable-init-fini",
			"-default-to-nil-allocator",
			"-no-bounds-check",
			"-no-type-assert",
			"-define:NO_FMT=true",
			"-define:ARNA_DISABLE_VIRTUAL=true",
			"-define:ARNA_DISABLE_THREAD_LOCAL=true",
			"-define:NODE_NAMES=false",
		}

		BASE_FLAGS :: []string {
			"bac/bindgen/lib",
			"-build-mode:obj",
			"-no-entry-point",
			"-use-single-module",
		}

		for tar in TARGETS {
			if 2 < len(args) && !strings.contains(tar, args[2]) {
				fmt.println("skipping building", tar)
				continue
			}

			fmt.println("building", tar)

			fmt.printfln(" building debug")
			cmd(
				..slice.concatenate(
					[][]string {
						{"odin", "build"},
						BASE_FLAGS,
						{"-debug"},
						{
							fmt.tprintf("-target:%v", tar),
							fmt.tprintf("-out:bac/bindgen/lib/%v_libdebug.o", tar),
						},
					},
				),
				env_map = {"ODIN_ROOT=" + ODIN_MOD},
			)

			fmt.printfln(" building release")
			cmd(
				..slice.concatenate(
					[][]string {
						{"odin", "build"},
						BASE_FLAGS,
						{
							fmt.tprintf("-target:%v", tar),
							fmt.tprintf("-out:bac/bindgen/lib/%v_lib.o", tar),
							"-o:size",
						},
						RELEASE_FLAGS,
					},
				),
				env_map = {"ODIN_ROOT=" + ODIN_MOD},
			)

			objcopy := "x86_64-w64-mingw32-objcopy"
			if cmd_exists(objcopy) && tar == "windows_amd64" {
				fmt.printfln(" building GNU objects")
				for lib in ([]string{"libdebug", "lib"}) {
					cmd(
						objcopy,
						"--redefine-sym",
						"__chkstk=___chkstk_ms",
						fmt.tprintf("bac/bindgen/lib/%v_%v.o", tar, lib),
						fmt.tprintf("bac/bindgen/lib/%v_gnu_%v.o", tar, lib),
					)
				}
			}
		}
	}
}

Cmd_Out :: struct {
	stdout, stderr: string,
	using state:    os.Process_State,
}

join :: proc(segments: ..string) -> string {
	res, _ := os.join_path(segments, context.allocator)
	return res
}

env :: proc(name: string) -> (string, bool) #optional_ok {
	return os.lookup_env(name, context.allocator)
}

nenv :: proc(name: string) -> (n: int, ok: bool) #optional_ok {
	vl := env(name) or_return
	return strconv.parse_int(vl)
}

cmd_exists :: proc(name: string) -> bool {
	pd: os.Process_Desc
	pd.command = {name, "-hhhhhh"}
	_, _, _, err := os.process_exec(pd, context.allocator)
	return err == nil
}

exists :: os.exists

cmd :: proc(
	args: ..string,
	env_map := []string{},
	extras := []string{},
) -> Cmd_Out {
	pd: os.Process_Desc
	pd.command = slice.concatenate([][]string{args, extras})
	if env("LOG_CMDS") != "" {
		fmt.println(strings.join(pd.command, " "))
	}
	pd.env = env_map
	state, stdout, stderr, err := os.process_exec(pd, context.allocator)
	fmt.assertf(err == nil, "cmd err (%v): %v", args, err)
	fmt.eprint(string(stderr), sep = "")
	return {stderr = string(stderr), stdout = string(stdout), state = state}
}

mkdir :: proc(name: string) {
	err := os.mkdir_all(name)
	fmt.assertf(err == nil || err == .Exist, "mkdir (%v): %v", name, err)
}

rmdir :: proc(name: string) {
	err := os.remove_all(name)
	fmt.assertf(err == nil || err == .Not_Exist, "rmdir (%v): %v", name, err)
}

list_dir :: proc(path: string) -> []os.File_Info {
	list, err := os.read_all_directory_by_path(path, context.allocator)
	fmt.assertf(err == nil, "list_sir (%v): %v", path, err)
	return list
}

cp :: proc(from, to: string) {
	err := os.copy_directory_all(to, from)
	fmt.assertf(err == nil, "cp (%v %v): %v", from, to, err)
}

cat :: proc(path: string) -> string {
	cont, err := os.read_entire_file(path, context.allocator)
	fmt.assertf(err == nil, "cat (%v): %v", path, err)
	return string(cont)
}

write :: proc(path, content: string) {
	err := os.write_entire_file(path, transmute([]u8)content, truncate = true)
	fmt.assertf(err == nil, "write (%v): %v", path, err)
}

collect_paths :: proc(root: string) -> []string {
	files: [dynamic]string
	walk := os.walker_create(root)
	for f in os.walker_walk(&walk) {
		if f.type == .Regular {
			append(&files, strings.clone(f.fullpath))
		}
	}
	return files[:]
}

rm :: proc(path: string) {
	os.remove(path)
}
