function Get-MicrosoftSsms21 {
    <#
        .SYNOPSIS
            Returns the latest SQL Server Management Studio

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

    $ResolvedUrl = Resolve-SystemNetWebRequest -Uri $res.Get.Download.Uri
    if ($ResolvedUrl.ResponseUri -is [System.Uri]) {
        # Construct the output; Return the custom object to the pipeline
        $PSObject = [PSCustomObject] @{
            Version = $res.Get.Download.Version
            Date    = $ResolvedUrl.LastModified.ToShortDateString()
            Type    = Get-FileType -File $ResolvedUrl.ResponseUri.AbsoluteUri
            URI     = $ResolvedUrl.ResponseUri.AbsoluteUri
        }
        Write-Output -InputObject $PSObject
    }
}
