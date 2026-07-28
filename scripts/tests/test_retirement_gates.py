from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import time
import unittest
from dataclasses import replace
from pathlib import Path
from unittest.mock import patch

import portalocker
import psutil

SCRIPT_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPT_ROOT))

from arena_controller.controller import _run_spec
from arena_controller.errors import ArenaError
from arena_controller.process import ProcessSupervisor
from arena_controller.records import write_derived_records
from arena_controller.schema import SchemaRegistry
from arena_controller.storage import StateStore, read_json
from test_phase1_foundation import valid_state


class RetirementGateTests(unittest.TestCase):
    def create_store(self, root: Path, *, timeout: float = 1.0) -> tuple[StateStore, Path]:
        (root / "repo").mkdir()
        state = valid_state(root)
        state_path = Path(state["paths"]["stateFile"])
        store = StateStore(state_path, schemas=SchemaRegistry(), record_writer=write_derived_records, lock_timeout=timeout)
        store.create(state, operation="preflight")
        return store, state_path

    def test_lock_contention_fails_without_revision_change(self) -> None:
        with tempfile.TemporaryDirectory(prefix="vda-lock-") as temporary:
            root = Path(temporary)
            store, state_path = self.create_store(root)
            with portalocker.Lock(str(store.lock_path), mode="a+b", timeout=1):
                contender = StateStore(state_path, schemas=SchemaRegistry(), lock_timeout=0.05)
                with self.assertRaisesRegex(ArenaError, "locked by another writer"):
                    contender.mutate(operation="contended", expected_revision=1, mutation=lambda state: state.update(status="blocked"))
            self.assertEqual(read_json(state_path)["stateRevision"], 1)

    def test_atomic_replace_failure_preserves_old_state_and_cleans_temp(self) -> None:
        with tempfile.TemporaryDirectory(prefix="vda-atomic-") as temporary:
            root = Path(temporary)
            store, state_path = self.create_store(root)
            with patch("arena_controller.storage.os.replace", side_effect=OSError("controlled replace failure")):
                with self.assertRaisesRegex(OSError, "controlled replace failure"):
                    store.mutate(operation="replace-failure", expected_revision=1, mutation=lambda state: state.update(status="blocked"))
            self.assertEqual((read_json(state_path)["stateRevision"], read_json(state_path)["status"]), (1, "ready"))
            self.assertFalse(list(state_path.parent.glob(f".{state_path.name}.*.tmp")))

    def test_controller_interruption_keeps_old_state_and_releases_lock(self) -> None:
        with tempfile.TemporaryDirectory(prefix="vda-interrupt-") as temporary:
            root = Path(temporary)
            store, state_path = self.create_store(root)
            marker = root / "mutation-entered"
            worker = f'''import sys,time\nfrom pathlib import Path\nsys.path.insert(0,{str(SCRIPT_ROOT)!r})\nfrom arena_controller.storage import StateStore\nstore=StateStore({str(state_path)!r},lock_timeout=2)\ndef mutate(state):\n Path({str(marker)!r}).write_text("entered",encoding="utf-8")\n time.sleep(60)\nstore.mutate(operation="interrupted",expected_revision=1,mutation=mutate)\n'''
            process = subprocess.Popen((sys.executable, "-c", worker), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            deadline = time.time() + 10
            while time.time() < deadline and not marker.exists() and process.poll() is None:
                time.sleep(0.05)
            self.assertTrue(marker.exists(), process.stderr.read().decode("utf-8", "replace") if process.poll() is not None else "worker did not enter mutation")
            process.terminate()
            process.wait(timeout=10)
            process.communicate(timeout=1)
            self.assertNotEqual(process.returncode, 0)
            self.assertEqual(read_json(state_path)["stateRevision"], 1)
            resumed = store.mutate(operation="after-interruption", expected_revision=1, mutation=lambda state: state.update(status="blocked"))
            self.assertEqual(resumed["stateRevision"], 2)

    def test_process_tree_stop_does_not_terminate_unrelated_process(self) -> None:
        with tempfile.TemporaryDirectory(prefix="vda-process-tree-") as temporary:
            root = Path(temporary)
            unrelated = subprocess.Popen((sys.executable, "-c", "import time; time.sleep(60)"), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            supervisor = ProcessSupervisor()
            identity = supervisor.start(
                sys.executable,
                ("-c", "import subprocess,sys,time; subprocess.Popen([sys.executable,'-c','import time; time.sleep(60)']); time.sleep(60)"),
                working_directory=root,
                environment={},
                stdout_path=root / "tree.out.log",
                stderr_path=root / "tree.err.log",
            )
            child_pids: list[int] = []
            try:
                deadline = time.time() + 10
                while time.time() < deadline and not child_pids:
                    try:
                        child_pids = [child.pid for child in psutil.Process(identity.pid).children(recursive=True)]
                    except psutil.NoSuchProcess:
                        break
                    time.sleep(0.05)
                self.assertTrue(child_pids, "managed preview did not create its child process")
                supervisor.stop(identity, graceful_timeout=3.0)
                self.assertFalse(psutil.pid_exists(identity.pid))
                self.assertTrue(all(not psutil.pid_exists(pid) for pid in child_pids))
                self.assertIsNone(unrelated.poll(), "unrelated process was terminated")
            finally:
                for pid in [identity.pid, *child_pids]:
                    try:
                        psutil.Process(pid).kill()
                    except psutil.Error:
                        pass
                if unrelated.poll() is None:
                    unrelated.terminate()
                    try:
                        unrelated.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        unrelated.kill()
                        unrelated.wait(timeout=5)

    def test_pid_reuse_simulation_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory(prefix="vda-pid-reuse-") as temporary:
            root = Path(temporary)
            supervisor = ProcessSupervisor()
            identity = supervisor.start(sys.executable, ("-c", "import time; time.sleep(60)"), working_directory=root, environment={}, stdout_path=root / "pid.out.log", stderr_path=root / "pid.err.log")
            try:
                with self.assertRaisesRegex(ArenaError, "PID has been reused"):
                    supervisor.stop(replace(identity, processStartTimeUtc=identity.processStartTimeUtc - 60))
                self.assertTrue(psutil.pid_exists(identity.pid))
                supervisor.stop(identity, graceful_timeout=3.0)
            finally:
                try:
                    psutil.Process(identity.pid).kill()
                except psutil.Error:
                    pass

    def test_structured_validation_failure_is_not_pass(self) -> None:
        with tempfile.TemporaryDirectory(prefix="vda-validation-") as temporary:
            result = _run_spec({"executable": sys.executable, "args": ["-c", "raise SystemExit(7)"], "environment": {}}, Path(temporary))
            self.assertEqual((result["exitCode"], result["status"]), (7, "FAIL"))


if __name__ == "__main__":
    unittest.main()