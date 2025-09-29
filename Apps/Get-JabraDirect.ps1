function Get-JabraDirect {
    <#
        .SYNOPSIS
            Returns the latest Jabra Direct version.

        .NOTES
            Author: Jasper Metselaar
            E-mail: jms@du.se
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Justification = "Product name is a plural")]
    [OutputType([System.Management.Automation.PSObject])]
    [CmdletBinding(SupportsShouldProcess = $false)]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateNotNull()]
        [System.Management.Automation.PSObject]
        $res = (Get-FunctionResource -AppName ("$($MyInvocation.MyCommand)".Split("-"))[1])
    )

    $Content = Invoke-EvergreenRestMethod -Uri $res.Get.Update.Uri
    if ($null -ne $Content) {

        $PSObject = [PSCustomObject] @{
            Version       = $Content.WindowsVersion
            Architecture  = "x64"
            Type          = Get-FileType -File $Content.WindowsDownload
            Sha256        = $Content.WindowsSHA256
            URI           = $Content.WindowsDownload
        }
        Write-Output -InputObject $PSObject
    }
}
