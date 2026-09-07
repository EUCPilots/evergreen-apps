function Get-Obsidian {
    <#
        .SYNOPSIS
            Returns the latest Obsidian version number and download.

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

    # Get the latest release from the PowerShell metadata
    try {
        # Get details from the update feed
        $updateFeed = Invoke-EvergreenRestMethod -Uri $res.Get.Update.Uri
    }
    catch {
        throw "Failed to resolve metadata: $($res.Get.Update.Uri)."
    }

    # Pass the repo releases API URL and return a formatted object
    foreach ($Tag in $res.Get.Download.Tags) {
        Write-Verbose -Message "$($MyInvocation.MyCommand): Query release for tag: $Tag."
        $params = @{
            Uri          = "$($res.Get.Download.Uri)$($updateFeed.$Tag)"
            MatchVersion = $res.Get.Download.MatchVersion
            Filter       = $res.Get.Download.MatchFileTypes
        }
        $object = Get-GitHubRepoRelease @params
        Write-Output -InputObject $object
    }
}
