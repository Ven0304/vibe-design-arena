from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

SCRIPT_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPT_ROOT))

from arena_controller.errors import ArenaError, RevisionMismatchError
from arena_controller.git import Git
from arena_controller.integrity import (
    canonical_text_facts,
    normalize_canonical_text,
    sha256_file,
    verify_brief,
)
from arena_controller.paths import child_path
from arena_controller.process import ProcessSupervisor, validate_environment
from arena_controller.records import write_derived_records
from arena_controller.schema import SchemaRegistry
from arena_controller.storage import StateStore, read_json, write_json_atomic


def review() -> dict:
    return {
        "status": "PENDING",
        "reviewer": None,
        "timestamp": None,
        "candidateCommit": None,
        "qaResultSha256": None,
        "evidenceIds": [],
    }


def valid_state(root: Path) -> dict:
    records = root / "records"
    state_path = records / "arena-state.json"
    styles = {}
    for name in ("style-a", "style-b", "style-c"):
        styles[name] = {
            "branch": name,
            "worktree": str(root / "worktrees" / name),
            "candidateGeneration": 1,
            "brief": {},
            "qaResultPath": None,
            "qaResultSha256": None,
            "preview": {},
            "reviews": {"visual": review(), "direction": review()},
            "qualification": {
                "briefIntegrity": "PENDING",
                "validation": "PENDING",
                "automatedQa": "PENDING",
                "mainAgentVisualReview": "PENDING",
                "directionConsistencyReview": "PENDING",
                "overall": "PENDING",
            },
        }
    return {
        "schemaVersion": "1.0",
        "stateRevision": 1,
        "arenaId": "arena-test",
        "stage": "preflight",
        "status": "ready",
        "paths": {
            "runRoot": str(root),
            "recordsRoot": str(records),
            "worktreeRoot": str(root / "worktrees"),
            "stateFile": str(state_path),
            "eventLog": str(records / "events.jsonl"),
        },
        "repository": {"root": str(root / "repo"), "baseBranch": "main", "baseSha": "a" * 40},
        "skillSnapshot": {},
        "styles": styles,
        "publication": {"main": {}, "style-a": {}, "style-b": {}, "style-c": {}},
    }


class FoundationTests(unittest.TestCase):
    def test_containment_resolves_and_rejects_sibling_prefix(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / "evidence"
            root.mkdir()
            inside = root / "style-a" / "shot.png"
            self.assertEqual(child_path(root, inside), inside.resolve())
            sibling = Path(temporary) / "evidence-escaped" / "shot.png"
            with self.assertRaises(ArenaError):
                child_path(root, sibling)

    def test_canonical_text_and_exact_hash(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "brief.md"
            path.write_bytes(b"\xef\xbb\xbfline1\r\nline2\r")
            before = canonical_text_facts(path)
            self.assertFalse(before.canonical)
            converted = normalize_canonical_text(path, write=False)
            self.assertTrue(converted["changed"])
            self.assertEqual(path.read_bytes(), b"\xef\xbb\xbfline1\r\nline2\r")
            normalize_canonical_text(path, write=True)
            self.assertEqual(path.read_bytes(), b"line1\nline2\n")
            self.assertTrue(canonical_text_facts(path).canonical)
            self.assertEqual(sha256_file(path), canonical_text_facts(path).sha256)

    def test_verify_brief_preserves_exact_byte_boundary(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            frozen = root / "frozen.md"
            working = root / "working.md"
            frozen.write_bytes(b"same\n")
            working.write_bytes(b"same\n")
            self.assertTrue(verify_brief(frozen, working)["matches"])
            working.write_bytes(b"same\r\n")
            details = verify_brief(frozen, working)
            self.assertFalse(details["matches"])
            self.assertEqual(details["classification"], "line-ending-mismatch")

    def test_git_adapter_uses_exit_code_and_hashes_blob_bytes(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            repo = Path(temporary)
            git = Git()
            git.run(repo, ("init", "-b", "main"))
            git.run(repo, ("config", "user.name", "Arena Test"))
            git.run(repo, ("config", "user.email", "arena@example.invalid"))
            (repo / "DESIGN_BRIEF.md").write_bytes(b"brief\n")
            git.run(repo, ("add", "--", "DESIGN_BRIEF.md"))
            git.run(repo, ("commit", "-m", "brief"))
            commit = git.run(repo, ("rev-parse", "HEAD")).stdout
            self.assertEqual(git.blob_sha256(repo, commit), sha256_file(repo / "DESIGN_BRIEF.md"))
            failed = git.run(repo, ("rev-parse", "missing-ref"), allow_failure=True)
            self.assertNotEqual(failed.exit_code, 0)

    def test_schema_and_revision_transaction(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "repo").mkdir()
            state = valid_state(root)
            state_path = Path(state["paths"]["stateFile"])
            store = StateStore(
                state_path,
                schemas=SchemaRegistry(),
                record_writer=write_derived_records,
            )
            created = store.create(state, operation="preflight")
            self.assertEqual(created["stateRevision"], 1)
            updated = store.mutate(
                operation="test",
                expected_revision=1,
                mutation=lambda value: value.update(status="blocked"),
                outcome="blocked",
            )
            self.assertEqual(updated["stateRevision"], 2)
            self.assertEqual(read_json(state_path)["status"], "blocked")
            with self.assertRaises(RevisionMismatchError):
                store.mutate(
                    operation="stale",
                    expected_revision=1,
                    mutation=lambda value: value.update(status="ready"),
                )
            events = (state_path.parent / "events.jsonl").read_text(encoding="utf-8").splitlines()
            self.assertEqual([json.loads(line)["stateRevision"] for line in events], [1, 2])
            self.assertTrue((state_path.parent / "generated" / "arena-record.md").is_file())

    def test_atomic_json_is_utf8_no_bom_one_lf(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "state.json"
            write_json_atomic(path, {"text": "中文"})
            data = path.read_bytes()
            self.assertFalse(data.startswith(b"\xef\xbb\xbf"))
            self.assertTrue(data.endswith(b"\n"))
            self.assertFalse(data.endswith(b"\n\n"))
            self.assertEqual(json.loads(data.decode("utf-8"))["text"], "中文")

    def test_environment_keys_are_case_insensitively_unique(self) -> None:
        with self.assertRaises(ArenaError):
            validate_environment({"Path": "a", "PATH": "b"})

    def test_cli_forces_utf8_for_non_gbk_state_content(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "repo").mkdir()
            state = valid_state(root)
            state["styles"]["style-a"]["preview"]["lastError"] = "\ue15f"
            state_path = Path(state["paths"]["stateFile"])
            write_json_atomic(state_path, state)
            environment = os.environ.copy()
            environment["PYTHONIOENCODING"] = "gbk"
            completed = subprocess.run(
                [
                    sys.executable,
                    str(SCRIPT_ROOT / "arena.py"),
                    "status",
                    "-State",
                    str(state_path),
                ],
                shell=False,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                env=environment,
                check=False,
            )
            self.assertEqual(completed.returncode, 0, completed.stderr.decode("utf-8"))
            parsed = json.loads(completed.stdout.decode("utf-8"))
            self.assertEqual(parsed["styles"]["style-a"]["preview"]["lastError"], "\ue15f")

    def test_process_stop_requires_full_verified_identity(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            supervisor = ProcessSupervisor()
            identity = supervisor.start(
                sys.executable,
                ("-c", "import time; time.sleep(60)"),
                working_directory=root,
                environment={},
                stdout_path=root / "stdout.log",
                stderr_path=root / "stderr.log",
            )
            try:
                supervisor.verify(identity)
                supervisor.stop(identity, graceful_timeout=2.0)
            finally:
                try:
                    os.kill(identity.pid, 9)
                except OSError:
                    pass


if __name__ == "__main__":
    unittest.main()