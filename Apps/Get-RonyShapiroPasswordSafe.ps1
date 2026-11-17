function Get-RonyShapiroPasswordSafe {
    <#
        .SYNOPSIS
            Returns the latest Rony Shapiro Password Safe version number and download.

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
    $object = Get-GitHubRepoRelease @params

    # Select the latest version from the objects returned from the repo
    $Version = $object.Version | Sort-Object -Property { [version]$_ } -Descending | Select-Object -First 1
    $object | where-Object { $_.Version -eq $Version }
}
