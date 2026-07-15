from __future__ import annotations

from pathlib import Path
from typing import Any

from .constants import CONTROLLER_COMMANDS
from .errors import PhaseUnavailableError
from .schema import SchemaRegistry
from .storage import read_json


def status_summary(state: dict[str, Any]) -> dict[str, Any]:
    repository = state["repository"]
    return {
        "arenaId": state["arenaId"],
        "stateRevision": state["stateRevision"],
        "stage": state["stage"],
        "status": state["status"],
        "blockingReason": state.get("blockingReason"),
        "baseBranch": repository["baseBranch"],
        "baseSha": repository["baseSha"],
        "selection": state.get("selection"),
        "styles": state["styles"],
        "publication": state["publication"],
    }


class Controller:
    """Phase 1 dispatch boundary.

    PowerShell remains canonical. Only the read-only status command executes
    against real state in Phase 1; all mutating commands are parsed but fail
    closed until differential parity work begins in Phase 2.
    """

    def __init__(self, *, schemas: SchemaRegistry | None = None) -> None:
        self.schemas = schemas or SchemaRegistry()

    def execute(self, command: str, options: dict[str, Any]) -> dict[str, Any]:
        if command not in CONTROLLER_COMMANDS:
            raise PhaseUnavailableError(f"Unknown controller command: {command}")
        if command == "status":
            state = read_json(Path(options["state"]).resolve())
            self.schemas.validate("state", state)
            return status_summary(state)
        raise PhaseUnavailableError(
            f"Python command '{command}' is present for Phase 1 contract testing "
            "but is not enabled for product workflow cutover. Use scripts/arena.ps1."
        )