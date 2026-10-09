#Requires -Module @{ ModuleName="Evergreen"; ModuleVersion="2510.2802.0" }
function Get-MicrosoftPowerAutomateDesktop {
    <#
        .SYNOPSIS
            Get the current version and download URL for Microsoft Power Automate Desktop.

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

    # Get the update information
    $Resolved = Resolve-MicrosoftFwLink -Uri $res.Get.Update.Uri -WarningAction "SilentlyContinue"
    Write-Verbose -Message "$($MyInvocation.MyCommand): Resolved update URL: $($Resolved.Uri)."

    # Download the CAB file
    $CabFile = Save-File -Uri $Resolved.Uri
    if ($null -ne $CabFile) {
        
        # Expand the CAB file and find the JSON update file
        $Files = Expand-CabArchive -Path $CabFile.FullName -DestinationPath $CabFile.DirectoryName
        if ($null -ne $Files) {
            Write-Verbose -Message "$($MyInvocation.MyCommand): $($Files.Count) files expanded."
            $UpdateFile = $Files | Where-Object { $_ -match $res.Get.Update.File }
            Write-Verbose -Message "$($MyInvocation.MyCommand): $($UpdateFile.Count) update files found."
            Write-Verbose -Message "$($MyInvocation.MyCommand): Found update file: $($UpdateFile)."
            $Update = Get-Content -Path $UpdateFile | ConvertFrom-Json

            # Check if the update object was successfully parsed from the JSON file
            if ($Update -is [System.Management.Automation.PSObject]) {
                Write-Verbose -Message "$($MyInvocation.MyCommand): Update object successfully parsed."

                # Get the update object and set properties
                $ResolvedUpdate = Resolve-MicrosoftFwLink -Uri $res.Get.Download.Uri
                $ResolvedUpdate.Version = $Update.latestVersion.version
                $ResolvedUpdate.Date = $Update.latestVersion.releaseDate
                Write-Output -InputObject $ResolvedUpdate
            }
            else {
                throw "$($MyInvocation.MyCommand): Failed to parse update file as JSON."
            }
        }
        else {
            throw "$($MyInvocation.MyCommand): No files expanded from CAB archive."
        }
    }
}
