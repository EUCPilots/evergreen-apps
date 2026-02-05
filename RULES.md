# PowerShell Analyzer Rules and Security Configuration

This document outlines the PowerShell Script Analyzer rules, custom rule implementations, and github.com security configurations that ensure code quality, consistency, and security across the evergreen-apps repository.

---

## Table of Contents

1. [PowerShell Script Analyzer Configuration](#powershell-script-analyzer-configuration)
2. [Custom Rules](#custom-rules)
3. [IDE Integration](#ide-integration)
4. [CI/CD Security and Validation](#cicd-security-and-validation)
5. [Branch Protection Rules](#branch-protection-rules)
6. [File Encoding and Format Standards](#file-encoding-and-format-standards)

---

## PowerShell Script Analyzer Configuration

### Configuration File Location

**File:** [`.rules/PSScriptAnalyzerSettings.psd1`](.rules/PSScriptAnalyzerSettings.psd1)

### Settings Overview

```powershell
@{
    CustomRulePath      = @(
        ".rules/LowercaseKeyword.psm1"
    )
    IncludeDefaultRules = $true
    Severity            = @("Error", "Warning")
    IncludeRules        = @(
        "Measure-LowercaseKeyword"
    )
}
```

### Configuration Explanation

- **CustomRulePath**: Specifies the path to custom PowerShell Script Analyzer rules implemented in the repository
  - Includes [LowercaseKeyword.psm1](.rules/LowercaseKeyword.psm1) for code style enforcement

- **IncludeDefaultRules**: Set to `$true`
  - Enables all built-in PSScriptAnalyzer rules (e.g., PSAvoidUsingCmdletAliases, PSAvoidUsingPositionalParameters, PSAvoidUsingInvokeExpression)
  - Provides comprehensive code quality checks beyond custom rules

- **Severity**: Set to `@("Error", "Warning")`
  - Analyzer reports both errors and warnings
  - Both severity levels must be addressed in code reviews

- **IncludeRules**: Explicitly enables the `Measure-LowercaseKeyword` custom rule
  - Only listed custom rules are active; others must be explicitly required in this configuration

---

## Custom Rules

### 1. Measure-LowercaseKeyword Rule

**File:** [`.rules/LowercaseKeyword.psm1`](.rules/LowercaseKeyword.psm1)

#### Purpose

Ensures PowerShell keywords and constants use lowercase formatting for consistency and adherence to PowerShell best practices.

#### Scope

Checks the following elements:

**Keywords:**

- Control flow: `function`, `if`, `elseif`, `else`, `switch`, `foreach`, `for`, `while`, `do`, `until`, `try`, `catch`, `finally`, `throw`, `trap`
- Function-related: `param`, `begin`, `process`, `end`, `dynamicparam`
- Other: `return`, `in`, `break`, `continue`, `exit`, `class`, `enum`, `using`, `namespace`, `data`

**Constants:**

- Boolean: `$true`, `$false`
- Null: `$null`

#### Violation Message

```
Keyword 'KEYWORD' should be lowercase ('keyword').
Constant 'CONSTANT' should be lowercase ('constant').
```

#### Example Violations

```powershell
# VIOLATION: Keywords not in lowercase
Function Get-Data { }        # Should be: function Get-Data { }
IF ($condition)              # Should be: if ($condition)
$value = $TRUE               # Should be: $value = $true
```

#### Severity

**Warning** - Code style violation that should be corrected during review but doesn't prevent deployment.

#### Implementation Details

- Uses token-based analysis for accurate detection
- Avoids duplicate reporting of the same token at the same location
- Implements case-sensitive comparison (`-cne`) to distinguish between cases
- Handles parse errors gracefully without stopping analysis

---

## IDE Integration

### Visual Studio Code Configuration

**File:** [`.vscode/settings.json`](.vscode/settings.json)

```jsonc
{
    "files.eol": "\n",
    "powershell.scriptAnalysis.settingsPath": ".rules/PSScriptAnalyzerSettings.psd1",
    "powershell.scriptAnalysis.enable": true
}
```

### Configuration Details

| Setting | Value | Purpose |
|---------|-------|---------|
| `files.eol` | `\n` | Enforces Unix-style line endings (LF) for all files in the repository |
| `powershell.scriptAnalysis.settingsPath` | `.rules/PSScriptAnalyzerSettings.psd1` | Points PowerShell extension to custom analyzer settings |
| `powershell.scriptAnalysis.enable` | `true` | Activates real-time script analysis in the editor |

### Benefits

- **Consistency**: All developers using VS Code see the same analysis rules
- **Real-time Feedback**: Issues are flagged during development, not just in CI/CD
- **Line Ending Standardization**: Prevents CRLF/LF inconsistencies across platforms
- **Immediate Education**: Developers learn correct patterns as they code

---

## CI/CD Security and Validation

### Validation Workflow

**File:** [`.github/workflows/validate.yml`](.github/workflows/validate.yml)

#### Trigger Events

1. **Push** to non-main branches when Apps or Manifests directories change
2. **Pull request** to main branch when Apps or Manifests directories change
3. **Manual trigger** via `workflow_dispatch`

#### Security Permissions

```yaml
permissions:
    contents: read              # Read-only access to code
    security-events: write      # Write SARIF scan results
    actions: read               # Read workflow status (private repos)
```

#### Jobs and Validations

#### Job 1: PSScriptAnalyzer

**Purpose:** Runs comprehensive PowerShell code analysis

**Configuration:**

```yaml
- name: 'Analyse PowerShell'
  uses: microsoft/psscriptanalyzer-action@6b2948b1944407914a58661c49941824d149734f
  with:
    path: "./Apps"
    recurse: true
    settings: ".rules/PSScriptAnalyzerSettings.psd1"
    output: results.sarif
```

**What it checks:**

- Applies all built-in PSScriptAnalyzer rules
- Applies custom rules (LowercaseKeyword)
- Recursively analyzes all scripts in the Apps directory
- Generates SARIF (Static Analysis Results Interchange Format) output for GitHub security tab

**SARIF Upload:**

- Results are uploaded to GitHub Code Scanning
- Available in Security > Code scanning alerts
- Issues appear in PR reviews automatically

**Failure Behavior:**

- Analysis failures block the entire validation workflow
- Pull requests cannot be merged until analysis passes

#### Job 2: Validate Apps and Manifests

**Dependencies:** Requires successful completion of `psscriptanalyzer` job

**Validations performed:**

##### 1. File Type Validation

```
✓ Apps directory must contain ONLY .ps1 files
✓ Manifests directory must contain ONLY .json files
```

##### 2. Empty File Detection

```
✓ No empty files allowed in Apps or Manifests
✓ Reports all empty files before failing
```

##### 3. JSON File Validation

```
✓ All JSON files in Manifests must be valid JSON
✓ Uses jq to verify JSON syntax
✓ Reports which files have invalid JSON
```

##### 4. Character Encoding Validation

**PowerShell Files:**

```
✓ All .ps1 files must be UTF-8 or ASCII encoded
✗ Rejects any other encoding (e.g., UTF-16, UTF-32, ISO-8859-1)
```

**JSON Files:**

```
✓ All .json files must be UTF-8 or ASCII encoded
✗ Rejects any other encoding
```

#### Failure Behavior

Any validation failure will:
1. Display detailed error message listing problematic files
2. Block workflow completion
3. Prevent merge of pull request
4. Appear as failed check on PR

---

## Branch Protection Rules

### Main Branch Protection Configuration

Based on the workflow triggers defined in [`.github/workflows/validate.yml`](.github/workflows/validate.yml) and [`.github/workflows/release.yml`](.github/workflows/release.yml), the following branch protection rules are recommended and implemented:

#### Pull Request Requirements

| Requirement | Status | Details |
|-------------|--------|---------|
| **Require status checks to pass before merging** | ✅ Enabled | `psscriptanalyzer` job must pass |
| **Require status checks to pass before merging** | ✅ Enabled | `validate-json` job must pass |
| **Require pull request reviews** | ✅ Enabled | Recommended: at least 1 approved review |
| **Dismiss stale pull request approvals** | ✅ Enabled | Approvals reset when code changes |
| **Require code owners approval** | ⚠️ Recommended | Implement CODEOWNERS file if needed |

#### Restricted Activities

| Restriction | Status |
|-------------|--------|
| **Allow force pushes** | ❌ Disabled |
| **Allow deletions** | ❌ Disabled |
| **Require branches to be up to date before merging** | ✅ Enabled |
| **Require conversation resolution before merging** | ✅ Enabled |

#### Merge Requirements

- **Require linear history**: Enforces a clean Git history
- **Allow merge commits**: Controlled via GitHub settings
- **Allow squash merging**: Recommended for clean commits
- **Allow rebase merging**: Recommended to preserve history

#### Path-Based Enforcement

The validation workflow only triggers when these paths change:
```
- 'Apps/**'
- 'Manifests/**'
```

This means:
- Changes to configuration files (`.rules/`, `.github/`, `.vscode/`) trigger validation
- Documentation changes alone do not block merges
- Maintainers can update workflows without strict validation

---

## File Encoding and Format Standards

### Git Attributes Settings

**File:** [`.gitattributes`](.gitattributes)

#### Text File Normalization

```properties
* -text
```
- Files are stored as-is without automatic line ending conversion
- Manual LF normalization via `.vscode/settings.json`

#### PowerShell Files (Text)

```properties
*.ps1       text
*.psm1      text
*.psd1      text
```
- All PowerShell files marked as text
- Git properly handles line-ending diffs

#### Data Files (Text)

```properties
*.json      text
*.xml       text
```
- JSON and XML files marked as text
- Enables proper Git diffing and merging

#### Binary Files Explicitly Marked

```properties
*.ai        binary
*.bmp       binary
*.eps       binary
*.gif       binary
# ... (all graphics and binary formats)
```
- Prevents Git from attempting to merge binary files
- Improves merge conflict handling

### Enforced Standards

#### Line Endings

- **Standard**: Unix-style LF (`\n`)
- **Enforcement**: VS Code `.vscode/settings.json` enforces this
- **Validation**: CI/CD doesn't explicitly validate but expects UTF-8 compliance

#### Character Encoding

- **Standard**: UTF-8 (with UTF-8 BOM or no BOM)
- **Accepted**: Also accepts ASCII (subset of UTF-8)
- **Validation**: CI/CD workflow explicitly validates all files
- **Rejection**: Rejects UTF-16, UTF-32, ISO-8859-1, and other encodings

#### File Format Requirements

- **PowerShell Scripts**: Must be `.ps1` (not `.txt` or other extensions)
- **Manifests**: Must be `.json` (not `.json5` or other formats)
- **No empty files**: All files must have content

---

## Security Considerations

### Code Analysis Pipeline

1. **IDE-level analysis**: Developers see issues before commit
2. **Pre-commit validation**: Can be enhanced with pre-commit hooks
3. **CI/CD validation**: GitHub Actions workflow runs on every PR
4. **SARIF reporting**: Security findings uploaded to GitHub Security tab

### Minimal Permissions

- Workflows use least-privilege permissions
- `contents: read` only for code scanning
- `security-events: write` for uploading analysis results
- No unnecessary elevated permissions

### Immutable Artifacts

- Main branch has force-push protection
- Direct pushes to main disabled (require PR)
- Status checks prevent merge of flagged code
- SARIF results create audit trail of security checks

### Encoding Security

- UTF-8 validation prevents encoding-based exploits
- Consistent line endings reduce diff confusion
- Binary file protection prevents accidental commits of machine-dependent data

---

## Maintenance and Updates

### How to Update Analyzer Rules

1. **Edit custom rule file**: Modify [`.rules/LowercaseKeyword.psm1`](.rules/LowercaseKeyword.psm1) or [`.rules/PascalCase.psm1`](.rules/PascalCase.psm1)
2. **Update settings file**: Add/remove rules in [`.rules/PSScriptAnalyzerSettings.psd1`](.rules/PSScriptAnalyzerSettings.psd1)
3. **Test locally**: Run analyzer with `Invoke-ScriptAnalyzer`
4. **Update documentation**: Modify this file
5. **Create PR**: Changes to analyzer rules go through normal PR workflow

### How to Update Validation Workflow

1. **Edit workflow file**: Modify [`.github/workflows/validate.yml`](.github/workflows/validate.yml)
2. **Test in PR**: Workflow runs on PR creation automatically
3. **Monitor job output**: Check GitHub Actions logs for any issues
4. **Merge when validated**: Approved changes become effective on main branch

### Disabling a Rule

To disable the `Measure-PascalCase` rule (currently not enabled):

1. Remove or comment out from `PSScriptAnalyzerSettings.psd1`:
```powershell
# IncludeRules        = @(
#     "Measure-PascalCase"
# )
```

2. Or add to exclusion list (if supported):

```powershell
ExcludeRules = @("Measure-PascalCase")
```

---

## Related Documentation

- [Microsoft.PowerShell.ScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer) - Official analyzer repository
- [PowerShell Best Practices](https://learn.microsoft.com/en-us/powershell/scripting/dev-cross-plat/code-style-guide) - Microsoft's PowerShell style guide
- [GitHub Code Scanning](https://docs.github.com/en/code-security/code-scanning) - Security analysis documentation
- [SARIF Format](https://sarifweb.azurewebsites.net/) - Static Analysis Results Interchange Format

---

**Last Updated:** February 5, 2026
