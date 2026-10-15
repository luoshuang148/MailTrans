#!/usr/bin/env python3
"""Verify the setup probe queries availability without reading/ translating stdin."""
import json
import subprocess
import sys

result = subprocess.run([sys.argv[1], "--model-status"], input=b"not a translation request",
                        capture_output=True, timeout=30)
assert result.returncode == 0, (result.returncode, result.stdout, result.stderr)
status = json.loads(result.stdout)
assert status["source"] == "en" and status["target"] == "zh-Hans", status
assert status["status"] in {"installed", "supported", "unsupported"}, status
assert "translations" not in status and "message" not in status, status
assert not result.stderr, result.stderr
print("PASS: setup model availability JSON bypasses translation input")
