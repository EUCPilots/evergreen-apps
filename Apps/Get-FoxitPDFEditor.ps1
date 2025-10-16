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

    # Query the Foxit package download form to get the JSON
    $UpdateFeed = Invoke-EvergreenRestMethod -Uri $res.Get.Update.Uri

    # Grab latest version. Removed Sort-Object because Foxit moved to a 5 part version number
    $BigVersion = $UpdateFeed.package_info.big_version | Select-Object -First 1
    Write-Verbose -Message "$($MyInvocation.MyCommand): Found 'big' version: $BigVersion."

    # Match version using the .package_info.down property
    if ($null -ne $UpdateFeed.package_info.version[0]) {
        $Version = $UpdateFeed.package_info.version[0]
    }
    else {
        $Version = [RegEx]::Match($UpdateFeed.package_info.down, $res.Get.Update.MatchVersion).Captures.Groups[0].Value
    }
    Write-Verbose -Message "$($MyInvocation.MyCommand): Matched version: $Version."

    # Build the download URL; Follow the download link which will return a 301/302
    $DownloadUrl = $res.Get.Download.Uri -replace "#version", $Version
    $Url = ((Resolve-InvokeWebRequest -Uri $DownloadUrl -MaximumRedirection 2) -split "\?")[0]

    # Construct the output; Return the custom object to the pipeline
    Write-Verbose -Message "$($MyInvocation.MyCommand): Return details for dynamic download URL."
    $PSObject = [PSCustomObject] @{
        Version  = $Version
        Date     = ConvertTo-DateTime -DateTime $updateFeed.package_info.release -Pattern $res.Get.Update.DateTimePattern
        Language = $res.Get.Download.Language
        Size     = $UpdateFeed.package_info.size
        Type     = Get-FileType -File $Url
        URI      = $Url
    }
    Write-Output -InputObject $PSObject
}
