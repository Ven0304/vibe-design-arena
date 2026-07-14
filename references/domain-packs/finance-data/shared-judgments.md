# Finance and Data Product Domain Pack

> **Purpose:** Supplies the domain-wide task modes and judgments shared by every candidate direction.
>
> **Readers:** The main agent and all builders assigned to this domain pack.

Use this pack in Stage 1 when the product centers on financial data, investment research, market monitoring, comparison, or research operations. Read it before drafting the three direction briefs.

This file is intentionally domain-specific. Bloomberg, Financial Times, Stripe, Linear, Every, and Stratechery are reference routes, not skins to copy. Borrow the decision logic named in parentheses; do not reproduce a brand palette, logo treatment, or proprietary type identity.

## 1. Task-Mode Decision Table

Classify each priority route before choosing typography, palette, or components. A route may support secondary tasks, but one mode must control its first screen and information order.

| Mode | User's first question | Preferred structure | Density posture | Strong reference routes | Reject the brief when |
| --- | --- | --- | --- | --- | --- |
| **Monitor** | What changed, and where is the anomaly? | Dense table, panel, ticker, alert rail, stable filters | Continuously high, with few high-contrast hotspots | Bloomberg + Linear | The first screen spends more space explaining the product than exposing current signals |
| **Compare** | Which object differs under one shared definition? | Aligned table, small multiples, synchronized filters, comparison notes | Compact evidence with stable columns and units | FT + Stripe | Objects use inconsistent periods, units, precision, or chart scales |
| **Explain** | What is the argument, evidence chain, and implication? | Article flow, embedded charts, breakout tables, source notes | Spacious claims and transitions; dense evidence | FT + Every + Stratechery | The argument is fragmented into unrelated dashboard cards or depends on hover to be understood |
| **Operate** | How do I filter, save, export, track, or update research? | Stable chrome, object list, detail panel, progressive disclosure, event history | Medium-to-high task density with clear action hierarchy | Stripe + Linear | The screen behaves like a marketing page or exposes every field at once |

### Mode Rules

- Do not let one route pretend to perform Monitor, Compare, Explain, and Operate equally. A product home may navigate among modes; a concrete view needs one primary mode.
- Write the mode into the direction's single job. “Understand the portfolio” is too vague; “detect the positions whose risk changed since the last close” is a Monitor job.
- Match the signature element to the mode. A source-aware argument spine fits Explain; a persistent anomaly rail fits Monitor; synchronized comparison columns fit Compare; a provenance timeline fits Operate.
- Reject a brief whose layout grammar contradicts its mode: a long editorial scroll for rapid monitoring, a card wall for cross-object comparison, or an app shell around a single authored essay.

## 2. Cross-Case Judgments

### Typography

- Use proportional text for explanation and interface language; reserve monospaced type for code-like identifiers or cases that truly require fixed-width alignment. Bloomberg combines proportional and mono roles rather than turning the entire terminal into hacker theater (borrowed from Bloomberg's terminal route).
- Use tabular figures for prices, percentages, time, quantities, and vertically compared values. Numeric stability is more important than a fashionable display face (Bloomberg/Stripe/Linear route).
- Keep financial hierarchy to roughly five or six stable levels. Use weight, role, line-height, color, and space before adding another near-duplicate size (Bloomberg/FT route).
- In dense data regions, make labels compact and numbers calm; in explanatory copy, release line-height and measure. One line-height system cannot serve both a quote grid and an investment thesis (Bloomberg/Stripe route).
- For an editorial direction, let serif type carry claims, chapter identity, or long-form voice while sans type carries filters, dates, sources, table heads, and controls (FT route).
- Do not force serif type into small data labels to perform “authority.” Below reading sizes, scanning efficiency usually matters more than editorial costume (FT route).
- A single high-quality sans family can cover display and body when hierarchy comes from a display cut, weight, tracking, and luminance. Use mono only for ticker, IDs, timestamps, or shortcuts (Linear route).
- A distinctive serif or handwritten accent may express authorship in titles, margin notes, or a short signature. It must never enter dense tables, long annotations, or repeated controls (Every route).
- A slab or humanist serif can create an authored research voice without a giant hero. Narrow measure and consistent article rhythm carry more authority than oversized type (Stratechery route).

Reject the brief if its type plan says only “serif for premium” or “mono for finance.” It must assign type roles to claims, evidence, operations, metadata, and numbers.

### Color

- Build neutral luminance hierarchy first. A financial screen that loses all hierarchy in grayscale is using color to compensate for weak structure.
- On a dark monitoring route, use three or four neutral text/surface steps and one bounded accent for current focus, key value, or navigation. Do not spread amber across all headings or copy Bloomberg's amber-black identity literally (Bloomberg route).
- On an editorial route, a warm high-value paper surface can unify text and charts, but the value lies in editorial continuity, not in copying FT pink. Keep interaction blue and judgment/brand accent responsibilities separate (FT route).
- Use semantic ramps rather than one green, one red, and one purple. State colors need predictable contrast across backgrounds and interaction states (Stripe route).
- Keep same-level category colors close in perceived lightness and saturation. A bright yellow series must not dominate a blue series merely because of hue physics (Stripe's perceptual-color route).
- On dark product surfaces, use base, accent, and contrast relationships plus luminance steps. Do not solve every layer with a new hue or heavy shadow (Linear route).
- Publication or research-section colors may vary inside one system, but they must not take over core control semantics (Every route).
- A nearly monochrome research article with one argument color is a valid, high-confidence choice. Low decoration does not mean the absence of a design system (Stratechery route).
- Never encode gain/loss, risk, or status through red/green alone. Add signs, arrows, direct labels, line styles, marker shapes, or position.
- In charts, prefer one argument or focus color with neutral evidence. When many categories are necessary, label them directly and calibrate perceptual weight.

Reject the brief if the accent represents brand, links, focus, selection, positive performance, and the main data series at the same time.

### Data, Tables, and Charts

- Left-align labels and right-align comparable numbers. Define units, time windows, precision, currency, negative sign, and missing-value treatment at the column or schema level.
- Keep fixed decimal precision when exact comparison matters; do not let formatting jitter make one value appear more important.
- Manage high density with column groups, local headings, alignment, fine separators, and luminance steps. Do not wrap each group or row in a card (Bloomberg/Linear route).
- Place immediately actionable data in one visual field when the Monitor job demands it. Density is not a defect; density without priority is (Bloomberg route).
- Keep explanation adjacent to raw evidence but visually secondary, so the reader sees the conclusion or anomaly before the caveat (Bloomberg/FT route).
- Choose chart grammar from the analytical question. Trend, distribution, deviation, correlation, ranking, and part-to-whole are different questions; do not start from a fashionable chart type (FT Visual Vocabulary route).
- Write chart titles as takeaways, subtitles as definitions or periods, and footnotes as sources. A title that repeats the metric name is incomplete (FT/Stratechery route).
- Prefer direct labels to distant legends. If categories overwhelm direct labeling, reduce, group, filter, or facet them instead of producing a rainbow chart (FT/Stripe route).
- Keep table operations near the data: filters, batch actions, sorting, and export should not live in a remote settings page (Stripe route).
- Give IDs, status, amount, and date stable column behavior. Long narrative text must not steal width from the values users compare (Stripe route).
- Use summary, key state, grouped attributes, and event/log history as progressive layers on object detail pages (Stripe/Linear route).
- Use a stable secondary panel for object metadata when it preserves the main task flow; do not interrupt every comparison with a full navigation jump (Linear route).
- In authored research, let charts act as sentences in the argument: question before, evidence in the graphic, implication after. Avoid detached dashboard islands (Stratechery route).
- Let conclusion graphics or wide tables break out of the reading measure with aligned captions and sources. The breakout should feel like an evidence pause, not decoration (Every route).
- Make every interactive chart's first frame communicate the core conclusion. Hover and animation may add dimensions but cannot rescue an unreadable static state.

Reject a brief that treats “data visualization” as a decorative background, that hides units until hover, or that proposes KPI cards without period, basis, or action.

### Layout and Density Rhythm

- Use adjustable panels, tabs, lists, or split views for repeated monitoring and comparison; do not import a marketing-page card waterfall into an expert tool (Bloomberg route).
- Give dense filters, headers, and navigation a stable home. Allow conclusions and research transitions to breathe so the eye can move from scan to pause to reading (Bloomberg/Linear route).
- A default customizable workspace still needs a hierarchy. Equal-sized panels are not neutral when tasks have unequal importance.
- Use article flow for continuous argument. Cards are appropriate for independent entries or reusable modules, not for every paragraph, chart, or section (FT/Every/Stratechery route).
- A 12-column or equivalent grid can align main analysis, secondary evidence, and notes, but the grid must serve the argument rather than advertise itself (FT route).
- Stable navigation, focused main content, and a contextual side region form a strong research-operation pattern. Keep the auxiliary region optional and subordinate (Stripe route).
- Treat list, table, board, timeline, split, and fullscreen as task modes, not visual variety. Each view must earn its place through a different question (Linear route).
- A magazine-like entry screen may curate themes or authors; the article itself should return to a stable reading axis with occasional evidence breakouts (Every route).
- Long scrolling is valid for Explain, provided headings, charts, margin notes, and argument transitions give the reader location. Long scrolling is not a substitute for Operate or Monitor.
- On narrow screens, reduce simultaneous columns, preserve the primary values or claims, and provide drill-down to secondary evidence. Do not mechanically shrink the desktop canvas.

Reject a brief that equates dashboard with card grid, editorial with one column for every object, or responsiveness with stacking every desktop block in source order.

### Motion and Product Feel

- Keep quote reading, sorting, filters, keyboard navigation, and other frequent actions near-instant. Long transitions make professional tools feel slower than they are (Bloomberg/Linear route).
- Use short motion for state change, focus movement, panel disclosure, and loading continuity. Do not animate a number merely because it changed (Bloomberg/Stripe route).
- Preserve axes, baselines, and object position when comparable data changes. Redraw locally or crossfade carefully rather than flying the entire chart away (FT route).
- Use motion to explain the stable chrome: a side panel should come from its side, a popover from its trigger, and focus should return on close (Linear route).
- Keep authored reading mostly static. Lightweight navigation, annotation, filtering, or image-detail feedback is enough (Every/Stratechery route).
- Reject count-up values, staged paragraph reveal, autoplay, background drift, elastic panels, and scroll hijacking across all finance routes.
- Treat reduced motion as a complete alternate behavior: remove large or repeated movement while preserving focus, loading, validation, and state feedback.

Reject a brief whose motion plan says only “subtle animations.” It must name which state changes move, which remain immediate, and which remain deliberately static.

These are evidence-based shared calibration rules, not standalone direction proposals. Apply them to the actual product schema, routes, audience, and brand. Keep the three separately assigned direction logics distinct; do not blend them into one “best of” brief.
