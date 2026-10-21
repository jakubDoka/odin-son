package script

import "core:container/intrusive/list"
import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"

TEMP_DIR :: ".tmp/build"

Cmd_Out :: struct {
	stdout, stderr: string,
	using state:    os.Process_State,
}

env :: proc(name: string) -> (string, bool) #optional_ok {
	return os.lookup_env(name, context.allocator)
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

main :: proc() {
	context.allocator = context.temp_allocator

	args := os.args

	root := cmd("odin", "root").stdout
	root_env := fmt.tprintf("ODIN_ROOT=%v", root)

	rmdir(TEMP_DIR)

	switch args[1] {
	case "run-programs":
		jit_path := env("JIT")
		if jit_path == "" {
			cmd("odin", "build", "odin", "-out:jit", "-debug")
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

			entry, _ := os.join_path(
				{item.fullpath, "main.odin"},
				context.allocator,
			)

			if !exists(entry) do continue

			subdir, _ := os.join_path({MOD_DIR, name}, context.allocator)
			mkdir(subdir)

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

			dest, _ := os.join_path(
				{MOD_DIR, name, "main.odin"},
				context.allocator,
			)

			write(dest, strings.to_string(builder))

			odin_bin, _ := os.join_path(
				{MOD_DIR, name, "ref-bin.bin"},
				context.allocator,
			)
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
				res_obj, _ := os.join_path(
					{MOD_DIR, name, fmt.tprintf("%v-%v.o", name, level)},
					context.allocator,
				)

				if cmd(jit_path, entry, fmt.tprintf("-o:%v", level), "-o", res_obj, env_map = {root_env}).exit_code !=
				   0 {
					continue
				}

				res_bin, _ := os.join_path(
					{MOD_DIR, name, fmt.tprintf("%v-%v-bin", name, level)},
					context.allocator,
				)

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
					fmt.printfln(
						" [%v] stdout mismatch: %v != %v",
						level,
						ref_res.stdout,
						prog_res.stdout,
					)
					ok = false
				}

				if ref_res.stderr != prog_res.stderr {
					fmt.printfln(
						" [%v] stderr mismatch: %v != %v",
						level,
						ref_res.stderr,
						prog_res.stderr,
					)
					ok = false
				}

				if ok {
					fmt.printfln(
						" [%v] OK (exit=%v)",
						level,
						prog_res.exit_code,
					)
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
							fmt.tprintf(
								"-out:bac/bindgen/lib/%v_libdebug.o",
								tar,
							),
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
