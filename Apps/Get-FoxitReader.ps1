function Get-FoxitReader {
    <#
        .SYNOPSIS
            Get the current version and download URL for Foxit PDF Reader.

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

    # Make an initial request to the Foxit catalog page to establish a session and retrieve cookies
    Write-Verbose -Message "$($MyInvocation.MyCommand): Make initial request to retrieve bearer token."
    $response = Invoke-WebRequest -Uri $res.Get.Update.InitialUri -SessionVariable 'foxitSession' -UseBasicParsing
    $tokenCookie = $foxitSession.Cookies.GetCookies($res.Get.Update.CookieHost) | Where-Object { $_.Name -eq 'token' }
    $bearerToken = $tokenCookie.Value
    if ($null -eq $bearerToken) {
        Write-Warning -Message "$($MyInvocation.MyCommand): Failed to retrieve bearer token from cookies."
        return
    }
    Write-Verbose -Message "$($MyInvocation.MyCommand): Retrieved bearer token from cookies."

    # Query the Foxit package download form to get the JSON
    $Metadata = Invoke-EvergreenRestMethod -Uri $res.Get.Update.Uri -Headers @{"authorization" = "Bearer $bearerToken"}

    # Grab latest version. The property name is also the value
    if ($null -eq $Metadata.data.version) {
        Write-Warning -Message "$($MyInvocation.MyCommand): No version information found in the metadata."
        return
    }
    $VersionProperty = $Metadata.data.version.PSObject.Properties |
        Where-Object { $_.MemberType -eq 'NoteProperty' } |
        Select-Object -First 1 -ExpandProperty Name
    $Version = $Metadata.data.version.$VersionProperty
    Write-Verbose -Message "$($MyInvocation.MyCommand): Found version: $Version."

    $FileTypes = $Metadata.data.package_type.PSObject.Properties |
        Where-Object { $_.MemberType -eq 'NoteProperty' } |
        ForEach-Object { $_.Name }
    Write-Verbose -Message "$($MyInvocation.MyCommand): Found file types: $($FileTypes -join ", ")."

    # Loop through the file types from the API metadata to build the download URLs
    foreach ($FileType in $FileTypes) {

        # Build the download URL; Follow the download link which will return a 301/302
        $DownloadUrl = $res.Get.Download.Uri -replace "#version", $Version -replace "#filetype", $FileType
        $Url = Invoke-EvergreenRestMethod -Uri $DownloadUrl -Headers @{"authorization" = "Bearer $bearerToken"}

        # Construct the output; Return the custom object to the pipeline
        $PSObject = [PSCustomObject] @{
            Version  = $Version
            Language = $res.Get.Download.Language
            Type     = Get-FileType -File $Url.data
            URI      = $Url.data
        }
        Write-Output -InputObject $PSObject
    }
}
