function Get-GoogleChrome {
    <#
        .SYNOPSIS
            Returns the available Google Chrome versions across all platforms
            and channels by querying the official Google version JSON.

        .DESCRIPTION
            Queries fully rolled-out, unended releases per platform, falling back to active
            releases when a channel has no fully rolled-out version. Each channel uses the
            version with the latest first rollout start time, breaking ties by version.

        .NOTES
            Author: Aaron Parker
    #>
    [OutputType([System.Management.Automation.PSObject])]
    [CmdletBinding(SupportsShouldProcess = $false)]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateNotNull()]
        [System.Management.Automation.PSObject]
        $res = (Get-FunctionResource -AppName ("$($MyInvocation.MyCommand)".Split("-"))[1])
    )

    process {
        # Collect every page so release selection considers all intervals returned by the API.
        $GetReleases = {
            param (
                [string] $Uri,
                [string] $Platform,
                [string] $QueryDescription
            )
            $BaseUri = $Uri
            $ReleaseResults = [System.Collections.Generic.List[System.Object]]::new()
            do {
                Write-Verbose -Message "$($MyInvocation.MyCommand): Querying $QueryDescription releases: $Uri"
                $Response = Invoke-EvergreenRestMethod -Uri $Uri -ErrorAction Stop
                if ($null -ne $Response.PSObject.Properties["releases"]) {
                    foreach ($Release in $Response.releases) {
                        $ReleaseResults.Add($Release)
                    }
                }
                $PageToken = $null
                if ($null -ne $Response.PSObject.Properties["nextPageToken"]) {
                    $PageToken = $Response.nextPageToken
                }
                if ($PageToken) {
                    $Uri = "$BaseUri&pageToken=$([uri]::EscapeDataString($PageToken))"
                    Write-Verbose -Message "$($MyInvocation.MyCommand): More releases available for $Platform; waiting 200 milliseconds before requesting the next page."
                    Start-Sleep -Milliseconds 200
                }
            } while ($PageToken)
            $ReleaseResults.ToArray()
        }

        foreach ($Platform in $res.Get.Update.Platforms) {

            # Determine which channels have configured downloads for the current platform.
            $Channels = @($res.Get.Update.Channels | Where-Object {
                $ChannelDownloads = $res.Get.Download.Uri.$_
                if ($ChannelDownloads -is [System.Collections.IDictionary]) {
                    $ChannelDownloads.Contains($Platform) -and $ChannelDownloads[$Platform]
                }
                else {
                    $DownloadProperty = $ChannelDownloads.PSObject.Properties[$Platform]
                    $null -ne $DownloadProperty -and $DownloadProperty.Value
                }
            })
            if ($Channels.Count -eq 0) {
                Write-Verbose -Message "$($MyInvocation.MyCommand): Skipping platform $Platform; no configured downloads."
                continue
            }

            # Retrieve fully rolled-out releases for the current platform.
            Write-Verbose -Message "$($MyInvocation.MyCommand): Platform: $Platform. Channels: $($Channels -join ', ')."
            $BaseReleaseUri = $res.Get.Update.Uri -replace "#platform", $Platform
            $Releases = [System.Collections.Generic.List[System.Object]]::new()
            foreach ($Release in @(& $GetReleases -Uri $BaseReleaseUri -Platform $Platform -QueryDescription "fully rolled-out, unended")) {
                $Releases.Add($Release)
            }
            Write-Verbose -Message "$($MyInvocation.MyCommand): Retrieved $($Releases.Count) release intervals for $Platform."

            # Only retry channels absent from the complete-release response.
            $AvailableChannels = foreach ($Release in $Releases) {
                $Match = [regex]::Match($Release.name, "channels/(?<channel>[^/]+)/versions/[^/]+/releases")
                if ($Match.Success) {
                    $Match.Groups["channel"].Value
                }
            }

            # Determine which channels are missing from the fully rolled-out releases.
            $MissingChannels = @($Channels | Where-Object { $AvailableChannels -notcontains $_ })
            if ($MissingChannels.Count -gt 0) {
                # Remove the full-rollout fraction filter while keeping the unended-release filter.
                $FallbackUri = $BaseReleaseUri -replace "filter=fraction%3D1%2C", "filter="
                Write-Verbose -Message "$($MyInvocation.MyCommand): No fully rolled-out release for $($MissingChannels -join ', ')/$Platform; querying active releases."
                foreach ($Release in @(& $GetReleases -Uri $FallbackUri -Platform $Platform -QueryDescription "active")) {
                    $Match = [regex]::Match($Release.name, "channels/(?<channel>[^/]+)/versions/[^/]+/releases")
                    if ($Match.Success -and $MissingChannels -contains $Match.Groups["channel"].Value) {
                        $Releases.Add($Release)
                    }
                }
            }

            # Ignore malformed API entries rather than allowing one to invalidate usable releases.
            # Construct the final list of release rows for the current platform.
            $Rows = foreach ($Release in $Releases) {
                $Match = [regex]::Match($Release.name, "channels/(?<channel>[^/]+)/versions/[^/]+/releases")
                if (-not $Match.Success -or $Channels -notcontains $Match.Groups["channel"].Value) {
                    continue
                }
                if ([string]::IsNullOrWhiteSpace($Release.version)) {
                    Write-Warning -Message "$($MyInvocation.MyCommand): Missing release version for $Platform."
                    continue
                }
                if ([string]::IsNullOrWhiteSpace($Release.serving.startTime)) {
                    Write-Warning -Message "$($MyInvocation.MyCommand): Missing release start time for $Platform version $($Release.version)."
                    continue
                }
                [PSCustomObject] @{
                    Channel   = $Match.Groups["channel"].Value
                    Version   = $Release.version
                    StartTime = [DateTimeOffset]$Release.serving.startTime
                }
            }

            # A version can have multiple rollout intervals; use its first start time for ranking.
            $PerVersion = $Rows | Group-Object -Property Channel, Version | ForEach-Object {
                $_.Group | Sort-Object -Property StartTime | Select-Object -First 1
            }

            # Retain only the earliest start time for each channel/version combination.
            Write-Verbose -Message "$($MyInvocation.MyCommand): Retained $(@($PerVersion).Count) channel/version candidates for $Platform using each version's earliest rollout start time."
            foreach ($Channel in $Channels) {

                # Prefer the most recently started rollout, then the numerically highest version.
                $Release = $PerVersion | Where-Object Channel -eq $Channel |
                    Sort-Object -ErrorAction Stop -Property @(
                        @{ Expression = { $_.StartTime }; Descending = $true }
                        @{ Expression = { [version]$_.Version }; Descending = $true }
                    ) | Select-Object -First 1
                if ($null -eq $Release) {
                    Write-Warning -Message "$($MyInvocation.MyCommand): No fully rolled-out or active releases returned for $Channel/$Platform."
                    continue
                }
                Write-Verbose -Message "$($MyInvocation.MyCommand): Selected $Channel/$Platform version $($Release.Version), rollout start time $($Release.StartTime.ToString('o')); latest start time wins, with higher version breaking ties."
                $StartDate = ConvertTo-DateTime -DateTime $Release.StartTime.ToString("o")
                $DownloadUris = $res.Get.Download.Uri.$Channel.$Platform

                # Iterate over each download URI for the selected release and construct the output objects.
                foreach ($DownloadUri in $DownloadUris) {
                    Write-Verbose -Message "$($MyInvocation.MyCommand): $Channel/$Platform version $($Release.Version). Download URI: $DownloadUri"
                    [PSCustomObject] @{
                        Version      = $Release.Version
                        StartDate    = $StartDate
                        Channel      = $Channel
                        Architecture = Get-Architecture -String $Platform
                        Type         = Get-FileType -File $DownloadUri
                        URI          = $DownloadUri
                    }
                }
            }
        }
    }
}
