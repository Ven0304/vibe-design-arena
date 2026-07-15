from __future__ import annotations

from typing import Any

from .constants import STAGE_ORDER, STYLES
from .errors import ArenaError


def stage_index(stage: str) -> int:
    try:
        return STAGE_ORDER.index(stage)
    except ValueError as exc:
        raise ArenaError(f"Unknown Arena stage: {stage}") from exc


def empty_review() -> dict[str, Any]:
    return {
        "status": "PENDING",
        "reviewer": None,
        "timestamp": None,
        "candidateCommit": None,
        "qaResultSha256": None,
        "evidenceIds": [],
    }


def assert_exact_styles(styles: dict[str, Any]) -> None:
    if set(styles) != set(STYLES):
        raise ArenaError(
            "Arena state must contain exactly style-a, style-b, and style-c."
        )


def invalidate_candidate_evidence(style: dict[str, Any]) -> None:
    style["qaResultPath"] = None
    style["qaResultSha256"] = None
    style["reviews"] = {"visual": empty_review(), "direction": empty_review()}
    qualification = style.setdefault("qualification", {})
    for key in (
        "automatedQa",
        "mainAgentVisualReview",
        "directionConsistencyReview",
        "overall",
    ):
        qualification[key] = "PENDING"