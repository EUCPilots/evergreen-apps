function Get-MicrosoftFSLogixApps {
    <#
        .SYNOPSIS
            Get the current version and download URL for the Microsoft FSLogix Apps agent.

        .NOTES
            Site: https://stealthpuppy.com
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

    # Follow the download link which will return a 301
    $response = Resolve-SystemNetWebRequest -Uri $res.Get.Download.Uri

    # Check returned URL. It should be a go.microsoft.com/fwlink/?linkid style link
    if ($null -ne $response) {

        # Construct the output; Return the custom object to the pipeline
        $PSObject = [PSCustomObject] @{
            Version = $res.Get.Download.Version
            Date    = ConvertTo-DateTime -DateTime $response.LastModified -Pattern $res.Get.Download.DatePattern
            Channel = $res.Get.Download.Channel
            URI     = $response.ResponseUri.AbsoluteUri
        }
        Write-Output -InputObject $PSObject
    }
}
