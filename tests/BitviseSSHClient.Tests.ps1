BeforeDiscovery {
    Import-Module -Name Evergreen -ErrorAction Stop
}

Describe "Bitvise SSH Client update discovery" {
    InModuleScope Evergreen {
        BeforeAll {
            $RepositoryRoot = Split-Path -Path $PSScriptRoot -Parent
            . (Join-Path -Path $RepositoryRoot -ChildPath "Apps/Get-BitviseSSHClient.ps1")
            $script:BitviseResource = Get-Content -Path (Join-Path -Path $RepositoryRoot -ChildPath "Manifests/BitviseSSHClient.json") -Raw |
                ConvertFrom-Json
        }

        BeforeEach {
            $script:BitviseXml = '<versions><version ver="9.67" minupax="2026-11-09" sha512="checksum" installer="https://dl.bitvise.com/BvSshClient-967.exe" /><note>' +
                [char]0x00e9 + '</note></versions>'
            Mock Invoke-EvergreenWebRequest {
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($script:BitviseXml)
                $length = [System.BitConverter]::GetBytes([uint32]$bytes.Length)
                if ([System.BitConverter]::IsLittleEndian) {
                    [System.Array]::Reverse($length)
                }
                $frame = [byte[]]($length + $bytes + [byte[]](0, 0, 0, 4, 255, 254, 253, 252))
                [PSCustomObject]@{ RawContentStream = [System.IO.MemoryStream]::new($frame) }
            }
        }

        It "extracts installer metadata from framed UTF-8 XML" {
            $result = @(Get-BitviseSSHClient -res $script:BitviseResource)
            $result.Count | Should -Be 1
            $result[0].Version | Should -BeExactly "9.67"
            $result[0].Date | Should -Be (Get-Date "2026-11-09")
            $result[0].Sha512 | Should -BeExactly "checksum"
            $result[0].Type | Should -BeExactly "exe"
            $result[0].URI | Should -BeExactly "https://dl.bitvise.com/BvSshClient-967.exe"
            Should -Invoke Invoke-EvergreenWebRequest -Times 1 -Exactly -ParameterFilter {
                $Uri -eq $script:BitviseResource.Get.Update.Uri -and $ReturnObject -eq "All"
            }
        }

        It "rejects a truncated frame" {
            Mock Invoke-EvergreenWebRequest {
                [PSCustomObject]@{ RawContentStream = [System.IO.MemoryStream]::new([byte[]](0, 0, 0, 20, 60)) }
            }
            { Get-BitviseSSHClient -res $script:BitviseResource } | Should -Throw "*Invalid Bitvise update response*"
        }

        It "rejects a truncated length prefix" {
            Mock Invoke-EvergreenWebRequest {
                [PSCustomObject]@{ RawContentStream = [System.IO.MemoryStream]::new([byte[]](0, 0)) }
            }
            { Get-BitviseSSHClient -res $script:BitviseResource } | Should -Throw "*missing XML length*"
        }

        It "rejects malformed XML" {
            $script:BitviseXml = '<versions>'
            { Get-BitviseSSHClient -res $script:BitviseResource } | Should -Throw
        }

        It "rejects XML without installer metadata" {
            $script:BitviseXml = '<versions><version ver="9.67" /></versions>'
            { Get-BitviseSSHClient -res $script:BitviseResource } | Should -Throw "*missing*"
        }
    }
}
