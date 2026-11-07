BeforeDiscovery {
    Import-Module -Name Evergreen -ErrorAction Stop
}

Describe "Apple iTunes installer discovery" {
    InModuleScope Evergreen {
        BeforeAll {
            $RepositoryRoot = Split-Path -Path $PSScriptRoot -Parent
            . (Join-Path -Path $RepositoryRoot -ChildPath "Apps/Get-AppleITunes.ps1")
            $script:AppleITunesResource = Get-Content -Path (Join-Path -Path $RepositoryRoot -ChildPath "Manifests/AppleITunes.json") -Raw |
                ConvertFrom-Json
        }

        BeforeEach {
            $script:AppleITunesFeed = '<?xml version="1.0"?><plist version="1.0"><dict><key>iTunesWindowsVersion</key><string>12.13.8</string></dict></plist>'
            Mock Invoke-EvergreenWebRequest { $script:AppleITunesFeed }
            Mock Resolve-InvokeWebRequest {
                param($Uri)
                if ($Uri -match "win64") {
                    return "https://secure-appldnld.apple.com/itunes12/iTunes64Setup.exe"
                }
                return "https://secure-appldnld.apple.com/itunes12/iTunesSetup.exe"
            }
        }

        It "returns the current version and resolved installers for both architectures" {
            $result = @(Get-AppleITunes -res $script:AppleITunesResource)
            $result.Count | Should -Be 2
            @($result.Architecture | Sort-Object) | Should -Be @("x64", "x86")
            foreach ($item in $result) {
                $item.Version | Should -BeExactly "12.13.8"
                $item.Type | Should -BeExactly "exe"
            }
            $result[0].URI | Should -BeExactly "https://secure-appldnld.apple.com/itunes12/iTunes64Setup.exe"
            $result[1].URI | Should -BeExactly "https://secure-appldnld.apple.com/itunes12/iTunesSetup.exe"
            Should -Invoke Invoke-EvergreenWebRequest -Times 1 -Exactly -ParameterFilter {
                $Uri -eq "https://s.mzstatic.com/version" -and $Raw
            }
            Should -Invoke Resolve-InvokeWebRequest -Times 2 -Exactly
        }

        It "reports when the version is missing from the feed" {
            $script:AppleITunesFeed = '<?xml version="1.0"?><plist version="1.0"><dict><key>OtherVersion</key><string>12.13.8</string></dict></plist>'
            { Get-AppleITunes -res $script:AppleITunesResource } | Should -Throw "*failed to locate iTunesWindowsVersion*"
        }

        It "reports when a download URL cannot be resolved" {
            Mock Resolve-InvokeWebRequest { $null }
            { Get-AppleITunes -res $script:AppleITunesResource } | Should -Throw "*failed to resolve the x64 download URL*"
        }
    }
}
