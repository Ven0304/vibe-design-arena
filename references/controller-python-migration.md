# Controller Python Migration Design

> Status: design proposal; no controller behavior changes are authorized by this document.
>
> Scope: migrate the stateful PowerShell controller and its PowerShell test harness to Python while retaining the Node-based browser QA runner.

## Contents

- [1. Decision summary](#1-decision-summary)
- [2. Compatibility boundary](#2-compatibility-boundary)
- [3. Proposed target layout](#3-proposed-target-layout)
- [4. File replacement matrix](#4-file-replacement-matrix)
- [5. Controller command contract](#5-controller-command-contract)
- [6. Integrity CLI contract](#6-integrity-cli-contract)
- [7. Platform abstraction matrix](#7-platform-abstraction-matrix)
- [8. Python dependency policy](#8-python-dependency-policy)
- [9. State, schema, and Node QA compatibility](#9-state-schema-and-node-qa-compatibility)
- [10. Safety and authorization invariants](#10-safety-and-authorization-invariants)
- [11. Test and conformance strategy](#11-test-and-conformance-strategy)
- [12. Migration phases and PowerShell retirement](#12-migration-phases-and-powershell-retirement)
- [13. Risks, objections, and design corrections](#13-risks-objections-and-design-corrections)
- [14. Acceptance criteria](#14-acceptance-criteria)

## 1. Decision Summary

Adopt Python as the sole long-term controller implementation and keep `scripts/arena-qa.mjs`, its Node tests, the Playwright/axe execution model, and the QA JSON contract in Node.

The migration must preserve behavior, not PowerShell implementation details. The following remain contractual:

- command names and command availability;
- parameter meaning, required/optional status, defaults, and validation;
- JSON document shapes, schema versions, enum values, and qualification semantics;
- stdout JSON on success, stderr diagnostics on failure, and zero/nonzero exit behavior;
- optimistic concurrency through `stateRevision`;
- the normal state transition graph and all blocking paths;
- Git branch/worktree lifecycle, brief-byte integrity, preview identity, qualification gates, publication authorization, and branch retention;
- the independent Node QA result and import boundary.

The executable prefix cannot be literally cross-platform and PowerShell-free at the same time. During compatibility, retain `scripts/arena.ps1` and `scripts/arena-integrity.ps1` only as thin forwarders. The canonical invocation becomes:

```text
python scripts/arena.py <command> --state <absolute-path> ...
python scripts/arena_integrity.py <action> ...
```

The Python parser should also accept the current PowerShell-style long option aliases, such as `-State`, `-ExpectedRevision`, and `-ApplyAttributes`, so wrapper forwarding does not reinterpret arguments. New documentation should use lowercase GNU-style options.

## 2. Compatibility Boundary

### 2.1 Must remain compatible

| Surface | Required compatibility |
| --- | --- |
| Commands | Keep all 16 controller commands and 4 integrity actions. |
| State | Existing valid `arena-state.json` files remain readable and resumable without migration. |
| Schemas | Keep current schema filenames, `schemaVersion: "1.0"`, required fields, enums, and `additionalProperties` policy. |
| Node QA | Keep QA config/result schemas, evidence identity, PASS/FAIL/BLOCKED meanings, proxy disclosure, and import checks. |
| Git lifecycle | Same base SHA, exactly three branches/worktrees, merge-mode recomputation, cleanup gate, and branch retention. |
| Authorization | No automatic dependency install, force removal, publication, dirty-state resolution, or conflict resolution. |
| Records | Preserve `events.jsonl`, derived record locations, evidence roots, approval/candidate/preview records, and handoff outputs. |
| Text integrity | Preserve SHA-256 over exact bytes and canonical UTF-8/no-BOM/LF rules for briefs and generated text. |

### 2.2 Compatibility does not mean byte-for-byte serialization

JSON key order and whitespace are not semantic contracts. Python may serialize JSON differently if all of the following hold:

- parsed values and types are identical;
- SHA-256 is never computed over controller JSON serialization unless the existing contract explicitly requires it;
- generated JSON ends with one LF and uses UTF-8 without BOM;
- conformance tests compare normalized JSON, not raw controller-state bytes.

Exact-byte compatibility remains mandatory for frozen references, approved `DESIGN_BRIEF.md` files, copied builder/QA result artifacts, and evidence files.

### 2.3 Known contract gap to close before implementation

The repository has schemas for Arena state, builder results, integrity results, QA config, and QA results, but the preflight controller configuration does not currently have a dedicated schema. Do not silently treat ad hoc Python validation as an unchanged schema contract. Add a versioned `arena-config.schema.json` only as a separately reviewed additive change, or initially reproduce the current structural checks exactly.

## 3. Proposed Target Layout

```text
scripts/
├── arena.py                         canonical controller entrypoint
├── arena_integrity.py               canonical integrity entrypoint
├── arena_controller/
│   ├── __init__.py
│   ├── cli.py                       parser, aliases, JSON/error emission
│   ├── controller.py                command orchestration
│   ├── state.py                     state model, revisions, transitions
│   ├── storage.py                   locking, atomic writes, events
│   ├── git.py                       shell-free Git adapter
│   ├── process.py                   preview identity and lifecycle
│   ├── integrity.py                 hashing, UTF-8/LF, Git blob checks
│   ├── qa_contract.py               imported Node QA validation
│   ├── records.py                   derived Markdown/JSONL records
│   ├── paths.py                     path and containment policy
│   └── platform.py                  narrow OS-specific adapter surface
├── arena.ps1                        temporary forwarding shim only
├── arena-integrity.ps1              temporary forwarding shim only
├── arena-qa.mjs                     retained Node QA runner
├── schemas/                         retained contracts
└── tests/
    ├── test_controller_*.py         Python unit/contract tests
    ├── test_lifecycle_smoke.py      successor to phase1 smoke
    ├── test_entrypoint_negative.py  successor to harness negative tests
    ├── conformance/                 normalized PS/Python traces
    ├── arena-qa-unit.mjs            retained
    └── arena-qa-scrollspy.mjs       retained
```

Do not place all translated logic in one large `arena.py`. The current `arena.ps1` already combines CLI parsing, state mutation, Git, preview management, QA contract validation, and record generation; a line-for-line translation would preserve the portability problem in another language.

## 4. File Replacement Matrix

| Current file | Target | Migration treatment | Retirement condition |
| --- | --- | --- | --- |
| `scripts/arena.ps1` | `scripts/arena.py` + `arena_controller/*` | Replace all controller logic. Keep `.ps1` temporarily as an argument-preserving forwarder to Python. | Remove shim after the deprecation gates in section 12 pass. |
| `scripts/lib/Arena.Core.psm1` | `storage.py`, `git.py`, `integrity.py`, `records.py`, `paths.py`, `platform.py` | Replace; no PowerShell module remains in the final runtime. | Python unit tests cover every exported PowerShell helper behavior used by the controller. |
| `scripts/arena-integrity.ps1` | `scripts/arena_integrity.py` | Replace four actions. Keep a temporary forwarding shim. | Same as controller shim, with action-level conformance. |
| `scripts/tests/phase1-smoke.ps1` | `scripts/tests/test_lifecycle_smoke.py` | Replace fixture setup and lifecycle assertions. | Python smoke passes on Windows, Linux, and macOS. |
| `scripts/tests/phase2-smoke.ps1` | Python test/orchestrator invoking Node unit QA and lifecycle smoke | Replace PowerShell orchestration; Node test remains. | Combined Python + Node entrypoint is the documented regression command. |
| `scripts/tests/smoke-harness-negative.ps1` | `scripts/tests/test_entrypoint_negative.py` | Replace negative entrypoint cases. | All six current negative cases plus signal/lock/path cases pass. |
| `scripts/tests/Smoke.TestHarness.psm1` | Python test helpers | Replace process, JSON, and assertion helpers. | No Python test imports the PowerShell harness. |
| `scripts/arena-qa.mjs` | unchanged | Retain in Node; only invocation documentation and cross-language fixtures may change. | Not scheduled for retirement. |
| `scripts/tests/arena-qa-unit.mjs` | unchanged | Retain. | Not scheduled for retirement. |
| `scripts/tests/arena-qa-scrollspy.mjs` | unchanged | Retain. | Not scheduled for retirement. |
| `scripts/schemas/*.json` | unchanged initially | Reuse directly from Python and Node. Do not fork Python-only schema copies. | Any future schema version requires an explicit migration design. |
| `scripts/fixtures/*` | unchanged initially | Reuse for cross-controller and Node QA regression. | Replace only for an independently justified fixture change. |
| `.gitattributes` | extend with `*.py text eol=lf` | Additive repository hygiene change. | Apply with the first Python implementation commit. |

## 5. Controller Command Contract

### 5.1 Common CLI contract

All mutating commands except creation of a new state require the latest expected revision. `status` is read-only. `publish-plan` is read-only. Every mutation acquires the state lock, checks `stateRevision`, performs one logical transition, atomically writes state, appends an event, and regenerates derived records.

| Common input | Contract |
| --- | --- |
| `state` | Required absolute path. State location must remain `ARENA_RUN_ROOT/records/arena-state.json`. |
| `expectedRevision` | Required and `>=1` for mutations against existing state. A mismatch fails without retry. |
| `skillRoot` | Defaults to the loaded Skill root; freeze its resolved absolute path and snapshot. |
| Paths | Accept native path syntax; store resolved absolute paths. Never accept containment based only on string prefix. |

Success writes one JSON object to stdout and exits `0`. A command error writes a clear diagnostic to stderr, appends a failure event when possible, makes no false state transition, and exits nonzero. Warnings from Git stderr do not cause failure when Git exits `0`.

### 5.2 Command matrix

| Command | Inputs beyond common fields | Preconditions and state transition | Output | External side effects and authorization |
| --- | --- | --- | --- | --- |
| `preflight` | New state: `repo`, optional `skillRoot`, optional `config`, optional `applyAttributes`. Resume: `expectedRevision`, optional `applyAttributes`. | New: valid clean Git root with committed, attached HEAD; run root outside repo. Creates `stage=preflight`. Records base branch/SHA only after attributes are valid. Resume only at `preflight`. | Full state JSON. May return a persisted `status=blocked` state with patch path. | Creates Arena directories, state/events/derived records, and reference snapshot. Without approval, only writes a proposed patch under records. With `applyAttributes`, edits, stages, and commits only `.gitattributes`. Must reject unexpected staged files. |
| `create-worktrees` | `expectedRevision`; optional `briefRoot` defaulting to records/briefs. | From `preflight`, verifies all three canonical briefs and records hashes, then `briefs-approved`; creates all worktrees and ends `worktrees-ready`. May resume from `briefs-approved`. | Full state JSON. | Creates exactly three branches/worktrees from recorded base SHA, copies each brief byte-for-byte, commits each brief, records dispatch IDs. No partial silent success. |
| `import-builder-result` | `expectedRevision`, `resultPath`. | Allowed at `worktrees-ready`, `building`, `previews-ready`, or `qualifying`; rejects stale arena/style/generation/dispatch/brief/HEAD. Ends `building` and invalidates old QA/reviews for that style. | Full state JSON. | Copies validated result into candidate records. Does not execute builder commands or alter candidate code. Requires recorded preview stopped before revised import. |
| `start-previews` | `expectedRevision`. Preview specs come from frozen configuration. | Requires all three current builder results/commits. Reuses a recorded live process only if PID and creation time match, then reprobes. All ready -> `previews-ready`; any blocked -> persisted `status=blocked`. | Full state JSON with PID, creation time, logs, HTTP status, and retry display. | Starts three shell-free child processes with separate cwd, argv, env, logs, ports, and process groups. Must not install dependencies or kill an unrelated port occupant. |
| `stop-previews` | `expectedRevision`. | Allowed before selection/merge as currently implemented. Clears preview process records after identity-safe stop attempts. Stage remains otherwise unchanged; status returns ready. | Full state JSON. | Stops only a process whose PID and creation time match the Arena record. Stops its owned process group/tree with bounded graceful timeout, then escalation only for that verified identity. |
| `status` | `state` only. | State must exist. No lock-required mutation and no revision change. | Summary JSON containing at least Arena ID, revision, stage, status, blocking reason, styles, selection, merge, cleanup, and publication facts. | Read-only filesystem access. No event required beyond current behavior. |
| `select` | `expectedRevision`, `style`. | Requires `selection-ready` and selected candidate overall PASS. Transitions to `selected`. | Full state JSON. | Writes selection only. Does not merge, stop previews, publish, or delete anything. User choice is the authority. |
| `merge` | `expectedRevision`. | Requires selected style and safe base worktree. Recomputes ancestry. Fast-forward if eligible; otherwise normal merge commit. Conflict -> truthful blocked state. Successful brief check and validation -> `merged`. | Full state JSON including method, SHAs, conflicts, and validation results. | Mutates main Git worktree. Never auto-resolves or auto-aborts product conflicts. Executes only structured validation specs without a shell. Does not clean worktrees. |
| `cleanup` | `expectedRevision`. | Requires `stage=merged` and merge PASS, no recorded previews, clean registered candidate worktrees, correct branches. Internally records `cleaned`, then `complete`. | Final full state JSON. | Removes linked worktree directories without force, prunes registry, verifies all three branches at retained commits. Never deletes candidate branches. Dirty/untracked ambiguity blocks. |
| `publish-plan` | Optional `remote`, optional `branches`. | State must exist. No transition. Defaults to base plus all three style branches. | JSON plan with local SHA, remote SHA, action, and current revision. | Read-only local/remote-ref inspection. Must not fetch or push unless separately specified by future contract. |
| `publish` | `expectedRevision`, explicit `branches`, optional `remote`, required `confirmPublish`. | Only Arena-owned base/style branches allowed. Stage semantics remain separate from completion. | Full state JSON with per-branch publication records. | Pushes only explicitly listed branches, verifies remote SHA after each push, records partial publication truthfully. Never automatic. |
| `handoff-docs` | `expectedRevision`. | Allowed only after `cleaned` or `complete`. Stage remains unchanged. | Full state JSON with handoff path/timestamp. | Writes generated README patch/final records under Arena records. Does not edit the product README automatically. |
| `import-qa-result` | `expectedRevision`, `resultPath`. | Allowed only at `previews-ready` or `qualifying`. Enforces Node QA identity, location, coverage, evidence, proxy, and commit contract. Ends `qualifying`; BLOCKED remains distinct. | Full state JSON. | Copies QA result into candidate records and resets both human reviews. Does not run Node QA and never edits QA artifacts. |
| `sign-visual-review` | `expectedRevision`, `style`, `result`, `reviewer`, `candidateCommit`, `evidenceIds`. | Requires `qualifying`, current commit, current imported QA hash, known evidence, screenshots for mobile/tablet/desktop. | Full state JSON. | Records human signature only. The controller cannot infer that screenshots were actually inspected; main-agent procedure remains mandatory. |
| `sign-direction-review` | Same as visual review. | Requires `qualifying`, current commit/QA, screenshot evidence, and design-brief evidence. | Full state JSON. | Records direction-consistency signature only. |
| `qualify` | `expectedRevision`, `style`. | Requires `qualifying`. Recomputes current HEAD, brief working/blob hashes, imported QA hash, and both signature bindings. Candidate PASS only if all five gates PASS. All three PASS -> `selection-ready`; otherwise remains blocked/qualifying. | Full state JSON. | Read/verify plus state mutation only. A changed candidate invalidates stale evidence and returns to `building` blocked. |

### 5.3 Structured command rules

Preview and validation records remain objects with `executable`, `args`, `environment`, and optional `workingDirectory`; never accept a single command string. The Python implementation must call `subprocess` with `shell=False`. Display-only retry text is derived from argv and must never be executed by parsing that text.

Environment keys must remain unique under case-insensitive comparison because Windows treats names case-insensitively and cross-platform configs must not change meaning by OS.

## 6. Integrity CLI Contract

| Action | Inputs | Output | Side effects |
| --- | --- | --- | --- |
| `snapshot` | `skillRoot`; optional `referenceFiles`. | Integrity result `1.0` with snapshot ID, provenance, resolved files, and SHA-256. | Read-only. |
| `normalize-brief` | `path`; optional `write`. | `PASS`, `CHANGED`, or `FAIL` plus before/conversion/after facts. | With `write`, rewrites only the named file as UTF-8/no-BOM/LF. Without it, read-only. |
| `check-attributes` | `repository`. | PASS/FAIL and required `/DESIGN_BRIEF.md text eol=lf` rule. | Read-only Git check. |
| `verify-brief` | `frozenPath`, `workingPath`; optional paired `repository` and `commit`. | PASS/FAIL with canonicality and frozen/working/blob hashes. | Read-only; temporary files must be private and cleaned. |

Retain `scripts/schemas/integrity-result.schema.json` and action/status spelling. The Python entrypoint should accept current action names and PowerShell-style aliases during deprecation.

## 7. Platform Abstraction Matrix

| Difference | Windows | Linux/macOS | Required abstraction and invariant |
| --- | --- | --- | --- |
| Python launcher | Often `py` or `python.exe`. | Usually `python3` or environment `python`. | Documentation uses “the selected Python interpreter”; the `.ps1` shim resolves an approved interpreter without installing one. Avoid hardcoded launcher names in state. |
| Executables | Package binaries may be `.cmd`/`.exe`. | Usually extensionless. | Config stores executable token appropriate to the product. Resolver may offer documented platform variants but must not silently rewrite arbitrary names. |
| Process creation | Creation flags and hidden windows; CTRL events differ. | Sessions/process groups and POSIX signals. | One `ProcessSupervisor` interface: start shell-free, record PID + creation time, own a process group, graceful stop, bounded escalation. Use no visible console window for managed previews. |
| Process identity | PID reuse; creation time available through OS APIs/psutil. | Same PID reuse risk. | PID alone never authorizes termination. Require matching creation time and Arena-owned command/worktree facts. |
| Process trees | Child npm/node processes may survive parent termination. | Child processes may form a process group. | Stop the verified Arena-owned group/tree, not every process on a port and not every matching executable. |
| File locks | Delete/replace semantics and sharing flags are strict. | Advisory locks are common. | Cross-platform exclusive lock with bounded acquisition; lock covers revision read through atomic state replace and derived-record write decision. |
| Atomic replace | `os.replace` is atomic on same volume but open-file behavior differs. | Same-filesystem rename is atomic. | Temp file in destination directory, flush/fsync where supported, `os.replace`, clean temp. Do not promise atomicity across volumes. |
| Path comparison | Case-insensitive by default; drive letters, UNC, junctions. | Usually case-sensitive; symlinks. | Resolve existing paths; use `commonpath`/same-file-aware containment, never lowercase string-prefix alone. Reject cross-drive `commonpath` failures. Define symlink/junction policy explicitly. |
| Path separators | `\`, drive roots, UNC. | `/`. | Store native absolute paths in state; JSON consumers treat them as opaque paths. Use `pathlib`, not manual separators. |
| Newlines/BOM | Git/autocrlf and editors may add CRLF/BOM. | LF normally. | Exact canonical UTF-8/no-BOM/LF check remains platform-independent; Git attribute rule remains mandatory. |
| Git output | Console encoding and CRLF warnings vary. | Locale and line endings vary. | Invoke Git with argv, capture bytes, decode UTF-8 with controlled fallback/error policy, trust exit code over stderr presence. Set no global Git config. |
| Git file mode | Usually ignored. | Executable bit may be tracked. | Python entrypoints need not be executable when invoked through Python; optional shebang/mode is additive, not contractual. |
| Port probing | Socket and firewall timing differ. | Socket timing differs. | Probe loop and timeout are configuration-independent contract facts. A responding port is not proof of process ownership. |
| HTTP probing | Proxy environment can interfere. | Same. | Probe loopback directly and avoid ambient proxy settings for `127.0.0.1`/`localhost`. Record exact status/error. |
| Temporary files | AV/indexers can hold files briefly. | Usually simpler. | Use run-root-local temp for durable artifacts and secure system temp only for transient blob hashing. Bounded retry may handle replace contention but must not hide failures. |
| Signals/interrupts | Console close and Ctrl+C propagation differ. | SIGINT/SIGTERM. | On controller interruption, do not claim a completed mutation. Atomic state protects old/new truth; started preview recovery must be discoverable from logs/process records. |
| Permissions | Read-only attributes and ACLs. | Mode bits and ownership. | Report exact permission failure; never chmod or relax ACLs automatically. |

## 8. Python Dependency Policy

### 8.1 Recommendation

Allow all three named libraries, but with explicit roles and pinned compatible ranges:

| Dependency | Decision | Reason |
| --- | --- | --- |
| `psutil` | Required for the controller runtime. | Reliable cross-platform process creation time, liveness, child-tree inspection, and identity-safe termination are security/lifecycle requirements, not convenience features. A stdlib-only substitute would be OS-specific code of higher risk. |
| `jsonschema` | Required for controller boundary validation. | The schemas should remain the single source of truth. Hand-coded validation would duplicate Node/schema logic and drift. Continue additional semantic checks that JSON Schema cannot express. |
| `portalocker` | Required unless an equivalent lock library is vendored and audited. | Cross-platform exclusive file locking is central to `stateRevision`. A naive `O_EXCL` lock file creates stale-lock recovery and crash semantics that are harder to make safe. |

Use Python 3.10+ as the initial floor unless support research proves a lower version is required. Prefer a small `requirements-controller.txt` with bounded major versions and hashes in release automation; do not add these packages to the target product's dependency files.

### 8.2 Installation and authority

- Never install Python dependencies automatically.
- First check the selected interpreter/environment.
- If missing, report exact packages and ask the user to choose an isolated installation scope.
- Support an approved external environment through `ARENA_PYTHON` or an explicitly invoked interpreter; do not persist a machine-specific interpreter path into portable configuration unless needed for handoff truth.
- Keep controller dependencies separate from `ARENA_QA_NODE_MODULES`; Python and Node dependency roots have different ownership.
- Do not vendor dependencies casually. Vendoring shifts patch and license responsibility into the Skill.

### 8.3 Counterargument

A zero-dependency Python controller is attractive but not the safest default here. File locking and process identity are exactly the areas where “portable stdlib” becomes platform-specific. If zero dependencies is a hard distribution requirement, reduce scope first: move preview process supervision out of the controller or accept weaker guarantees explicitly. Do not silently weaken termination identity or concurrency safety to claim zero dependencies.

## 9. State, Schema, and Node QA Compatibility

### 9.1 State rules

- `arena-state.json` remains schema version `1.0` during parity migration.
- `arena.py` is the only writer after cutover; shims only exec/forward to it.
- Existing state must resume regardless of whether it was last written by PowerShell or Python.
- Every mutation uses the latest revision, holds one exclusive lock, increments exactly once per logical mutation, and writes an event containing the committed revision.
- Preserve the current two-revision cleanup behavior (`cleanup` then internal `complete`) unless a separately approved contract change simplifies it.
- Preserve status values (`ready`, `blocked`, `complete`) and qualification values (`PENDING`, `PASS`, `FAIL`, `BLOCKED`) exactly where currently used.

### 9.2 Schema rules

Python loads the existing files under `scripts/schemas/`; it must not embed copied schemas in source. Validation occurs at trust boundaries:

1. state read and before state commit;
2. builder-result import;
3. integrity-result test fixtures;
4. QA config/result where the controller consumes them;
5. generated conformance fixtures.

Schema validation does not replace semantic checks such as current Git HEAD, evidence containment, exact coverage cardinality, process identity, or branch retention.

### 9.3 Node QA boundary

`arena-qa.mjs` remains an artifact producer and never writes Arena state. Python imports `qa-results.json` only after checking:

- Arena/style/generation/current commit identity;
- result file and screenshot containment under the registered evidence root;
- config/result schema validity;
- PASS/FAIL/BLOCKED and `environmentBlocked` consistency;
- proxy disclosure truth (`deviceScaleFactor=1`, not real browser zoom);
- universal and product-state scenario cardinality;
- unique check/evidence IDs and all evidence references;
- required screenshot, axe, overflow, and browser-error evidence;
- current QA-result hash at human-signature and qualification time.

Do not invoke Node code in-process from Python. Use the documented Node CLI as a separate process or let the main agent run it separately, preserving the current artifact/import boundary.

## 10. Safety and Authorization Invariants

The Python migration is unacceptable if it weakens any of these rules:

1. Never mutate a dirty or unborn baseline by assumption.
2. Never choose, create, or delete fewer/more than the exact three style candidates through lifecycle shortcuts.
3. Never write `arena-state.json` outside the controller transaction.
4. Never retry a revision mismatch blindly.
5. Never execute config through a shell or evaluate a command string.
6. Never kill a process by port or PID alone.
7. Never treat a responding URL as proof of preview identity.
8. Never install Python or Node dependencies automatically.
9. Never auto-resolve or auto-abort product merge conflicts.
10. Never force-remove a worktree with ambiguous files.
11. Never delete `style-a`, `style-b`, or `style-c` branches in cleanup.
12. Never push without a reviewed plan, explicit branch list, and confirmation.
13. Never convert Node QA `BLOCKED` into FAIL or PASS.
14. Never sign human reviews automatically from QA JSON.

## 11. Test and Conformance Strategy

### 11.1 Freeze the PowerShell behavior first

Before translating commands, create black-box traces from the current controller on Windows. For each command, capture:

- argv and fixture preconditions;
- exit code;
- parsed stdout JSON;
- stderr category/message pattern;
- normalized state before/after;
- Git refs, worktree registry, HEADs, dirty status;
- created/copied files and hashes;
- event and derived-record facts.

Normalize UUIDs, timestamps, absolute fixture roots, PIDs, process creation times, ports, and Git commit IDs. Do not normalize status, stages, revision deltas, branch names, error categories, artifact locations relative to run root, or file hashes.

### 11.2 Test layers

| Layer | Coverage |
| --- | --- |
| Unit | Paths/containment, canonical text, hashing, lock behavior, atomic writes, Git result handling, schema validation, process identity, record rendering. |
| Command contract | Every command success, blocked path, invalid stage, missing argument, revision mismatch, and stale artifact. |
| Differential | Run PowerShell and Python against equivalent Windows fixtures; compare normalized traces and Git side effects. |
| Lifecycle smoke | Full three-branch flow through qualification, selection, merge, cleanup, completion, and branch-retention verification. |
| Node boundary | Existing QA unit and scrollspy tests plus Python import of PASS, FAIL, BLOCKED, stale, escaped-path, duplicate-ID, and malformed results. |
| Cross-platform | Windows latest, Ubuntu LTS, macOS current; Python 3.10 and newest supported minor. |
| Fault injection | Lock contention, process crash, controller interruption, atomic replace failure, Git conflict, validation failure, dirty worktree, PID reuse simulation, partial publish. |

### 11.3 Golden compatibility rule

PowerShell is the behavioral oracle only during the parity phase. A discovered PowerShell bug must not be blindly reproduced. Classify differences as:

- `PARITY`: Python must match;
- `BUGFIX`: requires a named design decision, new test, and compatibility note;
- `PLATFORM`: same invariant with platform-specific evidence;
- `NON-CONTRACTUAL`: formatting/key-order difference only.

This prevents “compatibility” from freezing unsafe behavior forever.

## 12. Migration Phases and PowerShell Retirement

PowerShell retirement should be gate-based, not date-only.

| Phase | Runtime status | Required exit gate |
| --- | --- | --- |
| 0 — Contract freeze | PowerShell canonical; Python absent. | Command/state/side-effect fixtures and normalized trace format approved. |
| 1 — Python foundation | PowerShell canonical; Python implements storage, Git, integrity, schema, records, and CLI. | Unit tests pass; no product workflow cutover. |
| 2 — Dual implementation | Both controllers available; `.ps1` still executes old code for differential tests. | All commands reach parity or have approved BUGFIX decisions. |
| 3 — Python default | Python canonical in SKILL/README/lifecycle docs. `.ps1` becomes a thin forwarder and emits one deprecation warning to stderr, never stdout. | Full lifecycle and Node QA contract pass on all three OS families; existing PowerShell-created states resume in Python. |
| 4 — Compatibility window | Python only core; `.ps1` forwarding shims remain. | At least two tagged releases or a defined minimum support window, plus no unresolved P0/P1 parity defects. |
| 5 — PowerShell retired | Remove `.ps1`, `.psm1`, and PowerShell-only tests. | One final release note/handoff identifies the last shim-supported version and direct Python replacement commands. |

Do not retire the old implementation immediately after a single happy-path Python smoke test. Minimum retirement evidence:

- Windows differential suite passes;
- Linux and macOS lifecycle suites pass;
- lock-contention and controller-interruption tests pass;
- preview start/stop proves process-tree cleanup without unrelated termination;
- all old valid state fixtures resume;
- Node QA PASS/FAIL/BLOCKED imports are identical at the normalized contract level;
- merge conflict, cleanup refusal, partial publish, and branch-retention paths pass;
- Skill validator and link checks pass after documentation switches to Python.

## 13. Risks, Objections, and Design Corrections

### 13.1 “Keep the CLI unchanged” needs two layers

Keep the command vocabulary and data contract unchanged. Treat the launcher as a compatibility layer. Otherwise a permanent PowerShell wrapper would remain a runtime dependency and defeat the general-purpose goal.

### 13.2 The current controller has two concerns worth revisiting, not copying blindly

First, `preflight -ApplyAttributes` creates a Git commit. That is already authorized only after showing the exact patch, but the migration should test that the commit touches exactly `.gitattributes`, preserves user identity/config behavior, and reports commit failure truthfully.

Second, `cleanup` performs two internal state revisions (`cleaned`, then `complete`) in one CLI call. Preserve this for state compatibility during parity, but consider a later schema/version change that makes completion one explicit transition. Do not change it inside the migration unnoticed.

### 13.3 Process supervision is the hardest portability surface

Git and JSON translation are comparatively straightforward. Preview ownership, child processes, PID reuse, and cross-platform termination are the highest-risk part. Implement and test `ProcessSupervisor` before porting the full command switch. This is also why `psutil` should be allowed.

### 13.4 Schema reuse is necessary but insufficient

JSON Schema can validate shape, not live identity. The Python design must preserve semantic checks against Git HEAD, Git blob bytes, evidence roots, QA hashes, preview creation times, and retained branch commits.

### 13.5 Do not make the target product install controller dependencies

The Arena controller belongs to the Skill/tool environment. Modifying a React/Next/Vite product's Python or Node dependency files to run the controller would violate separation and pollute the baseline. Controller Python dependencies and QA Node dependencies stay external and approval-gated.

### 13.6 A single-file translation would be faster but strategically wrong

It would reduce initial diff size but leave OS branching mixed with state rules and make parity testing harder. The small internal package proposed above creates seams for platform tests without changing the public CLI.

## 14. Acceptance Criteria

The migration design is implemented only when all statements below are true:

- Python is the documented canonical controller on Windows, Linux, and macOS.
- All controller commands and integrity actions retain their public names and semantics.
- Current `1.0` state and result artifacts remain readable without conversion.
- Node QA remains independent and its schemas/contracts are unchanged.
- No command uses a shell string or loses optimistic concurrency.
- Preview termination requires verified process identity and does not target ports.
- All three Git branches are preserved after cleanup.
- Dirty work, conflicts, dependency installation, force cleanup, and publication remain user-authorized boundaries.
- Differential and cross-platform suites pass the retirement gates.
- PowerShell core code is removed only after the forwarding window, not at Python feature-complete time.
