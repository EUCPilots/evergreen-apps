function Get-Microsoft.NET {
    <#
        .SYNOPSIS
            Returns the available Microsoft .NET Desktop Runtime versions and download URIs.

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

    # Release cache to store previously fetched release JSON data to avoid redundant network calls
    $ReleaseCache = @{}

    # Read the version number from the version URI
    foreach ($Channel in $res.Get.Update.Channels) {

        # Determine the version for each channel
        Write-Verbose -Message "$($MyInvocation.MyCommand): Find latest version for channel: $Channel"
        $Content = Invoke-EvergreenRestMethod -Uri $($res.Get.Update.Uri -replace $res.Get.Update.ReplaceText, $Channel)
        if ($null -ne $Content) {

            # Log the raw content returned for the channel before processing it
            Write-Verbose -Message "$($MyInvocation.MyCommand): Returned: $Content."
            $FeedVersion = ([string]$Content).Trim()
            $VersionString = ($FeedVersion -split "-", 2)[0]
            $Version = $null
            if (-not [System.Version]::TryParse($VersionString, [ref]$Version)) {
                Write-Error -Message "$($MyInvocation.MyCommand): Invalid version returned for channel '$Channel': '$FeedVersion'."
                continue
            }

            # Log the parsed version information
            $MajorMinor = "$($Version.Major).$($Version.Minor)"
            Write-Verbose -Message "$($MyInvocation.MyCommand): Found version: $MajorMinor."

            # Read the releases JSON for that version
            Write-Verbose -Message "$($MyInvocation.MyCommand): Get releases list for $Channel, version: $MajorMinor."
            $ReleasesUri = $res.Get.Download.Uri -replace $res.Get.Download.ReplaceText, $MajorMinor
            if (-not $ReleaseCache.ContainsKey($ReleasesUri)) {
                $ReleaseCache[$ReleasesUri] = Invoke-EvergreenRestMethod -Uri $ReleasesUri
            }
            $Releases = $ReleaseCache[$ReleasesUri]

            # Log the releases URI being used
            if ($null -ne $Releases) {
                $ReleaseEntries = @($Releases.releases)
                if ($ReleaseEntries.Count -eq 0) {
                    Write-Error -Message "$($MyInvocation.MyCommand): No releases found for channel '$Channel', version '$MajorMinor'."
                    continue
                }

                # Find the release entry that matches the feed version
                $Release = $ReleaseEntries | Where-Object { $_.'release-version' -eq $FeedVersion } | Select-Object -First 1
                if ($null -eq $Release) {
                    Write-Error -Message "$($MyInvocation.MyCommand): No release matching version '$FeedVersion' found for channel '$Channel'."
                    continue
                }

                # Convert the release date to a DateTime object for easier handling
                $ReleaseDate = ConvertTo-DateTime -DateTime $Release.'release-date' -AutoDetect
                Write-Verbose -Message "$($MyInvocation.MyCommand): Found $($ReleaseEntries.Count) release/s."
                Write-Verbose -Message "$($MyInvocation.MyCommand): Release date for version '$FeedVersion': $ReleaseDate."

                # Step through each release type
                foreach ($Installer in $res.Get.Download.Installers) {
                    Write-Verbose -Message "$($MyInvocation.MyCommand): Build for type: $Installer."
                    $InstallerRelease = $Release.PSObject.Properties[$Installer].Value
                    if ($null -eq $InstallerRelease -or $null -eq $InstallerRelease.files) {
                        Write-Error -Message "$($MyInvocation.MyCommand): No files found for installer '$Installer' in release '$FeedVersion'."
                        continue
                    }

                    # Each installer includes multiple file types and platforms
                    $Files = @($InstallerRelease.files)
                    Write-Verbose -Message "$($MyInvocation.MyCommand): Found $($Files.Count) files."
                    foreach ($File in $Files) {

                        # Filter for .exe only so that we get Windows installers
                        if ($File.name -notmatch "\.exe$") {
                            continue
                        }

                        $ParsedUri = $null
                        if (-not [System.Uri]::TryCreate([string]$File.url, [System.UriKind]::Absolute, [ref]$ParsedUri)) {
                            Write-Error -Message "$($MyInvocation.MyCommand): Invalid download URI for installer '$Installer' in release '$FeedVersion': '$($File.url)'."
                            continue
                        }

                        # Build the output object; output it to the pipeline
                        $PSObject = [PSCustomObject] @{
                            Version      = $InstallerRelease.version
                            Channel      = $Channel
                            Support      = $Releases.'support-phase'
                            Date         = $ReleaseDate
                            Installer    = $Installer
                            Sha512       = $File.hash
                            Architecture = if (-not [string]::IsNullOrWhiteSpace([string]$File.rid)) { Get-Architecture -String $File.rid } else { Get-Architecture -String $File.url }
                            Type         = [System.IO.Path]::GetExtension($ParsedUri.AbsolutePath).TrimStart(".")
                            URI          = $File.url
                        }
                        Write-Output -InputObject $PSObject
                    }
                }
            }
        }
    }
}
