function Get-FontLab {
    <#
        .SYNOPSIS
            Returns the latest FontLab version number and download.

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
        foreach ($Item in $Update.Enclosure) {
            $Url = Resolve-SystemNetWebRequest -Uri $Item.url
            [PSCustomObject] @{
                Version      = $Item.version
                Architecture = Get-Architecture -String $Url.ResponseUri.AbsoluteUri
                Type         = Get-FileType -File $Url.ResponseUri.AbsoluteUri
                URI          = $Url.ResponseUri.AbsoluteUri
            }
        }
    }
}
