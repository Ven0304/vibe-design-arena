# Domain Pack Structure

Use one folder per product domain. Every domain pack follows the same three-part distribution boundary. The main agent reads the complete pack, embeds one assigned direction verbatim in each approved `DESIGN_BRIEF.md`, and prevents builders from receiving any direction-file path or the arena-level comparison.

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
| `shared-judgments.md` | Domain-wide task modes, evidence, and judgments that apply to every candidate | Main agent and all three builders |
| `directions/direction-<a/b/c>.md` | One direction's domain-calibrated starting point, copied verbatim into the matching `DESIGN_BRIEF.md` | Main agent only at this source path |
| `orthogonality-check.md` | Cross-direction comparison, pairwise rejection questions, and arena-level audit | Main agent only |

The file inputs named in a builder dispatch are limited to:

- the assigned worktree's root-level `DESIGN_BRIEF.md`, which contains the complete verbatim copy of that builder's matching direction;
- the four universal references: `anti-slop.md`, `visual-quality-bar.md`, `interaction-quality-bar.md`, and `arena-scorecard.md`;
- optionally, the matching domain pack's `shared-judgments.md`.

Do not include, name, or expose any path under `directions/` or the path to `orthogonality-check.md` in a builder dispatch. Builders receive direction content only through the committed `DESIGN_BRIEF.md` in their assigned worktree.

The filenames and distribution rules are domain-neutral. To add another pack, copy this folder shape, keep the boundary descriptions, and replace only the domain-specific calibration content.
