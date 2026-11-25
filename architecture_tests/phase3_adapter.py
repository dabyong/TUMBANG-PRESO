#!/usr/bin/env python3
"""Bridge the Phase 3 JSON protocol to the headless Godot domain."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


def main():
    request = json.load(sys.stdin)
    project = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix="tumbang-phase3-") as directory:
        request_path = Path(directory, "request.json")
        response_path = Path(directory, "response.json")
        request_path.write_text(json.dumps(request), encoding="utf-8")
        result = subprocess.run(
            [os.environ.get("GODOT", "godot"), "--headless", "--path", str(project),
             "--log-file", str(Path(directory, "godot.log")),
             "--script", "res://architecture_tests/phase3_adapter.gd", "--",
             str(request_path), str(response_path)],
            capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=45,
        )
        log = result.stdout + result.stderr
        if result.returncode or "SCRIPT ERROR" in log or "ERROR:" in log or not response_path.is_file():
            raise RuntimeError(f"Godot adapter failed (exit {result.returncode})\n{log}")
        response = json.loads(response_path.read_text(encoding="utf-8"))
        print(json.dumps(response))


if __name__ == "__main__":
    main()
