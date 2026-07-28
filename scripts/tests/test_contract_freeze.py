from __future__ import annotations

import hashlib
import json
import unittest
from pathlib import Path

SCRIPT_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = SCRIPT_ROOT.parent

import sys
sys.path.insert(0, str(SCRIPT_ROOT))

from arena_controller.constants import CONTROLLER_COMMANDS, INTEGRITY_ACTIONS, STAGE_ORDER
from arena_controller.cli import controller_parser, integrity_parser


class ContractFreezeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.contract = json.loads(
            (Path(__file__).parent / "conformance" / "controller-contract.json").read_text(
                encoding="utf-8"
            )
        )

    def test_public_command_sets_match_contract_and_python(self) -> None:
        self.assertEqual(tuple(self.contract["controllerCommands"]), CONTROLLER_COMMANDS)
        self.assertEqual(tuple(self.contract["integrityActions"]), INTEGRITY_ACTIONS)
        self.assertEqual(self.contract["controllerEntrypoint"], "scripts/arena.py")
        self.assertEqual(self.contract["integrityEntrypoint"], "scripts/arena_integrity.py")
        self.assertTrue((REPO_ROOT / self.contract["controllerEntrypoint"]).is_file())
        self.assertTrue((REPO_ROOT / self.contract["integrityEntrypoint"]).is_file())

    def test_state_order_and_schema_hashes_are_frozen(self) -> None:
        self.assertEqual(tuple(self.contract["stageOrder"]), STAGE_ORDER)
        schema_root = SCRIPT_ROOT / "schemas"
        actual = {
            path.name: hashlib.sha256(path.read_bytes()).hexdigest()
            for path in schema_root.glob("*.json")
        }
        self.assertEqual(self.contract["schemaSha256"], actual)

    def test_controller_parser_accepts_both_option_styles(self) -> None:
        parser = controller_parser()
        for command in CONTROLLER_COMMANDS:
            parsed = parser.parse_args([command, "-State", "C:/run/records/arena-state.json"])
            self.assertEqual(parsed.command, command)
            parsed = parser.parse_args([command, "--state", "C:/run/records/arena-state.json"])
            self.assertEqual(parsed.command, command)
        aliases = parser.parse_args(
            [
                "publish", "-State", "C:/run/records/arena-state.json",
                "-ExpectedRevision", "7", "-Branches", "main", "style-a",
                "-ConfirmPublish",
            ]
        )
        self.assertEqual(aliases.expected_revision, 7)
        self.assertEqual(aliases.branches, ["main", "style-a"])
        self.assertTrue(aliases.confirm_publish)

    def test_integrity_parser_accepts_all_actions_and_aliases(self) -> None:
        parser = integrity_parser()
        for action in INTEGRITY_ACTIONS:
            self.assertEqual(parser.parse_args([action]).action, action)
        parsed = parser.parse_args(["verify-brief", "-FrozenPath", "a", "-WorkingPath", "b"])
        self.assertEqual(parsed.frozen_path, "a")
        self.assertEqual(parsed.working_path, "b")

    def test_powershell_runtime_is_retired(self) -> None:
        self.assertFalse(list(SCRIPT_ROOT.rglob("*.ps1")))
        self.assertFalse(list(SCRIPT_ROOT.rglob("*.psm1")))


if __name__ == "__main__":
    unittest.main()