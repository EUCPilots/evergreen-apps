function Get-Dropbox {
    <#
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

    # Resolve the download URL for each architecture and return a formatted object
    foreach ($Architecture in $res.Get.Download.Architectures) {
        $ResolvedUrl = Resolve-SystemNetWebRequest -Uri ($res.Get.Download.Uri -replace "#architecture", $Architecture)
        if ($null -ne $ResolvedUrl) {

            # Extract the version from the resolved URL using the specified regex pattern
            $Version = $ResolvedUrl.ResponseUri.AbsoluteUri -match $res.Get.Download.MatchVersion | ForEach-Object { $Matches[1] }

            [PSCustomObject]@{
                Version      = $Version
                Date         = $ResolvedUrl.LastModified.ToShortDateString()
                Architecture = $Architecture
                Size         = $ResolvedUrl.ContentLength
                Filename     = ($ResolvedUrl.ResponseUri.AbsoluteUri -split "/")[-1] -replace "%20", " "
                URI          = $ResolvedUrl.ResponseUri.AbsoluteUri
            }
        }
    }
}
