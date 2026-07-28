from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path
from typing import Any

from controller_test_helpers import SKILL_ROOT, git, invoke, run, write_json, write_text

FIXTURE = Path(__file__).resolve().parent / "fixtures" / "legacy-powershell-preflight-state-v1.json"


def materialize(value: Any, replacements: dict[str, str]) -> Any:
    if isinstance(value, str):
        for marker, replacement in replacements.items():
            value = value.replace(marker, replacement)
        return value
    if isinstance(value, list):
        return [materialize(item, replacements) for item in value]
    if isinstance(value, dict):
        return {key: materialize(item, replacements) for key, item in value.items()}
    return value


class LegacyStateCompatibilityTests(unittest.TestCase):
    def test_python_resumes_normalized_powershell_v1_state_fixture(self) -> None:
        with tempfile.TemporaryDirectory(prefix="vda-legacy-state-") as temporary:
            root = Path(temporary).resolve()
            repository = root / "product repo"
            repository.mkdir()
            run(("git", "init", "-b", "main", str(repository)))
            git(repository, "config", "user.name", "Legacy State Test")
            git(repository, "config", "user.email", "legacy-state@example.invalid")
            write_text(repository / "app.txt", "baseline\n")
            git(repository, "add", "--", "app.txt")
            git(repository, "commit", "-m", "baseline")
            state = materialize(
                json.loads(FIXTURE.read_text(encoding="utf-8")),
                {
                    "${RUN_ROOT}": str(root),
                    "${REPOSITORY_ROOT}": str(repository),
                    "${SKILL_ROOT}": str(SKILL_ROOT),
                },
            )
            state_path = root / "arena run" / "records" / "arena-state.json"
            write_json(state_path, state)
            resumed = invoke(state_path, "preflight", "--expected-revision", "1", "--apply-attributes")
            self.assertEqual((resumed["schemaVersion"], resumed["stateRevision"], resumed["stage"], resumed["status"]), ("1.0", 2, "preflight", "ready"))
            self.assertEqual(git(repository, "show", "--format=", "--name-only", "HEAD"), ".gitattributes")


if __name__ == "__main__":
    unittest.main()