function Get-Scratch {
    <#
        .SYNOPSIS
            Get the current version and download URL for Scratch.

        .NOTES
            Author: Andrew Cooper
            Twitter: @adotcoop
            Get-Scratch.ps1 based on Get-TelerikFiddlerEverywhere.ps1
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
