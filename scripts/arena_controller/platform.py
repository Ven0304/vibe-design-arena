from __future__ import annotations

import os
import subprocess
from dataclasses import dataclass


@dataclass(frozen=True)
class ProcessCreationPolicy:
    creationflags: int = 0
    start_new_session: bool = False


def managed_process_policy() -> ProcessCreationPolicy:
    if os.name == "nt":
        return ProcessCreationPolicy(
            creationflags=(
                subprocess.CREATE_NEW_PROCESS_GROUP | subprocess.CREATE_NO_WINDOW
            )
        )
    return ProcessCreationPolicy(start_new_session=True)


def path_case_sensitive() -> bool:
    return os.name != "nt"