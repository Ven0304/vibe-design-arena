CONTROLLER_COMMANDS = (
    "preflight",
    "create-worktrees",
    "start-previews",
    "stop-previews",
    "status",
    "import-builder-result",
    "import-qa-result",
    "sign-visual-review",
    "sign-direction-review",
    "qualify",
    "select",
    "merge",
    "cleanup",
    "publish-plan",
    "publish",
    "handoff-docs",
)

INTEGRITY_ACTIONS = (
    "snapshot",
    "normalize-brief",
    "check-attributes",
    "verify-brief",
)

STYLES = ("style-a", "style-b", "style-c")

STAGE_ORDER = (
    "preflight",
    "briefs-approved",
    "worktrees-ready",
    "building",
    "previews-ready",
    "qualifying",
    "selection-ready",
    "selected",
    "merged",
    "cleaned",
    "complete",
)

EVENT_OUTCOMES = ("success", "failure", "blocked", "info")