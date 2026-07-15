class ArenaError(Exception):
    """Expected controller failure safe to report without a traceback."""


class DependencyUnavailableError(ArenaError):
    pass


class RevisionMismatchError(ArenaError):
    pass


class PhaseUnavailableError(ArenaError):
    pass