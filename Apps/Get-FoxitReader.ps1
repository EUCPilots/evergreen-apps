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

    # Query the Foxit package download form to get the JSON
    $Metadata = Invoke-EvergreenRestMethod -Uri $res.Get.Update.Uri -Headers $res.Get.Update.Headers

    # Grab latest version. The property name is also the value
    if ([System.String]::IsNullOrEmpty($Metadata.data.version)) {
        Write-Warning -Message "$($MyInvocation.MyCommand): No version information found in the metadata."
        return
    }
    $VersionProperty = $Metadata.data.version | Get-Member | Where-Object { $_.MemberType -eq "NoteProperty" } | Select-Object -ExpandProperty "Name"
    $Version = $Metadata.data.version.$VersionProperty
    Write-Verbose -Message "$($MyInvocation.MyCommand): Found version: $Version."

    $FileTypes = $Metadata.data.package_type | Get-Member | Where-Object { $_.MemberType -eq "NoteProperty" } | Select-Object -ExpandProperty "Name"
    Write-Verbose -Message "$($MyInvocation.MyCommand): Found file types: $($FileTypes -join ", ")."

    # Loop through the file types defined in the manifest to build the download URLs
    foreach ($FileType in $FileTypes) {

         # Build the download URL; Follow the download link which will return a 301/302
        $DownloadUrl = $res.Get.Download.Uri -replace "#version", $Version -replace "#filetype", $FileType
        $Url = Invoke-EvergreenRestMethod -Uri $DownloadUrl -Headers $res.Get.Download.Headers

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
