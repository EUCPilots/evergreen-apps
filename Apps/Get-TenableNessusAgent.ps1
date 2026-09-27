function Get-TenableNessusAgent {
    <#
        .SYNOPSIS
            Returns the latest Tenable Nessus Agent version and download.

        .NOTES
            Author: ch0nx
    #>
    [OutputType([System.Management.Automation.PSObject])]
    [CmdletBinding(SupportsShouldProcess = $false)]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateNotNull()]
        [System.Management.Automation.PSObject]
        $res = (Get-FunctionResource -AppName ("$($MyInvocation.MyCommand)".Split("-"))[1])
    )

    $UpdateFeed = Invoke-EvergreenRestMethod -Uri $res.Get.Update.Uri
    if ($null -eq $UpdateFeed) {
        throw "$($MyInvocation.MyCommand): Failed to resolve update feed: $($res.Get.Update.Uri)."
    }

    # The versioned release property name changes each release, e.g. "Nessus Agents - 11.2.3"
    $Release = $UpdateFeed.releases.PSObject.Properties | `
        Where-Object { $_.Name -match $res.Get.Update.MatchProperty } | `
        Select-Object -First 1
    if ($null -eq $Release) {
        throw "$($MyInvocation.MyCommand): No release matched pattern: $($res.Get.Update.MatchProperty)."
    }

    foreach ($File in ($Release.Value | Where-Object { $_.file -match $res.Get.Update.MatchFileTypes })) {
        $PSObject = [PSCustomObject] @{
            Version      = $File.version
            Date         = ConvertTo-DateTime -DateTime $File.release_date -Pattern $res.Get.Update.DatePattern
            Architecture = Get-Architecture -String $File.file
            Type         = Get-FileType -File $File.file
            Size         = $File.size
            Md5          = $File.md5
            Sha256       = $File.sha256
            URI          = $File.file_url
        }
        Write-Output -InputObject $PSObject
    }
}
