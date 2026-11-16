function Get-BoxTools {
    <#
        .SYNOPSIS
            Get the current version and download URIs for the supported releases of Box Tools.
    #>
    [OutputType([System.Management.Automation.PSObject])]
    [CmdletBinding(SupportsShouldProcess = $false)]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateNotNull()]
        [System.Management.Automation.PSObject]
        $res = (Get-FunctionResource -AppName ("$($MyInvocation.MyCommand)".Split("-"))[1])
    )

    # Query the update feed for the current version and download URIs of Box Tools
    $params = @{
        Uri = $res.Get.Update.Uri
        # UserAgent = $res.Get.Update.UserAgent
    }
    $UpdateFeed = Invoke-EvergreenRestMethod @params

    # Construct the output object with the relevant information from the update feed
    [PSCustomObject] @{
        Version = $UpdateFeed.win.default.win_version
        Release = "User"
        Sha1    = $UpdateFeed.win.default.win_checksum
        Type    = Get-FileType -File $UpdateFeed.win.default.win_download_url
        URI     = $UpdateFeed.win.default.win_download_url
    }

    # Construct the output object for the admin release from the update feed
    [PSCustomObject] @{
        Version = $UpdateFeed.win.default.win_version
        Release = "Admin"
        Sha1    = $UpdateFeed.win.default.win_admin_checksum
        Type    = Get-FileType -File $UpdateFeed.win.default.win_admin_download_url
        URI     = $UpdateFeed.win.default.win_admin_download_url
    }
}
