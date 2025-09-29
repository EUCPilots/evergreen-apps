function Get-VastLimitsUberAgent {
    <#
            .SYNOPSIS
                Get the current version and download URL for uberAgent.

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

    # Get latest version and download latest release via API
    $iwcParams = @{
        Uri         = $res.Get.Update.Uri
        ContentType = $res.Get.Update.ContentType
    }
    $Content = Invoke-EvergreenWebRequest @iwcParams

    # Construct the output; Return the custom object to the pipeline
    if ($null -ne $Content) {
        $PSObject = [PSCustomObject] @{
            Version = [RegEx]::Match($Content, $res.Get.Update.MatchVersion).Captures.Groups[1].Value
            URI     = $res.Get.Download.Uri -replace $res.Get.Download.ReplaceText, $Content
        }
        Write-Output -InputObject $PSObject
    }
}
