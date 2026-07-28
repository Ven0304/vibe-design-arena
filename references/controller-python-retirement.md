# Python Controller Retirement Handoff

## Final status

Phase 5 is complete: Python is the sole controller runtime, and the Node QA runner remains an independent artifact producer. The final runtime preserves schema version `1.0`, all 16 controller commands, all four integrity actions, lifecycle transitions, Git and publication authorization boundaries, process-identity safety, and the Node PASS/FAIL/BLOCKED import contract.

## Last shim-supported release

[`controller-python-v1.0.1-shim`](https://github.com/Ven0304/vibe-design-arena/releases/tag/controller-python-v1.0.1-shim), at commit `dee56a0`, is the last release containing the deprecated PowerShell forwarders and the historical PowerShell oracle. Use it only if a caller has not yet moved to the direct Python launcher.

## Direct replacements

Use an explicitly selected and approved Python 3.10+ interpreter:

```console
python scripts/arena.py <command> --state <absolute-path> ...
python scripts/arena_integrity.py <action> ...
```

The Python parser continues to accept the former PowerShell-style long aliases, including `-State`, `-ExpectedRevision`, and `-ApplyAttributes`, so stored argv and automation can migrate without reinterpretation. There is no `.ps1` launcher. Controller dependencies remain isolated in `requirements-controller.txt` and are never installed automatically.

## Removed surface

Phase 5 removed the PowerShell controller, integrity implementation, shared module, forwarding shims, executable differential capture, and PowerShell-only smoke harnesses. The normalized schema `1.0` legacy-state fixture is retained as data-only compatibility evidence; Python resumes it without conversion.

The permanent suite is `python scripts/tests/run_controller_tests.py`. The cross-platform `Controller Contract` workflow is the authoritative release matrix. Historical difference classifications and their regression tests remain documented in [`controller-compatibility-decisions.md`](../scripts/tests/conformance/controller-compatibility-decisions.md).
