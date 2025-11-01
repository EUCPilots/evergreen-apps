function Get-CanvaAffinity {
    <#
        .SYNOPSIS
            Returns the latest available Canva Affinity version.

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

    # Get details from the update API
    $params = @{
        Uri       = $res.Get.Update.Uri
        UserAgent = $res.Get.Update.UserAgent
    }
    $Update = Invoke-EvergreenRestMethod @params
    foreach ($Url in $res.Get.Download.Uri) {
        [PSCustomObject]@{
            Version      = $Update.Version
            Architecture = Get-Architecture -String $Url
            Type         = Get-FileType -File $Url
            URI          = $Url
        }
    }
}
