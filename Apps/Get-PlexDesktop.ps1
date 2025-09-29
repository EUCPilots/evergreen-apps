function Get-PlexDesktop {
    <#
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

    # Get the list of downloads
    $params = @{
        Uri = $res.Get.Download.Uri
    }
    $Content = Invoke-EvergreenRestMethod @params

    # Return a releases object to the pipeline
    foreach ($Release in $Content.computer.Windows.releases) {
        $PSObject = [PSCustomObject] @{
            Version      = $Content.computer.Windows.version
            Architecture = Get-Architecture -String $Release.build
            Checksum     = $Release.checksum
            URI          = $Release.url
        }
        Write-Output -InputObject $PSObject
    }
}
