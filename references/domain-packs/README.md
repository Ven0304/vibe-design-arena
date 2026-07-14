# Domain Pack Structure

Use one folder per product domain. Every domain pack follows the same three-part distribution boundary so a builder receives shared calibration plus one assigned direction without seeing sibling directions or the arena-level comparison.

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
| `directions/direction-<a/b/c>.md` | One direction's domain-calibrated starting point | Main agent and only the builder assigned to that direction |
| `orthogonality-check.md` | Cross-direction comparison, pairwise rejection questions, and arena-level audit | Main agent only |

The main agent must dispatch explicit file paths. A builder dispatch includes `shared-judgments.md` and exactly one matching direction file. It must not name sibling direction files or `orthogonality-check.md`.

The filenames and distribution rules are domain-neutral. To add another pack, copy this folder shape, keep the boundary descriptions, and replace only the domain-specific calibration content.
