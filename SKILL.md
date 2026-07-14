---
name: vibe-design-arena
description: Use when a user has an existing product codebase and wants to explore three independent frontend redesign directions in parallel, using git worktree branches plus sub-agents or dispatch, then preview the three complete alternatives, choose one, merge the selected branch back into the main line, clean up the linked worktrees, and retain every unselected branch. The workflow is for whole-style selection only, not mix-and-match composition, cherry-picking, or product-specific templates.
---

# Vibe Design Arena

Run a three-way frontend style exploration for an existing product repository. Build three complete, internally coherent alternatives from the same Git starting point, preview them side by side, let the user choose one, merge the chosen branch back, remove the linked worktrees, and retain the unselected branches for later inspection.

Do not support mixing elements across alternatives. The user chooses one complete branch.

## Operating Rules

- Treat all product details as runtime inputs: repo path, target product, audience, routes, brand constraints, references, install commands, test commands, preview commands, required environment variables, local services, and setup steps that must run before dev or build commands.
- Do not hard-code a framework, product type, UI style, or code example.
- Do not start worktree creation until the user has seen and confirmed the complete contents of all three `DESIGN_BRIEF.md` files.
- Do not cherry-pick selected elements. If the user asks to mix alternatives, explain that this skill handles whole-branch selection only and ask them to choose one direction or start a separate redesign task.
- Preserve unrelated user changes. Never reset, delete, or overwrite ambiguous work without explicit confirmation.
- Keep the three alternatives isolated in separate linked worktrees and branches.
- Retain every unselected style branch after the arena. Cleanup removes linked worktrees, not the losing branches.

## Stage 1: Inspect The Product And Propose Directions

Start in the product repository, or ask for the repo path if it is unclear.

### Freeze The Skill And Reference Snapshot

Resolve and record the absolute `SKILL_ROOT` that contains the loaded `SKILL.md`. Do not derive reference paths from the product repository or a style worktree.

Bash example:

```bash
SKILL_ROOT="$(cd "<directory-containing-the-loaded-SKILL.md>" && pwd -P)"
```

PowerShell example:

```powershell
$skillRoot = (Resolve-Path '<directory-containing-the-loaded-SKILL.md>').Path
```

Record Skill provenance before reading references. If `SKILL_ROOT` is inside Git, record the Git top level, current commit, and whether `SKILL.md` or `references/` differs from that commit:

```bash
git -C "$SKILL_ROOT" rev-parse --show-toplevel
git -C "$SKILL_ROOT" rev-parse HEAD
git -C "$SKILL_ROOT" status --short -- SKILL.md references
```

PowerShell equivalent:

```powershell
git -C $skillRoot rev-parse --show-toplevel
git -C $skillRoot rev-parse HEAD
git -C $skillRoot status --short -- SKILL.md references
```

Record the commit as provenance only when available. If Git is unavailable, or if any consumed file is untracked or differs from that commit, label the provenance `NO-GIT/HASHED` or `DIRTY-GIT/HASHED`. In every mode, SHA-256 hashes are the authoritative content lock.

Create one Arena-level reference snapshot manifest before drafting. Include:

```text
Reference snapshot ID:
Absolute SKILL_ROOT:
Skill Git root or NO-GIT:
Skill commit or HASHED provenance:
absolute file path | SHA-256
```

Hash `SKILL.md` and the core references: `direction-brief.md`, `anti-slop.md`, `visual-quality-bar.md`, `interaction-quality-bar.md`, and `arena-scorecard.md`. After the product domain is known and before reading a matching domain pack, extend the same manifest with `domain-packs/README.md` and every consumed file in that pack: `shared-judgments.md`, all three direction sources, and `orthogonality-check.md`. Then freeze the manifest and assign its final snapshot ID.

All reference names in this workflow must resolve against the recorded absolute `SKILL_ROOT`, never against the product worktree. Before every later main-agent or builder read, recompute the file's SHA-256 and compare it with the frozen manifest. If any path or hash differs, stop the Arena. Restore access to the frozen bytes, or ask the user whether to restart the entire Arena with a new snapshot or cancel; never update the manifest in place.

Preflight the Git repository boundary before running the full Git state check. This step first decides whether the current directory is already inside a Git repository:

```bash
git rev-parse --is-inside-work-tree
```

PowerShell equivalent:

```powershell
git rev-parse --is-inside-work-tree
```

If this command fails, stop and explain that Vibe Design Arena cannot run directly in a non-Git directory. The skill's core mechanism depends on Git history: three worktrees must branch from the same common ancestor, and the selected branch must later be merged back by recalculating whether fast-forward or a merge commit is correct at merge time.

Ask the user to choose one of these options. Do not choose for them:

- Initialize a Git repository now and create a baseline commit to use as the common starting point for the three worktrees.
- Point to the correct path if the current directory was the wrong target and an existing Git repository already exists elsewhere.
- Cancel this task.

If the user points to a different repository path, enter that path and restart Stage 1 preflight from the beginning.

If the inside-work-tree check succeeds, verify that the repository already has a baseline commit:

```bash
git rev-parse HEAD
```

PowerShell equivalent:

```powershell
git rev-parse HEAD
```

If this command fails, stop and explain that the directory is a Git repository but has no commits yet, so `HEAD` is unborn and Vibe Design Arena still has no `BASE_SHA` for creating the three worktrees. Ask the user to choose the same three options: create a baseline commit now, point to a different existing Git repository path, or cancel this task. If the user points to a different repository path, enter that path and restart Stage 1 preflight from the beginning. If the user chooses to create a baseline commit in this existing repository, skip `git init` and continue with the `.gitignore` Step 1 and Step 2 flow below.

If the user chooses to initialize Git or create a baseline commit in an existing repository with unborn `HEAD`, split `.gitignore` handling into two steps with a real stop between them.

Step 1: Inspect and ask for confirmation. Scan the directory for obvious generated artifacts or dependency folders, such as existing `node_modules`, `dist`, `build`, `.next`, `out`, `coverage`, virtual environment directories, and similar rebuildable output.

```bash
for path in node_modules dist build .next out coverage .venv venv env __pycache__; do
  [ -d "$path" ] && printf '%s\n' "$path"
done
```

PowerShell equivalent:

```powershell
@('node_modules','dist','build','.next','out','coverage','.venv','venv','env','__pycache__') |
  Where-Object { Test-Path $_ -PathType Container }
```

Present the detected paths and this suggested default pattern list to the user:

```text
node_modules/
dist/
build/
.next/
out/
coverage/
.venv/
venv/
env/
__pycache__/
```

If `.gitignore` already exists, check whether it already covers these patterns and report which suggested patterns are already covered and which would be added. Stop and ask the user to confirm or modify the pattern list. Explain that if the project has special cases, such as a directory that looks generated but should actually be tracked, the user should remove that pattern before initialization continues.

Step 2: Only after the user confirms the `.gitignore` plan, write or extend `.gitignore`, stage files, and show the staged baseline for review. Use the final pattern list confirmed or modified in Step 1; it may differ from the default list. Do not run these commands before receiving the user's confirmation.

If the user chose to initialize a non-Git directory, run `git init` first. Skip this command for an existing repository with unborn `HEAD`.

Bash:

```bash
git init
```

PowerShell:

```powershell
git init
```

For both the non-Git path and the unborn-`HEAD` path, write or extend `.gitignore`, stage files, and show the staged baseline for review.

Bash:

```bash
touch .gitignore
confirmed_ignore_patterns=(
  "node_modules/"
  "dist/"
  "build/"
  ".next/"
  "out/"
  "coverage/"
  ".venv/"
  "venv/"
  "env/"
  "__pycache__/"
)

# Treat this as the Step 1 user-confirmed final list. Remove or add entries here if the user changed the default list.
for pattern in "${confirmed_ignore_patterns[@]}"; do
  grep -qxF "$pattern" .gitignore || printf '%s\n' "$pattern" >> .gitignore
done

git add -A
git status --short
git diff --cached --stat
```

PowerShell:

```powershell
$confirmedIgnorePatterns = @(
  'node_modules/',
  'dist/',
  'build/',
  '.next/',
  'out/',
  'coverage/',
  '.venv/',
  'venv/',
  'env/',
  '__pycache__/'
)

# Treat this as the Step 1 user-confirmed final list. Remove or add entries here if the user changed the default list.
if (-not (Test-Path .gitignore)) {
  New-Item -ItemType File .gitignore | Out-Null
}

$existingIgnore = Get-Content .gitignore -ErrorAction SilentlyContinue
foreach ($pattern in $confirmedIgnorePatterns) {
  if ($existingIgnore -notcontains $pattern) {
    Add-Content -Path .gitignore -Value $pattern
  }
}

git add -A
git status --short
git diff --cached --stat
```

Stop after showing the staged baseline and ask the user to confirm that these are the files that should enter the initial commit. Only after the user confirms, create the baseline commit.

Bash:

```bash
git commit -m "Initial commit before Vibe Design Arena"
```

PowerShell:

```powershell
git commit -m "Initial commit before Vibe Design Arena"
```

After this initial commit exists, let it become the later `BASE_SHA` through the normal Stage 2 "record the common starting point" commands. Do not define separate `BASE_BRANCH` or `BASE_SHA` variables here.

Verify Git state:

```bash
git rev-parse --show-toplevel
git status --short
git branch --show-current
git rev-parse HEAD
```

PowerShell equivalent:

```powershell
git rev-parse --show-toplevel
git status --short
git branch --show-current
git rev-parse HEAD
```

If the working tree has uncommitted changes, stop and explain that the arena branches will be created from the current `HEAD`, so uncommitted changes are not included automatically. Ask the user whether to commit, stash, or intentionally ignore those changes before proceeding.

Inspect the product:

- Read the README and setup docs.
- Identify the package manager, framework, app entry points, routes, major screens, component system, styling approach, and available scripts.
- Inspect the current UI structure and visual language.
- If practical, run the current app and review the main user flows before proposing redesigns.
- For JavaScript/Vite/esbuild/Vitest projects on Windows, note in the technical snapshot that `spawn EPERM` from install, build, test, or dev commands is usually an environment permission issue. If a cheap baseline command already fails this way, plan to retry the same command with escalation before diagnosing application code.
- If the user requested market or reference inspiration, research or inspect the provided references before proposing directions.

### Critical Gate: Define Three Strong Directions Before Creating Worktrees

This is the highest-weight and highest-leverage stage in the entire workflow. Do not treat direction drafting as one checklist item among many. If the three briefs are not genuinely distinct before worktree creation, stronger execution in Stage 3 will only produce three polished versions of the same weak design proposition; it cannot recover the missing strategic separation.

Before drafting any direction, the main agent must verify the frozen hash and then read the complete original text at the absolute snapshot-manifest path for:

- [`references/direction-brief.md`](references/direction-brief.md), which defines the seven required brief elements, the token summary format, and the conditions that make all three briefs unqualified and require a rewrite.
- When the product matches a domain pack, the main agent must read the complete original text of every content file in that domain pack folder before drafting any brief:
  - `shared-judgments.md` for judgments shared across all three candidates;
  - all three files under `directions/`, one source for each candidate;
  - `orthogonality-check.md` for the main agent's cross-direction comparison and pairwise rejection check.
  Use the reusable folder contract in [`references/domain-packs/README.md`](references/domain-packs/README.md). The main agent uses the complete pack to draft the three briefs and must apply the main-agent-only check to verify that the resulting set is genuinely orthogonal.
- [`references/anti-slop.md`](references/anti-slop.md), which identifies default AI-design traps and requires the three directions to rotate across different design logics.

Do not create worktrees or dispatch builders until this reading and brief-writing gate is complete. The main agent owns the one-time arena-level judgment that the three directions are sufficiently orthogonal.

Draft each direction with all seven elements and the token summary required by `direction-brief.md`, calibrated by the matching domain pack and differentiated through the design-logic rotation in `anti-slop.md`. Apply the rewrite criteria to the three briefs as a set and rewrite any failed set before presentation.

Then prepare a concise shared "Arena Preface" to place immediately before the three full `DESIGN_BRIEF.md` files in Stage 1.5:

- Product snapshot: what the product does, who uses it, and which screens matter most.
- Technical snapshot: framework, install command, dev command, build/test commands, likely preview ports, required environment variables, local services or mock backends, and any setup, codegen, or build-before-dev steps.
- Reference snapshot ID, absolute `SKILL_ROOT`, and Skill commit or hashed provenance.
- Style index: the name and one-sentence distinction for Style A, Style B, and Style C.

The Arena Preface is shared context, not a separate approval artifact. Do not ask the user to confirm it. The only design-confirmation point occurs after the user has seen the preface and the complete contents of all three files.

## Stage 1.5: Generate And Show Three `DESIGN_BRIEF.md` Drafts

Before the single design-confirmation point, the main agent must generate three complete Markdown artifacts, each named `DESIGN_BRIEF.md` and labeled clearly in the presentation as Style A, Style B, or Style C. At this stage they may be held by the main agent as drafts, but they are the exact candidate files that will be materialized in the three worktrees after approval.

Build every file from the complete ready-to-use template in the frozen `direction-brief.md`. Every `DESIGN_BRIEF.md` must contain:

- the three-line `[AESTHETIC]`, `[SIGNATURE]`, and `[ANTI-DEFAULT]` record from `anti-slop.md` at the top;
- approval and integrity metadata, including the reference snapshot ID and the rule that the final whole-file SHA-256 is stored externally;
- the complete product snapshot and technical snapshot;
- the completed seven required brief elements;
- the required token summary and two-sided replaceability test;
- the domain pack ID and domain source ID, or explicit `none` values when no domain pack matches;
- an adaptation and precedence section that makes the user-approved seven elements normative and the domain source calibration material; and
- when a domain pack matches, a `Domain Direction Source — Complete Verbatim Copy` section containing the entire original text of that style's matching source file under `directions/`.

For the domain direction source, copy the whole file exactly. Preserve every heading, paragraph, list item, warning, and boundary note in its original order. Do not excerpt selected sentences, summarize it, paraphrase it, compress it, or replace it with a link. The copied block must be complete enough to compare line-for-line with the source file. Style A receives only the complete A source, Style B only the complete B source, and Style C only the complete C source.

If no domain pack matches, all three `DESIGN_BRIEF.md` files must still use the full template. Set the domain pack and source IDs to `none` and mark the verbatim source section `Not applicable — no domain pack matched`; do not omit the section structure.

Use the shared judgments while drafting and use the main-agent-only comparison file to test the three drafts as a set. If the three files fail the orthogonality or rewrite criteria, revise them before presentation.

Present the Arena Preface followed by the full contents of all three `DESIGN_BRIEF.md` drafts in one confirmation sequence. Do not ask for approval after the preface or after an individual file. A summary, abbreviated preview, diff, or table is not a substitute for showing all three complete files. After any requested revision, show the preface and the full current contents of all three files again before asking for the single final confirmation.

Before final confirmation, resolve any conflict between the completed seven brief elements and the embedded domain direction. The user-approved seven elements, token summary, replaceability test, and product or technical constraints are the normative implementation contract. The complete domain direction copy is calibration material. If they conflict, the main agent must revise the normative brief, re-run the orthogonality checks, and show all three complete files again; a builder must never decide which part wins.

Ask the user to confirm, replace, or adjust the three complete files. Do not create worktrees or enter Stage 2 until the user explicitly confirms them. Preserve the exact approved contents for Stage 2; do not silently regenerate or rewrite them after approval.

At final confirmation, compute and record a separate SHA-256 for the exact UTF-8 bytes of each approved `DESIGN_BRIEF.md`. Store an approval registry before Stage 2:

```text
style | approved brief SHA-256 | approval date or turn | reference snapshot ID
```

Line endings and encoding are part of the protected bytes. Later materialization must reproduce the exact approved file, not a visually equivalent rewrite. Do not write the resulting hash back into `DESIGN_BRIEF.md`: changing the file to insert its own hash would change the whole-file hash. Keep the final value in the external approval registry and Candidate Record.

## Stage 2: Create Three Worktrees From One Common Ancestor

After confirmation, choose branch and worktree names. Do not record `BASE_SHA` yet. First complete the `.worktrees/` ignore check and leave the main worktree clean so the final common ancestor includes any required `.gitignore` commit.

Default branches:

- `style-a`
- `style-b`
- `style-c`

Default to repository-internal worktree paths first:

- `.worktrees/style-a`
- `.worktrees/style-b`
- `.worktrees/style-c`

Before creating those paths, make sure `.worktrees/` is ignored. Inspect `.gitignore` first:

```bash
if [ -f .gitignore ]; then
  grep -qxF ".worktrees/" .gitignore || printf 'missing ignore rule: .worktrees/\n'
else
  printf 'missing .gitignore and ignore rule: .worktrees/\n'
fi
```

PowerShell equivalent:

```powershell
if (Test-Path .gitignore) {
  $existingIgnore = Get-Content .gitignore -ErrorAction SilentlyContinue
  if ($existingIgnore -notcontains '.worktrees/') {
    'missing ignore rule: .worktrees/'
  }
} else {
  'missing .gitignore and ignore rule: .worktrees/'
}
```

If `.worktrees/` is missing, show the user this exact rule and stop to ask for confirmation before writing it:

```text
.worktrees/
```

Only after the user confirms, add the rule, stage only `.gitignore`, and inspect the staged diff:

```bash
touch .gitignore
grep -qxF ".worktrees/" .gitignore || printf '%s\n' ".worktrees/" >> .gitignore
git add .gitignore
git diff --cached -- .gitignore
```

PowerShell equivalent:

```powershell
if (-not (Test-Path .gitignore)) {
  New-Item -ItemType File .gitignore | Out-Null
}
$existingIgnore = Get-Content .gitignore -ErrorAction SilentlyContinue
if ($existingIgnore -notcontains '.worktrees/') {
  Add-Content -Path .gitignore -Value '.worktrees/'
}
git add .gitignore
git diff --cached -- .gitignore
```

Stop after showing the staged diff. If it contains anything beyond the confirmed `.worktrees/` rule, ask the user how to handle the extra change. If the rule was already tracked, do not create an empty commit.

Only when the staged diff contains exactly the confirmed ignore change, commit it:

```bash
git commit -m "Ignore Vibe Design Arena worktrees"
```

PowerShell equivalent:

```powershell
git commit -m "Ignore Vibe Design Arena worktrees"
```

After either path, verify that the main worktree is clean:

```bash
git status --short
```

PowerShell equivalent:

```powershell
git status --short
```

If this prints any entry, stop and resolve it before continuing.

Then check branch and path availability using the confirmed names:

```bash
WORKTREE_ROOT=".worktrees"
STYLE_A_WORKTREE="$WORKTREE_ROOT/style-a"
STYLE_B_WORKTREE="$WORKTREE_ROOT/style-b"
STYLE_C_WORKTREE="$WORKTREE_ROOT/style-c"

for branch in style-a style-b style-c; do
  git show-ref --verify --quiet "refs/heads/$branch" && printf 'branch exists: %s\n' "$branch"
done
for path in "$STYLE_A_WORKTREE" "$STYLE_B_WORKTREE" "$STYLE_C_WORKTREE"; do
  [ -e "$path" ] && printf 'path exists: %s\n' "$path"
done
```

PowerShell equivalent:

```powershell
$worktreeRoot = '.worktrees'
$styleAWorktree = Join-Path $worktreeRoot 'style-a'
$styleBWorktree = Join-Path $worktreeRoot 'style-b'
$styleCWorktree = Join-Path $worktreeRoot 'style-c'

foreach ($branch in @('style-a','style-b','style-c')) {
  git show-ref --verify --quiet "refs/heads/$branch"
  if ($LASTEXITCODE -eq 0) { "branch exists: $branch" }
}
foreach ($path in @($styleAWorktree,$styleBWorktree,$styleCWorktree)) {
  if (Test-Path $path) { "path exists: $path" }
}
```

If those branch names or paths already exist, stop and ask the user for replacement names, or show clearly namespaced alternatives such as `vda-style-a-YYYYMMDD` and ask the user to confirm them before creating any worktrees.

Immediately before creation, verify the main worktree is still clean:

```bash
git status --short
```

PowerShell equivalent:

```powershell
git status --short
```

Stop if `git status --short` prints any entry. Only after it returns no entries, record the common starting point:

```bash
BASE_BRANCH=$(git branch --show-current)
BASE_SHA=$(git rev-parse HEAD)
```

PowerShell equivalent:

```powershell
$baseBranch = git branch --show-current
$baseSha = git rev-parse HEAD
```

The three style branches must all be created from this final `BASE_SHA`, which includes the `.gitignore` commit when one was required.

Create linked worktrees from the same `BASE_SHA` using the confirmed paths:

```bash
git worktree add -b style-a "$STYLE_A_WORKTREE" "$BASE_SHA"
git worktree add -b style-b "$STYLE_B_WORKTREE" "$BASE_SHA"
git worktree add -b style-c "$STYLE_C_WORKTREE" "$BASE_SHA"
git worktree list
```

PowerShell equivalent:

```powershell
git worktree add -b style-a $styleAWorktree $baseSha
git worktree add -b style-b $styleBWorktree $baseSha
git worktree add -b style-c $styleCWorktree $baseSha
git worktree list
```

If repository-internal worktree creation fails because of sandbox permission denial or another write failure, stop immediately. Tell the user: `repository-internal worktree path is not writable: <exact error>`. Then propose one concrete repository-external writable directory, such as an adjacent `vibe-design-arena` directory or another user-approved workspace path, and wait for the user to confirm that fallback path before creating any worktrees there. Do not silently choose a temporary directory or any repository-external path.

### Materialize And Commit The Approved `DESIGN_BRIEF.md` Files

After all three worktrees exist and before dispatching any builder, write the exact user-approved Style A, Style B, and Style C drafts to the root of their corresponding worktrees:

- Style A: `<style-a-worktree>/DESIGN_BRIEF.md`
- Style B: `<style-b-worktree>/DESIGN_BRIEF.md`
- Style C: `<style-c-worktree>/DESIGN_BRIEF.md`

Do not regenerate, summarize, paraphrase, or otherwise revise the approved contents while materializing them. If a domain pack was used, verify before commit that the embedded `Domain Direction Source — Complete Verbatim Copy` block in each file still matches its corresponding source under `directions/` line-for-line and contains the entire source file.

Before committing, compute the SHA-256 of each complete materialized file and compare it with that style's approved SHA-256. This whole-file check is mandatory and is not replaced by checking only the embedded domain block. Run the command from the corresponding worktree root or substitute the full worktree file path.

Bash example:

```bash
ACTUAL_BRIEF_SHA256=$(sha256sum DESIGN_BRIEF.md | awk '{print $1}')
test "$ACTUAL_BRIEF_SHA256" = "$APPROVED_BRIEF_SHA256"
```

PowerShell example:

```powershell
$actualBriefSha256 = (Get-FileHash -Algorithm SHA256 DESIGN_BRIEF.md).Hash
if ($actualBriefSha256 -ne $approvedBriefSha256) {
  throw 'DESIGN_BRIEF.md does not match the user-approved SHA-256'
}
```

If any hash differs, stop and rematerialize the exact approved bytes before dispatch. Do not ask the builder to reconcile the difference.

Commit each `DESIGN_BRIEF.md` on its own style branch before Stage 3 so the brief is part of that branch, not a temporary file retained only by the main agent.

Bash:

```bash
git -C "$STYLE_A_WORKTREE" add DESIGN_BRIEF.md
git -C "$STYLE_A_WORKTREE" commit -m "Add approved Vibe Design Arena brief for style A"

git -C "$STYLE_B_WORKTREE" add DESIGN_BRIEF.md
git -C "$STYLE_B_WORKTREE" commit -m "Add approved Vibe Design Arena brief for style B"

git -C "$STYLE_C_WORKTREE" add DESIGN_BRIEF.md
git -C "$STYLE_C_WORKTREE" commit -m "Add approved Vibe Design Arena brief for style C"
```

PowerShell equivalent:

```powershell
git -C $styleAWorktree add DESIGN_BRIEF.md
git -C $styleAWorktree commit -m "Add approved Vibe Design Arena brief for style A"

git -C $styleBWorktree add DESIGN_BRIEF.md
git -C $styleBWorktree commit -m "Add approved Vibe Design Arena brief for style B"

git -C $styleCWorktree add DESIGN_BRIEF.md
git -C $styleCWorktree commit -m "Add approved Vibe Design Arena brief for style C"
```

Immediately after each brief commit, record its independent commit hash:

```bash
BRIEF_COMMIT_A=$(git -C "$STYLE_A_WORKTREE" rev-parse HEAD)
BRIEF_COMMIT_B=$(git -C "$STYLE_B_WORKTREE" rev-parse HEAD)
BRIEF_COMMIT_C=$(git -C "$STYLE_C_WORKTREE" rev-parse HEAD)
```

PowerShell equivalent:

```powershell
$briefCommitA = git -C $styleAWorktree rev-parse HEAD
$briefCommitB = git -C $styleBWorktree rev-parse HEAD
$briefCommitC = git -C $styleCWorktree rev-parse HEAD
```

For each worktree, verify that `DESIGN_BRIEF.md` is tracked, its whole-file SHA-256 still equals the approved value, the recorded brief commit exists on the expected branch, and the worktree is clean before dispatch. If writing, verification, or commit fails for any style, stop and repair that style's branch before dispatching builders; do not let one builder begin without its committed brief.

Use one common ancestor because:

- The user compares three redesigns of the same product version.
- The only intended differences are the style implementations.
- Git can compute a clean diff from the selected branch back to the main line.
- Linked worktrees share the same repository object database while keeping separate working directories, indexes, and per-worktree `HEAD`s.
- Independent repository copies would hide ancestry, waste space, and make merge cleanup less reliable.

## Stage 3: Dispatch Parallel Builders

Use sub-agents or dispatch when available. Give each builder only its own worktree path. Its approved, committed style brief is the `DESIGN_BRIEF.md` file at that worktree's root.

Reuse the single frozen Arena reference snapshot created in Stage 1. Do not compute a per-candidate snapshot and do not refresh it at dispatch time. Immediately before dispatch, verify every reference that a builder will receive against the manifest's absolute path and SHA-256. If any check fails, stop and restore access to the frozen bytes, or ask the user whether to restart the entire Arena with a new snapshot or cancel.

Each builder works in one isolated worktree:

- Style A builder works only in `.worktrees/style-a` on branch `style-a`, unless the user confirmed a different Stage 2 fallback path.
- Style B builder works only in `.worktrees/style-b` on branch `style-b`, unless the user confirmed a different Stage 2 fallback path.
- Style C builder works only in `.worktrees/style-c` on branch `style-c`, unless the user confirmed a different Stage 2 fallback path.

Isolation works because every linked worktree has its own working directory, index, and checked-out branch `HEAD`. The builders share Git history but do not write to the same files on disk.

For each builder, the dispatch must provide:

- The exact assigned worktree path and branch.
- The product snapshot and technical snapshot.
- The recorded brief commit, approved brief SHA-256, frozen reference snapshot ID, absolute `SKILL_ROOT`, Skill commit or hashed provenance, and the relevant manifest entries.
- An explicit instruction to read the complete `DESIGN_BRIEF.md` at the assigned worktree root before implementing. This file always exists and contains at least the approved seven brief elements; when domain calibration applies, it also contains that style's complete verbatim direction source already embedded by the main agent.
- When a domain pack matches, the frozen manifest entry for `shared-judgments.md`: its exact absolute snapshot path and SHA-256, plus an instruction to verify the hash and read the file completely. Do not send a relative path or any matching direction-file path.
- The screens and flows to prioritize.
- The frozen manifest entries for the four universal references—`anti-slop.md`, `visual-quality-bar.md`, `interaction-quality-bar.md`, and `arena-scorecard.md`—including each exact absolute snapshot path and SHA-256, plus an instruction to verify every hash and read each complete original file before implementing. The main agent must not send paths relative to the product worktree, paraphrase, condense, or substitute excerpts for these files in the dispatch prompt.
- A requirement to use the frozen `anti-slop.md` manifest entry within the approved brief, while leaving the one-time judgment about whether all three candidates are orthogonal to the main agent's completed Stage 1 work.
- A requirement to self-check the finished implementation against the frozen `visual-quality-bar.md` and `interaction-quality-bar.md` manifest entries, verify that the approved brief's signature element and anti-default are present in the code, then report preliminary pass/fail against every applicable gate in the frozen `arena-scorecard.md`.
- The allowed scope: frontend redesign only; if any change outside that scope is needed, report it to the main agent, and have the main agent stop and ask the user to confirm before continuing.
- The expected validation commands.
- The requirement to preserve functionality and avoid unrelated refactors.

Do not include any other domain-pack path in a builder dispatch, and do not ask a builder to discover or browse the domain-pack directory. The builder uses the assigned `DESIGN_BRIEF.md` as its only style-specific source.

Inside the brief, the user-approved seven elements and associated implementation constraints are normative. The embedded domain direction is calibration material. If a builder perceives a conflict, it must stop and report it to the main agent; it must not reinterpret, rewrite, or choose between the two.

Each builder should:

1. Inspect the local worktree.
2. Verify that root-level `DESIGN_BRIEF.md` exists, is tracked, and has already been committed on the assigned branch. Compare its SHA-256 with the approved value and verify that it matches the file at the recorded brief commit. If any check fails, mark the candidate `FAIL` and return it to the main agent without implementing from a prompt summary.
3. Recompute the SHA-256 of every supplied absolute reference path and compare it with the frozen manifest. If a path is unavailable or any hash differs, stop and return the candidate to the main agent without implementing. Only after all checks pass, read the complete `DESIGN_BRIEF.md`, all four universal references, and `shared-judgments.md` when that extra manifest entry was supplied.
4. Run the project's install command from the Stage 1 technical snapshot inside this worktree before making changes. Report installation failures to the main agent; the available outcomes are to fix the environment and retry, assign a replacement builder and retry the same style, or cancel the entire Arena. Do not skip a style or continue with fewer than three candidates. On Windows, if the failure is `spawn EPERM` from Node, Vite, esbuild, or Vitest, treat it as a likely sandbox or OS execution-permission issue and retry the same command with escalation before treating the product code as broken.
5. Implement the complete approved style direction.
6. Run the relevant lint, typecheck, test, or build commands available in the project. Apply the same `spawn EPERM` retry rule to validation commands.
7. Perform a preliminary reference-based self-check: inspect the implementation against the visual and interaction quality bars, confirm the brief's signature element and anti-default in code, and record the scorecard's preliminary pass/fail results. A rendered item without rendered evidence must be `FAIL`, not assumed `PASS`; the main agent owns final qualification in Stage 4.5.
8. Summarize changed files, visual decisions, validation results, risks, and the preliminary self-check results for the main agent. If browser preview was intentionally deferred to the main agent, identify every rendered item still lacking evidence.
9. Before committing, verify that `git diff --exit-code <brief-commit> -- DESIGN_BRIEF.md` succeeds and that the current file SHA-256 equals the approved SHA-256. If either check fails, automatically mark the candidate `FAIL`, stop, and return it to the main agent. Do not silently restore or edit the brief.
10. Commit the branch when its version is ready:

```bash
git status --short
git add -A
git commit -m "Implement Vibe Design Arena style A"
```

PowerShell equivalent:

```powershell
git status --short
git add -A
git commit -m "Implement Vibe Design Arena style A"
```

Use the matching style letter in the commit message.

After the implementation commit, verify brief integrity again:

```bash
git diff --exit-code "$BRIEF_COMMIT" HEAD -- DESIGN_BRIEF.md
ACTUAL_BRIEF_SHA256=$(sha256sum DESIGN_BRIEF.md | awk '{print $1}')
test "$ACTUAL_BRIEF_SHA256" = "$APPROVED_BRIEF_SHA256"
```

PowerShell equivalent:

```powershell
git diff --exit-code $briefCommit HEAD -- DESIGN_BRIEF.md
$actualBriefSha256 = (Get-FileHash -Algorithm SHA256 DESIGN_BRIEF.md).Hash
if ($actualBriefSha256 -ne $approvedBriefSha256) {
  throw 'DESIGN_BRIEF.md changed after approval'
}
```

Any difference automatically fails the candidate and returns it for repair before preview. Do not enter Stage 4 with a modified brief.

If sub-agent or dispatch tooling is unavailable, execute the three branches sequentially while preserving the same worktree isolation and tell the user that parallel dispatch was unavailable. The same three-candidate completion gate still applies.

## Stage 4: Start And Track Preview Servers

The main agent owns preview server lifecycle. Builders should not leave unmanaged long-running servers.

Assign a different port to each alternative. Suggested defaults:

- Style A: `5173`
- Style B: `5174`
- Style C: `5175`

```bash
lsof -i :<port>
```

PowerShell equivalent:

```powershell
Test-NetConnection 127.0.0.1 -Port <port>
```

If a port is occupied, choose the next available port and record it.

Before preview, apply the required environment variables, local services, and setup steps captured in the Stage 1 technical snapshot. Start each preview server from its worktree using the project's actual dev command. Adapt the command to the framework instead of hard-coding one syntax. Examples only:

```bash
npm run dev -- --host 127.0.0.1 --port 5173
npm run dev -- -p 3001
pnpm dev --host 127.0.0.1 --port 5174
```

PowerShell examples only:

```powershell
npm run dev -- --host 127.0.0.1 --port 5173
npm run dev -- -p 3001
pnpm dev --host 127.0.0.1 --port 5174
```

Record a preview registry:

```text
style | branch | worktree path (`.worktrees/...` or confirmed fallback) | port | command | process id/session id | log path
```

On bash/macOS/Linux, start the dev server in the background from the worktree, redirect logs, and capture the PID:

```bash
(
  cd <worktree-path>
  nohup <dev-command> > <log-path> 2> <err-path> &
  echo $!
)
```

Record the printed PID in the preview registry.

On Windows PowerShell, prefer starting hidden tracked processes and capturing their process IDs:

```powershell
$p = Start-Process -FilePath npm.cmd `
  -ArgumentList @('run','dev','--','--host','127.0.0.1','--port','5173') `
  -WorkingDirectory '<worktree-path>' `
  -RedirectStandardOutput '<log-path>' `
  -RedirectStandardError '<err-path>' `
  -PassThru `
  -WindowStyle Hidden

$p.Id
```

If Windows `Start-Process` fails because of duplicate `Path`/`PATH` environment keys, or the dev server exits with Node/Vite/esbuild `spawn EPERM`, treat it as an environment startup problem. Request escalated preview startup, or ask the user to run the recorded preview commands manually. Do not mark the style implementation itself as failed solely because preview startup was blocked by this environment issue.

After recording the preview registry and before showing the comparison table, probe each preview URL with HTTP requests. Probe all three styles with their own recorded URLs and ports; do not probe one URL and treat all previews as ready. Do not rely only on captured dev-server stdout.

Bash HTTP probe example:

```bash
PREVIEW_URLS=(
  "http://127.0.0.1:5173"
  "http://127.0.0.1:5174"
  "http://127.0.0.1:5175"
)

for url in "${PREVIEW_URLS[@]}"; do
  status="000"
  for attempt in 1 2 3 4 5 6 7 8 9 10; do
    status=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)
    if [ "$status" != "000" ]; then
      printf 'preview responding: %s status=%s\n' "$url" "$status"
      break
    fi
    sleep 2
  done

  if [ "$status" = "000" ]; then
    printf 'preview did not respond after retries: %s\n' "$url"
  fi
done
```

PowerShell HTTP probe example:

```powershell
$previewUrls = @(
  'http://127.0.0.1:5173',
  'http://127.0.0.1:5174',
  'http://127.0.0.1:5175'
)

foreach ($url in $previewUrls) {
  $responding = $false
  for ($attempt = 1; $attempt -le 10; $attempt++) {
    try {
      $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 3
      "preview responding: $url status=$($response.StatusCode)"
      $responding = $true
      break
    } catch {
      Start-Sleep -Seconds 2
    }
  }

  if (-not $responding) {
    $port = ([System.Uri]$url).Port
    Test-NetConnection 127.0.0.1 -Port $port
    "preview did not respond after retries: $url"
  }
}
```

If HTTP probing still gets no response after the retry loop, treat that style's preview as failed to start. Report the failure, including the URL, port, command, process ID or session ID, and log paths. Then choose only one of these paths: repair the preview environment and retry; give the user the exact manual command and verify the resulting rendered candidate; or produce a complete static evidence bundle captured from the actually rendered candidate. Do not silently continue with a dead URL or with source inspection alone.

A static evidence bundle must still include the required viewport and state captures plus recorded keyboard, focus, reduced-motion, and interaction results from an actual rendered run. If neither a responding preview nor a complete evidence bundle exists for any style, stop. Stage 5 is blocked until all three candidates are viewable and fully evidenced.

Only stop preview servers that the main agent started and recorded. Do not kill unrelated processes just because they use a similar port.

## Stage 4.5: Build Final Evidence Bundles And Qualify All Three Candidates

The main agent is the final evidence owner. Builder scorecards are preliminary self-checks only. Before reading any quality reference, the main agent must verify its absolute path and SHA-256 against the frozen Arena manifest. The main agent must then complete every rendered check required by the frozen `visual-quality-bar.md`, `interaction-quality-bar.md`, and `arena-scorecard.md`; lightweight sampling is not a substitute.

Create one evidence bundle per candidate. Record a bundle path or artifact identifiers outside the product branch unless the user explicitly asks to track evidence files. Each bundle must include:

- style, branch, implementation commit, brief commit, approved brief SHA-256, reference snapshot ID, absolute `SKILL_ROOT`, Skill commit or hashed provenance, and the supplied manifest entries;
- route and viewport for every capture, including `320px`, a medium or tablet width, and a wide desktop width;
- screenshots of the primary screen, densest view, and applicable loading, empty, error, disabled, and stale-data states;
- edge-content captures for long text, missing values, negative values, and extreme numeric values where applicable;
- keyboard traversal and visible-focus results, plus the `200%` zoom result;
- actual reduced-motion results and the applicable interaction-acceptance checks, including rapid toggling and focus return;
- validation commands and results;
- every failed item, the attempted fix, and the result of the subsequent retest.

Do not mark a rendered item `PASS` without evidence in that candidate's bundle. Source code, a media query, a builder claim, or one successful viewport is not rendered evidence.

Before final qualification, recheck that `DESIGN_BRIEF.md` still matches both the recorded brief commit and approved SHA-256. Any difference automatically fails the candidate and returns it for repair.

For every failed scorecard item, run this loop:

1. Return the exact failed item IDs and evidence to the same builder or a replacement builder.
2. Implement the repair on that candidate's branch.
3. Re-run the candidate's validation commands.
4. Re-run brief-integrity checks.
5. Restart or refresh its preview and replace the affected evidence.
6. Have the main agent re-evaluate the failed items and record the retest result.

Repeat until the candidate passes or the Arena is cancelled. If a candidate cannot be completed, the available outcomes are to fix the environment, assign a replacement builder and retry, or cancel the entire Arena. Do not omit that candidate.

### Hard Gate Before User Selection

Do not enter Stage 5 until all three branches have:

- a complete committed implementation;
- a responding preview URL or a complete static evidence bundle from an actual rendered run;
- an unchanged approved `DESIGN_BRIEF.md`;
- successful required validation commands;
- a complete main-agent evidence bundle; and
- `OVERALL QUALIFICATION: PASS`.

The scorecard does not rank qualified candidates or make the aesthetic choice. After all three pass, give the user a comparison table containing:

- style letter and name;
- branch, implementation commit, brief commit, and brief SHA-256;
- preview URL or evidence-bundle location;
- frozen reference snapshot ID, absolute `SKILL_ROOT`, and Skill commit or hashed provenance;
- validation results and final qualification;
- main visual thesis; and
- known risks.

## Stage 5: User Selection

Ask the user to choose one complete alternative.

If the user wants more viewing time, allow preview servers and worktrees to remain temporarily. Make clear that final merge and cleanup have not happened yet.

If the user asks for revisions before choosing, revise the relevant whole branch or branches. Do not combine elements across branches.

Any revision invalidates that candidate's previous validation, preview evidence, and qualification. Return it through the full loop: implementation → validation → brief-integrity check → preview → evidence bundle → scorecard. Refresh the three-way comparison only after the revised candidate passes again; do not ask the user to choose from stale evidence.

## Stage 6: Stop Preview Servers Before Merge And Cleanup

Before merging or removing worktrees, the main agent must stop the recorded preview servers.

Use the preview registry to stop each process by recorded process ID or managed session handle.

On bash/macOS/Linux, try graceful shutdown first:

```bash
kill <pid>
```

On PowerShell:

```powershell
Stop-Process -Id <pid>
```

If graceful shutdown fails and the process is confirmed to be the recorded dev server, stop and ask the user to confirm before forcing it.

On bash/macOS/Linux:

```bash
kill -9 <pid>
```

On PowerShell:

```powershell
Stop-Process -Id <pid> -Force
```

After stopping, verify that the preview URLs no longer respond or that the recorded processes exited. If a port remains occupied, inspect the owning process before taking action. Do not terminate unknown processes without user confirmation.

If the user explicitly asks to keep previews open, defer merge and cleanup until they approve stopping the servers.

## Stage 7: Merge The Selected Branch

The fast-forward versus merge-commit decision must be made at merge time, not at worktree creation time. The main branch may have advanced while the arena stayed open.

Return to the original main worktree and branch:

```bash
git switch <BASE_BRANCH>
git status --short
```

PowerShell equivalent:

```powershell
git switch <BASE_BRANCH>
git status --short
```

If the main working tree is dirty, stop and ask whether to commit, stash, or cancel the merge. Do not merge over unrelated local changes.

Recompute ancestry immediately before merging:

```bash
git merge-base --is-ancestor HEAD <selected-branch>
```

PowerShell equivalent:

```powershell
git merge-base --is-ancestor HEAD <selected-branch>
```

If the command succeeds, the current main `HEAD` is an ancestor of the selected branch. Use fast-forward:

```bash
git merge --ff-only <selected-branch>
```

PowerShell equivalent:

```powershell
git merge --ff-only <selected-branch>
```

Use fast-forward when the selected branch is a direct descendant of the current main `HEAD`; this keeps history linear.

If the command fails because main has advanced separately, use a normal merge commit:

```bash
git merge --no-ff <selected-branch> -m "Merge selected Vibe Design Arena <selected-branch>"
```

PowerShell equivalent:

```powershell
git merge --no-ff <selected-branch> -m "Merge selected Vibe Design Arena <selected-branch>"
```

Use a merge commit when the current main branch and selected branch diverged after the arena was created.

If conflicts appear, stop and hand the conflict decision to the user. Do not automatically decide how to resolve conflicted code, because the conflict may represent two different intentions: the selected design branch and later main-branch changes.

Use this conflict principle for the user review: preserve the selected branch's complete design intent where possible, while also preserving meaningful later changes from the main branch, such as security fixes, functional bug fixes, or product behavior changes. If both cannot be preserved cleanly, present the conflicting files, summarize what each side appears to be trying to do, and ask the user which tradeoff to make. Do not choose one side by guessing.

If the conflict count is large, the affected scope is complex, or the user wants to pause, explain that the merge can be aborted to return to the pre-merge state:

Run this only after the user explicitly confirms aborting the merge.

```bash
git merge --abort
```

PowerShell equivalent:

```powershell
git merge --abort
```

After conflicts are resolved, show the key resolved result with `git diff` or an equivalent focused diff before completing the merge commit, and ask the user to confirm that it matches the selected design direction and preserves the necessary main-branch changes.

### Post-Merge Validation Hard Gate

After any merge path completes—fast-forward, conflict-free merge commit, or conflict-resolved merge commit—run the post-merge gate in the original main worktree. Do not treat pre-merge branch validation as a substitute.

First record the merged state and verify brief integrity:

```bash
POST_MERGE_SHA=$(git rev-parse HEAD)
git status --short
ACTUAL_BRIEF_SHA256=$(sha256sum DESIGN_BRIEF.md | awk '{print $1}')
test "$ACTUAL_BRIEF_SHA256" = "$APPROVED_BRIEF_SHA256"
```

PowerShell equivalent:

```powershell
$postMergeSha = git rev-parse HEAD
git status --short
$actualBriefSha256 = (Get-FileHash -Algorithm SHA256 DESIGN_BRIEF.md).Hash
if ($actualBriefSha256 -ne $approvedBriefSha256) {
  throw 'Merged DESIGN_BRIEF.md no longer matches the approved SHA-256'
}
```

If `git status --short` prints any entry, stop and resolve the dirty main worktree before validation.

Then run every relevant lint, build, test, typecheck, or other validation command from the technical snapshot in the main worktree. Record the commands and results against `POST_MERGE_SHA`.

If the main branch advanced independently after `BASE_SHA` or any merge conflict occurred, restart the selected design from the main worktree, probe the preview, and inspect at least the key routes and primary flow. Record this post-merge preview check, then stop that newly recorded preview process before Stage 8.

Any post-merge validation, brief-integrity, or required preview failure blocks Stage 8. Stop and repair the merged result or ask the user how to proceed; do not remove worktrees while the merged state is unverified.

Do not use cherry-pick for the selected design. The selected branch represents a complete version, not a collection of pieces.

## Stage 8: Clean Up Worktrees And Retain Unselected Branches

Cleanup happens after the selected branch is merged and preview servers are stopped.

First inspect each worktree and record its branch name and commit hash:

```bash
git -C <worktree-path> status --short --ignored
git -C <worktree-path> branch --show-current
git -C <worktree-path> rev-parse HEAD
```

PowerShell equivalent:

```powershell
git -C <worktree-path> status --short --ignored
git -C <worktree-path> branch --show-current
git -C <worktree-path> rev-parse HEAD
```

For the selected branch:

- Ensure it was merged into the main branch.
- Remove its worktree.
- Retain its branch by default. If the user separately asks to delete the already-merged selected branch, handle that request only after worktree cleanup with safe delete; never use force delete.

For unselected branches:

- Preserve every unselected branch unconditionally. Do not run any safe-delete, force-delete, or equivalent branch-deletion command on an unselected branch.
- Remove only the linked worktree after confirming that all intended changes are committed and recording the branch name and commit hash.
- Treat worktree removal and branch retention as separate operations: removing a linked worktree must leave its branch reference intact.
- After cleanup, verify that each unselected branch still exists at the recorded commit hash and report both values to the user.

Try normal removal first using the actual worktree paths confirmed in Stage 2. Use the recorded path variables or explicit placeholders; do not assume the worktrees are under `.worktrees/` if the user confirmed a fallback path:

```bash
git worktree remove "$STYLE_A_WORKTREE"
git worktree remove "$STYLE_B_WORKTREE"
git worktree remove "$STYLE_C_WORKTREE"
```

PowerShell equivalent:

```powershell
git worktree remove $styleAWorktree
git worktree remove $styleBWorktree
git worktree remove $styleCWorktree
```

If removal fails because the worktree contains generated or ignored files such as `node_modules`, `.next`, `dist`, build caches, or temporary preview output, ask the user to confirm that those files are disposable. After confirmation, use:

```bash
git worktree remove --force <worktree-path>
```

PowerShell equivalent:

```powershell
git worktree remove --force <worktree-path>
```

Do not use `--force` when the worktree contains ambiguous untracked files or user-created artifacts. List those files and ask the user whether to keep, commit, move, or discard them.

After worktrees are removed, verify that every unselected branch remains at its recorded commit hash. Use the actual branch names confirmed in Stage 2:

```bash
git show-ref --verify "refs/heads/<unselected-branch-1>"
git rev-parse <unselected-branch-1>
git show-ref --verify "refs/heads/<unselected-branch-2>"
git rev-parse <unselected-branch-2>
```

PowerShell equivalent:

```powershell
git show-ref --verify "refs/heads/<unselected-branch-1>"
git rev-parse <unselected-branch-1>
git show-ref --verify "refs/heads/<unselected-branch-2>"
git rev-parse <unselected-branch-2>
```

If the user separately requested deletion of the selected branch, verify that it is merged and use only safe delete:

```bash
git branch -d <selected-branch>
```

PowerShell equivalent:

```powershell
git branch -d <selected-branch>
```

If safe delete fails, stop, show why Git considers the selected branch unmerged, and keep the branch. Never force-delete it. This optional selected-branch action does not alter the unconditional retention rule for unselected branches.

Prune stale worktree metadata and verify final state:

```bash
git worktree prune
git worktree list
git status --short
```

PowerShell equivalent:

```powershell
git worktree prune
git worktree list
git status --short
```

## Final Report

End with:

- Selected style and branch.
- Selected brief commit and approved brief SHA-256.
- Frozen reference snapshot ID, absolute SKILL_ROOT, Skill commit or hashed provenance, and manifest location.
- Evidence-bundle locations and final qualification results for all three candidates.
- Merge method used: fast-forward or merge commit.
- Validation commands and results for the final post-merge SHA.
- Post-merge winner preview check when main advanced or conflicts occurred.
- Worktrees removed.
- Branches retained, with the branch name and commit hash for every retained style branch.
- Selected branch disposition, if the user separately requested its safe deletion.
- Any preview servers still running, if the user explicitly asked to keep them.
- Any remaining risks or manual checks.
