function Get-AnacondaMiniconda {
    <#
        .SYNOPSIS
            Get the current version and download URL for Miniconda.

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

    # Construct the Miniconda repo uri; Query the repo to get the full list of files
    $Uri = $res.Get.Update.Uri -replace "#replace", $res.Get.Update.ReplaceFileList
    $updateFeed = Invoke-EvergreenRestMethod -Uri $Uri
    if ($null -ne $updateFeed) {

        # Grab the Windows files
        $FileNames = $updateFeed.PSObject.Properties.name -match $res.Get.MatchFileTypes
        $FileName = $FileNames | Select-Object -Last 1
        $LatestRelease = $updateFeed.$FileName
        $Version = [RegEx]::Matches($FileName, $res.Get.MatchVersion) | Select-Object -ExpandProperty "Value" -Unique

        # We need to rebase the timestamps from unix time, so need the Unix Epoch
        $UnixEpoch = ([System.DateTime] '1970-01-01Z').ToUniversalTime()

        # Build the output object for each release
        foreach ($Release in $LatestRelease) {
            # Construct the output; Return the custom object to the pipeline
            $PSObject = [PSCustomObject] @{
                Version      = $Version
                Architecture = Get-Architecture $Release
                Date         = $UnixEpoch.AddSeconds($LatestRelease.mtime)
                Size         = $LatestRelease.size
                Sha256       = $LatestRelease.sha256
                URI          = $res.Get.Update.Uri -replace "#replace", $FileName
            }
            Write-Output -InputObject $PSObject
        }
    }
}
