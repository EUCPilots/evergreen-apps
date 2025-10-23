#Requires -Module @{ ModuleName="Evergreen"; ModuleVersion="2510.2817.0" }
function Get-TrimbleSketchUp {
    <#
        .SYNOPSIS
            Returns the latest Trimble SketchUp version number and download.

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

    # Get the update details from the API
    $params = @{
        Uri       = $res.Get.Update.Uri
        UserAgent = $res.Get.Update.UserAgent
    }
    $Payload = Invoke-EvergreenRestMethod @params
    
    # Convert the JWT token payload
    $ConvertedPayload = ConvertFrom-Jwt -Token $Payload.token
    Write-Verbose -Message "$($MyInvocation.MyCommand): Found version: $($ConvertedPayload.Payload.versions.versionNumber)"
    Write-Verbose -Message "$($MyInvocation.MyCommand):     Found URL: $($ConvertedPayload.Payload.versions.installerUrl)"

    # Modify the URL to get the full installer
    $Url = $ConvertedPayload.Payload.versions.installerUrl -replace $res.Get.Download.ConvertUrl, '$1Full$2'
    Write-Verbose -Message "$($MyInvocation.MyCommand):  Converted to: $Url"

    # Build object and output to the pipeline
    $PSObject = [PSCustomObject] @{
        Version = $ConvertedPayload.Payload.versions.versionNumber
        Date    = ConvertTo-DateTime -DateTime $ConvertedPayload.Payload.versions.releaseDate -Pattern $res.Get.Update.DateTimePattern
        Type    = Get-FileType -File $Url
        URI     = $Url
    }
    Write-Output -InputObject $PSObject
}
