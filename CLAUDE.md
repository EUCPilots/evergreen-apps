# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

This repository provides **application functions** (PowerShell scripts) and **manifests** (JSON configs) for the [Evergreen](https://eucpilots.com/evergreen-docs) PowerShell module. Evergreen uses these to detect and download the latest versions of Windows applications.

## Local Development Setup

```powershell
# Point Evergreen at the local repo clone
$env:EVERGREEN_APPS_PATH = "/path/to/evergreen-apps"

# Import the Evergreen module (from PSGallery or local clone)
Import-Module -Name Evergreen -Force
# or
Import-Module -Name "/path/to/evergreen-module/Evergreen" -Force
```

## Testing an App Function

After setting `EVERGREEN_APPS_PATH` and importing the module, call the function directly:

```powershell
Get-MicrosoftEdge
Get-GoogleChrome
```

## Running PSScriptAnalyzer Locally

```powershell
Invoke-ScriptAnalyzer -Path "./Apps" -Recurse -Settings ".rules/PSScriptAnalyzerSettings.psd1"
```

## Architecture

### Directory Structure

- `Apps/` — One `.ps1` file per app, named `Get-<AppName>.ps1`, containing a single PowerShell function
- `Manifests/` — One `.json` file per app, named `<AppName>.json`, describing how to retrieve and install the app
- `retired-apps/` — Deprecated app definitions kept for reference
- `.rules/` — PSScriptAnalyzer settings and custom rules

### App Script Pattern (`Apps/Get-<AppName>.ps1`)

Every app script exports a single function `Get-<AppName>` that:

1. Takes a `$res` parameter that auto-loads its companion manifest via `Get-FunctionResource -AppName`
2. Calls helper functions (`Invoke-EvergreenRestMethod`, `Get-FileType`, `Get-Architecture`) provided by the Evergreen module
3. Outputs one or more `[PSCustomObject]` instances with consistent properties — always including `Version` and `URI`, plus optional fields like `Architecture`, `Type`, `Channel`, `Language`

```powershell
function Get-ExampleApp {
    [OutputType([System.Management.Automation.PSObject])]
    [CmdletBinding(SupportsShouldProcess = $false)]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateNotNull()]
        [System.Management.Automation.PSObject]
        $res = (Get-FunctionResource -AppName ("$($MyInvocation.MyCommand)".Split("-"))[1])
    )
    # ... query API, return [PSCustomObject] with Version, URI, etc.
}
```

### Manifest Pattern (`Manifests/<AppName>.json`)

```json
{
    "Name": "Display Name",
    "Source": "https://app-homepage.com",
    "Get": {
        "Update": { "Uri": "...", "Platforms": [...], "Channels": [...] },
        "Download": { "Uri": "..." }
    },
    "Install": {
        "Setup": "installer-glob*.msi",
        "Physical": { "Arguments": "...", "PostInstall": [] },
        "Virtual": { "Arguments": "...", "PostInstall": [] }
    }
}
```

- `Get.Update.Uri` may contain `#channel`, `#platform`, `#version` placeholders that the script substitutes
- `Install.Physical` vs `Install.Virtual` allow different install args for physical vs virtual desktop deployments

### CI/CD

**Validate workflow** (on PR to main, or push to non-main branches touching `Apps/` or `Manifests/`):
1. Runs PSScriptAnalyzer on all files in `Apps/`, uploads SARIF results
2. Validates file types (only `.ps1` in `Apps/`, only `.json` in `Manifests/`)
3. Checks for empty files
4. Validates JSON syntax with `jq`
5. Validates UTF-8/ASCII encoding for all `.ps1` and `.json` files

**Release workflow** (on PR merged to main): Creates a versioned GitHub release with `evergreen-apps.zip` and SHA256 hashes.

## Code Style Requirements

PSScriptAnalyzer is enforced in CI. Key custom rule: **`Measure-LowercaseKeyword`** — all PowerShell keywords and boolean constants must be lowercase:

```powershell
# Correct
function Get-App { }
if ($condition) { }
$value = $true
$null

# Wrong
Function Get-App { }
IF ($condition) { }
$TRUE
$NULL
```

All files must use **LF line endings** and **UTF-8 or ASCII encoding**.
