function Get-FoxitPDFEditor {
    <#
        .SYNOPSIS
            Get the current version and download URL for Foxit PDF Editor.

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

    # Configure the environment
    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::continue
    $InformationPreference = [System.Management.Automation.ActionPreference]::continue
    $ProgressPreference = [System.Management.Automation.ActionPreference]::SilentlyContinue
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072

    # Make an initial request without a cookie container because Foxit's token exceeds the Windows PowerShell cookie limit
    Write-Verbose -Message "$($MyInvocation.MyCommand): Make initial request to retrieve bearer token."
    $request = [System.Net.HttpWebRequest]::Create($res.Get.Update.InitialUri)
    $request.CookieContainer = $null
    $request.UserAgent = $script:resourceStrings.UserAgent.Base
    try {
        $response = [System.Net.HttpWebResponse]$request.GetResponse()
        $tokenCookie = @($response.Headers.GetValues('Set-Cookie')) |
        Where-Object { $_ -match '(?i)(?:^|[,;\s])token=([^;]*)' } |
        Select-Object -First 1
        $bearerToken = [regex]::Match($tokenCookie, '(?i)(?:^|[,;\s])token=([^;]*)').Groups[1].Value
    }
    catch {
        Write-Verbose -Message "$($MyInvocation.MyCommand): Failed to make initial request to retrieve bearer token."
    }
    finally {
        if ($null -ne $response) {
            $response.Dispose()
        }
    }

    if ($null -eq $bearerToken) {
        Write-Warning -Message "$($MyInvocation.MyCommand): Failed to retrieve bearer token from cookies."
        return
    }
    Write-Verbose -Message "$($MyInvocation.MyCommand): Retrieved bearer token from cookies."

    # Query the Foxit package download form to get the JSON
    $Metadata = Invoke-EvergreenRestMethod -Uri $res.Get.Update.Uri -Headers @{"authorization" = "Bearer $bearerToken" }

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
        $ResolvedUrl = Invoke-EvergreenRestMethod -Uri $DownloadUrl -Headers @{"authorization" = "Bearer $bearerToken" }
        Write-Verbose -Message "$($MyInvocation.MyCommand): Resolved URL to: $($ResolvedUrl.data)."
        $DownloadUrl = ($ResolvedUrl.data -split "\?")[0]
        Write-Verbose -Message "$($MyInvocation.MyCommand): Split URL to: $DownloadUrl."

        # Construct the output; Return the custom object to the pipeline
        $PSObject = [PSCustomObject] @{
            Version  = $Version
            Language = $res.Get.Download.Language
            Type     = Get-FileType -File $DownloadUrl
            URI      = $DownloadUrl
        }
        Write-Output -InputObject $PSObject
    }
}
