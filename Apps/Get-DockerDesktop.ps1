function Get-DockerDesktop {
    <#
        .SYNOPSIS
            Returns the available Docker Desktop versions.

        .NOTES
            Author: Andrew Cooper
            Twitter: @adotcoop
    #>
    [OutputType([System.Management.Automation.PSObject])]
    [CmdletBinding(SupportsShouldProcess = $false)]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateNotNull()]
        [System.Management.Automation.PSObject]
        $res = (Get-FunctionResource -AppName ("$($MyInvocation.MyCommand)".Split("-"))[1])
    )

    foreach ($Url in $res.Get.Update.Uri) {
        # Get the releases data
        $Updates = Invoke-EvergreenRestMethod -Uri $Url

        # Keep only entries that can be version-sorted
        $ValidUpdates = $Updates | Where-Object {
            ($null -ne $_.enclosure) -and
            ($null -ne $_.enclosure.shortVersionString)
        }
        if ($ValidUpdates.Count -eq 0) {
            throw "$($MyInvocation.MyCommand): No valid release entries found with enclosure.shortVersionString."
        }

        # Select the latest version
        $Latest = $ValidUpdates | `
            Sort-Object -Property @{ Expression = { [System.Version]$_.enclosure.shortVersionString }; Descending = $true } | `
            Select-Object -First 1

        if (($null -eq $Latest) -or ($null -eq $Latest.enclosure)) {
            throw "$($MyInvocation.MyCommand): Latest release entry is missing enclosure data."
        }

        $RequiredEnclosureProperties = @(
            "shortVersionString",
            "version",
            "length",
            "url"
        )

        foreach ($Property in $RequiredEnclosureProperties) {
            if (-not ($Latest.enclosure.PSObject.Properties.Name -contains $Property)) {
                throw "$($MyInvocation.MyCommand): Latest release entry is missing required enclosure property '$Property'."
            }

            if ($null -eq $Latest.enclosure.$Property) {
                throw "$($MyInvocation.MyCommand): Latest release enclosure property '$Property' is null."
            }
        }

        $Urls = @($Latest.enclosure.url) | Where-Object {
            -not [System.String]::IsNullOrWhiteSpace([System.String]$_)
        }
        if ($Urls.Count -eq 0) {
            throw "$($MyInvocation.MyCommand): Latest release enclosure property 'url' has no valid values."
        }
        Write-Verbose -Message "$($MyInvocation.MyCommand): Found version: $($Latest.enclosure.shortVersionString)."

        # Output the latest version
        foreach ($Item in $Urls) {
            $PSObject = [PSCustomObject] @{
                Version      = $Latest.enclosure.shortVersionString
                Build        = $Latest.enclosure.version
                Size         = $Latest.enclosure.length
                Architecture = Get-Architecture -String $Item
                Type         = Get-FileType -File $Item
                FileName     = [System.IO.Path]::GetFileName($Item)
                URI          = $Item -replace " ", "%20"
            }
            Write-Output -InputObject $PSObject
        }
    }
}
