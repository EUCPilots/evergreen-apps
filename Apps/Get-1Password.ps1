function Get-1Password {
    <#
        .SYNOPSIS
            Get the current version and download URL for 1Password 8 and later.

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

    # Get latest version and download latest release via update API
    $params = @{
        Uri         = $res.Get.Update.Uri
        ContentType = $res.Get.Update.ContentType
    }
    $updateFeed = Invoke-EvergreenRestMethod @params
    if ($updateFeed.available -eq 1) {

        # Output the object to the pipeline from the update feed
        foreach ($item in $updateFeed) {

            $PSObject = [PSCustomObject] @{
                Version = $item.version
                Type    = Get-FileType -File $res.Get.Download.Uri["msi"]
                URI     = $res.Get.Download.Uri["msi"]
            }
            Write-Output -InputObject $PSObject
        }

        # Output the MSI version of the 1Password installer
        $PSObject = [PSCustomObject] @{
            Version = $item.version
            Type    = Get-FileType -File $res.Get.Download.Uri["exe"]
            URI     = $res.Get.Download.Uri["exe"]
        }
        Write-Output -InputObject $PSObject

        # Output the MSIX version of the 1Password installer
        $PSObject = [PSCustomObject] @{
            Version = $item.version
            Type    = Get-FileType -File $res.Get.Download.Uri["msix"]
            URI     = $res.Get.Download.Uri["msix"]
        }
        Write-Output -InputObject $PSObject
    }
}
