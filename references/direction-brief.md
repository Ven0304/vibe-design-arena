# Direction Brief Standard

Use this file in Stage 1, before any worktree is created. A direction brief is a design contract, not a mood-board caption. It must tell a builder what to emphasize, what to reject, and what observable result would prove the direction was implemented.

## Contents

- [Drafting rule](#drafting-rule)
- [The seven required elements](#the-seven-required-elements)
- [Token summary](#token-summary)
- [Two-sided replaceability test](#two-sided-replaceability-test)
- [Three-brief set gate](#three-brief-set-gate)
- [Ready-to-use template](#ready-to-use-template)

## Drafting Rule

Write all three briefs from the same product snapshot and technical snapshot. Use the matching domain pack to ground product-specific choices, then use `anti-slop.md` to force the three briefs into different design logics.

Do not start from style labels such as `brutalist`, `glassmorphism`, `editorial`, or `minimal`. A label may describe the result after the thesis is written, but it cannot substitute for the thesis.

A brief is ready only when another agent can answer all of these questions without guessing:

- What must the user notice or accomplish first?
- Why does this visual system fit this subject and audience?
- What single element should make the version memorable?
- What deliberate risk is being taken, and what limit keeps it usable?
- Which likely default solution is explicitly rejected?
- How is the first screen spatially organized?
- How will this version look or behave differently from the other two?

## The Seven Required Elements

### 1. Subject, Audience, and Single Job

State all three in concrete terms.

- **Subject:** Name the actual material or object being designed around, not only the product category. Include the content shape that matters: live quotes, research chapters, transaction records, portfolios, media, or another domain object.
- **Audience:** Name the user's level of expertise, working context, and time pressure. “Professionals” is too broad; “analysts comparing six companies during a 20-minute review” is actionable.
- **Single job:** Write one primary outcome for the target screen. Use a verb such as monitor, compare, explain, decide, configure, or publish. Do not join several equal jobs with “and.”

Reject the brief if the single job could describe every route in the product or if the proposed first screen gives equal visual weight to multiple jobs.

### 2. Aesthetic Thesis

Write one or two sentences that connect a visual proposition to evidence from the product, audience, content, or domain pack.

A thesis must include:

1. the intended visual or reading behavior;
2. the product reason for that behavior;
3. the system-level consequence for typography, density, or spatial organization.

Weak: “A premium, modern editorial experience with bold typography.”

Usable: “Treat each investment conclusion as the head of an evidence chain: a narrow reading column establishes authority, while charts and comparison tables break the measure only when the argument needs more width. Serif display type carries judgment; sans UI and tabular numerals keep operations and evidence fast to scan.”

Reject the thesis if it is only a cluster of adjectives, if its evidence is “it looks better,” or if the same sentence could justify all three directions.

### 3. Signature Element

Choose one memorable element that concentrates the direction's boldness. It must encode content or behavior, not sit on top of the product as decoration.

Examples of valid signatures include a conclusion-to-evidence spine, an anomaly rail that persists across dense views, or a source-aware margin annotation system. “Gradient hero,” “large type,” and “glass cards” are not signatures unless the product meaning makes them necessary.

Define:

- where the element appears;
- what information or action it carries;
- how it repeats without becoming noise;
- what implementation evidence would prove it exists.

Reject the brief if it names several competing signature moments, or if the signature could be removed without changing the reading order or interaction model.

### 4. One Justified Risk

Take one deliberate risk that strengthens the thesis: unusually high information density, a narrow authorial reading column, persistent split-view context, a strong typographic contrast, or another bounded departure from the safe default.

State:

- the benefit the risk creates;
- the failure mode it could introduce;
- the boundary or mitigation that keeps the risk usable.

Reject “use bold colors” or “add more motion” as risks. They describe treatments, not trade-offs. Reject a risk with no stated downside; it is probably promotional language rather than a real design decision.

### 5. Anti-Default Declaration

Name the most tempting default solution for this assignment, explain why it would weaken this direction, and name the replacement decision.

Use this form:

```text
[ANTI-DEFAULT] Reject <specific default pattern> because <product-specific harm>.
Replace it with <observable structural or behavioral choice>.
```

“Avoid generic design” is not acceptable. The rejected default must be visible or testable, such as “a KPI card grid,” “every section in a rounded card,” “all content centered,” or “scroll-revealed paragraphs.”

### 6. ASCII Wireframe

Draw the first screen and at least one important continuation state. Show hierarchy, relative width, persistent chrome, breakout regions, and the location of the signature element. Do not draw a generic sequence of identical boxes.

Minimum notation:

```text
┌──────────────────────────────────────────────────────────────┐
│ persistent navigation / context                              │
├───────────────┬───────────────────────────────┬──────────────┤
│ secondary     │ primary job                   │ evidence or  │
│ navigation    │ [SIGNATURE]                   │ context      │
│               │                               │              │
├───────────────┴───────────────────────────────┴──────────────┤
│ continuation: dense evidence, detail, or next action         │
└──────────────────────────────────────────────────────────────┘
```

Annotate where density changes and how the composition changes on a narrow viewport. Reject a wireframe that could be reused unchanged for the other two directions.

### 7. At Least Three Observable Differences

Compare the brief with both other versions. Declare at least three differences chosen from these axes:

- **First-screen composition:** what dominates, what is persistent, and what is deferred.
- **Typographic hierarchy:** which role carries identity, how conclusions differ from evidence, and how numbers behave.
- **Spatial organization:** article flow, panels, split view, stable chrome, breakout modules, or another layout grammar.
- **Motion behavior:** which transitions exist, which are intentionally absent, and how spatial continuity is expressed.

Each difference must be observable in screenshots or interaction. “A feels warmer while B feels sharper” is not enough. “A opens with a single conclusion column; B opens with a three-panel signal grid” is testable.

## Token Summary

Tokens are pre-code commitments. Name roles and intended use; do not dump an arbitrary palette or a list of CSS values.

### Required Format

```yaml
color:
  canvas: "#...... — page field"
  surface: "#...... — elevated or grouped region"
  ink: "#...... — primary text and key values"
  muted: "#...... — metadata and secondary evidence"
  accent: "#...... — interaction/current selection only"
  signal: "#...... — one domain-specific emphasis, if needed"

type:
  display: "family/fallback — role, weights, intended sizes"
  body: "family/fallback — reading or UI role, weights"
  data: "optional family or numeric feature — exact use"
  scale: "named levels only, for example display/page/section/body/meta"

layout:
  concept: "one sentence describing the layout grammar"
  wireframe: "reference the ASCII wireframe above"
  density: "where the interface is compact and where it breathes"

spacing:
  scale: "name a limited progression, for example space-1/2/3/4/6/8"
  rule: "state how the scale distinguishes within-group from between-group spacing"

radius:
  scale: "name the active radii, for example radius-0/sm/md/pill"
  rule: "state which component types may use each radius"

motion:
  duration: "name roles such as instant/fast/panel rather than scattered milliseconds"
  easing: "name enter/exit/move curves"
  distance: "name the maximum translation roles, if movement is justified"
```

Use four to six semantic colors in the brief. A domain may later require fuller ramps, but the brief must first make each color's responsibility unambiguous. At least display and body type roles are required; add data/utility only when the content needs it.

Reject the token summary if:

- names describe appearance instead of responsibility (`purple-1`, `nice-gray`);
- the accent is responsible for brand, links, positive values, focus, and selection at once;
- spacing, radius, or motion values appear without names or usage rules;
- the layout concept does not match the ASCII wireframe;
- token choices do not reinforce the aesthetic thesis.

## Two-Sided Replaceability Test

Run both sides of this test.

1. **Identity without the label:** Remove or replace the product name in the mock content. The structure should still communicate the subject, audience, and single job. If the design loses its identity as soon as the logo or name disappears, the underlying choices are not strong enough.
2. **Resistance to generic transplant:** Replace the subject with a different product that has another task or content model. If the same composition, signature, and tokens still work unchanged, the direction is probably a generic template. Re-ground at least one major choice in the actual product.

A strong brief survives removal of the brand label but does not transplant unchanged into an unrelated product.

## Three-Brief Set Gate

Judge the three briefs as a set before showing them to the user.

Rewrite the set if any condition is true:

- The briefs differ mainly in color, font family, radius, shadow, or light versus dark mode.
- Two briefs share the same first-screen composition and merely rename the visual mood.
- All three use the same card grid, navigation model, density rhythm, or interaction behavior.
- Their aesthetic theses rely on the same product evidence.
- The signature elements are decorative variations rather than different content or interaction ideas.
- Fewer than three observable differences can be stated for any pair.
- The anti-default declarations reject different surface details but preserve the same underlying design logic.

Do not “fix” a failed set by inventing more adjectives. Rewrite the single job, thesis, signature, layout grammar, or design logic until the versions are structurally different.

## Ready-to-Use Template

```markdown
## Style <A/B/C>: <direction name>

[AESTHETIC] <one- or two-sentence thesis with product evidence>
[SIGNATURE] <one memorable content-bearing element and where it appears>
[ANTI-DEFAULT] <specific default rejected, harm, and replacement>

### 1. Subject / Audience / Single Job
- Subject:
- Audience:
- Single job:

### 2. Aesthetic Thesis
<thesis, evidence, and system consequence>

### 3. Signature Element
<information/action, location, repetition rule, implementation evidence>

### 4. One Justified Risk
- Benefit:
- Failure mode:
- Boundary or mitigation:

### 5. Anti-Default Declaration
<specific rejection and replacement>

### 6. ASCII Wireframe
<first screen and continuation state, including narrow-screen note>

### 7. Observable Differences
- Versus Style <X>:
- Versus Style <Y>:
- Difference axes used:

### Token Summary
<color, type, layout, spacing, radius, motion>

### Replaceability Test
- Identity without label:
- Resistance to generic transplant:
```
