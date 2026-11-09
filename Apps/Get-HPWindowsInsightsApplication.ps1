function Get-HPWindowsInsightsApplication {
    [OutputType([System.Management.Automation.PSObject])]
    [CmdletBinding(SupportsShouldProcess = $false)]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateNotNull()]
        [System.Management.Automation.PSObject]
        $res = (Get-FunctionResource -AppName ("$($MyInvocation.MyCommand)".Split("-"))[1])
    )

    $Feed = Invoke-EvergreenRestMethod -Uri $res.Get.Update.Uri -ContentType $res.Get.Update.ContentType

    if ($null -ne $Feed) {
        foreach ($Build in ($Feed.microsoft.previousBuilds | Where-Object { $_.appName -eq $res.Get.Update.AppName })) {
            foreach ($Architecture in $res.Get.Download.Uri.Keys) {
                $DownloadUri = $res.Get.Download.Uri[$Architecture] -replace "#version", $Build.appVersion
                if ($Architecture -eq "arm64") {
                    $Sha256 = $Build.Sha256HashARM64
                }
                else {
                    $Sha256 = $Build.Sha256Hash
                }

                [PSCustomObject]@{
                    Version      = $Build.appVersion
                    Date         = ConvertTo-DateTime -DateTime $Build.releaseDate -AutoDetect
                    Architecture = $Architecture
                    Sha256       = $Sha256
                    Type         = Get-FileType -File $DownloadUri
                    URI          = $DownloadUri
                }
            }
        }
    }
}
