function Get-GoogleChrome {
    <#
        .SYNOPSIS
            Returns the available Google Chrome versions across all platforms
            and channels by querying the official Google version JSON.

        .DESCRIPTION
            Queries fully rolled-out, unended releases per platform. Each channel uses
            the version with the latest first rollout start time, breaking ties by version.

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

    begin {
        #Write-Warning -Message "$($MyInvocation.MyCommand): The MSI file available for Stable may not match the version returned for Stable."
    }
    process {
        foreach ($Platform in $res.Get.Update.Platforms) {
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

            Write-Verbose -Message "$($MyInvocation.MyCommand): Platform: $Platform. Channels: $($Channels -join ', ')."
            $BaseReleaseUri = $res.Get.Update.Uri -replace "#platform", $Platform
            $ReleaseUri = $BaseReleaseUri
            $Releases = [System.Collections.Generic.List[System.Object]]::new()
            do {
                Write-Verbose -Message "$($MyInvocation.MyCommand): Querying fully rolled-out, unended releases: $ReleaseUri"
                $Response = Invoke-EvergreenRestMethod -Uri $ReleaseUri -ErrorAction Stop
                if ($null -ne $Response.PSObject.Properties["releases"]) {
                    foreach ($Release in $Response.releases) {
                        $Releases.Add($Release)
                    }
                }
                $PageToken = $null
                if ($null -ne $Response.PSObject.Properties["nextPageToken"]) {
                    $PageToken = $Response.nextPageToken
                }
                if ($PageToken) {
                    $ReleaseUri = "$BaseReleaseUri&pageToken=$([uri]::EscapeDataString($PageToken))"
                    Write-Verbose -Message "$($MyInvocation.MyCommand): More releases available for $Platform; waiting 200 milliseconds before requesting the next page."
                    Start-Sleep -Milliseconds 200
                }
            } while ($PageToken)
            Write-Verbose -Message "$($MyInvocation.MyCommand): Retrieved $($Releases.Count) release intervals for $Platform."

            $Rows = foreach ($Release in $Releases) {
                $Match = [regex]::Match($Release.name, "channels/(?<channel>[^/]+)/versions/[^/]+/releases")
                if (-not $Match.Success -or $Channels -notcontains $Match.Groups["channel"].Value) {
                    continue
                }
                if ([string]::IsNullOrWhiteSpace($Release.version)) {
                    throw "$($MyInvocation.MyCommand): Missing release version for $Platform."
                }
                if ([string]::IsNullOrWhiteSpace($Release.serving.startTime)) {
                    throw "$($MyInvocation.MyCommand): Missing release start time for $Platform version $($Release.version)."
                }
                [PSCustomObject] @{
                    Channel   = $Match.Groups["channel"].Value
                    Version   = $Release.version
                    StartTime = [DateTimeOffset]$Release.serving.startTime
                }
            }

            # A version can have multiple rollout intervals; use its first start time.
            $PerVersion = $Rows | Group-Object -Property Channel, Version | ForEach-Object {
                $_.Group | Sort-Object -Property StartTime | Select-Object -First 1
            }
            Write-Verbose -Message "$($MyInvocation.MyCommand): Retained $(@($PerVersion).Count) channel/version candidates for $Platform using each version's earliest rollout start time."
            foreach ($Channel in $Channels) {
                $Release = $PerVersion | Where-Object Channel -eq $Channel |
                    Sort-Object -ErrorAction Stop -Property @(
                        @{ Expression = { $_.StartTime }; Descending = $true }
                        @{ Expression = { [version]$_.Version }; Descending = $true }
                    ) | Select-Object -First 1
                if ($null -eq $Release) {
                    throw "$($MyInvocation.MyCommand): No fully rolled-out releases returned for $Channel/$Platform."
                }
                Write-Verbose -Message "$($MyInvocation.MyCommand): Selected $Channel/$Platform version $($Release.Version), rollout start time $($Release.StartTime.ToString('o')); latest start time wins, with higher version breaking ties."
                $StartDate = ConvertTo-DateTime -DateTime $Release.StartTime.ToString("o")
                $DownloadUris = $res.Get.Download.Uri.$Channel.$Platform

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
