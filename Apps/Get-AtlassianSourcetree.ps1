function Get-AtlassianSourcetree {
    <#
        .SYNOPSIS
            Returns the available Atlassian Sourcetree versions and download URIs.

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

    # Read the update URI
    $params = @{
        Uri = $res.Get.Update.Uri
    }
    $Content = Invoke-EvergreenRestMethod @params

    # Read the JSON and build an array of platform, channel, version
    if ($null -ne $Content) {

        # Match version number
        try {
            $Lines = $Content -split "\n"
            $Version = [RegEx]::Match($Lines[0], $res.Get.Update.MatchVersion).Captures.Groups[1].Value
        }
        catch {
            $Version = "Unknown"
        }

        # Step through each installer type
        foreach ($item in $res.Get.Download.Uri.GetEnumerator()) {

            # Build the output object; Output object to the pipeline
            $Url = $res.Get.Download.Uri[$item.Key] -replace $res.Get.Download.ReplaceText, $Version
            $PSObject = [PSCustomObject] @{
                Version = $Version
                Type    = Get-FileType -File $Url
                URI     = $Url
            }
            Write-Output -InputObject $PSObject
        }
    }
}
