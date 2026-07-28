# Controller Conformance Fixtures

Phase 0 froze the PowerShell controller as the temporary behavioral oracle. In
Phase 3, Python is the canonical runtime; the retained `arena.phase2.ps1` and
`arena-integrity.phase2.ps1` files are historical Phase 2 oracles used only for
compatibility and differential evidence. Public `.ps1` entries are deprecated,
argument-preserving Python forwarders.

`controller-contract.json` is the reviewable contract manifest. It freezes the
16 controller commands, four integrity actions, state order, schema hashes,
authorization boundaries, side-effect classes, and trace-normalization rules.

`capture-powershell-traces.ps1` is a Windows black-box capture tool against the
retained Phase 2 oracle. It records argv, fixture preconditions, exit code,
separated stdout/stderr, normalized diagnostics, and unexpected files for every
public command/action. Full success and blocking-path traces come from
`phase1-smoke.ps1` and `controller-differential.ps1`. The cross-platform
canonical lifecycle and Node QA boundary run from `test_lifecycle_smoke.py`
through `run_phase3.py`.

Normalization may replace fixture roots, UUIDs, timestamps, PIDs, process
creation times, ports, and Git commit IDs. It must not replace status, stages,
revision deltas, branch names, error categories, relative artifact locations,
or file hashes.

Do not use the historical oracle as authority to reproduce a newly discovered
unsafe PowerShell bug. Classify each difference as PARITY, BUGFIX, PLATFORM,
NON-CONTRACTUAL, or TRANSIENT, with an explicit reason.
