function Get-OctopusDeployServer {
    <#
        .SYNOPSIS
            Get the current version and download URL for Octopus Deploy Server.

        .NOTES
            Site: https://stealthpuppy.com
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

    # Get the version details from the update API
    $params = @{
        Uri         = $res.Get.Update.Uri
        ContentType = $res.Get.Update.ContentType
    }
    $versions = Invoke-EvergreenRestMethod @params

    if ($null -ne $versions) {
        $LatestVersion = $versions | Select-Object -Last 1
        $object = [PSCustomObject] @{
            Version = $LatestVersion.Version
            Date    = ConvertTo-DateTime -DateTime $LatestVersion.Released -Pattern $res.Get.Update.DateTimePattern
            URI     = $res.Get.Download.Uri -replace "#version", $LatestVersion.Version
        }
    }
    Write-Output -InputObject $object
}
