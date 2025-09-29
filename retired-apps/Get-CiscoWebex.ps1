function Get-CiscoWebEx {
    <#
        .SYNOPSIS
            Get the current version and download URL for Get-Cisco WebEx.

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

    # Get details from the download API
    $params = @{
        Uri         = $res.Get.Download.Uri
        ContentType = $res.Get.Download.ContentType
    }
    $object = Invoke-EvergreenRestMethod @params
    if ($null -ne $object) {

        # Desktop app
        $PSObject = [PSCustomObject] @{
            Version = $object.($res.Get.Download.Properties.Version)
            Type    = "Desktop"
            URI     = $object.($res.Get.Download.Properties.Desktop)
        }
        Write-Output -InputObject $PSObject

        # VDI plug-in
        $PSObject = [PSCustomObject] @{
            Version = $object.($res.Get.Download.Properties.Version)
            Type    = "VDI"
            URI     = $object.($res.Get.Download.Properties.VDI)
        }
        Write-Output -InputObject $PSObject
    }
}
