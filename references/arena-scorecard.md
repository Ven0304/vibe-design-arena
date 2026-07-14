# Arena Qualification Gate

## Single Responsibility

This file answers one question only: **is this implementation qualified to enter the user's selection view as a complete candidate?**

It does not answer which direction is better. Do not assign points, weights, percentages, stars, letter grades, or ranks. Do not average failures into a total. Aesthetic judgment belongs entirely to the user after all three complete alternatives are shown.

Evaluate each item as `PASS` or `FAIL`. If a state or requirement truly cannot occur in the product, mark it `PASS` only after recording the product reason; do not create a third score category.

## Candidate Record

```text
Style:
Branch:
Commit:
Preview URL:
Builder self-check date:
Validation commands:
```

## Brief Consistency

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
BRIEF CONSISTENCY: PASS / FAIL
VISUAL BASELINE: PASS / FAIL
INTERACTION BASELINE: PASS / FAIL
OVERALL QUALIFICATION: PASS / FAIL

Failed item IDs:
Evidence or route for each failure:
Fix attempted:
Remaining discrepancy observed by main agent:
```

`OVERALL QUALIFICATION` is `PASS` only when every applicable item passes. One failed item makes the overall result `FAIL`; there is no score to carry forward and no stronger category that can compensate for it.

## Failure Handling and Stage 5 Display

Return every failed item to the builder for correction and re-evaluate that item after the fix. Do not hide the failure inside a summary or silently change the builder's original self-assessment.

If an item still fails when the user comparison is presented:

- show the candidate in full with its preview, branch, commit, and visual thesis;
- show the builder's original result and the main agent's observed discrepancy;
- label the exact failed item IDs;
- do not convert the result into a number or ranking;
- do not filter the candidate out of the user's options.

All three alternatives are shown regardless of qualification status. The gate supplies reliability context; the user still makes the complete aesthetic choice.
