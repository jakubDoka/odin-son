package bac_bindgen

import bac_ssa "../ssa"
import "base:runtime"
import "core:fmt"
import "core:os"
import "core:reflect"
import "core:strings"

Rust_Gen :: struct {
	file:    ^os.File,
	names:   map[typeid]string,
	pending: [dynamic]^runtime.Type_Info,
}

rust_ident :: proc(s: string) -> string {
	if s == "_" || s == "" do return "unused"
	b := strings.builder_make()
	for c in s {
		valid :=
			c >= 'a' && c <= 'z' ||
			c >= 'A' && c <= 'Z' ||
			c >= '0' && c <= '9' ||
			c == '_'
		strings.write_byte(&b, u8(c) if valid else '_')
	}
	return fmt.tprintf("r#%v", strings.to_string(b))
}

rust_lists :: proc(
	sig: runtime.Type_Info_Procedure,
) -> (
	params, results: runtime.Type_Info_Parameters,
) {
	if sig.params != nil do params = sig.params.variant.(runtime.Type_Info_Parameters)
	if sig.results != nil do results = sig.results.variant.(runtime.Type_Info_Parameters)
	return
}

rust_prefix :: proc(path: string, global := false) -> string {
	switch path {
	case "..":
		return "bac"
	case "../../utils/arna":
		return "arna"
	case "../ssa", "../regalloc":
		if !global do return "bac"
	}
	return strings.concatenate({"bac_", strings.trim_prefix(path, "../")})
}

rust_type :: proc(g: ^Rust_Gen, ty: ^runtime.Type_Info, hint := "") -> string {
	if ty == nil do return "core::ffi::c_void"
	if name, ok := g.names[ty.id]; ok do return name
	#partial switch t in ty.variant {
	case runtime.Type_Info_Integer:
		if ty.id == int do return "isize"
		if ty.id == uint || ty.id == uintptr do return "usize"
		return fmt.tprintf("%v%v", "i" if t.signed else "u", ty.size * 8)
	case runtime.Type_Info_Boolean:
		return "bool"
	case runtime.Type_Info_Rune:
		return "i32"
	case runtime.Type_Info_Float:
		return fmt.tprintf("f%v", ty.size * 8)
	case runtime.Type_Info_Type_Id:
		return "usize"
	case runtime.Type_Info_String:
		return "String"
	case runtime.Type_Info_Pointer:
		return fmt.tprintf("*mut %v", rust_type(g, t.elem, hint))
	case runtime.Type_Info_Multi_Pointer:
		return fmt.tprintf("*mut %v", rust_type(g, t.elem, hint))
	case runtime.Type_Info_Procedure:
		return "*mut core::ffi::c_void"
	case runtime.Type_Info_Array:
		return fmt.tprintf("[%v; %v]", rust_type(g, t.elem, hint), t.count)
	case runtime.Type_Info_Enumerated_Array:
		return fmt.tprintf("[%v; %v]", rust_type(g, t.elem, hint), t.count)
	case runtime.Type_Info_Slice:
		return fmt.tprintf("Slice<%v>", rust_type(g, t.elem, hint))
	case runtime.Type_Info_Dynamic_Array:
		return fmt.tprintf("DynamicArray<%v>", rust_type(g, t.elem, hint))
	case runtime.Type_Info_Fixed_Capacity_Dynamic_Array:
		return fmt.tprintf(
			"FixedCapDynArray<%v, %v>",
			t.capacity,
			rust_type(g, t.elem, hint),
		)
	}
	name := hint
	if t, ok := ty.variant.(runtime.Type_Info_Named); ok {
		name = fmt.tprintf("%v_%v", t.pkg, t.name)
		builder := strings.builder_make()
		for c in name {
			valid :=
				c >= 'a' && c <= 'z' ||
				c >= 'A' && c <= 'Z' ||
				c >= '0' && c <= '9' ||
				c == '_'
			strings.write_byte(&builder, u8(c) if valid else '_')
		}
		name = strings.to_string(builder)
	}
	name = strings.trim_prefix(name, "bac_")
	assert(name != "", "anonymous Rust types require a parent name")
	g.names[ty.id] = name
	append(&g.pending, ty)
	return name
}

rust_default :: proc(f: ^os.File, name: string, generics := "") {
	fmt.fprintfln(
		f,
		"impl%v Default for %v {{ fn default() -> Self {{ unsafe {{ core::mem::zeroed() }} }} }}",
		generics,
		name,
	)
}

rust_decl :: proc(g: ^Rust_Gen, ty: ^runtime.Type_Info) {
	f := g.file
	name := g.names[ty.id]
	base := runtime.type_info_base(ty)
	#partial switch t in base.variant {
	case runtime.Type_Info_Enum:
		fmt.fprintfln(f, "pub type %v = %v;", name, rust_type(g, t.base))
		for field in reflect.enum_fields_zipped(ty.id) {
			fmt.fprintfln(
				f,
				"pub const %v_%v: %v = %v;",
				name,
				field.name,
				name,
				field.value,
			)
		}
	case runtime.Type_Info_Bit_Set:
		fmt.fprintfln(f, "pub type %v = u%v;", name, ty.size * 8)
	case runtime.Type_Info_Bit_Field:
		fmt.fprintfln(
			f,
			"#[repr(C, align(%v))]\n#[derive(Clone, Copy)]\npub struct %v {{ pub bytes: [u8; %v] }}",
			ty.align,
			name,
			ty.size,
		)
		if ty.size <= 8 {
			fmt.fprintfln(f, "impl %v {{", name)
			for field in reflect.bit_fields_zipped(base.id) {
				mask := (u64(1) << field.size) - 1
				fmt.fprintfln(
					f,
					"pub fn %v(self) -> u64 {{ let mut b = [0; 8]; b[..%v].copy_from_slice(&self.bytes); (u64::from_le_bytes(b) >> %v) & %v }}",
					rust_ident(field.name),
					ty.size,
					field.offset,
					mask,
				)
				fmt.fprintfln(
					f,
					"pub fn set_%v(&mut self, value: u64) {{ assert!(value <= %v); let mut b = [0; 8]; b[..%v].copy_from_slice(&self.bytes); let bits = (u64::from_le_bytes(b) & !(%vu64 << %v)) | (value << %v); self.bytes.copy_from_slice(&bits.to_le_bytes()[..%v]); }}",
					field.name,
					mask,
					ty.size,
					mask,
					field.offset,
					field.offset,
					ty.size,
				)
			}
			fmt.fprintln(f, "}")
		}
	case runtime.Type_Info_Struct:
		kind := "union" if .raw_union in t.flags else "struct"
		max_align := 1
		for field in t.types[:t.field_count] do max_align = max(max_align, field.align)
		layout := "packed" if max_align > ty.align else "align"
		fmt.fprintfln(
			f,
			"#[repr(C, %v(%v))]\n#[derive(Clone, Copy)]\npub %v %v {{",
			layout,
			ty.align,
			kind,
			name,
		)
		for field, i in reflect.struct_fields_zipped(base.id) {
			fname := field.name
			if fname == "_" do fname = fmt.tprintf("field_%v", i)
			fmt.fprintfln(
				f,
				"pub %v: %v,",
				rust_ident(fname),
				rust_type(g, field.type, fmt.tprintf("%v_%v", name, fname)),
			)
		}
		fmt.fprintln(f, "}")
		for field, i in reflect.struct_fields_zipped(base.id) {
			fname := field.name
			if fname == "_" do fname = fmt.tprintf("field_%v", i)
			fmt.fprintfln(
				f,
				"const _: () = assert!(core::mem::offset_of!(%v, %v) == %v);",
				name,
				rust_ident(fname),
				t.offsets[i],
			)
		}
	case runtime.Type_Info_Union:
		if t.tag_type == nil {
			fmt.fprintfln(
				f,
				"#[repr(C, align(%v))]\n#[derive(Clone, Copy)]\npub union %v {{",
				ty.align,
				name,
			)
			for v, i in t.variants do fmt.fprintfln(f, "pub variant_%v: %v,", i, rust_type(g, v, fmt.tprintf("%v_variant_%v", name, i)))
			fmt.fprintln(f, "}")
		} else {
			fmt.fprintfln(
				f,
				"#[repr(C, align(%v))]\n#[derive(Clone, Copy)]\npub struct %v {{ pub payload: [u8; %v], pub tag: %v }}",
				ty.align,
				name,
				t.tag_offset,
				rust_type(g, t.tag_type),
			)
		}
	case runtime.Type_Info_Fixed_Capacity_Dynamic_Array:
		fmt.fprintfln(
			f,
			"pub type %v = FixedCapDynArray<%v, %v>;",
			name,
			t.capacity,
			rust_type(g, t.elem, name),
		)
	case:
		fmt.fprintfln(f, "pub type %v = %v;", name, rust_type(g, base))
	}
	#partial switch _ in base.variant {
	case runtime.Type_Info_Bit_Field,
	     runtime.Type_Info_Struct,
	     runtime.Type_Info_Union:
		rust_default(f, name)
	}
	fmt.fprintfln(
		f,
		"const _: () = assert!(core::mem::size_of::<%v>() == %v);",
		name,
		ty.size,
	)
	fmt.fprintfln(
		f,
		"const _: () = assert!(core::mem::align_of::<%v>() == %v);",
		name,
		ty.align,
	)
}

generate_rust :: proc(api: []API_Proc) {
	err := os.make_directory_all("bac/bindgen/rust/src")
	assert(err == nil || err == .Exist)
	f, ferr := os.open("bac/bindgen/rust/src/sys.rs", {.Create, .Write, .Trunc})
	assert(ferr == nil)
	defer os.close(f)
	g := Rust_Gen {
		file = f,
	}
	_ = rust_type(&g, type_info_of(bac_ssa.Node_Type))
	fmt.fprintln(
		f,
		`// Generated by odin run bac/bindgen. Do not edit.
#![allow(non_camel_case_types, non_upper_case_globals, non_snake_case, improper_ctypes, clippy::identity_op)]
pub use crate::FixedCapDynArray;
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
`,
	)
	rust_default(f, "Slice<T>", "<T>")
	rust_default(f, "String")
	rust_default(f, "DynamicArray<T>", "<T>")
	fmt.fprintln(f, "unsafe extern \"C\" {")
	for entry in api {
		if sig, ok := type_info_of(entry.type).variant.(runtime.Type_Info_Procedure);
		   ok {
			params, results := rust_lists(sig)
			fmt.fprintf(
				f,
				"pub fn %v_%v(",
				rust_prefix(entry.package_path),
				entry.name,
			)
			for ty, i in params.types do fmt.fprintf(f, "%v: %v,", rust_ident(params.names[i]), rust_type(&g, ty, fmt.tprintf("%v_%v_%v", rust_prefix(entry.package_path), entry.name, params.names[i])))
			for ty, i in results.types[:max(0, len(results.types) - 1)] do fmt.fprintf(f, "out%v: *mut %v,", i, rust_type(&g, ty, fmt.tprintf("%v_%v_out%v", rust_prefix(entry.package_path), entry.name, i)))
			fmt.fprintf(f, ")")
			if len(results.types) > 0 do fmt.fprintf(f, " -> %v", rust_type(&g, results.types[len(results.types) - 1], fmt.tprintf("%v_%v_result", rust_prefix(entry.package_path), entry.name)))
			fmt.fprintln(f, ";")
		} else {
			fmt.fprintfln(
				f,
				"pub static %v_%v: %v;",
				rust_prefix(entry.package_path, true),
				entry.name,
				rust_type(&g, type_info_of(entry.type)),
			)
		}
	}
	fmt.fprintln(f, "}")
	for i := 0; i < len(g.pending); i += 1 do rust_decl(&g, g.pending[i])
	generate_rust_api(api)
	format: os.Process_Desc
	format.command = {
		"rustfmt",
		"--edition",
		"2024",
		"bac/bindgen/rust/src/sys.rs",
		"bac/bindgen/rust/src/generated.rs",
	}
	state, _, stderr, format_err := os.process_exec(
		format,
		context.temp_allocator,
	)
	fmt.assertf(
		format_err == nil && state.exit_code == 0,
		"rustfmt failed: %v %s",
		format_err,
		stderr,
	)
}

Rust_ENUMS :: [?]struct {
	odin, rust: string,
} {
	{"bac_Node_Datatype", "Datatype"},
	{"bac_ssa_Node_Type", "NodeType"},
	{"bac_Bin_Op", "BinOp"},
	{"bac_Un_Op", "UnOp"},
	{"bac_Lane_Type", "Lane"},
	{"bac_ssa_Loop_Control", "LoopControl"},
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
	case runtime.Type_Info_Boolean:
		return "bool"
	case runtime.Type_Info_String:
		return "&str"
	case runtime.Type_Info_Slice:
		if rust_safe_type(t.elem) == "NodeId" do return "&[NodeId]"
	case runtime.Type_Info_Pointer:
		elem := rust_safe_type(t.elem)
		if elem == "NodeId" do return "&mut NodeId"
		if elem == "IfState" || elem == "LoopState" || elem == "BlockState" do return fmt.tprintf("&mut %v", elem)
	}
	return ""
}

rust_api_type :: proc(st: string, checked: bool) -> string {
	switch st {
	case "NodeId":
		if checked do return "&Node"
	case "&mut NodeId":
		if checked do return "&mut &'p Node"
	case "&[NodeId]":
		if checked do return "&[&Node]"
	case "&str":
		if checked do return "&'static str"
	case "&mut IfState":
		return "&mut sys::ssa_If_State"
	case "&mut LoopState":
		return "&mut sys::ssa_Loop_State"
	case "&mut BlockState":
		return "&mut sys::ssa_Block_State"
	}
	return st
}

generate_rust_api :: proc(api: []API_Proc) {
	f, err := os.open(
		"bac/bindgen/rust/src/generated.rs",
		{.Create, .Write, .Trunc},
	)
	assert(err == nil)
	defer os.close(f)
	fmt.fprintln(
		f,
		"// Generated by odin run bac/bindgen. Do not edit.\n#![allow(clippy::let_and_return, clippy::let_unit_value, clippy::too_many_arguments)]\nuse crate::*;",
	)
	g: Rust_Gen
	_ = rust_type(&g, type_info_of(bac_ssa.Node_Type))
	for entry in api {
		sig, ok := type_info_of(entry.type).variant.(runtime.Type_Info_Procedure)
		if !ok do continue
		params, _ := rust_lists(sig)
		for ty, i in params.types do _ = rust_type(&g, ty, fmt.tprintf("%v_%v_%v", rust_prefix(entry.package_path), entry.name, params.names[i]))
	}
	for e in Rust_ENUMS {
		name := strings.trim_prefix(e.odin, "bac_")
		for ty in g.pending {
			if g.names[ty.id] != name do continue
			zero_valid := false
			for field in reflect.enum_fields_zipped(ty.id) do zero_valid ||= field.value == 0
			fmt.fprintfln(
				f,
				"#[repr(transparent)]\n#[derive(Clone, Copy, Debug, PartialEq, Eq%v)]\npub struct %v(pub(crate) sys::%v);\n#[allow(non_upper_case_globals)]\nimpl %v {{",
				", Default" if zero_valid else "",
				e.rust,
				name,
				e.rust,
			)
			for field in reflect.enum_fields_zipped(ty.id) do fmt.fprintfln(f, "pub const %v: Self = Self(sys::%v_%v);", field.name, name, field.name)
			fmt.fprintln(f, "}")
		}
	}
	for receiver in ([?]string {
			"Proc",
			"Builder",
			"IfState",
			"LoopState",
			"BlockState",
		}) {
		checked := receiver != "Proc"
		state_receiver := checked && receiver != "Builder"
		if state_receiver {
			fmt.fprintfln(f, "impl<'p, 'a> %v<'p, 'a> {{", receiver)
		} else {
			fmt.fprintfln(f, "impl %v<'_> {{", receiver)
		}
		for entry in api {
			sig, ok := type_info_of(entry.type).variant.(runtime.Type_Info_Procedure)
			if !ok do continue
			params, results := rust_lists(sig)
			if len(params.types) == 0 || rust_type(&g, params.types[0]) != "*mut Proc" do continue
			if entry.name == "start_proc" || entry.name == "compact" do continue
			supported := true
			for ty in params.types[1:] do supported &&= rust_safe_type(ty) != ""
			for ty in results.types do supported &&= rust_safe_type(ty) != "" && rust_safe_type(ty) != "&[NodeId]"
			if !supported do continue
			state_index := -1
			state_type := ""
			for ty, i in params.types[1:] {
				st := rust_safe_type(ty)
				if st == "&mut IfState" ||
				   st == "&mut LoopState" ||
				   st == "&mut BlockState" {
					state_index = i
					state_type = strings.trim_prefix(st, "&mut ")
				}
			}
			if checked {
				if state_receiver {
					if state_type != receiver do continue
				} else if state_index != -1 do continue
			}
			mut_node := false
			for ty in params.types[1:] do mut_node ||= rust_safe_type(ty) == "&mut NodeId"
			borrow := checked && mut_node && !state_receiver
			self_borrow := "mut " if state_receiver else ("'p " if borrow else "")
			fmt.fprintf(
				f,
				"pub %vfn %v%v(&%vself",
				"" if checked else "unsafe ",
				rust_ident(entry.name),
				"<'p>" if borrow else "",
				self_borrow,
			)
			for ty, i in params.types[1:] {
				if state_receiver && i == state_index do continue
				st := rust_api_type(rust_safe_type(ty), checked)
				fmt.fprintf(f, ", %v: %v", rust_ident(params.names[i + 1]), st)
			}
			fmt.fprintf(f, ")")
			if len(results.types) == 1 do fmt.fprintf(f, " -> %v", rust_api_type(rust_safe_type(results.types[0]), checked))
			if len(results.types) > 1 {
				fmt.fprint(f, " -> (")
				for ty in results.types do fmt.fprintf(f, "%v,", rust_api_type(rust_safe_type(ty), checked))
				fmt.fprint(f, ")")
			}
			fmt.fprintln(f, " {")
			for ty, i in params.types[1:] {
				if state_receiver && i == state_index do continue
				name := rust_ident(params.names[i + 1])
				st := rust_safe_type(ty)
				if checked {
					checker := "self.proc" if state_receiver else "self"
					switch st {
					case "NodeId":
						fmt.fprintfln(f, "let %v = %v.check(%v);", name, checker, name)
					case "&mut NodeId":
						fmt.fprintfln(
							f,
							"let mut %v_id = %v.check(%v);",
							name,
							checker,
							name,
						)
					}
				}
			}
			if checked {
				for ty, i in params.types[1:] {
					if rust_safe_type(ty) != "&[NodeId]" do continue
					name := rust_ident(params.names[i + 1])
					fmt.fprintfln(f, "self.proc.with_node_ids(%v, |%v| {{", name, name)
				}
				fmt.fprint(f, "let result = unsafe { self.proc.")
				fmt.fprintf(f, "%v(", rust_ident(entry.name))
				for ty, i in params.types[1:] {
					name := rust_ident(params.names[i + 1])
					if state_receiver && i == state_index {
						fmt.fprint(f, "&mut self.raw,")
					} else if rust_safe_type(ty) == "&mut NodeId" {
						fmt.fprintf(f, "&mut %v_id,", name)
					} else {
						fmt.fprintf(f, "%v,", name)
					}
				}
				fmt.fprintln(f, ") };")
			} else {
				for _, i in results.types[:max(0, len(results.types) - 1)] do fmt.fprintfln(f, "let mut out%v = Default::default();", i)
				fmt.fprintf(
					f,
					"let result = unsafe {{ sys::%v_%v(self.raw_ptr(),",
					rust_prefix(entry.package_path),
					entry.name,
				)
				for ty, i in params.types[1:] {
					name := rust_ident(params.names[i + 1])
					st := rust_safe_type(ty)
					switch st {
					case "&[NodeId]":
						fmt.fprintf(f, "sys::Slice::from(%v).cast(),", name)
					case "&str":
						fmt.fprintf(f, "%v.into(),", name)
					case "&mut NodeId":
						fmt.fprintf(f, "core::ptr::from_mut(%v).cast(),", name)
					case "&mut IfState", "&mut LoopState", "&mut BlockState":
						fmt.fprintf(f, "%v,", name)
					case "NodeId",
					     "Datatype",
					     "NodeType",
					     "BinOp",
					     "UnOp",
					     "Lane",
					     "LoopControl",
					     "RegallocMode",
					     "Call":
						fmt.fprintf(f, "%v.0,", name)
					case:
						fmt.fprintf(f, "%v,", name)
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
				for ty, i in params.types[1:] {
					name := rust_ident(params.names[i + 1])
					st := rust_safe_type(ty)
					if st == "&mut NodeId" do fmt.fprintfln(f, "*%v = unsafe {{ self.proc.get_node(%v_id) }};", name, name)
				}
				if len(results.types) == 1 && rust_safe_type(results.types[0]) == "NodeId" do fmt.fprintln(f, "let result = unsafe { self.proc.get_node(result) };")
				if len(results.types) > 1 {
					fmt.fprint(f, "let result = (")
					for ty, i in results.types {
						expr := fmt.tprintf("result.%v", i)
						if rust_safe_type(ty) == "NodeId" do expr = fmt.tprintf("unsafe {{ self.proc.get_node(%v) }}", expr)
						fmt.fprintf(f, "%v,", expr)
					}
					fmt.fprintln(f, ");")
				}
				fmt.fprintln(f, "result")
				for ty in params.types[1:] do if rust_safe_type(ty) == "&[NodeId]" do fmt.fprintln(f, "})")
			} else {
				fmt.fprintln(f, "result")
			}
			fmt.fprintln(f, "}")
		}
		fmt.fprintln(f, "}")
	}
}
