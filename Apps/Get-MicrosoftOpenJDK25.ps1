function Get-MicrosoftOpenJDK25 {
    <#
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

    # Output the results from Get-AdoptiumTemurin
    $Output = Get-AdoptiumTemurin -res $res
    Write-Output -InputObject $Output

    if ($Output -and $Output.Count -gt 0) {
        # Capture the version number from the first output object
        $Output[0].Version -match $res.Get.Download.VersionPattern | Out-Null
        $Version = $Matches[0]

        # Output the download links for additional file types
        foreach ($Uri in $res.Get.Download.Uri) {
            [PSCustomObject]@{
                Version      = $Output[0].Version
                Date         = $Output[0].Date
                ImageType    = $Output[0].ImageType
                Architecture = Get-Architecture -String $Uri
                Type         = Get-FileType -File $Uri
                URI          = (Resolve-SystemNetWebRequest -Uri ($Uri -replace "#version", $Version)).ResponseUri.AbsoluteUri
            }
        }
    }
}
