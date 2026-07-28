# Controller Conformance Contract

Python is the sole controller runtime after Phase 5. `controller-contract.json` is the reviewable contract manifest for the 16 controller commands, four integrity actions, state order, schema hashes, authorization boundaries, side-effect classes, and trace-normalization rules.

Run `python scripts/tests/run_controller_tests.py` for the permanent conformance suite. It covers storage, locking, Git lifecycle behavior, process identity, schema validation, all public fail-closed entrypoints, the complete three-candidate lifecycle, legacy-state resume, retirement fault injection, and the retained Node QA contract.

`fixtures/legacy-powershell-preflight-state-v1.json` is a normalized historical artifact, not an executable oracle. It proves that Python can resume a schema `1.0` state written by the retired controller without conversion. Machine paths are replaced only by declared fixture tokens.

The migration-era difference record remains in [controller-compatibility-decisions.md](controller-compatibility-decisions.md). It classifies reviewed differences as PARITY, BUGFIX, PLATFORM, NON-CONTRACTUAL, or TRANSIENT and records the tests that prevent unsafe legacy behavior from returning.
