# Phase 2 Differential Decisions

PowerShell remains the canonical runtime throughout Phase 2. Differences listed here are deliberate exceptions to byte-for-byte behavioral parity; they do not change the public command, JSON schema, state-transition, Git-authorization, or Node QA contracts.

## BUGFIX-PROCESS-001 — verified preview process trees

Commands: `start-previews`, `stop-previews`.

The PowerShell oracle records and checks PID plus process start time, then stops the single recorded process. The Python implementation additionally binds executable, argument vector, working directory, and creation time and stops only the descendants of that fully verified process. A missing process may clear its stale record; an inaccessible or mismatched process fails closed. Python never kills by port or PID alone.

This is required by the migration safety contract and is covered by `test_process_stop_requires_full_verified_identity`, the full lifecycle smoke, and `controller-differential.ps1`.

## TRANSIENT-PREVIEW-001 — readiness retry count

The two runtimes can need different numbers of explicit `start-previews` retries while a newly spawned local HTTP server becomes ready. Every accepted retry still performs exactly one optimistic-concurrency revision. The differential gate compares the normalized terminal lifecycle and reports, rather than hides, any final revision difference caused solely by those explicit retries.
