function Get-SignalDesktop {
    <#
        .SYNOPSIS
            Returns details for Signal Desktop

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
        Uri               = $res.Get.Update.Uri
        MatchVersion      = $res.Get.Update.MatchVersion
        Filter            = $res.Get.Update.MatchFileTypes
        ReturnVersionOnly = $true
    }
    $object = Get-GitHubRepoRelease @params

    # Build the output object
    if ($null -ne $object) {
        $PSObject = [PSCustomObject] @{
            Version = $object.Version
            URI     = $res.Get.Download.Uri -replace $res.Get.Download.ReplaceText, $object.Version
        }
        Write-Output -InputObject $PSObject
    }
}
