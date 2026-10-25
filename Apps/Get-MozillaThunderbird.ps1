function Get-MozillaThunderbird {
    <#
        .SYNOPSIS
            Returns downloads for the latest Mozilla Thunderbird releases.

        .PARAMETER Language
            Filters localized installers to the specified languages. By default, returns
            all published languages. Multilingual MSIX packages are always included once
            per channel and architecture with Language set to Multi.

        .NOTES
            Site: https://stealthpuppy.com
            Author: Aaron Parker


            # https://wiki.mozilla.org/Release_Management/Product_details
    #>
    [OutputType([System.Management.Automation.PSObject])]
    [CmdletBinding(SupportsShouldProcess = $false)]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateNotNull()]
        [System.Management.Automation.PSObject]
        $res = (Get-FunctionResource -AppName ("$($MyInvocation.MyCommand)".Split("-"))[1]),

        [Parameter(Mandatory = $false, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [System.String[]] $Language
    )

    # Get latest Thunderbird version
    $Versions = Invoke-EvergreenRestMethod -Uri $res.Get.Update.Uri

    foreach ($channel in $res.Get.Update.Channels.GetEnumerator()) {
        $RawVersion = $Versions.$($channel.Key)
        if ([System.String]::IsNullOrWhiteSpace($RawVersion)) {
            Write-Verbose -Message "$($MyInvocation.MyCommand): Skipping inactive channel: $($channel.Key)."
            continue
        }

        $Version = $RawVersion -replace $res.Get.Download.ReplaceText.Version, ""
        $ReleaseUri = $res.Get.Download.ReleaseUri -replace "#version", $RawVersion
        $Checksums = Invoke-EvergreenRestMethod -Uri "$ReleaseUri/SHA256SUMS"

        # Use published full installers, excluding stubs and other artifacts.
        $Pattern = '^(?<Sha256>[a-f0-9]{64})\s+(?<Path>(?<Platform>win32|win64)/(?<Language>[^/\s]+)/(?<Filename>Thunderbird Setup ' +
            [regex]::Escape($RawVersion) + '\.(?:exe|msi)))\r?$'
        $Installers = [regex]::Matches($Checksums, $Pattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)
        if ($Installers.Count -eq 0) {
            throw "$($MyInvocation.MyCommand): No Windows installers found in $ReleaseUri/SHA256SUMS."
        }

        if ($Language) {
            $AvailableLanguages = $Installers | ForEach-Object { $_.Groups["Language"].Value } | Select-Object -Unique
            foreach ($RequestedLanguage in $Language) {
                if ($RequestedLanguage -notin $AvailableLanguages) {
                    Write-Warning -Message "$($MyInvocation.MyCommand): Language '$RequestedLanguage' is not available for channel: $($channel.Value)."
                }
            }
        }

        foreach ($installer in $Installers) {
            $CurrentLanguage = $installer.Groups["Language"].Value
            if ($Language -and $CurrentLanguage -notin $Language) {
                continue
            }

            $Path = ($installer.Groups["Path"].Value.Split("/") | ForEach-Object { [System.Uri]::EscapeDataString($_) }) -join "/"
            $Url = "$ReleaseUri/$Path"
            [PSCustomObject] @{
                Version      = $Version
                Channel      = $channel.Value
                Language     = $CurrentLanguage
                Sha256       = $installer.Groups["Sha256"].Value
                Architecture = Get-Architecture -String $installer.Groups["Platform"].Value
                Type         = Get-FileType -File $Url
                Filename     = $installer.Groups["Filename"].Value
                URI          = $Url
            } | Write-Output
        }

        # MSIX packages are multilingual and are not listed in SHA256SUMS.
        foreach ($platform in $res.Get.Download.Platforms) {
            $Uri = ($res.Get.Download.Msix -replace "#version", $RawVersion) -replace "#platform", $platform
            $Url = Resolve-InvokeWebRequest -Uri $Uri -ErrorAction Stop
            if ([System.String]::IsNullOrWhiteSpace($Url)) {
                Write-Verbose -Message "$($MyInvocation.MyCommand): No MSIX download resolved for $($channel.Value), $platform."
            }
            [PSCustomObject] @{
                Version      = $Version
                Channel      = $channel.Value
                Language     = "Multi"
                Sha256       = $null
                Architecture = Get-Architecture -String $platform
                Type         = Get-FileType -File $Url
                Filename     = [System.Uri]::UnescapeDataString((Split-Path -Path $Url -Leaf))
                URI          = $Url
            } | Write-Output
        }
    }
}
