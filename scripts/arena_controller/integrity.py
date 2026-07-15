from __future__ import annotations

import hashlib
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable

from .errors import ArenaError
from .git import Git
from .paths import absolute_path


DEFAULT_REFERENCE_FILES = (
    "SKILL.md",
    "references/direction-brief.md",
    "references/anti-slop.md",
    "references/visual-quality-bar.md",
    "references/interaction-quality-bar.md",
    "references/arena-scorecard.md",
)


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def sha256_file(path: str | Path) -> str:
    target = absolute_path(path, must_exist=True)
    digest = hashlib.sha256()
    with target.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


@dataclass(frozen=True)
class CanonicalTextFacts:
    path: str
    validUtf8: bool
    hasBom: bool
    hasCrLf: bool
    hasBareCr: bool
    canonical: bool
    sha256: str

    def as_dict(self) -> dict[str, Any]:
        return self.__dict__.copy()


def canonical_text_facts(path: str | Path) -> CanonicalTextFacts:
    target = absolute_path(path, must_exist=True)
    data = target.read_bytes()
    has_bom = data.startswith(b"\xef\xbb\xbf")
    try:
        text = data.decode("utf-8")
        valid = True
    except UnicodeDecodeError:
        text = ""
        valid = False
    has_crlf = valid and "\r\n" in text
    has_bare_cr = valid and "\r" in text.replace("\r\n", "")
    return CanonicalTextFacts(
        path=str(target),
        validUtf8=valid,
        hasBom=has_bom,
        hasCrLf=has_crlf,
        hasBareCr=has_bare_cr,
        canonical=valid and not has_bom and "\r" not in text,
        sha256=hashlib.sha256(data).hexdigest(),
    )


def normalize_canonical_text(path: str | Path, *, write: bool = False) -> dict[str, Any]:
    target = absolute_path(path, must_exist=True)
    data = target.read_bytes()
    offset = 3 if data.startswith(b"\xef\xbb\xbf") else 0
    try:
        text = data[offset:].decode("utf-8")
    except UnicodeDecodeError as exc:
        raise ArenaError(f"File is not valid UTF-8: {target}") from exc
    canonical = text.replace("\r\n", "\n").replace("\r", "\n")
    changed = offset > 0 or canonical != text
    if write and changed:
        target.write_bytes(canonical.encode("utf-8"))
    return {
        "path": str(target),
        "changed": changed,
        "written": bool(write),
        "sha256": sha256_file(target) if write else None,
    }


def check_brief_attributes(repository: str | Path, *, git: Git | None = None) -> dict[str, Any]:
    adapter = git or Git()
    result = adapter.run(
        repository,
        ("check-attr", "text", "eol", "--", "DESIGN_BRIEF.md"),
        allow_failure=True,
    )
    output = result.output
    return {
        "valid": (
            result.exit_code == 0
            and "DESIGN_BRIEF.md: text: set" in output
            and "DESIGN_BRIEF.md: eol: lf" in output
        ),
        "output": output,
        "requiredRule": "/DESIGN_BRIEF.md text eol=lf",
    }


def reference_snapshot(
    skill_root: str | Path,
    files: Iterable[str] = DEFAULT_REFERENCE_FILES,
    *,
    git: Git | None = None,
) -> dict[str, Any]:
    root = absolute_path(skill_root, must_exist=True)
    entries = []
    for relative in files:
        path = absolute_path(root / relative, must_exist=True)
        entries.append(
            {
                "relativePath": Path(relative).as_posix(),
                "absolutePath": str(path),
                "sha256": sha256_file(path),
            }
        )
    adapter = git or Git()
    top = adapter.run(root, ("rev-parse", "--show-toplevel"), allow_failure=True)
    git_root = None
    provenance = "NO-GIT/HASHED"
    if top.exit_code == 0:
        git_root = top.stdout
        commit = adapter.run(root, ("rev-parse", "HEAD")).stdout
        dirty = adapter.run(
            root,
            ("status", "--short", "--", "SKILL.md", "references", "scripts"),
        ).stdout
        provenance = commit if not dirty.strip() else "DIRTY-GIT/HASHED"
    material = "|".join(f"{item['relativePath']}:{item['sha256']}" for item in entries)
    snapshot_id = hashlib.sha256(material.encode("utf-8")).hexdigest()[:16]
    return {
        "snapshotId": snapshot_id,
        "skillRoot": str(root),
        "gitRoot": git_root,
        "provenance": provenance,
        "files": entries,
    }


def verify_brief(
    frozen_path: str | Path,
    working_path: str | Path,
    *,
    repository: str | Path | None = None,
    commit: str | None = None,
    git: Git | None = None,
) -> dict[str, Any]:
    if bool(repository) != bool(commit):
        raise ArenaError("verify-brief requires repository and commit together.")
    frozen = canonical_text_facts(frozen_path)
    working = canonical_text_facts(working_path)
    frozen_hash = frozen.sha256
    working_hash = working.sha256
    blob_hash = None
    if repository and commit:
        blob_hash = (git or Git()).blob_sha256(repository, commit)
    matches = (
        frozen.canonical
        and working.canonical
        and frozen_hash == working_hash
        and (blob_hash is None or blob_hash == frozen_hash)
    )
    if matches:
        classification = "exact-match"
    elif not working.validUtf8:
        classification = "invalid-utf8"
    elif working.hasBom:
        classification = "bom-mismatch"
    elif working.hasCrLf or working.hasBareCr:
        classification = "line-ending-mismatch"
    else:
        classification = "content-mismatch"
    return {
        "matches": matches,
        "frozen": frozen.as_dict(),
        "working": working.as_dict(),
        "frozenSha256": frozen_hash,
        "workingSha256": working_hash,
        "gitBlobSha256": blob_hash,
        "classification": classification,
    }


def integrity_result(action: str, status: str, details: dict[str, Any]) -> dict[str, Any]:
    return {
        "schemaVersion": "1.0",
        "action": action,
        "status": status,
        "timestamp": utc_now(),
        "details": details,
    }