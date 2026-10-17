package bac_bindgen

import "base:runtime"
import "core:fmt"
import "core:os"
import "core:reflect"
import "core:slice"
import "core:strings"

EXPORTED_SUBMODS := [?]string {
	"bac",
	"bac_builder",
	"bac_arm",
	"bac_x64",
	"bac_wasm",
	"bac_regalloc",
}
EXPORTED_SUBMODS_PATH := [?]string {
	"..",
	"../builder",
	"../arm",
	"../x64",
	"../wasm",
	"../regalloc/",
}

API_Proc :: struct {
	package_path: string,
	name:         string,
	type:         typeid,
}

main :: proc() {
	mkerr := os.make_directory("bac/bindgen/lib")
	assert(mkerr == nil || mkerr == .Exist)
	lib, operr := os.open(
		"bac/bindgen/lib/lib.odin",
		flags = {.Read, .Write, .Trunc, .Create},
	)
	assert(operr == nil)

	mkerr = os.make_directory("bac/bindgen/c")
	assert(mkerr == nil || mkerr == .Exist)
	c_lib, c_operr := os.open(
		"bac/bindgen/c/bac.h",
		flags = {.Read, .Write, .Trunc, .Create},
	)
	assert(c_operr == nil)

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

	os.write_string(
		c_lib,
		`
#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>

typedef struct {
	char* data;
	size_t len;
} bac_String;

`,
	)

	for i in 0 ..< 2 {for entry, j in API {
			first_pass := i == 0

			sig := type_info_of(entry.type).variant.(runtime.Type_Info_Procedure)
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

			params, results := proc_lists(sig)

			packag := entry.package_path
			packag = strings.trim_prefix(packag, "..")
			packag = strings.trim_prefix(packag, "/")
			if len(packag) != 0 {
				packag = strings.concatenate({"bac_", packag})
			} else {
				packag = "bac"
			}

			gen_lib: if first_pass {
				fmt.fprintln(lib, `@(export)`)
				fmt.fprintfln(lib, `%v_%v :: proc "c" (`, packag, entry.name)

				for i in 0 ..< len(params.types) {
					name := params.names[i]
					type := params.types[i]

					reflect.qualify = true

					fmt.fprintfln(lib, "\t%v: %T,", name, type)
				}

				fmt.fprintf(lib, `)`)

				if len(results.types) != 0 {
					fmt.fprintfln(lib, " -> (")
					for i in 0 ..< len(results.types) {
						fmt.fprintfln(lib, "\t%T,", results.types[i])
					}
					fmt.fprintf(lib, ")")
				}

				fmt.fprintf(lib, " {{\n\tcontext = {{}}\n\t")
				if len(results.types) != 0 {
					fmt.fprintf(lib, "return ")
				}

				fmt.fprintf(lib, "%v.%v(", packag, entry.name)
				for i in 0 ..< len(params.types) {
					if i != 0 do fmt.fprintf(lib, ", ")
					fmt.fprintf(lib, "%v", params.names[i])
				}
				fmt.fprintfln(lib, ")")

				fmt.fprintfln(lib, "}}\n")
			}

			if first_pass {
				for par in params.types {
					visit(par.id, &types, &seen)
				}
				for result in results.types {
					visit(result.id, &types, &seen)
				}
			}

			visit :: proc(
				ty: typeid,
				coll: ^map[typeid]int,
				seen: ^map[typeid]struct{},
			) -> (
				depth: int,
			) {
				if ty in seen do return coll[ty]
				seen[ty] = {}

				#partial switch t in type_info_of(ty).variant {
				case runtime.Type_Info_Multi_Pointer:
					depth = visit(t.elem.id, coll, seen)
				case runtime.Type_Info_Pointer:
					if t.elem != nil {
						depth = visit(t.elem.id, coll, seen)
					}
				case runtime.Type_Info_Named:
					depth = visit(t.base.id, coll, seen)
				case runtime.Type_Info_Struct:
					for field in t.types[:t.field_count] {
						depth = max(depth, visit(field.id, coll, seen))
					}
				case runtime.Type_Info_Bit_Field:
					depth = visit(t.backing_type.id, coll, seen)
					for field in t.types[:t.field_count] {
						depth = max(depth, visit(field.id, coll, seen))
					}
				case runtime.Type_Info_Union:
					for field in t.variants {
						depth = max(depth, visit(field.id, coll, seen))
					}
					if t.tag_type != nil {
						depth = max(depth, visit(t.tag_type.id, coll, seen))
					}
				case runtime.Type_Info_Slice:
					depth = max(depth, visit(t.elem.id, coll, seen))
				case runtime.Type_Info_Dynamic_Array:
					depth = max(depth, visit(t.elem.id, coll, seen))
					depth = max(
						depth,
						visit(runtime.Raw_Dynamic_Array, coll, seen),
					)
				case runtime.Type_Info_Array:
					depth = max(depth, visit(t.elem.id, coll, seen))
				case runtime.Type_Info_Fixed_Capacity_Dynamic_Array:
					depth = max(depth, visit(t.elem.id, coll, seen))
				case runtime.Type_Info_Integer,
				     runtime.Type_Info_Float,
				     runtime.Type_Info_Rune,
				     runtime.Type_Info_Type_Id,
				     runtime.Type_Info_String,
				     runtime.Type_Info_Boolean:
				case runtime.Type_Info_Procedure:
					params, results := proc_lists(t)
					for ty in params.types {
						depth = max(depth, visit(ty.id, coll, seen))
					}
					for ty in results.types {
						depth = max(depth, visit(ty.id, coll, seen))
					}
				case runtime.Type_Info_Enumerated_Array:
					depth = max(depth, visit(t.elem.id, coll, seen))
					depth = max(depth, visit(t.index.id, coll, seen))
				case runtime.Type_Info_Bit_Set:
					depth = max(depth, visit(t.elem.id, coll, seen))
					if t.underlying != nil {
						depth = max(depth, visit(t.underlying.id, coll, seen))
					}
				case runtime.Type_Info_Enum:
					depth = max(depth, visit(t.base.id, coll, seen))
				case:
					fmt.panicf("unhandled type: %v", t)
				}

				depth += 1
				coll[ty] = depth

				return
			}

			type_to_name :: proc(
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

			indent :: proc(f: ^os.File, depth: int) {
				for _ in 0 ..< depth {
					os.write_byte(f, '\t')
				}
			}

			Display_Mode :: enum {
				Field,
				Typedef,
				Decl,
			}

			disp_name :: proc(f: ^os.File, name: string) {
				@(static) anon_idx := 0

				if name == "_" {
					fmt.fprintf(f, " _%v", anon_idx)
					anon_idx += 1
				} else if name != "" {
					fmt.fprintf(f, " %v", name)
				}
			}

			display_field :: proc(
				f: ^os.File,
				ty: ^runtime.Type_Info,
				name: string,
				depth: int,
			) {
				indent(f, depth + 1)
				name := type_to_name(name)
				display_type(f, ty, .Field, &name, depth + 1)
				disp_name(f, name)
				fmt.fprintfln(f, ";")
			}

			display_type :: proc(
				f: ^os.File,
				ty: ^runtime.Type_Info,
				mode: Display_Mode,
				name: ^string,
				depth: int,
			) {
				#partial switch t in ty.variant {
				case runtime.Type_Info_Boolean:
					switch mode {
					case .Field, .Typedef:
						fmt.fprint(f, "bool")
					case .Decl:
						name^ = {}
					}
				case runtime.Type_Info_Array:
					if mode == .Decl {
						name^ = {}
					} else {
						name^ = fmt.tprintf("%v[%v]", name^, t.count)
						display_type(f, t.elem, .Field, name, depth)
					}
				case runtime.Type_Info_Enumerated_Array:
					if mode == .Decl {
						name^ = {}
					} else {
						name^ = fmt.tprintf("%v[%v]", name^, t.count)
						display_type(f, t.elem, .Field, name, depth)
					}
				case runtime.Type_Info_Fixed_Capacity_Dynamic_Array:
					switch mode {
					case .Typedef:
						fmt.fprint(f, "struct", name^)
					case .Field:
						fmt.fprint(f, type_name(ty))
					case .Decl:
						fmt.fprintfln(f, "struct %v {{", name^)
						info: runtime.Type_Info
						info.variant = runtime.Type_Info_Array {
							elem  = t.elem,
							count = t.capacity,
						}
						display_field(f, &info, "data", depth)
						padding := int(t.len_offset) - t.capacity * t.elem_size
						if padding > 0 {
							indent(f, depth + 1)
							fmt.fprintfln(f, "uint8_t _padding[%v];", padding)
						}
						indent(f, depth + 1)
						fmt.fprintln(f, "intptr_t len;")
						indent(f, depth)
						fmt.fprintf(f, "}}")
						name^ = {}
					}
				case runtime.Type_Info_Bit_Set:
					if mode == .Decl {
						name^ = {}
					} else {
						fmt.fprintf(f, "uint%v_t", ty.size * 8)
					}
				case runtime.Type_Info_Type_Id:
					if mode == .Decl {
						name^ = {}
					} else {
						fmt.fprintf(f, "uintptr_t")
					}
				case runtime.Type_Info_Float:
					if mode == .Decl {
						name^ = {}
					} else {
						assert(ty.size == 4 || ty.size == 8)
						fmt.fprintf(
							f,
							"%v",
							"float" if ty.size == 4 else "double",
						)
					}
				case runtime.Type_Info_Rune:
					if mode == .Decl {
						name^ = {}
					} else {
						fmt.fprintf(f, "int32_t")
					}
				case runtime.Type_Info_Slice:
					switch mode {
					case .Typedef:
						fmt.fprint(f, "struct", type_name(ty))
					case .Field:
						fmt.fprint(f, type_name(ty))
					case .Decl:
						fmt.fprintfln(f, `struct %v {{`, name^)
						info: runtime.Type_Info
						info.variant = runtime.Type_Info_Pointer {
							elem = t.elem,
						}
						display_field(f, &info, "data", depth)
						fmt.fprintln(f, "\tsize_t len;\n};")
						name^ = {}
					}
				case runtime.Type_Info_Dynamic_Array:
					switch mode {
					case .Typedef:
						fmt.fprint(f, "struct", type_name(ty))
					case .Field:
						fmt.fprint(f, type_name(ty))
					case .Decl:
						fmt.fprintfln(f, `struct %v {{`, name^)
						info: runtime.Type_Info
						info.variant = runtime.Type_Info_Pointer {
							elem = t.elem,
						}
						display_field(f, &info, "data", depth)
						fmt.fprintln(f, "\tsize_t len, cap;")
						fmt.fprintln(f, "\truntime_Allocator allocator;")
						fmt.fprintln(f, "};")
						name^ = {}
					}
				case runtime.Type_Info_Enum:
					switch mode {
					case .Field:
						display_type(f, t.base, mode, name, depth)
					case .Typedef:
						display_type(f, t.base, mode, name, depth)
					case .Decl:
						fmt.fprintln(f, "enum {")

						for field in reflect.enum_fields_zipped(ty.id) {
							indent(f, depth + 1)
							fmt.fprintfln(
								f,
								"%v_%v = %v,",
								name^,
								field.name,
								field.value,
							)
						}

						indent(f, depth)
						fmt.fprintf(f, "}}")
						name^ = {}
					}
				case runtime.Type_Info_Union:
					keyw := "struct" if t.tag_type != nil else "union"
					switch mode {
					case .Typedef:
						fmt.fprintf(f, "%v %v", keyw, name^)
					case .Decl, .Field:
						if mode == .Field {
							fmt.fprintfln(f, "%v {{", keyw)
						} else {
							fmt.fprintfln(f, "%v %v {{", keyw, name^)
							name^ = {}
						}
						if t.tag_type != nil {
							indent(f, depth + 1)
							fmt.fprintln(f, "union {")
						}
						payload_depth := depth + int(t.tag_type != nil)
						for variant, i in t.variants {
							display_field(
								f,
								variant,
								fmt.tprintf("variant_%v", i),
								payload_depth,
							)
						}
						if t.tag_type != nil {
							indent(f, payload_depth + 1)
							fmt.fprintfln(
								f,
								"uint8_t _payload[%v];",
								t.tag_offset,
							)
							indent(f, depth + 1)
							fmt.fprintln(f, "};")
							display_field(f, t.tag_type, "tag", depth)
						}
						indent(f, depth)
						fmt.fprintf(f, "}}")
					}
				case runtime.Type_Info_Struct:
					keyw := "union" if .raw_union in t.flags else "struct"

					switch mode {
					case .Typedef:
						fmt.fprintf(f, "%v %v", keyw, name^)
					case .Decl, .Field:
						if mode == .Field {
							fmt.fprintfln(f, "%v {{", keyw)
						} else {
							fmt.fprintfln(f, "%v %v {{", keyw, name^)
							name^ = {}
						}

						custom_layout :=
							.packed in t.flags || .align in t.flags
						offset: uintptr
						for field, i in reflect.struct_fields_zipped(ty.id) {
							if custom_layout &&
							   .raw_union not_in t.flags &&
							   t.offsets[i] > offset {
								indent(f, depth + 1)
								fmt.fprintfln(
									f,
									"uint8_t _padding_%v[%v];",
									i,
									t.offsets[i] - offset,
								)
							}
							display_field(f, field.type, field.name, depth)
							offset = t.offsets[i] + uintptr(field.type.size)
						}

						indent(f, depth)
						fmt.fprintf(f, "}}")
						if custom_layout {
							fmt.fprintf(
								f,
								" __attribute__((packed, aligned(%v)))",
								ty.align,
							)
						}
					}
				case runtime.Type_Info_Bit_Field:
					switch mode {
					case .Typedef:
						fmt.fprintf(f, "struct %v", name^)
					case .Decl, .Field:
						if mode == .Field {
							fmt.fprintln(f, "struct {")
						} else {
							fmt.fprintfln(f, "struct %v {{", name^)
							name^ = {}
						}

						for field in reflect.bit_fields_zipped(ty.id) {
							indent(f, depth + 1)
							name := field.name
							fmt.fprintf(f, "uint%v_t", ty.size * 8)
							fmt.fprintfln(f, " %v : %v;", name, field.size)
						}

						indent(f, depth)
						fmt.fprintf(f, "}}")
						if _, ok := t.backing_type.variant.(runtime.Type_Info_Array);
						   ok {
							fmt.fprintf(
								f,
								" __attribute__((packed, aligned(%v)))",
								ty.align,
							)
						}
					}
				case runtime.Type_Info_Named:
					switch mode {
					case .Decl, .Typedef:
						display_type(f, t.base, mode, name, depth)
					case .Field:
						fmt.fprintf(f, "%v_%v", t.pkg, type_to_name(t.name))
					}
				case runtime.Type_Info_Integer:
					switch mode {
					case .Decl:
						name^ = {}
					case .Field, .Typedef:
						fmt.fprintf(
							f,
							"%v%v_t",
							"int" if t.signed else "uint",
							ty.size * 8,
						)
					}
				case runtime.Type_Info_String:
					fmt.fprintf(f, "bac_String")
				case runtime.Type_Info_Procedure:
					switch mode {
					case .Field, .Typedef:
						params, results := proc_lists(t)
						if 0 < len(results.types) {
							ty := results.types[len(results.types) - 1]
							result_name := ""
							display_type(
								f,
								ty,
								.Field,
								&result_name,
								depth + 1,
							)
							disp_name(f, result_name)
						} else {
							fmt.fprintf(f, "void ")
						}

						fmt.fprintf(f, "(*%v)(", name^)
						for ty, i in params.types {
							if i != 0 do fmt.fprint(f, ", ")
							name := ""
							display_type(f, ty, .Field, &name, depth + 1)
							disp_name(f, name)
						}

						for i in 0 ..< len(results.types) - 1 {
							// NOTE: we dont have zero arg multireturns
							fmt.fprint(f, ", ")
							name := ""
							display_pointer(
								f,
								results.types[i],
								.Field,
								&name,
								depth + 1,
							)
							disp_name(f, name)
						}

						fmt.fprintf(f, ")")
						name^ = {}
					case .Decl:
						name^ = {}
					}
				case runtime.Type_Info_Multi_Pointer:
					display_pointer(f, t.elem, mode, name, depth)
				case runtime.Type_Info_Pointer:
					display_pointer(f, t.elem, mode, name, depth)
				case:
					fmt.panicf("unhandled type: %v", ty)
				}
			}

			display_pointer :: proc(
				f: ^os.File,
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
					fmt.fprint(f, "void")
				} else {
					#partial switch _ in elem.variant {
					case runtime.Type_Info_Array,
					     runtime.Type_Info_Enumerated_Array:
						name^ = fmt.tprintf("(%v)", name^)
					}
					display_type(f, elem, .Field, name, depth)
				}
			}

			type_name :: proc(ty: ^runtime.Type_Info) -> string {
				#partial switch t in ty.variant {
				case:
					return ""
				case runtime.Type_Info_Named:
					return fmt.tprintf("%v_%v", t.pkg, type_to_name(t.name))
				case runtime.Type_Info_Struct:
					if t.soa_kind != .None {
						return fmt.tprintf(
							"Soa_%v_Of_%v",
							t.soa_kind,
							type_name(t.soa_base_type),
						)
					}
				case runtime.Type_Info_Bit_Set:
					return fmt.tprintf(
						"Bit_Set_Of_%v_%v",
						type_name(t.elem),
						ty.size * 8,
					)
				case runtime.Type_Info_Type_Id:
					return "uintptr_t"
				case runtime.Type_Info_Boolean:
					return "bool"
				case runtime.Type_Info_Float:
					return "float" if ty.size == 4 else "double"
				case runtime.Type_Info_Rune:
					return "int32_t"
				case runtime.Type_Info_String:
					return "bac_String"
				case runtime.Type_Info_Array:
					return fmt.tprintf(
						"Array_Of_%v_%v",
						t.count,
						type_name(t.elem),
					)
				case runtime.Type_Info_Enumerated_Array:
					return fmt.tprintf(
						"Array_Of_%v_%v",
						t.count,
						type_name(t.elem),
					)
				case runtime.Type_Info_Slice:
					return fmt.tprintf("Slice_Of_%v", type_name(t.elem))
				case runtime.Type_Info_Dynamic_Array:
					return fmt.tprintf("Dyn_Arr_Of_%v", type_name(t.elem))
				case runtime.Type_Info_Fixed_Capacity_Dynamic_Array:
					return fmt.tprintf(
						"Fidxe_Cap_Dyn_Arr_Of_%v_%v",
						t.capacity,
						type_name(t.elem),
					)
				case runtime.Type_Info_Integer:
					return fmt.tprintf(
						"%v%v_t",
						"int" if t.signed else "uint",
						ty.size * 8,
					)
				}
				return ""
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
					name := type_name(type_info_of(ty))
					if name != "" && name not_in typedefs {
						typedefs[name] = {}
						fmt.fprintf(c_lib, "typedef ")
						display_type(
							c_lib,
							type_info_of(ty),
							.Typedef,
							&name,
							0,
						)

						disp_name(c_lib, name)
						fmt.fprintfln(c_lib, ";")
					}
				}

				slice.sort_by(
					ents[:],
					proc(a, b: Entry) -> bool {return a.depth < b.depth},
				)

				decls: map[string]struct{}
				for ent in ents {
					ty := ent.type
					name := type_name(type_info_of(ty))
					if name != "" && name in typedefs && name not_in decls {
						decls[name] = {}
						display_type(c_lib, type_info_of(ty), .Decl, &name, 0)
						disp_name(c_lib, name)
						fmt.fprintfln(c_lib, ";")
					}
				}
			}

		}
	}

}
