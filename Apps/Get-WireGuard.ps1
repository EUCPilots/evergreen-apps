function Get-WireGuard {
    <#
        .SYNOPSIS
            Get the current WireGuard installers from the published signature file.

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

    # Get the latest WireGuard installers from the signature file
    $Response = Invoke-EvergreenWebRequest -Uri $res.Get.Update.Uri -Raw

    # Parse the signature file to extract installer filenames, versions and SHA256 hashes
    $Installers = [regex]::Matches(($Response -join "`n"), $res.Get.Update.MatchPattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)
    if ($Installers.Count -eq 0) {
        throw "$($MyInvocation.MyCommand): No Windows installers found in $($res.Get.Update.Uri)."
    }

    # Ensure the signature file contains valid installer entries
    foreach ($Installer in $Installers) {
        $Uri = $res.Get.Download.Uri -replace "#filename", $Installer.Groups["Filename"].Value
        [PSCustomObject] @{
            Version      = $Installer.Groups["Version"].Value
            Architecture = Get-Architecture -String $Uri
            Type         = Get-FileType -File $Uri
            Sha256       = $Installer.Groups["Sha256"].Value
            URI          = $Uri
        } | Write-Output
    }
}
