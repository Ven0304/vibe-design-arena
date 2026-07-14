# Interaction Quality Bar

Use this file after implementation. Every motion or transition must have a product purpose and must remain understandable when motion is reduced.

A builder's result is preliminary unless it includes evidence from the actual rendered version. The main agent owns the final rendered interaction evidence, including keyboard, focus return, rapid toggling, touch-sized viewport behavior, and reduced motion. Source inspection alone cannot pass an interaction item.

## Allowed Purposes

Motion may be used only to provide one or more of these outcomes:

- **I-AP-01:** **Feedback:** acknowledge press, hover, completion, validation, save, selection, or failure.
- **I-AP-02:** **Spatial continuity:** show where a popover, panel, drawer, or object came from and where focus returns.
- **I-AP-03:** **State explanation:** clarify a meaningful change in status, data, hierarchy, or visibility.
- **I-AP-04:** **Avoiding abrupt change:** soften a necessary surface or content transition without delaying the task.
- **I-AP-05:** **Teaching a rare interaction:** briefly reveal a relationship the first time it matters, without repeating on every visit.

“It looks cool,” “it feels premium,” and “the page needs more life” are not valid purposes. If the builder cannot name the purpose, remove the motion.

## Duration Reference

Use these ranges as defaults, not quotas. High-frequency work should sit near the fast end or be immediate.

| Interaction | Reference duration | Pass condition |
| --- | ---: | --- |
| Press/tap feedback | `80–160ms` | Acknowledges input without delaying the action |
| Hover/focus/color feedback | `100–180ms` | Feels immediate and does not trail the pointer or keyboard |
| Popover/dropdown | `140–220ms` | Establishes origin and remains fast under repeated use |
| Dialog/drawer/side panel | `200–320ms` | Explains a larger spatial change without blocking work |

- [ ] **I-DU-01:** Keep data refresh, sorting, filtering, tab changes, and other high-frequency operations near-instant unless continuity would otherwise be lost.
- [ ] **I-DU-02:** Make exit slightly faster than entry for the same surface.
- [ ] **I-DU-03:** Do not extend a duration merely to make an effect easier to notice.
- [ ] **I-DU-04:** Use one named duration token for each recurring interaction role; scattered one-off milliseconds fail.

## Properties and Easing

- [ ] **I-PE-01:** Never use `transition: all`. Name only the properties that are expected to change.
- [ ] **I-PE-02:** Prefer `transform` and `opacity` for motion. Animate layout properties only when the layout change itself must be explained and performance remains stable.
- [ ] **I-PE-03:** Use a clear `ease-out` for entering surfaces and feedback that should settle quickly.
- [ ] **I-PE-04:** Make exits faster and less conspicuous than entries; use an appropriate ease-in or shortened easing when it does not feel abrupt.
- [ ] **I-PE-05:** Use `ease-in-out` for objects that visibly move while remaining on screen.
- [ ] **I-PE-06:** Keep hover and focus transitions short and non-elastic.
- [ ] **I-PE-07:** Do not create surfaces from `scale(0)`. Use a small, plausible scale range or directional translation only when origin matters.
- [ ] **I-PE-08:** Open popovers and dropdowns from the trigger direction. Closing must return focus to the logical trigger or next control.
- [ ] **I-PE-09:** Keep motion interruptible. Rapid open/close, repeated clicks, and route changes must not leave stale layers or force the previous animation to finish.
- [ ] **I-PE-10:** Prevent animation-driven layout shift, pointer-target movement, and dropped frames in the primary flow.

## Explicitly Prohibited Defaults

Fail the implementation when any of these appear without exceptional, documented product evidence:

- **I-PD-01:** purposeless bounce, spring, overshoot, or elastic easing;
- **I-PD-02:** count-up animation for ordinary prices, KPIs, balances, percentages, or report values;
- **I-PD-03:** paragraph-by-paragraph or section-by-section scroll reveal that delays reading;
- **I-PD-04:** automatic carousels, rotating testimonials, or unattended tab cycling;
- **I-PD-05:** continuous floating objects, pulsing glows, ambient background drift, or looping parallax;
- **I-PD-06:** scroll hijacking or forced scroll-snap in a reading or work flow;
- **I-PD-07:** charts that reveal their core conclusion only after an animation completes;
- **I-PD-08:** large full-page entrance sequences on repeat visits;
- **I-PD-09:** long crossfades on tabs, filters, tables, or high-frequency navigation;
- **I-PD-10:** hover movement that shifts adjacent layout or moves the pointer target;
- **I-PD-11:** repeated decorative animation competing with live data, alerts, or focus.

## Data and Content Behavior

- [ ] **I-DC-01:** Keep a chart's first stable frame readable. Motion may explain a change but cannot be the only carrier of the conclusion.
- [ ] **I-DC-02:** Preserve axes, baselines, and object positions when switching comparable data. Avoid replacing the whole chart with an unrelated entrance animation.
- [ ] **I-DC-03:** Use new-data highlighting briefly and locally. Do not flash entire rows or panels when only one value changed.
- [ ] **I-DC-04:** Keep reading surfaces mostly static. Navigation, annotation, filtering, and disclosure may animate; paragraphs should not wait for motion before becoming available.
- [ ] **I-DC-05:** Preserve the user's spatial context when opening details, then restore focus and scroll position on close.
- [ ] **I-DC-06:** Ensure loading motion communicates activity without implying false progress.

## Reduced Motion

Reduced motion is an alternate motion system, not a blanket removal of all feedback.

- [ ] **I-RM-01:** Implement `prefers-reduced-motion: reduce` or the platform-equivalent behavior.
- [ ] **I-RM-02:** Remove large translations, parallax, zoom, long movement, repeated motion, autoplay, and vestibularly risky effects.
- [ ] **I-RM-03:** Replace spatial movement with immediate state change, restrained opacity change, outline, color, text, or icon feedback where needed.
- [ ] **I-RM-04:** Preserve essential status feedback, focus visibility, validation, loading meaning, and open/closed state.
- [ ] **I-RM-05:** Never hide or delay content because its entrance animation was removed.
- [ ] **I-RM-06:** Keep the reduced version free of large scale changes and repeated flashing.
- [ ] **I-RM-07:** Test reduced motion in the browser or operating system; the presence of a media query in source is not evidence that behavior is correct.

## Interaction Acceptance

Test the rendered version, not only the CSS.

1. **I-AC-01:** Use mouse, keyboard, and touch-sized viewport paths for the primary task.
2. **I-AC-02:** Open and close every major popover, dialog, drawer, and panel repeatedly.
3. **I-AC-03:** Spam-click or rapidly toggle controls to test interruption and stale-state handling.
4. **I-AC-04:** Slow animations in developer tools to inspect origin, easing, and layout stability.
5. **I-AC-05:** Toggle reduced motion and repeat the primary task.
6. **I-AC-06:** Check a low-performance or throttled environment for jank in the most animated view.

## Pass Rule

Pass only when every motion has a named purpose, duration and easing are appropriate to frequency, prohibited defaults are absent, interaction remains stable under interruption, and reduced motion preserves meaning without harmful movement. Record each failed item separately; visual polish elsewhere cannot offset it.
