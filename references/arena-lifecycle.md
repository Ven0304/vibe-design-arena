# Arena Lifecycle Command Reference

Use this file when operating the canonical Python controller at `scripts/arena.py`. The main Skill defines decisions and gates; this file defines the mechanical interface.

## Controller Rules

- Invoke the controller from the loaded `SKILL_ROOT` or use absolute paths.
- Pass an absolute `--state` path under the durable `ARENA_RUN_ROOT`.
- Only `arena.py` writes state. Do not edit `arena-state.json`.
- Run `status` before every mutation and pass the latest `stateRevision` as `--expected-revision`.
- Keep configuration commands structured as `executable`, `args`, and `environment`; never store a shell command string.
- Treat nonzero exit as failure. CRLF warnings on Git stderr are not failures when the process exit code is zero.

Canonical command prefix (use the selected approved Python 3.10+ interpreter):

```console
python scripts/arena.py status --state <absolute-ARENA_RUN_ROOT/records/arena-state.json>
```

## Project Configuration

Provide JSON to `preflight --config`. Minimal shape:

```json
{
  "preview": {
    "style-a": {
      "executable": "npm.cmd",
      "args": ["run", "dev", "--", "--host", "127.0.0.1", "--port", "{{PORT}}"],
      "port": 5173,
      "url": "http://127.0.0.1:5173",
      "environment": {}
    },
    "style-b": {
      "executable": "npm.cmd",
      "args": ["run", "dev", "--", "--host", "127.0.0.1", "--port", "{{PORT}}"],
      "port": 5174,
      "url": "http://127.0.0.1:5174",
      "environment": {}
    },
    "style-c": {
      "executable": "npm.cmd",
      "args": ["run", "dev", "--", "--host", "127.0.0.1", "--port", "{{PORT}}"],
      "port": 5175,
      "url": "http://127.0.0.1:5175",
      "environment": {}
    }
  },
  "validation": [
    {
      "executable": "npm.cmd",
      "args": ["run", "build"],
      "environment": {}
    }
  ]
}
```

Adapt executables and arguments to the real product. Do not copy this example without inspecting the repository.

## Lifecycle Sequence

### Preflight

```console
python scripts/arena.py preflight  --state <state-path> --repo <product-repo> --skill-root <skill-root> --config <arena-config.json>
```

If preflight proposes controlled attributes such as the `.worktrees/` ignore rule, show the exact change and obtain user approval before applying:

```console
python scripts/arena.py preflight  --state <state-path> --expected-revision <revision> --apply-attributes
```

### Create worktrees

After the three frozen briefs have been approved and placed in the controller's expected brief root:

```console
python scripts/arena.py create-worktrees  --state <state-path> --expected-revision <revision>
```

The controller creates all three branches from the recorded final base SHA. Never create only one or two candidates.

### Import builder results

Each builder writes an independent schema-valid result conforming to `scripts/schemas/builder-result.schema.json`.

```console
python scripts/arena.py import-builder-result  --state <state-path> --expected-revision <revision> --result-path <builder-result.json>
```

Refresh status and revision after every import. Candidate commit changes invalidate old QA and reviews.

### Start or stop previews

```console
python scripts/arena.py start-previews  --state <state-path> --expected-revision <revision>

python scripts/arena.py stop-previews  --state <state-path> --expected-revision <revision>
```

`start-previews` is idempotent and re-probes HTTP readiness. Process identity includes PID and start time. Never kill a process merely because it occupies the same port.

### Import QA

Run the QA runner separately as described in `qa-configuration.md`. Then import its independent result:

```console
python scripts/arena.py import-qa-result  --state <state-path> --expected-revision <revision> --result-path <qa-results.json>
```

`PASS`, `FAIL`, and environment `BLOCKED` remain distinct. Importing QA never signs a human review.

### Sign current evidence

After actually inspecting current screenshots:

```console
python scripts/arena.py sign-visual-review  --state <state-path> --expected-revision <revision> --style style-a --result PASS  --reviewer <reviewer-id> --candidate-commit <full-commit>  --evidence-ids <mobile-id> <tablet-id> <desktop-id>
```

After comparing the render with the approved direction:

```console
python scripts/arena.py sign-direction-review  --state <state-path> --expected-revision <revision> --style style-a --result PASS  --reviewer <reviewer-id> --candidate-commit <full-commit>  --evidence-ids <screenshot-id> <design-brief-id>
```

Use `FAIL` when evidence does not meet the relevant quality IDs. Do not sign stale commits or unknown evidence IDs.

### Qualify

```console
python scripts/arena.py qualify  --state <state-path> --expected-revision <revision> --style style-a
```

Repeat for all three styles. `selection-ready` requires five PASS gates for all three.

### Select and merge

Only after the user chooses a complete qualified style:

```console
python scripts/arena.py select  --state <state-path> --expected-revision <revision> --style style-a

python scripts/arena.py merge  --state <state-path> --expected-revision <revision>
```

The merge command recalculates fast-forward versus merge-commit eligibility. Product conflicts remain a user decision.

### Cleanup

After post-merge checks pass:

```console
python scripts/arena.py cleanup  --state <state-path> --expected-revision <revision>
```

Cleanup removes worktrees and retains all three branches. If ordinary removal is blocked by ambiguous files, stop for the user.

### Publication and handoff

Publication is optional and separate from local completion:

```console
python scripts/arena.py publish-plan  --state <state-path> --remote origin --branches style-a style-b style-c

python scripts/arena.py publish  --state <state-path> --expected-revision <revision> --remote origin  --branches style-a style-b style-c --confirm-publish

python scripts/arena.py handoff-docs  --state <state-path> --expected-revision <revision>
```

Never publish automatically. Record partial publication per branch.

## Recovery Rules

- Revision mismatch: run `status`, inspect changes, and retry with the new revision only if the intended transition remains valid.
- Stale builder or QA result: regenerate it for the current candidate generation and commit.
- Environment `BLOCKED`: fix the exact recorded dependency, browser, permission, or preview issue; do not convert it to PASS.
- Candidate changed: re-import builder result, restart/reprobe preview, rerun QA, repeat both human reviews, and requalify.
- Merge conflict: leave the repository in its truthful Git state and ask the user; never auto-resolve or auto-abort.
- Cleanup failure: inspect each worktree and distinguish generated output from user artifacts before requesting any force operation.

## Verification Commands

For Skill development and regression:

```console
python scripts/tests/run_phase3.py
python -X utf8 "<CODEX_HOME>\skills\.system\skill-creator\scripts\quick_validate.py" "<absolute-skill-root>"
```

Also parse both PowerShell forwarding shims and retained Phase 2 oracle files, parse every JSON schema/config, run `node --check scripts/arena-qa.mjs`, run `git diff --check`, scan for dynamic execution, and verify all local links.
