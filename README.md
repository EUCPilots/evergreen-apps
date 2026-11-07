# Evergreen Apps Repository

Welcome to the **Evergreen Apps** repo! This is repo hosts application functions and manifests for the Evergreen module.

## What is This Repo?

This repository hosts:

- **Application Functions**: The logic that powers Evergreen's supported application features.
- **Manifests**: Configuration files that describe how apps detection works.

Check out [Evergreen Documentation](https://eucpilots.com/evergreen) for detailed guides.

## How to Use

If you want to contribute to this project with fixes or new applications, set up your local environment as follows:

1. Install the [Evergreen](https://www.powershellgallery.com/packages/Evergreen/) module, or clone the [evergreen-module](https://github.com/EUCPilots/evergreen-module) repository.
2. Clone this repository.
3. Configure the Evergreen environment for local development by creating the `EVERGREEN_APPS_PATH` environment variable, pointing to the location of the local repository: [Set a custom cache location](https://eucpilots.com/evergreen/updateapps#set-a-custom-cache-location). For example:

```powershell
$env:EVERGREEN_APPS_PATH="C:\projects\evergreen-apps"
```

or

```powershell
$env:EVERGREEN_APPS_PATH="/Users/aaron/projects/_EUCPilots/evergreen-apps"
```

4. Import the Evergreen module, for example:

```powershell
Import-Module -Name Evergreen -Force
```

or

```powershell
Import-Module -Name "/Users/aaron/projects/_EUCPilots/evergreen-module/Evergreen" -Force
```

5. Implement your changes in a new branch and create a pull request.

## Delegate an Issue to GitHub Copilot

The [Evergreen App Maintainer](.github/agents/evergreen-app-maintainer.agent.md)
agent handles both existing application bugs and new application requests. It
reads [AGENTS.md](AGENTS.md) and [RULES.md](RULES.md), investigates the issue,
updates the app function and manifest as needed, and validates the local
definitions. New applications must have a viable public machine-readable
source; the agent reports a blocker rather than inventing one.

### One-time setup

1. Merge the agent configuration and
   [Copilot setup workflow](.github/workflows/copilot-setup-steps.yml) into the
   default branch so GitHub can discover them.
2. Ensure your account has access to Copilot cloud agent, the organization's
   Copilot policy permits it, and it is enabled for this repository. The person
   assigning an issue needs write access. Cloud runs consume Copilot usage and
   GitHub Actions resources according to your plan.
3. Run **Copilot setup steps** manually in Actions to verify that the runner can
   install Evergreen, PSScriptAnalyzer, and Pester from PSGallery. Setup uses
   Ubuntu's PowerShell 7 and read-only repository permissions; GitHub supplies
   the agent's separate task permissions. No dispatch token or additional
   repository secret is required.
4. If a required vendor API is blocked by the Copilot firewall, review the
   domain and configure the repository's Copilot network allowlist as needed.
   Do not disable the firewall or give the agent credentials for vendor sites.

### Start a run

1. Create or complete the app bug or new-application issue. Include the
   application name, vendor/source links, and reproduction details or the
   information requested by the new-app issue template.
2. Open **Assignees**, select **Copilot**, and choose **Evergreen App Maintainer**
   in the agent dropdown. Add any task-specific context in the optional prompt
   before confirming assignment.
3. Copilot works unattended on its own branch and opens a pull request. Review
   its diff, source evidence, validation results, and any blockers before
   merging. The agent is instructed not to merge or push to the default branch.
4. Send follow-up requests with `@copilot` **on the pull request**. Copilot
   receives the issue's existing comments at assignment time; later issue
   comments are not automatically included in that task.

This uses GitHub's native issue assignment, not a custom issue-comment trigger.
Mentioning the agent name or `@copilot` in an issue comment alone does not start
this workflow. VS Code's **Autopilot** mode is a local chat setting, not a switch
for cloud runs. GitHub may still require maintainer approval before running
Actions on an agent pull request. Missing source information or blocked
validation is reported for review rather than silently treated as success.

For Windows-specific behavior, run the existing
[Test Evergreen app workflow](.github/workflows/test-evergreen-app.yml) against
the agent's branch before merging.

See GitHub's documentation for
[assigning issues and selecting custom agents](https://docs.github.com/en/copilot/how-tos/copilot-on-github/use-copilot-agents/kick-off-a-task)
and [configuring the agent environment](https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/customize-cloud-agent/customize-the-agent-environment).

## Testing an Application on Windows

Run the [Test Evergreen app workflow](.github/workflows/test-evergreen-app.yml) manually
from the repository's Actions tab. Select a branch and enter an Evergreen application
name, such as `MicrosoftPowerAutomateDesktop`.

The workflow installs Evergreen from PSGallery on `windows-latest` and uses the
selected branch's application functions and manifests. Separate matrix jobs test
PowerShell 7 (`pwsh`) and Windows PowerShell 5.1 (`powershell`), and a failure in
one job does not cancel the other. The test step logs runner,
PowerShell, and module details, along with verbose application output. Results or
full error details and the script stack trace are also written to the run summary.
Errors and empty application results fail the job.
