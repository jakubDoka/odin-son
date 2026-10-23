package script

import "core:fmt"
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
		jit_path := env("JIT")
		if jit_path == "" {
			cmd("odin", "build", "odinc", "-out:jit", "-debug")
			jit_path = "./jit"
		}

		PROGRAMS_DIR :: "test-programs"

		MOD_DIR :: TEMP_DIR + "/patched-tests"

		mkdir(MOD_DIR)

		for item in list_dir(PROGRAMS_DIR) {
			name := item.name

			if 2 < len(args) && args[2] != name {
				continue
			}

			fmt.println("===", name, "===")

			subdir := join(MOD_DIR, name)
			mkdir(subdir)

			switch name {
			case "big-gen":
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
							fmt.sbprintfln(
								&genned,
								"f%v :: proc() -> int {{return %v}}",
								i,
								i,
							)
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
						join(item.fullpath, fmt.tprintf("subfile%v.odin", i)),
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

				write(join(item.fullpath, "main.odin"), strings.to_string(genned))
			case "regalloc-stress":
				genned: strings.Builder
				generate_stress(&genned)
				write(join(item.fullpath, "main.odin"), strings.to_string(genned))
			case "wasm":
				genned: strings.Builder
				append(
					&genned.buf,
					`
package main // generated

run_generated :: proc() -> int {
  acc := 0
`,
				)

				for file in list_dir(join(item.fullpath, "programs")) {
					path := join(subdir, fmt.tprintf("%v.wasm", file.name))
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

				write(join(item.fullpath, "generated.odin"), strings.to_string(genned))
			}

			entry := join(item.fullpath, "main.odin")

			if !exists(entry) do continue

			cp(item.fullpath, subdir)

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
				continue
			}

			ref_res := cmd(odin_bin)

			LEVELS :: []string {
				"moderate-quick",
				"none",
				"none-quick",
				"moderate",
				"all",
				"aggresive",
			}

			for level in LEVELS {
				res_obj := join(MOD_DIR, name, fmt.tprintf("%v-%v.o", name, level))

				if cmd(jit_path, entry, fmt.tprintf("-o:%v", level), "-o", res_obj, env_map = {root_env}).exit_code !=
				   0 {
					continue
				}

				res_bin := join(MOD_DIR, name, fmt.tprintf("%v-%v-bin", name, level))

				if cmd("gcc", res_obj, "-o", res_bin).exit_code != 0 {
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
				}
			}
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

generate_stress :: proc(builder: ^strings.Builder) {
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

	fmt.sbprintln(builder, "package main")
	fmt.sbprintln(builder)

	fmt.sbprintln(
		builder,
		"// COMPILER BUG: grouped parameters are counted as one parameter by the JIT frontend.",
	)
	fmt.sbprintln(builder, "// stir :: proc(a, b, c, d, k0, k1: int) -> int {")
	fmt.sbprintln(
		builder,
		"stir :: proc(a: int, b: int, c: int, d: int, k0: int, k1: int) -> int {",
	)
	fmt.sbprintfln(builder, "\treturn ((a + b * k0) ~ (c + d * k1)) & %v", MASK)
	fmt.sbprintln(builder, "}")
	fmt.sbprintln(builder)

	for function_id in 0 ..< FUNCTION_COUNT {
		fmt.sbprintfln(
			builder,
			"stress_%v :: proc(seed: int) -> int {{",
			function_id,
		)

		for i in 0 ..< VALUE_COUNT {
			constant := int(next_random(&state) % 251) + 1
			fmt.sbprintfln(builder, "\tv%v := (seed + %v) & %v", i, constant, MASK)
		}
		fmt.sbprintln(builder)

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
					builder,
					"\tv%v = (v%v + v%v * %v + %v) & %v",
					a,
					b,
					c,
					k0,
					k1,
					MASK,
				)
				fmt.sbprintfln(builder, "\tv%v = (v%v ~ v%v) & %v", d, d, a, MASK)
				fmt.sbprintfln(
					builder,
					"\tv%v = (v%v + v%v + %v) & %v",
					b,
					b,
					d,
					k0,
					MASK,
				)

			case 1:
				fmt.sbprintfln(builder, "\tif (v%v & 1) == 0 {{", a)
				fmt.sbprintfln(
					builder,
					"\t\tv%v = (v%v + v%v * %v) & %v",
					b,
					b,
					c,
					k0,
					MASK,
				)
				fmt.sbprintfln(builder, "\t\tv%v = (v%v ~ v%v) & %v", d, d, b, MASK)
				fmt.sbprintln(builder, "\t} else {")
				fmt.sbprintfln(
					builder,
					"\t\tv%v = (v%v + v%v + %v) & %v",
					b,
					b,
					d,
					k1,
					MASK,
				)
				fmt.sbprintfln(
					builder,
					"\t\tv%v = (v%v * %v + v%v) & %v",
					d,
					d,
					k0,
					c,
					MASK,
				)
				fmt.sbprintln(builder, "\t}")

			case 2:
				fmt.sbprintfln(
					builder,
					"\tt%v := (v%v * %v + v%v) & %v",
					id,
					a,
					k0,
					b,
					MASK,
				)
				fmt.sbprintfln(builder, "\tv%v = (v%v + v%v) & %v", c, c, d, MASK)
				fmt.sbprintfln(builder, "\tv%v = (v%v ~ t%v) & %v", a, a, id, MASK)
				fmt.sbprintfln(
					builder,
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
					builder,
					"\tv%v = ((v%v << %v) ~ v%v) & %v",
					a,
					b,
					shift,
					c,
					MASK,
				)
				fmt.sbprintfln(
					builder,
					"\tv%v = ((v%v >> %v) + v%v + %v) & %v",
					d,
					a,
					shift,
					d,
					k1,
					MASK,
				)
				fmt.sbprintfln(
					builder,
					"\tv%v = (v%v + v%v * %v) & %v",
					c,
					c,
					d,
					k0,
					MASK,
				)

			case 4:
				fmt.sbprintfln(
					builder,
					"\tt%v := stir(v%v, v%v, v%v, v%v, %v, %v)",
					id,
					a,
					b,
					c,
					d,
					k0,
					k1,
				)
				fmt.sbprintfln(builder, "\tv%v = (v%v + t%v) & %v", a, a, id, MASK)
				fmt.sbprintfln(builder, "\tv%v = (v%v ~ t%v) & %v", c, c, id, MASK)

			case:
				fmt.sbprintfln(builder, "\tif v%v < v%v {{", a, b)
				fmt.sbprintfln(builder, "\t\tv%v = (v%v + %v) & %v", c, c, k1, MASK)
				fmt.sbprintfln(builder, "\t} else if (v%v & 3) == 1 {{", d)
				fmt.sbprintfln(
					builder,
					"\t\tv%v = (v%v * %v + v%v) & %v",
					c,
					c,
					k0,
					a,
					MASK,
				)
				fmt.sbprintln(builder, "\t} else {")
				fmt.sbprintfln(
					builder,
					"\t\tv%v = (v%v ~ v%v ~ %v) & %v",
					c,
					c,
					b,
					k1,
					MASK,
				)
				fmt.sbprintln(builder, "\t}")
				fmt.sbprintfln(
					builder,
					"\tv%v = (v%v + v%v + %v) & %v",
					d,
					d,
					c,
					k0,
					MASK,
				)
			}
		}

		fmt.sbprintf(builder, "\treturn (")
		for i in 0 ..< VALUE_COUNT {
			if i != 0 {
				fmt.sbprintf(builder, " + ")
			}
			fmt.sbprintf(builder, "v%v", i)
		}
		fmt.sbprintln(builder, ") & 0xff")
		fmt.sbprintln(builder, "}")
		fmt.sbprintln(builder)
	}

	fmt.sbprintln(builder, "main :: proc() -> int {")
	fmt.sbprintln(builder, "\tresult := 0")

	for function_id in 0 ..< FUNCTION_COUNT {
		fmt.sbprintfln(
			builder,
			"\tresult = (result + stress_%v(result + %v)) & 0xff",
			function_id,
			function_id + 1,
		)
	}

	fmt.sbprintln(builder, "\treturn result")
	fmt.sbprintln(builder, "}")
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

cmd :: proc(args: ..string, env_map := []string{}) -> Cmd_Out {
	pd: os.Process_Desc
	pd.command = args
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
