from __future__ import annotations

import copy
import json
import os
import tempfile
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Callable, Iterator

from .constants import EVENT_OUTCOMES
from .errors import ArenaError, DependencyUnavailableError, RevisionMismatchError
from .integrity import utc_now
from .schema import SchemaRegistry


def _portalocker():
    try:
        import portalocker
    except ImportError as exc:
        raise DependencyUnavailableError(
            "Python controller dependency 'portalocker' is missing. "
            "Install requirements-controller.txt in an approved isolated environment."
        ) from exc
    return portalocker


def read_json(path: str | Path) -> dict[str, Any]:
    target = Path(path)
    if not target.is_file():
        raise ArenaError(f"JSON file not found: {target}")
    try:
        value = json.loads(target.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise ArenaError(f"Unable to read JSON file {target}: {exc}") from exc
    if not isinstance(value, dict):
        raise ArenaError(f"JSON document root must be an object: {target}")
    return value


def write_utf8_lf(path: str | Path, content: str) -> None:
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    normalized = content.replace("\r\n", "\n").replace("\r", "\n")
    target.write_bytes(normalized.encode("utf-8"))


def write_json_atomic(path: str | Path, value: Any) -> None:
    target = Path(path).resolve()
    target.parent.mkdir(parents=True, exist_ok=True)
    payload = (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{target.name}.", suffix=".tmp", dir=target.parent
    )
    temporary = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "wb") as handle:
            handle.write(payload)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, target)
        try:
            directory_fd = os.open(target.parent, os.O_RDONLY)
        except (AttributeError, OSError):
            directory_fd = None
        if directory_fd is not None:
            try:
                os.fsync(directory_fd)
            finally:
                os.close(directory_fd)
    finally:
        if temporary.exists():
            temporary.unlink()


def append_event(
    state_path: str | Path,
    command: str,
    outcome: str,
    *,
    revision: int = -1,
    message: str = "",
    details: Any = None,
) -> None:
    if outcome not in EVENT_OUTCOMES:
        raise ArenaError(f"Unknown event outcome: {outcome}")
    records_root = Path(state_path).resolve().parent
    if not records_root.is_dir():
        return
    event = {
        "timestamp": utc_now(),
        "command": command,
        "outcome": outcome,
        "stateRevision": revision,
        "message": message,
        "details": details,
    }
    with (records_root / "events.jsonl").open("ab") as handle:
        handle.write(
            (json.dumps(event, ensure_ascii=False, separators=(",", ":")) + "\n").encode(
                "utf-8"
            )
        )
        handle.flush()
        os.fsync(handle.fileno())


class StateStore:
    def __init__(
        self,
        state_path: str | Path,
        *,
        schemas: SchemaRegistry | None = None,
        record_writer: Callable[[dict[str, Any], Path], None] | None = None,
        lock_timeout: float = 10.0,
    ) -> None:
        self.state_path = Path(state_path).resolve()
        self.lock_path = Path(f"{self.state_path}.lock")
        self.schemas = schemas or SchemaRegistry()
        self.record_writer = record_writer
        self.lock_timeout = lock_timeout

    @contextmanager
    def lock(self) -> Iterator[None]:
        portalocker = _portalocker()
        self.lock_path.parent.mkdir(parents=True, exist_ok=True)
        try:
            with portalocker.Lock(
                str(self.lock_path), mode="a+b", timeout=self.lock_timeout
            ):
                yield
        except portalocker.exceptions.LockException as exc:
            raise ArenaError(
                f"Arena state is locked by another writer: {self.lock_path}"
            ) from exc

    def read(self) -> dict[str, Any]:
        state = read_json(self.state_path)
        self.schemas.validate("state", state)
        return state

    def create(self, state: dict[str, Any], *, operation: str) -> dict[str, Any]:
        with self.lock():
            if self.state_path.exists():
                raise ArenaError(f"Arena state already exists: {self.state_path}")
            candidate = copy.deepcopy(state)
            self.schemas.validate("state", candidate)
            write_json_atomic(self.state_path, candidate)
            append_event(
                self.state_path,
                operation,
                "success",
                revision=int(candidate["stateRevision"]),
            )
            if self.record_writer:
                self.record_writer(candidate, self.state_path)
            return candidate

    def mutate(
        self,
        *,
        operation: str,
        expected_revision: int,
        mutation: Callable[[dict[str, Any]], None],
        outcome: str = "success",
        message: str = "",
        details: Any = None,
    ) -> dict[str, Any]:
        with self.lock():
            current = self.read()
            actual = int(current["stateRevision"])
            if expected_revision != actual:
                raise RevisionMismatchError(
                    f"State revision mismatch. Expected {expected_revision}; current {actual}."
                )
            candidate = copy.deepcopy(current)
            mutation(candidate)
            candidate["stateRevision"] = actual + 1
            candidate["updatedAt"] = utc_now()
            self.schemas.validate("state", candidate)
            write_json_atomic(self.state_path, candidate)
            append_event(
                self.state_path,
                operation,
                outcome,
                revision=int(candidate["stateRevision"]),
                message=message,
                details=details,
            )
            if self.record_writer:
                self.record_writer(candidate, self.state_path)
            return candidate