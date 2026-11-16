function Get-ClaudeDesktop {
    <#
        .SYNOPSIS
            Get the current version and download URL for Claude Desktop.

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

    # Get latest version and download latest release via update API
    $Guid = New-Guid
    foreach ($Architecture in $res.Get.Update.Architecture) {

        # Construct the update API URI for the current architecture
        $Uri = $res.Get.Update.Uri -f $Architecture, $Guid, $res.Get.Update.Version, (([System.Environment]::OSVersion.Version).ToString())
        $params = @{
            Uri       = $Uri
            UserAgent = $res.Get.Update.UserAgent
        }
        $Update = Invoke-EvergreenRestMethod @params
        if ($null -ne $Update -and $Update.releases.Count -gt 0) {

            # Output the object to the pipeline
            [PSCustomObject] @{
                Version      = $Update.releases[0].updateTo.version
                Date         = ConvertTo-DateTime -DateTime $Update.releases[0].updateTo.pub_date -AutoDetect
                Sha256       = $Update.releases[0].updateTo.sha256
                Size         = $Update.releases[0].updateTo.size
                Architecture = Get-Architecture -String $Architecture
                Type         = Get-FileType -File $Update.releases[0].updateTo.url
                URI          = $Update.releases[0].updateTo.url
            }
        }
    }
}
