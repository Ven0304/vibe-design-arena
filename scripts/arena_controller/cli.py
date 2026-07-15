from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any, Sequence

from .constants import CONTROLLER_COMMANDS, INTEGRITY_ACTIONS, STYLES
from .controller import Controller
from .errors import ArenaError
from .integrity import (
    DEFAULT_REFERENCE_FILES,
    canonical_text_facts,
    check_brief_attributes,
    integrity_result,
    normalize_canonical_text,
    reference_snapshot,
    verify_brief,
)
from .schema import SchemaRegistry


def _add(parser: argparse.ArgumentParser, *names: str, **kwargs: Any) -> None:
    parser.add_argument(*names, **kwargs)


def controller_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="arena.py")
    parser.add_argument("command", choices=CONTROLLER_COMMANDS)
    _add(parser, "--state", "-State", required=True)
    _add(parser, "--expected-revision", "-ExpectedRevision", type=int, default=-1)
    _add(parser, "--repo", "-Repo")
    _add(parser, "--skill-root", "-SkillRoot")
    _add(parser, "--config", "-Config")
    _add(
        parser,
        "--apply-attributes",
        "-ApplyAttributes",
        action="store_true",
        default=False,
    )
    _add(parser, "--brief-root", "-BriefRoot")
    _add(parser, "--result-path", "-ResultPath")
    _add(parser, "--style", "-Style", choices=STYLES)
    _add(parser, "--result", "-Result", choices=("PASS", "FAIL"))
    _add(parser, "--reviewer", "-Reviewer")
    _add(parser, "--evidence-ids", "-EvidenceIds", nargs="+")
    _add(parser, "--candidate-commit", "-CandidateCommit")
    _add(parser, "--remote", "-Remote", default="origin")
    _add(parser, "--branches", "-Branches", nargs="+")
    _add(
        parser,
        "--confirm-publish",
        "-ConfirmPublish",
        action="store_true",
        default=False,
    )
    return parser


def integrity_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="arena_integrity.py")
    parser.add_argument("action", choices=INTEGRITY_ACTIONS)
    _add(parser, "--skill-root", "-SkillRoot")
    _add(parser, "--reference-files", "-ReferenceFiles", nargs="+")
    _add(parser, "--path", "-Path")
    _add(parser, "--frozen-path", "-FrozenPath")
    _add(parser, "--working-path", "-WorkingPath")
    _add(parser, "--repository", "-Repository")
    _add(parser, "--commit", "-Commit")
    _add(parser, "--write", "-Write", action="store_true", default=False)
    return parser


def configure_stdio() -> None:
    for stream in (sys.stdout, sys.stderr):
        reconfigure = getattr(stream, "reconfigure", None)
        if reconfigure is not None:
            reconfigure(encoding="utf-8", errors="strict", newline="\n")


def emit_json(value: dict[str, Any]) -> None:
    sys.stdout.write(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def controller_main(argv: Sequence[str] | None = None) -> int:
    configure_stdio()
    parser = controller_parser()
    try:
        namespace = parser.parse_args(argv)
        options = vars(namespace)
        command = options.pop("command")
        emit_json(Controller().execute(command, options))
        return 0
    except ArenaError as exc:
        sys.stderr.write(str(exc) + "\n")
        return 1


def _require(value: Any, message: str) -> Any:
    if value is None or value == []:
        raise ArenaError(message)
    return value


def execute_integrity(action: str, options: dict[str, Any]) -> dict[str, Any]:
    if action == "snapshot":
        root = _require(options.get("skill_root"), "snapshot requires --skill-root.")
        files = options.get("reference_files") or DEFAULT_REFERENCE_FILES
        return integrity_result(action, "PASS", reference_snapshot(root, files))
    if action == "normalize-brief":
        path = _require(options.get("path"), "normalize-brief requires --path.")
        before = canonical_text_facts(path).as_dict()
        conversion = normalize_canonical_text(path, write=options.get("write", False))
        after = (
            canonical_text_facts(path).as_dict() if options.get("write", False) else before
        )
        status = (
            "CHANGED"
            if conversion["changed"]
            else ("PASS" if after["canonical"] else "FAIL")
        )
        return integrity_result(
            action,
            status,
            {"before": before, "conversion": conversion, "after": after},
        )
    if action == "check-attributes":
        repository = _require(
            options.get("repository"), "check-attributes requires --repository."
        )
        details = check_brief_attributes(repository)
        return integrity_result(action, "PASS" if details["valid"] else "FAIL", details)
    if action == "verify-brief":
        frozen = _require(
            options.get("frozen_path"), "verify-brief requires --frozen-path."
        )
        working = _require(
            options.get("working_path"), "verify-brief requires --working-path."
        )
        details = verify_brief(
            frozen,
            working,
            repository=options.get("repository"),
            commit=options.get("commit"),
        )
        return integrity_result(
            action, "PASS" if details.pop("matches") else "FAIL", details
        )
    raise ArenaError(f"Unknown integrity action: {action}")


def integrity_main(argv: Sequence[str] | None = None) -> int:
    configure_stdio()
    parser = integrity_parser()
    try:
        namespace = parser.parse_args(argv)
        options = vars(namespace)
        action = options.pop("action")
        result = execute_integrity(action, options)
        SchemaRegistry().validate("integrity-result", result)
        emit_json(result)
        return 0 if result["status"] != "FAIL" else 1
    except ArenaError as exc:
        action = "snapshot"
        if "namespace" in locals():
            action = getattr(namespace, "action", action)
        emit_json(integrity_result(action, "FAIL", {"error": str(exc)}))
        return 1