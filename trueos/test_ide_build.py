#!/usr/bin/env python3
"""Exercise the native compiler's IDE protocol through the TRUEOS ABI host mock."""
import hashlib
import json
import pathlib
import subprocess
import tempfile

NATIVE = pathlib.Path(__file__).resolve().parent


def run(argv, **kwargs):
    return subprocess.run(argv, timeout=12, check=True, **kwargs)


def main():
    with tempfile.TemporaryDirectory(prefix="odin-ide-test-") as temporary:
        root = pathlib.Path(temporary)
        executable = root / "compiler"
        run(["gcc", "-std=c11", str(NATIVE / "test_host.c"), str(NATIVE / "build/odin-son.o"), "-lm", "-o", str(executable)])
        sections = run(["readelf", "-SW", str(NATIVE / "build/odin-son.o")], capture_output=True, text=True)
        assert ".trueos.assets" not in sections.stdout
        app_root = root / "compiler-app"
        app_root.mkdir()
        for case in ("success", "failure", "module"):
            directory = root / case
            directory.mkdir()
            if case == "module":
                source = b'package main\nimport "helper"\nmain :: proc() -> i32 { return helper.answer() }\n'
            else:
                source = (NATIVE / "hello.odin.source").read_bytes() if case == "success" else b"package main\nmain :: proc() -> i32 { return missing }\n"
            files = [{"path": "main.odin", "bytes": list(source), "mode": 33188}]
            if case == "module":
                files.append({"path": "helper/answer.odin", "bytes": list(b"package helper\nanswer :: proc() -> i32 { return 42 }\n"), "mode": 33188})
            request = {"version": 1, "workspace_epoch": 42, "build_id": 7, "project": "hello",
                       "revision_id": 3, "backend": "odin_son", "entry": "main.odin",
                       "files": files,
                       "output_path": str(directory / "hello.bp"), "result_path": str(directory / "result.json")}
            path = directory / "request.json"
            path.write_text(json.dumps(request))
            process = subprocess.run([str(executable), "--ide-build", str(path)], timeout=12, capture_output=True, cwd=app_root)
            result = json.loads((directory / "result.json").read_text())
            expected_success = case != "failure"
            assert process.returncode == (0 if expected_success else 1), process.stderr
            assert result["success"] == expected_success
            assert (result["workspace_epoch"], result["build_id"], result["project"], result["revision_id"]) == (42, 7, "hello", 3)
            if expected_success:
                output = (directory / "hello.bp").read_bytes()
                assert result["artifact"] == {"path": request["output_path"], "bytes": len(output), "sha256": hashlib.sha256(output).hexdigest()}
            else:
                assert result["artifact"] is None and "undeclared identifier" in result["diagnostics"] and "main.odin(2:" in result["diagnostics"]
            if case == "module":
                program = directory / "hello"
                run(["gcc", str(directory / "hello.o"), "-o", str(program)])
                executed = subprocess.run([str(program)], timeout=12, capture_output=True)
                assert executed.returncode == 42, executed.stderr
        print("PASS: no SDK assets, project module execution, IDE success, failure, identity, and artifact SHA-256")


if __name__ == "__main__":
    main()
