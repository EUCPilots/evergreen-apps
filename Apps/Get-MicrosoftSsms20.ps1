function Get-MicrosoftSsms20 {
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

    foreach ($language in $res.Get.Download.Language.GetEnumerator()) {
        # Follow the download link which will return a 301
        $Query = "&clcid="
        $Uri = "$($res.Get.Download.Uri)$($Query)$($res.Get.Download.Language[$language.key])"
        Write-Verbose -Message "$($MyInvocation.MyCommand): Resolving: $Uri"
        $ResolvedUrl = Resolve-SystemNetWebRequest -Uri $Uri

        if ($ResolvedUrl.ResponseUri -is [System.Uri]) {
            # Construct the output; Return the custom object to the pipeline
            $PSObject = [PSCustomObject] @{
                Version  = $res.Get.Download.Version
                Date     = $ResolvedUrl.LastModified.ToShortDateString()
                Language = $language.key
                Type     = Get-FileType -File $ResolvedUrl.ResponseUri.AbsoluteUri
                URI      = $ResolvedUrl.ResponseUri.AbsoluteUri
            }
            Write-Output -InputObject $PSObject
        }
    }
}
