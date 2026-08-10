# AGENTS.md

## Repository purpose

This repository contains application functions and manifests for the Evergreen PowerShell module. Most changes involve adding or updating one PowerShell app definition in Apps and its matching JSON manifest in Manifests.

## Working conventions

- Prefer the existing repository patterns over inventing new ones. Start by reviewing nearby examples in Apps and Manifests.
- Keep changes focused. Do not modify unrelated files unless the task explicitly requires it.
- Follow the contributor guidance in [README.md](README.md), [CLAUDE.md](CLAUDE.md), and [RULES.md](RULES.md) for local setup, repository structure, and validation expectations.
- For new application requests, use the specialist workflow in [.github/agents/evergreen-new-app.agent.md](.github/agents/evergreen-new-app.agent.md) when applicable.

## File layout

- Apps/: one PowerShell script per app, named Get-<AppName>.ps1
- Manifests/: one JSON manifest per app, named <AppName>.json
- .rules/: PowerShell analyzer settings and custom rules
- .github/workflows/: validation workflows that enforce repository checks

## Implementation guidance

- PowerShell functions should follow the existing Evergreen pattern and return one or more objects with Version and URI at minimum.
- Use the existing helper patterns from the repository where possible, such as Get-FunctionResource, Invoke-EvergreenRestMethod, Get-FileType, and Get-Architecture.
- Keep code minimal and repository-consistent. Avoid introducing unrelated abstractions or comments.
- Use lowercase PowerShell keywords and boolean/null constants.
- Preserve LF line endings and UTF-8 or ASCII encoding.

## Validation expectations

Before finishing, verify that changes still align with the repository checks:

- PowerShell scripts in Apps should pass PSScriptAnalyzer with the rules in [.rules/PSScriptAnalyzerSettings.psd1](.rules/PSScriptAnalyzerSettings.psd1)
- JSON files in Manifests should remain valid JSON
- File types and encoding should remain consistent with the checks in [.github/workflows/validate.yml](.github/workflows/validate.yml)

## When adding a new app

1. Review the issue or request details and identify a stable, machine-readable update or download source.
2. Inspect similar app implementations in Apps and Manifests.
3. Create or update the PowerShell function and the matching manifest together.
4. Run the relevant validation checks for the touched files when practical.

## Commit messages

Use the following rules for commit messages:

- When commiting files in /Apps and /Manifests, use the application name in the commit subject, and only list the files added for the application in the commit description
- Use imperative mood: 'Add feature' not 'Added feature'
- Keep subject line under 50 characters
- Reference issue numbers with # prefix
