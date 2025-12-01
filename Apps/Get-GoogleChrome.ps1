function Get-GoogleChrome {
    <#
        .SYNOPSIS
            Returns the available Google Chrome versions across all platforms and channels by querying the official Google version JSON.

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

    begin {
        Write-Warning -Message "$($MyInvocation.MyCommand): The MSI file available for Stable and Extended channels are the same. The file version matches the Extended channel."
    }
    process {
        # Iterate through each channel defined in the manifest
        foreach ($Channel in $res.Get.Update.Channels) {
            Write-Verbose -Message "$($MyInvocation.MyCommand): Channel: $Channel."

            # Return details about the latest version for this channel
            $Versions = Invoke-EvergreenRestMethod -Uri ($res.Get.Update.Uri -replace "#channel", $Channel.ToLower())
            $LatestVersion = $Versions.versions | Select-Object -First 1 | Select-Object -ExpandProperty "version"

            # Iterate through each platform defined in the manifest
            foreach ($Platform in $res.Get.Update.Platforms) {

                # Get release details for this version
                $Release = Invoke-EvergreenRestMethod -Uri ($res.Get.Update.ReleaseUri -replace "#platform", $Platform -replace "#channel", $Channel.ToLower() -replace "#version", $LatestVersion)

                # Iterate through each download URI for this platform and channel
                foreach ($DownloadUri in $res.Get.Download.Uri.$Channel.$Platform) {
                    Write-Verbose -Message "$($MyInvocation.MyCommand): Download URI: $DownloadUri"

                    [PSCustomObject] @{
                        Version      = $LatestVersion
                        StartDate    = $( if ($null -ne $Release.releases.serving.startTime) { $Release.releases.serving.startTime[-1] } else { "N/A" } )
                        EndDate      = $( if ($null -ne $Release.releases.serving.endTime) { $Release.releases.serving.endTime[-1] } else { "N/A" } )
                        Channel      = $Channel
                        Architecture = Get-Architecture -String $Platform
                        Type         = Get-FileType -File $DownloadUri
                        URI          = $DownloadUri
                    }
                }
            }
        }
    }
}
