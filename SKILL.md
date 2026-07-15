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
3. Keep a complete, separate `DESIGN_BRIEF.md` for every candidate. Before creating worktrees, show the user a Markdown comparison table of the three directions' decision-relevant summaries and obtain one explicit approval of the three-direction set to enter implementation. Do not paste the three full briefs into chat unless the user asks to inspect one or more of them.
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
- Preserve all three complete briefs; verify each fixed `User Comparison Summary`, derive one traceable Markdown comparison table, and obtain approval of the three-direction set.
- Configure preview and QA commands without dynamic shell strings.
- Dispatch or coordinate three builders while preserving worktree isolation.
- Open and inspect the screenshots for every candidate.
- Sign visual quality and direction consistency only from current evidence.
- Present three qualified whole versions without ranking them.
- Ask for the winner, merge it, validate it, clean worktrees, and verify branch retention.

### Builder

- Work only in the assigned worktree and branch.
- Read the committed `DESIGN_BRIEF.md` and only the stage-appropriate frozen references supplied by the main agent.
- Never receive or inspect another candidate's brief, the three-direction comparison table, arena-level comparison material, or source files that describe sibling directions.
- Treat `User Comparison Summary` as an overview of the same complete brief, never as a reduced dispatch contract; implement from all detailed sections without editing the approved brief.
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

Universal references are mandatory at their stated stages, not all at Skill load time. Read only what the current stage needs, but read each selected file completely.

- Before drafting directions: [`references/direction-brief.md`](references/direction-brief.md) and [`references/anti-slop.md`](references/anti-slop.md).
- Before drafting directions, optionally select at most one domain pack for the entire Arena run. Select it only when the product's primary task, core content shape, and target users clearly match an existing pack; all three candidates use that selected domain pack, or all three use none. For cross-domain products, choose by the Arena run's primary task. If no single pack clearly matches, select none and continue with the universal references. Never combine packs or invent an unvalidated pack for coverage.
- When a domain pack is selected: the main agent reads its `shared-judgments.md`, `directions/direction-a.md`, `directions/direction-b.md`, `directions/direction-c.md`, and `orthogonality-check.md` completely; begin with [`references/domain-packs/README.md`](references/domain-packs/README.md). A selected domain pack calibrates the domain but never replaces the universal direction, anti-slop, visual, interaction, or qualification standards.
- Before implementation and rendered review: [`references/visual-quality-bar.md`](references/visual-quality-bar.md), [`references/interaction-quality-bar.md`](references/interaction-quality-bar.md), and [`references/arena-scorecard.md`](references/arena-scorecard.md).
- Before operating the state machine: [`references/arena-lifecycle.md`](references/arena-lifecycle.md).
- Before authoring or running declarative browser QA: [`references/qa-configuration.md`](references/qa-configuration.md) and the schemas under `scripts/schemas/`.

The absence of a matching domain pack never blocks brief drafting, approval of the three-direction set, worktree creation, building, QA, qualification, or final selection. Do not force a non-finance product into the finance/data pack.

Resolve every reference from the loaded `SKILL_ROOT`, not from the product worktree. Before briefs are drafted, determine and freeze the complete reference set that this Arena run will consume: the universal references required across its stages, plus the five required files from the selected domain pack, if any. Record each consumed file's absolute path and SHA-256. Unselected packs are not inputs or integrity blockers. Stage-specific reading still occurs at the stages above; freezing does not require loading every universal reference when the Skill first activates. Never add a previously unselected pack or otherwise extend the frozen manifest in place. If the reference set must change, or a frozen file changes or becomes unavailable, restore the frozen bytes or ask the user to restart or cancel the Arena.

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

Use the same product and technical snapshot for all three briefs. Apply the universal direction standard and anti-slop challenge, plus the selected domain pack when one exists. Without a selected domain pack, draft the same complete three-direction set from the universal references and product evidence; do not fabricate domain calibration. Each direction must define:

- subject, expert audience, and one primary job;
- an evidence-backed aesthetic thesis;
- one content-bearing signature element;
- one bounded design risk;
- a specific anti-default and observable replacement;
- first-screen and continuation wireframes, including narrow behavior;
- at least three observable pairwise differences;
- semantic token commitments and the two-sided replaceability test.

Reject the set if one component tree could express all three by changing tokens, if two share the same first-screen grammar, or if their identities depend on fashionable effects. When a domain pack is selected, the main agent applies its shared judgments to all three briefs, assigns direction A/B/C to the matching candidate, and uses its orthogonality check on the three-direction set. The main agent owns this comparison; builders do not select, reinterpret, or renegotiate directions.

Save the exact three complete brief files under `ARENA_RUN_ROOT`. Each must contain a fully populated `User Comparison Summary` after approval metadata and before the product snapshot. The summary is part of the complete brief and may only restate commitments established in its detailed sections. Reconcile each summary after the complete brief is otherwise ready; any contradiction or unsupported summary claim means the brief is unfinished and cannot be shown for approval or materialized. Do not compress, replace, or embed the complete brief in a builder dispatch prompt: each builder must receive its assigned complete `DESIGN_BRIEF.md` as a file.

Derive one Markdown comparison table from the three fixed summary blocks, with one row per candidate and these columns: Style / direction, Primary job and audience, Aesthetic thesis, First-screen grammar, Signature element, Intentional risk, Anti-default replacement, Responsive posture, and Observable distinctions. Every decision field must trace to the matching brief's `User Comparison Summary`. The main agent may shorten wording, reorder phrases, add line breaks, or lightly compress for table readability, but must not add, remove, mix, exaggerate, or materially change a design commitment or risk. The table is not a score, ranking, recommendation, mix-and-match menu, substitute for a complete brief, or early winner signal.

By default, show the user only that table, name the three saved complete brief files, and offer any one or more full briefs on request. The user then explicitly approves the three-direction set to enter implementation: all three are worth building, structurally distinct, and acceptable in primary job, risk, and responsive posture. This approval is not a winner choice, does not drop a candidate, and does not permit fewer than three builds. If the user requests a pre-approval revision, update both that brief's detailed sections and summary, recheck the three-direction set, regenerate the table, and request approval again.

Only after approval, hash the exact UTF-8 bytes of all three complete briefs, including their summary blocks. Those approved full files—not the table, summary alone, or a compressed prompt—remain the sole complete source of truth for materialization, brief-integrity checks, review, recovery, and builders. Do not rewrite a summary or any other brief content after approval; use the existing brief-integrity and restart/cancel path if a change is required.

### 3. Materialize isolated candidates

Use `create-worktrees` to create three linked worktrees from the same final `BASE_SHA`. Materialize each approved brief byte-for-byte, verify its approved SHA-256, commit it on the matching branch, and record the brief commit.

Dispatch three builders in parallel when delegation is available; otherwise build sequentially and tell the user that dispatch was unavailable. Isolation and the three-candidate completion gate do not change.

Each builder receives only its own committed `DESIGN_BRIEF.md`, the universal references allowed for the implementation stage, and—only when the main agent lists it as a dispatch input—the selected domain pack's `shared-judgments.md`. With no selected domain pack, dispatch no domain-pack files. Never dispatch direction source files, `orthogonality-check.md`, either sibling brief, the user comparison table, or other arena-level material that could reveal or encourage imitation of sibling directions.

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
