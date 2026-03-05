function Get-AnysphereCursor {
    <#
        .SYNOPSIS
            Reads the Anysphere Cursor update API to retrieve available updates.

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
        $res = (Get-FunctionResource -AppName ("$($MyInvocation.MyCommand)".Split('-'))[1])
    )

    # Walk through each platform
    foreach ($platform in $res.Get.Update.Platform) {
        Write-Verbose -Message "$($MyInvocation.MyCommand): Getting release info for $platform."

        # Read the version details from the API, format and return to the pipeline
        $Uri = $res.Get.Update.Uri -replace "#platform", $platform.ToLower()
        $updateFeed = Invoke-EvergreenRestMethod -Uri $Uri -UserAgent $res.Get.Update.UserAgent
        if ($updateFeed) {
            $PSObject = [PSCustomObject] @{
                Version      = $updateFeed.version
                Platform     = $platform
                Architecture = (Get-Architecture -String $updateFeed.url) -replace "x86", "x64"
                URI          = $updateFeed.url
            }
            Write-Output -InputObject $PSObject
        }
    }
}
