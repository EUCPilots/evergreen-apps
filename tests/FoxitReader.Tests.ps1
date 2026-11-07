BeforeDiscovery {
    Import-Module -Name Evergreen -ErrorAction Stop
}

Describe "Foxit Reader package discovery" {
    InModuleScope Evergreen {
        BeforeAll {
            $RepositoryRoot = Split-Path -Path $PSScriptRoot -Parent
            . (Join-Path -Path $RepositoryRoot -ChildPath "Apps/Get-FoxitReader.ps1")
            $script:FoxitReaderResource = Get-Content -Path (Join-Path -Path $RepositoryRoot -ChildPath "Manifests/FoxitReader.json") -Raw |
                ConvertFrom-Json
        }

        It "skips Foxit's stale MSI package and returns the current package types" {
            $script:FoxitTestToken = "regression-token"
            $portProbe = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
            $portProbe.Start()
            $port = $portProbe.LocalEndpoint.Port
            $portProbe.Stop()

            $serverJob = Start-Job -ArgumentList $port, $script:FoxitTestToken -ScriptBlock {
                param($Port, $Token)

                $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $Port)
                $listener.Start()
                Write-Output -InputObject "ready"
                try {
                    $client = $listener.AcceptTcpClient()
                    $stream = $client.GetStream()
                    $reader = [System.IO.StreamReader]::new($stream, [System.Text.Encoding]::ASCII, $false, 1024, $true)
                    do {
                        $line = $reader.ReadLine()
                    } while ($null -ne $line -and $line.Length -gt 0)

                    $response = "HTTP/1.1 200 OK`r`nSet-Cookie: token=$Token; Path=/`r`nContent-Length: 0`r`nConnection: close`r`n`r`n"
                    $bytes = [System.Text.Encoding]::ASCII.GetBytes($response)
                    $stream.Write($bytes, 0, $bytes.Length)
                    $stream.Flush()
                    $reader.Dispose()
                    $stream.Dispose()
                    $client.Close()
                }
                finally {
                    $listener.Stop()
                }
            }

            try {
                $serverReady = $false
                for ($attempt = 0; $attempt -lt 100; $attempt++) {
                    if (@(Receive-Job -Job $serverJob -Keep -ErrorAction SilentlyContinue) -contains "ready") {
                        $serverReady = $true
                        break
                    }
                    if ($serverJob.State -ne "Running") {
                        break
                    }
                    Start-Sleep -Milliseconds 50
                }
                $serverReady | Should -BeTrue

                $script:FoxitReaderResource.Get.Update.InitialUri = "http://127.0.0.1:$port/"
                $version = [PSCustomObject]@{}
                $version | Add-Member -MemberType NoteProperty -Name "2025.3.0.35737" -Value "2025.3.0.35737"
                $script:FoxitMetadata = [PSCustomObject]@{
                    data = [PSCustomObject]@{
                        version      = $version
                        package_type = [PSCustomObject]@{
                            msi = $true
                            zip = $true
                            exe = $true
                            msp = $true
                        }
                    }
                }
                $script:FoxitDownloadUris = @{
                    msi = "https://cdn01.foxitsoftware.com/product/reader/desktop/win/2025.1.0/FoxitPDFReader20251_L10N_Setup.msi"
                    zip = "https://cdn01.foxitsoftware.com/product/reader/desktop/win/2025.3.0/FoxitPDFReader20253_L10N_Setup_Prom_x64.zip"
                    exe = "https://cdn01.foxitsoftware.com/product/reader/desktop/win/2025.3.0/FoxitPDFReader20253_L10N_Setup_Prom_x64.exe"
                    msp = "https://cdn01.foxitsoftware.com/product/reader/desktop/win/2025.3.0/FoxitPDFReader20253_L10N_Setup_Prom_x64.msp"
                }
                $script:FoxitRequestedTypes = @()

                Mock Invoke-EvergreenRestMethod {
                    param($Uri, $Headers)

                    if ($Headers["authorization"] -ne ("Bearer " + $script:FoxitTestToken)) {
                        throw "Foxit API request did not use the session bearer token."
                    }
                    if ($Uri -eq $script:FoxitReaderResource.Get.Update.Uri) {
                        return $script:FoxitMetadata
                    }

                    $fileType = [regex]::Match($Uri, "(?:\?|&)package_type=([^&]+)").Groups[1].Value
                    $script:FoxitRequestedTypes += $fileType
                    return [PSCustomObject]@{ data = $script:FoxitDownloadUris[$fileType] }
                }

                $result = @(Get-FoxitReader -res $script:FoxitReaderResource)
                $result.Count | Should -Be 3
                $result.Type | Should -Be @("zip", "exe", "msp")
                $result.Version | Should -Be @("2025.3.0.35737", "2025.3.0.35737", "2025.3.0.35737")
                $result.URI | Should -Be @(
                    $script:FoxitDownloadUris.zip
                    $script:FoxitDownloadUris.exe
                    $script:FoxitDownloadUris.msp
                )
                $script:FoxitRequestedTypes | Should -Be @("zip", "exe", "msp")
                $result.URI | Should -Not -Contain $script:FoxitDownloadUris.msi
                Should -Invoke Invoke-EvergreenRestMethod -Times 4 -Exactly
            }
            finally {
                if ($serverJob.State -eq "Running") {
                    Stop-Job -Job $serverJob -ErrorAction SilentlyContinue
                }
                Remove-Job -Job $serverJob -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
