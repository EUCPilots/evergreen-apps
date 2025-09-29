function Get-ControlUpConsole {
    <#
        .SYNOPSIS
            Gets the ControlUp console version and download URI

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

    # Query the ControlUp Agent JSON
    $Object = Invoke-EvergreenRestMethod -Uri $res.Get.Update.Uri
    if ($null -ne $Object) {

        # Build and array of the latest release and download URLs
        foreach ($item in $Object) {
            $PSObject = [PSCustomObject] @{
                Version      = $Object.($res.Get.Update.Properties.Version) -replace $res.Get.Update.ReplaceText, ""
                URI          = $Object.($res.Get.Update.Properties.Console).Trim()
            }
            Write-Output -InputObject $PSObject
        }
    }
}
