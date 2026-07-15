from __future__ import annotations

from pathlib import Path
from typing import Any

from .constants import STYLES
from .storage import write_utf8_lf


def _get(value: Any, *keys: str, default: Any = None) -> Any:
    current = value
    for key in keys:
        if not isinstance(current, dict):
            return default
        current = current.get(key)
        if current is None:
            return default
    return current


def write_derived_records(state: dict[str, Any], state_path: Path) -> None:
    records_root = Path(state_path).resolve().parent
    generated_root = records_root / "generated"
    candidate_root = records_root / "candidates"
    generated_root.mkdir(parents=True, exist_ok=True)
    candidate_root.mkdir(parents=True, exist_ok=True)

    record = [
        "# Vibe Design Arena Record",
        "",
        f"- Arena ID: {_get(state, 'arenaId', default='')}",
        f"- State revision: {_get(state, 'stateRevision', default='')}",
        f"- Stage: {_get(state, 'stage', default='')}",
        f"- Status: {_get(state, 'status', default='')}",
        f"- Product repository: {_get(state, 'repository', 'root', default='')}",
        f"- Base branch: {_get(state, 'repository', 'baseBranch', default='')}",
        f"- Base SHA: {_get(state, 'repository', 'baseSha', default='')}",
        f"- Updated: {_get(state, 'updatedAt', default='')}",
    ]
    write_utf8_lf(generated_root / "arena-record.md", "\n".join(record) + "\n")

    approval = [
        "# Approval Registry",
        "",
        "| Style | Approved SHA-256 | Brief commit |",
        "| --- | --- | --- |",
    ]
    preview = [
        "# Preview Registry",
        "",
        "| Style | Branch | Port | PID | HTTP | URL |",
        "| --- | --- | ---: | ---: | --- | --- |",
    ]
    for name in STYLES:
        style = _get(state, "styles", name, default={})
        approval.append(
            f"| {name} | {_get(style, 'brief', 'approvedSha256', default='')} | "
            f"{_get(style, 'brief', 'commit', default='')} |"
        )
        preview.append(
            f"| {name} | {_get(style, 'branch', default='')} | "
            f"{_get(style, 'preview', 'port', default='')} | "
            f"{_get(style, 'preview', 'pid', default='')} | "
            f"{_get(style, 'preview', 'httpStatus', default='')} | "
            f"{_get(style, 'preview', 'url', default='')} |"
        )
        visual_ids = ", ".join(_get(style, "reviews", "visual", "evidenceIds", default=[]))
        direction_ids = ", ".join(
            _get(style, "reviews", "direction", "evidenceIds", default=[])
        )
        candidate = [
            f"# Candidate Record: {name}",
            "",
            f"- Branch: {_get(style, 'branch', default='')}",
            f"- Worktree: {_get(style, 'worktree', default='')}",
            f"- Dispatch ID: {_get(style, 'dispatchId', default='')}",
            f"- Candidate generation: {_get(style, 'candidateGeneration', default='')}",
            f"- Brief SHA-256: {_get(style, 'brief', 'approvedSha256', default='')}",
            f"- Brief commit: {_get(style, 'brief', 'commit', default='')}",
            f"- Implementation commit: {_get(style, 'implementationCommit', default='')}",
            f"- QA result: {_get(style, 'qaResultPath', default='')}",
            f"- QA result SHA-256: {_get(style, 'qaResultSha256', default='')}",
            f"- Validation: {_get(style, 'qualification', 'validation', default='')}",
            f"- Automated QA: {_get(style, 'qualification', 'automatedQa', default='')}",
            f"- Main-agent visual review: {_get(style, 'qualification', 'mainAgentVisualReview', default='')}",
            f"- Visual reviewer: {_get(style, 'reviews', 'visual', 'reviewer', default='')}",
            f"- Visual evidence IDs: {visual_ids}",
            f"- Direction consistency: {_get(style, 'qualification', 'directionConsistencyReview', default='')}",
            f"- Direction reviewer: {_get(style, 'reviews', 'direction', 'reviewer', default='')}",
            f"- Direction evidence IDs: {direction_ids}",
            f"- Overall: {_get(style, 'qualification', 'overall', default='')}",
        ]
        write_utf8_lf(candidate_root / f"{name}-record.md", "\n".join(candidate) + "\n")
    write_utf8_lf(generated_root / "approval-registry.md", "\n".join(approval) + "\n")
    write_utf8_lf(generated_root / "preview-registry.md", "\n".join(preview) + "\n")

    if _get(state, "stage") in ("cleaned", "complete"):
        final = [
            "# Vibe Design Arena Final Report",
            "",
            f"- Arena ID: {_get(state, 'arenaId', default='')}",
            f"- Selected style: {_get(state, 'selection', 'style', default='')}",
            f"- Selected branch: {_get(state, 'selection', 'branch', default='')}",
            f"- Merge method: {_get(state, 'merge', 'method', default='')}",
            f"- Post-merge SHA: {_get(state, 'merge', 'postMergeSha', default='')}",
            f"- Stage: {_get(state, 'stage', default='')}",
            "",
            "## Retained branches",
        ]
        for name in STYLES:
            style = _get(state, "styles", name, default={})
            final.append(
                f"- {_get(style, 'branch', default='')}: "
                f"{_get(style, 'retainedCommit', default='')}"
            )
        write_utf8_lf(generated_root / "final-report.md", "\n".join(final) + "\n")