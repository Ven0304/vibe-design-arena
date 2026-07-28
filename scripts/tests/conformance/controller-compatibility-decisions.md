# Controller Compatibility Decisions

Python preserves the public command, JSON schema, state-transition, Git authorization, and Node QA contracts. The following named differences repair unsafe or non-portable behavior instead of reproducing it.

## BUGFIX-PROCESS-001 — verified preview process trees

Commands: `start-previews`, `stop-previews`.

The PowerShell oracle recorded PID plus process start time and stopped only the single recorded process. Python binds executable, argument vector, working directory, and creation time, then stops only that verified process tree. It never kills by port or PID alone. Coverage: `test_process_stop_requires_full_verified_identity`, `test_process_tree_stop_does_not_terminate_unrelated_process`, PID-reuse simulation, full lifecycle, and the Phase 2 differential.

## BUGFIX-MERGE-RESUME-001 — conflict recovery before branch switching

Command: `merge`.

A conflict remains blocked for user judgment with `MERGE_HEAD` intact. After the user resolves and stages the conflict, rerunning `merge` now inspects the in-progress merge before any `git switch`, verifies that recovery is on the recorded base branch, commits the resolved merge, and continues post-merge validation. No conflict is automatically resolved or aborted. Coverage: the full lifecycle conflict-and-resume path.

## BUGFIX-CLEANUP-PREFLIGHT-001 — validate all worktrees before removal

Command: `cleanup`.

Cleanup now validates the registry, branch, preview state, and dirty status of all three candidate worktrees before removing any one of them. An ambiguous untracked file therefore refuses cleanup with no partial worktree removal and no revision change. Removal remains non-force and all three branches remain retained. Coverage: the full lifecycle cleanup-refusal and final branch-retention path.

## BUGFIX-RUNNER-PASS-001 — reject false-green Node output

The combined Python test runner now requires the Node contract result to be a JSON object with `status=PASS`. Native nonzero, empty output, invalid JSON, arrays, and explicit non-PASS results all fail closed. Coverage: `test_entrypoint_negative.py`.

## PLATFORM-HASH-001 — self-contained legacy SHA-256

During the compatibility window, clean Hosted Windows PowerShell sessions did not reliably resolve `Get-FileHash` from the legacy module. The retained oracle used the byte-equivalent .NET SHA-256 stream implementation. This compatibility-only repair was validated by the Windows differential and legacy-state fixture before PowerShell retirement.

## TRANSIENT-PREVIEW-001 — readiness retry count

PowerShell and Python could need different numbers of explicit `start-previews` retries while a local HTTP server became ready. Every accepted retry still performed exactly one optimistic-concurrency revision. Differential evidence compared normalized terminal lifecycle facts rather than treating retry-dependent final revision counts as semantic drift.