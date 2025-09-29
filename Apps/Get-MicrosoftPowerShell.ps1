function Get-MicrosoftPowerShell {
    <#
        .SYNOPSIS
            Returns the latest PowerShell version number and download.

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
        Throw "Failed to resolve metadata: $($res.Get.Update.Uri)."
        Break
    }

    # Query the releases API for each release tag specified in the manifest
    foreach ($release in $res.Get.Download.Tags.GetEnumerator()) {

        # Determine the tag
        $Tags = $updateFeed.($res.Get.Download.Tags[$release.key])
        Write-Verbose -Message "$($MyInvocation.MyCommand): Query release for tag: $Tag."

        # Pass the repo releases API URL and return a formatted object
        foreach ($Tag in $Tags) {
            $params = @{
                Uri          = "$($res.Get.Download.Uri)$($Tag)"
                MatchVersion = $res.Get.Download.MatchVersion
                Filter       = $res.Get.Download.MatchFileTypes
            }
            $object = Get-GitHubRepoRelease @params

            # Add the Release property to the object returned from Get-GitHubRepoRelease
            $object | Add-Member -MemberType "NoteProperty" -Name "Release" -Value $release.Name
            Write-Output -InputObject $object
        }
    }
}
