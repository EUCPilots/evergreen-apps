# AGENTS.md

## Repository purpose

This repository provides application functions (PowerShell scripts) and manifests (JSON configs) for the [Evergreen](https://eucpilots.com/evergreen) PowerShell module. Evergreen uses these to detect and download the latest versions of Windows applications. Most changes involve adding or updating one app definition in `Apps/` and its matching manifest in `Manifests/`.

## Working conventions

- Prefer the existing repository patterns over inventing new ones. Start by reviewing nearby examples in Apps and Manifests.
- Keep changes focused. Do not modify unrelated files unless the task explicitly requires it.
- Follow the contributor guidance in [README.md](README.md) and [RULES.md](RULES.md) for repository structure and validation expectations.
- For new application requests, use the specialist workflow in [.github/agents/evergreen-new-app.agent.md](.github/agents/evergreen-new-app.agent.md) when applicable.

## Local development and testing

Point Evergreen at the local repository and import the Evergreen module:

```powershell
$env:EVERGREEN_APPS_PATH = "/path/to/evergreen-apps"
Import-Module -Name Evergreen -Force
# Or import a local module clone:
Import-Module -Name "/path/to/evergreen-module/Evergreen" -Force
```

Test an app function by calling it directly, for example `Get-MicrosoftEdge` or `Get-GoogleChrome`.

Run PSScriptAnalyzer locally with the repository settings:

```powershell
Invoke-ScriptAnalyzer -Path "./Apps" -Recurse -Settings ".rules/PSScriptAnalyzerSettings.psd1"
```

## File layout

- `Apps/` — one `.ps1` file per app, named `Get-<AppName>.ps1`, containing a single function
- `Manifests/` — one `.json` file per app, named `<AppName>.json`, describing how to retrieve and install the app
- `_retired/` — deprecated app definitions kept for reference
- `.rules/` — PSScriptAnalyzer settings and custom rules
- `.github/workflows/` — validation and release workflows

## Implementation guidance

- Every app script exports a `Get-<AppName>` function. It should accept a `$res` parameter that loads its companion manifest via `Get-FunctionResource -AppName`, and return one or more objects with `Version` and `URI` at minimum.
- Use the existing helper patterns from the repository where possible, such as Get-FunctionResource, Invoke-EvergreenRestMethod, Get-FileType, and Get-Architecture.
- Use helpers provided by Evergreen to query app sources and determine file types and architecture. App objects may include additional properties such as `Architecture`, `Type`, `Channel`, and `Language`.
- Keep code minimal and repository-consistent. Avoid introducing unrelated abstractions or comments.
- Use lowercase PowerShell keywords and boolean/null constants.
- Preserve LF line endings and UTF-8 or ASCII encoding.

Manifests describe the app source and installation behavior. `Get.Update.Uri` may contain `#channel`, `#platform`, and `#version` placeholders substituted by the app function. `Install.Physical` and `Install.Virtual` can specify different installation arguments for physical and virtual desktop deployments.

## Validation expectations

Before finishing, verify that changes still align with the repository checks:

- PowerShell scripts in Apps should pass PSScriptAnalyzer with the rules in [.rules/PSScriptAnalyzerSettings.psd1](.rules/PSScriptAnalyzerSettings.psd1)
- JSON files in Manifests should remain valid JSON
- File types and encoding should remain consistent with the checks in [.github/workflows/validate.yml](.github/workflows/validate.yml)

The validation workflow runs PSScriptAnalyzer, checks file types and empty files, validates JSON syntax with `jq`, and checks UTF-8/ASCII encoding. The release workflow creates a versioned GitHub release containing `evergreen-apps.zip` and SHA256 hashes.

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
