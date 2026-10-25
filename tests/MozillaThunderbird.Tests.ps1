BeforeDiscovery {
    Import-Module -Name Evergreen -ErrorAction Stop
}

Describe "Thunderbird bulk installer discovery" {
    InModuleScope Evergreen {
        BeforeAll {
            $RepositoryRoot = Split-Path -Path $PSScriptRoot -Parent
            . (Join-Path -Path $RepositoryRoot -ChildPath "Apps/Get-MozillaThunderbird.ps1")
            $script:ThunderbirdResource = Get-Content -Path (Join-Path -Path $RepositoryRoot -ChildPath "Manifests/MozillaThunderbird.json") -Raw |
                ConvertFrom-Json -AsHashtable
        }

        BeforeEach {
            $script:ThunderbirdVersions = [PSCustomObject] @{
                LATEST_THUNDERBIRD_VERSION       = "158.0.1"
                LATEST_THUNDERBIRD_DEVEL_VERSION = "159.0b5"
                THUNDERBIRD_ESR                 = "153.5.1esr"
                THUNDERBIRD_ESR_NEXT            = ""
            }
            $script:ThunderbirdChecksums = @{}
            foreach ($version in @("158.0.1", "159.0b5", "153.5.1esr", "154.0esr")) {
                $lines = foreach ($locale in @("en-US", "de", "zz-new")) {
                    foreach ($platform in @("win32", "win64")) {
                        "$('a' * 64)  $platform/$locale/Thunderbird Setup $version.exe"
                        "$('b' * 64)  $platform/$locale/Thunderbird Setup $version.msi"
                    }
                }
                $lines += @(
                    "$('c' * 64)  win64/en-US/Thunderbird Installer.exe"
                    "$('d' * 64)  win64-EME-free/en-US/Thunderbird Setup $version.exe"
                    "$('e' * 64)  linux-x86_64/en-US/thunderbird-$version.tar.xz"
                    "$('f' * 64)  win64/en-US/Thunderbird Setup 100.0.exe"
                )
                $script:ThunderbirdChecksums[$version] = $lines -join "`n"
            }
            Mock Invoke-EvergreenRestMethod {
                param($Uri)
                if ($Uri -eq $script:ThunderbirdResource.Get.Update.Uri) {
                    return $script:ThunderbirdVersions
                }
                $version = ($Uri -split "/")[-2]
                return $script:ThunderbirdChecksums[$version]
            }
            Mock Resolve-InvokeWebRequest {
                param($Uri)
                $platform = if ($Uri -match "os=([^&]+)") { $Matches[1] }
                if ($platform -eq "win") { $platform = "win32" }
                $version = if ($Uri -match "product=thunderbird-(.+)-msix-SSL&") { $Matches[1] }
                "https://download-installer.cdn.mozilla.net/pub/thunderbird/releases/$version/$platform/multi/Thunderbird%20Setup%20$version.msix"
            }
        }

        It "returns all published locales with a fixed request budget" {
            $result = @(Get-MozillaThunderbird -res $script:ThunderbirdResource)
            $result.Count | Should -Be 42
            @($result.Language | Sort-Object -Unique) | Should -Be @("de", "en-US", "Multi", "zz-new")
            @($result | Where-Object Type -EQ "msix").Count | Should -Be 6
            @($result.URI | Sort-Object -Unique).Count | Should -Be $result.Count
            Should -Invoke Invoke-EvergreenRestMethod -Times 4 -Exactly
            Should -Invoke Resolve-InvokeWebRequest -Times 6 -Exactly
        }

        It "filters languages case-insensitively without duplicating MSIX" {
            $result = @(Get-MozillaThunderbird -res $script:ThunderbirdResource -Language "EN-us", "de", "de")
            $result.Count | Should -Be 30
            @($result | Where-Object Type -EQ "msix").Count | Should -Be 6
            @($result | Where-Object Language -EQ "zz-new").Count | Should -Be 0
            Should -Invoke Invoke-EvergreenRestMethod -Times 4 -Exactly
            Should -Invoke Resolve-InvokeWebRequest -Times 6 -Exactly
        }

        It "preserves fields, filenames, architectures and raw ESR paths" {
            $result = @(Get-MozillaThunderbird -res $script:ThunderbirdResource -Language "en-US")
            $result.Count | Should -Be 18
            foreach ($item in $result) {
                @($item.PSObject.Properties.Name) | Should -Be @("Version", "Channel", "Language", "Sha256", "Architecture", "Type", "Filename", "URI")
                $item.URI | Should -Not -Match " "
                $item.Filename | Should -Match "^Thunderbird Setup .+\.(exe|msi|msix)$"
            }
            $esr = @($result | Where-Object { $_.Channel -eq "ESR" -and $_.Type -eq "exe" })
            $esr.Count | Should -Be 2
            $esr.Version | Should -Be @("153.5.1", "153.5.1")
            $esr[0].URI | Should -Match "/153\.5\.1esr/.+/Thunderbird%20Setup%20153\.5\.1esr\.exe$"
            @($result.Architecture | Sort-Object -Unique) | Should -Be @("x64", "x86")
            @($result | Where-Object { $_.Filename -eq "Thunderbird Installer.exe" -or $_.URI -match "EME-free|linux" }).Count | Should -Be 0
        }

        It "returns exact published SHA256 values and null for MSIX" {
            $result = @(Get-MozillaThunderbird -res $script:ThunderbirdResource)
            foreach ($item in $result) {
                switch ($item.Type) {
                    "exe" { $item.Sha256 | Should -BeExactly ('a' * 64) }
                    "msi" { $item.Sha256 | Should -BeExactly ('b' * 64) }
                    "msix" { ($null -eq $item.Sha256) | Should -BeTrue }
                }
            }
        }

        It "skips inactive channels before making download requests" {
            $script:ThunderbirdVersions.THUNDERBIRD_ESR_NEXT = $null
            $result = @(Get-MozillaThunderbird -res $script:ThunderbirdResource)
            @($result | Where-Object Channel -EQ "ESR_Next").Count | Should -Be 0
            Should -Invoke Invoke-EvergreenRestMethod -Times 0 -Exactly -ParameterFilter { $Uri -match "154.0esr" }
        }

        It "discovers ESR Next when it becomes active" {
            $script:ThunderbirdVersions.THUNDERBIRD_ESR_NEXT = "154.0esr"
            $result = @(Get-MozillaThunderbird -res $script:ThunderbirdResource -Language "en-US")
            @($result | Where-Object Channel -EQ "ESR_Next").Count | Should -Be 6
            Should -Invoke Invoke-EvergreenRestMethod -Times 5 -Exactly
            Should -Invoke Resolve-InvokeWebRequest -Times 8 -Exactly
        }

        It "uses exact versions for all MSIX channels including Beta" {
            $null = Get-MozillaThunderbird -res $script:ThunderbirdResource
            foreach ($version in @("158.0.1", "159.0b5", "153.5.1esr")) {
                Should -Invoke Resolve-InvokeWebRequest -Times 2 -Exactly -ParameterFilter {
                    $Uri -like "*product=thunderbird-$version-msix-SSL&*"
                }
            }
            Should -Invoke Resolve-InvokeWebRequest -Times 0 -Exactly -ParameterFilter { $Uri -match "latest|#version|#platform" }
        }

        It "warns about unavailable languages while returning multilingual installers" {
            $warnings = @()
            $result = @(Get-MozillaThunderbird -res $script:ThunderbirdResource -Language "not-a-locale" -WarningVariable warnings -WarningAction SilentlyContinue)
            $result.Count | Should -Be 6
            @($result.Language | Sort-Object -Unique) | Should -Be @("Multi")
            $warnings.Count | Should -Be 3
        }

        It "rejects checksum responses without matching installers" {
            $script:ThunderbirdChecksums["158.0.1"] = "<html>Not a checksum manifest</html>"
            { Get-MozillaThunderbird -res $script:ThunderbirdResource } | Should -Throw "*No Windows installers found*"
        }

        It "accepts CRLF checksum files" {
            $script:ThunderbirdChecksums["158.0.1"] = $script:ThunderbirdChecksums["158.0.1"] -replace "`n", "`r`n"
            @(Get-MozillaThunderbird -res $script:ThunderbirdResource).Count | Should -Be 42
        }

        It "surfaces metadata failures" {
            Mock Invoke-EvergreenRestMethod { throw "Metadata unavailable" }
            { Get-MozillaThunderbird -res $script:ThunderbirdResource } | Should -Throw "*Metadata unavailable*"
        }

        It "surfaces MSIX resolution failures" {
            Mock Resolve-InvokeWebRequest { Write-Error "MSIX unavailable" }
            { Get-MozillaThunderbird -res $script:ThunderbirdResource } | Should -Throw "*MSIX unavailable*"
        }

        It "rejects empty MSIX resolution results" {
            Mock Resolve-InvokeWebRequest { $null }
            { Get-MozillaThunderbird -res $script:ThunderbirdResource } | Should -Throw "*No MSIX download resolved*"
        }
    }
}
