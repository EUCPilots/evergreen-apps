function Get-HPWindowsInsightsApplication {
    [OutputType([System.Management.Automation.PSObject])]
    [CmdletBinding(SupportsShouldProcess = $false)]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateNotNull()]
        [System.Management.Automation.PSObject]
        $res = (Get-FunctionResource -AppName ("$($MyInvocation.MyCommand)".Split("-"))[1])
    )

    $Response = Invoke-EvergreenWebRequest -Uri $res.Get.Update.Uri -ReturnObject All
    $Response.RawContentStream.Position = 0
    $Reader = [System.IO.StreamReader]::new($Response.RawContentStream, [System.Text.Encoding]::Unicode)
    try {
        $Feed = $Reader.ReadToEnd() | ConvertFrom-Json -ErrorAction Stop
    }
    finally {
        $Reader.Dispose()
    }
    if ($null -ne $Feed) {
        $LatestBuild = $Feed.microsoft.previousBuilds | `
            Where-Object { $_.appName -eq $res.Get.Update.AppName } | `
            Sort-Object -Property @{ Expression = { [System.Version]$_.appVersion }; Descending = $true } -ErrorAction Stop | `
            Select-Object -First 1
        foreach ($Build in $LatestBuild) {
            Write-Verbose -Message "$($MyInvocation.MyCommand): Processing version $($Build.appVersion) released on $($Build.releaseDate)."
            foreach ($Architecture in $res.Get.Download.Uri.Keys) {
                Write-Verbose -Message "$($MyInvocation.MyCommand): Generating $Architecture download URI for version $($Build.appVersion)."
                $DownloadUri = $res.Get.Download.Uri[$Architecture] -replace "#version", $Build.appVersion
                if ($Architecture -eq "arm64") {
                    $Sha256 = $Build.Sha256HashARM64
                }
                else {
                    $Sha256 = $Build.Sha256Hash
                }

                [PSCustomObject]@{
                    Version      = $Build.appVersion
                    Date         = ConvertTo-DateTime -DateTime $Build.releaseDate -Pattern "yyyyMMdd"
                    Architecture = $Architecture
                    Sha256       = $Sha256
                    Type         = Get-FileType -File $DownloadUri
                    URI          = $DownloadUri
                }
            }
        }
    }
}
