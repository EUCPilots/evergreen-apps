function Get-RiegeScopeRuntime {
    <#
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

    # Resolve the download URI
    foreach ($Uri in $res.Get.Download.Uri) {
        $Download = Resolve-SystemNetWebRequest -Uri $Uri
        if ($Download.ResponseUri.AbsoluteUri -match $res.Get.Download.MatchVersion) {
            $Version = $Matches[1]
            $DownloadUri = $Download.ResponseUri.AbsoluteUri
        }
        else {
            throw "Failed to match version from download URI: $($Download.ResponseUri.AbsoluteUri)"
        }
        [PSCustomObject]@{
            Version      = $Version -replace "_", "."
            Architecture = Get-Architecture -String $Download.ResponseUri.AbsoluteUri
            Type         = Get-FileType -File $Download.ResponseUri.AbsoluteUri
            URI          = $Download.ResponseUri.AbsoluteUri
        }
    }
}
