function Get-KinoveaKinovea {
    <#
        .SYNOPSIS
            Returns the latest Kinovea version number and download.

        .NOTES
            Author: Aaron Parker
    #>
    [OutputType([System.Management.Automation.PSObject])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Justification = "Product name is a plural")]
    [CmdletBinding(SupportsShouldProcess = $false)]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateNotNull()]
        [System.Management.Automation.PSObject]
        $res = (Get-FunctionResource -AppName ("$($MyInvocation.MyCommand)".Split("-"))[1])
    )

    # Get the latest version of Kinovea via the latest tag on the repository
    $Tags = Get-GitHubRepoTag -Uri $res.Get.Update.Uri

    # Select the latest version
    $Version = $Tags | Sort-Object -Property @{ Expression = { [System.Version]$_.Tag }; Descending = $true } -ErrorAction "SilentlyContinue" | Select-Object -First 1

    # Build the output object
    if ($null -ne $Version) {
        $PSObject = [PSCustomObject] @{
            Version = $Version.Tag
            Type    = Get-FileType -File $res.Get.Download.Uri
            URI     = $res.Get.Download.Uri -replace $res.Get.Download.ReplaceText, $Version.Tag
        }
        Write-Output -InputObject $PSObject
    }
}
