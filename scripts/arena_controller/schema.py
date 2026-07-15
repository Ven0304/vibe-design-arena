from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from .errors import ArenaError, DependencyUnavailableError


SCHEMA_FILES = {
    "state": "arena-state.schema.json",
    "builder-result": "builder-result.schema.json",
    "integrity-result": "integrity-result.schema.json",
    "qa-config": "qa-config.schema.json",
    "qa-result": "qa-result.schema.json",
}


def _jsonschema():
    try:
        import jsonschema
    except ImportError as exc:
        raise DependencyUnavailableError(
            "Python controller dependency 'jsonschema' is missing. "
            "Install requirements-controller.txt in an approved isolated environment."
        ) from exc
    return jsonschema


class SchemaRegistry:
    def __init__(self, schema_root: str | Path | None = None) -> None:
        self.schema_root = (
            Path(schema_root)
            if schema_root
            else Path(__file__).resolve().parents[1] / "schemas"
        ).resolve()

    def path_for(self, name: str) -> Path:
        try:
            filename = SCHEMA_FILES[name]
        except KeyError as exc:
            raise ArenaError(f"Unknown Arena schema: {name}") from exc
        path = self.schema_root / filename
        if not path.is_file():
            raise ArenaError(f"Arena schema not found: {path}")
        return path

    def load(self, name: str) -> dict[str, Any]:
        path = self.path_for(name)
        try:
            value = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            raise ArenaError(f"Unable to load Arena schema {path}: {exc}") from exc
        if not isinstance(value, dict):
            raise ArenaError(f"Arena schema root must be an object: {path}")
        return value

    def validate(self, name: str, instance: Any) -> None:
        jsonschema = _jsonschema()
        schema = self.load(name)
        validator = jsonschema.validators.validator_for(schema)
        validator.check_schema(schema)
        errors = sorted(validator(schema).iter_errors(instance), key=lambda e: list(e.path))
        if errors:
            first = errors[0]
            location = "/".join(map(str, first.absolute_path)) or "<root>"
            raise ArenaError(f"{name} schema validation failed at {location}: {first.message}")