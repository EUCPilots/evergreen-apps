function Get-genuagenuReSI {
    <#
        .SYNOPSIS
            Returns the available genua genuReSI versions.
    #>
    [OutputType([System.Management.Automation.PSObject])]
    [CmdletBinding(SupportsShouldProcess = $false)]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateNotNull()]
        [System.Management.Automation.PSObject]
        $res = (Get-FunctionResource -AppName ("$($MyInvocation.MyCommand)".Split("-"))[1])
    )

    # Get the latest version information
    $LatestVersion = Invoke-EvergreenRestMethod -Uri $res.Get.Update.Uri

    # Add validation
    if (-not [System.Double]::TryParse($LatestVersion, [ref]$null)) {
        Write-Warning -Message "$($MyInvocation.MyCommand): Invalid version format: $LatestVersion"
        return
    }

    # Normalize version number to two decimal places (culture-invariant)
    $NormalizedVersion = [System.Double]::Parse($LatestVersion.ToString().Replace(",", "."), [System.Globalization.CultureInfo]::InvariantCulture).ToString("F2", [System.Globalization.CultureInfo]::InvariantCulture)

    # Get the checksum details
    $Checksum = Invoke-EvergreenRestMethod -Uri ($res.Get.Download.ChecksumUri -replace "#version", $NormalizedVersion)
    if ($null -ne $Checksum) {
        $Sha256 = $null
        if ($Checksum -match $res.Get.Download.MatchChecksum) {
            $Sha256 = $Matches[1]
        }
    }

    [PSCustomObject]@{
        Version = $NormalizedVersion
        Sha256  = $Sha256
        URI     = $res.Get.Download.Uri -replace "#version", $NormalizedVersion
    }
}
