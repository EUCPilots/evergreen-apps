function Get-UnityHub {
    <#
        .NOTES
            Author: Aaron Parker
    #>
    [OutputType([System.Management.Automation.PSObject])]
    [CmdletBinding(SupportsShouldProcess = $false)]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateNotNull()]
        [System.Management.Automation.PSObject]
        $res = (Get-FunctionResource -AppName ("$($MyInvocation.MyCommand)".Split("-"))[1])
    )

    $UpdateYaml = Invoke-EvergreenRestMethod -Uri $res.Get.Update.Uri
    if ($null -ne $UpdateYaml) {
        $lines = $UpdateYaml -split "`r?`n"
        $result = @{
            Version     = $null
            ReleaseDate = $null
            Files       = @()
        }
        $currentFile = $null
        $inFilesSection = $false

        foreach ($line in $lines) {
            if ([System.String]::IsNullOrWhiteSpace($line) -or $line.TrimStart() -match '^#') {
                continue
            }

            if ($line -match '^\s*version\s*:\s*[''\"]?([^''\"]+)[''\"]?\s*$') {
                $result.Version = $matches[1].Trim()
                continue
            }

            if ($line -match '^\s*releaseDate\s*:\s*[''\"]?([^''\"]+)[''\"]?\s*$') {
                $result.ReleaseDate = $matches[1].Trim()
                continue
            }

            if ($line -match '^\s*files\s*:\s*$') {
                $inFilesSection = $true
                continue
            }

            if ($inFilesSection) {
                if ($line -match '^\s*-\s*(?:url\s*:\s*(.+)|$)') {
                    if ($currentFile -and ($currentFile.url -or $currentFile.sha512 -or $currentFile.size)) {
                        $result.Files += [PSCustomObject]$currentFile
                    }

                    $currentFile = @{
                        url    = $null
                        sha512 = $null
                        size   = $null
                    }

                    if ($matches[1]) {
                        $currentFile.url = $matches[1].Trim(' ''"`t')
                    }
                    continue
                }

                if ($line -match '^\s+url\s*:\s*(.+)$') {
                    if ($currentFile) {
                        $currentFile.url = $matches[1].Trim(' ''"`t')
                    }
                    continue
                }

                if ($line -match '^\s+sha512\s*:\s*(.+)$') {
                    if ($currentFile) {
                        $currentFile.sha512 = $matches[1].Trim(' ''"`t')
                    }
                    continue
                }

                if ($line -match '^\s+size\s*:\s*(.+)$') {
                    if ($currentFile) {
                        $sizeValue = $matches[1].Trim(' ''"`t')
                        if ($sizeValue -match '^\d+$') {
                            $currentFile.size = [int64]$sizeValue
                        }
                        else {
                            $currentFile.size = $sizeValue
                        }
                    }
                    continue
                }

                if ($line -match '^\S' -and $line -notmatch '^\s*-') {
                    if ($currentFile -and ($currentFile.url -or $currentFile.sha512 -or $currentFile.size)) {
                        $result.Files += [PSCustomObject]$currentFile
                    }
                    $inFilesSection = $false
                    $currentFile = $null
                }
            }
        }

        if ($inFilesSection -and $currentFile -and ($currentFile.url -or $currentFile.sha512 -or $currentFile.size)) {
            $result.Files += [PSCustomObject]$currentFile
        }

        foreach ($File in ($result.Files | Select-Object -Unique -Property "url", "sha512", "size")) {
            if ([System.String]::IsNullOrWhiteSpace($File.url)) {
                continue
            }

            $downloadUri = [System.Uri]::new([System.Uri]$res.Get.Update.Uri, $File.url).AbsoluteUri
            [PSCustomObject]@{
                Version      = $result.Version
                Date         = ConvertTo-DateTime -DateTime $result.ReleaseDate
                Architecture = Get-Architecture -String $File.url
                Size         = $File.size
                Sha512       = $File.sha512
                Type         = Get-FileType -File $File.url
                URI          = $downloadUri
            }
        }
    }
}
