BeforeDiscovery {
    Import-Module -Name Evergreen -ErrorAction Stop
}

Describe "WireGuard installer discovery" {
    InModuleScope Evergreen {
        BeforeAll {
            $RepositoryRoot = Split-Path -Path $PSScriptRoot -Parent
            . (Join-Path -Path $RepositoryRoot -ChildPath "Apps/Get-WireGuard.ps1")
            $script:WireGuardResource = Get-Content -Path (Join-Path -Path $RepositoryRoot -ChildPath "Manifests/WireGuard.json") -Raw |
                ConvertFrom-Json
        }

        BeforeEach {
            $script:WireGuardFeed = @(
                "untrusted comment: verify with wireguard-windows-release.pub"
                "RWRNqGKtBXftKXxdOWjsTHtUTWLcjLqfOzJG4TOVx/+KTnxUK2nMY4aLt2RmqwCrfsiWJBZb4zG8qJxpnbXvD6c6+I4pqsBMLAI="
                "$('a' * 64)  wireguard-amd64-1.1.1.msi"
                "$('b' * 64)  wireguard-arm64-1.1.1.msi"
                "$('c' * 64)  wireguard-x86-1.1.1.msi"
            ) -join "`n"
            Mock Invoke-EvergreenWebRequest { $script:WireGuardFeed }
        }

        It "returns all published installers from <Name>" -TestCases @(
            @{ Name = "LF text"; Newline = "`n"; AsLines = $false }
            @{ Name = "CRLF text"; Newline = "`r`n"; AsLines = $false }
            @{ Name = "raw response lines"; Newline = "`n"; AsLines = $true }
        ) {
            param($Name, $Newline, $AsLines)

            $script:WireGuardFeed = $script:WireGuardFeed -replace "`n", $Newline
            if ($AsLines) {
                $script:WireGuardFeed = $script:WireGuardFeed -split "`n"
            }
            $result = @(Get-WireGuard -res $script:WireGuardResource)
            $result.Count | Should -Be 3
            $result.Architecture | Should -Be @("x64", "ARM64", "x86")
            for ($index = 0; $index -lt $result.Count; $index++) {
                $item = $result[$index]
                @($item.PSObject.Properties.Name) | Should -Be @("Version", "Architecture", "Type", "Sha256", "URI")
                $item.Version | Should -BeExactly "1.1.1"
                $item.Type | Should -BeExactly "msi"
                $item.Sha256 | Should -BeExactly (@("a", "b", "c")[$index] * 64)
                $platform = @("amd64", "arm64", "x86")[$index]
                $item.URI | Should -BeExactly "https://download.wireguard.com/windows-client/wireguard-$platform-1.1.1.msi"
            }
            Should -Invoke Invoke-EvergreenWebRequest -Times 1 -Exactly -ParameterFilter {
                $Uri -eq "https://download.wireguard.com/windows-client/latest.sig" -and $Raw
            }
        }

        It "reads versions from filenames and ignores unrelated or malformed entries" {
            $script:WireGuardFeed = @(
                "$('a' * 64)  wireguard-amd64-2.10.3.msi"
                "$('b' * 64)  wireguard-amd64-2.10.3.exe"
                "$('c' * 64)  unrelated-x86-2.10.3.msi"
                "invalid-checksum  wireguard-x86-2.10.3.msi"
            ) -join "`n"
            $result = @(Get-WireGuard -res $script:WireGuardResource)
            $result.Count | Should -Be 1
            $result[0].Version | Should -BeExactly "2.10.3"
            $result[0].URI | Should -BeExactly "https://download.wireguard.com/windows-client/wireguard-amd64-2.10.3.msi"
        }

        It "reports feeds without installer entries" {
            $script:WireGuardFeed = "untrusted comment: no installers"
            { Get-WireGuard -res $script:WireGuardResource } | Should -Throw "*No Windows installers found*"
        }

        It "propagates request failures" {
            Mock Invoke-EvergreenWebRequest { throw "Request failed" }
            { Get-WireGuard -res $script:WireGuardResource } | Should -Throw "*Request failed*"
        }
    }
}
