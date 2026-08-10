function Get-reMarkable {
    <#
        .SYNOPSIS
            Get the current version and download URL for reMarkable.

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

    $update = Invoke-EvergreenRestMethod -Uri $res.Get.Update.Uri
    if ($null -ne $update) {

        $PSObject = [PSCustomObject] @{
            Version      = $update.enclosure.shortVersionString
            Architecture = Get-Architecture -String $update.enclosure.url
            Type         = Get-FileType -File $update.enclosure.url
            URI          = $update.enclosure.url
        }
        Write-Output -InputObject $PSObject
    }
}