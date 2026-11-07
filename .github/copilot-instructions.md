# Evergreen application maintenance

Read and follow the root [AGENTS.md](../AGENTS.md) and [RULES.md](../RULES.md)
before making changes. Use [README.md](../README.md) for setup and testing.
These documents are the repository's source of truth; do not replace their
requirements with generic PowerShell conventions.

For an assigned application bug or new-application issue, follow
[Evergreen App Maintainer](agents/evergreen-app-maintainer.agent.md). For new
applications, also follow the intake and source requirements in
[Evergreen New App](agents/evergreen-new-app.agent.md).

Keep changes limited to the issue. Validate the affected local app definitions
and report checks that could not run. Work on the task branch and leave the
pull request for human review; never push directly to the default branch or
merge automatically.
