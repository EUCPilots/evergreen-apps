function Get-MendeleyReferenceManager {
    <#
        .SYNOPSIS
            Get the current version and download URL for Mendeley Reference Manager.
    #>
    [OutputType([System.Management.Automation.PSObject])]
    [CmdletBinding(SupportsShouldProcess = $false)]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateNotNull()]
        [System.Management.Automation.PSObject]
        $res = (Get-FunctionResource -AppName ("$($MyInvocation.MyCommand)".Split("-"))[1])
    )

    # Get the latest update info
    $UpdateYaml = Invoke-EvergreenRestMethod -Uri $res.Get.Update.Uri

    # Build a PSCustomObject from the YAML content
    if ($null -ne $UpdateYaml) {
        Write-Verbose -Message "$($MyInvocation.MyCommand): Converting YAML content to object."

        $lines = $UpdateYaml -split "`r?`n"
        $result = @{
            Version     = $null
            ReleaseDate = $null
            Downloads   = @()
        }
        $currentDownload = $null
        $inDownloadsSection = $false
        foreach ($line in $lines) {
            # Skip empty lines and comments
            if ([System.String]::IsNullOrWhiteSpace($line) -or $line.TrimStart() -match '^#') {
                continue
            }

            # Extract version (various common formats)
            if ($line -match '^\s*version\s*:\s*[''"]?([^''"]+)[''"]?\s*$') {
                $result.Version = $matches[1].Trim()
            }

            # Extract release date (various common formats)
            if ($line -match '^\s*(?:release_?date|releaseDate|date)\s*:\s*[''"]?([^''"]+)[''"]?\s*$') {
                $result.ReleaseDate = $matches[1].Trim()
            }

            # Detect downloads section
            if ($line -match '^\s*files\s*:\s*$') {
                $inDownloadsSection = $true
                continue
            }

            if ($inDownloadsSection) {
                # New download entry (starts with dash or hyphen at specific indentation)
                if ($line -match '^\s*-\s*(?:url\s*:\s*(.+)|$)') {
                    # Save previous download if exists
                    if ($currentDownload -and ($currentDownload.url -or $currentDownload.sha512 -or $currentDownload.size)) {
                        $result.Downloads += [PSCustomObject]$currentDownload
                    }

                    # Start new download
                    $currentDownload = @{
                        url    = $null
                        sha512 = $null
                        size   = $null
                    }

                    # Check if url is on the same line
                    if ($matches[1]) {
                        $currentDownload.url = $matches[1].Trim(' ''"`t')
                    }
                }
                # URL property
                elseif ($line -match '^\s+url\s*:\s*(.+)$') {
                    if ($currentDownload) {
                        $currentDownload.url = $matches[1].Trim(' ''"`t')
                    }
                }
                # SHA512 property
                elseif ($line -match '^\s+sha512\s*:\s*(.+)$') {
                    if ($currentDownload) {
                        $currentDownload.sha512 = $matches[1].Trim(' ''"`t')
                    }
                }
                # Size property
                elseif ($line -match '^\s+size\s*:\s*(.+)$') {
                    if ($currentDownload) {
                        $sizeValue = $matches[1].Trim(' ''"`t')
                        # Try to convert to number if possible
                        if ($sizeValue -match '^\d+$') {
                            $currentDownload.size = [int64]$sizeValue
                        }
                        else {
                            $currentDownload.size = $sizeValue
                        }
                    }
                }
                # End of downloads section (non-indented key or end of indented section)
                elseif ($line -match '^\S' -and $line -notmatch '^\s*-') {
                    # Save the last download entry
                    if ($currentDownload -and ($currentDownload.url -or $currentDownload.sha512 -or $currentDownload.size)) {
                        $result.Downloads += [PSCustomObject]$currentDownload
                    }
                    $inDownloadsSection = $false
                    $currentDownload = $null
                }
            }
        }

        # Save the last download entry if still in downloads section
        if ($inDownloadsSection -and $currentDownload -and ($currentDownload.url -or $currentDownload.sha512 -or $currentDownload.size)) {
            $result.Downloads += [PSCustomObject]$currentDownload
        }

        # Return the final object that we can use to build the output
        Write-Verbose -Message "$($MyInvocation.MyCommand): Converted YAML to PSCustomObject."
        $YamlObject = [PSCustomObject]$result

        # Build output objects, filtering the .Downloads to unique entries
        foreach ($File in ($YamlObject.Downloads | Select-Object -Unique -Property "size", "sha512", "url")) {
            [PSCustomObject]@{
                Version      = $YamlObject.Version
                Date         = ConvertTo-DateTime -DateTime $YamlObject.ReleaseDate -Pattern $res.Get.Update.DateTimeFormat
                Size         = $File.size
                Sha512       = $File.sha512
                Architecture = Get-Architecture -String $File.url
                Type         = Get-FileType -File $File.url
                URI          = $res.Get.Download.Uri -replace "#filename", $File.url
            }
        }
    }
}
