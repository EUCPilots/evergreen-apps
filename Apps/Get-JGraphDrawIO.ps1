#Requires -Module @{ ModuleName="Evergreen"; ModuleVersion="2611.2877.1" }
function Get-JGraphDrawIO {
    <#
        .SYNOPSIS
            Returns the latest JGraph DrawIO / diagrams.net version number and download.

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

    # Pass the repo releases API URL and return a formatted object
    $params = @{
        Uri          = $res.Get.Uri
        MatchVersion = $res.Get.MatchVersion
        Filter       = $res.Get.MatchFileTypes
    }
    Get-GitHubRepoRelease @params | Set-ObjectProperty -PropertyName "Architecture" -CurrentValue "x86" -Value "x64" 
}
