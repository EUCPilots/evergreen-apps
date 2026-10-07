function Get-SublimeText {
    <#
        .SYNOPSIS
            Get the current version and download URL for Sublime Text.

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

    # Get the latest Sublime Text version
    $Updates = Invoke-EvergreenRestMethod -Uri $res.Get.Update.Uri

    # Construct the output; Return the custom object to the pipeline
    if ($null -ne $Updates) {

        # Extract and format the latest version number from the update information
        $Version = ([string]$Updates.latest_version).ToCharArray() -join "."

        $PSObject = [PSCustomObject] @{
            Version      = $Version
            Architecture = Get-Architecture -String $res.Get.Download.Uri
            Type         = Get-FileType -File $res.Get.Download.Uri
            URI          = $res.Get.Download.Uri -replace "#version", [string]$Updates.latest_version
        }
        Write-Output -InputObject $PSObject
    }
}
