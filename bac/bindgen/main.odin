package bac_bindgen

import "base:runtime"
import "core:fmt"
import "core:os"
import "core:reflect"
import "core:slice"
import "core:strings"

EXPORTED_SUBMODS := [?]string {
	"bac",
	"bac_ssa",
	"bac_arm",
	"bac_x64",
	"bac_wasm",
	"bac_regalloc",
	"arna",
}
EXPORTED_SUBMODS_PATH := [?]string {
	"..",
	"../ssa",
	"../arm",
	"../x64",
	"../wasm",
	"../regalloc/",
	"../../utils/arna/",
}

API_Proc :: struct {
	trhead_local: bool,
	package_path: string,
	name:         string,
	type:         typeid,
	doc_comment:  string,
}

main :: proc() {
	when #config(BAC_RUST_ONLY, false) {
		generate_rust(API[:])
		return
	}

	mkerr := os.make_directory("bac/bindgen/lib")
	assert(mkerr == nil || mkerr == .Exist)
	mkerr = os.make_directory("bac/bindgen/c")
	assert(mkerr == nil || mkerr == .Exist)

	lib, operr := os.open(
		"bac/bindgen/lib/lib.odin",
		flags = {.Read, .Write, .Trunc, .Create},
	)
	assert(operr == nil)
	defer os.close(lib)

	c_file, c_operr := os.open(
		"bac/bindgen/c/bac.h",
		flags = {.Read, .Write, .Trunc, .Create},
	)
	assert(c_operr == nil)
	defer os.close(c_file)

	c_lib := strings.builder_make()
	defer strings.builder_destroy(&c_lib)

	os.write_string(lib, `
package bac_lib

import "base:runtime"
`)

	for i in 0 ..< len(EXPORTED_SUBMODS) {
		name := EXPORTED_SUBMODS[i]
		path := EXPORTED_SUBMODS_PATH[i]
		fmt.fprintfln(lib, "import %v \"../%v\"", name, path)
	}

	fmt.fprintln(lib)

	for i in 0 ..< len(EXPORTED_SUBMODS) {
		name := EXPORTED_SUBMODS[i]
		fmt.fprintfln(lib, "_ :: %v", name)
	}

	types: map[typeid]int
	seen: map[typeid]struct{}

	strings.write_string(
		&c_lib,
		`
#define bac_i8       signed char
#define bac_i16      short
#define bac_i32      int
#define bac_i64      long long

#define bac_u8       unsigned char
#define bac_u16      unsigned short
#define bac_u32      unsigned int
#define bac_u64      unsigned long long

#define bac_f16      _Float16
#define bac_f32      float
#define bac_f64      double

#define bac_int      __INTPTR_TYPE__
#define bac_uint     __UINTPTR_TYPE__
#define bac_uintptr  __UINTPTR_TYPE__

#define bac_byte     unsigned char
#define bac_rune     int
#define bac_bool     _Bool

#define bac_str(s) ((bac_String){(bac_u8 *)(s), (bac_int)(sizeof(s) - 1)})
#define bac_slice(ptr, count) { (ptr), (bac_int)(count) }
#define bac_slice_array(ty, arr) \
    (Slice_Of_##ty){ (arr), (bac_int)(sizeof(arr) / sizeof((arr)[0])) }

typedef struct {
	bac_u8* data;
	bac_int len;
} bac_String;

`,
	)

	for i in 0 ..< 2 {
		for entry, j in API {
			first_pass := i == 0

			sig, is_proc := type_info_of(entry.type).variant.(runtime.Type_Info_Procedure)

			params, results := proc_lists(sig)

			packag := entry.package_path
			for _ in 0 ..< 10 {
				packag = strings.trim_prefix(packag, "..")
				packag = strings.trim_prefix(packag, "/")
				packag = strings.trim_prefix(packag, "utils")
			}
			if packag == "arna" {
			} else if len(packag) != 0 {

				packag = strings.concatenate({"bac_", packag})
			} else {
				packag = "bac"
			}

			prefix := packag
			if prefix == "bac_ssa" do prefix = "bac"
			if prefix == "bac_regalloc" do prefix = "bac"

			gen_lib: if first_pass && is_proc {
				fmt.fprintln(lib, `@(export)`)
				fmt.fprintfln(lib, `%v_%v :: proc "c" (`, prefix, entry.name)

				for i in 0 ..< len(params.types) {
					name := params.names[i]
					type := params.types[i]

					reflect.qualified = true

					fmt.fprintfln(lib, "\t%v: %T,", name, type)
				}
				for i in 0 ..< len(results.types) - 1 {
					fmt.fprintfln(lib, "\tbinding_out_%v: ^%T,", i, results.types[i])
				}

				fmt.fprintf(lib, `)`)

				if len(results.types) != 0 {
					fmt.fprintfln(lib, " -> (")
					fmt.fprintfln(lib, "\t%T,", results.types[len(results.types) - 1])
					fmt.fprintf(lib, ")")
				}

				fmt.fprintf(lib, " {{\n\tcontext = {{}}\n\t")
				if entry.name == "arg_gen_finalize" {
					fmt.fprintf(lib, "context.allocator = arna.allocator(ctx.mem)\n\t")
				}
				if len(results.types) == 1 {
					fmt.fprintf(lib, "return ")
				} else if len(results.types) > 1 {
					for i in 0 ..< len(results.types) {
						if i != 0 do fmt.fprintf(lib, ", ")
						fmt.fprintf(lib, "binding_result_%v", i)
					}
					fmt.fprintf(lib, " := ")
				}

				fmt.fprintf(lib, "%v.%v(", packag, entry.name)
				for i in 0 ..< len(params.types) {
					if i != 0 do fmt.fprintf(lib, ", ")
					fmt.fprintf(lib, "%v", params.names[i])
				}
				fmt.fprintfln(lib, ")")
				if len(results.types) > 1 {
					for i in 0 ..< len(results.types) - 1 {
						fmt.fprintfln(lib, "\tbinding_out_%v^ = binding_result_%v", i, i)
					}
					fmt.fprintfln(lib, "\treturn binding_result_%v", len(results.types) - 1)
				}

				fmt.fprintfln(lib, "}}\n")
			}

			if first_pass {
				for par in params.types {
					visit(type_info_of(par.id), &types, &seen)
				}
				for result in results.types {
					visit(type_info_of(result.id), &types, &seen)
				}
			}

			c: if !first_pass && j == 0 {
				Entry :: struct {
					depth: int,
					type:  typeid,
				}
				ents: [dynamic]Entry

				for k, v in types {
					append(&ents, Entry{v, k})
				}

				cmp :: proc(v: Entry) -> int {
					#partial switch t in type_info_of(v.type).variant {
					case runtime.Type_Info_Struct,
					     runtime.Type_Info_Union,
					     runtime.Type_Info_Bit_Field,
					     runtime.Type_Info_Bit_Set,
					     runtime.Type_Info_Enum,
					     runtime.Type_Info_Integer,
					     runtime.Type_Info_Fixed_Capacity_Dynamic_Array,
					     runtime.Type_Info_Slice,
					     runtime.Type_Info_Dynamic_Array:
						return 0
					case runtime.Type_Info_Named:
						return cmp({0, t.base.id})
					case:
						return 1
					}
				}

				slice.sort_by_key(ents[:], cmp)

				typedefs: map[string]struct{}
				for ent in ents {
					ty := ent.type
					#partial switch _ in type_info_of(ty).variant {
					case runtime.Type_Info_Integer,
					     runtime.Type_Info_Type_Id,
					     runtime.Type_Info_Boolean,
					     runtime.Type_Info_Float,
					     runtime.Type_Info_Rune,
					     runtime.Type_Info_String,
					     runtime.Type_Info_Array,
					     runtime.Type_Info_Enumerated_Array:
						continue
					}
					name := c_type_name(type_info_of(ty))
					if name != "" && name not_in typedefs {
						typedefs[name] = {}
						fmt.sbprintf(&c_lib, "typedef ")
						c_display_type(
							&c_lib,
							type_info_of(ty),
							.Typedef,
							&name,
							0,
						)

						c_disp_name(&c_lib, name)
						fmt.sbprintfln(&c_lib, ";")
					}
				}

				slice.sort_by(
					ents[:],
					proc(a, b: Entry) -> bool {return a.depth < b.depth},
				)

				decls: map[string]struct{}
				for ent in ents {
					ty := ent.type
					name := c_type_name(type_info_of(ty))
					if name != "" && name in typedefs && name not_in decls {
						prev_len := len(c_lib.buf)
						decls[name] = {}
						start := len(c_lib.buf)
						c_display_type(
							&c_lib,
							type_info_of(ty),
							.Decl,
							&name,
							0,
						)
						if len(c_lib.buf) == start do continue
						c_disp_name(&c_lib, name)
						if prev_len != len(c_lib.buf) {
							fmt.sbprintfln(&c_lib, ";")
						}
					}
				}
			}

			c_fn: if !first_pass {
				f := &c_lib

				if entry.doc_comment != "" {
					fmt.sbprintln(f, entry.doc_comment)
				}

				fmt.sbprint(f, "extern ")
				if entry.trhead_local {
					fmt.sbprint(f, "_Thread_local ")
				}
				if is_proc {

					if 0 < len(results.types) {
						ty := results.types[len(results.types) - 1]
						result_name := ""
						c_display_type(f, ty, .Field, &result_name, 0)
						c_disp_name(f, result_name)
					} else {
						fmt.sbprintf(f, "void")
					}

					fmt.sbprintf(f, " %v_%v(", prefix, entry.name)
					for ty, i in params.types {
						if i != 0 do fmt.sbprint(f, ", ")
						name := params.names[i]
						c_display_type(f, ty, .Field, &name, 0)
						c_disp_name(f, name)
					}

					for i in 0 ..< len(results.types) - 1 {
						// NOTE: we dont have zero arg multireturns
						fmt.sbprint(f, ", ")
						name := fmt.tprintf("ret%v", i)
						if results.names[i] != "" {
							name = results.names[i]
						}
						c_display_pointer(
							f,
							results.types[i],
							.Field,
							&name,
							0,
						)
						c_disp_name(f, name)
					}

					fmt.sbprintfln(f, ");")
				} else {
					name := fmt.tprintf("%v_%v", packag, entry.name)
					c_display_type(
						f,
						type_info_of(entry.type),
						.Field,
						&name,
						0,
					)
					c_disp_name(f, name)
					fmt.sbprintfln(f, ";")
				}
			}
		}
	}

	os.write_string(c_file, strings.to_string(c_lib))
	generate_rust(API[:])

	visit :: proc(
		ty: ^runtime.Type_Info,
		coll: ^map[typeid]int,
		seen: ^map[typeid]struct{},
	) -> (
		depth: int,
	) {
		if ty.id in seen do return coll[ty.id]
		seen[ty.id] = {}

		#partial switch t in ty.variant {
		case runtime.Type_Info_Multi_Pointer:
			depth = visit(t.elem, coll, seen)
		case runtime.Type_Info_Pointer:
			if t.elem != nil {
				depth = visit(t.elem, coll, seen)
			}
		case runtime.Type_Info_Named:
			depth = visit(t.base, coll, seen)
		case runtime.Type_Info_Struct:
			for field in t.types[:t.field_count] {
				depth = max(depth, visit(field, coll, seen))
			}
		case runtime.Type_Info_Bit_Field:
			depth = visit(t.backing_type, coll, seen)
			for field in t.types[:t.field_count] {
				depth = max(depth, visit(field, coll, seen))
			}
		case runtime.Type_Info_Union:
			for field in t.variants {
				depth = max(depth, visit(field, coll, seen))
			}
			if t.tag_type != nil {
				depth = max(depth, visit(t.tag_type, coll, seen))
			}
		case runtime.Type_Info_Slice:
			depth = max(depth, visit(t.elem, coll, seen))
		case runtime.Type_Info_Dynamic_Array:
			depth = max(depth, visit(t.elem, coll, seen))
			depth = max(
				depth,
				visit(type_info_of(runtime.Raw_Dynamic_Array), coll, seen),
			)
		case runtime.Type_Info_Array:
			depth = max(depth, visit(t.elem, coll, seen))
		case runtime.Type_Info_Fixed_Capacity_Dynamic_Array:
			depth = max(depth, visit(t.elem, coll, seen))
		case runtime.Type_Info_Integer,
		     runtime.Type_Info_Float,
		     runtime.Type_Info_Rune,
		     runtime.Type_Info_Type_Id,
		     runtime.Type_Info_String,
		     runtime.Type_Info_Boolean:
		case runtime.Type_Info_Procedure:
			params, results := proc_lists(t)
			for ty in params.types {
				depth = max(depth, visit(ty, coll, seen))
			}
			for ty in results.types {
				depth = max(depth, visit(ty, coll, seen))
			}
		case runtime.Type_Info_Enumerated_Array:
			depth = max(depth, visit(t.elem, coll, seen))
			depth = max(depth, visit(t.index, coll, seen))
		case runtime.Type_Info_Bit_Set:
			depth = max(depth, visit(t.elem, coll, seen))
			if t.underlying != nil {
				depth = max(depth, visit(t.underlying, coll, seen))
			}
		case runtime.Type_Info_Enum:
			depth = max(depth, visit(t.base, coll, seen))
		case:
			fmt.panicf("unhandled type: %v", t)
		}

		depth += 1
		coll[ty.id] = depth

		return
	}

	c_type_to_name :: proc(
		s: string,
		allocator := context.allocator,
	) -> string {
		b := strings.builder_make(allocator)

		for c in s {
			switch c {
			case ')', '$', ' ', '\t':
			// Skip
			case 'a' ..= 'z', 'A' ..= 'Z', '0' ..= '9', '_':
				strings.write_byte(&b, u8(c))
			case:
				strings.write_byte(&b, '_')
			}
		}

		return strings.to_string(b)
	}

	indent :: proc(f: ^strings.Builder, depth: int) {
		for _ in 0 ..< depth {
			strings.write_byte(f, '\t')
		}
	}

	Display_Mode :: enum {
		Field,
		Typedef,
		Decl,
	}

	c_disp_name :: proc(f: ^strings.Builder, name: string) {
		@(static) anon_idx := 0

		if name == "_" {
			fmt.sbprintf(f, " _%v", anon_idx)
			anon_idx += 1
		} else if name != "" {
			fmt.sbprintf(f, " %v", name)
		}
	}

	c_display_field :: proc(
		f: ^strings.Builder,
		ty: ^runtime.Type_Info,
		name: string,
		depth: int,
	) {
		indent(f, depth + 1)
		name := c_type_to_name(name)
		c_display_type(f, ty, .Field, &name, depth + 1)
		c_disp_name(f, name)
		fmt.sbprintfln(f, ";")
	}

	c_display_type :: proc(
		f: ^strings.Builder,
		ty: ^runtime.Type_Info,
		mode: Display_Mode,
		name: ^string,
		depth: int,
	) {
		#partial switch t in ty.variant {
		case runtime.Type_Info_Boolean:
			switch mode {
			case .Field, .Typedef:
				fmt.sbprint(f, "_Bool")
			case .Decl:
				name^ = {}
			}
		case runtime.Type_Info_Array:
			if mode == .Decl {
				name^ = {}
			} else {
				name^ = fmt.tprintf("%v[%v]", name^, t.count)
				c_display_type(f, t.elem, .Field, name, depth)
			}
		case runtime.Type_Info_Enumerated_Array:
			if mode == .Decl {
				name^ = {}
			} else {
				name^ = fmt.tprintf("%v[%v]", name^, t.count)
				c_display_type(f, t.elem, .Field, name, depth)
			}
		case runtime.Type_Info_Fixed_Capacity_Dynamic_Array:
			switch mode {
			case .Typedef:
				fmt.sbprint(f, "struct", name^)
			case .Field:
				fmt.sbprint(f, c_type_name(ty))
			case .Decl:
				fmt.sbprintfln(f, "struct %v {{", name^)
				info: runtime.Type_Info
				info.variant = runtime.Type_Info_Array {
					elem  = t.elem,
					count = t.capacity,
				}
				c_display_field(f, &info, "data", depth)
				padding := int(t.len_offset) - t.capacity * t.elem_size
				if padding > 0 {
					indent(f, depth + 1)
					fmt.sbprintfln(f, "bac_u8 _padding[%v];", padding)
				}
				indent(f, depth + 1)
				fmt.sbprintln(f, "bac_int len;")
				indent(f, depth)
				fmt.sbprintf(f, "}}")
				name^ = {}
			}
		case runtime.Type_Info_Bit_Set:
			switch mode {
			case .Field:
				fmt.sbprint(f, c_type_name(ty))
			case .Typedef:
				fmt.sbprintf(f, "bac_u%v", ty.size * 8)
			case .Decl:
				if _, ok := runtime.type_info_base(t.elem).variant.(runtime.Type_Info_Enum);
				   ok {
					fmt.sbprintln(f, "enum {")
					for field in reflect.enum_fields_zipped(t.elem.id) {
						indent(f, depth + 1)
						fmt.sbprintfln(
							f,
							"%v_%v = 1 << %v,",
							name^,
							c_type_to_name(field.name),
							i64(field.value) - t.lower,
						)
					}
					indent(f, depth)
					fmt.sbprintf(f, "}}")
				}
				name^ = {}
			}
		case runtime.Type_Info_Type_Id:
			if mode == .Decl {
				name^ = {}
			} else {
				fmt.sbprintf(f, "bac_int")
			}
		case runtime.Type_Info_Float:
			if mode == .Decl {
				name^ = {}
			} else {
				assert(ty.size == 4 || ty.size == 8)
				fmt.sbprintf(f, "%v", "float" if ty.size == 4 else "double")
			}
		case runtime.Type_Info_Rune:
			if mode == .Decl {
				name^ = {}
			} else {
				fmt.sbprintf(f, "bac_rune")
			}
		case runtime.Type_Info_Slice:
			switch mode {
			case .Typedef:
				fmt.sbprint(f, "struct", c_type_name(ty))
			case .Field:
				fmt.sbprint(f, c_type_name(ty))
			case .Decl:
				fmt.sbprintfln(f, `struct %v {{`, name^)
				info: runtime.Type_Info
				info.variant = runtime.Type_Info_Pointer {
					elem = t.elem,
				}
				c_display_field(f, &info, "data", depth)
				fmt.sbprint(f, "\tbac_int len;\n}")
				name^ = {}
			}
		case runtime.Type_Info_Dynamic_Array:
			switch mode {
			case .Typedef:
				fmt.sbprint(f, "struct", c_type_name(ty))
			case .Field:
				fmt.sbprint(f, c_type_name(ty))
			case .Decl:
				fmt.sbprintfln(f, `struct %v {{`, name^)
				info: runtime.Type_Info
				info.variant = runtime.Type_Info_Pointer {
					elem = t.elem,
				}
				c_display_field(f, &info, "data", depth)
				fmt.sbprintln(f, "\tbac_int len, cap;")
				fmt.sbprintln(f, "\truntime_Allocator allocator;")
				fmt.sbprint(f, "}")
				name^ = {}
			}
		case runtime.Type_Info_Enum:
			switch mode {
			case .Field:
				c_display_type(f, t.base, mode, name, depth)
			case .Typedef:
				c_display_type(f, t.base, mode, name, depth)
			case .Decl:
				fmt.sbprintln(f, "enum {")

				for field in reflect.enum_fields_zipped(ty.id) {
					indent(f, depth + 1)
					fmt.sbprintfln(
						f,
						"%v_%v = %v,",
						name^,
						field.name,
						field.value,
					)
				}

				indent(f, depth)
				fmt.sbprintf(f, "}}")
				name^ = {}
			}
		case runtime.Type_Info_Union:
			keyw := "struct" if t.tag_type != nil else "union"
			switch mode {
			case .Typedef:
				fmt.sbprintf(f, "%v %v", keyw, name^)
			case .Decl, .Field:
				if mode == .Field {
					fmt.sbprintfln(f, "%v {{", keyw)
				} else {
					fmt.sbprintfln(f, "%v %v {{", keyw, name^)
					name^ = {}
				}
				if t.tag_type != nil {
					indent(f, depth + 1)
					fmt.sbprintln(f, "union {")
				}
				payload_depth := depth + int(t.tag_type != nil)
				for variant, i in t.variants {
					c_display_field(
						f,
						variant,
						fmt.tprintf("variant_%v", i),
						payload_depth,
					)
				}
				if t.tag_type != nil {
					indent(f, payload_depth + 1)
					fmt.sbprintfln(f, "bac_u8 _payload[%v];", t.tag_offset)
					indent(f, depth + 1)
					fmt.sbprintln(f, "};")
					c_display_field(f, t.tag_type, "tag", depth)
				}
				indent(f, depth)
				fmt.sbprintf(f, "}}")
			}
		case runtime.Type_Info_Struct:
			keyw := "union" if .raw_union in t.flags else "struct"

			switch mode {
			case .Typedef:
				fmt.sbprintf(f, "%v %v", keyw, name^)
			case .Decl, .Field:
				if mode == .Field {
					fmt.sbprintfln(f, "%v {{", keyw)
				} else {
					fmt.sbprintfln(f, "%v %v {{", keyw, name^)
					name^ = {}
				}

				custom_layout := .packed in t.flags || .align in t.flags
				offset: uintptr
				for field, i in reflect.struct_fields_zipped(ty.id) {
					if custom_layout &&
					   .raw_union not_in t.flags &&
					   t.offsets[i] > offset {
						indent(f, depth + 1)
						fmt.sbprintfln(
							f,
							"bac_u8 _padding_%v[%v];",
							i,
							t.offsets[i] - offset,
						)
					}
					c_display_field(f, field.type, field.name, depth)
					offset = t.offsets[i] + uintptr(field.type.size)
				}

				indent(f, depth)
				fmt.sbprintf(f, "}}")
				if custom_layout {
					fmt.sbprintf(
						f,
						" __attribute__((packed, aligned(%v)))",
						ty.align,
					)
				}
			}
		case runtime.Type_Info_Bit_Field:
			switch mode {
			case .Typedef:
				fmt.sbprintf(f, "struct %v", name^)
			case .Decl, .Field:
				if mode == .Field {
					fmt.sbprintln(f, "struct {")
				} else {
					fmt.sbprintfln(f, "struct %v {{", name^)
					name^ = {}
				}

				for field in reflect.bit_fields_zipped(ty.id) {
					indent(f, depth + 1)
					name := field.name
					fmt.sbprintf(f, "bac_u%v", ty.size * 8)
					fmt.sbprintfln(f, " %v : %v;", name, field.size)
				}

				indent(f, depth)
				fmt.sbprintf(f, "}}")
				if _, ok := t.backing_type.variant.(runtime.Type_Info_Array);
				   ok {
					fmt.sbprintf(
						f,
						" __attribute__((packed, aligned(%v)))",
						ty.align,
					)
				}
			}
		case runtime.Type_Info_Named:
			switch mode {
			case .Decl, .Typedef:
				c_display_type(f, t.base, mode, name, depth)
			case .Field:
				fmt.sbprint(f, c_type_name(ty))
			}
		case runtime.Type_Info_Integer:
			switch mode {
			case .Decl:
				name^ = {}
			case .Field, .Typedef:
				fmt.sbprintf(f, "bac_%v", ty)
			}
		case runtime.Type_Info_String:
			fmt.sbprintf(f, "bac_String")
		case runtime.Type_Info_Procedure:
			switch mode {
			case .Field, .Typedef:
				params, results := proc_lists(t)
				if 0 < len(results.types) {
					ty := results.types[len(results.types) - 1]
					result_name := ""
					c_display_type(f, ty, .Field, &result_name, depth + 1)
					c_disp_name(f, result_name)
				} else {
					fmt.sbprintf(f, "void")
				}

				fmt.sbprintf(f, " (*%v)(", name^)
				for ty, i in params.types {
					if i != 0 do fmt.sbprint(f, ", ")
					name := ""
					c_display_type(f, ty, .Field, &name, depth + 1)
					c_disp_name(f, name)
				}

				for i in 0 ..< len(results.types) - 1 {
					// NOTE: we dont have zero arg multireturns
					fmt.sbprint(f, ", ")
					name := ""
					c_display_pointer(
						f,
						results.types[i],
						.Field,
						&name,
						depth + 1,
					)
					c_disp_name(f, name)
				}

				fmt.sbprintf(f, ")")
				name^ = {}
			case .Decl:
				name^ = {}
			}
		case runtime.Type_Info_Multi_Pointer:
			c_display_pointer(f, t.elem, mode, name, depth)
		case runtime.Type_Info_Pointer:
			c_display_pointer(f, t.elem, mode, name, depth)
		case:
			fmt.panicf("unhandled type: %v", ty)
		}
	}

	c_display_pointer :: proc(
		f: ^strings.Builder,
		elem: ^runtime.Type_Info,
		mode: Display_Mode,
		name: ^string,
		depth: int,
	) {
		if mode == .Decl {
			name^ = {}
			return
		}
		name^ = fmt.tprintf("*%v", name^)
		if elem == nil {
			fmt.sbprint(f, "void")
		} else {
			#partial switch _ in elem.variant {
			case runtime.Type_Info_Array, runtime.Type_Info_Enumerated_Array:
				name^ = fmt.tprintf("(%v)", name^)
			}
			c_display_type(f, elem, .Field, name, depth)
		}
	}

	proc_lists :: proc(
		sig: runtime.Type_Info_Procedure,
	) -> (
		params, results: runtime.Type_Info_Parameters,
	) {
		if sig.params != nil {
			params = sig.params.variant.(runtime.Type_Info_Parameters)
		}
		if sig.results != nil {
			results = sig.results.variant.(runtime.Type_Info_Parameters)
		}
		return
	}

	c_type_name :: proc(ty: ^runtime.Type_Info) -> string {
		#partial switch t in ty.variant {
		case:
			return ""
		case runtime.Type_Info_Named:
			if _, ok := runtime.type_info_base(ty).variant.(runtime.Type_Info_Bit_Set);
			   ok {
				return fmt.tprintf("%v_Bs_%v", t.pkg, c_type_to_name(t.name))
			}
			return fmt.tprintf("%v_%v", t.pkg, c_type_to_name(t.name))
		case runtime.Type_Info_Struct:
			if t.soa_kind != .None {
				return fmt.tprintf(
					"Soa_%v_Of_%v",
					t.soa_kind,
					c_type_name(t.soa_base_type),
				)
			}
		case runtime.Type_Info_Bit_Set:
			if elem, ok := t.elem.variant.(runtime.Type_Info_Named); ok {
				return fmt.tprintf(
					"%v_Bs_%v",
					elem.pkg,
					c_type_to_name(elem.name),
				)
			}
			return fmt.tprintf(
				"Bs_Bit_Set_Of_%v_%v",
				c_type_name(t.elem),
				ty.size * 8,
			)
		case runtime.Type_Info_Type_Id:
			return "bac_int"
		case runtime.Type_Info_Boolean:
			return "_Bool"
		case runtime.Type_Info_Float:
			return "float" if ty.size == 4 else "double"
		case runtime.Type_Info_Rune:
			return "bac_rune"
		case runtime.Type_Info_String:
			return "bac_String"
		case runtime.Type_Info_Array:
			return fmt.tprintf("Array_Of_%v_%v", t.count, c_type_name(t.elem))
		case runtime.Type_Info_Enumerated_Array:
			return fmt.tprintf("Array_Of_%v_%v", t.count, c_type_name(t.elem))
		case runtime.Type_Info_Slice:
			return fmt.tprintf("Slice_Of_%v", c_type_name(t.elem))
		case runtime.Type_Info_Dynamic_Array:
			return fmt.tprintf("Dyn_Arr_Of_%v", c_type_name(t.elem))
		case runtime.Type_Info_Fixed_Capacity_Dynamic_Array:
			return fmt.tprintf(
				"Fidxe_Cap_Dyn_Arr_Of_%v_%v",
				t.capacity,
				c_type_name(t.elem),
			)
		case runtime.Type_Info_Integer:
			return fmt.tprintf("bac_%v", ty)
		}
		return ""
	}
}
