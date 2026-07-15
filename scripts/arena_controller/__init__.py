"""Python foundation for the Vibe Design Arena controller.

PowerShell remains the canonical workflow implementation through migration
Phase 1. The package is intentionally split into testable portability seams.
"""

from .constants import CONTROLLER_COMMANDS, INTEGRITY_ACTIONS, STAGE_ORDER, STYLES

__all__ = ["CONTROLLER_COMMANDS", "INTEGRITY_ACTIONS", "STAGE_ORDER", "STYLES"]