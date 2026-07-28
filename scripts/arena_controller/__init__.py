"""Canonical Vibe Design Arena controller package.

The package keeps state, Git, integrity, process, QA, record, and platform
concerns in explicit portability seams. PowerShell entrypoints are deprecated
argument-preserving forwarders during the compatibility window.
"""

from .constants import CONTROLLER_COMMANDS, INTEGRITY_ACTIONS, STAGE_ORDER, STYLES

__all__ = ["CONTROLLER_COMMANDS", "INTEGRITY_ACTIONS", "STAGE_ORDER", "STYLES"]