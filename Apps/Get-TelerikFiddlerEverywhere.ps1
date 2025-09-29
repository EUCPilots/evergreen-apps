function Get-TelerikFiddlerEverywhere {
    <#
        .SYNOPSIS
            Get the current version and download URL for Telerik Fiddler Everywhere.

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

    # Get the latest download
    $Response = Resolve-SystemNetWebRequest -Uri $res.Get.Download.Uri

    # Construct the output; Return the custom object to the pipeline
    if ($null -ne $Response) {
        $PSObject = [PSCustomObject] @{
            Version = [RegEx]::Match($Response.ResponseUri.LocalPath, $res.Get.Download.MatchVersion).Captures.Groups[1].Value
            URI     = $Response.ResponseUri.AbsoluteUri
        }
        Write-Output -InputObject $PSObject
    }
}
