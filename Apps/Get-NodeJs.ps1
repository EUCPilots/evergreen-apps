function Get-NodeJs {
    <#
        .NOTES
            Site: https://stealthpuppy.com
            Author: Aaron Parker

    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Justification = "Product name ends in s")]
    [OutputType([System.Management.Automation.PSObject])]
    [CmdletBinding(SupportsShouldProcess = $false)]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateNotNull()]
        [System.Management.Automation.PSObject]
        $res = (Get-FunctionResource -AppName ("$($MyInvocation.MyCommand)".Split("-"))[1])
    )

    # Get latest version and download latest release via update API
    $params = @{
        Uri         = $res.Get.Update.Uri
        ContentType = $res.Get.Update.ContentType
    }
    $UpdateFeed = Invoke-EvergreenRestMethod @params

    if ($null -ne $updateFeed) {

        # Output the Current version
        $CurrentVersion = $UpdateFeed | Where-Object { $_.lts -eq $false } | Select-Object -First 1
        if ($null -eq $CurrentVersion) {
            throw "$($MyInvocation.MyCommand): No Current release found in $($res.Get.Update.Uri)."
        }

        foreach ($Url in $res.Get.Download.Uri.Current) {
            $DownloadUri = $Url -replace $res.Get.Download.ReplaceText, $CurrentVersion.version
            $PSObject = [PSCustomObject] @{
                Version      = $CurrentVersion.version.TrimStart($res.Get.Update.TrimStart)
                Architecture = Get-Architecture -String $Url
                Type         = Get-FileType -File $DownloadUri
                Channel      = "Current"
                URI          = $DownloadUri
            }
            Write-Output -InputObject $PSObject
        }

        # Output the LTS version
        $LtsVersion = $UpdateFeed | Where-Object { $_.lts -is [string] -and -not [string]::IsNullOrWhiteSpace($_.lts) } | Select-Object -First 1
        if ($null -eq $LtsVersion) {
            throw "$($MyInvocation.MyCommand): No LTS release found in $($res.Get.Update.Uri)."
        }

        foreach ($Url in $res.Get.Download.Uri.LTS) {
            $DownloadUri = $Url -replace $res.Get.Download.ReplaceText, $LtsVersion.version
            $PSObject = [PSCustomObject] @{
                Version      = $LtsVersion.version.TrimStart($res.Get.Update.TrimStart)
                Architecture = Get-Architecture -String $Url
                Type         = Get-FileType -File $DownloadUri
                Channel      = "LTS"
                URI          = $DownloadUri
            }
            Write-Output -InputObject $PSObject
        }
    }
}
