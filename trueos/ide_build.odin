package main

import "core:crypto/sha2"
import "core:encoding/json"
import "core:fmt"
import "core:strings"
import os "platform"

IDE_File :: struct { path: string, bytes: []u8, mode: u32 }
IDE_Request :: struct {
    version: u32, workspace_epoch, build_id: u64, project: string, revision_id: i64,
    backend, entry: string, files: []IDE_File, output_path, result_path: string,
}
IDE_Artifact :: struct { path: string, bytes: u64, sha256: string }
IDE_Result :: struct {
    version: u32, workspace_epoch, build_id: u64, project: string, revision_id: i64,
    success: bool, artifact: json.Null, diagnostics: string,
}

IDE_DIAGNOSTIC_LIMIT :: 8192
ide_diagnostic_bytes: [IDE_DIAGNOSTIC_LIMIT]u8
ide_diagnostic_len: int
ide_diagnostic_truncated: bool

ide_capture :: proc(stream: u32, text: string) {
    if stream != 2 do return
    remaining := IDE_DIAGNOSTIC_LIMIT - ide_diagnostic_len
    count := min(remaining, len(text))
    copy(ide_diagnostic_bytes[ide_diagnostic_len:ide_diagnostic_len+count], transmute([]u8)text[:count])
    ide_diagnostic_len += count
    if count < len(text) do ide_diagnostic_truncated = true
}

ide_path_valid :: proc(path: string) -> bool {
    if len(path) == 0 || strings.has_prefix(path, "/") || strings.contains(path, "\\") || strings.contains(path, ":") || strings.contains(path, "\x00") do return false
    cursor := path
    for part in strings.split_iterator(&cursor, "/") {
        if part == "" || part == "." || part == ".." do return false
    }
    return true
}

ide_build :: proc(request_path: string) -> i32 {
    input, read_err := os.read_entire_file(request_path)
    if read_err != nil { fmt.eprintln("cannot read IDE request"); return 1 }
    request: IDE_Request
    if json.unmarshal(input, &request) != nil { fmt.eprintln("invalid IDE request JSON"); return 1 }
    result := IDE_Result{version=1, workspace_epoch=request.workspace_epoch, build_id=request.build_id, project=request.project, revision_id=request.revision_id}
    diagnostic := ""
    if request.version != 1 || request.workspace_epoch == 0 || request.build_id == 0 || request.revision_id <= 0 || request.project == "" || request.backend != "odin_son" || len(request.files) == 0 {
        diagnostic = "invalid build request identity"
    }
    output_dir := os.dir(request.output_path)
    if !strings.has_prefix(request.output_path, "/") || !strings.has_suffix(request.output_path, ".bp") || output_dir == "" || os.dir(request.result_path) != output_dir || os.base(request.result_path) != "result.json" || request.output_path == request.result_path {
        diagnostic = "invalid build output or result path"
    }
    found := false
    for file, i in request.files {
        if !ide_path_valid(file.path) do diagnostic = "invalid source path"
        if file.path == request.entry do found = true
        for j in 0..<i { if request.files[j].path == file.path do diagnostic = "duplicate source path" }
    }
    if !found do diagnostic = "missing source entry"
    source_root := strings.concatenate({output_dir, "/source"})
    if diagnostic == "" {
        for file in request.files {
            target := strings.concatenate({source_root, "/", file.path})
            if os.create_dir_all(os.dir(target)) != nil || os.write_entire_file(target, file.bytes) != nil { diagnostic = "cannot stage source snapshot"; break }
        }
    }
    artifact: IDE_Artifact
    if diagnostic == "" {
        entry := strings.concatenate({source_root, "/", request.entry})
        object := strings.concatenate({request.output_path[:len(request.output_path)-3], ".o"})
        args := [6]cstring{cstring("odin-son"), cstring("--cpu-boids"), cstring("--blueprint"), strings.clone_to_cstring(entry), cstring("-o"), strings.clone_to_cstring(object)}
        ide_diagnostic_len = 0
        ide_diagnostic_truncated = false
        previous_sink := fmt.trueos_sink
        fmt.trueos_sink = ide_capture
        compiler_status := run_compiler(len(args), raw_data(args[:]))
        fmt.trueos_sink = previous_sink
        if compiler_status != 0 {
            diagnostic = strings.to_valid_utf8(string(ide_diagnostic_bytes[:ide_diagnostic_len]), "�")
            if diagnostic == "" do diagnostic = "Odin SON compilation failed"
            if ide_diagnostic_truncated do diagnostic = strings.concatenate({diagnostic, "\n[diagnostics truncated]"})
        }
    }
    if diagnostic == "" {
        bytes, err := os.read_entire_file(request.output_path)
        object_path := strings.concatenate({request.output_path[:len(request.output_path)-3], ".o"})
        object, object_err := os.read_entire_file(object_path)
        if err != nil || object_err != nil || len(object) < 64 || string(object[:4]) != "\x7fELF" || len(bytes) != len(object)+24 || string(bytes) != string(package_boids(object)) { diagnostic = "cannot read valid compiler Blueprint" } else {
            hash: sha2.Context_256
            sha2.init_256(&hash)
            sha2.update(&hash, bytes)
            digest: [32]u8
            sha2.final(&hash, digest[:])
            hex := "0123456789abcdef"
            encoded := make([]u8, 64)
            for byte, i in digest { encoded[i*2] = hex[byte >> 4]; encoded[i*2+1] = hex[byte & 15] }
            artifact = IDE_Artifact{path=request.output_path, bytes=u64(len(bytes)), sha256=string(encoded)}
            result.success = true

        }
    }
    result.diagnostics = diagnostic
    if !strings.has_prefix(request.result_path, "/") || request.result_path == request.output_path || os.base(request.result_path) != "result.json" { fmt.eprintln("invalid IDE result path"); return 1 }
    encoded, err := json.marshal(result)
    if err != nil { fmt.eprintln("cannot encode IDE result"); return 1 }
    if result.success {
        artifact_json, artifact_err := json.marshal(artifact)
        if artifact_err != nil { fmt.eprintln("cannot encode IDE artifact"); return 1 }
        replaced, _ := strings.replace_all(string(encoded), `"artifact":null`, strings.concatenate({`"artifact":`, string(artifact_json)}))
        encoded = transmute([]u8)replaced
    }
    if os.write_entire_file(request.result_path, encoded) != nil { fmt.eprintln("cannot write IDE result"); return 1 }
    verified, verify_err := os.read_entire_file(request.result_path)
    if verify_err != nil || string(verified) != string(encoded) { fmt.eprintln("IDE result readback failed"); return 1 }
    return result.success ? 0 : 1
}
