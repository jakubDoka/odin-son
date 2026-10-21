package main

import "core:mem"
import "core:odin/ast"
import "core:odin/parser"
import "typecheck"

EMBEDDED_BOIDS :: #load("boids.source", string)
EMBEDDED_GPU_BOIDS :: #load("gpu-boids.source", string)

load_embedded_boids :: proc(ctx: ^Gen_Ctx, gpu := false) -> bool {
    file := ast.File{src = gpu ? EMBEDDED_GPU_BOIDS : EMBEDDED_BOIDS, fullpath = gpu ? "embedded/gpu-boids/main.odin" : "embedded/boids/main.odin"}
    p: parser.Parser
    {
        context.allocator = ctx.types.allocator
        if !parser.parse_file(&p, &file) do return false
    }
    ctx.files.allocator = ctx.types.allocator
    ctx.modules.allocator = ctx.types.allocator
    append(&ctx.files, file)
    append(&ctx.modules, typecheck.Module{name = file.pkg_name, file_count = 1})
    ctx.modules[0].imports.allocator = ctx.types.allocator
    decls := make([dynamic]typecheck.Decl, ctx.types.allocator)
    typecheck.collect_decls(file, &decls, 0)
    typecheck.module_add_decls(ctx, 0, decls[:])
    return true
}

package_boids :: proc(elf: []u8) -> []u8 {
    Header :: struct {
        magic: [4]u8,
        version: u16,
        flags: u16,
        entry: u64,
        payload_len: u32,
        raw_len: u32,
    }
    #assert(size_of(Header) == 24)
    assert(len(elf) <= int(max(u32)))
    // A zero entry hint selects the ELF's main symbol in the existing loader.
    header := Header{{'T', 'R', 'B', 'P'}, 1, 0x601, 0, u32(len(elf)), u32(len(elf))}
    bytes := make([]u8, size_of(Header) + len(elf))
    copy(bytes[:size_of(Header)], mem.ptr_to_bytes(&header))
    copy(bytes[size_of(Header):], elf)
    return bytes
}
