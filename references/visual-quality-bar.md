# Visual Quality Bar

Use this file after implementation. Treat every applicable item as binary: pass only when the rendered interface provides visible evidence. Intent, source code, or a token name alone does not count.

## Typography Hierarchy

- [ ] Use a deliberate type scale with approximately four to six recurring size levels. Add another level only when it has a distinct semantic role; near-duplicate sizes fail.
- [ ] Assign stable roles such as display, page title, section title, body/UI, data, and meta. The same role must not drift in size or weight across screens.
- [ ] Keep dense tables, controls, and numeric regions readable at roughly `1.2–1.35` line-height; no ascenders, descenders, or focus outlines may collide.
- [ ] Keep explanatory body text at roughly `1.45–1.7` line-height. Display headings may tighten to roughly `1.0–1.2` only when multi-line wrapping remains legible.
- [ ] Keep long-form measure near `45–75` Latin characters per line, or a visually equivalent measure for the writing system. Narrow metadata and wide tables are exceptions, not body-copy defaults.
- [ ] Use `font-variant-numeric: tabular-nums` or an equivalent font feature for values that users compare vertically. Right-align numeric columns and align decimal precision where comparison requires it.
- [ ] Keep labels and text columns left-aligned unless the language or task provides a reason otherwise. Do not center dense data or long body copy.
- [ ] Review headings and paragraphs for orphaned headings, one-word final lines, and isolated first or last lines. Rewrap or adjust measure where these visibly damage rhythm.
- [ ] Avoid negative tracking on small text. Tight display tracking must not be inherited by labels, body copy, or numeric data.

## Color and Contrast

- [ ] Define semantic color roles and ramps for canvas/surface, text, accent, focus, success, warning, danger, and information as applicable. A single hard-coded color per state is not a system.
- [ ] Use neutral luminance steps to create hierarchy before adding category or brand color. Removing color should not collapse the entire reading order.
- [ ] Keep the accent role bounded. One color must not simultaneously mean brand, link, focus, selection, and positive performance unless those meanings cannot conflict.
- [ ] Do not encode positive/negative, risk, or status only with red and green. Add a sign, label, arrow, icon shape, line style, or position cue.
- [ ] Keep same-level category colors close in perceived lightness and saturation. One category must not dominate merely because its hue is naturally brighter.
- [ ] Check chart lines, grid lines, small labels, and muted text on their actual surface. Low-opacity color on a dark canvas must remain distinguishable.
- [ ] Meet WCAG AA contrast: at least `4.5:1` for normal text, `3:1` for large text, and `3:1` for essential UI boundaries and focus indicators.

## Spacing, Alignment, and Grouping

- [ ] Use a named spacing scale. Repeated arbitrary gaps that do not map to the scale fail.
- [ ] Keep within-group spacing smaller than between-group spacing. A user should be able to identify groups with color and borders temporarily removed.
- [ ] Establish shared alignment lines across headings, controls, charts, tables, and annotations. One-off offsets must have a content reason.
- [ ] Use whitespace according to task rhythm: conclusions and transitions may breathe; evidence, comparison, and high-frequency controls may be compact.
- [ ] Do not use card, border, shadow, and background tint together to perform the same separation. Choose the least chrome that creates the required boundary.
- [ ] Use cards only for independent objects, reusable modules, or action boundaries. Continuous arguments, rows, and every chart must not become isolated cards by default.
- [ ] Keep radius and elevation roles consistent. Components with the same hierarchy must not use unrelated corner or shadow treatments.

## Responsive Baseline

- [ ] Render without page-level horizontal overflow from `320px` through wide desktop. Intentional table or chart scrolling must be contained, signposted, and keyboard reachable.
- [ ] Verify at least one `320px` mobile viewport, one medium/tablet viewport, and one wide desktop viewport. Do not infer responsiveness from CSS alone.
- [ ] Reorder content by task priority on narrow screens. A desktop grid that merely shrinks, wraps randomly, or preserves secondary content above the primary job fails.
- [ ] Define a deliberate narrow-screen strategy for wide tables: column priority, stacked detail, horizontal region scroll, or drill-down. Hiding data without an access path fails.
- [ ] Keep interactive targets at least `44 × 44px` on touch layouts, including icon-only controls and row actions.
- [ ] Keep compact-layout body and control text at a readable size; do not solve width pressure by shrinking core text below approximately `14px`.
- [ ] Test long titles, long organization names, localization expansion, negative values, missing values, and extreme numbers. Critical content must not clip or overlap.

## Accessibility Baseline

- [ ] Reach every interactive element by keyboard in a logical order. No keyboard trap is permitted.
- [ ] Show a visible focus indicator on every interactive control and custom widget. Hover styling alone does not count.
- [ ] Preserve semantic HTML and accessible names. Use ARIA only where native semantics are insufficient.
- [ ] Associate form labels, errors, help text, table headers, and units with the controls or data they describe.
- [ ] Do not convey required information only through color, hover, animation, or pointer position.
- [ ] Keep zoom and text resizing usable. At `200%` zoom, the primary task must remain available without overlapping or disappearing controls.

## State Completeness

- [ ] Provide a loading state that preserves layout stability and explains what is loading. Endless generic spinners without context fail.
- [ ] Provide an empty/no-data state that distinguishes “nothing exists,” “filters returned nothing,” and “data is unavailable” when those cases require different actions.
- [ ] Provide an error state with a human-readable problem and a useful recovery action when recovery is possible.
- [ ] Provide disabled states that remain legible and explain prerequisites when the reason is not obvious.
- [ ] Provide stale-data treatment for time-sensitive or remotely sourced information: timestamp, stale indicator, refresh path, and preserved last-known value where appropriate.
- [ ] Provide clear default, hover, focus, active/pressed, selected, success, and destructive states for applicable controls.
- [ ] Keep state changes from causing avoidable layout shift. Loading, validation, and refreshed data must not unexpectedly move the user's target.

## Screenshot-Based Acceptance

Do not mark this file complete from source inspection.

Capture and inspect, at minimum:

1. the primary screen at `320px`, a medium/tablet width, and a wide desktop width;
2. the densest data or content view;
3. loading, empty, error, disabled, and stale-data states where applicable;
4. a keyboard-focused state;
5. long content, missing values, negative values, and an extreme numeric value.

For each screenshot, check first-screen hierarchy, text wrapping, alignment, color contrast, grouping, overflow, and state visibility. Record the viewport and route. If a requirement cannot be seen in a screenshot, provide a short interaction note or accessibility-tool result.

## Pass Rule

Pass only when every applicable checkbox has rendered evidence. A known failure cannot be offset by a strong signature element, attractive palette, or another passing category. Record the exact failed item and revise the implementation before reassessing it.
