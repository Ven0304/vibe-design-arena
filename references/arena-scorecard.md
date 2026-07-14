# Arena Qualification Gate

## Single Responsibility

This file answers one question only: **is this implementation qualified to enter the user's selection view as a complete candidate?**

It does not answer which direction is better. Do not assign points, weights, percentages, stars, letter grades, or ranks. Do not average failures into a total. Aesthetic judgment belongs entirely to the user after all three complete alternatives are shown.

Evaluate each item as `PASS` or `FAIL`. If a state or requirement truly cannot occur in the product, mark it `PASS` only after recording the product reason; do not create a third score category.

The builder produces a preliminary self-check. The main agent is the final qualification and evidence owner in Stage 4.5. Missing rendered evidence is `FAIL`, and a candidate with any failed item is not qualified to enter Stage 5.

## Candidate Record

```text
Style:
Branch:
Implementation commit:
Brief commit:
Brief SHA-256:
Arena ID:
Absolute ARENA_RUN_ROOT:
Candidate Record path:
Approval registry path:
Reference snapshot ID:
Absolute SKILL_ROOT:
Skill commit or hashed provenance:
Reference manifest: absolute path and SHA-256 for each supplied reference
Preview URL:
Evidence bundle:
Builder preliminary self-check date:
Main-agent final review date:
Validation commands:
Retest history:
```

The builder returns its preliminary record to the main agent without receiving `ARENA_RUN_ROOT`. The main agent saves the completed record at `$ARENA_RUN_ROOT/candidates/style-<a/b/c>-record.md` and stores rendered evidence under the matching `$ARENA_RUN_ROOT/evidence/style-<a/b/c>/` directory. Do not rely on chat history as the only copy of the preliminary scorecard, final qualification, validation results, or retest history.

Before any scorecard read or final qualification, recompute each supplied reference hash and compare it with the frozen manifest. A missing path, changed path, changed hash, or changed snapshot ID is `FAIL`; do not silently qualify against a newer Skill version.

The evidence bundle must identify the route and viewport for each capture and contain the required state screenshots, keyboard and focus results, reduced-motion result, failed items, fixes, and retest results. A preview URL without this evidence is insufficient; a static bundle must come from an actual rendered run.

## Brief Consistency

- [ ] **B0 — Approved brief integrity passes.** `DESIGN_BRIEF.md` matches both the recorded brief commit and approved whole-file SHA-256. The user-approved seven elements remain the normative contract; the embedded domain direction remains calibration material.
- [ ] **B1 — Aesthetic thesis is implemented.** The rendered hierarchy, density, and layout grammar reflect the assigned thesis; it is not merely repeated in documentation.
- [ ] **B2 — Signature element exists in code.** The declared signature is visible in its promised route/state, carries real content or behavior, and is not replaced by a decorative approximation.
- [ ] **B3 — Anti-default is implemented.** The rejected default is absent, and the promised structural or behavioral replacement is present.
- [ ] **B4 — Assigned direction remains coherent.** Implementation has not drifted into a generic card grid, unrelated component-library default, or another Arena direction.
- [ ] **B5 — Core functionality is preserved.** Priority screens and flows work without unrelated product regressions.

## Visual Baseline

Use `visual-quality-bar.md` as the source of truth. Do not restate or reinterpret its numeric thresholds here.

- [ ] **V1 — Typography hierarchy passes.** Every applicable item under “Typography Hierarchy” passes with rendered evidence.
- [ ] **V2 — Color and contrast pass.** Every applicable item under “Color and Contrast” passes, including non-color status cues and WCAG AA.
- [ ] **V3 — Spacing, alignment, and grouping pass.** Every applicable item in that section passes; chrome is not masking weak hierarchy.
- [ ] **V4 — Responsive baseline passes.** The required narrow, medium, and wide views pass, with no page-level horizontal overflow and a deliberate content-priority strategy.
- [ ] **V5 — Accessibility baseline passes.** Keyboard reachability, visible focus, semantics, accessible names, and zoom behavior pass.
- [ ] **V6 — State completeness passes.** Loading, empty/no-data, error, disabled, stale-data, and control states are implemented wherever the product can produce them.
- [ ] **V7 — Screenshot evidence exists.** The required viewport, state, focus, and edge-content captures were actually inspected; source-code inference is not accepted.

## Interaction Baseline

Use `interaction-quality-bar.md` as the source of truth. Do not duplicate its duration table or easing rules here.

- [ ] **I1 — Every motion has an allowed purpose.** Feedback, spatial continuity, state explanation, or avoidance of abrupt change is documented and visible.
- [ ] **I2 — Duration and frequency pass.** High-frequency actions remain fast, named duration roles are used, and exits do not linger.
- [ ] **I3 — Properties and easing pass.** No `transition: all`; origins, easing, interruption, focus return, and layout stability behave correctly.
- [ ] **I4 — Prohibited defaults are absent.** No unjustified bounce, count-up, staged scroll reveal, autoplay, ambient looping, scroll hijack, or equivalent distraction remains.
- [ ] **I5 — Data and content behavior pass.** First frames are readable, comparable states remain spatially stable, and reading is not delayed by motion.
- [ ] **I6 — Reduced motion passes.** Harmful movement is removed while essential focus, status, validation, loading, and open/closed feedback remain.
- [ ] **I7 — Interaction acceptance was performed.** Mouse, keyboard, touch-sized viewport, rapid toggling, slow-motion inspection, reduced motion, and performance-sensitive paths were tested as applicable.

## Qualification Result

```text
BRIEF INTEGRITY: PASS / FAIL
BRIEF CONSISTENCY: PASS / FAIL
VISUAL BASELINE: PASS / FAIL
INTERACTION BASELINE: PASS / FAIL
OVERALL QUALIFICATION: PASS / FAIL

Failed item IDs:
Evidence-bundle location and route for each failure:
Fix attempted:
Retest result:
Remaining discrepancy observed by main agent:
```

`OVERALL QUALIFICATION` is `PASS` only when every applicable item passes. One failed item makes the overall result `FAIL`; there is no score to carry forward and no stronger category that can compensate for it.

## Failure Handling and Stage 5 Gate

Return every failed item and its evidence to the same builder or a replacement builder for correction. After each fix, re-run validation, brief-integrity checks, preview or evidence capture, and the affected scorecard items. Preserve the builder's preliminary result and record the main agent's retest separately.

If an item still fails, do not present the user-selection comparison. The available outcomes are to fix the environment and retry, assign a replacement builder and retry that style, or cancel the entire Arena. Do not skip, hide, or remove a candidate to reach Stage 5.

All three alternatives enter Stage 5 only after all three have complete evidence bundles and `OVERALL QUALIFICATION: PASS`. The gate establishes eligibility only; after qualification, the user retains the complete aesthetic choice without scores or rankings.
