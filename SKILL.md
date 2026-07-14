---
name: vibe-design-arena
description: Use when a user has an existing product codebase and wants to explore three independent frontend redesign directions in parallel, using git worktree branches plus sub-agents or dispatch, then preview the three complete alternatives, choose one, merge the selected branch back into the main line, and clean up the unselected worktrees. The workflow is for whole-style selection only, not mix-and-match composition, cherry-picking, or product-specific templates.
---

# Vibe Design Arena

Run a three-way frontend style exploration for an existing product repository. Build three complete, internally coherent alternatives from the same Git starting point, preview them side by side, let the user choose one, merge the chosen branch back, and clean up the rest.

Do not support mixing elements across alternatives. The user chooses one complete branch.

## Operating Rules

- Treat all product details as runtime inputs: repo path, target product, audience, routes, brand constraints, references, install commands, test commands, preview commands, required environment variables, local services, and setup steps that must run before dev or build commands.
- Do not hard-code a framework, product type, UI style, or code example.
- Do not start worktree creation until the user confirms the three proposed style directions.
- Do not cherry-pick selected elements. If the user asks to mix alternatives, explain that this skill handles whole-branch selection only and ask them to choose one direction or start a separate redesign task.
- Preserve unrelated user changes. Never reset, delete, or overwrite ambiguous work without explicit confirmation.
- Keep the three alternatives isolated in separate linked worktrees and branches.

## Stage 1: Inspect The Product And Propose Directions

Start in the product repository, or ask for the repo path if it is unclear.

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

Before drafting any direction, the main agent must read the complete original text of:

- [`references/direction-brief.md`](references/direction-brief.md), which defines the seven required brief elements, the token summary format, and the conditions that make all three briefs unqualified and require a rewrite.
- When the product matches a domain pack, the main agent must read the complete original text of every content file in that domain pack folder before drafting any brief:
  - `shared-judgments.md` for judgments shared across all three candidates;
  - all three files under `directions/`, one source for each candidate;
  - `orthogonality-check.md` for the main agent's cross-direction comparison and pairwise rejection check.
  Use the reusable folder contract in [`references/domain-packs/README.md`](references/domain-packs/README.md). The main agent uses the complete pack to draft the three briefs and must apply the main-agent-only check to verify that the resulting set is genuinely orthogonal.
- [`references/anti-slop.md`](references/anti-slop.md), which identifies default AI-design traps and requires the three directions to rotate across different design logics.

Do not create worktrees or dispatch builders until this reading and brief-writing gate is complete. The main agent owns the one-time arena-level judgment that the three directions are sufficiently orthogonal.

Prepare a concise "Arena Brief" for user confirmation:

- Product snapshot: what the product does, who uses it, and which screens matter most.
- Technical snapshot: framework, install command, dev command, build/test commands, likely preview ports, required environment variables, local services or mock backends, and any setup, codegen, or build-before-dev steps.
- Three style directions: Style A, Style B, Style C.
- Draft each direction with all seven elements and the token summary required by `references/direction-brief.md`, calibrated by the matching domain pack and differentiated through the design-logic rotation in `references/anti-slop.md`.
- Apply the rewrite criteria in `references/direction-brief.md` to the three briefs as a set. If they fail, rewrite them before asking for user confirmation.

## Stage 1.5: Generate And Show Three `DESIGN_BRIEF.md` Drafts

Before asking the user to confirm the directions, the main agent must generate three complete Markdown artifacts, each named `DESIGN_BRIEF.md` and labeled clearly in the presentation as Style A, Style B, or Style C. At this stage they may be held by the main agent as drafts, but they are the exact candidate files that will be materialized in the three worktrees after approval.

Every `DESIGN_BRIEF.md` must contain:

- The completed seven required brief elements from `references/direction-brief.md` for that style.
- The required token summary and replaceability test so the artifact is implementation-ready rather than only a concept note.
- The product and technical constraints that the assigned builder must preserve.
- When a domain pack matches, a dedicated `Domain Direction Source — Complete Verbatim Copy` section containing the entire original text of that style's matching source file under `directions/`.

For the domain direction source, copy the whole file exactly. Preserve every heading, paragraph, list item, warning, and boundary note in its original order. Do not excerpt selected sentences, summarize it, paraphrase it, compress it, or replace it with a link. The copied block must be complete enough to compare line-for-line with the source file. Style A receives only the complete A source, Style B only the complete B source, and Style C only the complete C source.

If no domain pack matches, all three `DESIGN_BRIEF.md` files must still exist and contain at least the completed seven brief elements, token summary, replaceability test, and product constraints.

Use the shared judgments while drafting and use the main-agent-only comparison file to test the three drafts as a set. If the three files fail the orthogonality or rewrite criteria, revise them before presentation.

Present the full contents of all three `DESIGN_BRIEF.md` drafts to the user before asking for confirmation. A summary, abbreviated preview, diff, or table is not a substitute for showing the three complete files. After any requested revision, show the full current contents of all three files again before asking for final confirmation.

Ask the user to confirm, replace, or adjust the three complete files. Do not create worktrees or enter Stage 2 until the user explicitly confirms them. Preserve the exact approved contents for Stage 2; do not silently regenerate or rewrite them after approval.

## Stage 2: Create Three Worktrees From One Common Ancestor

After confirmation, record the common starting point:

```bash
BASE_BRANCH=$(git branch --show-current)
BASE_SHA=$(git rev-parse HEAD)
```

PowerShell equivalent:

```powershell
$baseBranch = git branch --show-current
$baseSha = git rev-parse HEAD
```

Choose branch and worktree names. Default branches:

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

Only after the user confirms, add the rule:

```bash
touch .gitignore
grep -qxF ".worktrees/" .gitignore || printf '%s\n' ".worktrees/" >> .gitignore
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
```

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

For each worktree, verify that `DESIGN_BRIEF.md` is tracked, the brief commit exists on the expected branch, and the worktree is clean before dispatch. If writing, verification, or commit fails for any style, stop and repair that style's branch before dispatching builders; do not let one builder begin without its committed brief.

Use one common ancestor because:

- The user compares three redesigns of the same product version.
- The only intended differences are the style implementations.
- Git can compute a clean diff from the selected branch back to the main line.
- Linked worktrees share the same repository object database while keeping separate working directories, indexes, and per-worktree `HEAD`s.
- Independent repository copies would hide ancestry, waste space, and make merge cleanup less reliable.

## Stage 3: Dispatch Parallel Builders

Use sub-agents or dispatch when available. Give each builder only its own worktree path. Its approved, committed style brief is the `DESIGN_BRIEF.md` file at that worktree's root.

Each builder works in one isolated worktree:

- Style A builder works only in `.worktrees/style-a` on branch `style-a`, unless the user confirmed a different Stage 2 fallback path.
- Style B builder works only in `.worktrees/style-b` on branch `style-b`, unless the user confirmed a different Stage 2 fallback path.
- Style C builder works only in `.worktrees/style-c` on branch `style-c`, unless the user confirmed a different Stage 2 fallback path.

Isolation works because every linked worktree has its own working directory, index, and checked-out branch `HEAD`. The builders share Git history but do not write to the same files on disk.

For each builder, the dispatch must provide:

- The exact assigned worktree path and branch.
- The product snapshot and technical snapshot.
- An explicit instruction to read the complete `DESIGN_BRIEF.md` at the assigned worktree root before implementing. This file always exists and contains at least the approved seven brief elements; when domain calibration applies, it also contains that style's complete verbatim direction source already embedded by the main agent.
- When a domain pack matches, the exact path to `references/domain-packs/<domain-pack>/shared-judgments.md` and an instruction to read it completely.
- The screens and flows to prioritize.
- The exact paths to the four universal references—[`references/anti-slop.md`](references/anti-slop.md), [`references/visual-quality-bar.md`](references/visual-quality-bar.md), [`references/interaction-quality-bar.md`](references/interaction-quality-bar.md), and [`references/arena-scorecard.md`](references/arena-scorecard.md)—and an instruction to read their complete original text before implementing. The main agent must not paraphrase, condense, or substitute excerpts for these files in the dispatch prompt.
- A requirement to use `references/anti-slop.md` within the approved brief, while leaving the one-time judgment about whether all three candidates are orthogonal to the main agent's completed Stage 1 work.
- A requirement to self-check the finished implementation against `references/visual-quality-bar.md` and `references/interaction-quality-bar.md`, verify that the approved brief's signature element and anti-default are present in the code, then report pass/fail against every applicable gate in `references/arena-scorecard.md`.
- The allowed scope: frontend redesign only; if any change outside that scope is needed, report it to the main agent, and have the main agent stop and ask the user to confirm before continuing.
- The expected validation commands.
- The requirement to preserve functionality and avoid unrelated refactors.

Do not include any other domain-pack path in a builder dispatch, and do not ask a builder to discover or browse the domain-pack directory. The builder uses the assigned `DESIGN_BRIEF.md` as its only style-specific source.

Each builder should:

1. Inspect the local worktree.
2. Verify that root-level `DESIGN_BRIEF.md` exists, is tracked, and has already been committed on the assigned branch. If it is missing, untracked, or uncommitted, stop and report the boundary failure to the main agent instead of implementing from a prompt summary.
3. Read the complete `DESIGN_BRIEF.md`, all four universal references, and `shared-judgments.md` when that extra path was supplied.
4. Run the project's install command from the Stage 1 technical snapshot inside this worktree before making changes. Report installation failures to the main agent; the main agent must stop and ask the user whether to retry, fix the environment, skip this style, or cancel. On Windows, if the failure is `spawn EPERM` from Node, Vite, esbuild, or Vitest, treat it as a likely sandbox or OS execution-permission issue and retry the same command with escalation before treating the product code as broken.
5. Implement the complete approved style direction.
6. Run the relevant lint, typecheck, test, or build commands available in the project. Apply the same `spawn EPERM` retry rule to validation commands.
7. Perform the required reference-based self-check: inspect the implementation against the visual and interaction quality bars, confirm the brief's signature element and anti-default in code, and record the scorecard's pass/fail results.
8. Summarize changed files, visual decisions, validation results, risks, and the self-check results for the main agent. If browser preview was intentionally deferred to the main agent, say that explicitly instead of presenting it as an implementation failure.
9. Commit the branch when its version is ready:

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

If sub-agent or dispatch tooling is unavailable, execute the three branches sequentially while preserving the same worktree isolation and tell the user that parallel dispatch was unavailable.

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

If HTTP probing still gets no response after the retry loop, treat that style's preview as failed to start. Report the failure, including the URL, port, command, process ID or session ID, and log paths, instead of assuming the preview succeeded.

Only stop preview servers that the main agent started and recorded. Do not kill unrelated processes just because they use a similar port.

## Stage 4.5: Aggregate Self-Checks And Run Lightweight Spot Checks

Before asking the user to choose, the main agent must aggregate all three builders' scorecard pass/fail self-assessments and run lightweight spot checks rather than repeating every reference check from scratch. At minimum, sample responsive behavior in a narrowed viewport, tab through key controls, and toggle `prefers-reduced-motion` in browser developer tools.

If an observed result conflicts with a builder's self-assessment, report the discrepancy explicitly alongside that builder's original conclusion; do not silently overwrite it. Present all three alternatives to the user regardless of pass/fail status. [`references/arena-scorecard.md`](references/arena-scorecard.md) is only a pass/fail eligibility aid: it does not score, rank, filter, or make the aesthetic choice. The user retains the complete aesthetic judgment.

Give the user a comparison table:

- Style letter and name.
- Branch.
- Preview URL.
- Commit hash.
- Validation commands and results.
- Builder scorecard self-assessment and any discrepancy found in the main agent's spot checks.
- Main visual thesis.
- Known risks.

## Stage 5: User Selection

Ask the user to choose one complete alternative.

If the user wants more viewing time, allow preview servers and worktrees to remain temporarily. Make clear that final merge and cleanup have not happened yet.

If the user asks for revisions before choosing, revise the relevant whole branch or branches. Do not combine elements across branches.

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

After conflicts are resolved, run the relevant lint, build, test, or typecheck commands again. Then show the key final merge result with `git diff` or an equivalent focused diff before completing the merge commit, and ask the user to confirm that the resolved result matches the selected design direction and preserves the necessary main-branch changes.

Do not use cherry-pick for the selected design. The selected branch represents a complete version, not a collection of pieces.

## Stage 8: Clean Up Worktrees And Branches

Cleanup happens after the selected branch is merged and preview servers are stopped.

First inspect each worktree:

```bash
git -C <worktree-path> status --short --ignored
```

PowerShell equivalent:

```powershell
git -C <worktree-path> status --short --ignored
```

For the selected branch:

- Ensure it was merged into the main branch.
- Remove its worktree.
- Delete its branch with safe delete.

For unselected branches:

- Stop before running `git worktree remove` or `git branch -D` on any unselected branch. Show the user each unselected branch name, its commit hash, and the worktree path that would be removed. Ask whether these unselected versions can be discarded.
- Do not remove unselected worktrees or force-delete unselected branches unless the user explicitly replies that they can be discarded. A final report after deletion is not enough.
- If the user does not explicitly confirm discard, do not continue with deletion automatically.
- After explicit discard confirmation, remove their worktrees.
- Delete their branches with force delete only after discard is confirmed.

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

After worktrees are removed, delete branches using the actual branch names confirmed in Stage 2:

```bash
git branch -d <selected-branch>
git branch -D <unselected-branch-1>
git branch -D <unselected-branch-2>
```

PowerShell equivalent:

```powershell
git branch -d <selected-branch>
git branch -D <unselected-branch-1>
git branch -D <unselected-branch-2>
```

Use `-d` for the selected branch because it should already be merged. If `git branch -d <selected-branch>` fails, stop, show why the safe-delete check failed, and ask the user whether to keep or delete the branch. Use `-D` for unselected branches only after the user confirms they should be discarded.

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
- Merge method used: fast-forward or merge commit.
- Validation commands run after merge.
- Worktrees removed.
- Branches deleted.
- Any preview servers still running, if the user explicitly asked to keep them.
- Any remaining risks or manual checks.
