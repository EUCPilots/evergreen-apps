BeforeDiscovery {
    Import-Module -Name Evergreen -ErrorAction Stop
}

Describe "Google Chrome platform versions and release dates" {
    InModuleScope Evergreen {
        BeforeAll {
            $RepositoryRoot = Split-Path -Path $PSScriptRoot -Parent
            . (Join-Path -Path $RepositoryRoot -ChildPath "Apps/Get-GoogleChrome.ps1")
        }

        BeforeEach {
            $script:ChromeResource = Get-Content -Path (Join-Path -Path $RepositoryRoot -ChildPath "Manifests/GoogleChrome.json") -Raw |
                ConvertFrom-Json
            $script:ChromeResource.Get.Update.Channels = @("Stable")
            $script:ChromeVersions = @{
                win       = "140.0.1.1"
                win64     = "140.0.1.2"
                win_arm64 = "140.0.1.3"
            }
            $script:ChromeReleases = @(
                [PSCustomObject] @{
                    serving = [PSCustomObject] @{ startTime = "2020-01-02T03:04:05Z" }
                }
            )
            $script:ChromePage = $null
            Mock Invoke-EvergreenRestMethod {
                param($Uri)
                if ($Uri -match "/platforms/([^/]+)/channels/stable/versions\?") {
                    return [PSCustomObject] @{
                        versions = @([PSCustomObject] @{ version = $script:ChromeVersions[$Matches[1]] })
                    }
                }
                if ($Uri -match "pageToken=") {
                    return [PSCustomObject] @{ releases = $script:ChromePage }
                }
                return [PSCustomObject] @{
                    releases      = $script:ChromeReleases
                    nextPageToken = if ($null -ne $script:ChromePage) { "next/page" } else { "" }
                }
            }
        }

        It "preserves full string timestamps for a single release and the output contract" {
            $result = @(Get-GoogleChrome -res $script:ChromeResource -WarningAction SilentlyContinue)
            $result.Count | Should -Be 6
            foreach ($item in $result) {
                $item.StartDate | Should -Be "2020-01-02"
                $item.EndDate | Should -Be "N/A"
                @($item.PSObject.Properties.Name) | Should -Be @(
                    "Version", "StartDate", "EndDate", "Channel", "Architecture", "Type", "URI"
                )
            }
            Should -Invoke Invoke-EvergreenRestMethod -Times 6 -Exactly
        }

        It "queries and returns the version specific to each platform" {
            $result = @(Get-GoogleChrome -res $script:ChromeResource -WarningAction SilentlyContinue)
            @($result | Where-Object Architecture -EQ "x86").Version | Should -Be @("140.0.1.1", "140.0.1.1")
            @($result | Where-Object Architecture -EQ "x64").Version | Should -Be @("140.0.1.2", "140.0.1.2")
            @($result | Where-Object Architecture -EQ "ARM64").Version | Should -Be @("140.0.1.3", "140.0.1.3")
            Should -Invoke Invoke-EvergreenRestMethod -Times 1 -Exactly -ParameterFilter {
                $Uri -match "/win_arm64/channels/stable/versions/all/releases\?filter=version=140\.0\.1\.3$"
            }
        }

        It "accepts already parsed DateTime timestamps" {
            $script:ChromeReleases[0].serving.startTime = [datetime]"2020-01-02T03:04:05Z"
            $result = @(Get-GoogleChrome -res $script:ChromeResource -WarningAction SilentlyContinue)
            $result[0].StartDate | Should -Be "2020-01-02"
        }

        It "prefers a currently serving record over a newer ended record" {
            $script:ChromeReleases += [PSCustomObject] @{
                serving = [PSCustomObject] @{
                    startTime = "2021-02-03T04:05:06Z"
                    endTime   = "2021-02-04T04:05:06Z"
                }
            }
            $result = @(Get-GoogleChrome -res $script:ChromeResource -WarningAction SilentlyContinue)
            $result[0].StartDate | Should -Be "2020-01-02"
            $result[0].EndDate | Should -Be "N/A"
        }

        It "selects the newest active record regardless of API ordering" {
            $script:ChromeReleases = @(
                [PSCustomObject] @{ serving = [PSCustomObject] @{ startTime = "2021-02-03T04:05:06Z" } }
                $script:ChromeReleases[0]
            )
            $result = @(Get-GoogleChrome -res $script:ChromeResource -WarningAction SilentlyContinue)
            $result[0].StartDate | Should -Be "2021-02-03"
        }

        It "uses both dates from the newest historical record when no record is active" {
            $script:ChromeReleases = @(
                [PSCustomObject] @{
                    serving = [PSCustomObject] @{
                        startTime = "2021-02-03T04:05:06Z"
                        endTime   = "2021-02-04T04:05:06Z"
                    }
                }
                [PSCustomObject] @{
                    serving = [PSCustomObject] @{
                        startTime = "2020-01-02T03:04:05Z"
                        endTime   = "2020-01-03T03:04:05Z"
                    }
                }
            )
            $result = @(Get-GoogleChrome -res $script:ChromeResource -WarningAction SilentlyContinue)
            $result[0].StartDate | Should -Be "2021-02-03"
            $result[0].EndDate | Should -Be "2021-02-04"
        }

        It "checks subsequent release pages before selecting a record" {
            $script:ChromePage = @(
                [PSCustomObject] @{ serving = [PSCustomObject] @{ startTime = "2021-02-03T04:05:06Z" } }
            )
            $result = @(Get-GoogleChrome -res $script:ChromeResource -WarningAction SilentlyContinue)
            $result[0].StartDate | Should -Be "2021-02-03"
            Should -Invoke Invoke-EvergreenRestMethod -Times 3 -Exactly -ParameterFilter {
                $Uri -match "pageToken=next%2Fpage$"
            }
        }

        It "does not choose a future release over a historical release" {
            $script:ChromeReleases[0].serving | Add-Member -NotePropertyName endTime -NotePropertyValue "2020-01-03T03:04:05Z"
            $script:ChromeReleases += [PSCustomObject] @{
                serving = [PSCustomObject] @{ startTime = "2999-01-01T00:00:00Z" }
            }
            $result = @(Get-GoogleChrome -res $script:ChromeResource -WarningAction SilentlyContinue)
            $result[0].StartDate | Should -Be "2020-01-02"
            $result[0].EndDate | Should -Be "2020-01-03"
        }

        It "fails explicitly when all releases start in the future" {
            $script:ChromeReleases[0].serving.startTime = "2999-01-01T00:00:00Z"
            { Get-GoogleChrome -res $script:ChromeResource -WarningAction SilentlyContinue } |
                Should -Throw "*No started releases returned for Stable/win*"
        }

        It "skips platforms with no configured downloads before making API requests" {
            $script:ChromeResource.Get.Update.Channels = @("Canary")
            Mock Invoke-EvergreenRestMethod {
                param($Uri)
                if ($Uri -match "/versions\?") {
                    return [PSCustomObject] @{ versions = @([PSCustomObject] @{ version = "140.0.1.2" }) }
                }
                return [PSCustomObject] @{ releases = $script:ChromeReleases }
            }
            $result = @(Get-GoogleChrome -res $script:ChromeResource -WarningAction SilentlyContinue)
            $result.Count | Should -Be 1
            $result[0].Architecture | Should -Be "x64"
            $result[0].Type | Should -Be "exe"
            Should -Invoke Invoke-EvergreenRestMethod -Times 2 -Exactly
            Should -Invoke Invoke-EvergreenRestMethod -Times 0 -Exactly -ParameterFilter {
                $Uri -notmatch "/win64/"
            }
        }

        It "fails explicitly when the platform has no version" {
            $script:ChromeVersions.win = $null
            { Get-GoogleChrome -res $script:ChromeResource -WarningAction SilentlyContinue } |
                Should -Throw "*No version returned for Stable/win*"
        }

        It "fails explicitly when the selected version has no releases" {
            $script:ChromeReleases = @()
            { Get-GoogleChrome -res $script:ChromeResource -WarningAction SilentlyContinue } |
                Should -Throw "*No releases returned for Stable/win*"
        }

        It "fails explicitly when a release has no start time" {
            $script:ChromeReleases[0].serving.startTime = $null
            { Get-GoogleChrome -res $script:ChromeResource -WarningAction SilentlyContinue } |
                Should -Throw "*Missing release start time for Stable/win*"
        }

        It "propagates request failures rather than emitting fabricated results" {
            Mock Invoke-EvergreenRestMethod { throw "API unavailable" }
            { Get-GoogleChrome -res $script:ChromeResource -WarningAction SilentlyContinue } |
                Should -Throw "*API unavailable*"
        }
    }
}
