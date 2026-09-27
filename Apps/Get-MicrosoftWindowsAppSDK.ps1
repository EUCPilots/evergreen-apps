function Get-MicrosoftWindowsAppSDK {
    <#
        .SYNOPSIS
            Get the current version and download URL for the Microsoft Windows Apps SDK.

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

    foreach ($Url in $res.Get.Download.Uri) {
        # Construct the output; Return the custom object to the pipeline
        $PSObject = [PSCustomObject] @{
            Version      = $res.Get.Download.Version
            Date         = ConvertTo-DateTime -DateTime (Get-Date) -Pattern $res.Get.Download.DatePattern
            Architecture = Get-Architecture -String $Url
            Type         = Get-FileType -File $Url
            URI          = $Url
        }
        Write-Output -InputObject $PSObject
    }
}
