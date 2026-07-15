from __future__ import annotations

import os
from pathlib import Path

from .errors import ArenaError


def absolute_path(value: str | os.PathLike[str], *, must_exist: bool = False) -> Path:
    path = Path(value).expanduser()
    if must_exist:
        try:
            return path.resolve(strict=True)
        except OSError as exc:
            raise ArenaError(f"Path does not exist or cannot be resolved: {path}") from exc
    if path.exists():
        return path.resolve(strict=True)
    parent = path.parent.resolve(strict=True) if path.parent.exists() else path.parent.resolve()
    return parent / path.name


def child_path(
    root: str | os.PathLike[str],
    candidate: str | os.PathLike[str],
    *,
    allow_root: bool = False,
) -> Path:
    resolved_root = absolute_path(root, must_exist=True)
    resolved_candidate = absolute_path(candidate)
    try:
        common = Path(os.path.commonpath((resolved_root, resolved_candidate)))
    except ValueError as exc:
        raise ArenaError(
            f"Path is outside the approved root. Root={resolved_root} Candidate={resolved_candidate}"
        ) from exc
    if common != resolved_root or (resolved_candidate == resolved_root and not allow_root):
        raise ArenaError(
            f"Path is outside the approved root. Root={resolved_root} Candidate={resolved_candidate}"
        )
    return resolved_candidate


def assert_run_root_outside_repository(run_root: Path, repository: Path) -> None:
    resolved_run = absolute_path(run_root)
    resolved_repo = absolute_path(repository, must_exist=True)
    try:
        common = Path(os.path.commonpath((resolved_run, resolved_repo)))
    except ValueError:
        return
    if common in (resolved_repo, resolved_run):
        raise ArenaError(
            "ARENA_RUN_ROOT must be outside the product repository and its worktrees."
        )