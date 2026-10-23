<#
.SYNOPSIS
Lists manifests whose latest GitHub release includes MSIX or AppX packages.

.DESCRIPTION
Finds GitHub repository API URLs anywhere in each manifest and checks the
latest stable release of each unique repository once. Outputs full manifest
paths, not asset URLs. API failures are reported on the error stream.

Only directly attached release assets are checked, not archive contents,
prereleases, older releases, vendor websites, or Microsoft Store listings.

.PARAMETER ManifestPath
Directory containing the manifests. Defaults to Manifests beside this script.

.PARAMETER GitHubToken
Optional GitHub token. Defaults to GH_TOKEN, then GITHUB_TOKEN. Authentication
is recommended to avoid GitHub's low unauthenticated API rate limit.

.EXAMPLE
./Get-GitHubPackageManifests.ps1

.EXAMPLE
./Get-GitHubPackageManifests.ps1 | Set-Content -Path ./matching-manifests.txt
#>
[CmdletBinding()]
[OutputType([string])]
param (
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$ManifestPath = (Join-Path -Path $PSScriptRoot -ChildPath "Manifests"),

    [Parameter(Mandatory = $false)]
    [string]$GitHubToken = $(if ($env:GH_TOKEN) { $env:GH_TOKEN } else { $env:GITHUB_TOKEN })
)

if (-not (Test-Path -LiteralPath $ManifestPath -PathType Container)) {
    throw "Manifest directory does not exist: $ManifestPath"
}

$headers = @{
    Accept = "application/vnd.github+json"
    "User-Agent" = "Evergreen-Manifest-Package-Check"
    "X-GitHub-Api-Version" = "2022-11-28"
}
if (-not [string]::IsNullOrWhiteSpace($GitHubToken)) {
    $headers.Authorization = "Bearer $GitHubToken"
}

$repositoryPattern = 'https://api\.github\.com/repos/(?<Repository>[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)(?=[/"?#\s]|$)'
$packagePattern = '\.(msix|msixbundle|appx|appxbundle)$'
$repositoryMatches = @{}
$manifests = Get-ChildItem -LiteralPath $ManifestPath -Filter "*.json" -File -ErrorAction Stop |
    Sort-Object -Property Name

foreach ($manifest in $manifests) {
    $content = Get-Content -LiteralPath $manifest.FullName -Raw -ErrorAction Stop
    $repositories = [regex]::Matches($content, $repositoryPattern) |
        ForEach-Object { $_.Groups["Repository"].Value } |
        Sort-Object -Unique

    foreach ($repository in $repositories) {
        if (-not $repositoryMatches.ContainsKey($repository)) {
            $uri = "https://api.github.com/repos/$repository/releases/latest"
            Write-Verbose "Checking $uri"
            try {
                $release = Invoke-RestMethod -Uri $uri -Headers $headers -TimeoutSec 30 -ErrorAction Stop
                $assets = @($release.assets | Where-Object { $_.name -match $packagePattern })
                $repositoryMatches[$repository] = ($assets.Count -gt 0)
            }
            catch {
                $repositoryMatches[$repository] = $null
                Write-Error -Message "Unable to check '$repository' at '$uri': $($_.Exception.Message)" -ErrorId "GitHubReleaseCheckFailed" -Category ResourceUnavailable -TargetObject $uri
            }
        }

        if ($repositoryMatches[$repository] -eq $true) {
            $manifest.FullName
            break
        }
    }
}
