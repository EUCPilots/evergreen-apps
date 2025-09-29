function Get-SumatraPDFReader {
    <#
        .SYNOPSIS
            Get the current version and download URL for Sumatra PDF Reader.

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

    # Read the SumatraPDFReader version from the text source
    $params = @{
        Uri = $res.Get.Update.Uri
    }
    $Content = Invoke-EvergreenWebRequest @params

    if ($null -ne $Content) {
        try {
            $Version = [RegEx]::Match($Content, $res.Get.Update.MatchVersion).Captures.Groups[1].Value
            Write-Verbose -Message "$($MyInvocation.MyCommand): Found version: $Version, from update source: $($res.Get.Update.Uri)."
        }
        catch {
            $Version = "Latest"
            Write-Warning -Message "$($MyInvocation.MyCommand): Unable to determine version."
        }

        # Construct the output for each architecture
        foreach ($architecture in $res.Get.Download.Uri.GetEnumerator()) {

            # Construct the output; Return the custom object to the pipeline
            $PSObject = [PSCustomObject] @{
                Version      = $Version
                Architecture = $architecture.Name
                Type         = [System.IO.Path]::GetExtension($res.Get.Download.Uri[$architecture.Key]).Split(".")[-1]
                URI          = $res.Get.Download.Uri[$architecture.Key] -replace $res.Get.Download.ReplaceText, $Version
            }
            Write-Output -InputObject $PSObject
        }
    }
}
