#!/usr/bin/env python3
"""Exercise the native compiler's IDE protocol through the TRUEOS ABI host mock."""
import hashlib
import json
import io
import struct
import tarfile
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
        archive = root / "assets.lz4"
        run(["objcopy", "--dump-section", f".trueos.assets={archive}", str(NATIVE / "build/odin-son.o")])
        tar_bytes = subprocess.check_output(["lz4", "-d", "-c", str(archive)], timeout=12)
        with tarfile.open(fileobj=io.BytesIO(tar_bytes), mode="r:") as tar:
            assert tar.getnames() == ["assets.bundle"]
            bundle = tar.extractfile("assets.bundle").read()
        magic, version, flags, count = struct.unpack_from("<4sHHI", bundle)
        assert (magic, version, flags) == (b"TRAS", 1, 0) and 0 < count <= 65536
        offset, paths = 12, {}
        for _ in range(count):
            path_len, data_len = struct.unpack_from("<IQ", bundle, offset)
            digest = bundle[offset + 12:offset + 44]
            offset += 44
            name = bundle[offset:offset + path_len].decode("utf-8")
            offset += path_len
            data = bundle[offset:offset + data_len]
            offset += data_len
            assert hashlib.sha256(data).digest() == digest and name not in paths
            paths[name] = data
        assert offset == len(bundle) and "core/odin/doc.odin" in paths and "odin-sdk-LICENSE" in paths
        app_root = root / "compiler-app"
        (app_root / "core/odin").mkdir(parents=True)
        (app_root / "core/odin/doc.odin").write_bytes(paths["core/odin/doc.odin"])
        for valid in (True, False, "import"):

            directory = root / str(valid)
            directory.mkdir()
            if valid == "import":
                source = b'package main\nimport "core:odin"\nmain :: proc() -> i32 { return 0 }\n'
            else:
                source = (NATIVE / "hello.odin.source").read_bytes() if valid else b"package main\nmain :: proc() -> i32 { return missing }\n"
            request = {"version": 1, "workspace_epoch": 42, "build_id": 7, "project": "hello",
                       "revision_id": 3, "backend": "odin_son", "entry": "main.odin",
                       "files": [{"path": "main.odin", "bytes": list(source), "mode": 33188}],
                       "output_path": str(directory / "hello.bp"), "result_path": str(directory / "result.json")}
            path = directory / "request.json"
            path.write_text(json.dumps(request))
            process = subprocess.run([str(executable), "--ide-build", str(path)], timeout=12, capture_output=True, cwd=app_root)
            result = json.loads((directory / "result.json").read_text())
            expected_success = bool(valid)
            assert process.returncode == (0 if expected_success else 1), process.stderr
            assert result["success"] == expected_success
            assert (result["workspace_epoch"], result["build_id"], result["project"], result["revision_id"]) == (42, 7, "hello", 3)
            if valid:
                output = (directory / "hello.bp").read_bytes()
                assert result["artifact"] == {"path": request["output_path"], "bytes": len(output), "sha256": hashlib.sha256(output).hexdigest()}
            else:
                assert result["artifact"] is None and "undeclared identifier" in result["diagnostics"] and "main.odin(2:" in result["diagnostics"]
        print("PASS: SDK asset hashes, IDE import, build success, failure, identity, and artifact SHA-256")


if __name__ == "__main__":
    main()
