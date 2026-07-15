from __future__ import annotations

import hashlib
import locale
import os
import subprocess
from dataclasses import dataclass
from typing import Mapping, Sequence

from .errors import ArenaError
from .paths import absolute_path


@dataclass(frozen=True)
class GitResult:
    exit_code: int
    output: str
    stdout: str
    stderr: str


def _decode(data: bytes) -> str:
    try:
        return data.decode("utf-8")
    except UnicodeDecodeError:
        encoding = locale.getpreferredencoding(False) or "utf-8"
        return data.decode(encoding, errors="replace")


class Git:
    def __init__(self, executable: str = "git") -> None:
        self.executable = executable

    def run(
        self,
        repository: str | os.PathLike[str],
        arguments: Sequence[str],
        *,
        allow_failure: bool = False,
        environment: Mapping[str, str] | None = None,
    ) -> GitResult:
        repo = absolute_path(repository, must_exist=True)
        argv = [self.executable, "-C", str(repo), *map(str, arguments)]
        env = os.environ.copy()
        if environment:
            env.update({str(k): str(v) for k, v in environment.items()})
        completed = subprocess.run(
            argv,
            shell=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env=env,
            check=False,
        )
        stdout = _decode(completed.stdout).rstrip()
        stderr = _decode(completed.stderr).rstrip()
        output = "\n".join(part for part in (stdout, stderr) if part)
        result = GitResult(completed.returncode, output, stdout, stderr)
        if completed.returncode != 0 and not allow_failure:
            rendered = " ".join(map(str, arguments))
            raise ArenaError(
                f'git -C "{repo}" {rendered} failed ({completed.returncode}): {output}'
            )
        return result

    def blob_sha256(
        self,
        repository: str | os.PathLike[str],
        commit: str,
        path: str = "DESIGN_BRIEF.md",
    ) -> str:
        repo = absolute_path(repository, must_exist=True)
        completed = subprocess.run(
            [self.executable, "-C", str(repo), "cat-file", "blob", f"{commit}:{path}"],
            shell=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        if completed.returncode != 0:
            raise ArenaError(f"git cat-file failed: {_decode(completed.stderr).rstrip()}")
        return hashlib.sha256(completed.stdout).hexdigest()