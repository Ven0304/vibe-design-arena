# Anti-Slop: Default Pattern Challenge

Use this file while drafting all three directions and again within each builder's assigned direction. Its purpose is to expose automatic visual habits before they harden into code.
## Contents

- [Operating principle](#operating-principle)
- [Current default pattern list](#current-default-pattern-list)
- [Three-version design-logic rotation](#three-version-design-logic-rotation)
- [Required three-line record](#required-three-line-record)
- [Brief critique procedure](#brief-critique-procedure)


## Operating Principle

This list is time-sensitive. A pattern can become overused, recover, or gain a new meaning as tools and trends change. Treat nothing here as a permanent ban.

Apply one rule: **a default pattern needs evidence from the subject, audience, content, or single job. If the brief cannot supply that evidence, replace the pattern.** “It looks modern,” “it feels premium,” and “the model chose it” are not evidence.

A justified use must answer:

- What product meaning does the pattern encode?
- What user task becomes clearer or faster because of it?
- Why is this pattern stronger than a quieter structural choice?
- What limit prevents it from spreading across the whole interface?

## Current Default Pattern List

Use the categories below as a challenge list, not a style blacklist. If a draft uses one, write the justification next to it. If no justification survives critique, replace it before worktree creation.

### Color Defaults

- **Purple-to-blue gradient as universal technology signal.** Reject it when no product state, depth, or brand system requires the gradient. A single calibrated accent on a neutral hierarchy is usually more legible.
- **Near-black canvas with acid green, violet, or cyan highlights.** Reject “dark equals expert tool” logic unless the audience, viewing environment, and density model support it. Dark mode must still define several readable luminance steps.
- **Cream canvas, high-contrast serif, and terracotta accent as instant editorial authority.** Reject it when the content is not an authored reading experience or when the palette merely imitates current portfolio aesthetics.
- **Newspaper beige or salmon surface used as a Financial Times shortcut.** Borrow editorial hierarchy, chart grammar, and reading rhythm instead of cloning a recognizable brand skin.
- **Rainbow category colors with unmatched visual weight.** Reject palettes where yellow, blue, and red at the same semantic level do not have comparable perceived lightness and saturation.
- **Red and green as the only positive/negative distinction.** Add sign, label, arrow, line style, or position so meaning survives color-vision differences and grayscale capture.

### Composition Defaults

- **Eyebrow + oversized headline + supporting sentence + three metrics + gradient CTA hero.** Reject this landing-page formula when the screen's real job is monitoring, comparing, explaining, or operating data.
- **Everything centered.** Reject centered navigation, headings, metrics, and body copy when the content requires scanning, comparison, or a strong reading edge.
- **Equal columns, equal spacing, equal emphasis.** Reject symmetrical balance when product priorities are unequal. Let the primary job own more width, contrast, or persistence.
- **Universal card grid or bento grid.** Reject it when content forms an argument, a table, a continuous workflow, or a stable hierarchy. Independent modules may use cards; continuous meaning should remain continuous.
- **Dashboard as four KPI cards above a generic chart grid.** Reject it unless those KPIs are truly the first decision surface and the charts answer distinct questions.
- **Marketing-page section rhythm applied to an application.** Repeating full-width bands with identical padding is not a substitute for stable navigation, progressive disclosure, or task-oriented views.

### Component Defaults

- **Every section inside a rounded card.** Use grouping, alignment, spacing, keylines, or surface luminance first. A card should represent an independent object or action boundary.
- **Pill overload.** Reserve pills for compact states, filters, or removable selections. Do not turn ordinary metadata, navigation, dates, and every button into pills.
- **Icon library as the main visual identity.** Lucide or another utility set may clarify controls, but repeated outline icons cannot carry the direction's signature element.
- **Border + shadow + tinted background + radius used together for one separation task.** Choose the least chrome that establishes the boundary; stacking all four signals unresolved hierarchy.
- **Generic SaaS sidebar, top bar, and settings shell copied into every product.** Stable chrome is valid only when the product has repeated routes or tools that benefit from it.
- **Decorative KPI tiles standing in for analysis.** A large number without period, unit, comparison basis, or next action is not an insight.

### Decorative and Effect Defaults

- **Glassmorphism without a depth or layering model.** Blur and transparency must clarify foreground/background relationships; otherwise use an opaque surface.
- **Floating orbs, blobs, dot grids, light beams, and glow fields.** Reject them when they encode no information and compete with the content hierarchy.
- **Gradient text as the only source of emphasis.** Prefer scale, weight, position, or a bounded accent role that remains readable in all states.
- **Fake editorial furniture.** Issue numbers, fine rules, folios, section marks, and captions must carry real navigation or metadata; otherwise they are costume.
- **Multiple signature effects at once.** Do not combine giant type, glass, glow, parallax, floating objects, and complex scroll animation to manufacture distinctiveness. Concentrate boldness in one content-bearing element.
- **Decorative charts or code fragments.** A graph, ticker, terminal line, or schema diagram must use plausible product data and communicate a real relationship.

## Three-Version Design-Logic Rotation

The three Arena directions must belong to different design logics. A design logic determines the reading order, spatial grammar, density rhythm, and interaction posture; it is deeper than theme, palette, or component styling.

Possible logic families include:

- **Editorial-led / content-led:** argument, narrative sequence, typographic hierarchy, evidence embedded in reading flow, mostly static interaction.
- **Spatial-led / product-led:** persistent chrome, panels, split views, task switching, progressive disclosure, and spatial continuity.
- **Expressive-led / brand-led:** a distinctive graphic or interaction grammar organizes the experience while the surrounding system remains restrained.

These are examples, not an exhaustive taxonomy. Other valid logics may be data-led, object-led, conversational, map-led, timeline-led, or command-led when the product supports them.

### Rotation Test

For each pair of directions, compare:

1. first-screen composition;
2. typographic identity and number treatment;
3. spatial organization and navigation;
4. density rhythm;
5. motion posture.

At least three must differ observably. If the same wireframe can accept all three token sets, the logics are not different enough. If all three could be built by changing CSS variables on one component tree, rewrite the briefs.

Do not ask individual builders to rejudge the arena-wide rotation. The main agent completes that decision once during direction drafting. A builder uses this file only to keep the assigned logic from drifting back toward defaults.

## Required Three-Line Record

Place these three lines at the top of every direction. Write decisions, not adjectives.

```text
[AESTHETIC] <visual thesis + product evidence + system consequence>
[SIGNATURE] <one content-bearing element, its location, and its job>
[ANTI-DEFAULT] <specific default rejected + product harm + replacement>
```

### What Each Line Must Contain

- **`[AESTHETIC]`:** State the visual behavior being created, the subject/audience/task evidence for it, and the resulting typography, density, or layout logic. “Clean and modern” fails.
- **`[SIGNATURE]`:** Name one memorable element that changes reading order, comparison, navigation, or feedback. List where it is visible. A palette or font name alone fails.
- **`[ANTI-DEFAULT]`:** Name the default most likely to appear in this assignment, the harm it would cause, and the structural replacement. “Avoid AI look” fails.

## Brief Critique Procedure

Before approving the three briefs:

1. Highlight every use of a pattern from the current list.
2. Demand subject, audience, content, or single-job evidence for each highlighted choice.
3. Remove unjustified patterns; do not merely rename them.
4. Verify that each brief has one dominant signature rather than several effects.
5. Run the design-logic rotation test across all three directions.
6. Inspect the three-line records. They must predict visible implementation decisions.

Fail and rewrite a brief when:

- its identity depends mainly on a fashionable palette or effect;
- its anti-default declaration rejects a surface detail while preserving the same generic layout underneath;
- the signature element is decorative, interchangeable, or absent from the wireframe;
- it uses several high-attention effects with no hierarchy;
- its design logic overlaps another direction on most observable axes.
