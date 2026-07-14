# Arena Lifecycle Command Reference

Use this file when operating `scripts/arena.ps1`. The main Skill defines decisions and gates; this file defines the mechanical interface.

## Controller Rules

- Invoke the controller from the loaded `SKILL_ROOT` or use absolute paths.
- Pass an absolute `-State` path under the durable `ARENA_RUN_ROOT`.
- Only `arena.ps1` writes state. Do not edit `arena-state.json`.
- Run `status` before every mutation and pass the latest `stateRevision` as `-ExpectedRevision`.
- Keep configuration commands structured as `executable`, `args`, and `environment`; never store a shell command string.
- Treat nonzero exit as failure. CRLF warnings on Git stderr are not failures when the process exit code is zero.

PowerShell command prefix:

```powershell
$arena = Join-Path $skillRoot 'scripts\arena.ps1'
$state = Join-Path $arenaRunRoot 'arena-state.json'
powershell -ExecutionPolicy Bypass -File $arena status -State $state
```

## Project Configuration

Provide JSON to `preflight -Config`. Minimal shape:

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

```powershell
powershell -ExecutionPolicy Bypass -File $arena preflight `
  -State $state -Repo $repo -SkillRoot $skillRoot -Config $config
```

If preflight proposes controlled attributes such as the `.worktrees/` ignore rule, show the exact change and obtain user approval before applying:

```powershell
powershell -ExecutionPolicy Bypass -File $arena preflight `
  -State $state -ExpectedRevision <revision> -ApplyAttributes
```

### Create worktrees

After the three frozen briefs have been approved and placed in the controller's expected brief root:

```powershell
powershell -ExecutionPolicy Bypass -File $arena create-worktrees `
  -State $state -ExpectedRevision <revision>
```

The controller creates all three branches from the recorded final base SHA. Never create only one or two candidates.

### Import builder results

Each builder writes an independent schema-valid result conforming to `scripts/schemas/builder-result.schema.json`.

```powershell
powershell -ExecutionPolicy Bypass -File $arena import-builder-result `
  -State $state -ExpectedRevision <revision> -ResultPath <builder-result.json>
```

Refresh status and revision after every import. Candidate commit changes invalidate old QA and reviews.

### Start or stop previews

```powershell
powershell -ExecutionPolicy Bypass -File $arena start-previews `
  -State $state -ExpectedRevision <revision>

powershell -ExecutionPolicy Bypass -File $arena stop-previews `
  -State $state -ExpectedRevision <revision>
```

`start-previews` is idempotent and re-probes HTTP readiness. Process identity includes PID and start time. Never kill a process merely because it occupies the same port.

### Import QA

Run the QA runner separately as described in `qa-configuration.md`. Then import its independent result:

```powershell
powershell -ExecutionPolicy Bypass -File $arena import-qa-result `
  -State $state -ExpectedRevision <revision> -ResultPath <qa-results.json>
```

`PASS`, `FAIL`, and environment `BLOCKED` remain distinct. Importing QA never signs a human review.

### Sign current evidence

After actually inspecting current screenshots:

```powershell
powershell -ExecutionPolicy Bypass -File $arena sign-visual-review `
  -State $state -ExpectedRevision <revision> -Style style-a -Result PASS `
  -Reviewer <reviewer-id> -CandidateCommit <full-commit> `
  -EvidenceIds <mobile-id>,<tablet-id>,<desktop-id>
```

After comparing the render with the approved direction:

```powershell
powershell -ExecutionPolicy Bypass -File $arena sign-direction-review `
  -State $state -ExpectedRevision <revision> -Style style-a -Result PASS `
  -Reviewer <reviewer-id> -CandidateCommit <full-commit> `
  -EvidenceIds <screenshot-id>,<design-brief-id>
```

Use `FAIL` when evidence does not meet the relevant quality IDs. Do not sign stale commits or unknown evidence IDs.

### Qualify

```powershell
powershell -ExecutionPolicy Bypass -File $arena qualify `
  -State $state -ExpectedRevision <revision> -Style style-a
```

Repeat for all three styles. `selection-ready` requires five PASS gates for all three.

### Select and merge

Only after the user chooses a complete qualified style:

```powershell
powershell -ExecutionPolicy Bypass -File $arena select `
  -State $state -ExpectedRevision <revision> -Style style-a

powershell -ExecutionPolicy Bypass -File $arena merge `
  -State $state -ExpectedRevision <revision>
```

The merge command recalculates fast-forward versus merge-commit eligibility. Product conflicts remain a user decision.

### Cleanup

After post-merge checks pass:

```powershell
powershell -ExecutionPolicy Bypass -File $arena cleanup `
  -State $state -ExpectedRevision <revision>
```

Cleanup removes worktrees and retains all three branches. If ordinary removal is blocked by ambiguous files, stop for the user.

### Publication and handoff

Publication is optional and separate from local completion:

```powershell
powershell -ExecutionPolicy Bypass -File $arena publish-plan `
  -State $state -Remote origin -Branches style-a,style-b,style-c

powershell -ExecutionPolicy Bypass -File $arena publish `
  -State $state -ExpectedRevision <revision> -Remote origin `
  -Branches style-a,style-b,style-c -ConfirmPublish

powershell -ExecutionPolicy Bypass -File $arena handoff-docs `
  -State $state -ExpectedRevision <revision>
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

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\tests\phase1-smoke.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\tests\phase2-smoke.ps1
python -X utf8 "<CODEX_HOME>\skills\.system\skill-creator\scripts\quick_validate.py" "<absolute-skill-root>"
```

Also parse every PowerShell file, parse every JSON schema/config, run `node --check scripts/arena-qa.mjs`, run `git diff --check`, scan for dynamic execution, and verify all local links.
