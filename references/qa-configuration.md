# Declarative Browser QA

Use this file to author a candidate QA configuration and run `scripts/arena-qa.mjs`. The runner is intentionally declarative: configuration selects from fixed operations and assertions and cannot execute arbitrary JavaScript or shell strings.

## Dependency Boundary

The Skill and three-worktree design flow can load and build without Playwright. Automated qualification cannot pass without the QA runtime.

The runner needs:

- a compatible `playwright` or `playwright-core` package;
- `axe-core`;
- a compatible Chromium runtime or an approved existing Chrome/Chromium executable.

Do not install any of these automatically. Check the existing project, workspace, and approved tool roots first. If missing, report the exact need and ask the user to choose installation scope.

Optional environment overrides:

```text
ARENA_QA_NODE_MODULES=<approved directory containing node_modules/package.json>
ARENA_QA_BROWSER_EXECUTABLE=<approved Chrome or Chromium executable>
```

Missing dependencies or browser launch failure produces `overall=BLOCKED` and `environmentBlocked=true`. This is neither PASS nor an application failure.

## Authoritative Files

- Config schema: `scripts/schemas/qa-config.schema.json`
- Result schema: `scripts/schemas/qa-result.schema.json`
- Runner: `scripts/arena-qa.mjs`
- Complete fixture: `scripts/fixtures/chapter-scrollspy-qa-config.json`
- Rendered fixture page: `scripts/fixtures/chapter-scrollspy-upward.html`

Validate a configuration without opening a browser:

```powershell
node scripts/arena-qa.mjs --validate-config <qa-config.json>
```

## Required Viewports

Every config declares these exact standard viewports:

| ID | Width | Height |
| --- | ---: | ---: |
| `mobile` | 320 | 800 |
| `tablet` | 834 | 1112 |
| `desktop` | 1440 | 1000 |

The `equivalent-200-percent-layout` scenario derives a `720x1000` CSS viewport from desktop and keeps `deviceScaleFactor=1`. It is an automated layout proxy, not real Chrome UI zoom.

## Applicability

Every scenario declares exactly one status:

- `required`: universal gate; it must run.
- `applicable`: product state exists; it must run.
- `not-applicable`: the state truly cannot occur in this product.

A not-applicable scenario must contain:

```json
{
  "id": "stale-data",
  "applicability": "not-applicable",
  "reason": "The product reads only immutable local documents and has no freshness state.",
  "approvedBy": "main-agent:<id>",
  "evidenceIds": ["contract.immutable-local-data"],
  "actions": [],
  "assertions": []
}
```

Declare the referenced evidence under `evidenceDefinitions`. Do not infer N/A from a missing selector or route.

## Required Scenario Declarations

Universal hard gates must be `required`:

- `primary`
- `dense`
- `touch-targets`
- `keyboard-traversal`
- `focus-visibility`
- `focus-return`
- `reduced-motion`
- `rapid-toggle`
- `equivalent-200-percent-layout`

Product states must be either executed (`required` or `applicable`) or explicitly approved N/A:

- `loading`
- `empty`
- `error`
- `disabled`
- `stale-data`
- `long-text`
- `missing-value`
- `negative-number`
- `extreme-number`
- `container-overflow`

The validator also enforces key behavior contracts: touch targets include a `44x44` bounding-box assertion; keyboard traversal uses keyboard actions and a focus assertion; focus visibility requires a visible indicator; reduced motion emulates `reduce`; rapid toggle repeats clicks; and applicable container overflow inspects a declared local container.

## Whitelisted Actions

Only these action types are accepted:

- `navigate`
- `click`
- `keyboard`
- `fill`
- `select`
- `wait`
- `viewport`
- `reduced-motion`
- `screenshot`
- `scroll`

Unknown fields and unknown action types fail config validation. There is no JavaScript, eval, PowerShell, or shell action.

## Whitelisted Assertions

Only these assertion types are accepted:

- `url`
- `hash`
- `attribute`
- `text`
- `visibility`
- `count`
- `focus`
- `bounding-box`
- `overflow`
- `aria-current`

Every executed scenario also receives runner-owned page-level horizontal-overflow, axe WCAG A/AA, browser-console/page-error, final-screenshot, and evidence checks.

## Evidence Identity

The run command binds the result to:

- Arena ID;
- style (`style-a`, `style-b`, or `style-c`);
- candidate generation;
- full current candidate commit;
- config SHA-256;
- base URL;
- registered output/evidence root.

Example:

```powershell
node scripts/arena-qa.mjs `
  --config <qa-config.json> `
  --output <ARENA_RUN_ROOT\evidence\style-a> `
  --arena-id <arena-id> `
  --style style-a `
  --candidate-generation <generation> `
  --candidate-commit <full-commit> `
  --base-url http://127.0.0.1:5173/
```

Artifacts:

```text
qa-results.json
qa-summary.md
browser-errors.jsonl
screenshots/*.png
```

The runner writes artifacts only. Import with `arena.ps1 import-qa-result`; never copy fields into `arena-state.json` manually.

## PASS Contract

A passing imported result must provide exactly one required PASS for every universal scenario at every standard viewport, plus the single proxy viewport check. Each product state must provide either one valid N/A declaration or one executed PASS per standard viewport, never both.

Every executed PASS check must cite screenshot and axe evidence and contain passing overflow, axe, and browser-error assertions. Screenshot paths must remain inside the registered candidate evidence root. Duplicate check or evidence IDs are rejected.

Automated PASS sets only `automatedQa=PASS`. The main agent must still inspect screenshots, sign visual review, sign direction review, and run qualification.

## Scrollspy Regression Fixture

The fixture specifically proves upward navigation behavior: after scrolling down and clicking an earlier chapter, the earlier section aligns near the viewport top and exactly one navigation item has `aria-current`. Run it with approved Playwright and browser paths:

```powershell
$env:ARENA_QA_NODE_MODULES = '<approved dependency root>'
$env:ARENA_QA_BROWSER_EXECUTABLE = '<approved browser executable>'
node scripts/tests/arena-qa-scrollspy.mjs
```

The successful test removes its temporary evidence. A failed test preserves evidence and prints its path for diagnosis.
