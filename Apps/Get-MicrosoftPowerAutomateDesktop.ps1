#Requires -Module @{ ModuleName="Evergreen"; ModuleVersion="2510.2799.0" }
function Get-MicrosoftPowerAutomateDesktop {
    <#
        .SYNOPSIS
            Get the current version and download URL for Microsoft Power Automate Desktop.

        .NOTES
            Author: Aaron Parker
    #>
    [OutputType([System.Management.Automation.PSObject])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Justification = "Product name is a plural")]
    [CmdletBinding(SupportsShouldProcess = $false)]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateNotNull()]
        [System.Management.Automation.PSObject]
        $res = (Get-FunctionResource -AppName ("$($MyInvocation.MyCommand)".Split("-"))[1])
    )

    # Get the update information
    $Resolved = Resolve-MicrosoftFwLink -Uri $res.Get.Update.Uri -WarningAction "Ignore"
    Write-Verbose -Message "$($MyInvocation.MyCommand): Resolved update URL: $($Resolved.Uri)."

    # Download the CAB file
    $CabFile = Save-File -Uri $Resolved.Uri
    if ($null -ne $CabFile) {
        
        # Expand the CAB file and find the JSON update file
        $Files = Expand-CabArchive -Path $CabFile.FullName -DestinationPath $CabFile.DirectoryName
        $UpdateFile = $Files | Where-Object { $_ -match $res.Get.Update.File }
        Write-Verbose -Message "$($MyInvocation.MyCommand): Found update file: $($UpdateFile)."
        $Update = Get-Content -Path $UpdateFile | ConvertFrom-Json

        # Get the update object and set properties
        $ResolvedUpdate = Resolve-MicrosoftFwLink -Uri $res.Get.Download.Uri
        $ResolvedUpdate.Version = $Update.latestVersion.version
        $ResolvedUpdate.Date = $Update.latestVersion.releaseDate
        Write-Output -InputObject $ResolvedUpdate
    }
}
