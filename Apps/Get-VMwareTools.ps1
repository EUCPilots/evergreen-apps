function Get-VMwareTools {
    <#
        .SYNOPSIS
            Get the current version and download URL for the VMware Tools.

        .NOTES
            Author: Bronson Magnan
            Twitter: @cit_bronson
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

    # Read the VMware version-mapping file
    $params = @{
        Uri         = $res.Get.Update.Uri
        ContentType = $res.Get.Update.ContentType
        Raw         = $true
    }
    $Content = Invoke-EvergreenWebRequest @params

    if ([string]::IsNullOrWhiteSpace($Content)) {
        Write-Error -Message "$($MyInvocation.MyCommand): Version source is empty."
        return
    }

    if ($null -ne $Content) {
        # Format the results returns and convert into an array that we can sort and use
        $Lines = @($Content -split '\r?\n')
        Write-Verbose -Message "$($MyInvocation.MyCommand): Filtering version table with $($Lines.Count) lines."
        $Lines = @($Lines | ForEach-Object { $_.Trim() } | Where-Object { $_ -and $_ -notmatch "^#" })
        Write-Verbose -Message "$($MyInvocation.MyCommand): Filtered to $($Lines.Count) lines."

        if ($Lines.Count -eq 0) {
            Write-Error -Message "$($MyInvocation.MyCommand): Version source contains no data rows."
            return
        }

        Write-Verbose -Message "$($MyInvocation.MyCommand): Convert to table."
        try {
            # Lines with ESXi server version 'esx/0.0' are missing column 3: ESXi server build number, so set this to '0' to not break table creation.
            # The ESXi server build number, even if set to 0, will not be used further in the process.
            $Lines = $Lines | ForEach-Object { $_ -replace '\besx/0\.0(?=\s+\d+\.\d+\.\d+)', 'esx/0.0 0' }
            $Lines = $Lines | ForEach-Object { $_ -replace '\s+', ',' }
            $VersionTable = $Lines | ConvertFrom-Csv -Delimiter "," -Header $res.Get.Update.CsvHeaders -ErrorAction Stop | `
                Sort-Object -Property @{ Expression = { [System.Version]$_.Version }; Descending = $true } -ErrorAction Stop
        }
        catch {
            Write-Error -Message "$($MyInvocation.MyCommand): Failed to convert version source to a table. $($_.Exception.Message)"
            return
        }

        $LatestVersion = $VersionTable | Select-Object -First 1
        if ($null -eq $LatestVersion -or [string]::IsNullOrWhiteSpace($LatestVersion.Version) -or $LatestVersion.ClientBuild -notmatch '^\d+$') {
            Write-Error -Message "$($MyInvocation.MyCommand): Latest version row is missing a valid version or build number."
            return
        }
        Write-Verbose -Message "$($MyInvocation.MyCommand): Found version: $($LatestVersion.Version)-$($LatestVersion.ClientBuild)"

        # Build the output object for each platform and architecture
        foreach ($architecture in $res.Get.Download.Architecture.GetEnumerator()) {

            # Build the output object
            $PSObject = [PSCustomObject] @{
                Version      = $LatestVersion.Version
                Architecture = Get-Architecture -String $architecture.Key
                URI          = $res.Get.Download.Uri -replace "#architecture", $architecture.Key `
                    -replace "#version", $LatestVersion.Version `
                    -replace "#build", $LatestVersion.ClientBuild `
                    -replace "#processor", $res.Get.Download.Architecture[$architecture.Key]
            }
            Write-Output -InputObject $PSObject
        }
    }
}
