function Get-GoToOpener {
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

    # Resolve the URL to the target location
    $Response = Resolve-SystemNetWebRequest -Uri $res.Get.Download.Uri

    # Match version number
    try {
        $Version = [RegEx]::Match($Response.ResponseUri, $res.Get.Download.MatchVersion).Captures.Groups[1].Value
    }
    catch {
        $Version = "Unknown"
    }

    # Build the output object; Output object to the pipeline
    $PSObject = [PSCustomObject] @{
        Version = $Version
        Date    = $Response.LastModified
        URI     = $Response.ResponseUri.AbsoluteUri
    }
    Write-Output -InputObject $PSObject
}
