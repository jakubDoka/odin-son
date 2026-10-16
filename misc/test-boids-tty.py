#!/usr/bin/env python3
import argparse
import os
from pathlib import Path
import pty
import select
import subprocess
import time


def main():
    parser = argparse.ArgumentParser(description="Check that boids keeps rendering in a terminal.")
    parser.add_argument("binary", type=Path)
    args = parser.parse_args()

    master, slave = pty.openpty()
    process = None
    output = bytearray()
    try:
        process = subprocess.Popen(
            [str(args.binary.resolve())],
            stdin=subprocess.DEVNULL,
            stdout=slave,
            stderr=slave,
        )
        deadline = time.monotonic() + 1.2
        while process.poll() is None and time.monotonic() < deadline:
            if select.select([master], [], [], 0.05)[0]:
                output.extend(os.read(master, 65536))

        status = process.poll()
        frames = output.count(b"\x1b[H")
        if status is not None:
            raise SystemExit(f"FAIL: boids exited with status {status} after {frames} frame(s)")
        if frames < 3:
            raise SystemExit(f"FAIL: expected at least 3 frames, got {frames}")
        print(f"PASS: boids rendered {frames} terminal frames without crashing")
    finally:
        if process is not None:
            if process.poll() is None:
                process.terminate()
            try:
                process.wait(timeout=1)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
        os.close(master)
        os.close(slave)


if __name__ == "__main__":
    main()
