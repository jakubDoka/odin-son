#+build !wasm32
package main

import "core:fmt"
import "core:odin/ast"
import "core:odin/parser"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "typecheck"

load_program :: proc(ctx: ^Gen_Ctx, entry_file: string) {
	ctx.files.allocator = ctx.types.allocator
	ctx.modules.allocator = ctx.types.allocator

	append(&ctx.modules, typecheck.Module{name = "intrinsics"})

	entry_dir := filepath.dir(entry_file)
	if entry_dir == "" do entry_dir = "."

	loaded: map[string]typecheck.Module_ID
	loaded.allocator = context.temp_allocator

	load_dir(ctx, entry_dir, &loaded)
}

@(private = "file")
load_dir :: proc(
	ctx: ^Gen_Ctx,
	dir: string,
	loaded: ^map[string]typecheck.Module_ID,
) -> typecheck.Module_ID {
	abs, _ := filepath.abs(dir, context.temp_allocator)
	if existing, ok := loaded[abs]; ok {
		return existing
	}

	dir := strings.clone(dir, ctx.types.allocator)

	mid := typecheck.Module_ID(len(ctx.modules))
	loaded[abs] = mid
	append(&ctx.modules, typecheck.Module{dir = dir})
	mod := &ctx.modules[mid]

	handle, oerr := os.open(dir)
	fmt.assertf(oerr == nil, "cannot open module directory %q", dir)
	defer os.close(handle)

	entries, rerr := os.read_dir(handle, -1, context.temp_allocator)
	fmt.assertf(rerr == nil, "cannot read module directory %q", dir)

	mod.file_start = len(ctx.files)
	decls: [dynamic]typecheck.Decl

	for entry in entries {
		if entry.type == .Directory do continue
		if !strings.has_suffix(entry.name, ".odin") do continue

		src, serr := os.read_entire_file(entry.fullpath, ctx.types.allocator)
		fmt.assertf(serr == nil, "cannot read %q", entry.fullpath)

		f: ast.File
		f.src = string(src)
		f.fullpath = entry.fullpath

		p := parser.Parser{}

		{
			context.allocator = ctx.types.allocator
			pok := parser.parse_file(&p, &f)
			fmt.assertf(pok, "failed to parse %q", entry.fullpath)
		}

		if mod.name == "" do mod.name = f.pkg_name

		typecheck.collect_decls(f, &decls, typecheck.File_ID(len(ctx.files)))

		append(&ctx.files, f)
	}

	typecheck.module_add_decls(ctx, mid, decls[:])

	mod.file_count = len(ctx.files) - mod.file_start

	if mod.name == "" {
		mod.name = filepath.base(abs)
	}

	for i in 0 ..< mod.file_count {
		for decl in ctx.files[mod.file_start + i].decls[:] {
			imp := decl.derived.(^ast.Import_Decl) or_continue
			path := imp.relpath.text[1:len(imp.relpath.text) - 1]
			name := imp.name.text
			if name == "" {
				name = path
				_, _ = strings.split_iterator(&name, ":")
				if name == "" do name = path
				_, name = os.split_path(name)
				name, _ = os.split_filename_all(name)
			}

			col_rel_path := path
			if col, ok := strings.split_iterator(&col_rel_path, ":");
			   ok && col_rel_path != "" {
				if col == "base" && col_rel_path == "intrinsics" {
					ctx.modules[mid].imports[name] =
						typecheck.MODULE_INTRINSICS
					continue
				}

				path, ok = ctx.collections[col]
				fmt.assertf(
					ok,
					"unknown collection: %v, available: %v",
					col,
					ctx.collections,
				)
				path, _ = os.join_path(
					{path, col_rel_path},
					context.temp_allocator,
				)
			} else {
				path, _ = filepath.join(
					{ctx.modules[mid].dir, path},
					context.temp_allocator,
				)
			}

			tid := load_dir(ctx, path, loaded)
			ctx.modules[mid].imports[name] = tid
		}
	}

	return mid
}
