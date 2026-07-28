from __future__ import annotations

import copy
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

from controller_test_helpers import SKILL_ROOT, STYLES, free_ports, git, invoke, qa_result, run, write_json, write_text


class CrossPlatformLifecycleTests(unittest.TestCase):
    maxDiff = None

    def test_full_python_lifecycle_and_node_import_boundary(self) -> None:
        with tempfile.TemporaryDirectory(prefix="vda-phase3-") as temporary:
            root = Path(temporary).resolve()
            repository = root / "product repo"
            remote = root / "remote.git"
            records = root / "arena run" / "records"
            state_path = records / "arena-state.json"
            results = root / "builder results"
            repository.mkdir(parents=True)
            results.mkdir(parents=True)
            run(("git", "init", "--bare", str(remote)))
            run(("git", "init", "-b", "main", str(repository)))
            git(repository, "config", "user.name", "Arena Phase3 Test")
            git(repository, "config", "user.email", "arena-phase3@example.invalid")
            write_text(repository / "app.txt", "baseline\n")
            git(repository, "add", "--", "app.txt")
            git(repository, "commit", "-m", "baseline")
            baseline = git(repository, "rev-parse", "HEAD")
            git(repository, "remote", "add", "origin", str(remote))
            ports = free_ports()
            preview = {}
            for name, port in zip(STYLES, ports):
                preview[name] = {
                    "executable": sys.executable,
                    "args": ["-m", "http.server", "{{PORT}}", "--bind", "127.0.0.1"],
                    "port": port,
                    "url": f"http://127.0.0.1:{port}",
                    "environment": {"PYTHONUTF8": "1"},
                }
            config = {
                "preview": preview,
                "validation": [{"executable": sys.executable, "args": ["-c", "from pathlib import Path; assert Path('DESIGN_BRIEF.md').is_file()"], "environment": {"PYTHONUTF8": "1"}}],
            }
            config_path = root / "arena-config.json"
            write_json(config_path, config)
            state: dict = invoke(state_path, "preflight", "--repo", str(repository), "--skill-root", str(SKILL_ROOT), "--config", str(config_path))  # type: ignore[assignment]
            self.assertEqual((state["stage"], state["status"]), ("preflight", "blocked"))
            state = invoke(state_path, "preflight", "--expected-revision", str(state["stateRevision"]), "--apply-attributes")  # type: ignore[assignment]
            self.assertEqual(state["status"], "ready")
            self.assertEqual(git(repository, "rev-parse", "HEAD^"), baseline)
            self.assertEqual(git(repository, "show", "--format=", "--name-only", "HEAD"), ".gitattributes")
            snapshot = invoke(state_path, "status")
            self.assertEqual(snapshot["stateRevision"], state["stateRevision"])
            base_sha = state["repository"]["baseSha"]
            for name in STYLES:
                write_text(records / "briefs" / name / "DESIGN_BRIEF.md", f"# {name}\n\nIndependent Phase 3 direction.\n")
            state = invoke(state_path, "create-worktrees", "--expected-revision", str(state["stateRevision"]))  # type: ignore[assignment]
            self.assertEqual(state["stage"], "worktrees-ready")
            for name in STYLES:
                style = state["styles"][name]
                worktree = Path(style["worktree"])
                self.assertEqual(git(worktree, "rev-parse", "HEAD^"), base_sha)
                write_text(worktree / "style.txt", f"{name} implementation\n")
                changed_files = ["style.txt"]
                if name == "style-a":
                    write_text(worktree / "app.txt", "style-a conflict side\n")
                    changed_files.append("app.txt")
                git(worktree, "add", "--", *changed_files)
                git(worktree, "commit", "-m", f"Implement {name}")
                builder = {
                    "schemaVersion": "1.0", "arenaId": state["arenaId"], "style": name, "dispatchId": style["dispatchId"], "candidateGeneration": style["candidateGeneration"],
                    "branch": style["branch"], "briefCommit": style["brief"]["commit"], "briefSha256": style["brief"]["approvedSha256"], "implementationCommit": git(worktree, "rev-parse", "HEAD"),
                    "validation": {"overall": "PASS", "commands": []}, "changedFiles": changed_files, "risks": [],
                }
                builder_path = results / f"{name}-builder-result.json"
                write_json(builder_path, builder)
                state = invoke(state_path, "import-builder-result", "--expected-revision", str(state["stateRevision"]), "--result-path", str(builder_path))  # type: ignore[assignment]
            stale_revision = state["stateRevision"] - 1
            invoke(state_path, "stop-previews", "--expected-revision", str(stale_revision), expect_failure=True)
            self.assertEqual(json.loads(state_path.read_text(encoding="utf-8"))["stateRevision"], state["stateRevision"])
            for _ in range(3):
                state = invoke(state_path, "start-previews", "--expected-revision", str(state["stateRevision"]))  # type: ignore[assignment]
                if state["stage"] == "previews-ready":
                    break
            self.assertEqual(state["stage"], "previews-ready")
            self.assertTrue(all(state["styles"][name]["preview"]["httpStatus"] == 200 for name in STYLES))
            state = invoke(state_path, "stop-previews", "--expected-revision", str(state["stateRevision"]))  # type: ignore[assignment]
            self.assertTrue(all(state["styles"][name]["preview"]["pid"] is None for name in STYLES))
            qa_paths: dict[str, Path] = {}
            for name in STYLES:
                qa_paths[name] = records / "evidence" / name / "qa-results.json"
                write_json(qa_paths[name], qa_result(state, name))
            blocked = qa_result(state, "style-a", overall="BLOCKED")
            write_json(qa_paths["style-a"], blocked)
            state = invoke(state_path, "import-qa-result", "--expected-revision", str(state["stateRevision"]), "--result-path", str(qa_paths["style-a"]))  # type: ignore[assignment]
            self.assertEqual((state["status"], state["styles"]["style-a"]["qualification"]["automatedQa"]), ("blocked", "BLOCKED"))
            failed = qa_result(state, "style-a", overall="FAIL")
            write_json(qa_paths["style-a"], failed)
            state = invoke(state_path, "import-qa-result", "--expected-revision", str(state["stateRevision"]), "--result-path", str(qa_paths["style-a"]))  # type: ignore[assignment]
            self.assertEqual(state["styles"]["style-a"]["qualification"]["automatedQa"], "FAIL")
            escaped = root / "escaped-qa-result.json"
            write_json(escaped, qa_result(state, "style-a"))
            invoke(state_path, "import-qa-result", "--expected-revision", str(state["stateRevision"]), "--result-path", str(escaped), expect_failure=True)
            duplicate = qa_result(state, "style-a")
            duplicate["evidence"].append(copy.deepcopy(duplicate["evidence"][0]))
            write_json(qa_paths["style-a"], duplicate)
            invoke(state_path, "import-qa-result", "--expected-revision", str(state["stateRevision"]), "--result-path", str(qa_paths["style-a"]), expect_failure=True)
            for name in STYLES:
                write_json(qa_paths[name], qa_result(state, name))
                state = invoke(state_path, "import-qa-result", "--expected-revision", str(state["stateRevision"]), "--result-path", str(qa_paths[name]))  # type: ignore[assignment]
                style = state["styles"][name]
                visual_ids = [f"shot.{name}.mobile", f"shot.{name}.tablet", f"shot.{name}.desktop"]
                state = invoke(state_path, "sign-visual-review", "--expected-revision", str(state["stateRevision"]), "--style", name, "--result", "PASS", "--reviewer", "phase3-test", "--candidate-commit", style["implementationCommit"], "--evidence-ids", *visual_ids)  # type: ignore[assignment]
                state = invoke(state_path, "sign-direction-review", "--expected-revision", str(state["stateRevision"]), "--style", name, "--result", "PASS", "--reviewer", "phase3-test", "--candidate-commit", style["implementationCommit"], "--evidence-ids", f"shot.{name}.desktop", f"brief.{name}")  # type: ignore[assignment]
                state = invoke(state_path, "qualify", "--expected-revision", str(state["stateRevision"]), "--style", name)  # type: ignore[assignment]
                self.assertEqual(state["styles"][name]["qualification"]["overall"], "PASS")
            self.assertEqual(state["stage"], "selection-ready")
            state = invoke(state_path, "select", "--expected-revision", str(state["stateRevision"]), "--style", "style-a")  # type: ignore[assignment]
            write_text(repository / "app.txt", "main conflict side\n")
            git(repository, "add", "--", "app.txt")
            git(repository, "commit", "-m", "Advance main with conflicting app change")
            state = invoke(state_path, "merge", "--expected-revision", str(state["stateRevision"]))  # type: ignore[assignment]
            self.assertEqual((state["merge"]["status"], state["status"]), ("CONFLICT", "blocked"))
            self.assertEqual(state["merge"]["conflicts"], ["app.txt"])
            self.assertTrue(git(repository, "rev-parse", "-q", "--verify", "MERGE_HEAD"))
            write_text(repository / "app.txt", "user-authorized conflict resolution\n")
            git(repository, "add", "--", "app.txt")
            state = invoke(state_path, "merge", "--expected-revision", str(state["stateRevision"]))  # type: ignore[assignment]
            self.assertEqual((state["stage"], state["merge"]["status"]), ("merged", "PASS"))
            dirty_worktree = Path(state["styles"]["style-b"]["worktree"])
            refusal_marker = dirty_worktree / "ambiguous-user-file.txt"
            write_text(refusal_marker, "must not be force-removed\n")
            refusal_revision = state["stateRevision"]
            refusal = invoke(state_path, "cleanup", "--expected-revision", str(refusal_revision), expect_failure=True)
            self.assertIn("refusing cleanup for style-b", refusal)
            self.assertEqual(json.loads(state_path.read_text(encoding="utf-8"))["stateRevision"], refusal_revision)
            self.assertTrue(all(Path(state["styles"][name]["worktree"]).exists() for name in STYLES))
            refusal_marker.unlink()
            state = invoke(state_path, "cleanup", "--expected-revision", str(state["stateRevision"]))  # type: ignore[assignment]
            self.assertEqual((state["stage"], state["status"]), ("complete", "complete"))
            for name in STYLES:
                self.assertFalse(Path(state["styles"][name]["worktree"]).exists())
                self.assertEqual(git(repository, "rev-parse", name), state["styles"][name]["implementationCommit"])
            plan = invoke(state_path, "publish-plan", "--remote", "origin", "--branches", "style-b")
            self.assertEqual(plan["branches"][0]["action"], "push")
            state = invoke(state_path, "publish", "--expected-revision", str(state["stateRevision"]), "--remote", "origin", "--branches", "style-b", "--confirm-publish")  # type: ignore[assignment]
            self.assertTrue(state["publication"]["style-b"]["published"])
            self.assertFalse(any(state["publication"][key]["published"] for key in ("main", "style-a", "style-c")))
            state = invoke(state_path, "handoff-docs", "--expected-revision", str(state["stateRevision"]))  # type: ignore[assignment]
            self.assertTrue(Path(state["handoff"]["patchPath"]).is_file())
            self.assertFalse(list(records.rglob("*.tmp")))


if __name__ == "__main__":
    unittest.main()