from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from phase3_helpers import SKILL_ROOT, git, run, write_text
from test_phase1_foundation import valid_state
from arena_controller.storage import write_json_atomic

SCRIPT_ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(os.name == "nt" and shutil.which("powershell.exe"), "PowerShell compatibility tests are Windows-only")
class PowerShellCompatibilityTests(unittest.TestCase):
    def invoke_shim(self, script: Path, *args: str) -> subprocess.CompletedProcess[bytes]:
        environment = os.environ.copy()
        environment["ARENA_PYTHON"] = sys.executable
        return subprocess.run(("powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(script), *args), env=environment, shell=False, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)

    def test_controller_shim_forwards_aliases_and_warns_only_on_stderr(self) -> None:
        with tempfile.TemporaryDirectory(prefix="vda-phase3-shim-") as temporary:
            root = Path(temporary)
            (root / "repo").mkdir()
            state = valid_state(root)
            state_path = Path(state["paths"]["stateFile"])
            write_json_atomic(state_path, state)
            completed = self.invoke_shim(SCRIPT_ROOT / "arena.ps1", "status", "-State", str(state_path))
            self.assertEqual(completed.returncode, 0, completed.stderr.decode("utf-8", "replace"))
            self.assertEqual(json.loads(completed.stdout.decode("utf-8"))["arenaId"], "arena-test")
            stderr_lines = completed.stderr.decode("utf-8", "replace").strip().splitlines()
            self.assertEqual(len(stderr_lines), 1)
            self.assertIn("DEPRECATION", stderr_lines[0])
            self.assertNotIn("DEPRECATION", completed.stdout.decode("utf-8", "replace"))

    def test_integrity_shim_forwards_and_preserves_json_stdout(self) -> None:
        completed = self.invoke_shim(SCRIPT_ROOT / "arena-integrity.ps1", "snapshot", "-SkillRoot", str(SKILL_ROOT))
        self.assertEqual(completed.returncode, 0, completed.stderr.decode("utf-8", "replace"))
        self.assertEqual(json.loads(completed.stdout.decode("utf-8"))["status"], "PASS")
        stderr_lines = completed.stderr.decode("utf-8", "replace").strip().splitlines()
        self.assertEqual(len(stderr_lines), 1)
        self.assertIn("DEPRECATION", stderr_lines[0])

    def test_python_resumes_state_created_by_phase2_powershell(self) -> None:
        with tempfile.TemporaryDirectory(prefix="vda-phase3-resume-") as temporary:
            root = Path(temporary).resolve()
            repository = root / "product repo"
            repository.mkdir()
            run(("git", "init", "-b", "main", str(repository)))
            git(repository, "config", "user.name", "Arena Legacy State Test")
            git(repository, "config", "user.email", "arena-legacy@example.invalid")
            write_text(repository / ".gitattributes", "/DESIGN_BRIEF.md text eol=lf\n")
            write_text(repository / "app.txt", "legacy baseline\n")
            git(repository, "add", "--", ".gitattributes", "app.txt")
            git(repository, "commit", "-m", "legacy baseline")
            state_path = root / "arena run" / "records" / "arena-state.json"
            legacy = subprocess.run(("powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(SCRIPT_ROOT / "arena.phase2.ps1"), "preflight", "-State", str(state_path), "-Repo", str(repository), "-SkillRoot", str(SKILL_ROOT)), shell=False, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
            self.assertEqual(legacy.returncode, 0, legacy.stderr.decode("utf-8", "replace"))
            legacy_state = json.loads(legacy.stdout.decode("utf-8-sig"))
            self.assertEqual((legacy_state["schemaVersion"], legacy_state["stateRevision"], legacy_state["status"]), ("1.0", 1, "ready"))
            resumed = subprocess.run((sys.executable, str(SCRIPT_ROOT / "arena.py"), "preflight", "--state", str(state_path), "--expected-revision", "1"), shell=False, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
            self.assertEqual(resumed.returncode, 0, resumed.stderr.decode("utf-8", "replace"))
            state = json.loads(resumed.stdout.decode("utf-8"))
            self.assertEqual((state["schemaVersion"], state["stateRevision"], state["status"]), ("1.0", 2, "ready"))
            self.assertEqual(state["repository"]["baseSha"], git(repository, "rev-parse", "HEAD"))


if __name__ == "__main__":
    unittest.main()