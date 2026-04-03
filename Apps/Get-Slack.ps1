function Get-Slack {
    <#
        .SYNOPSIS
            Get the current version and download URL for Slack.

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

    foreach ($Uri in $res.Get.Download.Uri) {

        # Follow the download link which will return a 301/302
        $redirectUrl = Resolve-SystemNetWebRequest -Uri $Uri
        $DownloadUrl = $redirectUrl.ResponseUri.AbsoluteUri

        # Match version number from the download URL
        try {
            $Version = [RegEx]::Match($DownloadUrl, $res.Get.MatchVersion).Captures.Groups[0].Value
        }
        catch {
            $Version = "Latest"
        }

        # Construct the output; Return the custom object to the pipeline
        $PSObject = [PSCustomObject] @{
            Version      = $Version
            Architecture = Get-Architecture -String $DownloadUrl
            Type         = Get-FileType -File $DownloadUrl
            URI          = $redirectUrl.ResponseUri.AbsoluteUri
        }
        Write-Output -InputObject $PSObject
    }
}
