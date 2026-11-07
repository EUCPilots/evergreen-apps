function Get-AppleITunes {
    [OutputType([System.Management.Automation.PSObject])]
    [CmdletBinding(SupportsShouldProcess = $false)]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateNotNull()]
        [System.Management.Automation.PSObject]
        $res = (Get-FunctionResource -AppName ("$($MyInvocation.MyCommand)".Split("-"))[1])
    )

    [System.XML.XMLDocument] $UpdateFeed = Invoke-EvergreenWebRequest -Uri $res.Get.Update.Uri -Raw -ErrorAction Stop
    $VersionNode = $UpdateFeed.SelectSingleNode("/plist/dict/key[.='iTunesWindowsVersion']/following-sibling::string[1]")
    if ($null -eq $VersionNode -or [string]::IsNullOrWhiteSpace($VersionNode.InnerText)) {
        throw "$($MyInvocation.MyCommand): failed to locate iTunesWindowsVersion in the update feed."
    }

    $Version = $VersionNode.InnerText.Trim()
    $DownloadUris = $res.Get.Download.Uri
    $Architectures = if ($DownloadUris -is [System.Collections.IDictionary]) {
        $DownloadUris.GetEnumerator()
    }
    else {
        $DownloadUris.PSObject.Properties
    }
    foreach ($Architecture in $Architectures) {
        $Uri = Resolve-InvokeWebRequest -Uri $Architecture.Value -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($Uri)) {
            throw "$($MyInvocation.MyCommand): failed to resolve the $($Architecture.Name) download URL."
        }

        [PSCustomObject] @{
            Version      = $Version
            Architecture = $Architecture.Name
            Type         = "Exe"
            URI          = $Uri
        } | Write-Output
    }
}
