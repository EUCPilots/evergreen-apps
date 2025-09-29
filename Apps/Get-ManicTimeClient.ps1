function Get-ManicTimeClient {
    <#
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

    $UpdateFeed = Invoke-EvergreenRestMethod -Uri $res.Get.Update.Uri
    if ($null -ne $UpdateFeed) {
        # Build the output object; Output object to the pipeline
        $PSObject = [PSCustomObject] @{
            Version = $UpdateFeed.version
            Date    = $UpdateFeed.releaseDate
            Type    = Get-FileType -File $UpdateFeed.downloadUrl
            URI     = $UpdateFeed.downloadUrl
        }
        Write-Output -InputObject $PSObject
    }
}
