BeforeDiscovery {
    Import-Module -Name Evergreen -ErrorAction Stop
}

Describe "Firefox bulk installer discovery" {
    InModuleScope Evergreen {
        BeforeAll {
            $RepositoryRoot = Split-Path -Path $PSScriptRoot -Parent
            . (Join-Path -Path $RepositoryRoot -ChildPath "Apps/Get-MozillaFirefox.ps1")
            $script:FirefoxResource = Get-Content -Path (Join-Path -Path $RepositoryRoot -ChildPath "Manifests/MozillaFirefox.json") -Raw |
                ConvertFrom-Json -AsHashtable
        }

        BeforeEach {
            $script:FirefoxVersions = [PSCustomObject] @{
                LATEST_FIREFOX_VERSION                = "158.0.1"
                FIREFOX_ESR                          = "153.5.1esr"
                FIREFOX_ESR_NEXT                     = ""
                FIREFOX_DEVEDITION                   = "159.0b5"
                LATEST_FIREFOX_RELEASED_DEVEL_VERSION = "159.0b5"
            }
            $script:FirefoxChecksums = @{}
            foreach ($version in @("158.0.1", "153.5.1esr", "154.0esr", "159.0b5")) {
                $lines = foreach ($locale in @("en-US", "de", "zz-new")) {
                    foreach ($platform in @("win32", "win64", "win64-aarch64")) {
                        "$('a' * 64)  $platform/$locale/Firefox Setup $version.exe"
                        if ($platform -ne "win64-aarch64") {
                            "$('b' * 64)  $platform/$locale/Firefox Setup $version.msi"
                        }
                    }
                }
                $lines += @(
                    "$('c' * 64)  win64/en-US/Firefox Installer.exe"
                    "$('d' * 64)  win64-EME-free/en-US/Firefox Setup $version.exe"
                    "$('e' * 64)  linux-x86_64/en-US/firefox-$version.tar.xz"
                    "$('f' * 64)  win64/en-US/Firefox Setup 100.0.exe"
                )
                $script:FirefoxChecksums[$version] = $lines -join "`n"
            }
            Mock Invoke-EvergreenRestMethod {
                param($Uri)
                if ($Uri -eq $script:FirefoxResource.Get.Update.Uri) {
                    return $script:FirefoxVersions
                }
                $version = ($Uri -split "/")[-2]
                return $script:FirefoxChecksums[$version]
            }
            Mock Resolve-InvokeWebRequest {
                param($Uri)
                $platform = if ($Uri -match "os=([^&]+)") { $Matches[1] }
                if ($platform -eq "win") { $platform = "win32" }
                $version = switch -Regex ($Uri) {
                    "esr-next" { "154.0esr"; break }
                    "esr-msix" { "153.5.1esr"; break }
                    "devedition|beta" { "159.0b5"; break }
                    default { "158.0.1" }
                }
                $product = if ($Uri -match "devedition") { "devedition" } else { "firefox" }
                "https://download-installer.cdn.mozilla.net/pub/$product/releases/$version/$platform/multi/Firefox%20Setup%20$version.msix"
            }
        }

        It "returns every published locale with a fixed request budget" {
            $result = @(Get-MozillaFirefox -res $script:FirefoxResource)
            $result.Count | Should -Be 72
            @($result.Language | Sort-Object -Unique) | Should -Be @("de", "en-US", "Multi", "zz-new")
            @($result | Where-Object Type -EQ "msix").Count | Should -Be 12
            @($result.URI | Sort-Object -Unique).Count | Should -Be $result.Count
            Should -Invoke Invoke-EvergreenRestMethod -Times 5 -Exactly
            Should -Invoke Resolve-InvokeWebRequest -Times 12 -Exactly
        }

        It "filters localized installers case-insensitively without duplicating MSIX" {
            $result = @(Get-MozillaFirefox -res $script:FirefoxResource -Language "EN-us", "de", "de")
            $result.Count | Should -Be 52
            @($result | Where-Object Type -EQ "msix").Count | Should -Be 12
            @($result | Where-Object Language -EQ "zz-new").Count | Should -Be 0
            Should -Invoke Invoke-EvergreenRestMethod -Times 5 -Exactly
            Should -Invoke Resolve-InvokeWebRequest -Times 12 -Exactly
        }

        It "preserves fields, encoded filenames, architectures and raw ESR paths" {
            $result = @(Get-MozillaFirefox -res $script:FirefoxResource -Language "en-US")
            $result.Count | Should -Be 32
            foreach ($item in $result) {
                @($item.PSObject.Properties.Name) | Should -Be @("Version", "Channel", "Language", "Architecture", "Type", "Filename", "Sha256", "URI")
                $item.URI | Should -Not -Match " "
                $item.Filename | Should -Match "^Firefox Setup .+\.(exe|msi|msix)$"
            }
            $esr = @($result | Where-Object { $_.Channel -eq "Extended Support" -and $_.Type -eq "exe" })
            $esr.Count | Should -Be 3
            $esr.Version | Should -Be @("153.5.1", "153.5.1", "153.5.1")
            $esr[0].URI | Should -Match "/153\.5\.1esr/.+/Firefox%20Setup%20153\.5\.1esr\.exe$"
            @($result.Architecture | Sort-Object -Unique) | Should -Be @("ARM64", "x64", "x86")
            @($result | Where-Object { $_.Architecture -eq "ARM64" -and $_.Type -eq "msi" }).Count | Should -Be 0
            @($result | Where-Object { $_.Filename -eq "Firefox Installer.exe" -or $_.URI -match "EME-free|linux" }).Count | Should -Be 0
        }

        It "returns the published SHA256 for each localized installer without additional requests" {
            $result = @(Get-MozillaFirefox -res $script:FirefoxResource)
            foreach ($item in $result) {
                switch ($item.Type) {
                    "exe" { $item.Sha256 | Should -BeExactly ('a' * 64) }
                    "msi" { $item.Sha256 | Should -BeExactly ('b' * 64) }
                    "msix" { ($null -eq $item.Sha256) | Should -BeTrue }
                }
            }
            Should -Invoke Invoke-EvergreenRestMethod -Times 5 -Exactly
            Should -Invoke Resolve-InvokeWebRequest -Times 12 -Exactly
        }

        It "skips inactive channels before making download requests" {
            $script:FirefoxVersions.FIREFOX_ESR_NEXT = $null
            $result = @(Get-MozillaFirefox -res $script:FirefoxResource)
            @($result | Where-Object Channel -EQ "Extended Support Next").Count | Should -Be 0
            Should -Invoke Resolve-InvokeWebRequest -Times 0 -Exactly -ParameterFilter { $Uri -match "esr-next" }
        }

        It "discovers ESR Next when the channel becomes active" {
            $script:FirefoxVersions.FIREFOX_ESR_NEXT = "154.0esr"
            $result = @(Get-MozillaFirefox -res $script:FirefoxResource -Language "en-US")
            @($result | Where-Object Channel -EQ "Extended Support Next").Count | Should -Be 8
            Should -Invoke Invoke-EvergreenRestMethod -Times 6 -Exactly
            Should -Invoke Resolve-InvokeWebRequest -Times 15 -Exactly
        }

        It "uses the developer release archive and valid MSIX product IDs" {
            $null = Get-MozillaFirefox -res $script:FirefoxResource
            Should -Invoke Invoke-EvergreenRestMethod -Times 1 -Exactly -ParameterFilter {
                $Uri -eq "https://archive.mozilla.org/pub/devedition/releases/159.0b5/SHA256SUMS"
            }
            Should -Invoke Resolve-InvokeWebRequest -Times 3 -Exactly -ParameterFilter { $Uri -match "product=firefox-devedition-msix-latest-ssl&" }
            Should -Invoke Resolve-InvokeWebRequest -Times 3 -Exactly -ParameterFilter { $Uri -match "product=firefox-beta-msix-latest-ssl&" }
        }

        It "reports unavailable languages while retaining multilingual installers" {
            $warnings = @()
            $result = @(Get-MozillaFirefox -res $script:FirefoxResource -Language "not-a-locale" -WarningVariable warnings -WarningAction SilentlyContinue)
            $result.Count | Should -Be 12
            @($result.Language | Sort-Object -Unique) | Should -Be @("Multi")
            $warnings.Count | Should -Be 4
        }

        It "rejects checksum responses without matching full installers" {
            $script:FirefoxChecksums["158.0.1"] = "<html>Not a checksum manifest</html>"
            { Get-MozillaFirefox -res $script:FirefoxResource } | Should -Throw "*No Windows installers found*"
        }

        It "accepts CRLF checksum files" {
            $script:FirefoxChecksums["158.0.1"] = $script:FirefoxChecksums["158.0.1"] -replace "`n", "`r`n"
            @(Get-MozillaFirefox -res $script:FirefoxResource).Count | Should -Be 72
        }

        It "surfaces metadata failures" {
            Mock Invoke-EvergreenRestMethod { throw "Metadata unavailable" }
            { Get-MozillaFirefox -res $script:FirefoxResource } | Should -Throw "*Metadata unavailable*"
        }

        It "surfaces MSIX resolution failures" {
            Mock Resolve-InvokeWebRequest { Write-Error "MSIX unavailable" }
            { Get-MozillaFirefox -res $script:FirefoxResource } | Should -Throw "*MSIX unavailable*"
        }

        It "rejects empty MSIX resolution results" {
            Mock Resolve-InvokeWebRequest { $null }
            { Get-MozillaFirefox -res $script:FirefoxResource } | Should -Throw "*No MSIX download resolved*"
        }
    }
}
