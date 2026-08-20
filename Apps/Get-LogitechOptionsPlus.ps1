function Get-LogitechOptionsPlus {
    <#
        .SYNOPSIS
            Returns the latest Logitech Options+ version number and download.

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

    $Update = Invoke-EvergreenRestMethod -Uri $res.Get.Update.Uri
    if ($null -ne $Update) {
        [PSCustomObject] @{
            Version = $Update.version
            Date    = ConvertTo-DateTime -DateTime $Update.lastModified -Pattern $res.Get.Update.DatePattern
            Type    = Get-FileType -File $res.Get.Download.Uri
            URI     = $res.Get.Download.Uri
        }
    }
}
