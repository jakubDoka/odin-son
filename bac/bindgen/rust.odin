package bac_bindgen

import bac_ssa "../ssa"
import "base:runtime"
import "core:fmt"
import "core:os"
import "core:reflect"
import "core:strings"

Rust_Gen :: struct {
	file: ^os.File,
	names: map[typeid]string,
	pending: [dynamic]^runtime.Type_Info,
}

rust_ident :: proc(s: string) -> string {
	if s == "_" || s == "" do return "unused"
	b := strings.builder_make()
	for c in s {
		valid := c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c >= '0' && c <= '9' || c == '_'
		strings.write_byte(&b, u8(c) if valid else '_')
	}
	return fmt.tprintf("r#%v", strings.to_string(b))
}

rust_lists :: proc(sig: runtime.Type_Info_Procedure) -> (params, results: runtime.Type_Info_Parameters) {
	if sig.params != nil do params = sig.params.variant.(runtime.Type_Info_Parameters)
	if sig.results != nil do results = sig.results.variant.(runtime.Type_Info_Parameters)
	return
}

rust_prefix :: proc(path: string, global := false) -> string {
	switch path {
	case "..": return "bac"
	case "../../utils/arna": return "arna"
	case "../ssa", "../regalloc":
		if !global do return "bac"
	}
	return strings.concatenate({"bac_", strings.trim_prefix(path, "../")})
}

rust_type :: proc(g: ^Rust_Gen, ty: ^runtime.Type_Info) -> string {
	if ty == nil do return "core::ffi::c_void"
	if name, ok := g.names[ty.id]; ok do return name
	#partial switch t in ty.variant {
	case runtime.Type_Info_Integer:
		if ty.id == int do return "isize"
		if ty.id == uint || ty.id == uintptr do return "usize"
		return fmt.tprintf("%v%v", "i" if t.signed else "u", ty.size * 8)
	case runtime.Type_Info_Boolean: return "bool"
	case runtime.Type_Info_Rune: return "i32"
	case runtime.Type_Info_Float: return fmt.tprintf("f%v", ty.size * 8)
	case runtime.Type_Info_Type_Id: return "usize"
	case runtime.Type_Info_String: return "String"
	case runtime.Type_Info_Pointer: return fmt.tprintf("*mut %v", rust_type(g, t.elem))
	case runtime.Type_Info_Multi_Pointer: return fmt.tprintf("*mut %v", rust_type(g, t.elem))
	case runtime.Type_Info_Procedure: return "*mut core::ffi::c_void"
	case runtime.Type_Info_Array: return fmt.tprintf("[%v; %v]", rust_type(g, t.elem), t.count)
	case runtime.Type_Info_Enumerated_Array: return fmt.tprintf("[%v; %v]", rust_type(g, t.elem), t.count)
	case runtime.Type_Info_Slice: return fmt.tprintf("Slice<%v>", rust_type(g, t.elem))
	case runtime.Type_Info_Dynamic_Array: return fmt.tprintf("DynamicArray<%v>", rust_type(g, t.elem))
	}
	name := fmt.tprintf("anon_%v", len(g.pending))
	if t, ok := ty.variant.(runtime.Type_Info_Named); ok {
		name = fmt.tprintf("%v_%v", t.pkg, t.name)
		builder := strings.builder_make()
		for c in name {
			valid := c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c >= '0' && c <= '9' || c == '_'
			strings.write_byte(&builder, u8(c) if valid else '_')
		}
		name = strings.to_string(builder)
	}
	g.names[ty.id] = name
	append(&g.pending, ty)
	return name
}

rust_decl :: proc(g: ^Rust_Gen, ty: ^runtime.Type_Info) {
	f := g.file
	name := g.names[ty.id]
	base := runtime.type_info_base(ty)
	#partial switch t in base.variant {
	case runtime.Type_Info_Enum:
		fmt.fprintfln(f, "pub type %v = %v;", name, rust_type(g, t.base))
		for field in reflect.enum_fields_zipped(ty.id) {
			fmt.fprintfln(f, "pub const %v_%v: %v = %v;", name, field.name, name, field.value)
		}
	case runtime.Type_Info_Bit_Set:
		fmt.fprintfln(f, "pub type %v = u%v;", name, ty.size * 8)
	case runtime.Type_Info_Bit_Field:
		fmt.fprintfln(f, "#[repr(C, align(%v))]\n#[derive(Clone, Copy)]\npub struct %v {{ pub bytes: [u8; %v] }}", ty.align, name, ty.size)
		if ty.size <= 8 {
			fmt.fprintfln(f, "impl %v {{", name)
			for field in reflect.bit_fields_zipped(base.id) {
				mask := (u64(1) << field.size) - 1
				fmt.fprintfln(f, "pub fn %v(self) -> u64 {{ let mut b = [0; 8]; b[..%v].copy_from_slice(&self.bytes); (u64::from_le_bytes(b) >> %v) & %v }}", rust_ident(field.name), ty.size, field.offset, mask)
				fmt.fprintfln(f, "pub fn set_%v(&mut self, value: u64) {{ assert!(value <= %v); let mut b = [0; 8]; b[..%v].copy_from_slice(&self.bytes); let bits = (u64::from_le_bytes(b) & !(%vu64 << %v)) | (value << %v); self.bytes.copy_from_slice(&bits.to_le_bytes()[..%v]); }}", field.name, mask, ty.size, mask, field.offset, field.offset, ty.size)
			}
			fmt.fprintln(f, "}")
		}
	case runtime.Type_Info_Struct:
		kind := "union" if .raw_union in t.flags else "struct"
		max_align := 1
		for field in t.types[:t.field_count] do max_align = max(max_align, field.align)
		layout := "packed" if max_align > ty.align else "align"
		fmt.fprintfln(f, "#[repr(C, %v(%v))]\n#[derive(Clone, Copy)]\npub %v %v {{", layout, ty.align, kind, name)
		for field, i in reflect.struct_fields_zipped(base.id) {
			fname := field.name
			if fname == "_" do fname = fmt.tprintf("field_%v", i)
			fmt.fprintfln(f, "pub %v: %v,", rust_ident(fname), rust_type(g, field.type))
		}
		fmt.fprintln(f, "}")
		for field, i in reflect.struct_fields_zipped(base.id) {
			fname := field.name
			if fname == "_" do fname = fmt.tprintf("field_%v", i)
			fmt.fprintfln(f, "const _: () = assert!(core::mem::offset_of!(%v, %v) == %v);", name, rust_ident(fname), t.offsets[i])
		}
	case runtime.Type_Info_Union:
		if t.tag_type == nil {
			fmt.fprintfln(f, "#[repr(C, align(%v))]\n#[derive(Clone, Copy)]\npub union %v {{", ty.align, name)
			for v, i in t.variants do fmt.fprintfln(f, "pub variant_%v: %v,", i, rust_type(g, v))
			fmt.fprintln(f, "}")
		} else {
			fmt.fprintfln(f, "#[repr(C, align(%v))]\n#[derive(Clone, Copy)]\npub struct %v {{ pub payload: [u8; %v], pub tag: %v }}", ty.align, name, t.tag_offset, rust_type(g, t.tag_type))
		}
	case runtime.Type_Info_Fixed_Capacity_Dynamic_Array:
		fmt.fprintfln(f, "#[repr(C, align(%v))]\n#[derive(Clone, Copy)]\npub struct %v {{ pub data: [%v; %v], pub len: isize }}", ty.align, name, rust_type(g, t.elem), t.capacity)
	case:
		fmt.fprintfln(f, "pub type %v = %v;", name, rust_type(g, base))
	}
	fmt.fprintfln(f, "const _: () = assert!(core::mem::size_of::<%v>() == %v);", name, ty.size)
	fmt.fprintfln(f, "const _: () = assert!(core::mem::align_of::<%v>() == %v);", name, ty.align)
}

generate_rust :: proc(api: []API_Proc) {
	err := os.make_directory_all("bac/bindings/rust/src")
	assert(err == nil || err == .Exist)
	f, ferr := os.open("bac/bindings/rust/src/sys.rs", {.Create, .Write, .Trunc})
	assert(ferr == nil)
	defer os.close(f)
	g := Rust_Gen{file = f}
	_ = rust_type(&g, type_info_of(bac_ssa.Node_Type))
	fmt.fprintln(f, `// Generated by odin run bac/bindgen. Do not edit.
#![allow(non_camel_case_types, non_upper_case_globals, non_snake_case, improper_ctypes, clippy::identity_op)]
#[cfg(not(target_endian = "little"))]
compile_error!("BAC Rust bitfield bindings currently require a little-endian target");
#[repr(C)]
#[derive(Clone, Copy)]
pub struct Slice<T> { pub data: *mut T, pub len: isize }
#[repr(C)]
#[derive(Clone, Copy)]
pub struct String { pub data: *mut u8, pub len: isize }
#[repr(C)]
#[derive(Clone, Copy)]
pub struct DynamicArray<T> { pub data: *mut T, pub len: isize, pub cap: isize, pub allocator: runtime_Allocator }
`)
	fmt.fprintln(f, "unsafe extern \"C\" {")
	for entry in api {
		if sig, ok := type_info_of(entry.type).variant.(runtime.Type_Info_Procedure); ok {
			params, results := rust_lists(sig)
			fmt.fprintf(f, "pub fn %v_%v(", rust_prefix(entry.package_path), entry.name)
			for ty, i in params.types do fmt.fprintf(f, "arg%v: %v,", i, rust_type(&g, ty))
			for ty, i in results.types[:max(0, len(results.types) - 1)] do fmt.fprintf(f, "out%v: *mut %v,", i, rust_type(&g, ty))
			fmt.fprintf(f, ")")
			if len(results.types) > 0 do fmt.fprintf(f, " -> %v", rust_type(&g, results.types[len(results.types) - 1]))
			fmt.fprintln(f, ";")
		} else {
			assert(!entry.trhead_local)
			fmt.fprintfln(f, "pub static %v_%v: %v;", rust_prefix(entry.package_path, true), entry.name, rust_type(&g, type_info_of(entry.type)))
		}
	}
	fmt.fprintln(f, "}")
	for i := 0; i < len(g.pending); i += 1 do rust_decl(&g, g.pending[i])
	generate_rust_api(api)
}

Rust_ENUMS :: [?]struct{odin, rust: string}{
	{"bac_Node_Datatype", "Datatype"}, {"bac_ssa_Node_Type", "NodeType"},
	{"bac_Bin_Op", "BinOp"}, {"bac_Un_Op", "UnOp"},
	{"bac_Lane_Type", "Lane"}, {"bac_ssa_Loop_Control", "LoopControl"},
	{"bac_Regalloc_Mode", "RegallocMode"},
}

rust_safe_type :: proc(ty: ^runtime.Type_Info) -> string {
	if t, ok := ty.variant.(runtime.Type_Info_Named); ok {
		name := fmt.tprintf("%v_%v", t.pkg, t.name)
		if name == "bac_Node_ID" do return "NodeId"
		if name == "bac_Node_Type" do return "NodeType"
		for e in Rust_ENUMS do if e.odin == name do return e.rust
		if name == "bac_Call" do return "Call"
		if name == "bac_ssa_If_State" do return "IfState"
		if name == "bac_ssa_Loop_State" do return "LoopState"
		if name == "bac_ssa_Block_State" do return "BlockState"
	}
	#partial switch t in ty.variant {
	case runtime.Type_Info_Integer:
		if ty.id == int do return "isize"
		if ty.id == uint || ty.id == uintptr do return "usize"
		return fmt.tprintf("%v%v", "i" if t.signed else "u", ty.size * 8)
	case runtime.Type_Info_Boolean: return "bool"
	case runtime.Type_Info_String: return "&str"
	case runtime.Type_Info_Slice:
		if rust_safe_type(t.elem) == "NodeId" do return "&[NodeId]"
	case runtime.Type_Info_Pointer:
		elem := rust_safe_type(t.elem)
		if elem == "NodeId" do return "&mut NodeId"
		if elem == "IfState" || elem == "LoopState" || elem == "BlockState" do return fmt.tprintf("&mut %v", elem)
	}
	return ""
}

generate_rust_api :: proc(api: []API_Proc) {
	f, err := os.open("bac/bindings/rust/src/generated.rs", {.Create, .Write, .Trunc})
	assert(err == nil)
	defer os.close(f)
	fmt.fprintln(f, "// Generated by odin run bac/bindgen. Do not edit.\n#![allow(clippy::let_and_return, clippy::let_unit_value, clippy::too_many_arguments)]\nuse crate::*;")
	g: Rust_Gen
	_ = rust_type(&g, type_info_of(bac_ssa.Node_Type))
	for entry in api {
		sig, ok := type_info_of(entry.type).variant.(runtime.Type_Info_Procedure)
		if !ok do continue
		params, _ := rust_lists(sig)
		for ty in params.types do _ = rust_type(&g, ty)
	}
	for e in Rust_ENUMS {
		for ty in g.pending {
			if g.names[ty.id] != e.odin do continue
			fmt.fprintfln(f, "#[repr(transparent)]\n#[derive(Clone, Copy, Debug, PartialEq, Eq)]\npub struct %v(pub(crate) sys::%v);\n#[allow(non_upper_case_globals)]\nimpl %v {{", e.rust, e.odin, e.rust)
			for field in reflect.enum_fields_zipped(ty.id) do fmt.fprintfln(f, "pub const %v: Self = Self(sys::%v_%v);", field.name, e.odin, field.name)
			fmt.fprintln(f, "}")
		}
	}
	for checked in ([?]bool{false, true}) {
		if checked {
			fmt.fprintln(f, "impl Builder<'_, '_> {")
		} else {
			fmt.fprintln(f, "impl Proc<'_> {")
		}
		for entry in api {
			sig, ok := type_info_of(entry.type).variant.(runtime.Type_Info_Procedure)
			if !ok do continue
			params, results := rust_lists(sig)
			if len(params.types) == 0 || rust_type(&g, params.types[0]) != "*mut bac_Proc" do continue
			if entry.name == "start_proc" || entry.name == "compact" do continue
			supported := true
			for ty in params.types[1:] do supported &&= rust_safe_type(ty) != ""
			for ty in results.types do supported &&= rust_safe_type(ty) != "" && rust_safe_type(ty) != "&[NodeId]"
			if !supported do continue
			fmt.fprintf(f, "pub %vfn %v(&mut self", "" if checked else "unsafe ", rust_ident(entry.name))
			for ty, i in params.types[1:] {
				st := rust_safe_type(ty)
				if checked && st == "&str" do st = "&'static str"
				fmt.fprintf(f, ", %v: %v", rust_ident(params.names[i + 1]), st)
			}
			fmt.fprintf(f, ")")
			if len(results.types) == 1 do fmt.fprintf(f, " -> %v", rust_safe_type(results.types[0]))
			if len(results.types) > 1 {
				fmt.fprint(f, " -> (")
				for ty in results.types do fmt.fprintf(f, "%v,", rust_safe_type(ty))
				fmt.fprint(f, ")")
			}
			fmt.fprintln(f, " {")
			for ty, i in params.types[1:] {
				name := rust_ident(params.names[i + 1])
				st := rust_safe_type(ty)
				if checked {
					switch st {
					case "NodeId", "&mut NodeId": fmt.fprintfln(f, "self.check(%v%v);", "*" if st == "&mut NodeId" else "", name)
					case "&[NodeId]": fmt.fprintfln(f, "for &id in %v {{ self.check(id); }}", name)
					case "&mut IfState", "&mut LoopState", "&mut BlockState": fmt.fprintfln(f, "self.check_state(%v);", name)
					}
				}
			}
			if checked {
				fmt.fprint(f, "let result = unsafe { self.proc.")
				fmt.fprintf(f, "%v(", rust_ident(entry.name))
				for _, i in params.types[1:] do fmt.fprintf(f, "%v,", rust_ident(params.names[i + 1]))
				fmt.fprintln(f, ") };")
			} else {
				for ty, i in params.types[1:] {
					if rust_safe_type(ty) == "&str" do fmt.fprintfln(f, "let %v = raw_string(%v);", rust_ident(params.names[i + 1]), rust_ident(params.names[i + 1]))
				}
				for _, i in results.types[:max(0, len(results.types) - 1)] do fmt.fprintfln(f, "let mut out%v = unsafe {{ core::mem::zeroed() }};", i)
				fmt.fprintf(f, "let result = unsafe {{ sys::%v_%v(&mut self.raw,", rust_prefix(entry.package_path), entry.name)
				for ty, i in params.types[1:] {
					name := rust_ident(params.names[i + 1])
					st := rust_safe_type(ty)
					switch st {
					case "&[NodeId]": fmt.fprintf(f, "sys::Slice {{ data: %v.as_ptr().cast_mut().cast(), len: %v.len() as isize }},", name, name)
					case "&str": fmt.fprintf(f, "%v,", name)
					case "&mut NodeId": fmt.fprintf(f, "core::ptr::from_mut(%v).cast(),", name)
					case "&mut IfState", "&mut LoopState", "&mut BlockState": fmt.fprintf(f, "&mut %v.raw,", name)
					case "NodeId", "Datatype", "NodeType", "BinOp", "UnOp", "Lane", "LoopControl", "RegallocMode", "Call": fmt.fprintf(f, "%v.0,", name)
					case: fmt.fprintf(f, "%v,", name)
					}
				}
				for _, i in results.types[:max(0, len(results.types) - 1)] do fmt.fprintf(f, "&mut out%v,", i)
				fmt.fprintln(f, ") };")
				if len(results.types) == 1 && rust_safe_type(results.types[0]) == "NodeId" do fmt.fprintln(f, "let result = NodeId(result);")
				if len(results.types) > 1 {
					fmt.fprint(f, "let result = (")
					for ty, i in results.types {
						expr := fmt.tprintf("out%v", i)
						if i == len(results.types) - 1 do expr = "result"
						if rust_safe_type(ty) == "NodeId" do expr = fmt.tprintf("NodeId(%v)", expr)
						fmt.fprintf(f, "%v,", expr)
					}
					fmt.fprintln(f, ");")
				}
			}
			if checked {
				for ty, i in results.types {
					if rust_safe_type(ty) != "NodeId" do continue
					expr := "result" if len(results.types) == 1 else fmt.tprintf("result.%v", i)
					fmt.fprintfln(f, "self.register(%v);", expr)
				}
				for ty, i in params.types[1:] {
					name := rust_ident(params.names[i + 1])
					st := rust_safe_type(ty)
					if st == "&mut NodeId" do fmt.fprintfln(f, "self.register(*%v);", name)
					if st == "&mut IfState" || st == "&mut LoopState" || st == "&mut BlockState" do fmt.fprintfln(f, "self.register_state(%v);", name)
				}
			}
			fmt.fprintln(f, "result\n}")
		}
		fmt.fprintln(f, "}")
	}
}
