# Controller Conformance Fixtures

Phase 0 freezes the PowerShell controller as the temporary behavioral oracle.

controller-contract.json is the reviewable contract manifest. It freezes the
16 controller commands, four integrity actions, state order, schema hashes,
authorization boundaries, side-effect classes, and trace-normalization rules.

capture-powershell-traces.ps1 is a Windows black-box capture tool. It records
argv, fixture preconditions, exit code, separated stdout/stderr, normalized
diagnostics, and unexpected files for every public command/action. Its default
fixture is deliberately non-mutating and exercises the missing-input/state
boundary. Full success and blocking-path traces continue to come from
phase1-smoke.ps1; Phase 2 will add equivalent Python fixtures and differential
comparison.

Normalization may replace fixture roots, UUIDs, timestamps, PIDs, process
creation times, ports, and Git commit IDs. It must not replace status, stages,
revision deltas, branch names, error categories, relative artifact locations,
or file hashes.

PowerShell remains canonical through Phase 1. Do not use these fixtures as
authority to reproduce a newly discovered unsafe PowerShell bug; classify each
difference as PARITY, BUGFIX, PLATFORM, or NON-CONTRACTUAL.