function Get-GoogleChrome {
    <#
        .SYNOPSIS
            Returns the available Google Chrome versions across all platforms
            and channels by querying the official Google version JSON.

        .DESCRIPTION
            Queries versions per platform. Dates come from the newest currently serving
            release, or the newest historical release when none is currently serving.

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
        Write-Warning -Message "$($MyInvocation.MyCommand): The MSI file available for Stable and Extended channels are the same. The file version matches the Extended channel."
    }
    process {
        # Iterate through each channel defined in the manifest
        foreach ($Channel in $res.Get.Update.Channels) {
            Write-Verbose -Message "$($MyInvocation.MyCommand): Channel: $Channel."

            foreach ($Platform in $res.Get.Update.Platforms) {
                $DownloadUris = $res.Get.Download.Uri.$Channel.$Platform
                if (-not $DownloadUris) {
                    continue
                }

                $Versions = Invoke-EvergreenRestMethod -Uri ($res.Get.Update.Uri -replace "#platform", $Platform -replace "#channel", $Channel.ToLower())
                $LatestVersion = $Versions.versions | Select-Object -First 1 -ExpandProperty "version"
                if ([string]::IsNullOrWhiteSpace($LatestVersion)) {
                    throw "$($MyInvocation.MyCommand): No version returned for $Channel/$Platform."
                }

                $BaseReleaseUri = $res.Get.Update.ReleaseUri -replace "#platform", $Platform -replace "#channel", $Channel.ToLower() -replace "#version", $LatestVersion
                $ReleaseUri = $BaseReleaseUri
                $Releases = @()
                do {
                    $Response = Invoke-EvergreenRestMethod -Uri $ReleaseUri
                    $Releases += @($Response.releases)
                    $PageToken = $Response.nextPageToken
                    $ReleaseUri = if ($PageToken) {
                        "$BaseReleaseUri&pageToken=$([uri]::EscapeDataString($PageToken))"
                    }
                } while ($PageToken)

                if ($Releases.Count -eq 0 -or $null -eq $Releases[0]) {
                    throw "$($MyInvocation.MyCommand): No releases returned for $Channel/$Platform version $LatestVersion."
                }
                foreach ($Release in $Releases) {
                    if ([string]::IsNullOrWhiteSpace($Release.serving.startTime)) {
                        throw "$($MyInvocation.MyCommand): Missing release start time for $Channel/$Platform version $LatestVersion."
                    }
                }

                $Now = [DateTimeOffset]::UtcNow
                $Release = $Releases | Where-Object -ErrorAction Stop {
                    [DateTimeOffset]$_.serving.startTime -le $Now
                } | Sort-Object -ErrorAction Stop -Property @{
                    Expression = {
                        -not $_.serving.endTime -or [DateTimeOffset]$_.serving.endTime -gt $Now
                    }
                    Descending = $true
                }, @{
                    Expression = { [DateTimeOffset]$_.serving.startTime }
                    Descending = $true
                } | Select-Object -First 1
                if ($null -eq $Release) {
                    throw "$($MyInvocation.MyCommand): No started releases returned for $Channel/$Platform version $LatestVersion."
                }
                $StartDate = ConvertTo-DateTime -DateTime $Release.serving.startTime
                $EndDate = if ($Release.serving.endTime) {
                    ConvertTo-DateTime -DateTime $Release.serving.endTime
                }
                else {
                    "N/A"
                }

                foreach ($DownloadUri in $DownloadUris) {
                    Write-Verbose -Message "$($MyInvocation.MyCommand): Download URI: $DownloadUri"
                    [PSCustomObject] @{
                        Version      = $LatestVersion
                        StartDate    = $StartDate
                        EndDate      = $EndDate
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
