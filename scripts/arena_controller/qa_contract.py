from __future__ import annotations

from pathlib import Path
from typing import Any

from .errors import ArenaError
from .paths import child_path
from .schema import SchemaRegistry


def validate_qa_result(
    result: dict[str, Any],
    *,
    schemas: SchemaRegistry,
    expected_arena_id: str,
    expected_style: str,
    expected_generation: int,
    expected_commit: str,
    result_path: str | Path,
    evidence_root: str | Path,
) -> None:
    schemas.validate("qa-result", result)
    expected = (
        ("arenaId", expected_arena_id),
        ("style", expected_style),
        ("candidateGeneration", expected_generation),
        ("candidateCommit", expected_commit),
    )
    for key, value in expected:
        if result.get(key) != value:
            raise ArenaError(
                f"QA result identity mismatch for {key}. "
                f"Expected {value!r}; got {result.get(key)!r}."
            )
    child_path(evidence_root, result_path)
    output_root = child_path(evidence_root, result["outputRoot"], allow_root=True)
    if result["overall"] == "BLOCKED" and not result["environmentBlocked"]:
        raise ArenaError("QA BLOCKED requires environmentBlocked=true.")
    if result["overall"] != "BLOCKED" and result["environmentBlocked"]:
        raise ArenaError("environmentBlocked=true requires QA overall=BLOCKED.")
    proxy = result["proxyDisclosure"]
    if (
        proxy["name"] != "equivalent-200-percent-layout"
        or proxy["isRealBrowserZoom"] is not False
        or proxy["deviceScaleFactor"] != 1
    ):
        raise ArenaError("QA proxy disclosure contract is invalid.")
    check_ids = [item["id"] for item in result["checks"]]
    evidence_ids = [item["id"] for item in result["evidence"]]
    if len(check_ids) != len(set(check_ids)):
        raise ArenaError("QA result contains duplicate check IDs.")
    if len(evidence_ids) != len(set(evidence_ids)):
        raise ArenaError("QA result contains duplicate evidence IDs.")
    known = set(evidence_ids)
    for check in result["checks"]:
        missing = set(check["evidenceIds"]) - known
        if missing:
            raise ArenaError(
                f"QA check {check['id']} references unknown evidence: {sorted(missing)}"
            )
    for evidence in result["evidence"]:
        path = evidence.get("path")
        if path:
            child_path(output_root, path, allow_root=True)