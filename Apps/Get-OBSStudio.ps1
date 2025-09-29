function Get-OBSStudio {
    <#
        .SYNOPSIS
            Get the current version and download URI for OBS Studio.

        .NOTES
            Site: https://stealthpuppy.com
            Author: Aaron Parker

    #>
    [CmdletBinding(SupportsShouldProcess = $false)]
    [OutputType([System.Management.Automation.PSObject])]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateNotNull()]
        [System.Management.Automation.PSObject]
        $res = (Get-FunctionResource -AppName ("$($MyInvocation.MyCommand)".Split("-"))[1])
    )

    # Query the update feed
    $params = @{
        Uri         = $res.Get.Update.Uri
        ContentType = $res.Get.Update.ContentType
    }
    $Updates = Invoke-EvergreenRestMethod @params

    # Output the object to the pipeline
    if ($null -ne $Updates) {
        foreach ($Update in $Updates) {

            # Build the latest version number
            if ($Update.version_patch -eq 0) {
                # Handle edge case where binaries with version_patch of 0 are published with only major.minor version
                $Version = "$($Update.version_major).$($Update.version_minor)"
            } else {
                $Version = "$($Update.version_major).$($Update.version_minor).$($Update.version_patch)"
            }

            # Build the output object
            foreach ($Architecture in $res.Get.Download.Architectures) {
                $PSObject = [PSCustomObject] @{
                    Version      = $Version
                    Architecture = $Architecture
                    URI          = $res.Get.Download.Uri -replace $res.Get.Download.ReplaceText.FileName, $res.Get.Download.FileName `
                        -replace $res.Get.Download.ReplaceText.Version, $Version `
                        -replace $res.Get.Download.ReplaceText.Architecture, $Architecture
                }
                Write-Output -InputObject $PSObject
            }
        }
    }
}
