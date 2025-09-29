function Get-MasterPackager {
    <#
        .SYNOPSIS
            Returns the available Master Packager versions and download URIs.

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
    $Version = Invoke-EvergreenRestMethod @params

    # Read the JSON and build an array of platform, channel, version
    if ($null -ne $Version) {

        # Step through each installer type
        foreach ($item in $res.Get.Download.Uri.GetEnumerator()) {

            # Build the output object; Output object to the pipeline
            $PSObject = [PSCustomObject] @{
                Version = $Version
                Type    = $item.Name
                URI     = $res.Get.Download.Uri[$item.Key] -replace $res.Get.Download.ReplaceText.Version, $Version
            }
            Write-Output -InputObject $PSObject
        }
    }
}
