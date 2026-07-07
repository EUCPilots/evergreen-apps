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
    foreach ($Uri in $res.Get.Update.Uri) {
        $params = @{
            Uri       = $Uri
            UserAgent = $script:resourceStrings.UserAgent.Base
        }
        $Update = Invoke-EvergreenRestMethod @params
        if ($null -ne $Update) {

            # Output the object to the pipeline
            [PSCustomObject] @{
                Version      = $Update.version
                Architecture = Get-Architecture -String $Update.url
                Type         = Get-FileType -File $Update.url
                URI          = $Update.url
            }
        }
    }
}
