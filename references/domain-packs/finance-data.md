# Finance and Data Product Domain Pack

Use this pack in Stage 1 when the product centers on financial data, investment research, market monitoring, comparison, or research operations. Read it before drafting the three direction briefs.

This file is intentionally domain-specific. Bloomberg, Financial Times, Stripe, Linear, Every, and Stratechery are reference routes, not skins to copy. Borrow the decision logic named in parentheses; do not reproduce a brand palette, logo treatment, or proprietary type identity.

## Contents

- [1. Task-mode decision table](#1-task-mode-decision-table)
- [2. Cross-case judgments](#2-cross-case-judgments)
- [3. Starting directions](#3-starting-directions)
- [4. Difference checklist](#4-difference-checklist)

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

## 3. Starting Directions

These are evidence-based starting points, not mandatory final directions. Adapt them to the actual product schema, routes, audience, and brand. Do not blend all three into one “best of” brief.

### Direction A — Editorial Investment Dossier

**Reference logic:** Financial Times + Stratechery, with optional Every-style authorial annotation.

**Best fit:** Explain first; Compare second. Use when the product's value lies in an argument, an investment thesis, a report, or a chain from claim to evidence.

**Aesthetic thesis:** Treat the product as a readable and citable research object rather than a dashboard containing report text. Typography establishes judgment; charts and tables interrupt the measure only when the evidence needs width.

**System starting point:**

- Warm or low-chroma high-value canvas; near-black text; one cool interaction color and one restrained judgment/section accent.
- Serif display for claims and chapter identity; readable serif or sans body; sans UI and metadata; tabular numeric features for comparisons.
- One primary reading axis, visible source/date context, deliberate chapter transitions, and limited chart/table breakouts.
- Takeaway chart titles, direct labels, source notes, and tables with minimal rules.
- Reading remains static; contents navigation, filters, annotations, and disclosure receive brief feedback.

**Signature candidates — choose one:**

- a conclusion-to-evidence spine that links each claim to charts, source, and implication;
- a margin-note system that carries provenance, definitions, and analyst qualification;
- a controlled evidence breakout where wide data temporarily exceeds the reading measure.

**Justified risk:** Strong editorial voice can slow scanning or become nostalgic. Bound it by keeping all operations, metadata, and numeric comparison in restrained sans/tabular roles.

**Anti-default:** Reject dark terminal styling, KPI-card walls, fake newspaper furniture, and scroll-revealed paragraphs. Do not copy FT pink, a newspaper masthead, or another recognizable surface treatment.

**Brief fails when:**

- it says “editorial” but keeps a generic dashboard grid;
- serif type appears in filters and tiny table labels without a reading reason;
- the warm palette is the only connection to editorial authority;
- charts are decorative islands rather than steps in an argument;
- the signature is merely a large headline.

### Direction B — Analyst Signal Terminal

**Reference logic:** Bloomberg Terminal + Linear.

**Best fit:** Monitor first; Compare second. Use when experts must detect changes, anomalies, and relationships without leaving the primary field of view.

**Aesthetic thesis:** Build a high-density decision surface where alignment, luminance, and one bounded signal color separate actionable change from background evidence. Speed and spatial continuity carry the product identity.

**System starting point:**

- Near-black or charcoal canvas with several surface/text luminance steps; one amber or cool accent for focus and key signal, not for every heading.
- Compact sans UI; tabular numerals; local mono only for identifiers, ticker, or strict fixed-width comparison.
- Stable L-shaped chrome or equivalent persistent context; list/table/chart/split views selected by task; detail in a side panel.
- Right-aligned values, stable decimals, low-area state markers, and brief local highlight for changed data.
- Frequent actions are immediate; popovers, panels, and focus movement use short, interruptible spatial transitions.

**Signature candidates — choose one:**

- a persistent anomaly rail that ranks and explains the few high-priority changes;
- a synchronized table-chart cursor that preserves comparison context;
- a split view where selection, evidence, and detail remain spatially connected.

**Justified risk:** High density can become indiscriminate noise. Bound it with a small number of contrast hotspots, stable alignment, and clear defaults for panel priority.

**Anti-default:** Reject retro green-terminal cosplay, full-site monospaced type, copied Bloomberg amber-black branding, neon glows, and animated-number spectacle.

**Brief fails when:**

- “terminal” means only dark mode plus mono type;
- every panel has equal weight or every value is highlighted;
- the primary route starts with marketing copy instead of current signals;
- mobile merely compresses all columns;
- motion delays filters, tabs, sorting, or keyboard work.

### Direction C — Research Operating System

**Reference logic:** Stripe + Linear for operations, with Every for bounded authorial voice.

**Best fit:** Operate first; Explain second. Use when users navigate, filter, save, trace, and update a body of research while retaining source and thesis context.

**Aesthetic thesis:** Turn research into a durable, traceable product system: stable navigation and complete object states make the work operational, while selective typographic voice marks conclusions without contaminating the controls.

**System starting point:**

- Bright neutral canvas and deep-gray text; one indigo or other bounded action color; low-saturation section colors may organize research domains but must not enter control semantics.
- Neutral sans for application, body, and object properties; optional distinctive serif only for investment propositions, chapter titles, or short conclusion quotations.
- Stable left navigation, focused research area, and optional source/definition panel; summary, object detail, and event history use progressive disclosure.
- Tables and grouped lists remain primary; KPI cards are limited to true summaries or action boundaries.
- Navigation, state, panel, and disclosure transitions are light and short; reading and chart first frames remain static.

**Signature candidates — choose one:**

- a provenance rail linking each conclusion to source, timestamp, and revision history;
- a research-object workspace that keeps thesis, evidence, and actions synchronized;
- a section-aware annotation system that changes authorial tone without changing control semantics.

**Justified risk:** A stable operating shell can feel generic or suppress authorial judgment. Bound it by giving one conclusion or provenance element a distinctive typographic role while keeping the rest quiet.

**Anti-default:** Reject a Stripe-purple marketing page, generic SaaS settings chrome, excessive cards, and decorative Every-style handwriting. The identity must come from traceability and state completeness.

**Brief fails when:**

- the shell could host any CRUD product without modification;
- purple or indigo is the only connection to Stripe's route;
- every research object is a rounded card;
- sources and revisions remain secondary text rather than an operational feature;
- the serif accent spreads into controls, tables, or long UI copy.

## 4. Difference Checklist

Use this table to test the three briefs as a set. The names may change, but the chosen directions must maintain comparable structural distance.

| Axis | Editorial Investment Dossier | Analyst Signal Terminal | Research Operating System |
| --- | --- | --- | --- |
| Primary mode | Explain / Compare | Monitor / Compare | Operate / Explain |
| First-screen promise | A claim and its evidence path | Current signals and anomalies | Research objects, status, and next action |
| Main structure | Article flow with evidence breakouts | Stable chrome with panel/table/split views | Stable navigation with progressive detail and provenance |
| Type identity | Serif-led judgment, sans operations | Sans/number-led, local mono | Sans system with bounded serif voice |
| Surface logic | High-value paper field, minimal cards | Near-black luminance hierarchy | Bright neutral surfaces and keylines |
| Density rhythm | Spacious claims, dense evidence | Continuously dense, few hotspots | Calm summary, medium/high operational density |
| Data role | Evidence inside an argument | Primary decision surface | Object state, history, and traceability |
| Motion posture | Nearly static | Immediate with brief spatial feedback | Light hierarchy and state transitions |
| Likely signature | Argument/evidence spine or margin provenance | Anomaly rail or synchronized split view | Provenance rail or research-object workspace |
| Primary risk | Nostalgia or slow scanning | Noise or inaccessible density | Generic SaaS shell |
| Default rejected | Dashboard/card wall | Dark hacker-terminal cosplay | Purple marketing UI and CRUD cards |

### Pairwise Rejection Questions

Reject and rewrite the set when any answer is “yes”:

- Can the same first-screen wireframe support all three by swapping color and typography?
- Do two directions lead with the same task mode and defer the same information?
- Do two directions use the same navigation, density rhythm, and signature placement?
- Are all three primarily card grids despite their different names?
- Is the terminal distinguished only by dark mode, the editorial version only by serif type, or the operating system only by a sidebar?
- Could all three be implemented from one component tree by changing tokens alone?
- Do the anti-default declarations reject different decorations while preserving the same underlying design logic?

### Domain-Specific Brief Audit

Before approving each finance-data brief, verify:

- The first screen names one task mode and makes that task visually dominant.
- Numeric formatting defines alignment, precision, unit, period, negative sign, and missing value.
- Positive/negative and risk states use a cue beyond red/green.
- Chart titles, definitions, and sources have a planned location.
- Dense tables have a narrow-screen access strategy rather than silent data loss.
- The accent color has bounded responsibilities.
- The signature element carries a conclusion, anomaly, comparison, action, or provenance relationship.
- Motion declares what remains immediate and what remains static, not only what animates.
- The reference route is named as borrowed logic, while recognizable brand skin is explicitly rejected.

If these conditions are absent, the brief is not yet grounded enough to dispatch to a builder.
