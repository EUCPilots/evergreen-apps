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
        Uri       = $res.Get.Update.Uri
        UserAgent = $res.Get.Update.UserAgent
    }
    $Update = Invoke-EvergreenRestMethod @params

    # Read the JSON and build an array of platform, channel, version
    if ($null -ne $Update) {
        # Step through each installer type
        foreach ($item in $Update) {

            # Build the output object; Output object to the pipeline
            $PSObject = [PSCustomObject] @{
                Version  = $item.Version
                Sha256   = $item.SHA256
                Type     = Get-FileType -File $item.Installer
                Filename = $item.Installer
                URI      = $item.URL
            }
            Write-Output -InputObject $PSObject
        }
    }
}
