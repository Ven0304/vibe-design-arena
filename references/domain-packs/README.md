# Domain Pack Structure

Domain packs are optional domain calibration for an Arena run; they are not prerequisites. Universal references remain mandatory at their stated workflow stages whether or not a pack is selected. Select at most one existing pack for the entire Arena run, based on the product's primary task, core content shape, and target users. All three candidates use that selected domain pack, or all three use none.

For a cross-domain product, use the primary task served by the Arena run. If no single pack clearly matches, select none and continue with universal standards. Do not combine packs, assign different packs per candidate, force a product into the finance/data pack, or assemble an unvalidated pack ad hoc. Missing a matching pack never blocks the three-direction set, implementation, QA, qualification, or winner selection.

Every selected domain pack follows the distribution boundary below. The main agent reads the five complete pack files, embeds the matching direction source verbatim in each approved `DESIGN_BRIEF.md`, and prevents builders from receiving sibling or arena-level comparison material.

```text
<domain-pack>/
├── shared-judgments.md
├── directions/
│   ├── direction-a.md
│   ├── direction-b.md
│   └── direction-c.md
└── orthogonality-check.md
```

## Distribution Boundary

| Path | Purpose | Readers |
| --- | --- | --- |
| `shared-judgments.md` | Domain-wide task modes, evidence, and judgments that apply to every candidate | Main agent; a builder only when the main agent lists it in that builder's dispatch |
| `directions/direction-<a/b/c>.md` | One direction's domain-calibrated starting point, copied verbatim into the matching `DESIGN_BRIEF.md` | Main agent only at this source path |
| `orthogonality-check.md` | Cross-direction comparison, pairwise rejection questions, and arena-level audit | Main agent only |

The main agent applies shared judgments across the three-direction set, assigns A/B/C to the matching candidates, and uses `orthogonality-check.md` to review structural independence. Names may change where a pack permits it, but the A/B/C structural roles and mapping do not. Builders never choose a pack or direction and never use sibling material to manufacture difference.

The file inputs named in a builder dispatch are limited to:

- the assigned worktree's root-level `DESIGN_BRIEF.md`, which contains the complete verbatim copy of that builder's matching direction;
- the universal references allowed for the implementation stage, including `anti-slop.md`, `visual-quality-bar.md`, `interaction-quality-bar.md`, and `arena-scorecard.md`;
- optionally, the selected domain pack's `shared-judgments.md`, only when the main agent explicitly lists it for that dispatch.

Do not include, name, summarize, or expose any path under `directions/`, `orthogonality-check.md`, either sibling candidate's `DESIGN_BRIEF.md`, the user-facing three-direction comparison table, or any other arena-level horizontal comparison in a builder dispatch. Do not include clues that enable a builder to infer or imitate sibling directions. Builders receive assigned direction content only through the committed `DESIGN_BRIEF.md` in their own worktree.

If no domain pack is selected, dispatch no domain-pack file. Each builder still receives its own complete committed `DESIGN_BRIEF.md` and the implementation-stage universal references. Record `none` for domain calibration where the brief template calls for it; do not fabricate pack-derived content or relax structural-independence requirements.

Before brief drafting, the main agent freezes the complete reference set for the Arena run: universal references that will be consumed at their required stages and, only when a pack is selected, that pack's `shared-judgments.md`, all three direction sources, and `orthogonality-check.md`. Unselected packs are neither manifest inputs nor integrity blockers. Do not add a pack to an existing manifest during the run; changing the frozen set requires the existing restart/cancel path.

The filenames and distribution rules are domain-neutral. To add another pack, copy this folder shape, keep the boundary descriptions, and replace only the domain-specific calibration content.
