function Get-OctopusDeployServer {
    <#
        .SYNOPSIS
            Get the current version and download URL for Octopus Deploy Server.

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

    # Get the version details from the update API
    $params = @{
        Uri         = $res.Get.Update.Uri
        ContentType = $res.Get.Update.ContentType
    }
    $Version = Invoke-EvergreenRestMethod @params
    Write-Verbose -Message "$($MyInvocation.MyCommand): Retrieved version $Version"

    $object = [PSCustomObject] @{
        Version = $Version
        URI     = $res.Get.Download.Uri -replace "#version", $Version
    }
    Write-Output -InputObject $object
}
