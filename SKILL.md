---
name: vibe-design-arena
description: Use when a user has an existing product codebase and wants three independent, visually competitive frontend redesign directions built from one Git baseline in isolated worktrees, reviewed as complete rendered candidates, compared side by side, and resolved by the user's whole-version winner choice. Merge only the winner, remove linked worktrees, and retain all three design branches. Do not use for mix-and-match composition, cherry-picking, or a single routine UI edit.
---

# Vibe Design Arena

Produce three complete frontend directions that are strong enough to compete with one another. The user chooses one whole version. Merge that winner, clean up the linked worktrees, and keep every design branch—including the two that lost.

The Arena is a design workflow with a scripted state machine. Scripts prove identity, freshness, coverage, and lifecycle facts. The main agent remains responsible for design judgment and must actually inspect the rendered candidates.

## Non-Negotiable Contract

1. Create exactly three candidate branches and linked worktrees from the same final `BASE_SHA`.
2. Make the directions structurally independent. Palette, font, radius, or dark/light swaps do not count as three directions.
3. Keep a complete, separate `DESIGN_BRIEF.md` for every candidate. Before creating worktrees, show the user a Markdown comparison table of the three directions' decision-relevant summaries and obtain one explicit direction approval. Do not paste the three full briefs into chat unless the user asks to inspect one or more of them.
4. Build and qualify all three candidates. Never hide or drop a weak candidate to reach selection.
5. Let the user choose one complete winner. Do not mix versions, cherry-pick favorite elements, average scores, or let QA choose.
6. Merge only the selected branch. Remove worktrees only after post-merge validation.
7. Retain `style-a`, `style-b`, and `style-c` branches at their recorded commits. Cleanup never deletes a losing branch.
8. Preserve unrelated user work. Do not reset, overwrite, force-remove, force-delete, auto-push, or resolve product merge conflicts without the required user authority.

If the user asks to combine versions, explain that this Skill protects whole-direction coherence. Ask them to choose one version or start a separate follow-up redesign after the Arena.

## Responsibility Split

### Main agent

- Inspect the product, current UI, key routes, real content shape, audience, and technical commands.
- Create the Arena run record and frozen reference snapshot.
- Draft three orthogonal directions and own the arena-wide anti-slop judgment.
- Preserve all three complete briefs; present their decision-relevant summaries in one Markdown comparison table and obtain approval.
- Configure preview and QA commands without dynamic shell strings.
- Dispatch or coordinate three builders while preserving worktree isolation.
- Open and inspect the screenshots for every candidate.
- Sign visual quality and direction consistency only from current evidence.
- Present three qualified whole versions without ranking them.
- Ask for the winner, merge it, validate it, clean worktrees, and verify branch retention.

### Builder

- Work only in the assigned worktree and branch.
- Read the committed `DESIGN_BRIEF.md` and the frozen references supplied by the main agent.
- Implement one complete direction without editing the approved brief.
- Preserve product behavior and avoid unrelated refactors.
- Run declared validation, perform a preliminary quality self-check, commit the implementation, and emit a builder result bound to the current commit.
- Never start unmanaged long-running preview servers or modify another candidate.

### Scripts

- Own mechanical lifecycle state, locking, revisions, hashes, evidence identity, preview process identity, qualification gates, merge mode, cleanup checks, publication plans, and handoff records.
- Never decide whether a design is beautiful, coherent, or the user's winner.

### User

- Approves the three directions through the comparison table; may request any complete brief before approving.
- Chooses the complete winner after all three qualify.
- Decides how to handle ambiguous dirty files, destructive cleanup, publication, and product merge conflicts.

## Reference Routing

Read only what the current stage needs, but read each selected file completely.

- Before drafting directions: [`references/direction-brief.md`](references/direction-brief.md) and [`references/anti-slop.md`](references/anti-slop.md).
- When a domain pack matches: read its `shared-judgments.md`, all three direction sources, and `orthogonality-check.md`; begin with [`references/domain-packs/README.md`](references/domain-packs/README.md).
- Before implementation and rendered review: [`references/visual-quality-bar.md`](references/visual-quality-bar.md), [`references/interaction-quality-bar.md`](references/interaction-quality-bar.md), and [`references/arena-scorecard.md`](references/arena-scorecard.md).
- Before operating the state machine: [`references/arena-lifecycle.md`](references/arena-lifecycle.md).
- Before authoring or running declarative browser QA: [`references/qa-configuration.md`](references/qa-configuration.md) and the schemas under `scripts/schemas/`.

Resolve every reference from the loaded `SKILL_ROOT`, not from the product worktree. Freeze the absolute path and SHA-256 of every consumed file before briefs are drafted. If a frozen file changes or becomes unavailable, stop; restore the frozen bytes or ask the user to restart or cancel the Arena. Never update the manifest in place.

## State Authority

`scripts/arena.ps1` is the only writer of `arena-state.json`. Do not bypass it, patch state manually, or treat chat history as state.

Every mutating command requires the latest `stateRevision`. Refresh status immediately before mutation. A revision mismatch is a concurrency signal: reread status and reassess instead of retrying blindly.

Normal stage flow:

```text
preflight -> briefs-approved -> worktrees-ready -> building
          -> previews-ready -> qualifying -> selection-ready
          -> selected -> merged -> cleaned -> complete
```

`blocked` is a machine status, not permission to skip a gate. Resolve the recorded cause and rerun the stated command. Candidate changes after builder import invalidate that candidate's QA and both human signatures.

## Workflow

### 1. Establish a trustworthy baseline

Confirm the product path is a Git worktree with an existing commit. Inspect `HEAD`, branch, status, remotes, framework, package manager, scripts, environment needs, services, routes, and current rendered UI when practical.

If the repository is dirty, stop and ask whether to commit, stash, or intentionally exclude those changes. If Git is absent or `HEAD` is unborn, ask whether to initialize and create a reviewed baseline, point to another repository, or cancel. Do not initialize or commit by assumption.

Choose a durable `ARENA_RUN_ROOT` outside the product repository and all candidate worktrees. Use it for state, events, frozen briefs, candidate records, preview logs, and evidence. Run `preflight`; apply a proposed `.worktrees/` ignore change only after the user approves that exact change. Record the final clean `BASE_SHA` only after this step.

### 2. Create three directions before code

Use the same product and technical snapshot for all three briefs. Apply the direction standard, anti-slop challenge, and matching domain pack. Each direction must define:

- subject, expert audience, and one primary job;
- an evidence-backed aesthetic thesis;
- one content-bearing signature element;
- one bounded design risk;
- a specific anti-default and observable replacement;
- first-screen and continuation wireframes, including narrow behavior;
- at least three observable pairwise differences;
- semantic token commitments and the two-sided replaceability test.

Reject the set if one component tree could express all three by changing tokens, if two share the same first-screen grammar, or if their identities depend on fashionable effects. The main agent owns this comparison; builders do not renegotiate it.

Save the exact three complete brief files under `ARENA_RUN_ROOT`. Do not compress, replace, or embed their content in a builder dispatch prompt: each builder must receive its assigned complete `DESIGN_BRIEF.md` as a file.

Before creating worktrees, present a single Markdown comparison table—one row per candidate, no full-brief dump—with at least: style/name, primary job and audience, aesthetic thesis, first-screen grammar, signature element, intentional risk, anti-default replacement, responsive posture, and the observable distinctions from the other two directions. The table is a user-facing decision aid, not a substitute for any `DESIGN_BRIEF.md`.

Ask for one explicit direction approval against that table, while naming the saved full brief files and offering their contents on request. After approval, hash the exact UTF-8 bytes of all three full briefs. The approved full files, not the table or a compressed prompt, are the source of truth for materialization, brief-integrity checks, and builders. Do not silently regenerate them.

### 3. Materialize isolated candidates

Use `create-worktrees` to create three linked worktrees from the same final `BASE_SHA`. Materialize each approved brief byte-for-byte, verify its approved SHA-256, commit it on the matching branch, and record the brief commit.

Dispatch three builders in parallel when delegation is available; otherwise build sequentially and tell the user that dispatch was unavailable. Isolation and the three-candidate completion gate do not change.

Import only schema-valid builder results. A result must identify its Arena, style, candidate generation, brief identity, current implementation commit, validation, and preliminary evidence. A stale result never advances the candidate.

### 4. Render and collect evidence

Start three tracked previews through the state machine. Each style uses its own executable/args/environment command record, port, logs, PID, process start time, and HTTP probe. Do not construct shell command strings. Do not treat one responding URL as proof that all three are ready.

Run `scripts/arena-qa.mjs` for each current candidate. It writes an independent `qa-results.json`; only `import-qa-result` may import it into Arena state. The runner never edits state.

Applicability has three distinct meanings:

- `required`: a universal hard gate and executed test;
- `applicable`: a product-state test that the product can produce;
- `not-applicable`: a reviewed declaration with `reason`, `approvedBy`, and `evidenceIds`.

Never infer N/A automatically. Use only whitelisted actions and assertions. No `eval`, arbitrary JavaScript, shell strings, or dynamic PowerShell execution.

The `equivalent-200-percent-layout` check is an automated proxy using a halved CSS viewport with `deviceScaleFactor=1`. It is not a claim that Chrome UI zoom was tested at 200 percent.

### 5. Perform the two human reviews

Automated QA cannot enter `selection-ready` by itself.

For `mainAgentVisualReview`, the main agent must open current screenshots for mobile, tablet, and desktop and inspect:

- first-screen hierarchy and primary-job clarity;
- typography, measure, wrapping, and numeric treatment;
- color roles, contrast, and non-color state cues;
- density, grouping, alignment, spacing, and rhythm;
- responsive transformation and overflow;
- state completeness and interaction affordances;
- the overall composition and whether it is genuinely compelling.

Do not sign by reading `qa-results.json` alone. Cite the exact screenshot evidence IDs actually inspected.

For `directionConsistencyReview`, compare the rendered candidate with the approved thesis, signature, risk boundary, anti-default, wireframe, and pairwise differences. Cite current screenshot evidence and the frozen design-brief evidence ID.

Both signatures bind the current candidate commit, QA result hash, reviewer, timestamp, and evidence IDs. Any candidate commit change invalidates them.

### 6. Qualify all three

Run `qualify` separately for each candidate. A candidate is eligible only when these five gates are simultaneously `PASS`:

1. `briefIntegrity`
2. `validation`
3. `automatedQa`
4. `mainAgentVisualReview`
5. `directionConsistencyReview`

No gate compensates for another. A beautiful version with failed validation is not qualified; a mechanically perfect version with weak or incoherent design is not qualified.

The Arena reaches `selection-ready` only when all three candidates pass all five gates. If any fails, return its stable quality item IDs and evidence to that builder, repair the same whole branch, and repeat builder import, preview, QA, both reviews, and qualification for the new commit.

### 7. Let the user choose the whole winner

Show all three qualified candidates together with style name, branch, commit, preview/evidence location, visual thesis, validation result, and known risks. Do not score, rank, preselect, or recommend a composite.

Ask the user to choose `style-a`, `style-b`, or `style-c` as a complete version. If the user wants revisions, revise the relevant whole candidate and fully requalify it before showing a fresh comparison.

### 8. Merge, validate, and clean up

Stop only the preview processes recorded by the Arena. If the user wants previews to remain open, defer merge and cleanup.

Run `select` with the user's winner, then `merge`. The controller recalculates ancestry at merge time: fast-forward when current main is an ancestor, otherwise a normal merge commit. If product conflicts appear, stop and show both intentions; never resolve them automatically.

Run post-merge validation against the actual merged SHA. A dirty main worktree, changed brief, failed command, or required preview failure blocks cleanup.

Run `cleanup` only after the merged result passes. Remove linked worktrees without force first. If generated files block removal, ask before force-removing them. Ambiguous untracked files always require a user decision.

Verify that all three branches still exist at their recorded commits. The selected branch is retained by default; losing branches are retained unconditionally. Publication is a separate explicit step: show `publish-plan` and require confirmation before `publish`.

Generate handoff documents and report the Arena ID, winner, merge method, post-merge SHA, validations, evidence bundles, removed worktrees, and all retained branch names and commits.

## Failure Recovery

| Failure | Required response |
| --- | --- |
| Dirty or unborn baseline | Stop; ask the user to commit, stash, initialize, choose another repo, or cancel. |
| Reference hash drift | Stop; restore frozen bytes or restart/cancel the Arena. |
| Branch or worktree name collision | Ask for replacement names; do not reuse silently. |
| Builder result is stale | Reject it; import a result for the current candidate commit and generation. |
| Preview launch is blocked | Record exact executable, args, logs, and retry command; repair permissions/environment or ask for a manual launch. |
| QA dependency or browser is missing | Import the `BLOCKED` result; state the exact dependency/runtime needed and request approval before installing anything. |
| QA or human review fails | Repair that candidate, commit, and rerun the complete qualification chain. |
| Candidate commit changes | Treat old QA and both signatures as invalid; never reuse stale evidence. |
| Main branch advanced | Recompute ancestry at merge; validate the actual merged SHA. |
| Merge conflict | Stop for the user's product decision; do not auto-resolve or auto-abort. |
| Worktree removal needs force | Distinguish generated files from ambiguous user files and obtain confirmation. |
| Publication is partial | Preserve local branches and record branch-level publication status; do not claim complete publication. |

## Browser QA Dependencies

Playwright is not required for Codex to load this Skill or for builders to create the three designs. It is required for the supplied automated browser QA runner to produce a qualifying `PASS`. Missing dependencies produce an explicit `BLOCKED` result instead of a false failure.

Do not install Playwright, `axe-core`, or browsers automatically. First check for compatible existing packages and an existing Chromium/Chrome runtime. If they are absent, state the exact need and ask the user. An approved isolated dependency root may be supplied through `ARENA_QA_NODE_MODULES`; an approved existing browser may be supplied through `ARENA_QA_BROWSER_EXECUTABLE`. Do not change the product's dependency files merely to run Arena QA unless the user chooses that installation scope.

## Completion Standard

The Skill succeeds only when the user has compared three independent, fully rendered, fully qualified directions and selected one complete winner; that winner is merged and validated; linked worktrees are cleaned; and all three design branches remain available. The objective is not three merely different screenshots. It is three coherent design propositions good enough that choosing the winner is genuinely difficult.
