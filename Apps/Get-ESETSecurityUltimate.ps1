function Get-ESETSecurityUltimate {
    <#
        .NOTES
            Site: https://stealthpuppy.com
            Author: Aaron Parker
    #>
    [CmdletBinding(SupportsShouldProcess = $false)]
    [OutputType([System.Management.Automation.PSObject])]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateNotNull()]
        [System.Management.Automation.PSObject]
        $res = (Get-FunctionResource -AppName ("$($MyInvocation.MyCommand)".Split("-"))[1])
    )

    # Query the download feed
    $params = @{
        Uri         = $res.Get.Download.Uri
        ContentType = $res.Get.Download.ContentType
        UserAgent   = $script:ResourceStrings.UserAgent.Base
    }
    $Metadata = Invoke-EvergreenRestMethod @params
    if ($null -ne $Metadata) {

        # Extract the files.installer child properties from the metadata
        $Properties = @{}
        $Properties = $Metadata.os_group.PSObject.Properties | `
            Where-Object { $_.Value -match 'Windows' } | `
            Select-Object -ExpandProperty "Name"

        # Iterate over each Windows-specific property extracted from the metadata
        foreach ($Property in $Properties) {
            [PSCustomObject]@{
                Version      = $Metadata.files.installer.$Property.full_version
                Size         = $Metadata.files.installer.$Property.size
                Sha256       = $Metadata.files.installer.$Property.sha2
                Architecture = Get-Architecture -String $Metadata.files.installer.$Property.url
                Type         = Get-FileType -File $Metadata.files.installer.$Property.url
                URI          = $Metadata.files.installer.$Property.url
            }
        }
    }
}
