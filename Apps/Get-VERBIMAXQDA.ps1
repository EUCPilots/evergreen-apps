function Get-VERBIMAXQDA {
    <#
        .SYNOPSIS
            Returns the latest VERBI MAXQDA version number and download.

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

    # Get the latest version information from the update feed
    $Update = Invoke-EvergreenRestMethod -Uri $res.Get.Update.Uri
    if ($null -ne $Update) {
        [PSCustomObject]@{
            Version = $Update.enclosure.shortVersionString
            Size    = $Update.enclosure.length
            Type    = Get-FileType -File $Update.enclosure.url
            URI     = $Update.enclosure.url
        }
    }
}
