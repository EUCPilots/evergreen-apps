function Get-ZabbixAgent2 {
    <#
        .SYNOPSIS
            Returns the latest Zabbix Agent 2 version number and download.

        .NOTES
            Author: Aaron Parker
    #>
    [OutputType([System.Management.Automation.PSObject])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Justification="Product name is a plural")]
    [CmdletBinding(SupportsShouldProcess = $false)]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateNotNull()]
        [System.Management.Automation.PSObject]
        $res = (Get-FunctionResource -AppName ("$($MyInvocation.MyCommand)".Split("-"))[1])
    )

    # Get the latest update information
    $UpdateYaml = Invoke-EvergreenRestMethod -Uri $res.Get.Update.Uri

    if ($null -ne $UpdateYaml) {
        $SoftwareVersion = $null
        $ReleaseDate = $null

        # Parse the YAML for the software version and release date
        foreach ($Line in ($UpdateYaml -split "`r?`n")) {
            if ($Line -match '^softwareVersion\s*:\s*[''"]?([^''"]+)[''"]?\s*$') {
                $SoftwareVersion = $matches[1].Trim() -replace '^Zabbix\s+', ''
            }
            elseif ($Line -match '^releaseDate\s*:\s*[''"]?([^''"]+)[''"]?\s*$') {
                $ReleaseDate = $matches[1].Trim()
            }
        }

        # Extract the minor version from the software version
        $MinorVersion = [RegEx]::Match($SoftwareVersion, '^\d+\.\d+').Value

        # Construct the download URIs and return the results
        if (-not [System.String]::IsNullOrWhiteSpace($SoftwareVersion) -and
            -not [System.String]::IsNullOrWhiteSpace($MinorVersion) -and
            -not [System.String]::IsNullOrWhiteSpace($ReleaseDate)) {
            foreach ($DownloadUri in $res.Get.Download.Uri) {
                $Uri = $DownloadUri.Replace('#softwareVersion', $SoftwareVersion).Replace('#minorVersion', $MinorVersion)
                [PSCustomObject]@{
                    Version      = $SoftwareVersion
                    Date         = $ReleaseDate #ConvertTo-DateTime -DateTime $ReleaseDate -Pattern $res.Get.Update.DateTimeFormat
                    Encryption   = if ($Uri -match 'openssl') { 'OpenSSL' } else { 'None' }
                    Architecture = Get-Architecture -String $Uri
                    Type         = Get-FileType -File $Uri
                    URI          = $Uri
                }
            }
        }
    }
}
