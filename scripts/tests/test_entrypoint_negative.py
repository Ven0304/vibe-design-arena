from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))

from run_controller_tests import run_node


class EntrypointNegativeTests(unittest.TestCase):
    def assert_failed_without_pass(self, argv: tuple[str, ...]) -> None:
        completed = subprocess.run(argv, shell=False, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
        self.assertNotEqual(completed.returncode, 0, completed.stdout.decode("utf-8", "replace"))
        self.assertNotIn('"status": "PASS"', completed.stdout.decode("utf-8", "replace"))

    def test_controller_and_integrity_fail_closed_cases(self) -> None:
        with tempfile.TemporaryDirectory(prefix="vda-negative-") as temporary:
            root = Path(temporary)
            missing = root / "records" / "arena-state.json"
            malformed = root / "malformed.json"
            malformed.write_text("not-json\n", encoding="utf-8")
            cases = (
                (sys.executable, str(SCRIPT_ROOT / "arena.py"), "status", "--state", str(missing)),
                (sys.executable, str(SCRIPT_ROOT / "arena.py"), "preflight", "--state", str(missing)),
                (sys.executable, str(SCRIPT_ROOT / "arena.py"), "start-previews", "--state", str(missing)),
                (sys.executable, str(SCRIPT_ROOT / "arena.py"), "status", "--state", str(malformed)),
                (sys.executable, str(SCRIPT_ROOT / "arena_integrity.py"), "normalize-brief"),
                (sys.executable, str(SCRIPT_ROOT / "arena_integrity.py"), "not-an-action"),
            )
            for argv in cases:
                with self.subTest(argv=argv):
                    self.assert_failed_without_pass(argv)

    def test_node_contract_runner_rejects_false_green_outputs(self) -> None:
        with tempfile.TemporaryDirectory(prefix="vda-node-negative-") as temporary:
            root = Path(temporary)
            fixtures = {
                "nonzero.mjs": "process.exit(23);\n",
                "empty.mjs": "\n",
                "fail.mjs": "process.stdout.write(JSON.stringify({status:'FAIL'}));\n",
                "invalid.mjs": "process.stdout.write('not-json');\n",
                "array.mjs": "process.stdout.write(JSON.stringify(['PASS']));\n",
            }
            for name, source in fixtures.items():
                (root / name).write_text(source, encoding="utf-8", newline="\n")
            with self.assertRaises(SystemExit):
                run_node(root / "nonzero.mjs")
            with self.assertRaises(json.JSONDecodeError):
                run_node(root / "empty.mjs")
            with self.assertRaises(SystemExit):
                run_node(root / "fail.mjs")
            with self.assertRaises(json.JSONDecodeError):
                run_node(root / "invalid.mjs")
            with self.assertRaises(SystemExit):
                run_node(root / "array.mjs")


if __name__ == "__main__":
    unittest.main()