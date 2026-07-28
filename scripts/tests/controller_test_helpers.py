from __future__ import annotations

import json
import os
import socket
import subprocess
import sys
from pathlib import Path
from typing import Any, Sequence

SCRIPT_ROOT = Path(__file__).resolve().parents[1]
SKILL_ROOT = SCRIPT_ROOT.parent
ARENA = SCRIPT_ROOT / "arena.py"
STYLES = ("style-a", "style-b", "style-c")


def write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(text.replace("\r\n", "\n").replace("\r", "\n").encode("utf-8"))


def write_json(path: Path, value: Any) -> None:
    write_text(path, json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def run(argv: Sequence[str], *, cwd: Path | None = None, check: bool = True, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[bytes]:
    environment = os.environ.copy()
    if env:
        environment.update(env)
    completed = subprocess.run(list(map(str, argv)), cwd=cwd, env=environment, shell=False, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    if check and completed.returncode:
        raise AssertionError(f"command failed ({completed.returncode}): {argv!r}\nstdout={completed.stdout.decode('utf-8', 'replace')}\nstderr={completed.stderr.decode('utf-8', 'replace')}")
    return completed


def git(repo: Path, *args: str, check: bool = True) -> str:
    completed = run(("git", "-C", str(repo), *args), check=check)
    return completed.stdout.decode("utf-8", "replace").strip()


def invoke(state: Path, command: str, *args: str, expect_failure: bool = False) -> dict[str, Any] | str:
    completed = run((sys.executable, str(ARENA), command, "--state", str(state), *args), check=False)
    if expect_failure:
        if completed.returncode == 0:
            raise AssertionError(f"{command} unexpectedly succeeded: {completed.stdout.decode('utf-8', 'replace')}")
        return completed.stderr.decode("utf-8", "replace").strip()
    if completed.returncode:
        raise AssertionError(f"{command} failed: {completed.stderr.decode('utf-8', 'replace')}")
    return json.loads(completed.stdout.decode("utf-8"))


def free_ports(count: int = 3) -> list[int]:
    sockets: list[socket.socket] = []
    try:
        for _ in range(count):
            item = socket.socket()
            item.bind(("127.0.0.1", 0))
            sockets.append(item)
        return [int(item.getsockname()[1]) for item in sockets]
    finally:
        for item in sockets:
            item.close()


def qa_result(state: dict[str, Any], style_name: str, *, overall: str = "PASS") -> dict[str, Any]:
    style = state["styles"][style_name]
    evidence_root = Path(state["paths"]["recordsRoot"]) / "evidence" / style_name
    evidence_root.mkdir(parents=True, exist_ok=True)
    evidence: list[dict[str, Any]] = [{"id": f"brief.{style_name}", "kind": "design-brief", "description": "Frozen design brief contract", "path": style["brief"]["frozenPath"], "scenarioId": None, "viewportId": None, "route": None}]
    for viewport in ("mobile", "tablet", "desktop", "desktop-equivalent-200-percent"):
        screenshot = evidence_root / f"{viewport}.png"
        screenshot.write_bytes(b"\x89PNG\r\n\x1a\nphase3")
        evidence.extend((
            {"id": f"shot.{style_name}.{viewport}", "kind": "screenshot", "description": f"Lifecycle screenshot {viewport}", "path": str(screenshot), "scenarioId": "shared-lifecycle-evidence", "viewportId": viewport, "route": style["preview"]["url"]},
            {"id": f"axe.{style_name}.{viewport}", "kind": "axe", "description": f"Lifecycle axe result {viewport}", "path": None, "scenarioId": "shared-lifecycle-evidence", "viewportId": viewport, "route": style["preview"]["url"]},
        ))
    if overall in ("FAIL", "BLOCKED"):
        status = overall
        return {
            "schemaVersion": "1.0", "arenaId": state["arenaId"], "style": style_name, "candidateGeneration": style["candidateGeneration"], "candidateCommit": style["implementationCommit"],
            "generatedAt": "2026-01-01T00:00:00Z", "configSha256": "0" * 64, "baseUrl": style["preview"]["url"], "outputRoot": str(evidence_root), "overall": overall,
            "environmentBlocked": overall == "BLOCKED", "blocker": "Lifecycle environment blocker" if overall == "BLOCKED" else None,
            "proxyDisclosure": {"name": "equivalent-200-percent-layout", "isRealBrowserZoom": False, "deviceScaleFactor": 1},
            "coverage": {"required": 1, "applicable": 0, "notApplicable": 0, "executed": 1, "failed": 1},
            "checks": [{"id": f"qa.{style_name}.{overall.lower()}", "scenarioId": "environment", "viewportId": None, "applicability": "required", "status": status, "reason": "controlled lifecycle result", "approvedBy": None, "evidenceIds": [], "assertions": []}],
            "evidence": evidence, "browserErrors": [],
        }
    checks: list[dict[str, Any]] = []
    assertions = lambda scenario, viewport: [
        {"id": f"{scenario}.{viewport}.overflow", "type": "overflow", "status": "PASS", "expected": False, "actual": False},
        {"id": f"{scenario}.{viewport}.axe", "type": "axe", "status": "PASS", "expected": 0, "actual": []},
        {"id": f"{scenario}.{viewport}.browser", "type": "browser-errors", "status": "PASS", "expected": 0, "actual": 0},
    ]
    for scenario in ("primary", "dense", "touch-targets", "keyboard-traversal", "focus-visibility", "focus-return", "reduced-motion", "rapid-toggle"):
        for viewport in ("mobile", "tablet", "desktop"):
            checks.append({"id": f"qa.{style_name}.{scenario}.{viewport}", "scenarioId": scenario, "viewportId": viewport, "applicability": "required", "status": "PASS", "reason": None, "approvedBy": None, "evidenceIds": [f"shot.{style_name}.{viewport}", f"axe.{style_name}.{viewport}"], "assertions": assertions(scenario, viewport)})
    proxy = "desktop-equivalent-200-percent"
    checks.append({"id": f"qa.{style_name}.equivalent-200-percent-layout.{proxy}", "scenarioId": "equivalent-200-percent-layout", "viewportId": proxy, "applicability": "required", "status": "PASS", "reason": None, "approvedBy": None, "evidenceIds": [f"shot.{style_name}.{proxy}", f"axe.{style_name}.{proxy}"], "assertions": assertions("equivalent-200-percent-layout", proxy)})
    for scenario in ("loading", "empty", "error", "disabled", "stale-data", "long-text", "missing-value", "negative-number", "extreme-number", "container-overflow"):
        checks.append({"id": f"qa.{style_name}.{scenario}.not-applicable", "scenarioId": scenario, "viewportId": None, "applicability": "not-applicable", "status": "NOT-APPLICABLE", "reason": f"Lifecycle product contract excludes {scenario} behavior.", "approvedBy": "phase3-lifecycle", "evidenceIds": [f"brief.{style_name}"], "assertions": []})
    return {
        "schemaVersion": "1.0", "arenaId": state["arenaId"], "style": style_name, "candidateGeneration": style["candidateGeneration"], "candidateCommit": style["implementationCommit"],
        "generatedAt": "2026-01-01T00:00:00Z", "configSha256": "0" * 64, "baseUrl": style["preview"]["url"], "outputRoot": str(evidence_root), "overall": "PASS", "environmentBlocked": False, "blocker": None,
        "proxyDisclosure": {"name": "equivalent-200-percent-layout", "isRealBrowserZoom": False, "deviceScaleFactor": 1},
        "coverage": {"required": 25, "applicable": 0, "notApplicable": 10, "executed": 25, "failed": 0}, "checks": checks, "evidence": evidence, "browserErrors": [],
    }