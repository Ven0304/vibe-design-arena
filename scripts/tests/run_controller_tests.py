from __future__ import annotations

import json
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def run_node(path: Path) -> dict:
    completed = subprocess.run(("node", str(path)), cwd=ROOT, shell=False, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    if completed.returncode:
        raise SystemExit(f"Node contract test failed ({completed.returncode}): {completed.stderr.decode('utf-8', 'replace')}")
    value = json.loads(completed.stdout.decode("utf-8"))
    if not isinstance(value, dict) or value.get("status") != "PASS":
        raise SystemExit(f"Node contract test did not emit PASS: {value!r}")
    return value


def main() -> int:
    suite = unittest.defaultTestLoader.discover(
        str(ROOT / "scripts" / "tests"), pattern="test_*.py", top_level_dir=str(ROOT / "scripts" / "tests")
    )
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    if not result.wasSuccessful():
        return 1
    node_result = run_node(ROOT / "scripts" / "tests" / "arena-qa-unit.mjs")
    syntax = subprocess.run(("node", "--check", str(ROOT / "scripts" / "arena-qa.mjs")), cwd=ROOT, shell=False, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    if syntax.returncode:
        sys.stderr.write(syntax.stderr.decode("utf-8", "replace"))
        return syntax.returncode
    print(json.dumps({"status": "PASS", "pythonTests": result.testsRun, "nodeQa": node_result, "platform": sys.platform, "python": sys.version.split()[0]}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())