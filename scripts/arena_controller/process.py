from __future__ import annotations

import os
import signal
import subprocess
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Mapping, Sequence

from .errors import ArenaError, DependencyUnavailableError
from .paths import absolute_path
from .platform import managed_process_policy


def _psutil():
    try:
        import psutil
    except ImportError as exc:
        raise DependencyUnavailableError(
            "Python controller dependency 'psutil' is missing. "
            "Install requirements-controller.txt in an approved isolated environment."
        ) from exc
    return psutil


def validate_environment(environment: Mapping[str, Any] | None) -> dict[str, str]:
    result: dict[str, str] = {}
    seen: dict[str, str] = {}
    for key, value in (environment or {}).items():
        folded = str(key).casefold()
        if folded in seen:
            raise ArenaError(
                "Command environment contains duplicate case-insensitive keys: "
                f"{seen[folded]}, {key}"
            )
        seen[folded] = str(key)
        result[str(key)] = str(value)
    return result


@dataclass(frozen=True)
class ProcessIdentity:
    pid: int
    processStartTimeUtc: float
    executable: str
    args: tuple[str, ...]
    workingDirectory: str


class ProcessSupervisor:
    def __init__(self) -> None:
        self._handles: dict[int, subprocess.Popen[Any]] = {}

    def start(
        self,
        executable: str,
        args: Sequence[str],
        *,
        working_directory: str | Path,
        environment: Mapping[str, Any] | None,
        stdout_path: str | Path,
        stderr_path: str | Path,
    ) -> ProcessIdentity:
        psutil = _psutil()
        cwd = absolute_path(working_directory, must_exist=True)
        env = os.environ.copy()
        env.update(validate_environment(environment))
        stdout_target = Path(stdout_path)
        stderr_target = Path(stderr_path)
        stdout_target.parent.mkdir(parents=True, exist_ok=True)
        stderr_target.parent.mkdir(parents=True, exist_ok=True)
        policy = managed_process_policy()
        with stdout_target.open("ab") as stdout, stderr_target.open("ab") as stderr:
            process = subprocess.Popen(
                [executable, *map(str, args)],
                cwd=cwd,
                env=env,
                shell=False,
                stdin=subprocess.DEVNULL,
                stdout=stdout,
                stderr=stderr,
                creationflags=policy.creationflags,
                start_new_session=policy.start_new_session,
            )
        self._handles[process.pid] = process
        observed = psutil.Process(process.pid)
        return ProcessIdentity(
            pid=process.pid,
            processStartTimeUtc=float(observed.create_time()),
            executable=str(executable),
            args=tuple(map(str, args)),
            workingDirectory=str(cwd),
        )

    def verify(self, expected: ProcessIdentity) -> Any:
        psutil = _psutil()
        try:
            process = psutil.Process(expected.pid)
            actual_create = float(process.create_time())
            actual_cwd = absolute_path(process.cwd(), must_exist=True)
            expected_cwd = absolute_path(expected.workingDirectory, must_exist=True)
            cmdline = process.cmdline()
        except (psutil.NoSuchProcess, psutil.AccessDenied, OSError) as exc:
            raise ArenaError(f"Recorded preview process identity cannot be verified: {exc}") from exc
        if abs(actual_create - expected.processStartTimeUtc) > 0.01:
            raise ArenaError("Recorded preview PID has been reused; creation time differs.")
        if actual_cwd != expected_cwd:
            raise ArenaError("Recorded preview process working directory differs.")
        if not cmdline:
            raise ArenaError("Recorded preview process command line is unavailable.")
        actual_executable = Path(cmdline[0]).name.casefold()
        expected_executable = Path(expected.executable).name.casefold()
        if actual_executable != expected_executable:
            raise ArenaError("Recorded preview process executable differs.")
        expected_args = list(expected.args)
        if expected_args and cmdline[1 : 1 + len(expected_args)] != expected_args:
            raise ArenaError("Recorded preview process arguments differ.")
        return process

    def stop(self, expected: ProcessIdentity, *, graceful_timeout: float = 8.0) -> None:
        psutil = _psutil()
        process = self.verify(expected)
        family = process.children(recursive=True)
        targets = [*family, process]
        if os.name == "nt":
            for target in reversed(targets):
                try:
                    target.terminate()
                except psutil.NoSuchProcess:
                    pass
        else:
            try:
                os.killpg(os.getpgid(process.pid), signal.SIGTERM)
            except (ProcessLookupError, PermissionError, OSError) as exc:
                raise ArenaError(f"Unable to signal verified preview process group: {exc}") from exc
        _, alive = psutil.wait_procs(targets, timeout=graceful_timeout)
        for target in alive:
            try:
                target.kill()
            except psutil.NoSuchProcess:
                pass
        _, still_alive = psutil.wait_procs(alive, timeout=2.0)
        if still_alive:
            pids = [item.pid for item in still_alive]
            raise ArenaError(f"Verified preview process tree did not stop: {pids}")
        handle = self._handles.pop(expected.pid, None)
        if handle is not None:
            handle.wait(timeout=2.0)