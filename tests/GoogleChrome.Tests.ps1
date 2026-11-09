BeforeDiscovery {
    Import-Module -Name Evergreen -ErrorAction Stop
}

Describe "Google Chrome fully rolled-out channel releases" {
    InModuleScope Evergreen {
        BeforeAll {
            $RepositoryRoot = Split-Path -Path $PSScriptRoot -Parent
            . (Join-Path -Path $RepositoryRoot -ChildPath "Apps/Get-GoogleChrome.ps1")

            function New-ChromeRelease {
                param (
                    [string] $Channel = "stable",
                    [string] $Version = "140.0.1.1",
                    [object] $StartTime = "2020-01-02T03:04:05Z"
                )
                [PSCustomObject] @{
                    name    = "chrome/platforms/win/channels/$Channel/versions/$Version/releases/1"
                    version = $Version
                    serving = [PSCustomObject] @{ startTime = $StartTime }
                }
            }
        }

        BeforeEach {
            $script:ChromeResource = Get-Content -Path (Join-Path -Path $RepositoryRoot -ChildPath "Manifests/GoogleChrome.json") -Raw |
                ConvertFrom-Json
            $script:ChromeResource.Get.Update.Channels = @("Stable")
            $script:ChromeReleases = @{
                win       = @(New-ChromeRelease -Version "140.0.1.1")
                win64     = @(New-ChromeRelease -Version "140.0.1.2")
                win_arm64 = @(New-ChromeRelease -Version "140.0.1.3")
            }
            $script:ChromeFallbackReleases = @{}
            $script:ChromePage = $null
            Mock Start-Sleep {}
            Mock Invoke-EvergreenRestMethod {
                param($Uri)
                $Uri -match "/platforms/([^/]+)/" | Out-Null
                $Platform = $Matches[1]
                if ($Uri -match "filter=endtime%3Dnone") {
                    return [PSCustomObject] @{ releases = $script:ChromeFallbackReleases[$Platform] }
                }
                if ($Uri -match "pageToken=") {
                    return [PSCustomObject] @{ releases = $script:ChromePage }
                }
                $response = [PSCustomObject] @{ releases = $script:ChromeReleases[$Platform] }
                if ($null -ne $script:ChromePage) {
                    $response | Add-Member -NotePropertyName nextPageToken -NotePropertyValue "next/page+token"
                }
                return $response
            }
        }

        It "logs verbose query and selection details without changing result objects" {
            $script:ChromeResource.Get.Update.Platforms = @("win")
            Mock Write-Verbose {}
            $result = @(Get-GoogleChrome -res $script:ChromeResource -WarningAction SilentlyContinue -Verbose)
            $result.Count | Should -Be 2
            $result[0].Version | Should -Be "140.0.1.1"
            Should -Invoke Write-Verbose -Times 1 -Exactly -ParameterFilter {
                $Message -like "*Platform: win. Channels: Stable."
            }
            Should -Invoke Write-Verbose -Times 1 -Exactly -ParameterFilter {
                $Message -like "*Querying fully rolled-out, unended releases: https://versionhistory.googleapis.com/*"
            }
            Should -Invoke Write-Verbose -Times 1 -Exactly -ParameterFilter {
                $Message -like "*Retrieved 1 release intervals for win."
            }
            Should -Invoke Write-Verbose -Times 1 -Exactly -ParameterFilter {
                $Message -like "*Retained 1 channel/version candidates for win*"
            }
            Should -Invoke Write-Verbose -Times 1 -Exactly -ParameterFilter {
                $Message -like "*Selected Stable/win version 140.0.1.1, rollout start time *"
            }
            Should -Invoke Write-Verbose -Times 2 -Exactly -ParameterFilter {
                $Message -like "*Stable/win version 140.0.1.1. Download URI: https://dl.google.com/*"
            }
        }

        It "logs verbose pagination details" {
            $script:ChromeResource.Get.Update.Platforms = @("win")
            $script:ChromePage = @(New-ChromeRelease)
            Mock Write-Verbose {}
            Get-GoogleChrome -res $script:ChromeResource -WarningAction SilentlyContinue -Verbose | Out-Null
            Should -Invoke Write-Verbose -Times 2 -Exactly -ParameterFilter {
                $Message -like "*Querying fully rolled-out, unended releases:*"
            }
            Should -Invoke Write-Verbose -Times 1 -Exactly -ParameterFilter {
                $Message -like "*More releases available for win; waiting 200 milliseconds*"
            }
            Should -Invoke Write-Verbose -Times 1 -Exactly -ParameterFilter {
                $Message -like "*Retrieved 2 release intervals for win."
            }
        }

        It "logs verbose reasons for skipping platforms" {
            $script:ChromeResource.Get.Update.Channels = @("Canary")
            $script:ChromeReleases.win64 = @(New-ChromeRelease -Channel "canary")
            Mock Write-Verbose {}
            Get-GoogleChrome -res $script:ChromeResource -WarningAction SilentlyContinue -Verbose | Out-Null
            Should -Invoke Write-Verbose -Times 2 -Exactly -ParameterFilter {
                $Message -like "*Skipping platform *; no configured downloads."
            }
        }

        It "preserves dates, download URIs, and the output contract" {
            $result = @(Get-GoogleChrome -res $script:ChromeResource -WarningAction SilentlyContinue)
            $result.Count | Should -Be 6
            foreach ($item in $result) {
                $item.StartDate | Should -Be "2020-01-02"
                $item.Channel | Should -Be "Stable"
                $platform = switch ($item.Architecture) {
                    "x86" { "win" }
                    "x64" { "win64" }
                    "ARM64" { "win_arm64" }
                }
                $item.URI | Should -BeIn $script:ChromeResource.Get.Download.Uri.Stable.$platform
                @($item.PSObject.Properties.Name) | Should -Be @(
                    "Version", "StartDate", "Channel", "Architecture", "Type", "URI"
                )
            }
            @($result.Type | Sort-Object -Unique) | Should -Be @("msi", "zip")
            Should -Invoke Invoke-EvergreenRestMethod -Times 3 -Exactly
        }

        It "uses default resources with dictionary-backed channel downloads" {
            $downloads = $script:ChromeResource.Get.Download.Uri.Stable
            $script:ChromeResource.Get.Download.Uri.Stable = [ordered] @{
                win       = $downloads.win
                win64     = $downloads.win64
                win_arm64 = $downloads.win_arm64
            }
            Mock Get-FunctionResource { $script:ChromeResource }
            Set-StrictMode -Version Latest
            $result = @(Get-GoogleChrome -WarningAction SilentlyContinue)
            $result.Count | Should -Be 6
            @($result | Where-Object Architecture -EQ "x86").Version | Should -Be @("140.0.1.1", "140.0.1.1")
            @($result | Where-Object Architecture -EQ "x64").Version | Should -Be @("140.0.1.2", "140.0.1.2")
            @($result | Where-Object Architecture -EQ "ARM64").Version | Should -Be @("140.0.1.3", "140.0.1.3")
            Should -Invoke Get-FunctionResource -Times 1 -Exactly -ParameterFilter { $AppName -eq "GoogleChrome" }
            Should -Invoke Invoke-EvergreenRestMethod -Times 3 -Exactly
        }

        It "skips absent dictionary download keys under strict mode" {
            $script:ChromeResource.Get.Update.Channels = @("Canary")
            $downloads = $script:ChromeResource.Get.Download.Uri.Canary
            $script:ChromeResource.Get.Download.Uri.Canary = [ordered] @{ win64 = $downloads.win64 }
            $script:ChromeReleases.win64 = @(New-ChromeRelease -Channel "canary")
            Set-StrictMode -Version Latest
            $result = @(Get-GoogleChrome -res $script:ChromeResource -WarningAction SilentlyContinue)
            $result.Count | Should -Be 1
            $result[0].Architecture | Should -Be "x64"
            Should -Invoke Invoke-EvergreenRestMethod -Times 1 -Exactly
        }

        It "queries fully rolled-out unended releases once per platform" {
            $result = @(Get-GoogleChrome -res $script:ChromeResource -WarningAction SilentlyContinue)
            @($result | Where-Object Architecture -EQ "x86").Version | Should -Be @("140.0.1.1", "140.0.1.1")
            @($result | Where-Object Architecture -EQ "x64").Version | Should -Be @("140.0.1.2", "140.0.1.2")
            @($result | Where-Object Architecture -EQ "ARM64").Version | Should -Be @("140.0.1.3", "140.0.1.3")
            Should -Invoke Invoke-EvergreenRestMethod -Times 3 -Exactly -ParameterFilter {
                $Uri -match "/channels/all/versions/all/releases\?filter=fraction%3D1%2Cendtime%3Dnone$"
            }
        }

        It "accepts already parsed DateTime timestamps" {
            $script:ChromeReleases.win[0].serving.startTime = [datetime]"2020-01-02T03:04:05Z"
            $result = @(Get-GoogleChrome -res $script:ChromeResource -WarningAction SilentlyContinue)
            $result[0].StartDate | Should -Be "2020-01-02"
        }

        It "selects by start time rather than the highest published version" {
            $script:ChromeReleases.win = @(
                New-ChromeRelease -Version "141.0.1.1"
                New-ChromeRelease -Version "140.0.1.1" -StartTime "2021-02-03T04:05:06Z"
            )
            $result = @(Get-GoogleChrome -res $script:ChromeResource -WarningAction SilentlyContinue)
            $result[0].Version | Should -Be "140.0.1.1"
            $result[0].StartDate | Should -Be "2021-02-03"
        }

        It "reduces duplicate intervals to the earliest start for each channel and version" {
            $script:ChromeReleases.win = @(
                New-ChromeRelease -Version "141.0.1.1" -StartTime "2022-01-01T00:00:00Z"
                New-ChromeRelease -Version "140.0.1.1" -StartTime "2021-01-01T00:00:00Z"
                New-ChromeRelease -Version "141.0.1.1" -StartTime "2020-01-01T00:00:00Z"
            )
            $result = @(Get-GoogleChrome -res $script:ChromeResource -WarningAction SilentlyContinue)
            $result[0].Version | Should -Be "140.0.1.1"
            $result[0].StartDate | Should -Be "2021-01-01"
        }

        It "breaks start time ties by numeric version rather than string ordering" {
            $script:ChromeReleases.win = @(
                New-ChromeRelease -Version "140.0.9.1"
                New-ChromeRelease -Version "140.0.10.1"
            )
            $result = @(Get-GoogleChrome -res $script:ChromeResource -WarningAction SilentlyContinue)
            $result[0].Version | Should -Be "140.0.10.1"
        }

        It "compares timestamps by instant rather than their text or local time" {
            $script:ChromeReleases.win = @(
                New-ChromeRelease -Version "141.0.1.1" -StartTime "2021-01-02T01:00:00+02:00"
                New-ChromeRelease -Version "140.0.1.1" -StartTime "2021-01-02T00:00:00Z"
            )
            $result = @(Get-GoogleChrome -res $script:ChromeResource -WarningAction SilentlyContinue)
            $result[0].Version | Should -Be "140.0.1.1"
        }

        It "checks subsequent pages before reducing rollout intervals" {
            $script:ChromeReleases.win = @(
                New-ChromeRelease -Version "141.0.1.1" -StartTime "2022-01-01T00:00:00Z"
                New-ChromeRelease -Version "140.0.1.1" -StartTime "2021-01-01T00:00:00Z"
            )
            $script:ChromePage = @(New-ChromeRelease -Version "141.0.1.1")
            $result = @(Get-GoogleChrome -res $script:ChromeResource -WarningAction SilentlyContinue)
            $result[0].Version | Should -Be "140.0.1.1"
            Should -Invoke Invoke-EvergreenRestMethod -Times 3 -Exactly -ParameterFilter {
                $Uri -match "pageToken=next%2Fpage%2Btoken$"
            }
            Should -Invoke Start-Sleep -Times 3 -Exactly -ParameterFilter { $Milliseconds -eq 200 }
        }

        It "handles an omitted releases array on an intermediate page under strict mode" {
            $script:ChromeResource.Get.Update.Platforms = @("win")
            $script:ChromePage = @(New-ChromeRelease)
            Mock Invoke-EvergreenRestMethod {
                param($Uri)
                if ($Uri -notmatch "pageToken=") {
                    return [PSCustomObject] @{ nextPageToken = "empty" }
                }
                if ($Uri -match "pageToken=empty$") {
                    return [PSCustomObject] @{ nextPageToken = "final" }
                }
                return [PSCustomObject] @{ releases = $script:ChromePage }
            }
            Set-StrictMode -Version Latest
            $result = @(Get-GoogleChrome -res $script:ChromeResource -WarningAction SilentlyContinue)
            $result.Count | Should -Be 2
            Should -Invoke Invoke-EvergreenRestMethod -Times 3 -Exactly
            Should -Invoke Start-Sleep -Times 2 -Exactly
        }

        It "selects all configured channels independently and ignores canary_asan" {
            $script:ChromeResource.Get.Update.Channels = @("Extended", "Stable", "Beta", "Dev", "Canary")
            $script:ChromeReleases.win64 = @(
                New-ChromeRelease -Channel "extended" -Version "138.0.1.1"
                New-ChromeRelease -Channel "stable" -Version "140.0.1.1"
                New-ChromeRelease -Channel "beta" -Version "141.0.1.1"
                New-ChromeRelease -Channel "dev" -Version "142.0.1.1"
                New-ChromeRelease -Channel "canary" -Version "143.0.1.1"
                New-ChromeRelease -Channel "canary_asan" -Version "144.0.1.1"
                New-ChromeRelease -Channel "stable" -Version "138.0.1.1" -StartTime "2019-01-01T00:00:00Z"
            )
            $script:ChromeResource.Get.Update.Platforms = @("win64")
            $result = @(Get-GoogleChrome -res $script:ChromeResource -WarningAction SilentlyContinue)
            $result.Count | Should -Be 7
            @($result.Channel) | Should -Be @("Extended", "Extended", "Stable", "Stable", "Beta", "Dev", "Canary")
            @($result.Version) | Should -Be @("138.0.1.1", "138.0.1.1", "140.0.1.1", "140.0.1.1", "141.0.1.1", "142.0.1.1", "143.0.1.1")
            Should -Invoke Invoke-EvergreenRestMethod -Times 1 -Exactly
        }

        It "skips platforms with no configured downloads before making API requests" {
            $script:ChromeResource.Get.Update.Channels = @("Canary")
            $script:ChromeReleases.win64 = @(New-ChromeRelease -Channel "canary")
            Set-StrictMode -Version Latest
            $result = @(Get-GoogleChrome -res $script:ChromeResource -WarningAction SilentlyContinue)
            $result.Count | Should -Be 1
            $result[0].Architecture | Should -Be "x64"
            $result[0].Type | Should -Be "exe"
            Should -Invoke Invoke-EvergreenRestMethod -Times 1 -Exactly
            Should -Invoke Invoke-EvergreenRestMethod -Times 0 -Exactly -ParameterFilter {
                $Uri -notmatch "/win64/"
            }
        }

        It "uses an active release when no fully rolled-out release is available" {
            $script:ChromeResource.Get.Update.Channels = @("Extended")
            $script:ChromeResource.Get.Update.Platforms = @("win")
            $script:ChromeReleases.win = @()
            $script:ChromeFallbackReleases.win = @(
                New-ChromeRelease -Channel "extended" -Version "141.0.2.3"
            )
            $result = @(Get-GoogleChrome -res $script:ChromeResource -WarningAction SilentlyContinue)
            $result.Count | Should -Be 2
            @($result.Version | Sort-Object -Unique) | Should -Be @("141.0.2.3")
            @($result.URI) | Should -Be $script:ChromeResource.Get.Download.Uri.Extended.win
            Should -Invoke Invoke-EvergreenRestMethod -Times 2 -Exactly
            Should -Invoke Invoke-EvergreenRestMethod -Times 1 -Exactly -ParameterFilter {
                $Uri -match "filter=endtime%3Dnone$"
            }
        }

        It "skips a channel when neither fully rolled-out nor active releases are available" {
            $script:ChromeResource.Get.Update.Platforms = @("win")
            $script:ChromeReleases.win = @(New-ChromeRelease -Channel "canary_asan")
            $result = @(Get-GoogleChrome -res $script:ChromeResource -WarningAction SilentlyContinue)
            $result.Count | Should -Be 0
        }

        It "skips empty download lists without querying the API" {
            $script:ChromeResource.Get.Update.Platforms = @("win")
            $script:ChromeResource.Get.Download.Uri.Stable.win = @()
            $result = @(Get-GoogleChrome -res $script:ChromeResource -WarningAction SilentlyContinue)
            $result.Count | Should -Be 0
            Should -Invoke Invoke-EvergreenRestMethod -Times 0 -Exactly
        }

        It "skips a channel when the API returns no releases" {
            $script:ChromeResource.Get.Update.Platforms = @("win")
            $script:ChromeReleases.win = @()
            $result = @(Get-GoogleChrome -res $script:ChromeResource -WarningAction SilentlyContinue)
            $result.Count | Should -Be 0
        }

        It "skips a channel on an empty final page with omitted proto3 fields" {
            Mock Invoke-EvergreenRestMethod { [PSCustomObject] @{} }
            Set-StrictMode -Version Latest
            $result = @(Get-GoogleChrome -res $script:ChromeResource -WarningAction SilentlyContinue)
            $result.Count | Should -Be 0
        }

        It "skips a release without a version" {
            $script:ChromeResource.Get.Update.Platforms = @("win")
            $script:ChromeReleases.win[0].version = $null
            $result = @(Get-GoogleChrome -res $script:ChromeResource -WarningAction SilentlyContinue)
            $result.Count | Should -Be 0
        }

        It "skips a release without a start time" {
            $script:ChromeResource.Get.Update.Platforms = @("win")
            $script:ChromeReleases.win[0].serving.startTime = $null
            $result = @(Get-GoogleChrome -res $script:ChromeResource -WarningAction SilentlyContinue)
            $result.Count | Should -Be 0
        }

        It "propagates request failures rather than emitting fabricated results" {
            Mock Invoke-EvergreenRestMethod { throw "API unavailable" }
            { Get-GoogleChrome -res $script:ChromeResource -WarningAction SilentlyContinue } |
                Should -Throw "*API unavailable*"
        }
    }
}
